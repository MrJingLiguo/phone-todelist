import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:voice_todo/nlu/intent.dart';
import 'package:voice_todo/ui/confirm_sheet.dart';

void main() {
  testWidgets('ConfirmSheet 显示识别结果并允许确认', (tester) async {
    final intent = ParsedIntent(
      type: IntentType.addTask,
      title: '开会',
      time: DateTime(2026, 11, 1, 15, 0),
      raw: '明天下午三点提醒我开会',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ConfirmSheet(intent: intent),
        ),
      ),
    );

    expect(find.text('开会'), findsOneWidget);
    expect(find.text('待办'), findsOneWidget);
    expect(find.textContaining('11月1日'), findsOneWidget);
    expect(find.text('确认执行'), findsOneWidget);
  });

  testWidgets('unknown 意图只显示提示，无确认按钮', (tester) async {
    const intent = ParsedIntent(
      type: IntentType.unknown,
      hint: '没听懂，试试：“明天下午三点提醒我开会”',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SizedBox(
              height: 600,
              child: ConfirmSheet(intent: intent),
            ),
          ),
        ),
      ),
    );

    expect(find.text('确认执行'), findsNothing);
    expect(find.textContaining('没听懂'), findsOneWidget);
  });
}
