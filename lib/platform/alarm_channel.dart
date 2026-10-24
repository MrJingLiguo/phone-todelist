import 'package:flutter/services.dart';

/// 写系统时钟闹钟（AlarmClock Intent）。
/// 系统限制：只能新增，不能修改/删除已有闹钟。
class AlarmChannel {
  const AlarmChannel();

  static const _channel = MethodChannel('voice_todo/alarm');

  /// [days] 用 Calendar.DAY_OF_WEEK 常量（周日=1 … 周六=7），null 表示一次性闹钟。
  Future<bool> setAlarm({
    required DateTime time,
    String message = '',
    List<int>? days,
    bool skipUi = true,
  }) async {
    try {
      final ok = await _channel.invokeMethod<bool>('setAlarm', {
        'hour': time.hour,
        'minute': time.minute,
        'message': message,
        'days': days,
        'skipUi': skipUi,
      });
      return ok ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
