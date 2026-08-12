import '../../core/config/app_config.dart';

String resolveMediaUrl(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return '';
  final uri = Uri.tryParse(trimmed);
  if (uri == null) return trimmed;
  if (uri.hasScheme) {
    return uri.isScheme('http') || uri.isScheme('https') ? trimmed : '';
  }
  final base = Uri.parse(AppConfig.apiBaseUrl);
  final origin = base.replace(path: '', query: '', fragment: '');
  return origin.resolve(trimmed).toString();
}

bool isViewableMediaUrl(String value) {
  final resolved = resolveMediaUrl(value);
  if (resolved.isEmpty) return false;
  final uri = Uri.tryParse(resolved);
  return uri != null && (uri.isScheme('http') || uri.isScheme('https'));
}
