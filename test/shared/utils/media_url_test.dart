import 'package:flutter_test/flutter_test.dart';
import 'package:ventourkid_mobile/core/config/app_config.dart';
import 'package:ventourkid_mobile/shared/utils/media_url.dart';

void main() {
  test('resolves managed blog media path against API origin', () {
    final url = resolveMediaUrl(
      '/api/v1/public/blog-media/11111111-1111-1111-1111-111111111111',
    );

    final apiBase = Uri.parse(AppConfig.apiBaseUrl);
    final origin = apiBase.replace(path: '', query: '', fragment: '');
    expect(
      url,
      origin
          .resolve('/api/v1/public/blog-media/11111111-1111-1111-1111-111111111111')
          .toString(),
    );
    expect(isViewableMediaUrl(url), isTrue);
  });

  test('rejects non HTTP object storage uri for Image.network', () {
    expect(resolveMediaUrl('s3://bucket/object.jpg'), isEmpty);
    expect(isViewableMediaUrl('s3://bucket/object.jpg'), isFalse);
  });
}
