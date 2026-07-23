import 'dart:io';

import '../config/api_config.dart';

/// Allows TLS for the configured API host when the server chain is incomplete.
/// Needed so [Image.network] / [NetworkImage] can load `/storage/...` avatars
/// (Dio already had this; Flutter's image client did not).
class ApiHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    final apiHost = Uri.tryParse(ApiConfig.baseUrl)?.host;
    client.badCertificateCallback = (cert, host, port) {
      return apiHost != null && host == apiHost;
    };
    return client;
  }
}
