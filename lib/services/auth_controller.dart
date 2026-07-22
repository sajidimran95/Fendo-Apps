import 'package:flutter/foundation.dart';

import '../core/network/api_client.dart';
import '../core/network/api_exception.dart';
import '../core/storage/app_prefs.dart';
import '../core/storage/token_storage.dart';
import '../models/user_model.dart';
import 'activity_api.dart';
import 'activity_controller.dart';
import 'auth_api.dart';
import 'balances_api.dart';
import 'bills_api.dart';
import 'categories_api.dart';
import 'contacts_api.dart';
import 'dashboard_api.dart';
import 'dashboard_controller.dart';
import 'expenses_api.dart';
import 'groups_api.dart';
import 'notifications_api.dart';
import 'reports_api.dart';
import 'settlements_api.dart';
import 'user_api.dart';

/// App-wide auth session: token + current user (live API only).
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
  late final ContactsApi _contactsApi = ContactsApi(_client);
  late final DashboardApi _dashboardApi = DashboardApi(_client);

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
  ContactsApi get contactsApi => _contactsApi;
  DashboardApi get dashboardApi => _dashboardApi;
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
    if (token == null || token.isEmpty || token == 'demo-access-token') {
      if (token == 'demo-access-token') {
        await _storage.clear();
      }
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

  /// 1.4 POST /auth/login
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

  /// 1.9 POST /auth/social-login
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

  /// 1.1 POST /auth/register
  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
    String? phone,
  }) async {
    return _api.register(
      name: name,
      email: email,
      password: password,
      passwordConfirmation: passwordConfirmation,
      phone: phone,
    );
  }

  /// 1.2 POST /auth/verify-otp (register)
  Future<UserModel> verifyRegisterOtp({
    required String email,
    required String otp,
  }) async {
    final res = await _api.verifyOtp(
      email: email,
      otp: otp,
      purpose: 'register',
    );
    // Ask contacts permission once after new registration.
    await AppPrefs.instance.clearContactsPrefs();
    await applyAuth(
      user: res.user,
      accessToken: res.accessToken,
      tokenType: res.tokenType,
    );
    return res.user;
  }

  /// 1.3 POST /auth/resend-otp
  Future<String?> resendOtp({
    required String email,
    required String purpose,
  }) async {
    return _api.resendOtp(email: email, purpose: purpose);
  }

  /// 1.7 POST /auth/forgot-password
  Future<String?> forgotPassword({required String email}) async {
    return _api.forgotPassword(email: email);
  }

  /// 1.8 POST /auth/reset-password
  Future<String?> resetPassword({
    required String email,
    required String otp,
    required String password,
    required String passwordConfirmation,
  }) async {
    return _api.resetPassword(
      email: email,
      otp: otp,
      password: password,
      passwordConfirmation: passwordConfirmation,
    );
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
    DashboardController.instance.clear();
    ActivityController.instance.clear();
    notifyListeners();
  }
}
