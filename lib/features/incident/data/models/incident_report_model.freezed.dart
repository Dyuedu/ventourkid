// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'incident_report_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

IncidentReportModel _$IncidentReportModelFromJson(Map<String, dynamic> json) {
  return _IncidentReportModel.fromJson(json);
}

/// @nodoc
mixin _$IncidentReportModel {
  String get id => throw _privateConstructorUsedError;
  String get tourId => throw _privateConstructorUsedError;
  String? get tourInstanceId => throw _privateConstructorUsedError;
  String? get tourName => throw _privateConstructorUsedError;
  String? get schoolName => throw _privateConstructorUsedError;
  String get reporterId => throw _privateConstructorUsedError;
  String get reporterRole => throw _privateConstructorUsedError;
  String get incidentType => throw _privateConstructorUsedError;
  String get severity => throw _privateConstructorUsedError;
  String get status => throw _privateConstructorUsedError;
  String get title => throw _privateConstructorUsedError;
  String? get description => throw _privateConstructorUsedError;
  String get incidentTime => throw _privateConstructorUsedError;
  String? get locationText => throw _privateConstructorUsedError;
  double? get latitude => throw _privateConstructorUsedError;
  double? get longitude => throw _privateConstructorUsedError;
  List<String> get affectedStudentIds => throw _privateConstructorUsedError;
  String? get lastCheckpointId => throw _privateConstructorUsedError;
  String? get acknowledgedBy => throw _privateConstructorUsedError;
  String? get acknowledgedAt => throw _privateConstructorUsedError;
  String? get resolvedBy => throw _privateConstructorUsedError;
  String? get resolvedAt => throw _privateConstructorUsedError;
  String? get resolutionNote => throw _privateConstructorUsedError;
  bool get offlineCreated => throw _privateConstructorUsedError;
  List<IncidentEvidenceModel> get evidences =>
      throw _privateConstructorUsedError;
  String get createdAt => throw _privateConstructorUsedError;
  String get updatedAt => throw _privateConstructorUsedError;

  /// Serializes this IncidentReportModel to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of IncidentReportModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $IncidentReportModelCopyWith<IncidentReportModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $IncidentReportModelCopyWith<$Res> {
  factory $IncidentReportModelCopyWith(
    IncidentReportModel value,
    $Res Function(IncidentReportModel) then,
  ) = _$IncidentReportModelCopyWithImpl<$Res, IncidentReportModel>;
  @useResult
  $Res call({
    String id,
    String tourId,
    String? tourInstanceId,
    String? tourName,
    String? schoolName,
    String reporterId,
    String reporterRole,
    String incidentType,
    String severity,
    String status,
    String title,
    String? description,
    String incidentTime,
    String? locationText,
    double? latitude,
    double? longitude,
    List<String> affectedStudentIds,
    String? lastCheckpointId,
    String? acknowledgedBy,
    String? acknowledgedAt,
    String? resolvedBy,
    String? resolvedAt,
    String? resolutionNote,
    bool offlineCreated,
    List<IncidentEvidenceModel> evidences,
    String createdAt,
    String updatedAt,
  });
}

