/// API base URL only — change this when the server moves.
/// No trailing slash. Paths look like `/auth/login`.
class ApiConfig {
  ApiConfig._();

  /// Website: https://fendo.posquickcart.com/
  ///
  /// Desired API host: https://api.fendo.posquickcart.com/v1
  /// That host has no DNS yet, so the app uses the live path on the main
  /// subdomain (same server/API): .../api/v1
  /// When api.fendo DNS + SSL work, switch baseUrl to:
  ///   'https://api.fendo.posquickcart.com/v1'
  static const String baseUrl = 'https://fendo.posquickcart.com/api/v1';

  /// When true, any email/password signs in locally (no API).
  /// Keep false for live server.
  static const bool demoAuth = false;

  static const Duration connectTimeout = Duration(seconds: 20);
  static const Duration receiveTimeout = Duration(seconds: 20);
}
