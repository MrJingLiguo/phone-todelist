import 'package:flutter/services.dart';

/// release 模式下 Dart 的 print 不会进 logcat，
/// 通过原生日志桥输出，logcat 里以 tag "voice_todo" 过滤。
class VLog {
  VLog._();

  static const MethodChannel _ch = MethodChannel('voice_todo/log');

  static void say(String msg) {
    _ch.invokeMethod<void>('log', msg).catchError((Object _) {});
  }
}
