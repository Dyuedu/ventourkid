// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'livestream_token_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$LivestreamTokenModelImpl _$$LivestreamTokenModelImplFromJson(
  Map<String, dynamic> json,
) => _$LivestreamTokenModelImpl(
  sessionId: json['sessionId'] as String,
  token: json['token'] as String,
  wsUrl: json['wsUrl'] as String,
);

Map<String, dynamic> _$$LivestreamTokenModelImplToJson(
  _$LivestreamTokenModelImpl instance,
) => <String, dynamic>{
  'sessionId': instance.sessionId,
  'token': instance.token,
  'wsUrl': instance.wsUrl,
};
