import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SettingsProvider extends ChangeNotifier {
  static const _storage = FlutterSecureStorage();
  static const _keyTheme = 'theme_mode';
  static const _keyLocale = 'locale_code';

  ThemeMode _themeMode = ThemeMode.system;
  Locale? _locale; // null = follow system locale

  ThemeMode get themeMode => _themeMode;
  Locale? get locale => _locale;

  Future<void> load() async {
    final rawTheme = await _storage.read(key: _keyTheme);
    final rawLocale = await _storage.read(key: _keyLocale);
    _themeMode = _parseTheme(rawTheme);
    _locale = rawLocale != null ? Locale(rawLocale) : null;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    await _storage.write(key: _keyTheme, value: _serializeTheme(mode));
  }

  Future<void> setLocale(Locale? locale) async {
    if (_locale == locale) return;
    _locale = locale;
    notifyListeners();
    if (locale == null) {
      await _storage.delete(key: _keyLocale);
    } else {
      await _storage.write(key: _keyLocale, value: locale.languageCode);
    }
  }

  static ThemeMode _parseTheme(String? raw) => switch (raw) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };

  static String _serializeTheme(ThemeMode m) => switch (m) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      };
}