/// @nodoc
class _$IncidentReportModelCopyWithImpl<$Res, $Val extends IncidentReportModel>
    implements $IncidentReportModelCopyWith<$Res> {
  _$IncidentReportModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of IncidentReportModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? tourId = null,
    Object? tourInstanceId = freezed,
    Object? tourName = freezed,
    Object? schoolName = freezed,
    Object? reporterId = null,
    Object? reporterRole = null,
    Object? incidentType = null,
    Object? severity = null,
    Object? status = null,
    Object? title = null,
    Object? description = freezed,
    Object? incidentTime = null,
    Object? locationText = freezed,
    Object? latitude = freezed,
    Object? longitude = freezed,
    Object? affectedStudentIds = null,
    Object? lastCheckpointId = freezed,
    Object? acknowledgedBy = freezed,
    Object? acknowledgedAt = freezed,
    Object? resolvedBy = freezed,
    Object? resolvedAt = freezed,
    Object? resolutionNote = freezed,
    Object? offlineCreated = null,
    Object? evidences = null,
    Object? createdAt = null,
    Object? updatedAt = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            tourId: null == tourId
                ? _value.tourId
                : tourId // ignore: cast_nullable_to_non_nullable
                      as String,
            tourInstanceId: freezed == tourInstanceId
                ? _value.tourInstanceId
                : tourInstanceId // ignore: cast_nullable_to_non_nullable
                      as String?,
            tourName: freezed == tourName
                ? _value.tourName
                : tourName // ignore: cast_nullable_to_non_nullable
                      as String?,
            schoolName: freezed == schoolName
                ? _value.schoolName
                : schoolName // ignore: cast_nullable_to_non_nullable
                      as String?,
            reporterId: null == reporterId
                ? _value.reporterId
                : reporterId // ignore: cast_nullable_to_non_nullable
                      as String,
            reporterRole: null == reporterRole
                ? _value.reporterRole
                : reporterRole // ignore: cast_nullable_to_non_nullable
                      as String,
            incidentType: null == incidentType
                ? _value.incidentType
                : incidentType // ignore: cast_nullable_to_non_nullable
                      as String,
            severity: null == severity
                ? _value.severity
                : severity // ignore: cast_nullable_to_non_nullable
                      as String,
            status: null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                      as String,
            title: null == title
                ? _value.title
                : title // ignore: cast_nullable_to_non_nullable
                      as String,
            description: freezed == description
                ? _value.description
                : description // ignore: cast_nullable_to_non_nullable
                      as String?,
            incidentTime: null == incidentTime
                ? _value.incidentTime
                : incidentTime // ignore: cast_nullable_to_non_nullable
                      as String,
            locationText: freezed == locationText
                ? _value.locationText
                : locationText // ignore: cast_nullable_to_non_nullable
                      as String?,
            latitude: freezed == latitude
                ? _value.latitude
                : latitude // ignore: cast_nullable_to_non_nullable
                      as double?,
            longitude: freezed == longitude
                ? _value.longitude
                : longitude // ignore: cast_nullable_to_non_nullable
                      as double?,
            affectedStudentIds: null == affectedStudentIds
                ? _value.affectedStudentIds
                : affectedStudentIds // ignore: cast_nullable_to_non_nullable
                      as List<String>,
            lastCheckpointId: freezed == lastCheckpointId
                ? _value.lastCheckpointId
                : lastCheckpointId // ignore: cast_nullable_to_non_nullable
                      as String?,
            acknowledgedBy: freezed == acknowledgedBy
                ? _value.acknowledgedBy
                : acknowledgedBy // ignore: cast_nullable_to_non_nullable
                      as String?,
            acknowledgedAt: freezed == acknowledgedAt
                ? _value.acknowledgedAt
                : acknowledgedAt // ignore: cast_nullable_to_non_nullable
                      as String?,
            resolvedBy: freezed == resolvedBy
                ? _value.resolvedBy
                : resolvedBy // ignore: cast_nullable_to_non_nullable
                      as String?,
            resolvedAt: freezed == resolvedAt
                ? _value.resolvedAt
                : resolvedAt // ignore: cast_nullable_to_non_nullable
                      as String?,
            resolutionNote: freezed == resolutionNote
                ? _value.resolutionNote
                : resolutionNote // ignore: cast_nullable_to_non_nullable
                      as String?,
            offlineCreated: null == offlineCreated
                ? _value.offlineCreated
                : offlineCreated // ignore: cast_nullable_to_non_nullable
                      as bool,
            evidences: null == evidences
                ? _value.evidences
                : evidences // ignore: cast_nullable_to_non_nullable
                      as List<IncidentEvidenceModel>,
            createdAt: null == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as String,
            updatedAt: null == updatedAt
                ? _value.updatedAt
                : updatedAt // ignore: cast_nullable_to_non_nullable
                      as String,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$IncidentReportModelImplCopyWith<$Res>
    implements $IncidentReportModelCopyWith<$Res> {
  factory _$$IncidentReportModelImplCopyWith(
    _$IncidentReportModelImpl value,
    $Res Function(_$IncidentReportModelImpl) then,
  ) = __$$IncidentReportModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String tourId,
    String? tourInstanceId,
    String? tourName,
    String? schoolName,
    String reporterId,
    String reporterRole,
    String incidentType,
    String severity,
    String status,
    String title,
    String? description,
    String incidentTime,
    String? locationText,
    double? latitude,
    double? longitude,
    List<String> affectedStudentIds,
    String? lastCheckpointId,
    String? acknowledgedBy,
    String? acknowledgedAt,
    String? resolvedBy,
    String? resolvedAt,
    String? resolutionNote,
    bool offlineCreated,
    List<IncidentEvidenceModel> evidences,
    String createdAt,
    String updatedAt,
  });
}

