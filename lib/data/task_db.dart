import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/task.dart';

/// 本地任务存储（单表）。
class TaskDb {
  Database? _db;

  Future<Database> get _database async {
    return _db ??= await openDatabase(
      join(await getDatabasesPath(), 'voice_todo.db'),
      version: 1,
      onCreate: (d, version) {
        return d.execute('''
          CREATE TABLE tasks(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            note TEXT NOT NULL DEFAULT '',
            kind TEXT NOT NULL DEFAULT 'task',
            due_at TEXT,
            end_at TEXT,
            remind_at TEXT,
            repeat TEXT,
            done INTEGER NOT NULL DEFAULT 0,
            created_at TEXT NOT NULL
          )
        ''');
      },
    );
  }

  Future<int> insert(Task t) async {
    final d = await _database;
    return d.insert('tasks', t.toRow()..remove('id'));
  }

  Future<void> updateDone(int id, bool done) async {
    final d = await _database;
    await d.update('tasks', {'done': done ? 1 : 0},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<void> delete(int id) async {
    final d = await _database;
    await d.delete('tasks', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Task>> all() async {
    final d = await _database;
    final rows = await d.query(
      'tasks',
      orderBy: 'done ASC, due_at IS NULL ASC, due_at ASC, created_at DESC',
    );
    return rows.map(Task.fromRow).toList();
  }
}
