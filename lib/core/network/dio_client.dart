import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../storage/token_storage.dart';
import 'api_exception.dart';

class DioClient {
  DioClient({
    required TokenStorage tokenStorage,
    String languageCode = 'vi',
    Dio? httpClient,
    Dio? refreshHttpClient,
  }) : _tokenStorage = tokenStorage,
       _languageCode = languageCode {
    dio =
        httpClient ??
        Dio(
          BaseOptions(
            baseUrl: AppConfig.apiBaseUrl,
            connectTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 15),
            sendTimeout: const Duration(seconds: 15),
            headers: {
              'Content-Type': 'application/json',
              'Accept-Language': languageCode,
            },
          ),
        );
    _refreshDio = refreshHttpClient ?? Dio(dio.options.copyWith());

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final accessToken = await _tokenStorage.getAccessToken();
          options.headers['Accept-Language'] = _languageCode;

          if (accessToken != null && accessToken.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $accessToken';
          }

          handler.next(options);
        },
        onError: (error, handler) async {
          final request = error.requestOptions;
          if (error.response?.statusCode == 401 &&
              request.extra['authRetry'] != true &&
              request.extra['skipAuthRefresh'] != true) {
            request.extra['authRetry'] = true;
            if (await refreshSession()) {
              final accessToken = await _tokenStorage.getAccessToken();
              request.headers['Authorization'] = 'Bearer $accessToken';
              try {
                handler.resolve(await dio.fetch<dynamic>(request));
                return;
              } on DioException catch (retryError) {
                error = retryError;
              }
            }
          }

          final apiException = ApiException.fromDioException(error);
          handler.reject(
            DioException(
              requestOptions: error.requestOptions,
              response: error.response,
              type: error.type,
              error: apiException,
              message: apiException.message,
            ),
          );
        },
      ),
    );
  }

  final TokenStorage _tokenStorage;
  final String _languageCode;

  late final Dio dio;
  late final Dio _refreshDio;
  Future<bool>? _refreshRequest;

  /// Rotates tokens once even when several requests fail at the same time.
  Future<bool> refreshSession() {
    final inFlight = _refreshRequest;
    if (inFlight != null) {
      return inFlight;
    }

    final request = _performRefresh();
    _refreshRequest = request;
    request.whenComplete(() {
      if (identical(_refreshRequest, request)) {
        _refreshRequest = null;
      }
    });
    return request;
  }

  Future<bool> _performRefresh() async {
    final refreshToken = await _tokenStorage.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      await _tokenStorage.clearTokens();
      return false;
    }

    try {
      final response = await _refreshDio.post<Map<String, dynamic>>(
        '/v1/auth/refresh',
        data: {'refreshToken': refreshToken},
      );
      final data = response.data?['data'];
      if (data is! Map<String, dynamic>) {
        throw const FormatException('Invalid refresh response');
      }
      final accessToken = data['accessToken']?.toString() ?? '';
      final rotatedRefreshToken = data['refreshToken']?.toString() ?? '';
      if (accessToken.isEmpty || rotatedRefreshToken.isEmpty) {
        throw const FormatException('Refresh response contains empty tokens');
      }
      await _tokenStorage.saveAccessToken(accessToken);
      await _tokenStorage.saveRefreshToken(rotatedRefreshToken);
      return true;
    } on Object {
      await _tokenStorage.clearTokens();
      return false;
    }
  }
}
