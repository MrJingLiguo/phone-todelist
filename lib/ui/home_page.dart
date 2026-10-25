import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/task.dart';
import '../nlu/intent.dart';
import '../state/app_state.dart';
import 'confirm_sheet.dart';
import 'mic_button.dart';
import 'settings_page.dart';
import 'task_editor.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _shownTick = -1;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    if (state.messageTick != _shownTick) {
      _shownTick = state.messageTick;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || state.lastMessage.isEmpty) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(state.lastMessage)));
      });
    }

    final sections = _sections(state);
    return Scaffold(
      appBar: AppBar(
        title: const Text('语音待办'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const SettingsPage())),
          ),
        ],
      ),
      body: Column(
        children: [
          if (state.listening)
            _ListeningBar(
              partial: state.partial,
              modelLoading: state.modelLoading,
              fedSeconds: state.fedBytes / 32000,
            ),
          Expanded(
            child: state.loading
                ? const Center(child: CircularProgressIndicator())
                : sections.isEmpty
                    ? const _EmptyHint()
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 8),
                        itemCount: sections.length,
                        itemBuilder: (context, i) => _section(context, sections[i], state),
                      ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 4, 0, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              MicButton(
                listening: state.listening,
                loading: state.modelLoading,
                onTap: () => _onMicTap(state),
              ),
              const SizedBox(height: 4),
              Text(
                state.listening ? '点击停止' : '点击说话',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              TextButton.icon(
                onPressed: () => TaskEditor.show(context),
                icon: const Icon(Icons.edit_note, size: 18),
                label: const Text('手动添加'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onMicTap(AppState state) async {
    if (!state.listening) {
      await state.startVoice();
      return;
    }
    final intent = await state.stopVoice();
    if (!mounted || intent == null) return;
    if (intent.type == IntentType.unknown) {
      state.showHint(intent.hint);
      return;
    }
    // 完成/删除/查询/待办/闹钟直接执行；写系统日历的日程保留确认卡片（防误建）
    if (intent.type == IntentType.addEvent) {
      final result = await showModalBottomSheet<ConfirmResult>(
        context: context,
        isScrollControlled: true,
        builder: (_) => ConfirmSheet(intent: intent),
      );
      if (!mounted || result == null) return;
      await state.execute(
        result.intent,
        title: result.title,
        time: result.time,
        end: result.end,
      );
      return;
    }
    await state.execute(intent);
  }

  List<_Section> _sections(AppState state) {
    final now = DateTime.now();
    final today0 = DateTime(now.year, now.month, now.day);
    final src = state.filterDay == null
        ? state.tasks
        : state.tasks
            .where((t) => t.dueAt != null && _sameDay(t.dueAt!, state.filterDay!))
            .toList();
    final overdue = <Task>[];
    final today = <Task>[];
    final future = <Task>[];
    final someday = <Task>[];
    final done = <Task>[];
    for (final t in src) {
      if (t.done) {
        done.add(t);
        continue;
      }
      final d = t.dueAt;
      if (d == null) {
        someday.add(t);
        continue;
      }
      final d0 = DateTime(d.year, d.month, d.day);
      if (d0.isBefore(today0)) {
        overdue.add(t);
      } else if (d0 == today0) {
        today.add(t);
      } else {
        future.add(t);
      }
    }
    final sections = <_Section>[];
    void add(String title, List<Task> list) {
      if (list.isNotEmpty) sections.add(_Section(title, list));
    }

    add('已逾期', overdue);
    add('今天', today);
    add('之后', future);
    add('没有时间', someday);
    add('已完成', done);
    return sections;
  }

  Widget _section(BuildContext context, _Section s, AppState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
          child: Text(
            '${s.title} · ${s.tasks.length}',
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        for (final t in s.tasks) _tile(context, t, state),
      ],
    );
  }

  Widget _tile(BuildContext context, Task t, AppState state) {
    final kindIcon = switch (t.kind) {
      'event' => Icons.event_outlined,
      'alarm' => Icons.alarm,
      _ => t.remindAt != null ? Icons.notifications_active_outlined : Icons.check_circle_outline,
    };
    final sub = StringBuffer();
    if (t.dueAt != null) sub.write(fmtTime(t.dueAt));
    if (t.repeat != null) {
      if (sub.isNotEmpty) sub.write(' · ');
      sub.write(repeatLabel(t.repeat!));
    }
    return CheckboxListTile(
      value: t.done,
      onChanged: (_) {
        state.toggleDone(t);
      },
      controlAffinity: ListTileControlAffinity.leading,
      title: Text(
        t.title,
        style: TextStyle(
          decoration: t.done ? TextDecoration.lineThrough : null,
          color: t.done ? Theme.of(context).disabledColor : null,
        ),
      ),
      subtitle: sub.isEmpty
          ? null
          : Row(
              children: [
                Icon(kindIcon, size: 14, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 4),
                Text(sub.toString()),
              ],
            ),
      secondary: IconButton(
        icon: const Icon(Icons.delete_outline),
        onPressed: () async {
          final ok = await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: const Text('删除这条待办？'),
              content: Text(t.title),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: const Text('取消')),
                FilledButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    child: const Text('删除')),
              ],
            ),
          );
          if (ok == true) {
            await state.remove(t);
          }
        },
      ),
    );
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _Section {
  final String title;
  final List<Task> tasks;
  const _Section(this.title, this.tasks);
}

class _ListeningBar extends StatelessWidget {
  final String partial;
  final bool modelLoading;
  final double fedSeconds;

  const _ListeningBar({
    required this.partial,
    required this.modelLoading,
    required this.fedSeconds,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final status = modelLoading
        ? '正在加载识别模型，首次约需几秒…'
        : partial.isEmpty
            ? (fedSeconds < 0.5
                ? '正在听，请说出指令…'
                : '正在听… 已收音 ${fedSeconds.toStringAsFixed(1)} 秒')
            : partial;
    return Container(
      width: double.infinity,
      color: scheme.primaryContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(Icons.mic, size: 18, color: scheme.onPrimaryContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              status,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: scheme.onPrimaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.mic_none, size: 56, color: scheme.onSurfaceVariant),
          const SizedBox(height: 12),
          const Text('还没有待办'),
          const SizedBox(height: 4),
          Text(
            '试试说：“明天下午三点提醒我开会”',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
