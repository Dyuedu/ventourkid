// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'incident_view_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$IncidentViewState {
  // ── List state ──────────────────────────────────────────────────────────
  List<IncidentReport> get incidents => throw _privateConstructorUsedError;
  bool get isLoadingList =>
      throw _privateConstructorUsedError; // ── Detail state ─────────────────────────────────────────────────────────
  IncidentReport? get selectedIncident => throw _privateConstructorUsedError;
  bool get isLoadingDetail =>
      throw _privateConstructorUsedError; // ── Create / Submit state ─────────────────────────────────────────────────
  bool get isSubmitting => throw _privateConstructorUsedError;
  bool get submitSuccess =>
      throw _privateConstructorUsedError; // ── Evidence upload ──────────────────────────────────────────────────────
  bool get isUploadingEvidence =>
      throw _privateConstructorUsedError; // ── Missing student emergency ─────────────────────────────────────────────
  bool get isMissingStudentAlertSent =>
      throw _privateConstructorUsedError; // ── Shared error ─────────────────────────────────────────────────────────
  String? get errorMessage =>
      throw _privateConstructorUsedError; // ── Active filter ────────────────────────────────────────────────────────
  IncidentStatus? get activeStatusFilter => throw _privateConstructorUsedError;

  /// Create a copy of IncidentViewState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $IncidentViewStateCopyWith<IncidentViewState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $IncidentViewStateCopyWith<$Res> {
  factory $IncidentViewStateCopyWith(
    IncidentViewState value,
    $Res Function(IncidentViewState) then,
  ) = _$IncidentViewStateCopyWithImpl<$Res, IncidentViewState>;
  @useResult
  $Res call({
    List<IncidentReport> incidents,
    bool isLoadingList,
    IncidentReport? selectedIncident,
    bool isLoadingDetail,
    bool isSubmitting,
    bool submitSuccess,
    bool isUploadingEvidence,
    bool isMissingStudentAlertSent,
    String? errorMessage,
    IncidentStatus? activeStatusFilter,
  });
}

