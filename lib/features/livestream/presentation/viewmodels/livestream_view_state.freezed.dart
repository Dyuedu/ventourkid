// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'livestream_view_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$LivestreamViewState {
  bool get isLoading => throw _privateConstructorUsedError;
  bool get isLive => throw _privateConstructorUsedError;
  String? get token => throw _privateConstructorUsedError;
  String? get wsUrl => throw _privateConstructorUsedError;
  String? get sessionId => throw _privateConstructorUsedError;
  String? get errorMessage => throw _privateConstructorUsedError;

  /// Create a copy of LivestreamViewState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $LivestreamViewStateCopyWith<LivestreamViewState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $LivestreamViewStateCopyWith<$Res> {
  factory $LivestreamViewStateCopyWith(
    LivestreamViewState value,
    $Res Function(LivestreamViewState) then,
  ) = _$LivestreamViewStateCopyWithImpl<$Res, LivestreamViewState>;
  @useResult
  $Res call({
    bool isLoading,
    bool isLive,
    String? token,
    String? wsUrl,
    String? sessionId,
    String? errorMessage,
  });
}

/// @nodoc
class _$LivestreamViewStateCopyWithImpl<$Res, $Val extends LivestreamViewState>
    implements $LivestreamViewStateCopyWith<$Res> {
  _$LivestreamViewStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of LivestreamViewState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? isLoading = null,
    Object? isLive = null,
    Object? token = freezed,
    Object? wsUrl = freezed,
    Object? sessionId = freezed,
    Object? errorMessage = freezed,
  }) {
    return _then(
      _value.copyWith(
            isLoading: null == isLoading
                ? _value.isLoading
                : isLoading // ignore: cast_nullable_to_non_nullable
                      as bool,
            isLive: null == isLive
                ? _value.isLive
                : isLive // ignore: cast_nullable_to_non_nullable
                      as bool,
            token: freezed == token
                ? _value.token
                : token // ignore: cast_nullable_to_non_nullable
                      as String?,
            wsUrl: freezed == wsUrl
                ? _value.wsUrl
                : wsUrl // ignore: cast_nullable_to_non_nullable
                      as String?,
            sessionId: freezed == sessionId
                ? _value.sessionId
                : sessionId // ignore: cast_nullable_to_non_nullable
                      as String?,
            errorMessage: freezed == errorMessage
                ? _value.errorMessage
                : errorMessage // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$LivestreamViewStateImplCopyWith<$Res>
    implements $LivestreamViewStateCopyWith<$Res> {
  factory _$$LivestreamViewStateImplCopyWith(
    _$LivestreamViewStateImpl value,
    $Res Function(_$LivestreamViewStateImpl) then,
  ) = __$$LivestreamViewStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    bool isLoading,
    bool isLive,
    String? token,
    String? wsUrl,
    String? sessionId,
    String? errorMessage,
  });
}

/// @nodoc
class __$$LivestreamViewStateImplCopyWithImpl<$Res>
    extends _$LivestreamViewStateCopyWithImpl<$Res, _$LivestreamViewStateImpl>
    implements _$$LivestreamViewStateImplCopyWith<$Res> {
  __$$LivestreamViewStateImplCopyWithImpl(
    _$LivestreamViewStateImpl _value,
    $Res Function(_$LivestreamViewStateImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of LivestreamViewState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? isLoading = null,
    Object? isLive = null,
    Object? token = freezed,
    Object? wsUrl = freezed,
    Object? sessionId = freezed,
    Object? errorMessage = freezed,
  }) {
    return _then(
      _$LivestreamViewStateImpl(
        isLoading: null == isLoading
            ? _value.isLoading
            : isLoading // ignore: cast_nullable_to_non_nullable
                  as bool,
        isLive: null == isLive
            ? _value.isLive
            : isLive // ignore: cast_nullable_to_non_nullable
                  as bool,
        token: freezed == token
            ? _value.token
            : token // ignore: cast_nullable_to_non_nullable
                  as String?,
        wsUrl: freezed == wsUrl
            ? _value.wsUrl
            : wsUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
        sessionId: freezed == sessionId
            ? _value.sessionId
            : sessionId // ignore: cast_nullable_to_non_nullable
                  as String?,
        errorMessage: freezed == errorMessage
            ? _value.errorMessage
            : errorMessage // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc

class _$LivestreamViewStateImpl implements _LivestreamViewState {
  const _$LivestreamViewStateImpl({
    this.isLoading = false,
    this.isLive = false,
    this.token,
    this.wsUrl,
    this.sessionId,
    this.errorMessage,
  });

  @override
  @JsonKey()
  final bool isLoading;
  @override
  @JsonKey()
  final bool isLive;
  @override
  final String? token;
  @override
  final String? wsUrl;
  @override
  final String? sessionId;
  @override
  final String? errorMessage;

  @override
  String toString() {
    return 'LivestreamViewState(isLoading: $isLoading, isLive: $isLive, token: $token, wsUrl: $wsUrl, sessionId: $sessionId, errorMessage: $errorMessage)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$LivestreamViewStateImpl &&
            (identical(other.isLoading, isLoading) ||
                other.isLoading == isLoading) &&
            (identical(other.isLive, isLive) || other.isLive == isLive) &&
            (identical(other.token, token) || other.token == token) &&
            (identical(other.wsUrl, wsUrl) || other.wsUrl == wsUrl) &&
            (identical(other.sessionId, sessionId) ||
                other.sessionId == sessionId) &&
            (identical(other.errorMessage, errorMessage) ||
                other.errorMessage == errorMessage));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    isLoading,
    isLive,
    token,
    wsUrl,
    sessionId,
    errorMessage,
  );

  /// Create a copy of LivestreamViewState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$LivestreamViewStateImplCopyWith<_$LivestreamViewStateImpl> get copyWith =>
      __$$LivestreamViewStateImplCopyWithImpl<_$LivestreamViewStateImpl>(
        this,
        _$identity,
      );
}

abstract class _LivestreamViewState implements LivestreamViewState {
  const factory _LivestreamViewState({
    final bool isLoading,
    final bool isLive,
    final String? token,
    final String? wsUrl,
    final String? sessionId,
    final String? errorMessage,
  }) = _$LivestreamViewStateImpl;

  @override
  bool get isLoading;
  @override
  bool get isLive;
  @override
  String? get token;
  @override
  String? get wsUrl;
  @override
  String? get sessionId;
  @override
  String? get errorMessage;

  /// Create a copy of LivestreamViewState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$LivestreamViewStateImplCopyWith<_$LivestreamViewStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
