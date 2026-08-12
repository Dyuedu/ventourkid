import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ventourkid_mobile/core/network/dio_client.dart';
import 'package:ventourkid_mobile/core/storage/token_storage.dart';
import 'package:ventourkid_mobile/features/tracking/data/datasources/tracking_remote_data_source.dart';

void main() {
  group('Tracking map API contract', () {
    late _RecordingAdapter adapter;
    late TrackingRemoteDataSource dataSource;

    setUp(() {
      adapter = _RecordingAdapter();
      final client = DioClient(tokenStorage: _FakeTokenStorage());
      client.dio.httpClientAdapter = adapter;
      dataSource = TrackingRemoteDataSource(client);
    });

    test('vehicle tracker loads location snapshot from backend contract', () async {
      await dataSource.getVehicleLocation('operation-plan-001');

      expect(adapter.lastMethod, 'GET');
      expect(adapter.lastPath, '/v1/tracking/locations');
      expect(adapter.lastQueryParameters, {'operationPlanId': 'operation-plan-001'});
    });

    test('selected tracker loads assignment snapshot from backend contract', () async {
      await dataSource.getTargetLocation('assignment-001');

      expect(adapter.lastMethod, 'GET');
      expect(adapter.lastPath, '/v1/tracking/locations/assignment-001');
    });

    test('raw GPS access goes through audited backend endpoint only', () async {
      await dataSource.getRawLocation();

      expect(adapter.lastMethod, 'GET');
      expect(adapter.lastPath, '/v1/tracking/raw-telemetry');
      expect(adapter.lastHeaders['X-Audit-Reason'], 'tracking-dashboard-access');
    });
  });
}

class _RecordingAdapter implements HttpClientAdapter {
  String? lastMethod;
  String? lastPath;
  Map<String, dynamic>? lastQueryParameters;
  Map<String, dynamic> lastHeaders = const {};

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastMethod = options.method;
    lastPath = options.path;
    lastQueryParameters = Map<String, dynamic>.from(options.queryParameters);
    lastHeaders = Map<String, dynamic>.from(options.headers);
    return ResponseBody.fromString(
      '{"data":{}}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _FakeTokenStorage implements TokenStorage {
  @override
  Future<void> clearTokens() async {}

  @override
  Future<String?> getAccessToken() async => null;

  @override
  Future<String?> getRefreshToken() async => null;

  @override
  Future<String?> getUserRole() async => null;

  @override
  Future<String?> getAccountId() async => null;

  @override
  Future<String?> getPhoneNumber() async => null;

  @override
  Future<void> saveAccessToken(String token) async {}

  @override
  Future<void> saveRefreshToken(String token) async {}
}
