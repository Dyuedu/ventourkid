import 'package:flutter_test/flutter_test.dart';
import 'package:ventourkid_mobile/features/newsfeed/domain/entities/newsfeed_item.dart';

void main() {
  test('parses blog cover image aliases from API response', () {
    final post = BlogPostPreview.fromJson({
      'id': 'post-1',
      'slug': 'summer-trip',
      'title': 'Summer Trip',
      'cover_image_url':
          '/api/v1/public/blog-media/11111111-1111-1111-1111-111111111111',
      'author_name': 'VentourKids',
      'published_at': '2026-08-02T10:15:00Z',
    });

    expect(post.coverImageUrl, startsWith('/api/v1/public/blog-media/'));
    expect(post.authorName, 'VentourKids');
    expect(post.publishedAt, DateTime.parse('2026-08-02T10:15:00Z'));

    final feedItem = post.toFeedItem();
    expect(feedItem.kind, NewsfeedItemKind.blog);
    expect(feedItem.imageUrl, post.coverImageUrl);
    expect(feedItem.serverId, 'post-1');
  });

  test('parses per-account like state and comments from the server', () {
    final post = BlogPostPreview.fromJson({
      'id': 'post-2',
      'slug': 'da-lat',
      'title': 'Đà Lạt',
      'interactions': {
        'likeCount': 3,
        'commentCount': 1,
        'likedByCurrentUser': true,
        'comments': [
          {
            'id': 'c1',
            'accountId': 'a1',
            'authorName': 'Phụ huynh An',
            'content': 'Ảnh đẹp quá',
            'createdAt': '2026-08-02T10:15:00Z',
          },
        ],
      },
    });

    expect(post.interactions.likeCount, 3);
    expect(post.interactions.likedByCurrentUser, isTrue);
    expect(post.interactions.comments.single.displayAuthor, 'Phụ huynh An');
    expect(post.toFeedItem().interactions.commentCount, 1);
  });

  test('falls back to empty interactions when the server omits them', () {
    final post = BlogPostPreview.fromJson({
      'id': 'post-3',
      'slug': 'tin-tuc',
      'title': 'Tin tức',
    });

    expect(post.interactions.likeCount, 0);
    expect(post.interactions.likedByCurrentUser, isFalse);
    expect(post.interactions.comments, isEmpty);
  });

  test('comment without an author name still renders a readable label', () {
    const comment = NewsfeedComment(id: 'c2', content: 'Hay quá');

    expect(comment.displayAuthor, 'Người dùng VentourKids');
  });
}
