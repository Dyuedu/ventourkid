import 'package:flutter_test/flutter_test.dart';
import 'package:ventourkid_mobile/core/error/app_failure.dart';
import 'package:ventourkid_mobile/core/network/api_exception.dart';
import 'package:ventourkid_mobile/core/device/device_id_provider.dart';
import 'package:ventourkid_mobile/core/storage/token_storage.dart';
import 'package:ventourkid_mobile/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:ventourkid_mobile/features/auth/data/models/accept_invitation_model.dart';
import 'package:ventourkid_mobile/features/auth/data/models/auth_tokens_model.dart';
import 'package:ventourkid_mobile/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:ventourkid_mobile/features/auth/domain/entities/register_draft.dart';

void main() {
  group('AuthRepositoryImpl', () {
    test('lưu access token và refresh token sau khi đăng nhập', () async {
      final storage = _FakeTokenStorage();
      final remoteDataSource = _FakeAuthRemoteDataSource();
      final repository = AuthRepositoryImpl(
        remoteDataSource: remoteDataSource,
        tokenStorage: storage,
        deviceIdProvider: _FakeDeviceIdProvider(),
      );

      await repository.login(
        identifier: 'parent@example.com',
        password: 'password1!',
      );

      expect(storage.accessToken, 'access-token');
      expect(storage.refreshToken, 'refresh-token');
      expect(remoteDataSource.loginDeviceId, 'test-device');
      expect(await repository.isAuthenticated(), isTrue);
      // A successful login seeds the short-lived session cache; bootstrap does
      // not need to immediately make a second validate-session request.
      expect(remoteDataSource.sessionValidated, isFalse);
    });

    test('xóa phiên đăng nhập thông qua token storage', () async {
      final storage = _FakeTokenStorage()
        ..accessToken = 'access-token'
        ..refreshToken = 'refresh-token';
      final remoteDataSource = _FakeAuthRemoteDataSource();
      final repository = AuthRepositoryImpl(
        remoteDataSource: remoteDataSource,
        tokenStorage: storage,
        deviceIdProvider: _FakeDeviceIdProvider(),
      );

      await repository.logout();

      expect(storage.accessToken, isNull);
      expect(storage.refreshToken, isNull);
      expect(remoteDataSource.logoutRefreshToken, 'refresh-token');
      expect(await repository.isAuthenticated(), isFalse);
    });

    test('không để lỗi data source vượt qua repository boundary', () async {
      final repository = AuthRepositoryImpl(
        remoteDataSource: _FailingAuthRemoteDataSource(),
        tokenStorage: _FakeTokenStorage(),
        deviceIdProvider: _FakeDeviceIdProvider(),
      );

      await expectLater(
        repository.login(identifier: 'parent@example.com', password: 'wrong'),
        throwsA(isA<AppFailure>()),
      );
    });

    test('giữ refresh token khi kiểm tra session gặp lỗi mạng', () async {
      final storage = _FakeTokenStorage()
        ..accessToken = 'access-token'
        ..refreshToken = 'refresh-token';
      final repository = AuthRepositoryImpl(
        remoteDataSource: _FailingSessionDataSource(),
        tokenStorage: storage,
        deviceIdProvider: _FakeDeviceIdProvider(),
      );

      expect(await repository.isAuthenticated(), isFalse);
      expect(storage.refreshToken, 'refresh-token');
    });
  });
}

class _FakeAuthRemoteDataSource implements AuthRemoteDataSource {
  String? loginDeviceId;
  String? logoutRefreshToken;
  bool sessionValidated = false;

  @override
  Future<AuthTokensModel> login({
    required String identifier,
    required String password,
    String? deviceId,
  }) async {
    loginDeviceId = deviceId;
    return const AuthTokensModel(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      tokenType: 'Bearer',
      expiresIn: 900,
    );
  }

  @override
  Future<AuthTokensModel> googleLogin({
    required String googleToken,
    String? deviceId,
  }) async {
    return const AuthTokensModel(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      tokenType: 'Bearer',
      expiresIn: 900,
    );
  }

  @override
  Future<void> register(RegisterDraft draft, String otpCode) async {}

  @override
  Future<void> sendRegisterOtp({required String identifier}) async {}

  @override
  Future<void> validateSession() async {
    sessionValidated = true;
  }

  @override
  Future<void> logout({required String? refreshToken}) async {
    logoutRefreshToken = refreshToken;
  }

  @override
  Future<AcceptInvitationModel> acceptInvitation({required String token}) async {
    return const AcceptInvitationModel(
      challengeToken: 'challenge-token',
      expiresInSeconds: 900,
      phoneNumberMasked: '+84***000',
      fullName: 'Test User',
    );
  }

  @override
  Future<AuthTokensModel> setInvitationPassword({
    required String challengeToken,
    required String newPassword,
    required String confirmPassword,
    String? deviceId,
  }) async {
    return const AuthTokensModel(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      tokenType: 'Bearer',
      expiresIn: 900,
    );
  }
}

class _FakeDeviceIdProvider implements DeviceIdProvider {
  @override
  Future<String> getDeviceId() async => 'test-device';
}

class _FailingAuthRemoteDataSource extends _FakeAuthRemoteDataSource {
  @override
  Future<AuthTokensModel> login({
    required String identifier,
    required String password,
    String? deviceId,
  }) {
    throw StateError('remote failure');
  }
}

class _FailingSessionDataSource extends _FakeAuthRemoteDataSource {
  @override
  Future<void> validateSession() {
    throw const ApiException(message: 'Network error');
  }
}

class _FakeTokenStorage implements TokenStorage {
  String? accessToken;
  String? refreshToken;

  @override
  Future<void> clearTokens() async {
    accessToken = null;
    refreshToken = null;
  }

  @override
  Future<String?> getUserRole() async {
    return 'PARENT'; // Default mock role
  }

  @override
  Future<String?> getAccountId() async => null;

  @override
  Future<String?> getPhoneNumber() async => null;

  @override
  Future<String?> getAccessToken() async => accessToken;

  @override
  Future<String?> getRefreshToken() async => refreshToken;

  @override
  Future<void> saveAccessToken(String token) async {
    accessToken = token;
  }

  @override
  Future<void> saveRefreshToken(String token) async {
    refreshToken = token;
  }
}
