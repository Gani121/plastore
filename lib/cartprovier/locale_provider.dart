import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleProvider with ChangeNotifier {
  Locale? _locale;
  Locale? get locale => _locale;

  LocaleProvider() {
    _loadSavedLocale(); // Load the language when the app starts
  }

  // Get the saved language from SharedPreferences
  void _loadSavedLocale() async {
    final prefs = await SharedPreferences.getInstance();
    // Get the saved language code (e.g., 'mr', 'hi', 'en')
    String? languageCode = prefs.getString('languageCode');

    if (languageCode != null) {
      _locale = Locale(languageCode);
      notifyListeners();
    }
  }

  // Set and save the new language
  void setLocale(Locale newLocale) async {
    _locale = newLocale;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    // Save the new language code
    await prefs.setString('languageCode', newLocale.languageCode);
  }
}