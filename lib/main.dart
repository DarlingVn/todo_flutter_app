import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'core/theme_provider.dart';
import 'presentation/screens/auth_wrapper.dart';
import 'firebase_options.dart';
import 'data/services/notification_service.dart';
import 'data/services/task_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // Initialize notifications
  await NotificationService().initNotifications();
  // Enable offline persistence
  await TaskService().enableOfflinePersistence();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: Consumer<ThemeProvider>(
        builder: (context, theme, _) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData.light(),
            darkTheme: ThemeData.dark(),
            themeMode: theme.isDark ? ThemeMode.dark : ThemeMode.light,
            home: AuthWrapper(),
          );
        },
      ),
    );
  }
}