/// @nodoc
class _$IncidentViewStateCopyWithImpl<$Res, $Val extends IncidentViewState>
    implements $IncidentViewStateCopyWith<$Res> {
  _$IncidentViewStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of IncidentViewState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? incidents = null,
    Object? isLoadingList = null,
    Object? selectedIncident = freezed,
    Object? isLoadingDetail = null,
    Object? isSubmitting = null,
    Object? submitSuccess = null,
    Object? isUploadingEvidence = null,
    Object? isMissingStudentAlertSent = null,
    Object? errorMessage = freezed,
    Object? activeStatusFilter = freezed,
  }) {
    return _then(
      _value.copyWith(
            incidents: null == incidents
                ? _value.incidents
                : incidents // ignore: cast_nullable_to_non_nullable
                      as List<IncidentReport>,
            isLoadingList: null == isLoadingList
                ? _value.isLoadingList
                : isLoadingList // ignore: cast_nullable_to_non_nullable
                      as bool,
            selectedIncident: freezed == selectedIncident
                ? _value.selectedIncident
                : selectedIncident // ignore: cast_nullable_to_non_nullable
                      as IncidentReport?,
            isLoadingDetail: null == isLoadingDetail
                ? _value.isLoadingDetail
                : isLoadingDetail // ignore: cast_nullable_to_non_nullable
                      as bool,
            isSubmitting: null == isSubmitting
                ? _value.isSubmitting
                : isSubmitting // ignore: cast_nullable_to_non_nullable
                      as bool,
            submitSuccess: null == submitSuccess
                ? _value.submitSuccess
                : submitSuccess // ignore: cast_nullable_to_non_nullable
                      as bool,
            isUploadingEvidence: null == isUploadingEvidence
                ? _value.isUploadingEvidence
                : isUploadingEvidence // ignore: cast_nullable_to_non_nullable
                      as bool,
            isMissingStudentAlertSent: null == isMissingStudentAlertSent
                ? _value.isMissingStudentAlertSent
                : isMissingStudentAlertSent // ignore: cast_nullable_to_non_nullable
                      as bool,
            errorMessage: freezed == errorMessage
                ? _value.errorMessage
                : errorMessage // ignore: cast_nullable_to_non_nullable
                      as String?,
            activeStatusFilter: freezed == activeStatusFilter
                ? _value.activeStatusFilter
                : activeStatusFilter // ignore: cast_nullable_to_non_nullable
                      as IncidentStatus?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$IncidentViewStateImplCopyWith<$Res>
    implements $IncidentViewStateCopyWith<$Res> {
  factory _$$IncidentViewStateImplCopyWith(
    _$IncidentViewStateImpl value,
    $Res Function(_$IncidentViewStateImpl) then,
  ) = __$$IncidentViewStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    List<IncidentReport> incidents,
    bool isLoadingList,
    IncidentReport? selectedIncident,
    bool isLoadingDetail,
    bool isSubmitting,
    bool submitSuccess,
    bool isUploadingEvidence,
    bool isMissingStudentAlertSent,
    String? errorMessage,
    IncidentStatus? activeStatusFilter,
  });
}

/// @nodoc
class __$$IncidentViewStateImplCopyWithImpl<$Res>
    extends _$IncidentViewStateCopyWithImpl<$Res, _$IncidentViewStateImpl>
    implements _$$IncidentViewStateImplCopyWith<$Res> {
  __$$IncidentViewStateImplCopyWithImpl(
    _$IncidentViewStateImpl _value,
    $Res Function(_$IncidentViewStateImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of IncidentViewState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? incidents = null,
    Object? isLoadingList = null,
    Object? selectedIncident = freezed,
    Object? isLoadingDetail = null,
    Object? isSubmitting = null,
    Object? submitSuccess = null,
    Object? isUploadingEvidence = null,
    Object? isMissingStudentAlertSent = null,
    Object? errorMessage = freezed,
    Object? activeStatusFilter = freezed,
  }) {
    return _then(
      _$IncidentViewStateImpl(
        incidents: null == incidents
            ? _value._incidents
            : incidents // ignore: cast_nullable_to_non_nullable
                  as List<IncidentReport>,
        isLoadingList: null == isLoadingList
            ? _value.isLoadingList
            : isLoadingList // ignore: cast_nullable_to_non_nullable
                  as bool,
        selectedIncident: freezed == selectedIncident
            ? _value.selectedIncident
            : selectedIncident // ignore: cast_nullable_to_non_nullable
                  as IncidentReport?,
        isLoadingDetail: null == isLoadingDetail
            ? _value.isLoadingDetail
            : isLoadingDetail // ignore: cast_nullable_to_non_nullable
                  as bool,
        isSubmitting: null == isSubmitting
            ? _value.isSubmitting
            : isSubmitting // ignore: cast_nullable_to_non_nullable
                  as bool,
        submitSuccess: null == submitSuccess
            ? _value.submitSuccess
            : submitSuccess // ignore: cast_nullable_to_non_nullable
                  as bool,
        isUploadingEvidence: null == isUploadingEvidence
            ? _value.isUploadingEvidence
            : isUploadingEvidence // ignore: cast_nullable_to_non_nullable
                  as bool,
        isMissingStudentAlertSent: null == isMissingStudentAlertSent
            ? _value.isMissingStudentAlertSent
            : isMissingStudentAlertSent // ignore: cast_nullable_to_non_nullable
                  as bool,
        errorMessage: freezed == errorMessage
            ? _value.errorMessage
            : errorMessage // ignore: cast_nullable_to_non_nullable
                  as String?,
        activeStatusFilter: freezed == activeStatusFilter
            ? _value.activeStatusFilter
            : activeStatusFilter // ignore: cast_nullable_to_non_nullable
                  as IncidentStatus?,
      ),
    );
  }
}

/// @nodoc

class _$IncidentViewStateImpl implements _IncidentViewState {
  const _$IncidentViewStateImpl({
    final List<IncidentReport> incidents = const [],
    this.isLoadingList = false,
    this.selectedIncident,
    this.isLoadingDetail = false,
    this.isSubmitting = false,
    this.submitSuccess = false,
    this.isUploadingEvidence = false,
    this.isMissingStudentAlertSent = false,
    this.errorMessage,
    this.activeStatusFilter,
  }) : _incidents = incidents;

  // ── List state ──────────────────────────────────────────────────────────
  final List<IncidentReport> _incidents;
  // ── List state ──────────────────────────────────────────────────────────
  @override
  @JsonKey()
  List<IncidentReport> get incidents {
    if (_incidents is EqualUnmodifiableListView) return _incidents;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_incidents);
  }

  @override
  @JsonKey()
  final bool isLoadingList;
  // ── Detail state ─────────────────────────────────────────────────────────
  @override
  final IncidentReport? selectedIncident;
  @override
  @JsonKey()
  final bool isLoadingDetail;
  // ── Create / Submit state ─────────────────────────────────────────────────
  @override
  @JsonKey()
  final bool isSubmitting;
  @override
  @JsonKey()
  final bool submitSuccess;
  // ── Evidence upload ──────────────────────────────────────────────────────
  @override
  @JsonKey()
  final bool isUploadingEvidence;
  // ── Missing student emergency ─────────────────────────────────────────────
  @override
  @JsonKey()
  final bool isMissingStudentAlertSent;
  // ── Shared error ─────────────────────────────────────────────────────────
  @override
  final String? errorMessage;
  // ── Active filter ────────────────────────────────────────────────────────
  @override
  final IncidentStatus? activeStatusFilter;

  @override
  String toString() {
    return 'IncidentViewState(incidents: $incidents, isLoadingList: $isLoadingList, selectedIncident: $selectedIncident, isLoadingDetail: $isLoadingDetail, isSubmitting: $isSubmitting, submitSuccess: $submitSuccess, isUploadingEvidence: $isUploadingEvidence, isMissingStudentAlertSent: $isMissingStudentAlertSent, errorMessage: $errorMessage, activeStatusFilter: $activeStatusFilter)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$IncidentViewStateImpl &&
            const DeepCollectionEquality().equals(
              other._incidents,
              _incidents,
            ) &&
            (identical(other.isLoadingList, isLoadingList) ||
                other.isLoadingList == isLoadingList) &&
            (identical(other.selectedIncident, selectedIncident) ||
                other.selectedIncident == selectedIncident) &&
            (identical(other.isLoadingDetail, isLoadingDetail) ||
                other.isLoadingDetail == isLoadingDetail) &&
            (identical(other.isSubmitting, isSubmitting) ||
                other.isSubmitting == isSubmitting) &&
            (identical(other.submitSuccess, submitSuccess) ||
                other.submitSuccess == submitSuccess) &&
            (identical(other.isUploadingEvidence, isUploadingEvidence) ||
                other.isUploadingEvidence == isUploadingEvidence) &&
            (identical(
                  other.isMissingStudentAlertSent,
                  isMissingStudentAlertSent,
                ) ||
                other.isMissingStudentAlertSent == isMissingStudentAlertSent) &&
            (identical(other.errorMessage, errorMessage) ||
                other.errorMessage == errorMessage) &&
            (identical(other.activeStatusFilter, activeStatusFilter) ||
                other.activeStatusFilter == activeStatusFilter));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    const DeepCollectionEquality().hash(_incidents),
    isLoadingList,
    selectedIncident,
    isLoadingDetail,
    isSubmitting,
    submitSuccess,
    isUploadingEvidence,
    isMissingStudentAlertSent,
    errorMessage,
    activeStatusFilter,
  );

  /// Create a copy of IncidentViewState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$IncidentViewStateImplCopyWith<_$IncidentViewStateImpl> get copyWith =>
      __$$IncidentViewStateImplCopyWithImpl<_$IncidentViewStateImpl>(
        this,
        _$identity,
      );
}

