import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// App-level prefs (survives logout) — e.g. one-time contacts permission.
class AppPrefs {
  AppPrefs._();

  static final AppPrefs instance = AppPrefs._();

  static const _promptedKey = 'fendo_contacts_prompted';
  static const _allowedKey = 'fendo_contacts_allowed';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<bool> get contactsPrompted async {
    final v = await _storage.read(key: _promptedKey);
    return v == '1' || v == 'true';
  }

  Future<bool> get contactsAllowed async {
    final v = await _storage.read(key: _allowedKey);
    return v == '1' || v == 'true';
  }

  Future<void> setContactsAllowed(bool allowed) async {
    await _storage.write(key: _promptedKey, value: '1');
    await _storage.write(key: _allowedKey, value: allowed ? '1' : '0');
  }

  /// For tests / reset only.
  Future<void> clearContactsPrefs() async {
    await _storage.delete(key: _promptedKey);
    await _storage.delete(key: _allowedKey);
  }
}