/// @nodoc
class __$$IncidentReportModelImplCopyWithImpl<$Res>
    extends _$IncidentReportModelCopyWithImpl<$Res, _$IncidentReportModelImpl>
    implements _$$IncidentReportModelImplCopyWith<$Res> {
  __$$IncidentReportModelImplCopyWithImpl(
    _$IncidentReportModelImpl _value,
    $Res Function(_$IncidentReportModelImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of IncidentReportModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? tourId = null,
    Object? tourInstanceId = freezed,
    Object? tourName = freezed,
    Object? schoolName = freezed,
    Object? reporterId = null,
    Object? reporterRole = null,
    Object? incidentType = null,
    Object? severity = null,
    Object? status = null,
    Object? title = null,
    Object? description = freezed,
    Object? incidentTime = null,
    Object? locationText = freezed,
    Object? latitude = freezed,
    Object? longitude = freezed,
    Object? affectedStudentIds = null,
    Object? lastCheckpointId = freezed,
    Object? acknowledgedBy = freezed,
    Object? acknowledgedAt = freezed,
    Object? resolvedBy = freezed,
    Object? resolvedAt = freezed,
    Object? resolutionNote = freezed,
    Object? offlineCreated = null,
    Object? evidences = null,
    Object? createdAt = null,
    Object? updatedAt = null,
  }) {
    return _then(
      _$IncidentReportModelImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        tourId: null == tourId
            ? _value.tourId
            : tourId // ignore: cast_nullable_to_non_nullable
                  as String,
        tourInstanceId: freezed == tourInstanceId
            ? _value.tourInstanceId
            : tourInstanceId // ignore: cast_nullable_to_non_nullable
                  as String?,
        tourName: freezed == tourName
            ? _value.tourName
            : tourName // ignore: cast_nullable_to_non_nullable
                  as String?,
        schoolName: freezed == schoolName
            ? _value.schoolName
            : schoolName // ignore: cast_nullable_to_non_nullable
                  as String?,
        reporterId: null == reporterId
            ? _value.reporterId
            : reporterId // ignore: cast_nullable_to_non_nullable
                  as String,
        reporterRole: null == reporterRole
            ? _value.reporterRole
            : reporterRole // ignore: cast_nullable_to_non_nullable
                  as String,
        incidentType: null == incidentType
            ? _value.incidentType
            : incidentType // ignore: cast_nullable_to_non_nullable
                  as String,
        severity: null == severity
            ? _value.severity
            : severity // ignore: cast_nullable_to_non_nullable
                  as String,
        status: null == status
            ? _value.status
            : status // ignore: cast_nullable_to_non_nullable
                  as String,
        title: null == title
            ? _value.title
            : title // ignore: cast_nullable_to_non_nullable
                  as String,
        description: freezed == description
            ? _value.description
            : description // ignore: cast_nullable_to_non_nullable
                  as String?,
        incidentTime: null == incidentTime
            ? _value.incidentTime
            : incidentTime // ignore: cast_nullable_to_non_nullable
                  as String,
        locationText: freezed == locationText
            ? _value.locationText
            : locationText // ignore: cast_nullable_to_non_nullable
                  as String?,
        latitude: freezed == latitude
            ? _value.latitude
            : latitude // ignore: cast_nullable_to_non_nullable
                  as double?,
        longitude: freezed == longitude
            ? _value.longitude
            : longitude // ignore: cast_nullable_to_non_nullable
                  as double?,
        affectedStudentIds: null == affectedStudentIds
            ? _value._affectedStudentIds
            : affectedStudentIds // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        lastCheckpointId: freezed == lastCheckpointId
            ? _value.lastCheckpointId
            : lastCheckpointId // ignore: cast_nullable_to_non_nullable
                  as String?,
        acknowledgedBy: freezed == acknowledgedBy
            ? _value.acknowledgedBy
            : acknowledgedBy // ignore: cast_nullable_to_non_nullable
                  as String?,
        acknowledgedAt: freezed == acknowledgedAt
            ? _value.acknowledgedAt
            : acknowledgedAt // ignore: cast_nullable_to_non_nullable
                  as String?,
        resolvedBy: freezed == resolvedBy
            ? _value.resolvedBy
            : resolvedBy // ignore: cast_nullable_to_non_nullable
                  as String?,
        resolvedAt: freezed == resolvedAt
            ? _value.resolvedAt
            : resolvedAt // ignore: cast_nullable_to_non_nullable
                  as String?,
        resolutionNote: freezed == resolutionNote
            ? _value.resolutionNote
            : resolutionNote // ignore: cast_nullable_to_non_nullable
                  as String?,
        offlineCreated: null == offlineCreated
            ? _value.offlineCreated
            : offlineCreated // ignore: cast_nullable_to_non_nullable
                  as bool,
        evidences: null == evidences
            ? _value._evidences
            : evidences // ignore: cast_nullable_to_non_nullable
                  as List<IncidentEvidenceModel>,
        createdAt: null == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as String,
        updatedAt: null == updatedAt
            ? _value.updatedAt
            : updatedAt // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$IncidentReportModelImpl implements _IncidentReportModel {
  const _$IncidentReportModelImpl({
    required this.id,
    required this.tourId,
    this.tourInstanceId,
    this.tourName,
    this.schoolName,
    required this.reporterId,
    required this.reporterRole,
    required this.incidentType,
    required this.severity,
    required this.status,
    required this.title,
    this.description,
    required this.incidentTime,
    this.locationText,
    this.latitude,
    this.longitude,
    final List<String> affectedStudentIds = const [],
    this.lastCheckpointId,
    this.acknowledgedBy,
    this.acknowledgedAt,
    this.resolvedBy,
    this.resolvedAt,
    this.resolutionNote,
    this.offlineCreated = false,
    final List<IncidentEvidenceModel> evidences = const [],
    required this.createdAt,
    required this.updatedAt,
  }) : _affectedStudentIds = affectedStudentIds,
       _evidences = evidences;

  factory _$IncidentReportModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$IncidentReportModelImplFromJson(json);

  @override
  final String id;
  @override
  final String tourId;
  @override
  final String? tourInstanceId;
  @override
  final String? tourName;
  @override
  final String? schoolName;
  @override
  final String reporterId;
  @override
  final String reporterRole;
  @override
  final String incidentType;
  @override
  final String severity;
  @override
  final String status;
  @override
  final String title;
  @override
  final String? description;
  @override
  final String incidentTime;
  @override
  final String? locationText;
  @override
  final double? latitude;
  @override
  final double? longitude;
  final List<String> _affectedStudentIds;
  @override
  @JsonKey()
  List<String> get affectedStudentIds {
    if (_affectedStudentIds is EqualUnmodifiableListView)
      return _affectedStudentIds;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_affectedStudentIds);
  }

  @override
  final String? lastCheckpointId;
  @override
  final String? acknowledgedBy;
  @override
  final String? acknowledgedAt;
  @override
  final String? resolvedBy;
  @override
  final String? resolvedAt;
  @override
  final String? resolutionNote;
  @override
  @JsonKey()
  final bool offlineCreated;
  final List<IncidentEvidenceModel> _evidences;
  @override
  @JsonKey()
  List<IncidentEvidenceModel> get evidences {
    if (_evidences is EqualUnmodifiableListView) return _evidences;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_evidences);
  }

  @override
  final String createdAt;
  @override
  final String updatedAt;

  @override
  String toString() {
    return 'IncidentReportModel(id: $id, tourId: $tourId, tourInstanceId: $tourInstanceId, tourName: $tourName, schoolName: $schoolName, reporterId: $reporterId, reporterRole: $reporterRole, incidentType: $incidentType, severity: $severity, status: $status, title: $title, description: $description, incidentTime: $incidentTime, locationText: $locationText, latitude: $latitude, longitude: $longitude, affectedStudentIds: $affectedStudentIds, lastCheckpointId: $lastCheckpointId, acknowledgedBy: $acknowledgedBy, acknowledgedAt: $acknowledgedAt, resolvedBy: $resolvedBy, resolvedAt: $resolvedAt, resolutionNote: $resolutionNote, offlineCreated: $offlineCreated, evidences: $evidences, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$IncidentReportModelImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.tourId, tourId) || other.tourId == tourId) &&
            (identical(other.tourInstanceId, tourInstanceId) ||
                other.tourInstanceId == tourInstanceId) &&
            (identical(other.tourName, tourName) ||
                other.tourName == tourName) &&
            (identical(other.schoolName, schoolName) ||
                other.schoolName == schoolName) &&
            (identical(other.reporterId, reporterId) ||
                other.reporterId == reporterId) &&
            (identical(other.reporterRole, reporterRole) ||
                other.reporterRole == reporterRole) &&
            (identical(other.incidentType, incidentType) ||
                other.incidentType == incidentType) &&
            (identical(other.severity, severity) ||
                other.severity == severity) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.incidentTime, incidentTime) ||
                other.incidentTime == incidentTime) &&
            (identical(other.locationText, locationText) ||
                other.locationText == locationText) &&
            (identical(other.latitude, latitude) ||
                other.latitude == latitude) &&
            (identical(other.longitude, longitude) ||
                other.longitude == longitude) &&
            const DeepCollectionEquality().equals(
              other._affectedStudentIds,
              _affectedStudentIds,
            ) &&
            (identical(other.lastCheckpointId, lastCheckpointId) ||
                other.lastCheckpointId == lastCheckpointId) &&
            (identical(other.acknowledgedBy, acknowledgedBy) ||
                other.acknowledgedBy == acknowledgedBy) &&
            (identical(other.acknowledgedAt, acknowledgedAt) ||
                other.acknowledgedAt == acknowledgedAt) &&
            (identical(other.resolvedBy, resolvedBy) ||
                other.resolvedBy == resolvedBy) &&
            (identical(other.resolvedAt, resolvedAt) ||
                other.resolvedAt == resolvedAt) &&
            (identical(other.resolutionNote, resolutionNote) ||
                other.resolutionNote == resolutionNote) &&
            (identical(other.offlineCreated, offlineCreated) ||
                other.offlineCreated == offlineCreated) &&
            const DeepCollectionEquality().equals(
              other._evidences,
              _evidences,
            ) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hashAll([
    runtimeType,
    id,
    tourId,
    tourInstanceId,
    tourName,
    schoolName,
    reporterId,
    reporterRole,
    incidentType,
    severity,
    status,
    title,
    description,
    incidentTime,
    locationText,
    latitude,
    longitude,
    const DeepCollectionEquality().hash(_affectedStudentIds),
    lastCheckpointId,
    acknowledgedBy,
    acknowledgedAt,
    resolvedBy,
    resolvedAt,
    resolutionNote,
    offlineCreated,
    const DeepCollectionEquality().hash(_evidences),
    createdAt,
    updatedAt,
  ]);

  /// Create a copy of IncidentReportModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$IncidentReportModelImplCopyWith<_$IncidentReportModelImpl> get copyWith =>
      __$$IncidentReportModelImplCopyWithImpl<_$IncidentReportModelImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$IncidentReportModelImplToJson(this);
  }
}

