// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'livestream_token_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

LivestreamTokenModel _$LivestreamTokenModelFromJson(Map<String, dynamic> json) {
  return _LivestreamTokenModel.fromJson(json);
}

/// @nodoc
mixin _$LivestreamTokenModel {
  String get sessionId => throw _privateConstructorUsedError;
  String get token => throw _privateConstructorUsedError;
  String get wsUrl => throw _privateConstructorUsedError;

  /// Serializes this LivestreamTokenModel to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of LivestreamTokenModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $LivestreamTokenModelCopyWith<LivestreamTokenModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $LivestreamTokenModelCopyWith<$Res> {
  factory $LivestreamTokenModelCopyWith(
    LivestreamTokenModel value,
    $Res Function(LivestreamTokenModel) then,
  ) = _$LivestreamTokenModelCopyWithImpl<$Res, LivestreamTokenModel>;
  @useResult
  $Res call({String sessionId, String token, String wsUrl});
}

/// @nodoc
class _$LivestreamTokenModelCopyWithImpl<
  $Res,
  $Val extends LivestreamTokenModel
>
    implements $LivestreamTokenModelCopyWith<$Res> {
  _$LivestreamTokenModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of LivestreamTokenModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? sessionId = null,
    Object? token = null,
    Object? wsUrl = null,
  }) {
    return _then(
      _value.copyWith(
            sessionId: null == sessionId
                ? _value.sessionId
                : sessionId // ignore: cast_nullable_to_non_nullable
                      as String,
            token: null == token
                ? _value.token
                : token // ignore: cast_nullable_to_non_nullable
                      as String,
            wsUrl: null == wsUrl
                ? _value.wsUrl
                : wsUrl // ignore: cast_nullable_to_non_nullable
                      as String,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$LivestreamTokenModelImplCopyWith<$Res>
    implements $LivestreamTokenModelCopyWith<$Res> {
  factory _$$LivestreamTokenModelImplCopyWith(
    _$LivestreamTokenModelImpl value,
    $Res Function(_$LivestreamTokenModelImpl) then,
  ) = __$$LivestreamTokenModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String sessionId, String token, String wsUrl});
}

/// @nodoc
class __$$LivestreamTokenModelImplCopyWithImpl<$Res>
    extends _$LivestreamTokenModelCopyWithImpl<$Res, _$LivestreamTokenModelImpl>
    implements _$$LivestreamTokenModelImplCopyWith<$Res> {
  __$$LivestreamTokenModelImplCopyWithImpl(
    _$LivestreamTokenModelImpl _value,
    $Res Function(_$LivestreamTokenModelImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of LivestreamTokenModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? sessionId = null,
    Object? token = null,
    Object? wsUrl = null,
  }) {
    return _then(
      _$LivestreamTokenModelImpl(
        sessionId: null == sessionId
            ? _value.sessionId
            : sessionId // ignore: cast_nullable_to_non_nullable
                  as String,
        token: null == token
            ? _value.token
            : token // ignore: cast_nullable_to_non_nullable
                  as String,
        wsUrl: null == wsUrl
            ? _value.wsUrl
            : wsUrl // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$LivestreamTokenModelImpl implements _LivestreamTokenModel {
  const _$LivestreamTokenModelImpl({
    required this.sessionId,
    required this.token,
    required this.wsUrl,
  });

  factory _$LivestreamTokenModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$LivestreamTokenModelImplFromJson(json);

  @override
  final String sessionId;
  @override
  final String token;
  @override
  final String wsUrl;

  @override
  String toString() {
    return 'LivestreamTokenModel(sessionId: $sessionId, token: $token, wsUrl: $wsUrl)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$LivestreamTokenModelImpl &&
            (identical(other.sessionId, sessionId) ||
                other.sessionId == sessionId) &&
            (identical(other.token, token) || other.token == token) &&
            (identical(other.wsUrl, wsUrl) || other.wsUrl == wsUrl));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, sessionId, token, wsUrl);

  /// Create a copy of LivestreamTokenModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$LivestreamTokenModelImplCopyWith<_$LivestreamTokenModelImpl>
  get copyWith =>
      __$$LivestreamTokenModelImplCopyWithImpl<_$LivestreamTokenModelImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$LivestreamTokenModelImplToJson(this);
  }
}

abstract class _LivestreamTokenModel implements LivestreamTokenModel {
  const factory _LivestreamTokenModel({
    required final String sessionId,
    required final String token,
    required final String wsUrl,
  }) = _$LivestreamTokenModelImpl;

  factory _LivestreamTokenModel.fromJson(Map<String, dynamic> json) =
      _$LivestreamTokenModelImpl.fromJson;

  @override
  String get sessionId;
  @override
  String get token;
  @override
  String get wsUrl;

  /// Create a copy of LivestreamTokenModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$LivestreamTokenModelImplCopyWith<_$LivestreamTokenModelImpl>
  get copyWith => throw _privateConstructorUsedError;
}
