import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../shared/i18n/app_language.dart';
import '../shared/i18n/translations.dart';
import '../shared/theme/app_theme.dart';
import '../shared/widgets/app_bootstrap_splash.dart';
import '../shared/widgets/brand_logo.dart';
import 'providers.dart';
import 'router.dart';

/// Listens for HTTPS invitation App Links and routes into `/invite/:token`.
class VentourKidApp extends ConsumerStatefulWidget {
  const VentourKidApp({super.key});

  @override
  ConsumerState<VentourKidApp> createState() => _VentourKidAppState();
}

class _VentourKidAppState extends ConsumerState<VentourKidApp>
    with WidgetsBindingObserver {
  StreamSubscription<Uri>? _linkSub;
  final _appLinks = AppLinks();
  final _splashKey = GlobalKey();

  /// Router may start under the splash; splash stays until fade completes.
  bool _routerReady = false;
  bool _splashVisible = true;
  bool _splashGone = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initDeepLinks();
    Future.microtask(() async {
      await _bootstrapSession();
      await _bootstrapNotifications();
    });
    unawaited(preloadTranslations());
  }

  /// Validate remembered session behind a single stable splash overlay.
  Future<void> _bootstrapSession() async {
    final started = DateTime.now();
    try {
      await ref.read(routeGuardsProvider).isAuthenticated;
    } catch (_) {
      // Splash still dismisses; router redirect will re-check.
    }

    // Precache logo so the first paint is stable (no decode flash).
    try {
      final binding = WidgetsBinding.instance;
      await binding.endOfFrame;
      if (mounted) {
        await precacheImage(const AssetImage(BrandLogo.assetPath), context);
      }
    } catch (_) {}

    const minVisible = Duration(milliseconds: 900);
    final elapsed = DateTime.now().difference(started);
    if (elapsed < minVisible) {
      await Future<void>.delayed(minVisible - elapsed);
    }

    if (!mounted) return;
    // Reveal router under the same splash, then fade splash out once.
    setState(() => _routerReady = true);
    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (!mounted) return;
    setState(() => _splashVisible = false);
  }

  Future<void> _bootstrapNotifications() async {
    final push = ref.read(pushNotificationServiceProvider);
    push.onNotificationTap = _handlePushTap;
    await push.initialize();

    final authenticated = await ref.read(routeGuardsProvider).isAuthenticated;
    if (!authenticated) {
      await ref.read(notificationRealtimeProvider.notifier).stop();
      return;
    }
    await ref.read(notificationRealtimeProvider.notifier).start();
    await push.syncTokenWithBackend();
  }

  Future<void> _ensureNotificationStream() async {
    final authenticated = await ref.read(routeGuardsProvider).isAuthenticated;
    if (!authenticated) {
      await ref.read(notificationRealtimeProvider.notifier).stop();
      return;
    }
    await ref.read(notificationRealtimeProvider.notifier).start();
    await ref.read(pushNotificationServiceProvider).syncTokenWithBackend();
  }

  void _handlePushTap(Map<String, dynamic> data) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final router = ref.read(appRouterProvider);
      final mobilePath = data['mobileActionPath']?.toString();
      if (mobilePath != null &&
          mobilePath.startsWith('/') &&
          (mobilePath.startsWith('/guide/') ||
              mobilePath.startsWith('/livestream/') ||
              mobilePath.startsWith('/attendance/') ||
              mobilePath.startsWith('/incident') ||
              mobilePath.startsWith('/tracking') ||
              mobilePath.startsWith('/notifications'))) {
        router.push(mobilePath);
        return;
      }
      final tourId =
          data['tourId']?.toString() ?? data['operationPlanId']?.toString();
      if (tourId != null && tourId.isNotEmpty) {
        router.push('/guide/itinerary?tourId=$tourId');
        return;
      }
      router.push('/notifications');
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_ensureNotificationStream());
    }
  }

  Future<void> _initDeepLinks() async {
    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) {
        _handleUri(initial);
      }
    } on Object {
      // Ignore cold-start link failures; user can open SMS link again.
    }

    _linkSub = _appLinks.uriLinkStream.listen(_handleUri);
  }

  void _handleUri(Uri uri) {
    final token = _extractInviteToken(uri);
    if (token == null || token.isEmpty) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final router = ref.read(appRouterProvider);
      router.go('/invite/$token');
    });
  }

  static String? _extractInviteToken(Uri uri) {
    if (uri.scheme == 'ventourkids' &&
        (uri.host == 'invite' || uri.pathSegments.isNotEmpty)) {
      if (uri.host == 'invite' && uri.pathSegments.isNotEmpty) {
        return uri.pathSegments.first;
      }
      if (uri.pathSegments.length >= 2 && uri.pathSegments.first == 'invite') {
        return uri.pathSegments[1];
      }
    }
    if (uri.pathSegments.length >= 2 && uri.pathSegments.first == 'invite') {
      return uri.pathSegments[1];
    }
    return null;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _linkSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    final language = ref.watch(appLanguageControllerProvider);

    return MaterialApp.router(
      title: 'VentourKid',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.light,
      locale: Locale(language.htmlLang ?? language.code),
      supportedLocales: const [
        Locale('vi'),
        Locale('en'),
        Locale('ko'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        return Stack(
          fit: StackFit.expand,
          children: [
            if (_routerReady)
              child ?? const AppBootstrapHold()
            else
              const AppBootstrapHold(),
            if (!_splashGone)
              IgnorePointer(
                ignoring: !_splashVisible,
                child: AnimatedOpacity(
                  opacity: _splashVisible ? 1 : 0,
                  duration: const Duration(milliseconds: 380),
                  curve: Curves.easeOut,
                  onEnd: () {
                    if (!_splashVisible && mounted) {
                      setState(() => _splashGone = true);
                    }
                  },
                  child: AppBootstrapSplash(key: _splashKey),
                ),
              ),
          ],
        );
      },
    );
  }
}
