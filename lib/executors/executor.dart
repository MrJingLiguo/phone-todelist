import 'package:device_calendar/device_calendar.dart' as cal;
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../data/task_db.dart';
import '../models/task.dart';
import '../nlu/intent.dart';
import '../platform/alarm_channel.dart';
import '../platform/vlog.dart';

/// 时区初始化（v1：东八区按 Asia/Shanghai，其他偏移退化为 UTC）。
class AppTz {
  AppTz._();
  static tz.Location? _local;
  static tz.Location get local {
    if (_local == null) {
      tzdata.initializeTimeZones();
      final offset = DateTime.now().timeZoneOffset;
      _local = tz.getLocation(
          offset == const Duration(hours: 8) ? 'Asia/Shanghai' : 'UTC');
    }
    return _local!;
  }
}

class ExecResult {
  final bool ok;
  final String message;
  const ExecResult(this.ok, this.message);
}

/// 本地通知提醒（精确闹钟调度）。
class ReminderService {
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  /// 频道设置创建后不可变：换提示音/音量通道时必须换新 id
  static const _channelId = 'reminders_v3';
  static const _channel = AndroidNotificationChannel(
    _channelId,
    '待办提醒',
    description: '语音待办的定时提醒（到点响 1 分钟闹钟音）',
    importance: Importance.max,
    playSound: true,
    sound: RawResourceAndroidNotificationSound('alarm_60s'),
    audioAttributesUsage: AudioAttributesUsage.alarm,
    enableVibration: true,
  );
  static const _details = AndroidNotificationDetails(
    _channelId,
    '待办提醒',
    channelDescription: '语音待办的定时提醒（到点响 1 分钟闹钟音）',
    importance: Importance.max,
    priority: Priority.high,
    playSound: true,
    sound: RawResourceAndroidNotificationSound('alarm_60s'),
    audioAttributesUsage: AudioAttributesUsage.alarm,
    enableVibration: true,
  );
  static const _testDetails = AndroidNotificationDetails(
    _channelId,
    '待办提醒',
    channelDescription: '语音待办的定时提醒（到点响 1 分钟闹钟音）',
    importance: Importance.max,
    priority: Priority.high,
    playSound: true,
    sound: RawResourceAndroidNotificationSound('keep_beep'),
    audioAttributesUsage: AudioAttributesUsage.alarm,
    enableVibration: true,
  );

  Future<void> init() async {
    await _plugin.initialize(
      const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher')),
    );
    if (defaultTargetPlatform == TargetPlatform.android) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.requestNotificationsPermission();
      // pm clear / 重装会清掉频道；启动时显式重建，确保接收器触发时频道存在
      await android?.createNotificationChannel(_channel);
      // 清理历史版本频道
      await android?.deleteNotificationChannel('reminders');
      await android?.deleteNotificationChannel('reminders_v2');
    }
  }

  Future<void> schedule(int id, String title, DateTime when, String? repeat) async {
    var at = when;
    final now = DateTime.now();
    if (repeat != null && !at.isAfter(now)) {
      at = repeat.startsWith('weekly:')
          ? at.add(const Duration(days: 7))
          : at.add(const Duration(days: 1));
    }
    DateTimeComponents? comp;
    if (repeat == 'daily' || repeat == 'weekday') {
      comp = DateTimeComponents.time;
    } else if (repeat != null && repeat.startsWith('weekly:')) {
      comp = DateTimeComponents.dayOfWeekAndTime;
    }
    await _plugin.zonedSchedule(
      id,
      '待办提醒',
      title,
      tz.TZDateTime.from(at, AppTz.local),
      const NotificationDetails(android: _details),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: comp,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: 'task:$id',
    );
  }

  /// 立即发一条测试通知，验证通知链路（短音，不响满 1 分钟）。
  Future<void> testNotification() async {
    await _plugin.show(
      99999,
      '测试通知',
      '看到这条说明通知链路正常',
      const NotificationDetails(android: _testDetails),
    );
  }

  Future<void> cancel(int id) async {
    try {
      await _plugin.cancel(id);
    } catch (_) {}
  }

  /// 系统通知权限是否开启（MIUI 等国产 ROM 需手动确认）。
  Future<bool> notificationsEnabled() async {
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      return await android?.areNotificationsEnabled() ?? true;
    } catch (_) {
      return true;
    }
  }

  /// 已排定的提醒数量（-1 表示查询失败）。
  Future<int> pendingCount() async {
    try {
      final list = await _plugin.pendingNotificationRequests();
      return list.length;
    } catch (_) {
      return -1;
    }
  }
}

/// 系统日历读写。
class CalendarService {
  final cal.DeviceCalendarPlugin _plugin = cal.DeviceCalendarPlugin();

  Future<bool> ensurePermission() async {
    final r = await _plugin.requestPermissions();
    return r.isSuccess && (r.data ?? false);
  }

  Future<String?> defaultCalendarId() async {
    final r = await _plugin.retrieveCalendars();
    final cals = r.data ?? const [];
    if (cals.isEmpty) return null;
    for (final c in cals) {
      if (c.isDefault ?? false) return c.id;
    }
    return cals.first.id;
  }

  Future<bool> createEvent({
    required String calendarId,
    required String title,
    required DateTime start,
    required DateTime end,
  }) async {
    final event = cal.Event(
      calendarId,
      title: title,
      start: tz.TZDateTime.from(start, AppTz.local),
      end: tz.TZDateTime.from(end, AppTz.local),
      description: '由语音待办创建',
    );
    final r = await _plugin.createOrUpdateEvent(event);
    return (r?.isSuccess ?? false) && (r?.data != null);
  }
}

