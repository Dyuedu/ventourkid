import '../../../media/domain/entities/tour_media_item.dart';

enum NewsfeedItemKind { media, blog }

/// Lượt thích và bình luận lấy từ server. likeCount là số account đã thích,
/// likedByCurrentUser tính riêng cho người đang đăng nhập — không phải cờ dùng chung.
class NewsfeedInteractions {
  const NewsfeedInteractions({
    this.likeCount = 0,
    this.commentCount = 0,
    this.likedByCurrentUser = false,
    this.comments = const [],
  });

  final int likeCount;
  final int commentCount;
  final bool likedByCurrentUser;
  final List<NewsfeedComment> comments;

  factory NewsfeedInteractions.fromJson(Object? value) {
    if (value is! Map<String, dynamic>) return const NewsfeedInteractions();
    final rawComments = value['comments'];
    final comments = rawComments is List
        ? rawComments
              .whereType<Map<String, dynamic>>()
              .map(NewsfeedComment.fromJson)
              .toList()
        : const <NewsfeedComment>[];
    return NewsfeedInteractions(
      likeCount: int.tryParse(value['likeCount']?.toString() ?? '') ?? 0,
      commentCount:
          int.tryParse(value['commentCount']?.toString() ?? '') ??
          comments.length,
      likedByCurrentUser: value['likedByCurrentUser'] == true,
      comments: comments,
    );
  }

  factory NewsfeedInteractions.fromMedia(TourMediaInteractions interactions) {
    return NewsfeedInteractions(
      likeCount: interactions.likeCount,
      commentCount: interactions.commentCount,
      likedByCurrentUser: interactions.likedByCurrentUser,
      comments: interactions.comments
          .map(
            (comment) => NewsfeedComment(
              id: comment.id,
              authorName: comment.authorName,
              content: comment.content,
              createdAt: comment.createdAt,
            ),
          )
          .toList(),
    );
  }
}

class NewsfeedComment {
  const NewsfeedComment({
    required this.id,
    required this.content,
    this.authorName,
    this.createdAt,
  });

  final String id;
  final String content;
  final String? authorName;
  final DateTime? createdAt;

  String get displayAuthor => authorName?.trim().isNotEmpty == true
      ? authorName!.trim()
      : 'Người dùng VentourKids';

  factory NewsfeedComment.fromJson(Map<String, dynamic> json) {
    final authorName = json['authorName']?.toString();
    return NewsfeedComment(
      id: json['id']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      authorName: authorName == null || authorName.isEmpty ? null : authorName,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
    );
  }
}

class NewsfeedItem {
  const NewsfeedItem({
    required this.id,
    required this.kind,
    required this.title,
    required this.publishedAt,
    required this.serverId,
    this.subtitle,
    this.body,
    this.imageUrl,
    this.mediaType,
    this.slug,
    this.category,
    this.interactions = const NewsfeedInteractions(),
    this.mediaAttachments = const [],
  });

  final String id;

  /// Id thật của bản ghi trên server (media id hoặc blog post id) — dùng để gọi like/comment.
  final String serverId;
  final NewsfeedItemKind kind;
  final String title;
  final String? subtitle;
  final String? body;
  final String? imageUrl;
  final String? mediaType;
  final String? slug;
  final String? category;
  final DateTime? publishedAt;
  final NewsfeedInteractions interactions;
  final List<NewsfeedMediaAttachment> mediaAttachments;

  NewsfeedItem copyWith({NewsfeedInteractions? interactions}) {
    return NewsfeedItem(
      id: id,
      serverId: serverId,
      kind: kind,
      title: title,
      subtitle: subtitle,
      body: body,
      imageUrl: imageUrl,
      mediaType: mediaType,
      slug: slug,
      category: category,
      publishedAt: publishedAt,
      interactions: interactions ?? this.interactions,
      mediaAttachments: mediaAttachments,
    );
  }

