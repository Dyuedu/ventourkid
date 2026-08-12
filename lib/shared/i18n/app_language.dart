import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppLanguage {
  const AppLanguage({
    required this.code,
    required this.shortLabel,
    required this.label,
    this.htmlLang,
  });

  final String code;
  final String shortLabel;
  final String label;

  /// BCP-47 language tag for the HTML `lang` attribute / locale delegates.
  /// Falls back to [code] if not specified.
  final String? htmlLang;
}

const appLanguages = [
  AppLanguage(code: 'vi', shortLabel: 'VI', label: 'Tiếng Việt', htmlLang: 'vi'),
  AppLanguage(code: 'en', shortLabel: 'EN', label: 'English', htmlLang: 'en'),
  AppLanguage(code: 'ko', shortLabel: 'KO', label: '한국어', htmlLang: 'ko'),
];

const defaultAppLanguage = AppLanguage(
  code: 'vi',
  shortLabel: 'VI',
  label: 'Tiếng Việt',
  htmlLang: 'vi',
);

class AppLanguageController extends StateNotifier<AppLanguage> {
  AppLanguageController() : super(defaultAppLanguage) {
    _load();
  }

  static const _storageKey = 'ventourkids.language';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final savedCode = prefs.getString(_storageKey);
    final saved = _find(savedCode);
    if (saved != null) state = saved;
  }

  Future<void> setLanguage(String code) async {
    final next = _find(code) ?? defaultAppLanguage;
    if (next.code == state.code) return;
    state = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, next.code);
  }

  static AppLanguage? _find(String? code) {
    for (final language in appLanguages) {
      if (language.code == code) return language;
    }
    return null;
  }
}

final appLanguageControllerProvider =
    StateNotifierProvider<AppLanguageController, AppLanguage>(
      (ref) => AppLanguageController(),
    );
