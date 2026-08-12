import '../../../../core/network/dio_client.dart';
import '../models/parent_link_api_models.dart';
import 'parent_link_remote_data_source.dart';

class ParentLinkRemoteDataSourceImpl implements ParentLinkRemoteDataSource {
  ParentLinkRemoteDataSourceImpl(this._dio);

  final DioClient _dio;

  @override
  Future<ParentLinkPrerequisitesModel> getPrerequisites() async {
    final response = await _dio.dio.get('/v1/parents/link-child/prerequisites');
    final raw = response.data['data'];
    if (raw is! Map) {
      throw const FormatException('Invalid prerequisites response');
    }
    return ParentLinkPrerequisitesModel.fromJson(
      Map<String, dynamic>.from(raw),
    );
  }

  @override
  Future<List<TripLinkActivityModel>> getTripLinkCandidates() async {
    final response = await _dio.dio.get('/v1/parents/trip-links/candidates');
    final list = response.data['data'] as List<dynamic>? ?? [];
    return list
        .map(
          (item) => TripLinkActivityModel.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .where((activity) => activity.operationPlanId.isNotEmpty)
        .toList();
  }

  @override
  Future<TripLinkOtpResultModel> sendTripLinkOtp({
    required String operationPlanId,
    required TripLinkStudentMatchRequest request,
  }) async {
    final response = await _dio.dio.post(
      '/v1/parents/trip-links/activities/$operationPlanId/otp',
      data: request.toJson(),
    );
    final raw = response.data['data'];
    if (raw is! Map) {
      throw const FormatException('Invalid OTP response');
    }
    return TripLinkOtpResultModel.fromJson(Map<String, dynamic>.from(raw));
  }

  @override
  Future<void> verifyTripLinkOtp({
    required String rosterStudentId,
    required String otpCode,
  }) async {
    await _dio.dio.post(
      '/v1/parents/trip-links/$rosterStudentId/verify',
      data: {'otpCode': otpCode},
    );
  }
}