abstract class _IncidentViewState implements IncidentViewState {
  const factory _IncidentViewState({
    final List<IncidentReport> incidents,
    final bool isLoadingList,
    final IncidentReport? selectedIncident,
    final bool isLoadingDetail,
    final bool isSubmitting,
    final bool submitSuccess,
    final bool isUploadingEvidence,
    final bool isMissingStudentAlertSent,
    final String? errorMessage,
    final IncidentStatus? activeStatusFilter,
  }) = _$IncidentViewStateImpl;

  // ── List state ──────────────────────────────────────────────────────────
  @override
  List<IncidentReport> get incidents;
  @override
  bool get isLoadingList; // ── Detail state ─────────────────────────────────────────────────────────
  @override
  IncidentReport? get selectedIncident;
  @override
  bool get isLoadingDetail; // ── Create / Submit state ─────────────────────────────────────────────────
  @override
  bool get isSubmitting;
  @override
  bool get submitSuccess; // ── Evidence upload ──────────────────────────────────────────────────────
  @override
  bool get isUploadingEvidence; // ── Missing student emergency ─────────────────────────────────────────────
  @override
  bool get isMissingStudentAlertSent; // ── Shared error ─────────────────────────────────────────────────────────
  @override
  String? get errorMessage; // ── Active filter ────────────────────────────────────────────────────────
  @override
  IncidentStatus? get activeStatusFilter;

  /// Create a copy of IncidentViewState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$IncidentViewStateImplCopyWith<_$IncidentViewStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
