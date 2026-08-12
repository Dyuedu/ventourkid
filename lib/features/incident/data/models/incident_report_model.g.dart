// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'incident_report_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$IncidentReportModelImpl _$$IncidentReportModelImplFromJson(
  Map<String, dynamic> json,
) => _$IncidentReportModelImpl(
  id: json['id'] as String,
  tourId: json['tourId'] as String,
  tourInstanceId: json['tourInstanceId'] as String?,
  tourName: json['tourName'] as String?,
  schoolName: json['schoolName'] as String?,
  reporterId: json['reporterId'] as String,
  reporterRole: json['reporterRole'] as String,
  incidentType: json['incidentType'] as String,
  severity: json['severity'] as String,
  status: json['status'] as String,
  title: json['title'] as String,
  description: json['description'] as String?,
  incidentTime: json['incidentTime'] as String,
  locationText: json['locationText'] as String?,
  latitude: (json['latitude'] as num?)?.toDouble(),
  longitude: (json['longitude'] as num?)?.toDouble(),
  affectedStudentIds:
      (json['affectedStudentIds'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
  lastCheckpointId: json['lastCheckpointId'] as String?,
  acknowledgedBy: json['acknowledgedBy'] as String?,
  acknowledgedAt: json['acknowledgedAt'] as String?,
  resolvedBy: json['resolvedBy'] as String?,
  resolvedAt: json['resolvedAt'] as String?,
  resolutionNote: json['resolutionNote'] as String?,
  offlineCreated: json['offlineCreated'] as bool? ?? false,
  evidences:
      (json['evidences'] as List<dynamic>?)
          ?.map(
            (e) => IncidentEvidenceModel.fromJson(e as Map<String, dynamic>),
          )
          .toList() ??
      const [],
  createdAt: json['createdAt'] as String,
  updatedAt: json['updatedAt'] as String,
);

Map<String, dynamic> _$$IncidentReportModelImplToJson(
  _$IncidentReportModelImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'tourId': instance.tourId,
  'tourInstanceId': instance.tourInstanceId,
  'tourName': instance.tourName,
  'schoolName': instance.schoolName,
  'reporterId': instance.reporterId,
  'reporterRole': instance.reporterRole,
  'incidentType': instance.incidentType,
  'severity': instance.severity,
  'status': instance.status,
  'title': instance.title,
  'description': instance.description,
  'incidentTime': instance.incidentTime,
  'locationText': instance.locationText,
  'latitude': instance.latitude,
  'longitude': instance.longitude,
  'affectedStudentIds': instance.affectedStudentIds,
  'lastCheckpointId': instance.lastCheckpointId,
  'acknowledgedBy': instance.acknowledgedBy,
  'acknowledgedAt': instance.acknowledgedAt,
  'resolvedBy': instance.resolvedBy,
  'resolvedAt': instance.resolvedAt,
  'resolutionNote': instance.resolutionNote,
  'offlineCreated': instance.offlineCreated,
  'evidences': instance.evidences,
  'createdAt': instance.createdAt,
  'updatedAt': instance.updatedAt,
};

_$IncidentEvidenceModelImpl _$$IncidentEvidenceModelImplFromJson(
  Map<String, dynamic> json,
) => _$IncidentEvidenceModelImpl(
  id: json['id'] as String,
  incidentId: json['incidentId'] as String,
  evidenceType: json['evidenceType'] as String,
  fileUrl: json['fileUrl'] as String?,
  noteContent: json['noteContent'] as String?,
  description: json['description'] as String?,
  uploadedBy: json['uploadedBy'] as String,
  uploadedAt: json['uploadedAt'] as String,
);

Map<String, dynamic> _$$IncidentEvidenceModelImplToJson(
  _$IncidentEvidenceModelImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'incidentId': instance.incidentId,
  'evidenceType': instance.evidenceType,
  'fileUrl': instance.fileUrl,
  'noteContent': instance.noteContent,
  'description': instance.description,
  'uploadedBy': instance.uploadedBy,
  'uploadedAt': instance.uploadedAt,
};
