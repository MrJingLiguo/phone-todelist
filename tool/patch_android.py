#!/usr/bin/env python3
"""对 CI 生成的 Android 脚手架做幂等定制。

android/ 目录不入库，每次 CI 构建时由 `flutter create .` 重新生成，
本脚本随后重放全部定制：
  1. AndroidManifest.xml 注入权限 + <queries>，改应用名为「语音待办」
  2. minSdk 提到 24（兼容 build.gradle 与 build.gradle.kts 两种模板）
  3. 覆写 MainActivity.kt，注册写系统闹钟的 MethodChannel
"""
import io
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ANDROID = os.path.join(ROOT, "android")
APP_MAIN = os.path.join(ANDROID, "app", "src", "main")
PKG = "com.jing.voice_todo"

PERMISSIONS = [
    "android.permission.RECORD_AUDIO",
    "android.permission.POST_NOTIFICATIONS",
    "android.permission.USE_EXACT_ALARM",
    "android.permission.SCHEDULE_EXACT_ALARM",
    "android.permission.SET_ALARM",
    "android.permission.READ_CALENDAR",
    "android.permission.WRITE_CALENDAR",
    "android.permission.RECEIVE_BOOT_COMPLETED",
    "android.permission.VIBRATE",
]

QUERIES = (
    "    <queries>\n"
    '        <intent>\n'
    '            <action android:name="android.intent.action.SET_ALARM" />\n'
    "        </intent>\n"
    "    </queries>\n"
)

MAIN_ACTIVITY = """package %s

import android.content.Intent
import android.provider.AlarmClock
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "voice_todo/alarm")
            .setMethodCallHandler { call, result ->
                if (call.method == "setAlarm") {
                    try {
                        val hour = call.argument<Int>("hour")!!
                        val minute = call.argument<Int>("minute")!!
                        val message = call.argument<String>("message") ?: ""
                        val days = call.argument<List<Int>>("days")
                        val intent = Intent(AlarmClock.ACTION_SET_ALARM).apply {
                            putExtra(AlarmClock.EXTRA_HOUR, hour)
                            putExtra(AlarmClock.EXTRA_MINUTES, minute)
                            if (message.isNotEmpty()) {
                                putExtra(AlarmClock.EXTRA_MESSAGE, message)
                            }
                            if (days != null && days.isNotEmpty()) {
                                putExtra(AlarmClock.EXTRA_DAYS, days.toIntArray())
                            }
                            putExtra(AlarmClock.EXTRA_SKIP_UI, call.argument<Boolean>("skipUi") ?: true)
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ALARM_ERROR", e.message, null)
                    }
                } else {
                    result.notImplemented()
                }
            }
    }
}
""" % PKG


def read(path):
    with io.open(path, encoding="utf-8") as f:
        return f.read()


def write(path, text):
    with io.open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)


def patch_manifest(path):
    text = read(path)
    if 'android:label="语音待办"' not in text:
        text = re.sub(r'android:label="[^"]*"', 'android:label="语音待办"', text, count=1)
    missing = [
        '    <uses-permission android:name="%s" />\n' % p
        for p in PERMISSIONS
        if p not in text
    ]
    if missing:
        text = text.replace("<application", "".join(missing) + "    <application", 1)
    if "<queries>" not in text:
        text = text.replace("<application", QUERIES + "    <application", 1)
    write(path, text)
    print("manifest: %d permissions ensured, queries ensured, label set" % len(PERMISSIONS))


def patch_min_sdk():
    rules = [
        ("build.gradle.kts", r"minSdk\s*=\s*flutter\.minSdkVersion", "minSdk = 24"),
        ("build.gradle", r"minSdkVersion\s+flutter\.minSdkVersion", "minSdkVersion 24"),
    ]
    for name, pat, repl in rules:
        p = os.path.join(ANDROID, "app", name)
        if os.path.exists(p):
            text = read(p)
            new = re.sub(pat, repl, text, count=1)
            if new != text:
                write(p, new)
                print("%s: minSdk -> 24" % name)
            else:
                print("%s: minSdk already patched" % name)
            return
    print("WARN: no app-level gradle file found")


def write_main_activity():
    d = os.path.join(APP_MAIN, "kotlin", *PKG.split("."))
    os.makedirs(d, exist_ok=True)
    write(os.path.join(d, "MainActivity.kt"), MAIN_ACTIVITY)
    print("MainActivity.kt written")


DESUGAR_LIB = "com.android.tools:desugar_jdk_libs:2.1.4"


def patch_desugaring():
    """flutter_local_notifications 要求开启 core library desugaring。"""
    for name, kts in [("build.gradle.kts", True), ("build.gradle", False)]:
        p = os.path.join(ANDROID, "app", name)
        if not os.path.exists(p):
            continue
        text = read(p)
        changed = False
        if "CoreLibraryDesugaringEnabled = true" not in text and "coreLibraryDesugaringEnabled true" not in text:
            if kts:
                new = re.sub(
                    r"(compileOptions\s*\{)",
                    r"\1\n        isCoreLibraryDesugaringEnabled = true",
                    text,
                    count=1,
                )
            else:
                new = re.sub(
                    r"(compileOptions\s*\{)",
                    r"\1\n        coreLibraryDesugaringEnabled true",
                    text,
                    count=1,
                )
            if new != text:
                text, changed = new, True
        if "coreLibraryDesugaring(" not in text and "coreLibraryDesugaring " not in text:
            if kts:
                block = '\n\ndependencies {\n    coreLibraryDesugaring("%s")\n}\n' % DESUGAR_LIB
            else:
                block = "\n\ndependencies {\n    coreLibraryDesugaring '%s'\n}\n" % DESUGAR_LIB
            text = text.rstrip() + block
            changed = True
        if changed:
            write(p, text)
            print("%s: desugaring enabled" % name)
        else:
            print("%s: desugaring already patched" % name)
        return
    print("WARN: no gradle file found for desugaring patch")


if __name__ == "__main__":
    patch_manifest(os.path.join(APP_MAIN, "AndroidManifest.xml"))
    patch_min_sdk()
    write_main_activity()
    patch_desugaring()
