import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ventourkid_mobile/core/network/dio_client.dart';
import 'package:ventourkid_mobile/core/storage/token_storage.dart';

void main() {
  test(
    'AUTH-TC-MOB-002 concurrent 401 responses share one refresh request',
    () async {
      final storage = _MemoryTokenStorage(
        accessToken: 'expired-access-token',
        refreshToken: 'original-refresh-token',
      );
      final protectedAdapter = _ProtectedResourceAdapter();
      final refreshAdapter = _RefreshAdapter();
      final httpClient = Dio(BaseOptions(baseUrl: 'https://api.example.test'))
        ..httpClientAdapter = protectedAdapter;
      final refreshClient = Dio(
        BaseOptions(baseUrl: 'https://api.example.test'),
      )..httpClientAdapter = refreshAdapter;
      final client = DioClient(
        tokenStorage: storage,
        httpClient: httpClient,
        refreshHttpClient: refreshClient,
      );

      final responses = await Future.wait(<Future<Response<dynamic>>>[
        client.dio.get<dynamic>('/protected/1'),
        client.dio.get<dynamic>('/protected/2'),
        client.dio.get<dynamic>('/protected/3'),
      ]);

      expect(refreshAdapter.requestCount, 1);
      expect(storage.accessToken, 'rotated-access-token');
      expect(storage.refreshToken, 'rotated-refresh-token');
      expect(
        responses.map((response) => response.statusCode),
        everyElement(200),
      );
      expect(protectedAdapter.attempts.values, everyElement(2));
      expect(
        protectedAdapter.retryAuthorizationHeaders,
        everyElement('Bearer rotated-access-token'),
      );
    },
  );

  test(
    'AUTH-TC-MOB-003 failed refresh clears tokens and does not recurse',
    () async {
      final storage = _MemoryTokenStorage(
        accessToken: 'expired-access-token',
        refreshToken: 'invalid-refresh-token',
      );
      final protectedAdapter = _ProtectedResourceAdapter(
        alwaysUnauthorized: true,
      );
      final refreshAdapter = _RefreshAdapter(statusCode: 401);
      final httpClient = Dio(BaseOptions(baseUrl: 'https://api.example.test'))
        ..httpClientAdapter = protectedAdapter;
      final refreshClient = Dio(
        BaseOptions(baseUrl: 'https://api.example.test'),
      )..httpClientAdapter = refreshAdapter;
      final client = DioClient(
        tokenStorage: storage,
        httpClient: httpClient,
        refreshHttpClient: refreshClient,
      );

      await expectLater(
        client.dio.get<dynamic>('/protected/failure'),
        throwsA(isA<DioException>()),
      );

      expect(refreshAdapter.requestCount, 1);
      expect(protectedAdapter.attempts['/protected/failure'], 1);
      expect(storage.accessToken, isNull);
      expect(storage.refreshToken, isNull);
    },
  );
}

class _ProtectedResourceAdapter implements HttpClientAdapter {
  _ProtectedResourceAdapter({this.alwaysUnauthorized = false});

  final bool alwaysUnauthorized;
  final Map<String, int> attempts = <String, int>{};
  final List<String?> retryAuthorizationHeaders = <String?>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final attempt = (attempts[options.path] ?? 0) + 1;
    attempts[options.path] = attempt;
    if (alwaysUnauthorized || attempt == 1) {
      return _jsonResponse(401, <String, Object?>{'message': 'Unauthorized'});
    }

    retryAuthorizationHeaders.add(options.headers['Authorization']?.toString());
    return _jsonResponse(200, <String, Object?>{'success': true});
  }

  @override
  void close({bool force = false}) {}
}

class _RefreshAdapter implements HttpClientAdapter {
  _RefreshAdapter({this.statusCode = 200});

  final int statusCode;
  int requestCount = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requestCount++;
    await Future<void>.delayed(const Duration(milliseconds: 20));
    if (statusCode != 200) {
      return _jsonResponse(statusCode, <String, Object?>{
        'message': 'Invalid refresh',
      });
    }
    return _jsonResponse(200, <String, Object?>{
      'data': <String, Object?>{
        'accessToken': 'rotated-access-token',
        'refreshToken': 'rotated-refresh-token',
      },
    });
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _jsonResponse(int statusCode, Map<String, Object?> body) {
  return ResponseBody.fromString(
    jsonEncode(body),
    statusCode,
    headers: <String, List<String>>{
      Headers.contentTypeHeader: <String>[Headers.jsonContentType],
    },
  );
}

class _MemoryTokenStorage implements TokenStorage {
  _MemoryTokenStorage({this.accessToken, this.refreshToken});

  String? accessToken;
  String? refreshToken;

  @override
  Future<void> clearTokens() async {
    accessToken = null;
    refreshToken = null;
  }

  @override
  Future<String?> getAccessToken() async => accessToken;

  @override
  Future<String?> getRefreshToken() async => refreshToken;

  @override
  Future<String?> getUserRole() async => null;

  @override
  Future<String?> getAccountId() async => null;

  @override
  Future<String?> getPhoneNumber() async => null;

  @override
  Future<void> saveAccessToken(String token) async {
    accessToken = token;
  }

  @override
  Future<void> saveRefreshToken(String token) async {
    refreshToken = token;
  }
}
