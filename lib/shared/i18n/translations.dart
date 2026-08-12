import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

/// Translation catalog loaded from JSON asset files: vi.json, en.json, ko.json
/// The catalog is populated lazily on first request for each language.

const _assetBase = 'assets/i18n/';

final Map<String, Map<String, String>> _cache = {};

/// Returns a loaded catalog without touching assets.
Map<String, String>? getCachedCatalog(String languageCode) {
  return _cache[languageCode];
}

class _DynamicPattern {
  final RegExp pattern;
  final Map<String, String> translations;

  const _DynamicPattern({required this.pattern, required this.translations});
}

final _dynamicPatterns = <_DynamicPattern>[
  _DynamicPattern(
    pattern: RegExp(r'^Thông báo, có (\d+) chưa đọc$'),
    translations: {
      'en': r'Notifications, $1 unread',
      'ko': r'알림, 읽지 않은 항목 $1개',
    },
  ),
];

// Diacritic removal map for Vietnamese characters.
// Dart's String doesn't have a normalize() method like JavaScript,
// so we manually map Vietnamese characters to their non-diacritic equivalents.
const _diacriticMap = {
  'á': 'a',
  'à': 'a',
  'ả': 'a',
  'ã': 'a',
  'ạ': 'a',
  'ă': 'a',
  'ắ': 'a',
  'ằ': 'a',
  'ẳ': 'a',
  'ẵ': 'a',
  'ặ': 'a',
  'â': 'a',
  'ấ': 'a',
  'ầ': 'a',
  'ẩ': 'a',
  'ẫ': 'a',
  'ậ': 'a',
  'é': 'e',
  'è': 'e',
  'ẻ': 'e',
  'ẽ': 'e',
  'ẹ': 'e',
  'ê': 'e',
  'ế': 'e',
  'ề': 'e',
  'ể': 'e',
  'ễ': 'e',
  'ệ': 'e',
  'í': 'i',
  'ì': 'i',
  'ỉ': 'i',
  'ĩ': 'i',
  'ị': 'i',
  'ó': 'o',
  'ò': 'o',
  'ỏ': 'o',
  'õ': 'o',
  'ọ': 'o',
  'ô': 'o',
  'ố': 'o',
  'ồ': 'o',
  'ổ': 'o',
  'ỗ': 'o',
  'ộ': 'o',
  'ơ': 'o',
  'ớ': 'o',
  'ờ': 'o',
  'ở': 'o',
  'ỡ': 'o',
  'ợ': 'o',
  'ú': 'u',
  'ù': 'u',
  'ủ': 'u',
  'ũ': 'u',
  'ụ': 'u',
  'ư': 'u',
  'ứ': 'u',
  'ừ': 'u',
  'ử': 'u',
  'ữ': 'u',
  'ự': 'u',
  'ý': 'y',
  'ỳ': 'y',
  'ỷ': 'y',
  'ỹ': 'y',
  'ỵ': 'y',
  'đ': 'd',
  'Á': 'A',
  'À': 'A',
  'Ả': 'A',
  'Ã': 'A',
  'Ạ': 'A',
  'Ă': 'A',
  'Ắ': 'A',
  'Ằ': 'A',
  'Ẳ': 'A',
  'Ẵ': 'A',
  'Ặ': 'A',
  'Â': 'A',
  'Ấ': 'A',
  'Ầ': 'A',
  'Ẩ': 'A',
  'Ẫ': 'A',
  'Ậ': 'A',
  'É': 'E',
  'È': 'E',
  'Ẻ': 'E',
  'Ẽ': 'E',
  'Ẹ': 'E',
  'Ê': 'E',
  'Ế': 'E',
  'Ề': 'E',
  'Ể': 'E',
  'Ễ': 'E',
  'Ệ': 'E',
  'Í': 'I',
  'Ì': 'I',
  'Ỉ': 'I',
  'Ĩ': 'I',
  'Ị': 'I',
  'Ó': 'O',
  'Ò': 'O',
  'Ỏ': 'O',
  'Õ': 'O',
  'Ọ': 'O',
  'Ô': 'O',
  'Ố': 'O',
  'Ồ': 'O',
  'Ổ': 'O',
  'Ỗ': 'O',
  'Ộ': 'O',
  'Ơ': 'O',
  'Ớ': 'O',
  'Ờ': 'O',
  'Ở': 'O',
  'Ỡ': 'O',
  'Ợ': 'O',
  'Ú': 'U',
  'Ù': 'U',
  'Ủ': 'U',
  'Ũ': 'U',
  'Ụ': 'U',
  'Ư': 'U',
  'Ứ': 'U',
  'Ừ': 'U',
  'Ử': 'U',
  'Ữ': 'U',
  'Ự': 'U',
  'Ý': 'Y',
  'Ỳ': 'Y',
  'Ỷ': 'Y',
  'Ỹ': 'Y',
  'Ỵ': 'Y',
  'Đ': 'D',
};

