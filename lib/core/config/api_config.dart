/// Backend API configuration.
///
/// Override at run/build time:
/// `flutter run --dart-define=API_BASE_URL=https://your-server.com/v1`
/// `flutter run --dart-define=DEMO_AUTH=true`  // local demo only
class ApiConfig {
  ApiConfig._();

  /// No trailing slash. Paths are like `/auth/login`.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://fendo.posprimepluswholesale.com/api/v1',
  );

  /// When true, any email/password signs in locally (no API).
  /// Live builds use the real backend (default false).
  static const bool demoAuth = bool.fromEnvironment(
    'DEMO_AUTH',
    defaultValue: false,
  );

  static const Duration connectTimeout = Duration(seconds: 20);
  static const Duration receiveTimeout = Duration(seconds: 20);
}
