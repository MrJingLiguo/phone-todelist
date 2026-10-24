/// 语音指令解析结果的数据模型与展示辅助（纯 Dart，可单测）。
library;

enum IntentType { addTask, addEvent, setAlarm, completeTask, deleteTask, query, unknown }

class ParsedIntent {
  final IntentType type;

  /// 待办/日程/闹钟的标题；complete/delete 场景下是用于模糊匹配的关键词。
  final String title;
  final DateTime? time;
  final DateTime? endTime;

  /// null | daily | weekday | weekly:N
  final String? repeat;

  /// 无需执行也要展示给用户的说明（如“系统闹钟无法语音删除”）。
  final String? hint;
  final String raw;

  const ParsedIntent({
    required this.type,
    this.title = '',
    this.time,
    this.endTime,
    this.repeat,
    this.hint,
    this.raw = '',
  });
}

String intentLabel(IntentType type) {
  return switch (type) {
    IntentType.addTask => '待办',
    IntentType.addEvent => '日程',
    IntentType.setAlarm => '闹钟',
    IntentType.completeTask => '完成',
    IntentType.deleteTask => '删除',
    IntentType.query => '查询',
    IntentType.unknown => '未识别',
  };
}

String repeatLabel(String repeat) {
  if (repeat == 'daily') return '每天';
  if (repeat == 'weekday') return '工作日';
  if (repeat.startsWith('weekly:')) {
    const names = ['一', '二', '三', '四', '五', '六', '日'];
    final n = int.tryParse(repeat.split(':')[1]) ?? 1;
    return '每周${names[n - 1]}';
  }
  return repeat;
}

String two(int v) => v.toString().padLeft(2, '0');

String fmtTime(DateTime? t) {
  if (t == null) return '';
  return '${t.month}月${t.day}日 ${two(t.hour)}:${two(t.minute)}';
}

String fmtDay(DateTime? t) {
  if (t == null) return '';
  return '${t.year}年${t.month}月${t.day}日';
}
