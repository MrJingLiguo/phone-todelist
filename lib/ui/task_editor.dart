import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';

/// 手动新增待办（兜底入口）。
class TaskEditor extends StatefulWidget {
  const TaskEditor({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const TaskEditor(),
    );
  }

  @override
  State<TaskEditor> createState() => _TaskEditorState();
}

class _TaskEditorState extends State<TaskEditor> {
  final _title = TextEditingController();
  bool _remind = false;
  DateTime? _time;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final now = DateTime.now();
    final initial = _time ?? now.add(const Duration(hours: 1));
    final d = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (d == null || !mounted) return;
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(initial));
    if (t == null || !mounted) return;
    setState(() {
      _time = DateTime(d.year, d.month, d.day, t.hour, t.minute);
    });
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) return;
    final state = context.read<AppState>();
    Navigator.pop(context);
    await state.addManual(title, _remind ? _time : null);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _title,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: '要做什么？',
                border: OutlineInputBorder(),
              ),
            ),
            SwitchListTile(
              value: _remind,
              onChanged: (v) {
                setState(() {
                  _remind = v;
                  if (!v) _time = null;
                });
              },
              title: const Text('到点提醒我'),
              contentPadding: EdgeInsets.zero,
            ),
            if (_remind)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.schedule),
                title: Text(_time == null ? '选择提醒时间' : '提醒：${_time!.month}月${_time!.day}日 ${_time!.hour}:${_time!.minute.toString().padLeft(2, '0')}'),
                onTap: _pickTime,
              ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _save,
                child: const Text('保存'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
