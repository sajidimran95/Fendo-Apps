/// ═══════════════════════════════════════════════════════════
/// API BASE URL — edit ONLY this file.
/// Change [baseUrl] below and the whole app (login, groups,
/// loans, bills, avatars, etc.) uses the new server.
/// No trailing slash. Paths look like `/auth/login`.
/// Example: https://your-domain.com/api/v1
/// ═══════════════════════════════════════════════════════════
class ApiConfig {
  ApiConfig._();

  /// ← PUT YOUR API BASE URL HERE
  static const String baseUrl =
      'https://fendo.posprimepluswholesale.com/api/v1';

  /// When true, any email/password signs in locally (no API).
  /// Keep false for live server.
  static const bool demoAuth = false;

  static const Duration connectTimeout = Duration(seconds: 20);
  static const Duration receiveTimeout = Duration(seconds: 20);
}
