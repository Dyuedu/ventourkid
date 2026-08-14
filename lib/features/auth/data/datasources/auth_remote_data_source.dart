import 'package:dio/dio.dart';

import '../../../../core/network/dio_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../domain/entities/register_draft.dart';
import '../models/accept_invitation_model.dart';
import '../models/auth_tokens_model.dart';

abstract interface class AuthRemoteDataSource {
  Future<void> sendRegisterOtp({required String identifier});

  Future<void> sendPasswordResetOtp({required String email});

  Future<void> resetPassword({
    required String email,
    required String otpCode,
    required String newPassword,
    required String confirmPassword,
  });

  Future<void> register(RegisterDraft draft, String otpCode);

  Future<AuthTokensModel> login({
    required String identifier,
    required String password,
    String? deviceId,
  });

  Future<AuthTokensModel> googleLogin({
    required String googleToken,
    String? deviceId,
  });

  Future<AcceptInvitationModel> acceptInvitation({required String token});

  Future<AuthTokensModel> setInvitationPassword({
    required String challengeToken,
    required String newPassword,
    required String confirmPassword,
    String? deviceId,
  });

  Future<void> validateSession();

  Future<void> logout({required String? refreshToken});
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  const AuthRemoteDataSourceImpl(this._dioClient);

  final DioClient _dioClient;

  @override
  Future<void> sendRegisterOtp({required String identifier}) async {
    await _dioClient.dio.post<void>(
      '/v1/auth/register/otp/send',
      data: {'identifier': identifier},
      options: Options(extra: const {'skipAuthRefresh': true}),
    );
  }

  @override
  Future<void> sendPasswordResetOtp({required String email}) async {
    await _dioClient.dio.post<void>(
      '/v1/auth/password-reset/otp/send',
      data: {'email': email},
      options: Options(extra: const {'skipAuthRefresh': true}),
    );
  }

  @override
  Future<void> resetPassword({
    required String email,
    required String otpCode,
    required String newPassword,
    required String confirmPassword,
  }) async {
    await _dioClient.dio.post<void>(
      '/v1/auth/password-reset',
      data: {
        'email': email,
        'otpCode': otpCode,
        'newPassword': newPassword,
        'confirmPassword': confirmPassword,
      },
      options: Options(extra: const {'skipAuthRefresh': true}),
    );
  }

  @override
  Future<void> register(RegisterDraft draft, String otpCode) async {
    await _dioClient.dio.post<void>(
      '/v1/auth/register',
      data: {
        'identifier': draft.identifier,
        'fullName': draft.fullName,
        'password': draft.password,
        'otpCode': otpCode,
        'termsAccepted': draft.termsAccepted,
      },
      options: Options(extra: const {'skipAuthRefresh': true}),
    );
  }

  @override
  Future<AuthTokensModel> login({
    required String identifier,
    required String password,
    String? deviceId,
  }) async {
    final response = await _dioClient.dio.post<Map<String, dynamic>>(
      '/v1/auth/login',
      data: {
        'identifier': identifier,
        'password': password,
        if (deviceId != null && deviceId.isNotEmpty) 'deviceId': deviceId,
      },
      options: Options(extra: const {'skipAuthRefresh': true}),
    );

    return _tokensFromResponse(
      response,
      fallbackMessage: 'Invalid login response',
    );
  }

  @override
  Future<AuthTokensModel> googleLogin({
    required String googleToken,
    String? deviceId,
  }) async {
    final response = await _dioClient.dio.post<Map<String, dynamic>>(
      '/v1/auth/google-login',
      data: {
        'googleToken': googleToken,
        if (deviceId != null && deviceId.isNotEmpty) 'deviceId': deviceId,
      },
      options: Options(extra: const {'skipAuthRefresh': true}),
    );

    return _tokensFromResponse(
      response,
      fallbackMessage: 'Invalid google login response',
    );
  }

  @override
  Future<AcceptInvitationModel> acceptInvitation({required String token}) async {
    final response = await _dioClient.dio.post<Map<String, dynamic>>(
      '/v1/auth/invitations/accept',
      data: {'token': token},
      options: Options(extra: const {'skipAuthRefresh': true}),
    );

    final body = response.data;
    if (body != null && body['success'] == false) {
      throw ApiException(
        statusCode: int.tryParse(body['status']?.toString() ?? ''),
        details: body,
        message: body['message']?.toString() ?? 'Không thể chấp nhận lời mời.',
      );
    }
    final data = body == null ? null : body['data'];
    if (data is! Map<String, dynamic>) {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        message: 'Invalid invitation accept response',
      );
    }
    return AcceptInvitationModel.fromJson(data);
  }

  @override
  Future<AuthTokensModel> setInvitationPassword({
    required String challengeToken,
    required String newPassword,
    required String confirmPassword,
    String? deviceId,
  }) async {
    final response = await _dioClient.dio.post<Map<String, dynamic>>(
      '/v1/auth/invitations/set-password',
      data: {
        'challengeToken': challengeToken,
        'newPassword': newPassword,
        'confirmPassword': confirmPassword,
      },
      options: Options(
        extra: const {'skipAuthRefresh': true},
        headers: {
          if (deviceId != null && deviceId.isNotEmpty) 'X-Device-Id': deviceId,
        },
      ),
    );

    return _tokensFromResponse(
      response,
      fallbackMessage: 'Invalid invitation set-password response',
    );
  }

  @override
  Future<void> validateSession() async {
    await _dioClient.dio.get<void>('/v1/auth/session');
  }

  @override
  Future<void> logout({required String? refreshToken}) async {
    await _dioClient.dio.post<void>(
      '/v1/auth/logout',
      data: refreshToken == null ? null : {'refreshToken': refreshToken},
      options: Options(extra: const {'skipAuthRefresh': true}),
    );
  }

  AuthTokensModel _tokensFromResponse(
    Response<Map<String, dynamic>> response, {
    required String fallbackMessage,
  }) {
    final body = response.data;
    if (body != null && body['success'] == false) {
      throw ApiException(
        statusCode: int.tryParse(body['status']?.toString() ?? ''),
        details: body,
        message: body['message']?.toString() ?? fallbackMessage,
      );
    }

    final data = body == null ? null : body['data'];
    if (data is! Map<String, dynamic>) {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        message: fallbackMessage,
      );
    }

    return AuthTokensModel.fromJson(data);
  }
}
