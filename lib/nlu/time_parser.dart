/// 中文时间/日期表达式解析（纯 Dart，可单测）。
///
/// 支持：今天/明天/后天/大后天/今晚/明早/明晚、周X/下周X/下下周X/每周X/每天/工作日、
/// X年X月X日(号)、X日(号)、凌晨/早上/上午/中午/下午/傍晚/晚上 + X点[半/X分]、
/// X:Y、N小时后/N分钟后/半小时后，以及日程结束时间「到X点」。
///
/// 解析不会失败：没有任何时间表达时 [TimeParseResult.start] 为 null，
/// [TimeParseResult.rest] 返回剔除时间表达后的剩余文本，供标题提取。
library;

class TimeParseResult {
  final DateTime? start;
  final DateTime? end;

  /// null | daily | weekday | weekly:N（N: 1=周一 … 7=周日）
  final String? repeat;

  /// 是否解析出具体时刻（含相对时间）。
  final bool hasTime;

  /// 是否显式提到日期（今天/明天/周X/X月X日等）。
  final bool explicitDate;

  /// 原句剔除时间表达后的剩余文本。
  final String rest;

  const TimeParseResult({
    this.start,
    this.end,
    this.repeat,
    this.hasTime = false,
    this.explicitDate = false,
    this.rest = '',
  });
}

class TimeParser {
  static const _digitChars = '0-9一二两三四五六七八九十';
  static final _num = '[$_digitChars]{1,3}';

