import 'intent.dart';
import 'time_parser.dart';

/// 规则引擎：语音文本 → 意图。
///
/// 优先级：闹钟 → 完成 → 删除 → 查询 → 提醒类待办 → 日程类 → 兜底待办。
/// 「提醒我开会」命中提醒词走待办；「和客户开会」没有提醒词、命中会议词走日历日程。
class IntentParser {
  static final _alarmWord = RegExp(r'闹钟|闹铃');
  static final _deleteCmd = RegExp(r'删掉|删除|去掉|移除|取消|关掉|关闭');
  static final _completePre = RegExp(
      r'^(?:把|将)?\s*(.+?)\s*(?:给)?(?:完成|做完|办完|搞定|处理完|打勾|勾掉)\s*了?[。，,.!！?？\s]*$');
  static final _completePost = RegExp(
      r'^(?:完成|做完|办完|搞定|处理完|打勾|勾掉)(?:一下|掉)?\s*(.+?)\s*了?[。，,.!！?？\s]*$');
  static final _deletePre = RegExp(
      r'^(?:把|将)?\s*(.+?)\s*(?:给)?(?:删掉|删除|去掉|移除|取消)\s*[了吧]?\s*[。，,.!！?？\s]*$');
  static final _deletePost = RegExp(
      r'^(?:删掉|删除|去掉|移除|取消)(?:一下|掉)?\s*(.+?)\s*[了吧]?\s*[。，,.!！?？\s]*$');
  static final _queryRe = RegExp(
      r'(?:看一?看|查看|列出|显示)[\s\S]{0,6}(?:任务|安排|待办|日程)|(?:有什么|有哪些|啥)[\s\S]{0,4}(?:安排|任务|事|待办)|今天[\s\S]{0,4}(?:干嘛|做啥|干什么)');
  static final _taskWord = RegExp(r'提醒|记得|待办|事项|任务');
  static final _eventWord =
      RegExp(r'日程|日历|会议|开会|约会|见面|碰头|聚餐|面试|出差|航班|火车|挂号|看诊|考试|门诊');
  static final _prefixFiller = RegExp(
      r'^(?:帮我|麻烦|请|我要|我想|给我|先|再|劳驾)*(?:提醒我?|记得|设置?个?|设定?个?|定个?|设个?|建个?|创建|新增|添加|新建|加个?|安排个?|记录|记个?|写个?|上?个?|弄个?)*\s*');
  static final _suffixFiller = RegExp(
      r'\s*(?:的?(?:任务|事项|待办|日程|提醒|闹钟|闹铃))*(?:吧|啊|哦|呀|哈|呗|啦|了)*[。，,.!！?？]*$');

  static ParsedIntent parse(String raw, {DateTime? now}) {
    final text = raw.trim();
    final tp = TimeParser.parse(text, now: now);
    final title = _cleanTitle(tp.rest.isEmpty ? text : tp.rest);

    // 1) 闹钟
    if (_alarmWord.hasMatch(text)) {
      if (_deleteCmd.hasMatch(text)) {
        return const ParsedIntent(
            type: IntentType.unknown,
            hint: '系统时钟的闹钟只能新增，无法语音删除，请到时钟 App 手动操作');
      }
      if (tp.start == null) {
        return const ParsedIntent(
            type: IntentType.unknown, hint: '没听出闹钟时间，试试：“设个明早七点的闹钟”');
      }
      final t = title.isEmpty
          ? '闹钟 ${two(tp.start.hour)}:${two(tp.start.minute)}'
          : title;
      return ParsedIntent(
          type: IntentType.setAlarm,
          title: t,
          time: tp.start,
          repeat: tp.repeat,
          raw: text);
    }

    // 2) 完成
    final cm = _completePre.firstMatch(text) ?? _completePost.firstMatch(text);
    if (cm != null) {
      if (_alarmWord.hasMatch(text)) {
        return const ParsedIntent(
            type: IntentType.unknown, hint: '系统闹钟无法语音完成，请手动处理');
      }
      final key = _cleanTitle(cm.group(1) ?? '');
      if (key.isNotEmpty) {
        return ParsedIntent(type: IntentType.completeTask, title: key, raw: text);
      }
    }

    // 3) 删除
    final dm = _deletePre.firstMatch(text) ?? _deletePost.firstMatch(text);
    if (dm != null) {
      if (_alarmWord.hasMatch(text)) {
        return const ParsedIntent(
            type: IntentType.unknown,
            hint: '系统时钟的闹钟只能新增，无法语音删除，请到时钟 App 手动操作');
      }
      final key = _cleanTitle(dm.group(1) ?? '');
      if (key.isNotEmpty) {
        return ParsedIntent(type: IntentType.deleteTask, title: key, raw: text);
      }
    }

    // 4) 查询
    if (_queryRe.hasMatch(text)) {
      final d = tp.start;
      final day = d == null ? null : DateTime(d.year, d.month, d.day);
      return ParsedIntent(type: IntentType.query, time: day, raw: text);
    }

    // 5) 提醒类待办
    if (_taskWord.hasMatch(text)) {
      if (title.isEmpty) {
        return const ParsedIntent(
            type: IntentType.unknown, hint: '没听清内容，试试：“明天下午三点提醒我开会”');
      }
      return ParsedIntent(
          type: IntentType.addTask,
          title: title,
          time: tp.start,
          repeat: tp.repeat,
          raw: text);
    }

    // 6) 日程类
    if (_eventWord.hasMatch(text)) {
      if (tp.start == null) {
        return const ParsedIntent(
            type: IntentType.unknown, hint: '请带上时间，例如：“明天下午三点开项目会”');
      }
      return ParsedIntent(
          type: IntentType.addEvent,
          title: title.isEmpty ? '日程' : title,
          time: tp.start,
          endTime: tp.end,
          raw: text);
    }

    // 7) 兜底：普通待办
    if (title.isNotEmpty) {
      return ParsedIntent(
          type: IntentType.addTask,
          title: title,
          time: tp.start,
          repeat: tp.repeat,
          raw: text);
    }
    return const ParsedIntent(
        type: IntentType.unknown, hint: '没听懂，试试：“明天下午三点提醒我开会”');
  }

  static String _cleanTitle(String s) {
    var t = s.trim();
    t = t.replaceAll(_prefixFiller, '');
    t = t.replaceAll(_suffixFiller, '');
    return t.trim();
  }
}
