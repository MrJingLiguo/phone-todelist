import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';

/// 设置页：权限状态 + 语音指令帮助。
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text('提醒状态', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          FutureBuilder<int>(
            future: context.read<AppState>().executor.reminders.pendingCount(),
            builder: (context, snap) {
              final n = snap.data ?? -1;
              return ListTile(
                leading: Icon(
                  n > 0 ? Icons.notifications_active : Icons.notifications_off_outlined,
                  color: n > 0 ? Colors.green : Colors.orange,
                ),
                title: const Text('已排定的提醒'),
                subtitle: Text(n < 0 ? '查询失败' : '$n 条'),
              );
            },
          ),
          const ListTile(
            leading: Icon(Icons.bug_report_outlined),
            title: Text('小米/红米（MIUI）必读'),
            subtitle: Text(
              '到点不提醒时依次检查：\n'
              '1. 系统设置 → 应用管理 → 语音待办 → 允许「自启动」\n'
              '2. 省电策略改为「无限制」\n'
              '3. 通知权限保持开启\n'
              '4. 最近任务里不要划掉本应用（可先锁定）',
              style: TextStyle(height: 1.4),
            ),
            isThreeLine: true,
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text('权限', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          FutureBuilder<PermissionStatus>(
            future: Permission.microphone.status,
            builder: (context, snap) {
              final ok = snap.data == PermissionStatus.granted;
              return ListTile(
                leading: Icon(
                  ok ? Icons.check_circle : Icons.error_outline,
                  color: ok ? Colors.green : Colors.orange,
                ),
                title: const Text('麦克风'),
                subtitle: Text(ok ? '已授权，可以使用语音' : '未授权，语音功能不可用'),
                trailing: ok
                    ? null
                    : TextButton(
                        onPressed: () => Permission.microphone.request(),
                        child: const Text('授权'),
                      ),
              );
            },
          ),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('通知 / 日历 / 精确闹钟'),
            subtitle: Text('首次使用对应功能时向系统申请；精确闹钟由 USE_EXACT_ALARM 权限自动授予'),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text('语音指令示例', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          const _Example('明天下午三点提醒我开会', '建待办 + 到点通知提醒'),
          const _Example('每天早上八点提醒我吃药', '建每日重复待办'),
          const _Example('设个明早七点的闹钟', '写入系统时钟（仅新增）'),
          const _Example('10月28号下午和客户开会到四点', '写入系统日历日程'),
          const _Example('完成买牛奶 / 删掉买牛奶', '勾选 / 删除（模糊匹配标题）'),
          const _Example('今天有什么安排', '筛选展示当天任务'),
          const Divider(),
          const ListTile(
            leading: Icon(Icons.graphic_eq),
            title: Text('识别模型'),
            subtitle: Text('sherpa-onnx 流式 zipformer 中英双语 int8，完全离线'),
          ),
          const ListTile(
            leading: Icon(Icons.tag),
            title: Text('版本'),
            subtitle: Text('0.1.0'),
          ),
        ],
      ),
    );
  }
}

class _Example extends StatelessWidget {
  final String cmd;
  final String effect;

  const _Example(this.cmd, this.effect);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: const Icon(Icons.chat_bubble_outline, size: 18),
      title: Text(cmd),
      subtitle: Text(effect),
    );
  }
}
