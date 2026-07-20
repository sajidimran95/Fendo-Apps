import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  TokenStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _tokenKey = 'fendo_access_token';
  static const _tokenTypeKey = 'fendo_token_type';

  final FlutterSecureStorage _storage;

  Future<void> saveToken({
    required String accessToken,
    String tokenType = 'Bearer',
  }) async {
    await _storage.write(key: _tokenKey, value: accessToken);
    await _storage.write(key: _tokenTypeKey, value: tokenType);
  }

  Future<String?> readAccessToken() => _storage.read(key: _tokenKey);

  Future<String?> readTokenType() => _storage.read(key: _tokenTypeKey);

  Future<void> clear() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _tokenTypeKey);
  }
}
