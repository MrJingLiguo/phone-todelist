import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import '../data/task_db.dart';
import '../executors/executor.dart';
import '../models/task.dart';
import '../nlu/intent.dart';
import '../nlu/intent_parser.dart';
import '../stt/sherpa_stt.dart';

/// 全局状态：任务列表 + 语音录入 + 执行反馈。
class AppState extends ChangeNotifier {
  AppState({required this.db, required this.executor});

  final TaskDb db;
  final Executor executor;

  List<Task> tasks = [];
  bool loading = true;
  bool listening = false;
  bool modelLoading = false;
  String partial = '';

  /// 本次录音已收到的 PCM 字节数（诊断用，UI 显示收音秒数）。
  int fedBytes = 0;
  int _lastNotifyFed = 0;

  /// 查询意图设置的日期过滤；null 显示全部。
  DateTime? filterDay;

  String lastMessage = '';
  bool lastOk = true;
  int messageTick = 0;

  SherpaStt? _stt;
  AudioRecorder? _recorder;
  StreamSubscription<Uint8List>? _sub;

  Future<void> init() async {
    try {
      await executor.reminders.init();
    } catch (_) {}
    await refresh();
  }

  Future<void> refresh() async {
    tasks = await db.all();
    loading = false;
    notifyListeners();
  }

  void _msg(String m, {bool ok = true}) {
    lastMessage = m;
    lastOk = ok;
    messageTick++;
    notifyListeners();
  }

  /// 展示解析器的提示（未识别等）。
  void showHint(String? hint) {
    _msg(hint ?? '没听懂，请再说一次', ok: false);
  }

  Future<void> startVoice() async {
    if (listening) return;
    listening = true;
    partial = '';
    notifyListeners();

    if (_stt == null) {
      modelLoading = true;
      notifyListeners();
      try {
        _stt = await SherpaStt.create();
      } catch (e) {
        modelLoading = false;
        listening = false;
        _msg('识别模型加载失败：$e', ok: false);
        return;
      }
      modelLoading = false;
    }

    final status = await Permission.microphone.request();
    print('[voice_todo] mic permission -> $status');
    if (status != PermissionStatus.granted) {
      listening = false;
      _msg('未获得麦克风权限', ok: false);
      return;
    }

    try {
      _stt!.newStream();
      fedBytes = 0;
      _lastNotifyFed = 0;
      final recorder = AudioRecorder();
      _recorder = recorder;
      final stream = await recorder.startStream(const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
        androidConfig: AndroidRecordConfig(audioSource: AndroidAudioSource.mic),
      ));
      print('[voice_todo] record stream started');
      _sub = stream.listen((chunk) {
        if (!listening) return;
        fedBytes += chunk.lengthInBytes;
        _stt!.feed(chunk);
        final t = _stt!.decode();
        final changed = t != partial;
        if (changed) partial = t;
        if (changed || fedBytes - _lastNotifyFed >= 8000) {
          _lastNotifyFed = fedBytes;
          notifyListeners();
        }
      }, onError: (Object e) {
        print('[voice_todo] stream error: $e');
        _stopInternal();
        _msg('录音出错：$e', ok: false);
      });
    } catch (e) {
      listening = false;
      print('[voice_todo] start error: $e');
      _msg('无法开始录音：$e', ok: false);
      return;
    }
    notifyListeners();
  }

  /// 停止录音并解析，返回可确认的意图（文本为空返回 null）。
  Future<ParsedIntent?> stopVoice() async {
    if (!listening) return null;
    await _stopInternal();
    final text = partial.trim();
    partial = '';
    notifyListeners();
    print('[voice_todo] stop, fed=${(fedBytes / 32000).toStringAsFixed(1)}s, final="$text"');
    if (text.isEmpty) {
      _msg('没听清，请再试一次', ok: false);
      return null;
    }
    return IntentParser.parse(text);
  }

  Future<void> _stopInternal() async {
    listening = false;
    await _sub?.cancel();
    _sub = null;
    try {
      await _recorder?.stop();
    } catch (_) {}
    try {
      await _recorder?.dispose();
    } catch (_) {}
    _recorder = null;
    notifyListeners();
  }

  Future<void> execute(
    ParsedIntent i, {
    String? title,
    DateTime? time,
    DateTime? end,
  }) async {
    if (i.type == IntentType.query) {
      filterDay = i.time;
      await refresh();
      final n = i.time == null
          ? tasks.where((t) => !t.done).length
          : tasks.where((t) => !t.done && _inDay(t.dueAt, i.time!)).length;
      _msg(i.time == null ? '共 $n 条未完成' : '已筛选到 ${fmtDay(i.time)}，共 $n 条');
      return;
    }
    filterDay = null;
    final r = await executor.run(
      i,
      titleOverride: title,
      timeOverride: time,
      endOverride: end,
    );
    await refresh();
    _msg(r.message, ok: r.ok);
  }

  Future<void> toggleDone(Task t) async {
    final done = !t.done;
    await db.updateDone(t.id!, done);
    if (done) {
      await executor.reminders.cancel(t.id!);
    } else if (t.remindAt != null && !t.remindAt!.isBefore(DateTime.now())) {
      await executor.reminders.schedule(t.id!, t.title, t.remindAt!, t.repeat);
    }
    await refresh();
  }

  Future<void> remove(Task t) async {
    await db.delete(t.id!);
    await executor.reminders.cancel(t.id!);
    await refresh();
  }

  Future<void> addManual(String title, DateTime? time) async {
    final i = ParsedIntent(type: IntentType.addTask, title: title, time: time, raw: title);
    final r = await executor.run(i);
    await refresh();
    _msg(r.message, ok: r.ok);
  }

  static bool _inDay(DateTime? d, DateTime day) {
    if (d == null) return false;
    return d.year == day.year && d.month == day.month && d.day == day.day;
  }

  @override
  void dispose() {
    _stopInternal();
    _stt?.dispose();
    super.dispose();
  }
}
