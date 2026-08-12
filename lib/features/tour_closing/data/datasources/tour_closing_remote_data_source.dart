import '../../../../core/network/dio_client.dart';

class TourClosingRemoteDataSource {
  TourClosingRemoteDataSource(this._dio);

  final DioClient _dio;

  String _base(String planId) => '/v1/operation-plans/$planId/closing';

  Future<Map<String, dynamic>> getChecklist(String planId) async {
    final response = await _dio.dio.get(_base(planId));
    return Map<String, dynamic>.from(response.data['data'] as Map);
  }

  Future<Map<String, dynamic>> getReadyCheck(String planId) async {
    final response = await _dio.dio.get('${_base(planId)}/ready-check');
    return Map<String, dynamic>.from(response.data['data'] as Map);
  }

  Future<Map<String, dynamic>> confirmFinalAttendance(
    String planId,
    String sessionId,
  ) async {
    final response = await _dio.dio.post(
      '${_base(planId)}/final-attendance',
      data: {'sessionId': sessionId},
    );
    return Map<String, dynamic>.from(response.data['data'] as Map);
  }

  Future<Map<String, dynamic>> confirmHandover(
    String planId,
    String operationVehicleId,
  ) async {
    final response = await _dio.dio.post(
      '${_base(planId)}/handover',
      data: {'operationVehicleId': operationVehicleId},
    );
    return Map<String, dynamic>.from(response.data['data'] as Map);
  }

  Future<Map<String, dynamic>> returnDevices(
    String planId, {
    List<String>? deviceCodes,
    List<String>? assignmentIds,
    String? qrPayload,
  }) async {
    final response = await _dio.dio.post(
      '${_base(planId)}/devices/return',
      data: {
        if (deviceCodes != null) 'deviceCodes': deviceCodes,
        if (assignmentIds != null) 'assignmentIds': assignmentIds,
        if (qrPayload != null && qrPayload.isNotEmpty) 'qrPayload': qrPayload,
      },
    );
    return Map<String, dynamic>.from(response.data['data'] as Map);
  }

  Future<Map<String, dynamic>> inspectDevices(String planId) async {
    final response = await _dio.dio.post('${_base(planId)}/devices/inspect');
    return Map<String, dynamic>.from(response.data['data'] as Map);
  }

  Future<Map<String, dynamic>> refreshIncidents(String planId) async {
    final response = await _dio.dio.post('${_base(planId)}/incidents/refresh');
    return Map<String, dynamic>.from(response.data['data'] as Map);
  }

  /// Parent / SchoolRep / Teacher post-tour feedback (BR-107).
  Future<Map<String, dynamic>> submitFeedback(
    String planId, {
    required int rating,
    String? comment,
    String targetType = 'TOUR',
  }) async {
    final response = await _dio.dio.post(
      '${_base(planId)}/feedback',
      data: {
        'rating': rating,
        if (comment != null) 'comment': comment,
        'targetType': targetType,
      },
    );
    return Map<String, dynamic>.from(response.data['data'] as Map);
  }
}