  factory NewsfeedItem.fromMedia(TourMediaItem media) {
    final caption = media.caption?.trim();
    final isVideo = media.mediaType.toUpperCase() == 'VIDEO';
    final bestMatch = media.faceMatches.isEmpty
        ? null
        : media.faceMatches.first;
    return NewsfeedItem(
      id: 'media-${media.id}',
      serverId: media.id,
      kind: NewsfeedItemKind.media,
      title: caption?.isNotEmpty == true
          ? caption!
          : isVideo
          ? 'Video chuyến đi'
          : 'Ảnh chuyến đi',
      subtitle: bestMatch?.studentDisplayName,
      imageUrl: media.fileUrl,
      mediaType: media.mediaType,
      mediaAttachments: [NewsfeedMediaAttachment.fromMedia(media)],
      publishedAt: media.createdAt,
      interactions: NewsfeedInteractions.fromMedia(media.interactions),
    );
  }
}

class NewsfeedMediaAttachment {
  const NewsfeedMediaAttachment({
    required this.id,
    required this.url,
    required this.mediaType,
    this.thumbnailUrl,
    this.caption,
    this.students = const [],
    this.faceMatches = const [],
  });

  final String id;
  final String url;
  final String mediaType;
  final String? thumbnailUrl;
  final String? caption;
  final List<NewsfeedMediaStudent> students;
  final List<TourMediaFaceMatch> faceMatches;

  bool get isVideo => mediaType.toUpperCase() == 'VIDEO';

  String get displayUrl =>
      thumbnailUrl?.trim().isNotEmpty == true ? thumbnailUrl!.trim() : url;

  String? get studentLabel {
    final names =
        [
              ...students.map((student) => student.displayName),
              ...faceMatches.map((match) => match.studentDisplayName),
            ]
            .where((name) => name?.trim().isNotEmpty == true)
            .map((name) => name!.trim());
    final uniqueNames = <String>{};
    for (final name in names) {
      uniqueNames.add(name);
    }
    return uniqueNames.isEmpty ? null : uniqueNames.join(', ');
  }

  factory NewsfeedMediaAttachment.fromMedia(TourMediaItem media) {
    return NewsfeedMediaAttachment(
      id: media.id,
      url: media.fileUrl,
      mediaType: media.mediaType,
      caption: media.caption,
      faceMatches: media.faceMatches,
    );
  }

  factory NewsfeedMediaAttachment.fromJson(Map<String, dynamic> json) {
    final faceMatchesRaw = json['faceMatches'] ?? json['face_matches'];
    final faceMatches = faceMatchesRaw is List
        ? faceMatchesRaw
              .map(_asStringMap)
              .whereType<Map<String, dynamic>>()
              .map(TourMediaFaceMatch.fromJson)
              .toList()
        : const <TourMediaFaceMatch>[];
    final studentsRaw =
        json['students'] ??
        json['studentMatches'] ??
        json['student_matches'] ??
        json['taggedStudents'] ??
        json['tagged_students'];
    final students = studentsRaw is List
        ? studentsRaw
              .map(NewsfeedMediaStudent.fromValue)
              .whereType<NewsfeedMediaStudent>()
              .toList()
        : const <NewsfeedMediaStudent>[];
    return NewsfeedMediaAttachment(
      id: _firstString(json, ['id', 'mediaId', 'media_id']),
      url: _firstString(json, [
        'url',
        'fileUrl',
        'file_url',
        'mediaUrl',
        'media_url',
        'src',
      ]),
      thumbnailUrl: _nullableString(json, [
        'thumbnailUrl',
        'thumbnail_url',
        'previewUrl',
        'preview_url',
      ]),
      mediaType: _firstString(json, [
        'mediaType',
        'media_type',
        'type',
      ], 'IMAGE'),
      caption: _nullableString(json, ['caption', 'description']),
      students: students,
      faceMatches: faceMatches,
    );
  }
}

class NewsfeedMediaStudent {
  const NewsfeedMediaStudent({
    this.studentId,
    this.displayName,
    this.className,
  });

  final String? studentId;
  final String? displayName;
  final String? className;

