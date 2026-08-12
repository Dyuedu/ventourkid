import 'package:google_sign_in/google_sign_in.dart';

import '../../../../core/config/app_config.dart';

class GoogleSignInResult {
  const GoogleSignInResult({required this.accessToken, required this.email});

  final String accessToken;
  final String email;
}

abstract interface class GoogleSignInService {
  Future<GoogleSignInResult> signIn();
}

class GoogleSignInServiceImpl implements GoogleSignInService {
  GoogleSignInServiceImpl({GoogleSignIn? googleSignIn})
    : _googleSignIn = googleSignIn ?? GoogleSignIn.instance;

  static const _scopes = [
    'https://www.googleapis.com/auth/userinfo.email',
    'https://www.googleapis.com/auth/userinfo.profile',
    'openid',
  ];

  final GoogleSignIn _googleSignIn;
  static bool _initialized = false;

  @override
  Future<GoogleSignInResult> signIn() async {
    await _initialize();

    try {
      final account = await _googleSignIn.authenticate();
      final authorization = await _authorizationFor(account);
      final accessToken = authorization.accessToken;
      if (accessToken.isEmpty) {
        throw const GoogleSignInServiceException(
          'Google did not return an access token.',
        );
      }

      return GoogleSignInResult(accessToken: accessToken, email: account.email);
    } on GoogleSignInException catch (error) {
      if (_isCanceled(error)) {
        throw const GoogleSignInCancelledException();
      }
      throw GoogleSignInServiceException(
        'Không thể đăng nhập Google. Vui lòng thử lại.',
      );
    }
  }

  Future<void> _initialize() async {
    if (_initialized) {
      return;
    }

    try {
      await _googleSignIn.initialize(
        clientId: AppConfig.googleClientId,
        serverClientId: AppConfig.googleClientId,
      );
    } on Object catch (error) {
      final message = error.toString();
      if (!message.contains('already been called')) {
        rethrow;
      }
    }
    _initialized = true;
  }

  Future<GoogleSignInClientAuthorization> _authorizationFor(
    GoogleSignInAccount account,
  ) async {
    final authorization = await account.authorizationClient
        .authorizationForScopes(_scopes);
    if (authorization != null) {
      return authorization;
    }

    return account.authorizationClient.authorizeScopes(_scopes);
  }

  static bool _isCanceled(GoogleSignInException error) {
    final codeName = error.code.name.toLowerCase();
    if (codeName.contains('cancel')) {
      return true;
    }
    final message = error.description?.toLowerCase() ?? '';
    return message.contains('cancel') || message.contains('cancelled');
  }
}

/// User dismissed the Google account picker (e.g. system back).
class GoogleSignInCancelledException implements Exception {
  const GoogleSignInCancelledException();
}

class GoogleSignInServiceException implements Exception {
  const GoogleSignInServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}
