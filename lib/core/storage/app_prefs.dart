import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// App-level prefs (survives logout) — e.g. one-time permission prompts.
class AppPrefs {
  AppPrefs._();

  static final AppPrefs instance = AppPrefs._();

  static const _contactsPromptedKey = 'fendo_contacts_prompted';
  static const _contactsAllowedKey = 'fendo_contacts_allowed';
  static const _notificationsPromptedKey = 'fendo_notifications_prompted';
  static const _notificationsAllowedKey = 'fendo_notifications_allowed';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<bool> get contactsPrompted async {
    final v = await _storage.read(key: _contactsPromptedKey);
    return v == '1' || v == 'true';
  }

  Future<bool> get contactsAllowed async {
    final v = await _storage.read(key: _contactsAllowedKey);
    return v == '1' || v == 'true';
  }

  Future<void> setContactsAllowed(bool allowed) async {
    await _storage.write(key: _contactsPromptedKey, value: '1');
    await _storage.write(
      key: _contactsAllowedKey,
      value: allowed ? '1' : '0',
    );
  }

  Future<bool> get notificationsPrompted async {
    final v = await _storage.read(key: _notificationsPromptedKey);
    return v == '1' || v == 'true';
  }

  Future<bool> get notificationsAllowed async {
    final v = await _storage.read(key: _notificationsAllowedKey);
    return v == '1' || v == 'true';
  }

  Future<void> setNotificationsAllowed(bool allowed) async {
    await _storage.write(key: _notificationsPromptedKey, value: '1');
    await _storage.write(
      key: _notificationsAllowedKey,
      value: allowed ? '1' : '0',
    );
  }

  /// For tests / reset only.
  Future<void> clearContactsPrefs() async {
    await _storage.delete(key: _contactsPromptedKey);
    await _storage.delete(key: _contactsAllowedKey);
  }

  Future<void> clearNotificationsPrefs() async {
    await _storage.delete(key: _notificationsPromptedKey);
    await _storage.delete(key: _notificationsAllowedKey);
  }
}
