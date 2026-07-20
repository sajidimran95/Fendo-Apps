import 'package:flutter/foundation.dart';

import '../core/network/api_client.dart';
import '../core/network/api_exception.dart';
import '../core/storage/token_storage.dart';
import '../models/user_model.dart';
import 'auth_api.dart';

/// App-wide auth session: token + current user.
class AuthController extends ChangeNotifier {
  AuthController._();

  static final AuthController instance = AuthController._();

  final TokenStorage _storage = TokenStorage();
  late final ApiClient _client = ApiClient(
    tokenStorage: _storage,
    onUnauthorized: () async {
      await _clearLocal();
    },
  );
  late final AuthApi _api = AuthApi(_client);

  AuthApi get api => _api;
  ApiClient get client => _client;

  UserModel? _user;
  bool _ready = false;
  bool _authenticated = false;

  UserModel? get user => _user;
  bool get isReady => _ready;
  bool get isAuthenticated => _authenticated;

  String get deviceName {
    if (kIsWeb) return 'web';
    return '${defaultTargetPlatform.name}-fendo';
  }

  Future<void> bootstrap() async {
    final token = await _storage.readAccessToken();
    if (token == null || token.isEmpty) {
      _authenticated = false;
      _user = null;
      _ready = true;
      notifyListeners();
      return;
    }

    try {
      _user = await _api.me();
      _authenticated = true;
    } on ApiException {
      try {
        final fresh = await _api.refreshToken();
        await _storage.saveToken(accessToken: fresh);
        _user = await _api.me();
        _authenticated = true;
      } on ApiException {
        await _clearLocal();
      }
    }

    _ready = true;
    notifyListeners();
  }

  Future<void> applyAuth({
    required UserModel user,
    required String accessToken,
    String tokenType = 'Bearer',
  }) async {
    await _storage.saveToken(
      accessToken: accessToken,
      tokenType: tokenType,
    );
    _user = user;
    _authenticated = true;
    notifyListeners();
  }

  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    final res = await _api.login(
      email: email,
      password: password,
      deviceName: deviceName,
    );
    await applyAuth(
      user: res.user,
      accessToken: res.accessToken,
      tokenType: res.tokenType,
    );
    return res.user;
  }

  Future<UserModel> socialLogin({
    required String provider,
    required String providerId,
    required String email,
    required String name,
    String? avatar,
  }) async {
    final res = await _api.socialLogin(
      provider: provider,
      providerId: providerId,
      email: email,
      name: name,
      avatar: avatar,
      deviceName: deviceName,
    );
    await applyAuth(
      user: res.user,
      accessToken: res.accessToken,
      tokenType: res.tokenType,
    );
    return res.user;
  }

  Future<void> logout() async {
    try {
      await _api.logout();
    } on ApiException {
      // Still clear local session.
    }
    await _clearLocal();
  }

  Future<UserModel> refreshMe() async {
    final me = await _api.me();
    _user = me;
    _authenticated = true;
    notifyListeners();
    return me;
  }

  Future<void> _clearLocal() async {
    await _storage.clear();
    _user = null;
    _authenticated = false;
    notifyListeners();
  }
}