/// 意图 → 实际动作的路由。
class Executor {
  final TaskDb db;
  final ReminderService reminders;
  final CalendarService calendar;
  final AlarmChannel alarm;

  const Executor(this.db, this.reminders, this.calendar, this.alarm);

  Future<ExecResult> run(
    ParsedIntent i, {
    String? titleOverride,
    DateTime? timeOverride,
    DateTime? endOverride,
  }) async {
    final title =
        (titleOverride != null && titleOverride.trim().isNotEmpty) ? titleOverride.trim() : i.title;
    final time = timeOverride ?? i.time;
    switch (i.type) {
      case IntentType.addTask:
        return _addTask(title, time, i.repeat);
      case IntentType.addEvent:
        return _addEvent(title, time, endOverride ?? i.endTime);
      case IntentType.setAlarm:
        return _setAlarm(title, time, i.repeat);
      case IntentType.completeTask:
        return _complete(i.title);
      case IntentType.deleteTask:
        return _delete(i.title);
      case IntentType.query:
        return const ExecResult(true, '已更新列表');
      case IntentType.unknown:
        return ExecResult(false, i.hint ?? '没听懂，请再说一次');
    }
  }

  Future<ExecResult> _addTask(String title, DateTime? time, String? repeat,
      [String? extra]) async {
    final id = await db.insert(Task(
      title: title,
      kind: 'task',
      dueAt: time,
      remindAt: time,
      repeat: repeat,
      createdAt: DateTime.now(),
    ));
    var warn = '';
    if (time != null) {
      try {
        if (!time.isAfter(DateTime.now())) {
          warn = '提醒时间已过，未设置提醒';
        } else {
          await reminders.schedule(id, title, time, repeat);
          if (!await reminders.notificationsEnabled()) {
            warn = '已排提醒，但系统通知权限未开启，到点不会显示';
          }
        }
      } catch (e) {
        VLog.say('schedule failed: $e');
        warn = '提醒设置失败：$e';
      }
    }
    var msg = '已添加「$title」';
    if (time != null && warn.isEmpty) msg += '，${fmtTime(time)}提醒';
    if (repeat != null) msg += '（${repeatLabel(repeat)}）';
    if (warn.isNotEmpty) msg += '。$warn';
    if (extra != null) msg += '。$extra';
    return ExecResult(true, msg);
  }

  Future<ExecResult> _addEvent(
      String title, DateTime? time, DateTime? endTime) async {
    if (time == null) {
      return const ExecResult(false, '请带上时间，例如：“明天下午三点开项目会”');
    }
    final granted = await calendar.ensurePermission();
    final calId = granted ? await calendar.defaultCalendarId() : null;
    final end = endTime ?? time.add(const Duration(hours: 1));
    if (calId == null) {
      return _addTask(title, time, null, '未获得日历权限，已存为待办');
    }
    final ok = await calendar.createEvent(
        calendarId: calId, title: title, start: time, end: end);
    if (!ok) {
      return _addTask(title, time, null, '写入日历失败，已存为待办');
    }
    await db.insert(Task(
      title: title,
      kind: 'event',
      dueAt: time,
      endAt: end,
      createdAt: DateTime.now(),
    ));
    return ExecResult(true, '已创建日程「$title」${fmtTime(time)} 至 ${fmtTime(end)}');
  }

  Future<ExecResult> _setAlarm(String title, DateTime? time, String? repeat) async {
    if (time == null) {
      return const ExecResult(false, '没听出闹钟时间，试试：“设个明早七点的闹钟”');
    }
    final id = await db.insert(Task(
      title: title,
      kind: 'alarm',
      dueAt: time,
      repeat: repeat,
      createdAt: DateTime.now(),
    ));
    final ok = await alarm.setAlarm(time: time, message: title, days: _alarmDays(repeat));
    if (ok) {
      return ExecResult(true, '已在系统时钟创建 ${two(time.hour)}:${two(time.minute)} 闹钟「$title」');
    }
    await reminders.schedule(id, title, time, repeat);
    return ExecResult(true, '无法写入系统时钟，已改为应用内提醒「$title」');
  }

  Future<ExecResult> _complete(String keyword) async {
    final t = await _find(keyword);
    if (t == null) {
      return ExecResult(false, '没找到「$keyword」对应的待办');
    }
    await db.updateDone(t.id!, true);
    await reminders.cancel(t.id!);
    return ExecResult(true, '已完成「${t.title}」');
  }

  Future<ExecResult> _delete(String keyword) async {
    final t = await _find(keyword);
    if (t == null) {
      return ExecResult(false, '没找到「$keyword」对应的待办');
    }
    await db.delete(t.id!);
    await reminders.cancel(t.id!);
    return ExecResult(true, '已删除「${t.title}」');
  }

  Future<Task?> _find(String keyword) async {
    final kw = keyword.trim();
    if (kw.isEmpty) return null;
    final tasks = await db.all();
    for (final t in tasks) {
      if (!t.done && (t.title.contains(kw) || kw.contains(t.title))) {
        return t;
      }
    }
    return null;
  }

  /// EXTRA_DAYS 使用 Calendar.DAY_OF_WEEK 常量：周日=1 … 周六=7。
  List<int>? _alarmDays(String? repeat) {
    if (repeat == null) return null;
    if (repeat == 'daily') return const [1, 2, 3, 4, 5, 6, 7];
    if (repeat == 'weekday') return const [2, 3, 4, 5, 6];
    if (repeat.startsWith('weekly:')) {
      final n = int.tryParse(repeat.split(':')[1]);
      if (n == null) return null;
      return [n == 7 ? 1 : n + 1];
    }
    return null;
  }
}
