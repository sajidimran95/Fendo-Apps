import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  TokenStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _tokenKey = 'fendo_access_token';
  static const _tokenTypeKey = 'fendo_token_type';
  static const _demoEmailKey = 'fendo_demo_email';
  static const _demoNameKey = 'fendo_demo_name';

  final FlutterSecureStorage _storage;

  Future<void> saveToken({
    required String accessToken,
    String tokenType = 'Bearer',
  }) async {
    await _storage.write(key: _tokenKey, value: accessToken);
    await _storage.write(key: _tokenTypeKey, value: tokenType);
  }

  Future<void> saveDemoIdentity({
    required String email,
    required String name,
  }) async {
    await _storage.write(key: _demoEmailKey, value: email);
    await _storage.write(key: _demoNameKey, value: name);
  }

  Future<String?> readAccessToken() => _storage.read(key: _tokenKey);

  Future<String?> readTokenType() => _storage.read(key: _tokenTypeKey);

  Future<String?> readDemoEmail() => _storage.read(key: _demoEmailKey);

  Future<String?> readDemoName() => _storage.read(key: _demoNameKey);

  Future<void> clear() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _tokenTypeKey);
    await _storage.delete(key: _demoEmailKey);
    await _storage.delete(key: _demoNameKey);
  }
}
