import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_language.dart';
import 'translations.dart';

/// Holds the current language code and the loaded translation catalog.
class TranslationsState {
  const TranslationsState({required this.languageCode, required this.catalog});

  final String languageCode;
  final Map<String, String> catalog;

  /// Translates [source] using the current catalog.
  /// If the language is 'vi' (source), returns [source] unchanged.
  /// Falls back to [source] if no translation is found.
  String tr(String source) {
    if (source.isEmpty || languageCode == 'vi') return source;
    return translatePhrase(source, languageCode, catalog);
  }

  TranslationsState copyWith({
    String? languageCode,
    Map<String, String>? catalog,
  }) {
    return TranslationsState(
      languageCode: languageCode ?? this.languageCode,
      catalog: catalog ?? this.catalog,
    );
  }
}

/// Notifier that watches [appLanguageControllerProvider] and loads
/// the appropriate translation catalog whenever the language changes.
class TranslationsNotifier extends Notifier<TranslationsState> {
  @override
  TranslationsState build() {
    final language = ref.watch(appLanguageControllerProvider);
    final cachedCatalog = getCachedCatalog(language.code);
    if (cachedCatalog != null) {
      return TranslationsState(
        languageCode: language.code,
        catalog: cachedCatalog,
      );
    }

    // Load catalog asynchronously only when startup preload has not finished.
    _loadCatalog(language.code);

    return TranslationsState(languageCode: language.code, catalog: const {});
  }

  Future<void> _loadCatalog(String languageCode) async {
    final catalog = await getCatalog(languageCode);
    if (state.languageCode == languageCode) {
      state = TranslationsState(languageCode: languageCode, catalog: catalog);
    }
  }
}

/// Provides the current [TranslationsState].
/// Watch this provider (or use `ref.tr()`) to rebuild widgets when
/// the language or catalog changes.
final translationsProvider =
    NotifierProvider<TranslationsNotifier, TranslationsState>(
      TranslationsNotifier.new,
    );

/// Extension on [WidgetRef] for convenient translation access.
///
/// Usage in [ConsumerWidget.build]:
/// ```dart
/// Text(ref.tr('Đăng nhập'))
/// ```
///
/// The widget will automatically rebuild when the language changes.
extension TranslationsWidgetRefX on WidgetRef {
  /// Translates [source] using the current language.
  ///
  /// Uses `watch` internally so the widget rebuilds on language change.
  /// Call this inside `build()` methods only.
  String tr(String source) {
    final state = watch(translationsProvider);
    return state.tr(source);
  }

  /// Translates [source] without subscribing to updates.
  ///
  /// Use this in callbacks, error handlers, or other places where
  /// a rebuild is not desired.
  String trRead(String source) {
    final state = read(translationsProvider);
    return state.tr(source);
  }
}

/// Extension on [BuildContext] for convenient translation access.
///
/// Usage:
/// ```dart
/// Text(context.tr('Đăng nhập'))
/// ```
///
/// Note: This uses `read` internally, so the widget will NOT rebuild
/// on language change. For reactive translations, use `ref.tr()` in a
/// [ConsumerWidget] instead.
extension TranslationsBuildContextX on BuildContext {
  String tr(String source) {
    final container = ProviderScope.containerOf(this);
    final state = container.read(translationsProvider);
    return state.tr(source);
  }
}
