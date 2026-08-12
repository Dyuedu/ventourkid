import '../../../../core/network/dio_client.dart';
import '../models/parent_dashboard_api_models.dart';
import 'parent_dashboard_remote_data_source.dart';

class ParentDashboardRemoteDataSourceImpl
    implements ParentDashboardRemoteDataSource {
  ParentDashboardRemoteDataSourceImpl(this._dio);

  final DioClient _dio;

  @override
  Future<List<LinkedChildModel>> getLinkedChildren() async {
    final response = await _dio.dio.get('/v1/parents/children');
    final list = response.data['data'] as List<dynamic>? ?? [];
    return list
        .map(
          (e) => LinkedChildModel.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .where((child) => child.rosterStudentId.isNotEmpty)
        .toList();
  }

  @override
  Future<ParentCurrentTourModel?> getCurrentTour({
    required String rosterStudentId,
    String? tourId,
  }) async {
    final response = await _dio.dio.get(
      '/v1/parents/children/$rosterStudentId/tours/current',
      queryParameters: {
        if (tourId != null && tourId.isNotEmpty) 'tourId': tourId,
      },
    );
    final raw = response.data['data'];
    if (raw is! Map) return null;
    final tour = ParentCurrentTourModel.fromJson(
      Map<String, dynamic>.from(raw),
    );
    return tour.isEmpty ? null : tour;
  }

  @override
  Future<ParentConsentOtpModel> sendTripConsentOtp({
    required String rosterStudentId,
    required String operationPlanId,
  }) async {
    final response = await _dio.dio.post(
      '/v1/parents/children/$rosterStudentId/trip-consents/otp',
      queryParameters: {'operationPlanId': operationPlanId},
    );
    final raw = Map<String, dynamic>.from(response.data['data'] as Map);
    return ParentConsentOtpModel.fromJson(raw);
  }

  @override
  Future<void> submitTripConsents({
    required String rosterStudentId,
    required String operationPlanId,
    required String otpCode,
    required Map<String, bool> scopes,
    required bool acceptedMandatoryTerms,
  }) async {
    await _dio.dio.post(
      '/v1/parents/children/$rosterStudentId/trip-consents',
      data: {
        'operationPlanId': operationPlanId,
        'noticeVersion': 'trip-consent-v1',
        'otpCode': otpCode,
        'scopes': scopes,
        'acceptedMandatoryTerms': acceptedMandatoryTerms,
      },
    );
  }

  @override
  Future<Map<String, bool>> getTripConsents({
    required String rosterStudentId,
    required String operationPlanId,
  }) async {
    final response = await _dio.dio.get(
      '/v1/parents/children/$rosterStudentId/trip-consents',
      queryParameters: {'operationPlanId': operationPlanId},
    );
    final rows = response.data['data'] as List<dynamic>? ?? const [];
    return {
      for (final row in rows.whereType<Map>())
        if (row['scope'] != null)
          row['scope'].toString(): row['authorized'] == true,
    };
  }

  @override
  Future<List<Map<String, dynamic>>> getTourHistory({
    required String rosterStudentId,
    int? year,
  }) async {
    final response = await _dio.dio.get(
      '/v1/parents/children/$rosterStudentId/tours/history',
      queryParameters: {if (year != null) 'year': year},
    );
    final list = response.data['data'] as List<dynamic>? ?? const [];
    return list
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  @override
  Future<Map<String, dynamic>> listChildTours({
    required String rosterStudentId,
    int? year,
  }) async {
    final response = await _dio.dio.get(
      '/v1/parents/children/$rosterStudentId/tours',
      queryParameters: {if (year != null) 'year': year},
    );
    final raw = response.data['data'];
    if (raw is! Map) {
      return const {
        'upcoming': <Map<String, dynamic>>[],
        'live': <Map<String, dynamic>>[],
        'past': <Map<String, dynamic>>[],
        'active': <Map<String, dynamic>>[],
      };
    }
    Map<String, dynamic> asMap(Object? value) =>
        value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
    List<Map<String, dynamic>> asList(Object? value) =>
        (value is List ? value : const [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
    final data = asMap(raw);
    return {
      'upcoming': asList(data['upcoming']),
      'live': asList(data['live']),
      'past': asList(data['past']),
      'active': asList(data['active']),
    };
  }

  @override
  Future<Map<String, dynamic>> getChildMedia({
    required String rosterStudentId,
    String? tourId,
    int page = 0,
    int size = 48,
  }) async {
    final response = await _dio.dio.get(
      '/v1/parents/children/$rosterStudentId/media',
      queryParameters: {
        if (tourId != null && tourId.isNotEmpty) 'tourId': tourId,
        'page': page,
        'size': size,
      },
    );
    final raw = response.data['data'];
    if (raw is! Map) {
      return const {'total': 0, 'media': <Map<String, dynamic>>[]};
    }
    final data = Map<String, dynamic>.from(raw);
    final media = (data['media'] is List ? data['media'] as List : const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final total = data['total'];
    return {
      'total': total is num ? total.toInt() : media.length,
      'media': media,
    };
  }
}
