import '../core/config/api_config.dart';

/// Resolves API media paths (avatars, photos) to an absolute URL.
String? resolveMediaUrl(String? path, {int? cacheBust}) {
  if (path == null) return null;
  final raw = path.trim();
  if (raw.isEmpty) return null;

  String url;
  if (raw.startsWith('http://') || raw.startsWith('https://')) {
    url = raw;
  } else {
    // Laravel public disk: storage/{path}
    final cleaned = raw.startsWith('/') ? raw.substring(1) : raw;
    final withStorage = cleaned.startsWith('storage/')
        ? cleaned
        : 'storage/$cleaned';
    final origin = _apiOrigin();
    url = '$origin/$withStorage';
  }

  if (cacheBust != null) {
    final sep = url.contains('?') ? '&' : '?';
    return '$url${sep}t=$cacheBust';
  }
  return url;
}

String _apiOrigin() {
  final base = ApiConfig.baseUrl;
  // Strip /api/v1 or /api/...
  final apiIdx = base.indexOf('/api');
  if (apiIdx > 0) return base.substring(0, apiIdx);
  if (base.endsWith('/')) return base.substring(0, base.length - 1);
  return base;
}
