import 'package:flutter/foundation.dart';

import '../core/config/api_config.dart';
import '../core/network/api_client.dart';
import '../core/network/api_exception.dart';
import '../core/storage/token_storage.dart';
import '../models/user_model.dart';
import 'activity_api.dart';
import 'auth_api.dart';
import 'balances_api.dart';
import 'bills_api.dart';
import 'categories_api.dart';
import 'expenses_api.dart';
import 'groups_api.dart';
import 'notifications_api.dart';
import 'reports_api.dart';
import 'settlements_api.dart';
import 'user_api.dart';

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
  late final UserApi _userApi = UserApi(_client);
  late final GroupsApi _groupsApi = GroupsApi(_client);
  late final ExpensesApi _expensesApi = ExpensesApi(_client);
  late final BalancesApi _balancesApi = BalancesApi(_client);
  late final BillsApi _billsApi = BillsApi(_client);
  late final SettlementsApi _settlementsApi = SettlementsApi(_client);
  late final ActivityApi _activityApi = ActivityApi(_client);
  late final NotificationsApi _notificationsApi = NotificationsApi(_client);
  late final ReportsApi _reportsApi = ReportsApi(_client);
  late final CategoriesApi _categoriesApi = CategoriesApi(_client);

  AuthApi get api => _api;
  UserApi get userApi => _userApi;
  GroupsApi get groupsApi => _groupsApi;
  ExpensesApi get expensesApi => _expensesApi;
  BalancesApi get balancesApi => _balancesApi;
  BillsApi get billsApi => _billsApi;
  SettlementsApi get settlementsApi => _settlementsApi;
  ActivityApi get activityApi => _activityApi;
  NotificationsApi get notificationsApi => _notificationsApi;
  ReportsApi get reportsApi => _reportsApi;
  CategoriesApi get categoriesApi => _categoriesApi;
  ApiClient get client => _client;

  UserModel? _user;
  bool _ready = false;
  bool _authenticated = false;
  bool _demo = false;

  UserModel? get user => _user;
  bool get isReady => _ready;
  bool get isAuthenticated => _authenticated;
  bool get isDemo => _demo;

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

    if (token == ApiConfig.demoToken) {
      final email = await _storage.readDemoEmail() ?? 'demo@fendo.app';
      final name = await _storage.readDemoName() ?? _nameFromEmail(email);
      _user = _demoUser(email: email, name: name);
      _authenticated = true;
      _demo = true;
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
    if (ApiConfig.demoAuth) {
      return _loginDemo(email: email);
    }

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
    if (ApiConfig.demoAuth) {
      return _loginDemo(email: email, name: name);
    }

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

  /// 1.1 Register — returns message (and optional dev OTP).
  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
    String? phone,
  }) async {
    if (ApiConfig.demoAuth) {
      return {
        'email': email,
        'message': 'Registration successful. Please verify your email.',
        'otp': '123456',
      };
    }
    return _api.register(
      name: name,
      email: email,
      password: password,
      passwordConfirmation: passwordConfirmation,
      phone: phone,
    );
  }

  /// 1.2 Verify OTP for register → session.
  Future<UserModel> verifyRegisterOtp({
    required String email,
    required String otp,
  }) async {
    if (ApiConfig.demoAuth) {
      return _loginDemo(email: email);
    }
    final res = await _api.verifyOtp(
      email: email,
      otp: otp,
      purpose: 'register',
    );
    await applyAuth(
      user: res.user,
      accessToken: res.accessToken,
      tokenType: res.tokenType,
    );
    return res.user;
  }

  /// 1.3 Resend OTP
  Future<String?> resendOtp({
    required String email,
    required String purpose,
  }) async {
    if (ApiConfig.demoAuth) {
      return 'OTP resent successfully.';
    }
    return _api.resendOtp(email: email, purpose: purpose);
  }

  Future<UserModel> _loginDemo({
    required String email,
    String? name,
  }) async {
    final resolvedName = (name != null && name.trim().isNotEmpty)
        ? name.trim()
        : _nameFromEmail(email);
    final user = _demoUser(email: email, name: resolvedName);
    await _storage.saveDemoIdentity(email: email, name: resolvedName);
    _demo = true;
    await applyAuth(
      user: user,
      accessToken: ApiConfig.demoToken,
    );
    return user;
  }

  UserModel _demoUser({required String email, required String name}) {
    return UserModel(
      id: 1,
      name: name,
      email: email,
      phone: '+1 555 0100',
      currency: 'USD',
      timezone: 'UTC',
      language: 'en',
    );
  }

  String _nameFromEmail(String email) {
    final local = email.split('@').first.trim();
    if (local.isEmpty) return 'Fendo User';
    return local[0].toUpperCase() + local.substring(1);
  }

  Future<void> logout() async {
    final token = await _storage.readAccessToken();
    if (token != ApiConfig.demoToken) {
      try {
        await _api.logout();
      } on ApiException {
        // Still clear local session.
      }
    }
    await _clearLocal();
  }

  Future<UserModel> refreshMe() async {
    final token = await _storage.readAccessToken();
    if (token == ApiConfig.demoToken) {
      return _user!;
    }
    try {
      _user = await _userApi.getProfile();
    } on ApiException {
      _user = await _api.me();
    }
    _authenticated = true;
    notifyListeners();
    return _user!;
  }

  void setUser(UserModel user) {
    _user = user;
    _authenticated = true;
    notifyListeners();
  }

  Future<void> clearSession() => _clearLocal();

  Future<void> _clearLocal() async {
    await _storage.clear();
    _user = null;
    _authenticated = false;
    _demo = false;
    notifyListeners();
  }
}
