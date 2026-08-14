import '../../../../core/device/device_id_provider.dart';
import '../../../../core/error/app_failure.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/storage/token_storage.dart';
import '../../domain/entities/register_draft.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_data_source.dart';
import '../models/accept_invitation_model.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required AuthRemoteDataSource remoteDataSource,
    required TokenStorage tokenStorage,
    required DeviceIdProvider deviceIdProvider,
  }) : _remoteDataSource = remoteDataSource,
       _tokenStorage = tokenStorage,
       _deviceIdProvider = deviceIdProvider;

  final AuthRemoteDataSource _remoteDataSource;
  final TokenStorage _tokenStorage;
  final DeviceIdProvider _deviceIdProvider;

  /// Short-lived cache so bootstrap splash + first GoRouter redirect
  /// do not hit validateSession twice.
  bool? _sessionCache;
  DateTime? _sessionCacheAt;
  static const _sessionCacheTtl = Duration(seconds: 12);

  void _rememberSession(bool authenticated) {
    _sessionCache = authenticated;
    _sessionCacheAt = DateTime.now();
  }

  void _clearSessionCache() {
    _sessionCache = null;
    _sessionCacheAt = null;
  }

  bool? _cachedSessionIfFresh() {
    final cached = _sessionCache;
    final at = _sessionCacheAt;
    if (cached == null || at == null) return null;
    if (DateTime.now().difference(at) > _sessionCacheTtl) return null;
    return cached;
  }

  @override
  Future<void> sendRegisterOtp({required String identifier}) {
    return _guard(
      () => _remoteDataSource.sendRegisterOtp(identifier: identifier),
      fallbackMessage: 'Không thể gửi mã OTP. Vui lòng thử lại.',
    );
  }

  @override
  Future<void> sendPasswordResetOtp({required String email}) {
    return _guard(
      () => _remoteDataSource.sendPasswordResetOtp(email: email),
      fallbackMessage: 'KhĂ´ng thá»ƒ gá»­i mĂ£ khĂ´i phá»¥c. Vui lĂ²ng thá»­ láº¡i.',
    );
  }

  @override
  Future<void> resetPassword({
    required String email,
    required String otpCode,
    required String newPassword,
    required String confirmPassword,
  }) {
    return _guard(
      () => _remoteDataSource.resetPassword(
        email: email,
        otpCode: otpCode,
        newPassword: newPassword,
        confirmPassword: confirmPassword,
      ),
      fallbackMessage: 'KhĂ´ng thá»ƒ Ä‘áº·t láº¡i máº­t kháº©u. Vui lĂ²ng thá»­ láº¡i.',
    );
  }

  @override
  Future<void> register(RegisterDraft draft, String otpCode) {
    return _guard(
      () => _remoteDataSource.register(draft, otpCode),
      fallbackMessage: 'Không thể xác minh OTP. Vui lòng thử lại.',
    );
  }

  @override
  Future<void> login({required String identifier, required String password}) {
    return _guard(() async {
      final deviceId = await _deviceIdProvider.getDeviceId();
      final tokens = await _remoteDataSource.login(
        identifier: identifier,
        password: password,
        deviceId: deviceId,
      );
      await _tokenStorage.saveAccessToken(tokens.accessToken);
      await _tokenStorage.saveRefreshToken(tokens.refreshToken);
      _rememberSession(true);
    }, fallbackMessage: 'Không thể đăng nhập. Vui lòng thử lại.');
  }

  @override
  Future<void> googleLogin({required String googleToken}) {
    return _guard(() async {
      final deviceId = await _deviceIdProvider.getDeviceId();
      final tokens = await _remoteDataSource.googleLogin(
        googleToken: googleToken,
        deviceId: deviceId,
      );
      await _tokenStorage.saveAccessToken(tokens.accessToken);
      await _tokenStorage.saveRefreshToken(tokens.refreshToken);
      _rememberSession(true);
    }, fallbackMessage: 'Không thể đăng nhập bằng Google. Vui lòng thử lại.');
  }

  @override
  Future<AcceptInvitationModel> acceptInvitation({required String token}) {
    return _guard(
      () => _remoteDataSource.acceptInvitation(token: token),
      fallbackMessage: 'Không thể kích hoạt lời mời. Vui lòng thử lại.',
    );
  }

  @override
  Future<void> setInvitationPassword({
    required String challengeToken,
    required String newPassword,
    required String confirmPassword,
  }) {
    return _guard(() async {
      final deviceId = await _deviceIdProvider.getDeviceId();
      final tokens = await _remoteDataSource.setInvitationPassword(
        challengeToken: challengeToken,
        newPassword: newPassword,
        confirmPassword: confirmPassword,
        deviceId: deviceId,
      );
      await _tokenStorage.saveAccessToken(tokens.accessToken);
      await _tokenStorage.saveRefreshToken(tokens.refreshToken);
      _rememberSession(true);
    }, fallbackMessage: 'Không thể đặt mật khẩu. Vui lòng thử lại.');
  }

  @override
  Future<void> logout() async {
    final refreshToken = await _tokenStorage.getRefreshToken();
    try {
      await _remoteDataSource.logout(refreshToken: refreshToken);
    } on Object {
      // Local logout must still complete when the server is temporarily offline.
    } finally {
      await _tokenStorage.clearTokens();
      _rememberSession(false);
    }
  }

  @override
  Future<bool> isAuthenticated() async {
    final cached = _cachedSessionIfFresh();
    if (cached != null) return cached;

    try {
      final token = await _tokenStorage.getAccessToken();
      final refreshToken = await _tokenStorage.getRefreshToken();
      if ((token == null || token.isEmpty) &&
          (refreshToken == null || refreshToken.isEmpty)) {
        _rememberSession(false);
        return false;
      }
      await _remoteDataSource.validateSession();
      _rememberSession(true);
      return true;
    } on Object catch (error) {
      final statusCode = ApiException.maybeFrom(error)?.statusCode;
      if (statusCode == 401 || statusCode == 403) {
        await _tokenStorage.clearTokens();
        _rememberSession(false);
      } else {
        _clearSessionCache();
      }
      return false;
    }
  }

  @override
  Future<String?> getUserRole() async {
    return _tokenStorage.getUserRole();
  }

  @override
  Future<String?> getAccountId() async {
    return _tokenStorage.getAccountId();
  }

  Future<T> _guard<T>(
    Future<T> Function() action, {
    required String fallbackMessage,
  }) async {
    try {
      return await action();
    } on Object catch (error) {
      if (error is AppFailure) {
        rethrow;
      }
      throw AppFailure(
        ApiException.maybeFrom(error)?.message ?? fallbackMessage,
        cause: error,
      );
    }
  }
}
