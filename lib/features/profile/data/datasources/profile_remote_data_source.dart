import '../../../../core/network/dio_client.dart';
import '../models/profile_api_model.dart';

abstract interface class ProfileRemoteDataSource {
  Future<ProfileApiModel> getOwnProfile();

  Future<ProfileApiModel> updateOwnProfile({
    String? fullName,
    String? email,
    String? phoneNumber,
    required bool includeEmail,
    required bool includePhone,
  });
}

class ProfileRemoteDataSourceImpl implements ProfileRemoteDataSource {
  const ProfileRemoteDataSourceImpl(this._dioClient);

  final DioClient _dioClient;

  @override
  Future<ProfileApiModel> getOwnProfile() async {
    final response = await _dioClient.dio.get<Map<String, dynamic>>('/v1/me/profile');
    final data = response.data?['data'];
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Invalid profile response');
    }
    return ProfileApiModel.fromJson(data);
  }

  @override
  Future<ProfileApiModel> updateOwnProfile({
    String? fullName,
    String? email,
    String? phoneNumber,
    required bool includeEmail,
    required bool includePhone,
  }) async {
    final payload = <String, dynamic>{};
    if (fullName != null) payload['fullName'] = fullName;
    if (includeEmail && email != null) payload['email'] = email;
    if (includePhone && phoneNumber != null) payload['phoneNumber'] = phoneNumber;

    final response = await _dioClient.dio.patch<Map<String, dynamic>>(
      '/v1/me/profile',
      data: payload,
    );
    final data = response.data?['data'];
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Invalid profile update response');
    }
    return ProfileApiModel.fromJson(data);
  }
}
