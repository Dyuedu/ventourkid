import 'package:freezed_annotation/freezed_annotation.dart';

part 'livestream_token_model.freezed.dart';
part 'livestream_token_model.g.dart';

@freezed
class LivestreamTokenModel with _$LivestreamTokenModel {
  const factory LivestreamTokenModel({
    required String sessionId,
    required String token,
    required String wsUrl,
  }) = _LivestreamTokenModel;

  factory LivestreamTokenModel.fromJson(Map<String, dynamic> json) =>
      _$LivestreamTokenModelFromJson(json);
}
