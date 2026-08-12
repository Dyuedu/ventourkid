class TourMediaItem {
  const TourMediaItem({
    required this.id,
    required this.tourId,
    this.activityId,
    this.checkpointId,
    this.groupId,
    required this.fileUrl,
    required this.mediaType,
    required this.status,
    required this.faceProcessingStatus,
    required this.createdAt,
    required this.faceMatches,
    required this.interactions,
    this.caption,
  });

  final String id;
  final String tourId;
  final String? activityId;
  final String? checkpointId;
  final String? groupId;
  final String fileUrl;
  final String mediaType;
  final String status;
  final String faceProcessingStatus;
  final DateTime? createdAt;
  final String? caption;
  final List<TourMediaFaceMatch> faceMatches;
  final TourMediaInteractions interactions;

  factory TourMediaItem.fromJson(Map<String, dynamic> json) {
    final matches = json['faceMatches'] ?? json['face_matches'];
    final faceMatches = matches is List
        ? matches
              .whereType<Map<String, dynamic>>()
              .map(TourMediaFaceMatch.fromJson)
              .toList()
        : const <TourMediaFaceMatch>[];
    final sortedMatches = [...faceMatches]..sort(_compareFaceMatches);
    return TourMediaItem(
      id: _firstString(json, ['id', 'media_id']),
      tourId: _firstString(json, ['tourId', 'tour_id']),
      activityId: _nullableString(json, ['activityId', 'activity_id']),
      checkpointId: _nullableString(json, ['checkpointId', 'checkpoint_id']),
      groupId: _nullableString(json, ['groupId', 'group_id']),
      fileUrl: _firstString(json, [
        'fileUrl',
        'file_url',
        'url',
        'mediaUrl',
        'media_url',
        'thumbnailUrl',
        'thumbnail_url',
      ]),
      mediaType: _firstString(json, ['mediaType', 'media_type'], 'IMAGE'),
      status: json['status']?.toString() ?? 'PENDING_REVIEW',
      faceProcessingStatus: _firstString(json, [
        'faceProcessingStatus',
        'face_processing_status',
      ], 'NOT_REQUIRED'),
      caption: json['caption']?.toString(),
      createdAt: DateTime.tryParse(
        _firstString(json, [
          'createdAt',
          'created_at',
          'capturedAt',
          'taken_at',
        ]),
      ),
      faceMatches: sortedMatches,
      interactions: TourMediaInteractions.fromJson(
        json['interactions'] is Map<String, dynamic>
            ? json['interactions'] as Map<String, dynamic>
            : const <String, dynamic>{},
      ),
    );
  }
}

String _firstString(
  Map<String, dynamic> json,
  List<String> keys, [
  String fallback = '',
]) {
  for (final key in keys) {
    final value = json[key]?.toString().trim();
    if (value != null && value.isNotEmpty && value != 'null') return value;
  }
  return fallback;
}

String? _nullableString(Map<String, dynamic> json, List<String> keys) {
  final value = _firstString(json, keys);
  return value.isEmpty ? null : value;
}

const _faceMatchStatusOrder = {'MATCHED': 0, 'LOW_CONFIDENCE': 1, 'UNKNOWN': 2};

int _compareFaceMatches(TourMediaFaceMatch a, TourMediaFaceMatch b) {
  final statusA = _faceMatchStatusOrder[a.matchStatus] ?? 9;
  final statusB = _faceMatchStatusOrder[b.matchStatus] ?? 9;
  if (statusA != statusB) return statusA.compareTo(statusB);
  return b.confidence.compareTo(a.confidence);
}

class TourMediaFaceMatch {
  const TourMediaFaceMatch({
    required this.studentId,
    required this.confidence,
    required this.matchStatus,
    this.id,
    this.studentDisplayName,
    this.boundingBox,
  });

  final String? id;
  final String? studentId;
  final String? studentDisplayName;
  final String? boundingBox;
  final double confidence;
  final String matchStatus;

  factory TourMediaFaceMatch.fromJson(Map<String, dynamic> json) {
    return TourMediaFaceMatch(
      id: json['id']?.toString(),
      studentId:
          json['studentId']?.toString() ?? json['student_id']?.toString(),
      studentDisplayName:
          json['studentDisplayName']?.toString() ??
          json['student_display_name']?.toString() ??
          json['studentName']?.toString() ??
          json['student_name']?.toString(),
      boundingBox:
          json['boundingBox']?.toString() ?? json['bounding_box']?.toString(),
      confidence: double.tryParse(json['confidence']?.toString() ?? '') ?? 0,
      matchStatus:
          json['matchStatus']?.toString() ??
          json['match_status']?.toString() ??
          'UNKNOWN',
    );
  }
}

class TourMediaInteractions {
  const TourMediaInteractions({
    required this.likeCount,
    required this.commentCount,
    required this.likedByCurrentUser,
    required this.comments,
  });

  final int likeCount;
  final int commentCount;
  final bool likedByCurrentUser;
  final List<TourMediaComment> comments;

  factory TourMediaInteractions.fromJson(Map<String, dynamic> json) {
    final commentsJson = json['comments'];
    final comments = commentsJson is List
        ? commentsJson
              .whereType<Map<String, dynamic>>()
              .map(TourMediaComment.fromJson)
              .toList()
        : const <TourMediaComment>[];
    return TourMediaInteractions(
      likeCount:
          int.tryParse(json['likeCount']?.toString() ?? '') ??
          int.tryParse(json['like_count']?.toString() ?? '') ??
          0,
      commentCount:
          int.tryParse(json['commentCount']?.toString() ?? '') ??
          int.tryParse(json['comment_count']?.toString() ?? '') ??
          comments.length,
      likedByCurrentUser:
          json['likedByCurrentUser'] == true ||
          json['liked_by_current_user'] == true ||
          json['likedByCurrentUser']?.toString().toLowerCase() == 'true' ||
          json['liked_by_current_user']?.toString().toLowerCase() == 'true',
      comments: comments,
    );
  }
}

class TourMediaComment {
  const TourMediaComment({
    required this.id,
    required this.accountId,
    required this.content,
    this.authorName,
    this.createdAt,
  });

  final String id;
  final String accountId;
  final String content;
  final String? authorName;
  final DateTime? createdAt;

  factory TourMediaComment.fromJson(Map<String, dynamic> json) {
    final authorName = _firstString(json, ['authorName', 'author_name']);
    return TourMediaComment(
      id: _firstString(json, ['id']),
      accountId: _firstString(json, ['accountId', 'account_id']),
      content: _firstString(json, ['content']),
      authorName: authorName.isEmpty ? null : authorName,
      createdAt: DateTime.tryParse(
        _firstString(json, ['createdAt', 'created_at']),
      ),
    );
  }
}
