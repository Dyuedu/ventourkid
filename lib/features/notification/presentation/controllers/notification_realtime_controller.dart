import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/dio_client.dart';
import '../../../../core/storage/token_storage.dart';
import '../../data/datasources/notification_remote_data_source.dart';
import '../../data/datasources/notification_sse_client.dart';
import '../../data/models/notification_models.dart';

class NotificationRealtimeState {
  const NotificationRealtimeState({
    this.unreadCount = 0,
    this.connected = false,
    this.lastCreated,
    this.revision = 0,
  });

  final int unreadCount;
  final bool connected;
  /// Latest created notification pushed over SSE (if any).
  final AppNotification? lastCreated;
  /// Bumps on every SSE frame so listeners can refresh inbox.
  final int revision;

  NotificationRealtimeState copyWith({
    int? unreadCount,
    bool? connected,
    AppNotification? lastCreated,
    int? revision,
    bool clearLastCreated = false,
  }) {
    return NotificationRealtimeState(
      unreadCount: unreadCount ?? this.unreadCount,
      connected: connected ?? this.connected,
      lastCreated:
          clearLastCreated ? null : (lastCreated ?? this.lastCreated),
      revision: revision ?? this.revision,
    );
  }
}

/// Holds unread badge + SSE lifecycle for the logged-in session.
class NotificationRealtimeController
    extends StateNotifier<NotificationRealtimeState>
    with WidgetsBindingObserver {
  NotificationRealtimeController({
    required NotificationRemoteDataSource remote,
    required TokenStorage tokenStorage,
    required DioClient dioClient,
  }) : _remote = remote,
       _tokenStorage = tokenStorage,
       _dioClient = dioClient,
       super(const NotificationRealtimeState()) {
    WidgetsBinding.instance.addObserver(this);
  }

  final NotificationRemoteDataSource _remote;
  final TokenStorage _tokenStorage;
  final DioClient _dioClient;
  NotificationSseClient? _sse;
  bool _started = false;

  Future<void> start() async {
    if (_started) return;
    final token = await _tokenStorage.getAccessToken();
    if (token == null || token.isEmpty) return;

    _started = true;
    await refreshUnread();
    await _connectSse();
  }

  Future<void> stop() async {
    _started = false;
    await _sse?.disconnect();
    _sse = null;
    if (mounted) {
      state = const NotificationRealtimeState();
    }
  }

  Future<void> refreshUnread() async {
    try {
      final count = await _remote.unreadCount();
      if (!mounted) return;
      state = state.copyWith(unreadCount: count);
    } on Object {
      // keep previous badge
    }
  }

  void setUnreadCount(int count) {
    if (!mounted) return;
    state = state.copyWith(unreadCount: count < 0 ? 0 : count);
  }

  Future<void> _connectSse() async {
    await _sse?.disconnect();
    final client = NotificationSseClient(
      tokenStorage: _tokenStorage,
      dioClient: _dioClient,
      onMessage: _onSseMessage,
    );
    _sse = client;
    await client.connect();
    if (mounted) {
      state = state.copyWith(connected: true);
    }
  }

  void _onSseMessage(Map<String, dynamic> message) {
    if (!mounted) return;
    final type = message['type']?.toString();
    final unread = (message['unreadCount'] as num?)?.toInt();

    AppNotification? created;
    final rawNotification = message['notification'];
    if (type == 'NOTIFICATION_CREATED' && rawNotification is Map) {
      created = AppNotification.fromJson(
        Map<String, dynamic>.from(rawNotification),
      );
    }

    state = state.copyWith(
      unreadCount: unread ?? state.unreadCount,
      connected: true,
      lastCreated: created,
      revision: state.revision + 1,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_started) return;
    if (state == AppLifecycleState.resumed) {
      unawaited(refreshUnread());
      unawaited(_connectSse());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_sse?.disconnect());
    super.dispose();
  }
}
