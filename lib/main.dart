import 'package:flutter/material.dart';
import 'package:picdb/screens/dashboard.dart';
import 'package:picdb/screens/onboarding.dart';
import 'package:picdb/screens/splash.dart';
import 'package:picdb/screens/upload.dart';
import 'package:picdb/screens/group_chat_screen.dart';
import 'package:picdb/services/notify_service.dart';
import 'package:picdb/services/theme_notifier.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize notifications
  final notifyService = NotifyService();
  await notifyService.initNotification();

  SharedPreferences prefs = await SharedPreferences.getInstance();
  String? theme = prefs.getString("theme");
  ThemeMode themeMode;
  if (theme == "light") {
    themeMode = ThemeMode.light;
  } else if (theme == "dark") {
    themeMode = ThemeMode.dark;
  } else {
    themeMode = ThemeMode.system;
  }

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeNotifier(themeMode: themeMode),
      child: MyApp(prefs: prefs),
    ),
  );
}

class MyApp extends StatelessWidget {
  final SharedPreferences prefs;
  const MyApp({super.key, required this.prefs});

  @override
  StatelessElement createElement() {
    return super.createElement();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeNotifier>(
      builder: (context, themeNotifier, child) {
        return MaterialApp(
          theme: ThemeData(
            brightness: Brightness.light,
            scaffoldBackgroundColor: Colors.white,
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            scaffoldBackgroundColor: Colors.grey[850],
            useMaterial3: true,
          ),
          themeMode: themeNotifier.themeMode,
          home: const SplashScreen(),
          routes: {
            "/splash": (context) => const SplashScreen(),
            "/onboarding": (context) => const OnboardingScreen(),
            "/upload": (context) => const UploadImage(),
            "/dashboard": (context) => const DashboardScreen(),
          },
          onGenerateRoute: (settings) {
            if (settings.name == GroupChatScreen.routeName) {
              final args = settings.arguments as GroupChatArgs;
              return MaterialPageRoute(
                builder: (context) => GroupChatScreen(args: args),
              );
            }
            return null;
          },
          onUnknownRoute: (settings) {
            return MaterialPageRoute(
              builder: (context) => const SplashScreen(),
            );
          },
        );
      },
    );
  }
}