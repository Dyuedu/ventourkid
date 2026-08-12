import 'package:dio/dio.dart';

import '../../../../core/network/dio_client.dart';
import '../../domain/entities/newsfeed_item.dart';

abstract interface class NewsfeedRemoteDataSource {
  Future<List<BlogPostPreview>> listPublishedBlogs({
    String? category,
    String? keyword,
  });

  Future<BlogPostPreview> toggleBlogLike({required String postId});

  Future<BlogPostPreview> addBlogComment({
    required String postId,
    required String content,
  });
}

class NewsfeedRemoteDataSourceImpl implements NewsfeedRemoteDataSource {
  const NewsfeedRemoteDataSourceImpl(this._dio);

  final DioClient _dio;

  @override
  Future<List<BlogPostPreview>> listPublishedBlogs({
    String? category,
    String? keyword,
  }) async {
    final response = await _dio.dio.get<Map<String, dynamic>>(
      '/v1/public/blog-posts',
      queryParameters: {
        if (category != null && category.isNotEmpty) 'category': category,
        if (keyword != null && keyword.isNotEmpty) 'keyword': keyword,
      },
      options: Options(extra: const {'skipAuthRefresh': true}),
    );
    final data = response.data?['data'];
    if (data is! List) return const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(BlogPostPreview.fromJson)
        .toList();
  }

  @override
  Future<BlogPostPreview> toggleBlogLike({required String postId}) async {
    final response = await _dio.dio.post<Map<String, dynamic>>(
      '/v1/blog-posts/$postId/like',
    );
    return _blogFromResponse(response.data);
  }

  @override
  Future<BlogPostPreview> addBlogComment({
    required String postId,
    required String content,
  }) async {
    final response = await _dio.dio.post<Map<String, dynamic>>(
      '/v1/blog-posts/$postId/comments',
      data: {'content': content},
    );
    return _blogFromResponse(response.data);
  }

  BlogPostPreview _blogFromResponse(Map<String, dynamic>? response) {
    final data = response?['data'];
    if (data is! Map<String, dynamic>) {
      throw StateError('Invalid blog post response');
    }
    return BlogPostPreview.fromJson(data);
  }
}
