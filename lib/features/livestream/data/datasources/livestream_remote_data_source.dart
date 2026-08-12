import '../models/livestream_replay_models.dart';
import '../models/livestream_setup_models.dart';
import '../models/livestream_token_model.dart';

abstract interface class LivestreamRemoteDataSource {
  Future<LivestreamSetupOptions> getGuideSetupOptions({required String tourId});

  Future<List<ParentActiveLivestream>> getParentActiveLivestreams();

  Future<List<ParentActiveLivestream>> getActiveLivestreams({String? tourId});

  Future<LivestreamTokenModel> startLivestream({
    required String planItemId,
    required String tourId,
    required String operationVehicleId,
    required String checkpointId,
    required String title,
    String? description,
    String? thumbnailUrl,
    String audienceScope,
    List<String>? audienceVehicleIds,
  });

  Future<LivestreamTokenModel> getViewerToken({
    required String tourId,
    String? sessionId,
  });

  Future<void> stopLivestream({required String tourId});

  Future<void> sendInteraction({
    required String sessionId,
    required String type,
    required String payload,
    String? senderName,
    String? senderRole,
  });

  Future<List<LivestreamReplaySession>> getReplaySessions({
    required String tourId,
  });

  Future<LivestreamReplayUrl> getReplayPresignedUrl({
    required String sessionId,
  });
}