  static TimeParseResult parse(String input, {DateTime? now}) {
    final n = now ?? DateTime.now();
    var work = input;

    DateTime? date;
    var dateExplicit = false;
    var fromWeekday = false;
    var preferEvening = false;
    int? hour;
    int? minute;
    int? defaultHour;
    int? endHour;
    int? endMinute;
    String? repeat;
    var hasTime = false;
    Duration? relative;

    Match? m;

    // —— 重复规则（先于普通周X，避免“每周一”被当普通周X）——
    m = RegExp(r'每\s*[个]?\s*(?:天|日)').firstMatch(work);
    if (m != null) {
      repeat = 'daily';
      work = _nullify(work, m);
    }
    m = RegExp(r'每\s*[个]?\s*(?:星期|礼拜|周)\s*([一二三四五六日天])').firstMatch(work);
    if (m != null && repeat == null) {
      repeat = 'weekly:${_weekdayOf(m.group(1)!)}';
      work = _nullify(work, m);
    }
    if (repeat == null) {
      m = RegExp(r'工作日').firstMatch(work);
      if (m != null) {
        repeat = 'weekday';
        work = _nullify(work, m);
      }
    }

    // —— 相对时间 ——
    m = RegExp('($_num|半)\\s*个?\\s*(小时|分钟)\\s*(?:之|以)?后').firstMatch(work);
    if (m != null) {
      final raw = m.group(1)!;
      final v = raw == '半' ? null : _cn(raw);
      final isHour = m.group(2) == '小时';
      relative = Duration(minutes: v == null ? (isHour ? 30 : 1) : (isHour ? v * 60 : v));
      hasTime = true;
      work = _nullify(work, m);
    }

    // —— 日期词 ——
    const dayWords = <String, int>{'大后天': 3, '后天': 2, '明天': 1, '明日': 1, '今天': 0, '今日': 0};
    for (final w in dayWords.keys) {
      m = RegExp(RegExp.escape(w)).firstMatch(work);
      if (m != null) {
        date = DateTime(n.year, n.month, n.day).add(Duration(days: dayWords[w]!));
        dateExplicit = true;
        work = _nullify(work, m);
        break;
      }
    }
    // 今晚/明晚/明早：日期 + 默认时刻（若后面还有显式时刻则覆盖）
    const eveningWords = <String, List<int>>{'今晚': [0, 20], '明晚': [1, 20], '明早': [1, 8]};
    for (final w in eveningWords.keys) {
      m = RegExp(RegExp.escape(w)).firstMatch(work);
      if (m != null) {
        date = DateTime(n.year, n.month, n.day).add(Duration(days: eveningWords[w]![0]));
        defaultHour = eveningWords[w]![1];
        preferEvening = w != '明早';
        dateExplicit = true;
        work = _nullify(work, m);
        break;
      }
    }

    // —— 周X ——
    m = RegExp(r'(下下|下|这|本)?\s*(?:星期|礼拜|周)\s*([一二三四五六日天])').firstMatch(work);
    if (m != null) {
      final target = _weekdayOf(m.group(2)!);
      var delta = (target - n.weekday) % 7;
      if (delta < 0) delta += 7;
      final prefix = m.group(1);
      if (prefix == '下') {
        delta = delta == 0 ? 7 : delta;
      } else if (prefix == '下下') {
        delta = delta == 0 ? 14 : delta + 7;
      }
      date = DateTime(n.year, n.month, n.day).add(Duration(days: delta));
      dateExplicit = true;
      fromWeekday = prefix == null || prefix == '这' || prefix == '本';
      work = _nullify(work, m);
    }

    // —— X年X月X日 / X月X号 / X号 ——
    m = RegExp('([0-9]{4})\\s*年\\s*($_num)\\s*月\\s*($_num)\\s*[日号]').firstMatch(work);
    if (m != null) {
      final y = int.tryParse(m.group(1)!) ?? n.year;
      final mo = _cn(m.group(2)!);
      final d = _cn(m.group(3)!);
      if (mo != null && d != null && mo >= 1 && mo <= 12 && d >= 1 && d <= 31) {
        date = DateTime(y, mo, d);
        dateExplicit = true;
        work = _nullify(work, m);
      }
    }
    if (!dateExplicit) {
      m = RegExp('($_num)\\s*月\\s*($_num)\\s*[日号]').firstMatch(work);
      if (m != null) {
        final mo = _cn(m.group(1)!);
        final d = _cn(m.group(2)!);
        if (mo != null && d != null && mo >= 1 && mo <= 12 && d >= 1 && d <= 31) {
          date = DateTime(n.year, mo, d);
          if (date.isBefore(DateTime(n.year, n.month, n.day))) {
            date = DateTime(n.year, mo + 1, d); // 已过 → 下月（DateTime 自动进位年份）
          }
          dateExplicit = true;
          work = _nullify(work, m);
        }
      }
    }
    if (!dateExplicit) {
      m = RegExp('($_num)\\s*[日号]').firstMatch(work);
      if (m != null) {
        final d = _cn(m.group(1)!);
        if (d != null && d >= 1 && d <= 31) {
          date = DateTime(n.year, n.month, d);
          if (date.isBefore(DateTime(n.year, n.month, n.day))) {
            date = DateTime(n.year, n.month + 1, d);
          }
          dateExplicit = true;
          work = _nullify(work, m);
        }
      }
    }

    // —— 带时段前缀的时刻 ——
    const qual = '(凌晨|清晨|早上|上午|中午|午后|下午|傍晚|晚上|夜里)';
    m = RegExp('$qual\\s*(?:($_num)\\s*[点时:：]\\s*)?(半|($_num)\\s*分?)?').firstMatch(work);
    if (m != null) {
      hour = _qualifiedHour(m.group(1)!, m.group(2));
      minute = _minuteOf(m.group(3) ?? '');
      hasTime = true;
      work = _nullify(work, m);
    }

    // —— 结束时间：到/至 X点 ——
    m = RegExp(r'(?:到|至|直到|开到)\s*(?:凌晨|清晨|早上|上午|中午|午后|下午|傍晚|晚上|夜里)?\s*(' +
            _num +
            r')\s*[点时:：]\s*(半|(' +
            _num +
            r')\s*分?)?')
        .firstMatch(work);
    if (m != null) {
      final eh = _cn(m.group(1)!);
      if (eh != null) {
        var h = eh;
        if (hour != null && h < hour) h += 12;
        endHour = h;
        endMinute = _minuteOf(m.group(2) ?? '');
        work = _nullify(work, m);
      }
    }

    // —— 24 小时制 X:Y ——
    if (!hasTime) {
      m = RegExp(r'([0-9]{1,2})\s*[:：]\s*([0-9]{2})').firstMatch(work);
      if (m != null) {
        final h = int.tryParse(m.group(1)!);
        final mi = int.tryParse(m.group(2)!);
        if (h != null && mi != null && h <= 24 && mi <= 59) {
          hour = h == 24 ? 0 : h;
          minute = mi;
          hasTime = true;
          work = _nullify(work, m);
        }
      }
    }

    // —— 裸时刻 X点(半) ——
    if (!hasTime) {
      m = RegExp('($_num)\\s*[点时]\\s*(半|($_num)\\s*分?)?').firstMatch(work);
      if (m != null) {
        final raw = _cn(m.group(1)!);
        if (raw != null && raw >= 0 && raw <= 24) {
          var h = raw == 24 ? 0 : raw;
          if (h >= 1 && h <= 6) h += 12; // “3点”默认下午
          if (preferEvening && h >= 5 && h <= 11) h += 12; // “今晚8点”
          hour = h;
          minute = _minuteOf(m.group(2) ?? '');
          hasTime = true;
          work = _nullify(work, m);
        }
      }
    }

    // —— 组装 ——
    final effHour = hour ?? defaultHour ?? (repeat != null ? 8 : null);
    if (relative != null) {
      // 相对时间直接用
    } else if (repeat == 'daily' && date == null) {
      date = DateTime(n.year, n.month, n.day).add(const Duration(days: 1));
    } else if (repeat != null && repeat.startsWith('weekly:') && date == null) {
      final target = int.parse(repeat.split(':')[1]);
      var delta = (target - n.weekday) % 7;
      if (delta < 0) delta += 7;
      date = DateTime(n.year, n.month, n.day).add(Duration(days: delta));
      fromWeekday = true;
    }

    DateTime? start;
    if (relative != null) {
      start = n.add(relative);
    } else if (date != null) {
      start = DateTime(date.year, date.month, date.day, effHour ?? 9, minute ?? 0);
    } else if (effHour != null) {
      start = DateTime(n.year, n.month, n.day, effHour, minute ?? 0);
      if (!start.isAfter(n)) {
        start = start.add(const Duration(days: 1)); // 只说时刻且已过 → 明天
      }
    }
    if (start != null && relative == null && fromWeekday && start.isBefore(n)) {
      start = start.add(const Duration(days: 7)); // “周一”且已过 → 下周一
    }

    DateTime? end;
    if (endHour != null && start != null) {
      end = DateTime(start.year, start.month, start.day, endHour, endMinute ?? 0);
      if (!end.isAfter(start)) {
        end = start.add(const Duration(hours: 1));
      }
    }

    final rest = work.replaceAll('\x00', '').replaceAll(RegExp(r'\s+'), ' ').trim();
    return TimeParseResult(
      start: start,
      end: end,
      repeat: repeat,
      hasTime: hasTime || defaultHour != null,
      explicitDate: dateExplicit,
      rest: rest,
    );
  }