abstract class _IncidentReportModel implements IncidentReportModel {
  const factory _IncidentReportModel({
    required final String id,
    required final String tourId,
    final String? tourInstanceId,
    final String? tourName,
    final String? schoolName,
    required final String reporterId,
    required final String reporterRole,
    required final String incidentType,
    required final String severity,
    required final String status,
    required final String title,
    final String? description,
    required final String incidentTime,
    final String? locationText,
    final double? latitude,
    final double? longitude,
    final List<String> affectedStudentIds,
    final String? lastCheckpointId,
    final String? acknowledgedBy,
    final String? acknowledgedAt,
    final String? resolvedBy,
    final String? resolvedAt,
    final String? resolutionNote,
    final bool offlineCreated,
    final List<IncidentEvidenceModel> evidences,
    required final String createdAt,
    required final String updatedAt,
  }) = _$IncidentReportModelImpl;

  factory _IncidentReportModel.fromJson(Map<String, dynamic> json) =
      _$IncidentReportModelImpl.fromJson;

  @override
  String get id;
  @override
  String get tourId;
  @override
  String? get tourInstanceId;
  @override
  String? get tourName;
  @override
  String? get schoolName;
  @override
  String get reporterId;
  @override
  String get reporterRole;
  @override
  String get incidentType;
  @override
  String get severity;
  @override
  String get status;
  @override
  String get title;
  @override
  String? get description;
  @override
  String get incidentTime;
  @override
  String? get locationText;
  @override
  double? get latitude;
  @override
  double? get longitude;
  @override
  List<String> get affectedStudentIds;
  @override
  String? get lastCheckpointId;
  @override
  String? get acknowledgedBy;
  @override
  String? get acknowledgedAt;
  @override
  String? get resolvedBy;
  @override
  String? get resolvedAt;
  @override
  String? get resolutionNote;
  @override
  bool get offlineCreated;
  @override
  List<IncidentEvidenceModel> get evidences;
  @override
  String get createdAt;
  @override
  String get updatedAt;