  static NewsfeedMediaStudent? fromValue(Object? value) {
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty
          ? null
          : NewsfeedMediaStudent(displayName: trimmed);
    }
    final json = _asStringMap(value);
    if (json == null) return null;
    final student = NewsfeedMediaStudent(
      studentId: _nullableString(json, ['studentId', 'student_id', 'id']),
      displayName: _nullableString(json, [
        'studentDisplayName',
        'student_display_name',
        'displayName',
        'display_name',
        'studentName',
        'student_name',
        'name',
      ]),
      className: _nullableString(json, ['className', 'class_name']),
    );
    return student.studentId == null &&
            student.displayName == null &&
            student.className == null
        ? null
        : student;
  }
}

class BlogPostPreview {
  const BlogPostPreview({
    required this.id,
    required this.slug,
    required this.title,
    this.excerpt,
    this.content,
    this.coverImageUrl,
    this.authorName,
    this.category,
    this.mediaAttachments = const [],
    this.publishedAt,
    this.createdAt,
    this.interactions = const NewsfeedInteractions(),
  });

  final String id;
  final String slug;
  final String title;
  final String? excerpt;
  final String? content;
  final String? coverImageUrl;
  final String? authorName;
  final String? category;
  final List<NewsfeedMediaAttachment> mediaAttachments;
  final DateTime? publishedAt;
  final DateTime? createdAt;
  final NewsfeedInteractions interactions;

  factory BlogPostPreview.fromJson(Map<String, dynamic> json) {
    final mediaRaw = json['media'] ?? json['mediaItems'] ?? json['media_items'];
    final attachments = mediaRaw is List
        ? mediaRaw
              .map(_asStringMap)
              .whereType<Map<String, dynamic>>()
              .map(NewsfeedMediaAttachment.fromJson)
              .where((attachment) => attachment.url.trim().isNotEmpty)
              .toList()
        : const <NewsfeedMediaAttachment>[];
    return BlogPostPreview(
      id: json['id']?.toString() ?? '',
      slug: json['slug']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Bài viết',
      excerpt: json['excerpt']?.toString(),
      content: json['content']?.toString(),
      coverImageUrl:
          json['coverImageUrl']?.toString() ??
          json['cover_image_url']?.toString() ??
          json['coverUrl']?.toString() ??
          json['cover_url']?.toString() ??
          json['coverImage']?.toString() ??
          json['cover_image']?.toString() ??
          json['thumbnailUrl']?.toString() ??
          json['thumbnail_url']?.toString() ??
          json['imageUrl']?.toString() ??
          json['image_url']?.toString() ??
          json['fileUrl']?.toString() ??
          json['file_url']?.toString(),
      authorName:
          json['authorName']?.toString() ?? json['author_name']?.toString(),
      category: json['category']?.toString(),
      mediaAttachments: attachments,
      publishedAt: DateTime.tryParse(
        json['publishedAt']?.toString() ??
            json['published_at']?.toString() ??
            '',
      ),
      createdAt: DateTime.tryParse(
        json['createdAt']?.toString() ?? json['created_at']?.toString() ?? '',
      ),
      interactions: NewsfeedInteractions.fromJson(json['interactions']),
    );
  }

  NewsfeedItem toFeedItem() {
    final attachments = mediaAttachments.isNotEmpty
        ? mediaAttachments
        : coverImageUrl?.trim().isNotEmpty == true
        ? [
            NewsfeedMediaAttachment(
              id: '$id-cover',
              url: coverImageUrl!.trim(),
              mediaType: 'IMAGE',
            ),
          ]
        : const <NewsfeedMediaAttachment>[];
    return NewsfeedItem(
      id: 'blog-$id',
      serverId: id,
      kind: NewsfeedItemKind.blog,
      title: title,
      subtitle: authorName,
      body: excerpt?.trim().isNotEmpty == true
          ? excerpt!.trim()
          : _plainText(content),
      imageUrl: coverImageUrl,
      slug: slug,
      category: category,
      mediaAttachments: attachments,
      publishedAt: publishedAt ?? createdAt,
      interactions: interactions,
    );
  }
}

Map<String, dynamic>? _asStringMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, child) => MapEntry(key.toString(), child));
  }
  return null;
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

String? _plainText(String? html) {
  final value = html
      ?.replaceAll(RegExp('<[^>]+>'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (value == null || value.isEmpty) return null;
  return value;
}
