import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppLanguage {
  tr('tr', 'Türkçe', 'Turkish'),
  en('en', 'English', 'İngilizce');

  const AppLanguage(this.code, this.nativeName, this.turkishName);

  final String code;
  final String nativeName;
  final String turkishName;

  Locale get locale => Locale(code);

  static AppLanguage fromCode(String? code) {
    return AppLanguage.values.firstWhere(
      (language) => language.code == code,
      orElse: () => AppLanguage.tr,
    );
  }
}

class LanguageService extends ChangeNotifier {
  LanguageService._();

  static final LanguageService instance = LanguageService._();
  static const _languageKey = 'app_language';

  AppLanguage _language = AppLanguage.tr;
  bool _configured = false;

  AppLanguage get language => _language;
  bool get configured => _configured;
  bool get isEnglish => _language == AppLanguage.en;

  Future<void> initialize() async {
    final preferences = await SharedPreferences.getInstance();
    final code = preferences.getString(_languageKey);
    _configured = code != null;
    _language = AppLanguage.fromCode(code);
  }

  Future<void> setLanguage(AppLanguage language) async {
    _language = language;
    _configured = true;
    notifyListeners();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_languageKey, language.code);
  }

  String text(String tr, String en) {
    return isEnglish ? en : tr;
  }
}

extension AppLanguageText on BuildContext {
  String tr(String turkish, String english) {
    return LanguageService.instance.text(turkish, english);
  }
}
