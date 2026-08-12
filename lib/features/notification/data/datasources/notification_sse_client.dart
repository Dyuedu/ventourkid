import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../../../core/config/app_config.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/storage/token_storage.dart';

typedef NotificationSseMessageHandler = void Function(Map<String, dynamic> message);

/// Mobile SSE client for `GET /v1/notifications/stream` (Bearer auth).
///
/// Mirrors web [connectNotificationStream]: reconnect with backoff, refresh
/// session on auth failure, ignore malformed frames / heartbeat comments.
class NotificationSseClient {
  NotificationSseClient({
    required TokenStorage tokenStorage,
    required DioClient dioClient,
    this.onMessage,
  }) : _tokenStorage = tokenStorage,
       _dioClient = dioClient;

  final TokenStorage _tokenStorage;
  final DioClient _dioClient;
  NotificationSseMessageHandler? onMessage;

  HttpClient? _httpClient;
  HttpClientRequest? _request;
  StreamSubscription<String>? _lineSub;
  Timer? _reconnectTimer;
  bool _closed = true;
  bool _connecting = false;
  int _attempt = 0;

  bool get isActive => !_closed;

  Uri get _streamUri {
    final base = AppConfig.apiBaseUrl.endsWith('/')
        ? AppConfig.apiBaseUrl.substring(0, AppConfig.apiBaseUrl.length - 1)
        : AppConfig.apiBaseUrl;
    return Uri.parse('$base/v1/notifications/stream');
  }

  Future<void> connect() async {
    _closed = false;
    await _open();
  }

  Future<void> disconnect() async {
    _closed = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    await _tearDownSocket();
  }

  Future<void> _open() async {
    if (_closed || _connecting) return;
    _connecting = true;
    await _tearDownSocket();

    try {
      final token = await _tokenStorage.getAccessToken();
      if (token == null || token.isEmpty) {
        _scheduleReconnect(refreshFirst: false);
        return;
      }

      final client = HttpClient()..idleTimeout = const Duration(seconds: 90);
      _httpClient = client;
      final request = await client.getUrl(_streamUri);
      _request = request;
      request.headers.set(HttpHeaders.acceptHeader, 'text/event-stream');
      request.headers.set(HttpHeaders.cacheControlHeader, 'no-cache');
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');

      final response = await request.close();
      if (_closed) {
        await response.drain<void>();
        return;
      }

      if (response.statusCode == 401 || response.statusCode == 403) {
        await response.drain<void>();
        _scheduleReconnect(refreshFirst: true);
        return;
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        await response.drain<void>();
        _scheduleReconnect(refreshFirst: false);
        return;
      }

      _attempt = 0;
      final parser = _SseParser(onEvent: _handleEvent);
      _lineSub = response
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
            parser.addLine,
            onDone: () {
              if (!_closed) _scheduleReconnect(refreshFirst: false);
            },
            onError: (_) {
              if (!_closed) _scheduleReconnect(refreshFirst: false);
            },
            cancelOnError: true,
          );
    } on Object {
      if (!_closed) _scheduleReconnect(refreshFirst: false);
    } finally {
      _connecting = false;
    }
  }

  void _handleEvent(String eventName, String data) {
    if (data.isEmpty) return;
    // Named events from BE are `notification`; also accept default `message`.
    if (eventName.isNotEmpty &&
        eventName != 'notification' &&
        eventName != 'message') {
      return;
    }
    try {
      final decoded = jsonDecode(data);
      if (decoded is Map<String, dynamic>) {
        onMessage?.call(decoded);
      } else if (decoded is Map) {
        onMessage?.call(Map<String, dynamic>.from(decoded));
      }
    } on Object {
      // ignore malformed frames
    }
  }

  void _scheduleReconnect({required bool refreshFirst}) {
    if (_closed) return;
    _reconnectTimer?.cancel();
    final delay = Duration(
      milliseconds: (1000 * (1 << _attempt.clamp(0, 4))).clamp(1000, 30000),
    );
    _attempt += 1;
    _reconnectTimer = Timer(delay, () async {
      if (_closed) return;
      if (refreshFirst) {
        final ok = await _dioClient.refreshSession();
        if (!ok) {
          _closed = true;
          return;
        }
        _attempt = 0;
      }
      await _open();
    });
  }

  Future<void> _tearDownSocket() async {
    await _lineSub?.cancel();
    _lineSub = null;
    try {
      _request?.abort();
    } on Object {
      // ignore
    }
    _request = null;
    _httpClient?.close(force: true);
    _httpClient = null;
  }
}

class _SseParser {
  _SseParser({required this.onEvent});

  final void Function(String eventName, String data) onEvent;

  String _event = '';
  final StringBuffer _data = StringBuffer();

  void addLine(String line) {
    if (line.isEmpty) {
      if (_data.isNotEmpty) {
        onEvent(_event, _data.toString().replaceFirst(RegExp(r'\n$'), ''));
      }
      _event = '';
      _data.clear();
      return;
    }
    if (line.startsWith(':')) {
      // heartbeat / comment
      return;
    }
    final colon = line.indexOf(':');
    final field = colon < 0 ? line : line.substring(0, colon);
    var value = colon < 0 ? '' : line.substring(colon + 1);
    if (value.startsWith(' ')) value = value.substring(1);

    switch (field) {
      case 'event':
        _event = value;
      case 'data':
        if (_data.isNotEmpty) _data.write('\n');
        _data.write(value);
      default:
        break;
    }
  }
}
