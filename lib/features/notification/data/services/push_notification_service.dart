import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../../../core/device/device_id_provider.dart';
import '../datasources/notification_remote_data_source.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

typedef PushTapHandler = void Function(Map<String, dynamic> data);

/// Registers FCM token with BE and surfaces system notifications on Android.
class PushNotificationService {
  PushNotificationService({
    required NotificationRemoteDataSource remote,
    required DeviceIdProvider deviceIdProvider,
  }) : _remote = remote,
       _deviceIdProvider = deviceIdProvider;

  final NotificationRemoteDataSource _remote;
  final DeviceIdProvider _deviceIdProvider;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  String? _currentToken;
  PushTapHandler? onNotificationTap;

  Future<void> initialize() async {
    if (_initialized) return;
    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) {
      return;
    }

    await Firebase.initializeApp();

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _local.initialize(
      const InitializationSettings(android: androidInit),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload == null || payload.isEmpty) return;
        try {
          final data = jsonDecode(payload);
          if (data is Map<String, dynamic>) {
            onNotificationTap?.call(data);
          } else if (data is Map) {
            onNotificationTap?.call(Map<String, dynamic>.from(data));
          }
        } on Object {
          // ignore malformed payload
        }
      },
    );

    const channel = AndroidNotificationChannel(
      'ventourkid_default',
      'VentourKid',
      description: 'Thông báo tour và vận hành',
      importance: Importance.high,
    );
    await _local
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(alert: true, badge: true, sound: true);
    await messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    FirebaseMessaging.onMessage.listen(_showForeground);
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      onNotificationTap?.call(Map<String, dynamic>.from(message.data));
    });

    final initial = await messaging.getInitialMessage();
    if (initial != null) {
      onNotificationTap?.call(Map<String, dynamic>.from(initial.data));
    }

    messaging.onTokenRefresh.listen(_registerToken);
    _initialized = true;
  }

  Future<void> syncTokenWithBackend() async {
    if (!_initialized) {
      await initialize();
    }
    if (!_initialized) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) return;
      await _registerToken(token);
    } on Object catch (error) {
      debugPrint('[FCM] sync token failed: $error');
    }
  }

  Future<void> clearTokenOnLogout() async {
    final token = _currentToken;
    if (token == null) return;
    try {
      await _remote.unregisterDeviceToken(token);
    } on Object {
      // best effort
    }
    _currentToken = null;
  }

  Future<void> _registerToken(String token) async {
    _currentToken = token;
    final deviceId = await _deviceIdProvider.getDeviceId();
    await _remote.registerDeviceToken(
      token: token,
      platform: Platform.isIOS ? 'IOS' : 'ANDROID',
      deviceId: deviceId,
    );
  }

  Future<void> _showForeground(RemoteMessage message) async {
    final notification = message.notification;
    final title = notification?.title ?? message.data['title']?.toString();
    final body = notification?.body ?? message.data['body']?.toString();
    if (title == null && body == null) return;

    await _local.show(
      message.hashCode,
      title ?? 'VentourKid',
      body ?? '',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'ventourkid_default',
          'VentourKid',
          channelDescription: 'Thông báo tour và vận hành',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }
}
