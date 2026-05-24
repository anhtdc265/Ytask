import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'firebase_options.dart';
import 'package:todo_app/features/auth/login_screen.dart';
import 'package:todo_app/features/dashboard/dashboard_screen.dart';
import 'package:todo_app/features/progress/progress_screen.dart';
import 'package:todo_app/features/profile/profile_screen.dart';
import 'package:todo_app/features/chatbot/chatbot_screen.dart';
import 'package:todo_app/services/theme_service.dart';
import 'package:todo_app/services/notification_service.dart';
import 'package:todo_app/core/navigation/app_navigator.dart';
import 'package:todo_app/core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await NotificationService.instance.init();

  final themeService = ThemeService();
  await themeService.init();

  runApp(const YTask());
}

class YTask extends StatelessWidget {
  const YTask({super.key});

  @override
  Widget build(BuildContext context) {
    final themeService = ThemeService();

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeService.themeNotifier,
      builder: (context, currentMode, _) {
        return MaterialApp(
          navigatorKey: AppNavigator.navigatorKey,
          debugShowCheckedModeBanner: false,
          title: 'YTask',
          themeMode: currentMode,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          routes: {
            '/dashboard': (context) => const DashboardScreen(),
            '/progress': (context) => const ProgressScreen(),
            '/profile': (context) => const ProfileScreen(),
            '/chatbot': (context) => const ChatbotScreen(),
          },
          home: StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF63D64E),
                    ),
                  ),
                );
              }

              if (snapshot.hasData && snapshot.data != null) {
                return const DashboardScreen();
              }

              return const LoginScreen();
            },
          ),
        );
      },
    );
  }
}
