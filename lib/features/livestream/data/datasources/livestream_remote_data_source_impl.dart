import '../../../../core/network/dio_client.dart';
import '../models/livestream_replay_models.dart';
import '../models/livestream_setup_models.dart';
import '../models/livestream_token_model.dart';
import 'livestream_remote_data_source.dart';

class LivestreamRemoteDataSourceImpl implements LivestreamRemoteDataSource {
  LivestreamRemoteDataSourceImpl(this._dio);

  final DioClient _dio;

  @override
  Future<LivestreamSetupOptions> getGuideSetupOptions({
    required String tourId,
  }) async {
    final response = await _dio.dio.get(
      '/v1/livestreams/guides/setup-options',
      queryParameters: {'tourId': tourId},
    );
    return LivestreamSetupOptions.fromJson(
      Map<String, dynamic>.from(response.data['data'] as Map),
    );
  }

  @override
  Future<List<ParentActiveLivestream>> getParentActiveLivestreams() async {
    final response = await _dio.dio.get('/v1/parent/livestreams/active');
    final list = response.data['data'] as List<dynamic>? ?? [];
    return list
        .map(
          (e) => ParentActiveLivestream.fromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();
  }

  @override
  Future<List<ParentActiveLivestream>> getActiveLivestreams({
    String? tourId,
  }) async {
    final response = await _dio.dio.get(
      '/v1/livestreams/active',
      queryParameters: tourId == null || tourId.isEmpty
          ? null
          : {'tourId': tourId},
    );
    final list = response.data['data'] as List<dynamic>? ?? [];
    return list.map((e) {
      final json = Map<String, dynamic>.from(e as Map);
      json['sessionId'] = json['sessionId'] ?? json['id'];
      return ParentActiveLivestream.fromJson(json);
    }).toList();
  }

  @override
  Future<LivestreamTokenModel> getViewerToken({
    required String tourId,
    String? sessionId,
  }) async {
    final response = await _dio.dio.get(
      '/v1/livestreams/$tourId/watch',
      queryParameters: sessionId == null ? null : {'sessionId': sessionId},
    );
    return LivestreamTokenModel.fromJson(response.data['data']);
  }

  @override
  Future<LivestreamTokenModel> startLivestream({
    required String planItemId,
    required String tourId,
    required String operationVehicleId,
    required String checkpointId,
    required String title,
    String? description,
    String? thumbnailUrl,
    String audienceScope = 'VEHICLE',
    List<String>? audienceVehicleIds,
  }) async {
    final data = <String, dynamic>{
      'planItemId': planItemId,
      'tourId': tourId,
      'operationVehicleId': operationVehicleId,
      'checkpointId': checkpointId,
      'audienceScope': audienceScope,
      'title': title,
    };
    if (description != null) data['description'] = description;
    if (thumbnailUrl != null) data['thumbnailUrl'] = thumbnailUrl;
    if (audienceVehicleIds != null && audienceVehicleIds.isNotEmpty) {
      data['audienceVehicleIds'] = audienceVehicleIds;
    }
    final response = await _dio.dio.post('/v1/livestreams/start', data: data);
    return LivestreamTokenModel.fromJson(response.data['data']);
  }

  @override
  Future<void> stopLivestream({required String tourId}) async {
    await _dio.dio.post('/v1/livestreams/$tourId/stop');
  }

  @override
  Future<void> sendInteraction({
    required String sessionId,
    required String type,
    required String payload,
    String? senderName,
    String? senderRole,
  }) async {
    final data = <String, dynamic>{
      'sessionId': sessionId,
      'type': type,
      'payload': payload,
    };
    if (senderName != null) data['senderName'] = senderName;
    if (senderRole != null) data['senderRole'] = senderRole;
    await _dio.dio.post('/v1/livestreams/interactions', data: data);
  }

  @override
  Future<List<LivestreamReplaySession>> getReplaySessions({
    required String tourId,
  }) async {
    final response = await _dio.dio.get('/v1/livestreams/$tourId/replays');
    final list = response.data['data'] as List<dynamic>? ?? [];
    return list
        .map(
          (e) => LivestreamReplaySession.fromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();
  }

  @override
  Future<LivestreamReplayUrl> getReplayPresignedUrl({
    required String sessionId,
  }) async {
    final response = await _dio.dio.get(
      '/v1/livestreams/sessions/$sessionId/replay-url',
    );
    return LivestreamReplayUrl.fromJson(
      Map<String, dynamic>.from(response.data['data'] as Map),
    );
  }
}