  /// Create a copy of IncidentReportModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$IncidentReportModelImplCopyWith<_$IncidentReportModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

IncidentEvidenceModel _$IncidentEvidenceModelFromJson(
  Map<String, dynamic> json,
) {
  return _IncidentEvidenceModel.fromJson(json);
}

/// @nodoc
mixin _$IncidentEvidenceModel {
  String get id => throw _privateConstructorUsedError;
  String get incidentId => throw _privateConstructorUsedError;
  String get evidenceType => throw _privateConstructorUsedError;
  String? get fileUrl => throw _privateConstructorUsedError;
  String? get noteContent => throw _privateConstructorUsedError;
  String? get description => throw _privateConstructorUsedError;
  String get uploadedBy => throw _privateConstructorUsedError;
  String get uploadedAt => throw _privateConstructorUsedError;

  /// Serializes this IncidentEvidenceModel to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of IncidentEvidenceModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $IncidentEvidenceModelCopyWith<IncidentEvidenceModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $IncidentEvidenceModelCopyWith<$Res> {
  factory $IncidentEvidenceModelCopyWith(
    IncidentEvidenceModel value,
    $Res Function(IncidentEvidenceModel) then,
  ) = _$IncidentEvidenceModelCopyWithImpl<$Res, IncidentEvidenceModel>;
  @useResult
  $Res call({
    String id,
    String incidentId,
    String evidenceType,
    String? fileUrl,
    String? noteContent,
    String? description,
    String uploadedBy,
    String uploadedAt,
  });
}

/// @nodoc
class _$IncidentEvidenceModelCopyWithImpl<
  $Res,
  $Val extends IncidentEvidenceModel
>
    implements $IncidentEvidenceModelCopyWith<$Res> {
  _$IncidentEvidenceModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of IncidentEvidenceModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? incidentId = null,
    Object? evidenceType = null,
    Object? fileUrl = freezed,
    Object? noteContent = freezed,
    Object? description = freezed,
    Object? uploadedBy = null,
    Object? uploadedAt = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            incidentId: null == incidentId
                ? _value.incidentId
                : incidentId // ignore: cast_nullable_to_non_nullable
                      as String,
            evidenceType: null == evidenceType
                ? _value.evidenceType
                : evidenceType // ignore: cast_nullable_to_non_nullable
                      as String,
            fileUrl: freezed == fileUrl
                ? _value.fileUrl
                : fileUrl // ignore: cast_nullable_to_non_nullable
                      as String?,
            noteContent: freezed == noteContent
                ? _value.noteContent
                : noteContent // ignore: cast_nullable_to_non_nullable
                      as String?,
            description: freezed == description
                ? _value.description
                : description // ignore: cast_nullable_to_non_nullable
                      as String?,
            uploadedBy: null == uploadedBy
                ? _value.uploadedBy
                : uploadedBy // ignore: cast_nullable_to_non_nullable
                      as String,
            uploadedAt: null == uploadedAt
                ? _value.uploadedAt
                : uploadedAt // ignore: cast_nullable_to_non_nullable
                      as String,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$IncidentEvidenceModelImplCopyWith<$Res>
    implements $IncidentEvidenceModelCopyWith<$Res> {
  factory _$$IncidentEvidenceModelImplCopyWith(
    _$IncidentEvidenceModelImpl value,
    $Res Function(_$IncidentEvidenceModelImpl) then,
  ) = __$$IncidentEvidenceModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String incidentId,
    String evidenceType,
    String? fileUrl,
    String? noteContent,
    String? description,
    String uploadedBy,
    String uploadedAt,
  });
}

