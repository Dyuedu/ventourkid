import '../../data/datasources/livestream_remote_data_source.dart';
import '../../data/models/livestream_replay_models.dart';
import '../../data/models/livestream_setup_models.dart';
import '../../data/models/livestream_token_model.dart';
import '../../domain/repositories/livestream_repository.dart';

class LivestreamRepositoryImpl implements LivestreamRepository {
  LivestreamRepositoryImpl({
    required LivestreamRemoteDataSource remoteDataSource,
  }) : _remoteDataSource = remoteDataSource;

  final LivestreamRemoteDataSource _remoteDataSource;

  @override
  Future<LivestreamSetupOptions> getGuideSetupOptions({
    required String tourId,
  }) => _remoteDataSource.getGuideSetupOptions(tourId: tourId);

  @override
  Future<List<ParentActiveLivestream>> getParentActiveLivestreams() =>
      _remoteDataSource.getParentActiveLivestreams();

  @override
  Future<List<ParentActiveLivestream>> getActiveLivestreams({String? tourId}) =>
      _remoteDataSource.getActiveLivestreams(tourId: tourId);

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
    return await _remoteDataSource.startLivestream(
      planItemId: planItemId,
      tourId: tourId,
      operationVehicleId: operationVehicleId,
      checkpointId: checkpointId,
      title: title,
      description: description,
      thumbnailUrl: thumbnailUrl,
      audienceScope: audienceScope,
      audienceVehicleIds: audienceVehicleIds,
    );
  }

  @override
  Future<LivestreamTokenModel> getViewerToken({
    required String tourId,
    String? sessionId,
  }) => _remoteDataSource.getViewerToken(tourId: tourId, sessionId: sessionId);

  @override
  Future<void> stopLivestream({required String tourId}) async {
    await _remoteDataSource.stopLivestream(tourId: tourId);
  }

  @override
  Future<void> sendInteraction({
    required String sessionId,
    required String type,
    required String payload,
    String? senderName,
    String? senderRole,
  }) async {
    await _remoteDataSource.sendInteraction(
      sessionId: sessionId,
      type: type,
      payload: payload,
      senderName: senderName,
      senderRole: senderRole,
    );
  }

  @override
  Future<List<LivestreamReplaySession>> getReplaySessions({
    required String tourId,
  }) => _remoteDataSource.getReplaySessions(tourId: tourId);

  @override
  Future<LivestreamReplayUrl> getReplayPresignedUrl({
    required String sessionId,
  }) => _remoteDataSource.getReplayPresignedUrl(sessionId: sessionId);
}
