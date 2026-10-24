# 语音待办 (voice_todo)

Flutter 安卓应用：按住说话 → 离线识别 → 自动建任务 / 设提醒 / 写日历 / 定闹钟。

**本仓库不在本地安装 Flutter / Java / Android SDK**，APK 完全由 GitHub Actions 构建。

## 安装

1. 打开仓库的 **Actions → build-apk**，选一次成功的构建
2. 页面底部 **Artifacts** 下载 `voice_todo-apk-*`
3. 解压后把 `app-release.apk` 传到手机安装（需允许安装未知来源应用）

## 语音指令

| 说法 | 效果 |
|---|---|
| 明天下午三点提醒我开会 | 建待办 + 到点通知提醒 |
| 每天早上八点提醒我吃药 | 建重复待办 + 每日提醒 |
| 设个明早七点的闹钟 | 写入系统时钟 App（仅新增） |
| 10月28号下午和客户开会到四点 | 写入系统日历日程 |
| 完成买牛奶 / 删掉买牛奶 | 勾选 / 删除待办（模糊匹配标题） |
| 今天有什么安排 | 筛选展示当天任务 |

时间表达支持：今天/明天/后天/大后天、周X/下周X、X月X日(号)、早上/中午/下午/晚上 X点(半)、X:Y、半小时后/N小时后、每天/每周X。

## 技术栈

- Flutter（stable，仅 CI 存在）+ provider
- 语音识别：sherpa-onnx 离线流式 zipformer 中英小模型（int8，构建时下载打进 APK，无需联网/GMS）
- 意图解析：纯 Dart 规则引擎（`lib/nlu/`，有完整单测）
- 存储：sqflite；提醒：flutter_local_notifications（精确闹钟）
- 日历：device_calendar；系统闹钟：MethodChannel → `AlarmClock` Intent（系统限制：只能新增，不能改删）

## 构建链路（CI）

`checkout → flutter create 生成 android/ 脚手架 → tool/patch_android.py 重放定制（权限/label/minSdk/MainActivity）→ tool/fetch_models.sh 下载模型 → analyze → test → build apk → 上传 artifact`

打 `v*` tag 会额外创建 GitHub Release 并附 APK。

## 后续计划

- 识别引擎抽象出接口，可插 Vosk / 云端一句话识别
- 意图模型化（Laya 322M ONNX 或自训小模型）替代规则引擎
- 周重复提醒编辑、任务详情页
