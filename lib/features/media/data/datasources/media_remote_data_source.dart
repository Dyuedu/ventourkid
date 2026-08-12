import 'dart:io';

import 'package:dio/dio.dart';

import '../../../../core/network/dio_client.dart';
import '../../domain/entities/tour_media_item.dart';

abstract interface class MediaRemoteDataSource {
  Future<List<TourMediaItem>> getTimeline({
    required String tourId,
    required String filter,
    String? studentId,
    String? studentName,
    String? activityId,
    String? checkpointId,
  });

  Future<void> upload({
    required String tourId,
    required String path,
    String? filename,
    String? caption,
    String? activityId,
    String? checkpointId,
    String? groupId,
  });

  Future<void> uploadBatch({
    required String tourId,
    required List<MediaUploadFile> files,
    String? caption,
    String? activityId,
    String? checkpointId,
    String? groupId,
  });

  Future<TourMediaItem> toggleLike({required String mediaId});

  Future<TourMediaItem> addComment({
    required String mediaId,
    required String content,
  });
}

class MediaRemoteDataSourceImpl implements MediaRemoteDataSource {
  MediaRemoteDataSourceImpl(this._dio);

  final DioClient _dio;

  @override
  Future<List<TourMediaItem>> getTimeline({
    required String tourId,
    required String filter,
    String? studentId,
    String? studentName,
    String? activityId,
    String? checkpointId,
  }) async {
    final response = await _dio.dio.get<Map<String, dynamic>>(
      '/v1/media/tours/$tourId',
      queryParameters: {
        'filter': filter,
        if (studentId != null && studentId.isNotEmpty) 'studentId': studentId,
        if (studentName != null && studentName.isNotEmpty)
          'studentName': studentName,
        if (activityId != null && activityId.isNotEmpty)
          'activityId': activityId,
        if (checkpointId != null && checkpointId.isNotEmpty)
          'checkpointId': checkpointId,
      },
    );
    final data = response.data?['data'];
    final content = data is Map<String, dynamic> ? data['content'] : null;
    if (content is! List) return const [];
    return content
        .whereType<Map<String, dynamic>>()
        .map(TourMediaItem.fromJson)
        .toList();
  }

  @override
  Future<void> upload({
    required String tourId,
    required String path,
    String? filename,
    String? caption,
    String? activityId,
    String? checkpointId,
    String? groupId,
  }) async {
    final uploadName = filename?.trim().isNotEmpty == true
        ? filename!.trim()
        : null;
    final effectiveName = _ensureUploadFilename(uploadName ?? _basename(path));
    final bytes = await File(path).readAsBytes();
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(
        bytes,
        filename: effectiveName,
        contentType: _resolveUploadContentType(effectiveName),
      ),
    });
    await _dio.dio.post(
      '/v1/media/uploads',
      data: form,
      queryParameters: {
        'tourId': tourId,
        if (activityId != null && activityId.isNotEmpty)
          'activityId': activityId,
        if (checkpointId != null && checkpointId.isNotEmpty)
          'checkpointId': checkpointId,
        if (groupId != null && groupId.isNotEmpty) 'groupId': groupId,
        if (caption != null && caption.isNotEmpty) 'caption': caption,
      },
      options: Options(contentType: 'multipart/form-data'),
    );
  }

  @override
  Future<void> uploadBatch({
    required String tourId,
    required List<MediaUploadFile> files,
    String? caption,
    String? activityId,
    String? checkpointId,
    String? groupId,
  }) async {
    if (files.isEmpty) return;
    final multipartFiles = <MultipartFile>[];
    for (final file in files) {
      final uploadName = file.filename.trim().isNotEmpty
          ? file.filename.trim()
          : _basename(file.path);
      final effectiveName = _ensureUploadFilename(uploadName);
      multipartFiles.add(
        MultipartFile.fromBytes(
          await File(file.path).readAsBytes(),
          filename: effectiveName,
          contentType: _resolveUploadContentType(effectiveName),
        ),
      );
    }
    final form = FormData();
    form.files.addAll(multipartFiles.map((file) => MapEntry('files', file)));
    await _dio.dio.post(
      '/v1/media/uploads/batch',
      data: form,
      queryParameters: {
        'tourId': tourId,
        if (activityId != null && activityId.isNotEmpty)
          'activityId': activityId,
        if (checkpointId != null && checkpointId.isNotEmpty)
          'checkpointId': checkpointId,
        if (groupId != null && groupId.isNotEmpty) 'groupId': groupId,
        if (caption != null && caption.isNotEmpty) 'caption': caption,
      },
      options: Options(contentType: 'multipart/form-data'),
    );
  }

  @override
  Future<TourMediaItem> toggleLike({required String mediaId}) async {
    final response = await _dio.dio.post<Map<String, dynamic>>(
      '/v1/media/$mediaId/like',
    );
    return _mediaItemFromResponse(response.data);
  }

  @override
  Future<TourMediaItem> addComment({
    required String mediaId,
    required String content,
  }) async {
    final response = await _dio.dio.post<Map<String, dynamic>>(
      '/v1/media/$mediaId/comments',
      data: {'content': content},
    );
    return _mediaItemFromResponse(response.data);
  }

  TourMediaItem _mediaItemFromResponse(Map<String, dynamic>? response) {
    final data = response?['data'];
    if (data is! Map<String, dynamic>) {
      throw StateError('Invalid media response');
    }
    return TourMediaItem.fromJson(data);
  }

  String _basename(String path) {
    final segments = Uri.parse(path).pathSegments;
    return segments.isEmpty ? 'media-upload.jpg' : segments.last;
  }

  String _ensureUploadFilename(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return 'media-upload.jpg';
    }
    final lower = trimmed.toLowerCase();
    if (lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.mp4') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.webm')) {
      return trimmed;
    }
    return '$trimmed.jpg';
  }

  DioMediaType? _resolveUploadContentType(String filename) {
    final resolved = MultipartFile.lookupMediaType(filename);
    if (resolved != null) {
      return resolved;
    }
    final lower = filename.toLowerCase();
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
      return DioMediaType.parse('image/jpeg');
    }
    if (lower.endsWith('.png')) {
      return DioMediaType.parse('image/png');
    }
    if (lower.endsWith('.webp')) {
      return DioMediaType.parse('image/webp');
    }
    if (lower.endsWith('.mp4')) {
      return DioMediaType.parse('video/mp4');
    }
    if (lower.endsWith('.mov')) {
      return DioMediaType.parse('video/quicktime');
    }
    if (lower.endsWith('.webm')) {
      return DioMediaType.parse('video/webm');
    }
    return null;
  }
}

class MediaUploadFile {
  const MediaUploadFile({required this.path, required this.filename});

  final String path;
  final String filename;
}