/// @nodoc
class __$$IncidentEvidenceModelImplCopyWithImpl<$Res>
    extends
        _$IncidentEvidenceModelCopyWithImpl<$Res, _$IncidentEvidenceModelImpl>
    implements _$$IncidentEvidenceModelImplCopyWith<$Res> {
  __$$IncidentEvidenceModelImplCopyWithImpl(
    _$IncidentEvidenceModelImpl _value,
    $Res Function(_$IncidentEvidenceModelImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of IncidentEvidenceModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? incidentId = null,
    Object? evidenceType = null,
    Object? fileUrl = freezed,
    Object? noteContent = freezed,
    Object? description = freezed,
    Object? uploadedBy = null,
    Object? uploadedAt = null,
  }) {
    return _then(
      _$IncidentEvidenceModelImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        incidentId: null == incidentId
            ? _value.incidentId
            : incidentId // ignore: cast_nullable_to_non_nullable
                  as String,
        evidenceType: null == evidenceType
            ? _value.evidenceType
            : evidenceType // ignore: cast_nullable_to_non_nullable
                  as String,
        fileUrl: freezed == fileUrl
            ? _value.fileUrl
            : fileUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
        noteContent: freezed == noteContent
            ? _value.noteContent
            : noteContent // ignore: cast_nullable_to_non_nullable
                  as String?,
        description: freezed == description
            ? _value.description
            : description // ignore: cast_nullable_to_non_nullable
                  as String?,
        uploadedBy: null == uploadedBy
            ? _value.uploadedBy
            : uploadedBy // ignore: cast_nullable_to_non_nullable
                  as String,
        uploadedAt: null == uploadedAt
            ? _value.uploadedAt
            : uploadedAt // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$IncidentEvidenceModelImpl implements _IncidentEvidenceModel {
  const _$IncidentEvidenceModelImpl({
    required this.id,
    required this.incidentId,
    required this.evidenceType,
    this.fileUrl,
    this.noteContent,
    this.description,
    required this.uploadedBy,
    required this.uploadedAt,
  });

  factory _$IncidentEvidenceModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$IncidentEvidenceModelImplFromJson(json);

  @override
  final String id;
  @override
  final String incidentId;
  @override
  final String evidenceType;
  @override
  final String? fileUrl;
  @override
  final String? noteContent;
  @override
  final String? description;
  @override
  final String uploadedBy;
  @override
  final String uploadedAt;

  @override
  String toString() {
    return 'IncidentEvidenceModel(id: $id, incidentId: $incidentId, evidenceType: $evidenceType, fileUrl: $fileUrl, noteContent: $noteContent, description: $description, uploadedBy: $uploadedBy, uploadedAt: $uploadedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$IncidentEvidenceModelImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.incidentId, incidentId) ||
                other.incidentId == incidentId) &&
            (identical(other.evidenceType, evidenceType) ||
                other.evidenceType == evidenceType) &&
            (identical(other.fileUrl, fileUrl) || other.fileUrl == fileUrl) &&
            (identical(other.noteContent, noteContent) ||
                other.noteContent == noteContent) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.uploadedBy, uploadedBy) ||
                other.uploadedBy == uploadedBy) &&
            (identical(other.uploadedAt, uploadedAt) ||
                other.uploadedAt == uploadedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    incidentId,
    evidenceType,
    fileUrl,
    noteContent,
    description,
    uploadedBy,
    uploadedAt,
  );

  /// Create a copy of IncidentEvidenceModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$IncidentEvidenceModelImplCopyWith<_$IncidentEvidenceModelImpl>
  get copyWith =>
      __$$IncidentEvidenceModelImplCopyWithImpl<_$IncidentEvidenceModelImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$IncidentEvidenceModelImplToJson(this);
  }
}

abstract class _IncidentEvidenceModel implements IncidentEvidenceModel {
  const factory _IncidentEvidenceModel({
    required final String id,
    required final String incidentId,
    required final String evidenceType,
    final String? fileUrl,
    final String? noteContent,
    final String? description,
    required final String uploadedBy,
    required final String uploadedAt,
  }) = _$IncidentEvidenceModelImpl;

  factory _IncidentEvidenceModel.fromJson(Map<String, dynamic> json) =
      _$IncidentEvidenceModelImpl.fromJson;

  @override
  String get id;
  @override
  String get incidentId;
  @override
  String get evidenceType;
  @override
  String? get fileUrl;
  @override
  String? get noteContent;
  @override
  String? get description;
  @override
  String get uploadedBy;
  @override
  String get uploadedAt;

  /// Create a copy of IncidentEvidenceModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$IncidentEvidenceModelImplCopyWith<_$IncidentEvidenceModelImpl>
  get copyWith => throw _privateConstructorUsedError;
}
