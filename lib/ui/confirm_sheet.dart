import 'package:flutter/material.dart';

import '../nlu/intent.dart';

/// 确认卡片执行结果（允许用户修改标题与时间后提交）。
class ConfirmResult {
  final ParsedIntent intent;
  final String title;
  final DateTime? time;
  final DateTime? end;

  const ConfirmResult(this.intent, this.title, this.time, this.end);
}

/// 识别结果确认卡片：原始文本 + 可编辑标题/时间 → 确认执行。
class ConfirmSheet extends StatefulWidget {
  final ParsedIntent intent;

  const ConfirmSheet({super.key, required this.intent});

  @override
  State<ConfirmSheet> createState() => _ConfirmSheetState();
}

class _ConfirmSheetState extends State<ConfirmSheet> {
  late final TextEditingController _title;
  DateTime? _time;
  DateTime? _end;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.intent.title);
    _time = widget.intent.time;
    _end = widget.intent.endTime;
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  bool get _timeEditable {
    return switch (widget.intent.type) {
      IntentType.addTask ||
      IntentType.addEvent ||
      IntentType.setAlarm =>
        _time != null,
      _ => false,
    };
  }

  Future<void> _pickTime() async {
    final now = DateTime.now();
    final initial = _time ?? now;
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

  @override
  Widget build(BuildContext context) {
    final i = widget.intent;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Chip(label: Text(intentLabel(i.type))),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    i.raw,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _title,
              decoration: const InputDecoration(labelText: '内容', border: OutlineInputBorder()),
            ),
            if (_timeEditable) ...[
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.schedule),
                title: Text(fmtTime(_time)),
                subtitle: (i.endTime != null || _end != null)
                    ? Text('至 ${fmtTime(_end ?? i.endTime)}')
                    : null,
                onTap: _pickTime,
              ),
            ],
            if (i.repeat != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('重复：${repeatLabel(i.repeat!)}',
                    style: TextStyle(color: scheme.onSurfaceVariant)),
              ),
            if (i.hint != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(i.hint!, style: TextStyle(color: scheme.error)),
              ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消'),
                ),
                const SizedBox(width: 8),
                if (i.type != IntentType.unknown)
                  FilledButton(
                    onPressed: () => Navigator.pop(
                        context, ConfirmResult(i, _title.text.trim(), _time, _end)),
                    child: const Text('确认执行'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
