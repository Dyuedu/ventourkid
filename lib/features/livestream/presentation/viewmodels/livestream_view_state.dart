import 'package:freezed_annotation/freezed_annotation.dart';

part 'livestream_view_state.freezed.dart';

@freezed
class LivestreamViewState with _$LivestreamViewState {
  const factory LivestreamViewState({
    @Default(false) bool isLoading,
    @Default(false) bool isLive,
    String? token,
    String? wsUrl,
    String? sessionId,
    String? errorMessage,
  }) = _LivestreamViewState;
}
