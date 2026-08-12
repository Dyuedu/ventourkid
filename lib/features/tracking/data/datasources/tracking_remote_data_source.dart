import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../../core/network/dio_client.dart';
import '../../domain/models/tracker_location_view_model.dart';

class TrackingRealtimeMessage {
  const TrackingRealtimeMessage({
    required this.type,
    required this.data,
    this.id,
  });

  final String type;
  final Map<String, dynamic> data;
  final String? id;
}

class TrackingRemoteDataSource {
  TrackingRemoteDataSource(this._dioClient);

  final DioClient _dioClient;

  Object? _unwrap(Object? response) {
    if (response is Map<String, dynamic> && response.containsKey('data')) {
      return response['data'];
    }
    return response;
  }

  Future<List<TrackingOperationViewModel>> getOperations({int page = 0}) async {
    final response = await _dioClient.dio.get(
      '/v1/tracking/operations',
      queryParameters: {'page': page, 'size': 20, 'sort': 'tourDate,desc'},
    );
    final data = _unwrap(response.data);
    final content = data is Map ? data['content'] : null;
    return (content is List ? content : const [])
        .whereType<Map>()
        .map(
          (item) => TrackingOperationViewModel.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .where((item) => item.operationPlanId.isNotEmpty)
        .toList(growable: false);
  }

  Future<TrackingSnapshotViewModel> getSnapshot(String operationPlanId) async {
    final response = await _dioClient.dio.get(
      '/v1/tracking/operations/$operationPlanId/snapshot',
    );
    final data = _unwrap(response.data);
    if (data is! Map) throw const FormatException('Invalid tracking snapshot');
    return TrackingSnapshotViewModel.fromJson(Map<String, dynamic>.from(data));
  }

  Future<Response<dynamic>> getVehicleLocation(String operationPlanId) {
    return _dioClient.dio.get(
      '/v1/tracking/locations',
      queryParameters: {'operationPlanId': operationPlanId},
    );
  }

  Future<Response<dynamic>> getTargetLocation(String assignmentId) {
    return _dioClient.dio.get('/v1/tracking/locations/$assignmentId');
  }

  Future<Response<dynamic>> getRawLocation() {
    return _dioClient.dio.get(
      '/v1/tracking/raw-telemetry',
      options: Options(
        headers: {'X-Audit-Reason': 'tracking-dashboard-access'},
      ),
    );
  }

  Stream<TrackingRealtimeMessage> openRealtime(
    String operationPlanId, {
    String? lastEventId,
  }) async* {
    final ticketResponse = await _dioClient.dio.post(
      '/v1/tracking/realtime-tickets',
      data: {'operationPlanId': operationPlanId},
    );
    final ticketData = _unwrap(ticketResponse.data);
    final ticket = ticketData is Map ? ticketData['ticket']?.toString() : null;
    if (ticket == null || ticket.isEmpty) {
      throw const FormatException('Invalid realtime ticket');
    }

    final response = await _dioClient.dio.get<ResponseBody>(
      '/v1/tracking/stream',
      queryParameters: {
        'ticket': ticket,
        if (lastEventId != null && lastEventId.isNotEmpty)
          'lastEventId': lastEventId,
      },
      options: Options(
        responseType: ResponseType.stream,
        receiveTimeout: const Duration(minutes: 31),
        headers: const {'Accept': 'text/event-stream'},
      ),
    );
    final body = response.data;
    if (body == null) {
      throw const FormatException('Realtime stream has no body');
    }

    var eventType = 'message';
    String? eventId;
    final dataLines = <String>[];
    await for (final line
        in body.stream
            .cast<List<int>>()
            .transform(utf8.decoder)
            .transform(const LineSplitter())) {
      if (line.isEmpty) {
        if (dataLines.isNotEmpty) {
          final decoded = jsonDecode(dataLines.join('\n'));
          if (decoded is Map) {
            yield TrackingRealtimeMessage(
              type: eventType,
              id: eventId,
              data: Map<String, dynamic>.from(decoded),
            );
          }
        }
        eventType = 'message';
        eventId = null;
        dataLines.clear();
      } else if (line.startsWith('event:')) {
        eventType = line.substring(6).trim();
      } else if (line.startsWith('id:')) {
        eventId = line.substring(3).trim();
      } else if (line.startsWith('data:')) {
        dataLines.add(line.substring(5).trimLeft());
      }
    }
  }

  Future<void> acknowledgeAlert(String operationPlanId, String alertId) async {
    await _dioClient.dio.post(
      '/v1/tracking/operations/$operationPlanId/alerts/$alertId/acknowledge',
    );
  }

  Future<Map<String, dynamic>> previewReplacement(
    String assignmentId,
    String qrPayload,
  ) async {
    final response = await _dioClient.dio.post(
      '/v1/tracking/assignments/$assignmentId/replacement-preview',
      data: {'newDeviceQrPayload': qrPayload},
    );
    final data = _unwrap(response.data);
    if (data is! Map) {
      throw const FormatException('Phản hồi xem trước thay thiết bị không hợp lệ');
    }
    return Map<String, dynamic>.from(data);
  }

  Future<void> replaceDevice({
    required String assignmentId,
    required String qrPayload,
    required String reason,
  }) async {
    await _dioClient.dio.post(
      '/v1/tracking/assignments/$assignmentId/replace-device',
      data: {'newDeviceQrPayload': qrPayload, 'reason': reason},
    );
  }

  Future<void> syncOfflineCommands(List<Map<String, dynamic>> commands) async {
    await _dioClient.dio.post('/v1/offline/sync', data: {'commands': commands});
  }

}
