import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeNotifier with ChangeNotifier {
  final String key = "theme";
  SharedPreferences? _prefs;
  late ThemeMode _themeMode;

  ThemeMode get themeMode => _themeMode;

  ThemeNotifier({required ThemeMode themeMode}) {
    _themeMode = themeMode;
  }

  toggleTheme(ThemeMode themeMode) {
    _themeMode = themeMode;
    _saveToPrefs();
    notifyListeners();
  }

  _initPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  _loadFromPrefs() async {
    await _initPrefs();
    String? theme = _prefs!.getString(key);
    if (theme == "light") {
      _themeMode = ThemeMode.light;
    } else if (theme == "dark") {
      _themeMode = ThemeMode.dark;
    } else {
      _themeMode = ThemeMode.system;
    }
    notifyListeners();
  }

  _saveToPrefs() async {
    await _initPrefs();
    if (_themeMode == ThemeMode.light) {
      _prefs!.setString(key, "light");
    } else if (_themeMode == ThemeMode.dark) {
      _prefs!.setString(key, "dark");
    } else {
      _prefs!.setString(key, "system");
    }
  }
}
