import 'package:flutter_test/flutter_test.dart';

import 'package:voice_todo/nlu/time_parser.dart';

void main() {
  // 2026-10-24 是周六，14:00
  final now = DateTime(2026, 10, 24, 14, 0);

  DateTime? start(String text) => TimeParser.parse(text, now: now).start;

  group('TimeParser 相对时间', () {
    test('半小时后', () {
      expect(start('半小时后提醒我'), DateTime(2026, 10, 24, 14, 30));
    });
    test('两小时后', () {
      expect(start('两小时后叫我'), DateTime(2026, 10, 24, 16, 0));
    });
    test('20分钟后', () {
      expect(start('20分钟后'), DateTime(2026, 10, 24, 14, 20));
    });
  });

  group('TimeParser 日期词', () {
    test('明天 + 下午三点', () {
      expect(start('明天下午三点提醒我开会'), DateTime(2026, 10, 25, 15, 0));
    });
    test('今天只有日期 → 默认 9 点且不回滚', () {
      expect(start('今天交报告'), DateTime(2026, 10, 24, 9, 0));
    });
    test('后天中午十二点', () {
      expect(start('后天中午十二点吃饭'), DateTime(2026, 10, 26, 12, 0));
    });
    test('大后天', () {
      expect(start('大后天出门'), DateTime(2026, 10, 27, 9, 0));
    });
  });

  group('TimeParser 周X', () {
    test('周一（本周已过 → 下周一）', () {
      // 10-24 是周六，下一个周一是 10-26
      expect(start('周一开周会'), DateTime(2026, 10, 26, 9, 0));
    });
    test('下周三', () {
      expect(start('下周三体检'), DateTime(2026, 10, 28, 9, 0));
    });
  });

  group('TimeParser 月日', () {
    test('10月28号 + 时段默认 + 结束时间', () {
      final r = TimeParser.parse('10月28号下午和客户开会到四点', now: now);
      expect(r.start, DateTime(2026, 10, 28, 14, 0));
      expect(r.end, DateTime(2026, 10, 28, 16, 0));
    });
    test('本月已过的日子 → 下个月', () {
      expect(start('12号发工资'), DateTime(2026, 11, 12, 9, 0));
    });
  });

  group('TimeParser 时刻', () {
    test('24小时制', () {
      expect(start('15:30开会'), DateTime(2026, 10, 24, 15, 30));
    });
    test('裸时刻 3点 → 默认下午', () {
      expect(start('3点取快递'), DateTime(2026, 10, 24, 15, 0));
    });
    test('晚上九点', () {
      expect(start('晚上九点吃药'), DateTime(2026, 10, 24, 21, 0));
    });
    test('今晚八点半', () {
      expect(start('今晚八点半散步'), DateTime(2026, 10, 24, 20, 30));
    });
    test('只说时刻且已过 → 明天', () {
      // 10 点在 14:00 之前已过
      expect(start('10点开会'), DateTime(2026, 10, 25, 10, 0));
    });
  });

  group('TimeParser 重复', () {
    test('每天 + 早上八点 → 明天开始', () {
      final r = TimeParser.parse('每天早上八点提醒我吃药', now: now);
      expect(r.repeat, 'daily');
      expect(r.start, DateTime(2026, 10, 25, 8, 0));
    });
    test('每周一', () {
      final r = TimeParser.parse('每周一交周报', now: now);
      expect(r.repeat, 'weekly:1');
      expect(r.start, DateTime(2026, 10, 26, 8, 0));
    });
    test('工作日', () {
      final r = TimeParser.parse('工作日早上七点起床', now: now);
      expect(r.repeat, 'weekday');
      expect(r.start, DateTime(2026, 10, 25, 7, 0));
    });
  });

  group('TimeParser 明早/今晚', () {
    test('明早七点（显式时刻覆盖默认 8 点）', () {
      expect(start('明早七点跑步'), DateTime(2026, 10, 25, 7, 0));
    });
    test('明早不带时刻 → 默认 8 点', () {
      expect(start('明早出发'), DateTime(2026, 10, 25, 8, 0));
    });
    test('今晚八点（晚上语义）', () {
      expect(start('今晚八点看直播'), DateTime(2026, 10, 24, 20, 0));
    });
  });

  group('TimeParser 无时间 / 剩余文本', () {
    test('没有时间表达 → start 为 null', () {
      final r = TimeParser.parse('买牛奶', now: now);
      expect(r.start, isNull);
      expect(r.rest, '买牛奶');
    });
    test('rest 剔除时间表达', () {
      expect(TimeParser.parse('明天下午三点提醒我开会', now: now).rest, '提醒我开会');
    });
  });
}
