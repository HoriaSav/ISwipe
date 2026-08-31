import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/app_services.dart';
import 'providers/deletion_events.dart';
import 'screens/main_shell.dart';
import 'services/database_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseService.instance.database;
  runApp(const ISwipeApp());
}

class ISwipeApp extends StatelessWidget {
  const ISwipeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => DeletionEvents()),
        ChangeNotifierProxyProvider<DeletionEvents, AppServices>(
          create: (context) =>
              AppServices(context.read<DeletionEvents>())..initialize(),
          update: (_, events, services) => services!,
        ),
      ],
      child: MaterialApp(
        title: 'ISwipe',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.system,
        home: const MainShell(),
      ),
    );
  }
}
