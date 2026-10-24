/// 待办/日程/闹钟统一的本地记录。
///
/// [kind] 区分来源与去向：
/// - task  普通待办（可带通知提醒）
/// - event 已写入系统日历的日程
/// - alarm 已写入系统时钟的闹钟（系统限制只能新增）
class Task {
  final int? id;
  final String title;
  final String note;
  final String kind;
  final DateTime? dueAt;
  final DateTime? endAt;
  final DateTime? remindAt;

  /// null | daily | weekday | weekly:N（N: 1=周一 … 7=周日）
  final String? repeat;
  final bool done;
  final DateTime createdAt;

  const Task({
    this.id,
    required this.title,
    this.note = '',
    this.kind = 'task',
    this.dueAt,
    this.endAt,
    this.remindAt,
    this.repeat,
    this.done = false,
    required this.createdAt,
  });

  Task copyWith({
    int? id,
    String? title,
    String? note,
    String? kind,
    DateTime? dueAt,
    DateTime? endAt,
    DateTime? remindAt,
    String? repeat,
    bool? done,
    DateTime? createdAt,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      note: note ?? this.note,
      kind: kind ?? this.kind,
      dueAt: dueAt ?? this.dueAt,
      endAt: endAt ?? this.endAt,
      remindAt: remindAt ?? this.remindAt,
      repeat: repeat ?? this.repeat,
      done: done ?? this.done,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, Object?> toRow() {
    String? iso(DateTime? d) => d?.toIso8601String();
    return {
      'id': id,
      'title': title,
      'note': note,
      'kind': kind,
      'due_at': iso(dueAt),
      'end_at': iso(endAt),
      'remind_at': iso(remindAt),
      'repeat': repeat,
      'done': done ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Task.fromRow(Map<String, Object?> row) {
    DateTime? dt(String? s) => s == null ? null : DateTime.tryParse(s);
    return Task(
      id: row['id'] as int?,
      title: row['title'] as String? ?? '',
      note: row['note'] as String? ?? '',
      kind: row['kind'] as String? ?? 'task',
      dueAt: dt(row['due_at'] as String?),
      endAt: dt(row['end_at'] as String?),
      remindAt: dt(row['remind_at'] as String?),
      repeat: row['repeat'] as String?,
      done: (row['done'] as int? ?? 0) == 1,
      createdAt: dt(row['created_at'] as String?) ?? DateTime.now(),
    );
  }
}
