import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';
import '../services/notify_service.dart';
import '../services/theme_notifier.dart';
import '../widgets/check_connection.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  late SharedPreferences prefs;
  late bool accepted;
  late bool onboardingCompleted;
  late List<String> images;
  final NotifyService _notifyService = NotifyService();

  @override
  void initState() {
    super.initState();
    initPrefs();
    _initializeNotifications();
    Future.delayed(const Duration(seconds: 2), () {
      initAccepted();
      initNotification();
    });
    Future.delayed(const Duration(seconds: 8), () {
      // Re-read prefs to ensure latest values
      onboardingCompleted = prefs.getBool('onboarding_completed') ?? false;
      accepted = prefs.getBool('accepted') ?? false;

      if (onboardingCompleted || accepted) {
        Navigator.pushReplacementNamed(context, '/upload');
      } else {
        Navigator.pushReplacementNamed(context, '/onboarding');
      }
    });
  }

  Future<void> _initializeNotifications() async {
    await _notifyService.initNotification();
  }

  void initAccepted() async {
    accepted = prefs.getBool("accepted") ?? false;
    // Ensure onboarding_completed is set when policies already accepted
    if (accepted) {
      await prefs.setBool('onboarding_completed', true);
    } else {
      // ensure key exists
      await prefs.setBool("accepted", false);
    }
  }

  void initImages() async {
    images = prefs.getStringList("images") ?? [];
    if (images.isEmpty) {
      await prefs.setStringList("images", []);
    }
  }

  void initPrefs() async {
    prefs = await SharedPreferences.getInstance();
    // Initialize onboardingCompleted flag
    onboardingCompleted = prefs.getBool('onboarding_completed') ?? false;
  }

  void initNotification() async {
    if (prefs.get('recent_notify') == null) {
      await prefs.setStringList('recent_notify', []);
    }
    if (prefs.get('recent_notify') is String) {
      await prefs.setStringList('recent_notify', []);
    }

    List<String> recentNotifyId = prefs.getStringList('recent_notify') ?? [];
    try {
      final notification = await APIService().fetchNotify();
      if (notification['success'] == true) {
        final notifications = notification['notifications'] as List;
        for (var notify in notifications) {
          final id = notify['_id'] as String?;
          if (id == null) continue;
          if (!recentNotifyId.contains(id)) {
            await _notifyService.showNotification(
              title: notify['title'],
              body: notify['body'],
              id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
            );
            recentNotifyId.add(id);
            await prefs.setStringList('recent_notify', recentNotifyId);
          }
        }
      }
    } catch (e) {
      print('Error showing notification: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    bool isDarkMode;
    if (themeNotifier.themeMode == ThemeMode.system) {
      isDarkMode = MediaQuery.of(context).platformBrightness == Brightness.dark;
    } else {
      isDarkMode = themeNotifier.themeMode == ThemeMode.dark;
    }

    return ConnectivityWidget(
      child: Scaffold(
        backgroundColor: isDarkMode ? Colors.grey[850] : Colors.white,
        body: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Center(
            child: Column (
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset("assets/logo/app_icon.png"),
                Text(
                  "PicDB",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 50,
                    color: isDarkMode ? Colors.white : Colors.black,
                    fontFamily: 'Vonique',
                  ),
                ),
                Text(
                  "Made with ❤️ by Arkynox",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: isDarkMode ? Colors.white : Colors.black,
                    fontFamily: 'Vonique',
                  ),
                ),
              ]
            ),
          ),
        ),
      ),
    );
  }
}