  /// 将匹配区间替换为等长空字符，保持后续正则的偏移量稳定。
  static String _nullify(String s, Match m) =>
      s.replaceRange(m.start, m.end, '\x00' * (m.end - m.start));

  static int _weekdayOf(String ch) =>
      const {'一': 1, '二': 2, '三': 3, '四': 4, '五': 5, '六': 6, '日': 7, '天': 7}[ch] ?? 1;

  /// 中文/阿拉伯数字 → int（支持 一~九十九）。
  static int? _cn(String s) {
    final t = s.trim();
    if (t.isEmpty) return null;
    final digits = t.replaceAll(RegExp('[^0-9]'), '');
    if (digits.isNotEmpty) return int.tryParse(digits);
    const d = {'零': 0, '一': 1, '二': 2, '两': 2, '三': 3, '四': 4, '五': 5, '六': 6, '七': 7, '八': 8, '九': 9};
    if (t == '十') return 10;
    if (t.contains('十')) {
      final i = t.indexOf('十');
      final head = i == 0 ? 1 : (d[t.substring(0, i)] ?? -1);
      final tailStr = t.substring(i + 1);
      final tail = tailStr.isEmpty ? 0 : (d[tailStr] ?? -1);
      if (head < 0 || tail < 0) return null;
      return head * 10 + tail;
    }
    if (t.length == 1) return d[t];
    return null;
  }

  static int? _minuteOf(String g) {
    final t = g.trim().replaceAll('分', '').trim();
    if (t.isEmpty) return 0;
    if (t == '半') return 30;
    final v = _cn(t);
    if (v == null) return 0;
    return v <= 59 ? v : 0;
  }

  static int _qualifiedHour(String q, String? numStr) {
    final h = numStr == null ? null : _cn(numStr);
    switch (q) {
      case '凌晨':
        return h ?? 1;
      case '清晨':
      case '早上':
      case '上午':
        if (h == null) return 8;
        return h == 12 ? 0 : h;
      case '中午':
        return h ?? 12;
      case '午后':
      case '下午':
        if (h == null) return 14;
        return h < 12 ? h + 12 : h;
      case '傍晚':
        if (h == null) return 18;
        return h < 12 ? h + 12 : h;
      default: // 晚上/夜里
        if (h == null) return 20;
        return h < 12 ? h + 12 : h;
    }
  }
}
