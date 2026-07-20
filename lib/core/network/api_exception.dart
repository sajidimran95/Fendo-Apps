class ApiException implements Exception {
  ApiException({
    required this.message,
    this.statusCode,
    this.errors,
  });

  final String message;
  final int? statusCode;
  final Map<String, List<String>>? errors;

  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isValidation => statusCode == 422;

  String get displayMessage {
    if (errors != null && errors!.isNotEmpty) {
      final first = errors!.values.first;
      if (first.isNotEmpty) return first.first;
    }
    return message;
  }

  @override
  String toString() => 'ApiException($statusCode): $message';
}
