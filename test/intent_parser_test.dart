import 'package:flutter_test/flutter_test.dart';

import 'package:voice_todo/nlu/intent.dart';
import 'package:voice_todo/nlu/intent_parser.dart';

void main() {
  final now = DateTime(2026, 10, 24, 14, 0);

  ParsedIntent parse(String text) => IntentParser.parse(text, now: now);

  group('IntentParser 建待办', () {
    test('带时间提醒', () {
      final i = parse('明天下午三点提醒我开会');
      expect(i.type, IntentType.addTask);
      expect(i.title, '开会');
      expect(i.time, DateTime(2026, 10, 25, 15, 0));
    });
    test('每日重复', () {
      final i = parse('每天早上八点提醒我吃药');
      expect(i.type, IntentType.addTask);
      expect(i.title, '吃药');
      expect(i.repeat, 'daily');
    });
    test('兜底：无关键词直接说事', () {
      final i = parse('买牛奶');
      expect(i.type, IntentType.addTask);
      expect(i.title, '买牛奶');
      expect(i.time, isNull);
    });
    test('提醒前缀 + 日期', () {
      final i = parse('帮我提醒明天买牛奶');
      expect(i.type, IntentType.addTask);
      expect(i.title, '买牛奶');
      expect(i.time, DateTime(2026, 10, 25, 9, 0));
    });
  });

  group('IntentParser 闹钟', () {
    test('设闹钟', () {
      final i = parse('设个明早七点的闹钟');
      expect(i.type, IntentType.setAlarm);
      expect(i.time, DateTime(2026, 10, 25, 7, 0));
      expect(i.title, isNotEmpty);
    });
    test('无法删除系统闹钟 → unknown + 提示', () {
      final i = parse('关闭闹钟');
      expect(i.type, IntentType.unknown);
      expect(i.hint, isNotNull);
    });
    test('闹钟缺时间 → unknown + 提示', () {
      final i = parse('上个闹钟');
      expect(i.type, IntentType.unknown);
      expect(i.hint, isNotNull);
    });
  });

  group('IntentParser 日程', () {
    test('带起止时间', () {
      final i = parse('10月28号下午和客户开会到四点');
      expect(i.type, IntentType.addEvent);
      expect(i.title, '和客户开会');
      expect(i.time, DateTime(2026, 10, 28, 14, 0));
      expect(i.endTime, DateTime(2026, 10, 28, 16, 0));
    });
    test('会议无时间 → unknown + 提示', () {
      final i = parse('和客户开会');
      expect(i.type, IntentType.unknown);
      expect(i.hint, isNotNull);
    });
  });

  group('IntentParser 完成/删除', () {
    test('完成X', () {
      final i = parse('完成买牛奶');
      expect(i.type, IntentType.completeTask);
      expect(i.title, '买牛奶');
    });
    test('把X完成了', () {
      final i = parse('把买牛奶完成了');
      expect(i.type, IntentType.completeTask);
      expect(i.title, '买牛奶');
    });
    test('删掉X', () {
      final i = parse('删掉买牛奶');
      expect(i.type, IntentType.deleteTask);
      expect(i.title, '买牛奶');
    });
  });

  group('IntentParser 查询', () {
    test('今天有什么安排', () {
      final i = parse('今天有什么安排');
      expect(i.type, IntentType.query);
      expect(i.time, DateTime(2026, 10, 24));
    });
    test('看看明天任务', () {
      final i = parse('看看明天的任务');
      expect(i.type, IntentType.query);
      expect(i.time, DateTime(2026, 10, 25));
    });
  });

  group('IntentParser 未识别', () {
    test('空泛内容 → unknown', () {
      final i = parse('嗯嗯啊啊');
      expect(i.type, IntentType.unknown);
      expect(i.hint, isNotNull);
    });
  });

  group('展示辅助', () {
    test('intentLabel', () {
      expect(intentLabel(IntentType.addTask), '待办');
      expect(intentLabel(IntentType.setAlarm), '闹钟');
    });
    test('repeatLabel', () {
      expect(repeatLabel('daily'), '每天');
      expect(repeatLabel('weekly:1'), '每周一');
      expect(repeatLabel('weekly:7'), '每周日');
    });
    test('fmtTime', () {
      expect(fmtTime(DateTime(2026, 11, 1, 9, 5)), '11月1日 09:05');
    });
  });
}
