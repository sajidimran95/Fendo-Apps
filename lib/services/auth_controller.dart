import 'package:flutter/foundation.dart';

import '../core/firebase/firebase_phone_otp.dart';
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
import 'contacts_match_service.dart';
import 'dashboard_api.dart';
import 'dashboard_controller.dart';
import 'expenses_api.dart';
import 'groups_api.dart';
import 'notifications_api.dart';
import 'reports_api.dart';
import 'otp_sms_service.dart';
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

  /// 1.4 POST /auth/login (phone)
  Future<UserModel> login({
    required String phone,
    required String password,
  }) async {
    final res = await _api.login(
      phone: phone,
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

  String? _otpFrom(Map<String, dynamic> data) {
    final direct = data['otp']?.toString();
    if (direct != null && direct.isNotEmpty) return direct;
    final nested = data['data'];
    if (nested is Map) {
      final nestedOtp = nested['otp']?.toString();
      if (nestedOtp != null && nestedOtp.isNotEmpty) return nestedOtp;
    }
    return null;
  }

  /// True when API says this phone cannot receive a register OTP
  /// (missing user / already verified / no pending registration).
  bool _resendRegisterUnavailable(ApiException e) {
    final m = e.displayMessage.toLowerCase();
    return m.contains('no account') ||
        m.contains('not found') ||
        m.contains('does not exist') ||
        m.contains('don\'t have an account') ||
        m.contains('do not have an account') ||
        m.contains('already verified') ||
        m.contains('already been verified') ||
        m.contains('no pending') ||
        m.contains('nothing to resend');
  }

  /// Soft-deleted / closed account: login & forgot treat as missing,
  /// but register uniqueness still holds the phone.
  bool isAccountMissing(ApiException e) {
    final m = e.displayMessage.toLowerCase();
    return m.contains('no account') ||
        m.contains('account not found') ||
        m.contains('user not found') ||
        m.contains('does not exist') ||
        m.contains('don\'t have an account') ||
        m.contains('do not have an account') ||
        m.contains('no user found') ||
        (m.contains('not found') && !m.contains('otp'));
  }

  /// True when API says the phone is already fully verified / active account.
  bool isAlreadyVerifiedAccount(ApiException e) {
    final m = e.displayMessage.toLowerCase();
    return m.contains('already verified') ||
        m.contains('already been verified') ||
        m.contains('phone already verified') ||
        m.contains('already active') ||
        (m.contains('already registered') && !m.contains('pending')) ||
        (m.contains('already exists') && m.contains('verified'));
  }

  /// After register says phone is taken:
  /// - [PhoneTakenResolution.unverifiedPending] → open register OTP
  /// - [PhoneTakenResolution.activeAccount] → go to login
  /// - [PhoneTakenResolution.closedAccount] → phone stuck on soft-deleted user
  Future<PhoneTakenResolution> resolvePhoneTakenConflict(String phone) async {
    try {
      await resendOtp(phone: phone, purpose: 'register', awaitSms: false);
      final hasOtp = FirebasePhoneOtp.pendingApiOtp != null &&
          FirebasePhoneOtp.pendingApiOtp!.isNotEmpty;
      return hasOtp
          ? PhoneTakenResolution.unverifiedPending
          : PhoneTakenResolution.activeAccount;
    } on ApiException catch (e) {
      if (isAccountMissing(e)) {
        return PhoneTakenResolution.closedAccount;
      }
      if (isAlreadyVerifiedAccount(e) || _resendMeansVerifiedAccount(e)) {
        // Soft-deleted phones may also look like "no pending". Callers should
        // show a closed-account hint if login/forgot then fail for this number.
        return PhoneTakenResolution.activeAccount;
      }
      rethrow;
    }
  }

  /// After register says phone is taken:
  /// - Unverified account → resend register OTP (returns true)
  /// - Verified account → returns false (caller should go to login)
  Future<bool> resendRegisterOtpIfUnverified(String phone) async {
    final resolution = await resolvePhoneTakenConflict(phone);
    return resolution == PhoneTakenResolution.unverifiedPending;
  }

  bool _resendMeansVerifiedAccount(ApiException e) {
    final m = e.displayMessage.toLowerCase();
    // Resend register OTP is only for pending verification.
    // Do NOT treat "no account" as verified — that is usually soft-delete.
    return m.contains('no pending') ||
        m.contains('nothing to resend') ||
        m.contains('already verified') ||
        m.contains('no otp pending') ||
        m.contains('cannot resend') ||
        m.contains('already completed');
  }

  /// Loads a server OTP for [phone] without blocking on Firebase SMS.
  /// Prefers register resend; falls back to forgot-password for existing accounts.
  /// Returns API purpose: `register` or `reset_password`.
  Future<String> preparePhoneOtp(String phone) async {
    try {
      await resendOtp(phone: phone, purpose: 'register', awaitSms: false);
      return 'register';
    } on ApiException catch (e) {
      if (!_resendRegisterUnavailable(e)) rethrow;
      // Login "needs verify" path may still use forgot as last resort.
      if (isAlreadyVerifiedAccount(e)) rethrow;
      await forgotPassword(phone: phone, awaitSms: false);
      return 'reset_password';
    }
  }

  /// Stores API OTP and optionally waits for Firebase SMS.
  ///
  /// Use [awaitSms] = false from signup/forgot so the UI can open the OTP
  /// screen immediately (robot check happens there). Resend uses true.
  Future<OtpSmsResult> deliverPhoneOtp(
    String phone,
    Map<String, dynamic> data, {
    bool awaitSms = true,
  }) async {
    final otp = _otpFrom(data);
    if (otp == null) {
      return const OtpSmsResult(sent: false, error: 'API did not return OTP');
    }
    if (!awaitSms) {
      // Prepare for OTP screen — do not block navigation on reCAPTCHA.
      FirebasePhoneOtp.pendingPhone = phone;
      FirebasePhoneOtp.pendingApiOtp = otp;
      // Force a fresh Firebase SMS (don't reuse a previous forgot/register session).
      FirebasePhoneOtp.verificationId = null;
      FirebasePhoneOtp.resendToken = null;
      return const OtpSmsResult(sent: false, pending: true);
    }
    return OtpSmsService.sendOtpSms(phone: phone, otp: otp);
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

  /// 1.1 POST /auth/register (phone) — delivers OTP via Firebase SMS.
  Future<Map<String, dynamic>> register({
    required String name,
    required String phone,
    required String password,
    required String passwordConfirmation,
    String? email,
  }) async {
    final data = await _api.register(
      name: name,
      phone: phone,
      password: password,
      passwordConfirmation: passwordConfirmation,
      email: email,
    );
    final sms = await deliverPhoneOtp(phone, data, awaitSms: false);
    return {
      ...data,
      '_sms_sent': sms.sent,
      '_sms_pending': sms.pending,
      '_sms_error': sms.error,
      '_sms_firebase': sms.viaFirebase,
    };
  }

  /// 1.3 POST /auth/resend-otp (phone)
  Future<Map<String, dynamic>> resendOtp({
    required String phone,
    required String purpose,
    bool awaitSms = false,
  }) async {
    final data = await _api.resendOtp(phone: phone, purpose: purpose);
    final sms = await deliverPhoneOtp(phone, data, awaitSms: awaitSms);
    return {
      ...data,
      '_sms_sent': sms.sent,
      '_sms_pending': sms.pending,
      '_sms_error': sms.error,
      '_sms_firebase': sms.viaFirebase,
    };
  }

  /// 1.7 POST /auth/forgot-password (phone)
  Future<Map<String, dynamic>> forgotPassword({
    required String phone,
    bool awaitSms = false,
  }) async {
    final data = await _api.forgotPassword(phone: phone);
    final sms = await deliverPhoneOtp(phone, data, awaitSms: awaitSms);
    return {
      ...data,
      '_sms_sent': sms.sent,
      '_sms_pending': sms.pending,
      '_sms_error': sms.error,
      '_sms_firebase': sms.viaFirebase,
    };
  }

  /// 1.2 POST /auth/verify-otp (register, phone)
  Future<UserModel> verifyRegisterOtp({
    required String phone,
    required String otp,
  }) async {
    final res = await _api.verifyOtp(
      phone: phone,
      otp: otp,
      purpose: 'register',
    );
    await AppPrefs.instance.clearContactsPrefs();
    await applyAuth(
      user: res.user,
      accessToken: res.accessToken,
      tokenType: res.tokenType,
    );
    return res.user;
  }

  /// 1.8 POST /auth/reset-password (phone)
  Future<String?> resetPassword({
    required String phone,
    required String otp,
    required String password,
    required String passwordConfirmation,
  }) async {
    return _api.resetPassword(
      phone: phone,
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
    ContactsMatchService.clearCache();
    await FirebasePhoneOtp.resetSession();
    try {
      await FirebasePhoneOtp.signOutQuietly();
    } catch (_) {}
    notifyListeners();
  }
}

/// How to handle a phone that register rejected as already taken.
enum PhoneTakenResolution {
  /// Pending signup — continue to register OTP.
  unverifiedPending,

  /// Active verified account — send user to login.
  activeAccount,

  /// Soft-deleted / closed: phone still reserved, login/forgot unavailable.
  closedAccount,
}
