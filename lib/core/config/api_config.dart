/// Backend API configuration.
///
/// Override at run/build time:
/// `flutter run --dart-define=API_BASE_URL=https://your-server.com/api`
/// `flutter run --dart-define=DEMO_AUTH=false`  // real API only
class ApiConfig {
  ApiConfig._();

  /// No trailing slash. Paths are like `/auth/login`.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.fendo.app/api',
  );

  /// When true, any email/password signs in locally (no API).
  /// Set `DEMO_AUTH=false` when your backend is ready.
  static const bool demoAuth = bool.fromEnvironment(
    'DEMO_AUTH',
    defaultValue: true,
  );

  static const Duration connectTimeout = Duration(seconds: 20);
  static const Duration receiveTimeout = Duration(seconds: 20);

  static const String demoToken = 'demo-access-token';
}
