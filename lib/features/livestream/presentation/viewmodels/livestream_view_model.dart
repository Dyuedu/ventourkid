import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_failure.dart';
import '../../domain/repositories/livestream_repository.dart';
import 'livestream_view_state.dart';

class LivestreamViewModel extends StateNotifier<LivestreamViewState> {
  LivestreamViewModel(this._repository) : super(const LivestreamViewState());

  final LivestreamRepository _repository;

  Future<bool> startLivestream(
    String planItemId,
    String tourId,
    String operationVehicleId,
    String checkpointId,
    String title,
    String? description,
    String? thumbnailUrl, {
    String audienceScope = 'VEHICLE',
    List<String>? audienceVehicleIds,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final model = await _repository.startLivestream(
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
      state = state.copyWith(
        isLoading: false,
        token: model.token,
        wsUrl: model.wsUrl,
        sessionId: model.sessionId,
        isLive: true,
      );
      return true;
    } on AppFailure catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> stopLivestream(String tourId) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _repository.stopLivestream(tourId: tourId);
      state = state.copyWith(
        isLoading: false,
        isLive: false,
        token: null,
        wsUrl: null,
      );
      return true;
    } on AppFailure catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<void> sendInteraction(
    String type,
    String payload, {
    String? senderName,
    String? senderRole,
  }) async {
    if (state.sessionId == null) return;
    try {
      await _repository.sendInteraction(
        sessionId: state.sessionId!,
        type: type,
        payload: payload,
        senderName: senderName,
        senderRole: senderRole,
      );
    } catch (e) {
      // Ignore network errors for chat to not interrupt stream
      debugPrint('Error sending interaction: $e');
    }
  }
}
