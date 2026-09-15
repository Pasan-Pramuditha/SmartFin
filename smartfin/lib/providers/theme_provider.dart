import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  static const String themeKey = "theme_mode";
  static const String alertsKey = "spending_alerts";
  
  ThemeMode _themeMode = ThemeMode.dark;
  bool _spendingAlerts = true;

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;
  bool get spendingAlerts => _spendingAlerts;

  ThemeProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Load Theme
    final String? savedTheme = prefs.getString(themeKey);
    if (savedTheme == 'light') {
      _themeMode = ThemeMode.light;
    } else if (savedTheme == 'dark') {
      _themeMode = ThemeMode.dark;
    } else {
      _themeMode = ThemeMode.dark;
    }

    // Load Alerts
    _spendingAlerts = prefs.getBool(alertsKey) ?? true;
    
    notifyListeners();
  }

  Future<void> toggleTheme(bool isDark) async {
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(themeKey, isDark ? 'dark' : 'light');
  }

  Future<void> toggleSpendingAlerts(bool value) async {
    _spendingAlerts = value;
    notifyListeners();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(alertsKey, value);
  }
}
