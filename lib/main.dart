import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'services/audio_player_service.dart';
import 'services/memory_manager.dart';
import 'services/messenger_store.dart';
import 'services/notification_service.dart';
import 'services/theme_manager.dart';
import 'ui/views/main_desktop_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Enforce RAM optimization limits (150-200 MB max)
  MemoryManager.instance.init();

  // Mount UI immediately for near-instant window display
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: ThemeManager.instance),
        ChangeNotifierProvider.value(value: MessengerStore.instance),
        ChangeNotifierProvider.value(value: AudioPlayerService.instance),
        ChangeNotifierProvider.value(value: NotificationService.instance),
      ],
      child: const OpenVKApp(),
    ),
  );

  // Background non-blocking warmups
  initializeDateFormatting('ru', null);
  NotificationService.instance.init();
  MessengerStore.instance.init();
}

class OpenVKApp extends StatelessWidget {
  const OpenVKApp({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeManager>();
    final isDark = theme.isDark(context);

    return MaterialApp(
      title: 'OpenVK Messenger',
      debugShowCheckedModeBanner: false,
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFEBEDF0),
        primaryColor: theme.accentColor,
        colorScheme: ColorScheme.light(
          primary: theme.accentColor,
          surface: Colors.white,
        ),
        fontFamily: Platform.isWindows ? 'Segoe UI' : (Platform.isLinux ? 'Ubuntu' : null),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF19191A),
        primaryColor: theme.accentColor,
        colorScheme: ColorScheme.dark(
          primary: theme.accentColor,
          surface: const Color(0xFF222223),
        ),
        fontFamily: Platform.isWindows ? 'Segoe UI' : (Platform.isLinux ? 'Ubuntu' : null),
        useMaterial3: true,
      ),
      home: const MainDesktopView(),
    );
  }
}
