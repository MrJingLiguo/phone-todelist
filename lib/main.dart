import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'data/task_db.dart';
import 'executors/executor.dart';
import 'platform/alarm_channel.dart';
import 'state/app_state.dart';
import 'ui/home_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = TaskDb();
  final state = AppState(
    db: db,
    executor: Executor(db, ReminderService(), CalendarService(), const AlarmChannel()),
  );
  await state.init();
  runApp(
    MultiProvider(
      providers: [ChangeNotifierProvider.value(value: state)],
      child: const VoiceTodoApp(),
    ),
  );
}

class VoiceTodoApp extends StatelessWidget {
  const VoiceTodoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '语音待办',
      theme: ThemeData(colorSchemeSeed: const Color(0xFF00897B)),
      locale: const Locale('zh'),
      supportedLocales: const [Locale('zh'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const HomePage(),
    );
  }
}