/// Removes Vietnamese diacritics from a string.
String _removeDiacritics(String source) {
  var result = source;
  _diacriticMap.forEach((diacritic, replacement) {
    result = result.replaceAll(diacritic, replacement);
  });
  return result;
}

/// Normalizes a Vietnamese source string into a translation key.
/// Removes diacritics, converts đ→d, replaces non-alphanumeric with spaces,
/// and lowercases — matching the web project's normalizeI18nKey.
String normalizeI18nKey(String source) {
  return _removeDiacritics(source)
      .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ')
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ')
      .toLowerCase();
}

Future<Map<String, String>> _loadCatalog(String languageCode) async {
  if (_cache.containsKey(languageCode)) return _cache[languageCode]!;
  try {
    final jsonString = await rootBundle.loadString(
      '$_assetBase$languageCode.json',
    );
    final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
    final catalog = decoded.map(
      (key, value) => MapEntry(key, value.toString()),
    );
    _cache[languageCode] = catalog;
    return catalog;
  } catch (_) {
    _cache[languageCode] = {};
    return _cache[languageCode]!;
  }
}

/// Preloads all translation catalogs into memory.
/// Call this at app startup to avoid jank on first translation.
Future<void> preloadTranslations() async {
  await Future.wait([
    _loadCatalog('vi'),
    _loadCatalog('en'),
    _loadCatalog('ko'),
  ]);
}

/// Returns the translation for [source] in the given [languageCode].
/// If [languageCode] is 'vi' (the source language), returns [source] as-is.
/// Falls back to [source] if no translation is found.
Future<String> translatePhraseAsync(String source, String languageCode) async {
  if (source.isEmpty || languageCode == 'vi') return source;
  final catalog = await _loadCatalog(languageCode);
  return _translate(source, languageCode, catalog);
}

/// Synchronous translation using an already-loaded catalog.
/// Falls back to [source] if no translation is found.
String translatePhrase(
  String source,
  String languageCode,
  Map<String, String> catalog,
) {
  if (source.isEmpty || languageCode == 'vi') return source;
  return _translate(source, languageCode, catalog);
}

String _translate(
  String source,
  String languageCode,
  Map<String, String> catalog,
) {
  for (final dp in _dynamicPatterns) {
    final match = dp.pattern.firstMatch(source);
    if (match != null) {
      final template = dp.translations[languageCode];
      if (template != null) {
        var result = template;
        for (var i = 1; i <= match.groupCount; i++) {
          result = result.replaceAll('\$$i', match.group(i) ?? '');
        }
        return result;
      }
    }
  }
  final translated = catalog[normalizeI18nKey(source)];
  return translated ?? source;
}

/// Returns the full translation catalog for [languageCode].
/// Loads from cache or asset if necessary.
Future<Map<String, String>> getCatalog(String languageCode) async {
  return _loadCatalog(languageCode);
}

/// Clears the in-memory cache. Useful for testing or hot-reload scenarios.
void clearTranslationCache() {
  _cache.clear();
}
