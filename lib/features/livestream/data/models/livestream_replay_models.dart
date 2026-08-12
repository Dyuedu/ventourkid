class LivestreamReplaySession {
  const LivestreamReplaySession({
    required this.id,
    required this.tourId,
    this.operationPlanItemId,
    this.title,
    this.description,
    this.thumbnailUrl,
    this.startedAt,
    this.endedAt,
    required this.durationSeconds,
    required this.hasRecording,
    this.recordingStatus = 'PROCESSING',
  });

  factory LivestreamReplaySession.fromJson(Map<String, dynamic> json) {
    final hasRecording = _asBool(
          json['hasRecording'] ?? json['has_recording'] ?? json['recording'],
        ) ??
        false;
    final status = _asString(json['recordingStatus'] ?? json['recording_status']);
    return LivestreamReplaySession(
      id: _asString(json['id']) ?? '',
      tourId: _asString(json['tourId'] ?? json['tour_id']) ?? '',
      operationPlanItemId: _asString(
        json['operationPlanItemId'] ?? json['operation_plan_item_id'],
      ),
      title: _asString(json['title']),
      description: _asString(json['description']),
      thumbnailUrl: _asString(json['thumbnailUrl'] ?? json['thumbnail_url']),
      startedAt: _asString(json['startedAt'] ?? json['started_at']),
      endedAt: _asString(json['endedAt'] ?? json['ended_at']),
      durationSeconds: (json['durationSeconds'] as num?)?.toInt() ??
          (json['duration_seconds'] as num?)?.toInt() ??
          -1,
      hasRecording: hasRecording,
      recordingStatus: status ?? (hasRecording ? 'READY' : 'PROCESSING'),
    );
  }

  final String id;
  final String tourId;
  final String? operationPlanItemId;
  final String? title;
  final String? description;
  final String? thumbnailUrl;
  final String? startedAt;
  final String? endedAt;
  final int durationSeconds;
  final bool hasRecording;
  final String recordingStatus;

  bool get canWatch =>
      hasRecording || recordingStatus.toUpperCase() == 'READY';

  bool get isProcessing =>
      !canWatch && recordingStatus.toUpperCase() == 'PROCESSING';

  String get displayTitle => title?.trim().isNotEmpty == true
      ? title!.trim()
      : 'Phiên phát sóng không có tiêu đề';
}

class LivestreamReplayUrl {
  const LivestreamReplayUrl({
    required this.sessionId,
    required this.presignedUrl,
    this.expiresAt,
    this.title,
    this.startedAt,
    this.endedAt,
    required this.durationSeconds,
  });

  factory LivestreamReplayUrl.fromJson(Map<String, dynamic> json) {
    return LivestreamReplayUrl(
      sessionId: _asString(json['sessionId'] ?? json['session_id']) ?? '',
      presignedUrl:
          _asString(json['presignedUrl'] ?? json['presigned_url']) ?? '',
      expiresAt: _asString(json['expiresAt'] ?? json['expires_at']),
      title: _asString(json['title']),
      startedAt: _asString(json['startedAt'] ?? json['started_at']),
      endedAt: _asString(json['endedAt'] ?? json['ended_at']),
      durationSeconds: (json['durationSeconds'] as num?)?.toInt() ??
          (json['duration_seconds'] as num?)?.toInt() ??
          -1,
    );
  }

  final String sessionId;
  final String presignedUrl;
  final String? expiresAt;
  final String? title;
  final String? startedAt;
  final String? endedAt;
  final int durationSeconds;
}

String? _asString(Object? value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

bool? _asBool(Object? value) {
  if (value == null) return null;
  if (value is bool) return value;
  if (value is num) return value != 0;
  final text = value.toString().trim().toLowerCase();
  if (text == 'true' || text == '1' || text == 'yes') return true;
  if (text == 'false' || text == '0' || text == 'no') return false;
  return null;
}
