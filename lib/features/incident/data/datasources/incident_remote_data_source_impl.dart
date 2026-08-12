import 'package:dio/dio.dart';

import '../../../../core/network/dio_client.dart';
import '../mappers/incident_report_payload_mapper.dart';
import '../models/incident_report_model.dart';
import 'incident_remote_data_source.dart';

/// Concrete implementation calling the backend incident API.
class IncidentRemoteDataSourceImpl implements IncidentRemoteDataSource {
  IncidentRemoteDataSourceImpl(this._dio);

  final DioClient _dio;

  static const _base = '/v1/incidents';

  IncidentReportModel _toIncidentReportModel(dynamic raw) {
    return IncidentReportModel.fromJson(
      normalizeIncidentReportPayload(Map<String, dynamic>.from(raw as Map)),
    );
  }

  @override
  Future<IncidentReportModel> createIncident(Map<String, dynamic> body) async {
    final response = await _dio.dio.post(_base, data: body);
    return _toIncidentReportModel(response.data['data']);
  }

  @override
  Future<IncidentEvidenceModel> attachEvidence(
      String incidentId, Map<String, dynamic> body) async {
    final response =
        await _dio.dio.post('$_base/$incidentId/evidence', data: body);
    return IncidentEvidenceModel.fromJson(response.data['data']);
  }

  @override
  Future<Map<String, dynamic>> uploadEvidenceFile({
    required String tourId,
    required String path,
    required String filename,
  }) async {
    final form = FormData.fromMap({
      'tourId': tourId,
      'file': await MultipartFile.fromFile(
        path,
        filename: filename,
        contentType: MultipartFile.lookupMediaType(filename),
      ),
    });
    final response = await _dio.dio.post(
      '$_base/evidence-files',
      data: form,
      options: Options(contentType: 'multipart/form-data'),
    );
    return Map<String, dynamic>.from(response.data['data'] as Map);
  }

  @override
  Future<IncidentReportModel> handleMissingStudent(
      Map<String, dynamic> body) async {
    final response =
        await _dio.dio.post('$_base/missing-student', data: body);
    return _toIncidentReportModel(response.data['data']);
  }

  @override
  Future<List<Map<String, dynamic>>> getMissingStudentCandidates(String tourId) async {
    final response = await _dio.dio.get('$_base/missing-student-candidates', queryParameters: {'tourId': tourId});
    return (response.data['data'] as List<dynamic>).map((item) => Map<String, dynamic>.from(item as Map)).toList();
  }

  @override
  Future<Map<String, dynamic>> getMissingStudentContext(String tourId, String rosterStudentId) async {
    final response = await _dio.dio.get('$_base/missing-student-context', queryParameters: {
      'tourId': tourId, 'rosterStudentId': rosterStudentId,
    });
    return Map<String, dynamic>.from(response.data['data'] as Map);
  }

  @override
  Future<Map<String, dynamic>> getMissingStudentSnapshot(String incidentId) async {
    final response = await _dio.dio.get('$_base/$incidentId/missing-student-snapshot');
    return Map<String, dynamic>.from(response.data['data'] as Map);
  }

  @override
  Future<IncidentReportModel> getIncidentById(String incidentId) async {
    final response = await _dio.dio.get('$_base/$incidentId');
    return _toIncidentReportModel(response.data['data']);
  }

  @override
  Future<List<IncidentReportModel>> getIncidentsByTour(String tourId,
      {String? status}) async {
    final response = await _dio.dio.get(_base, queryParameters: {
      'tourId': tourId,
      if (status != null) 'status': status,
    });
    final List<dynamic> items = response.data['data'];
    return items.map(_toIncidentReportModel).toList();
  }

  @override
  Future<List<IncidentReportModel>> getMyIncidents() async {
    final response = await _dio.dio.get('$_base/my');
    final List<dynamic> items = response.data['data'];
    return items.map(_toIncidentReportModel).toList();
  }

  @override
  Future<List<IncidentReportModel>> getIncidentsByStudent(
      String studentId) async {
    final response =
        await _dio.dio.get('$_base/by-student/$studentId');
    final List<dynamic> items = response.data['data'];
    return items.map(_toIncidentReportModel).toList();
  }

  @override
  Future<IncidentReportModel> resolveIncident(
    String incidentId, {
    required String resolutionNote,
  }) async {
    final response = await _dio.dio.patch(
      '$_base/$incidentId/resolve',
      data: {'resolutionNote': resolutionNote},
    );
    return _toIncidentReportModel(response.data['data']);
  }
}
