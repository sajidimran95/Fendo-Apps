/// Backend API configuration.
///
/// Override at run/build time:
/// `flutter run --dart-define=API_BASE_URL=https://your-server.com/api`
class ApiConfig {
  ApiConfig._();

  /// No trailing slash. Paths are like `/auth/login`.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.fendo.app/api',
  );

  static const Duration connectTimeout = Duration(seconds: 20);
  static const Duration receiveTimeout = Duration(seconds: 20);
}
