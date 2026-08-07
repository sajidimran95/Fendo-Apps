import '../storage/app_prefs.dart';
import '../../services/auth_controller.dart';

/// Profile + currency helpers.
///
/// - **First login** for an account → default **USD**
/// - After user changes currency in profile → kept on next launches
class AppCurrency {
  AppCurrency._();

  static const String fallback = 'USD';

  static String? _sessionPreferred;
  static int? _boundUserId;

  /// Picker list (USD first = signup / first-login default).
  static const List<String> codes = [
    'USD',
    'BDT',
    'EUR',
    'GBP',
    'INR',
    'CAD',
    'AUD',
    'JPY',
    'SGD',
    'AED',
    'PKR',
    'NPR',
    'LKR',
    'MYR',
    'THB',
    'CNY',
    'SAR',
    'QAR',
  ];

  /// After login / session restore for [userId].
  ///
  /// First time for this account on this device → **USD**.
  /// Next times → last currency they saved in profile.
  static Future<void> onLogin(int userId) async {
    if (userId <= 0) {
      _sessionPreferred = fallback;
      _boundUserId = null;
      return;
    }
    _boundUserId = userId;
    final stored = await AppPrefs.instance.preferredCurrencyForUser(userId);
    if (stored != null && stored.isNotEmpty) {
      _sessionPreferred = normalize(stored);
      return;
    }
    // First login for this account → USD.
    _sessionPreferred = fallback;
    await AppPrefs.instance.setPreferredCurrencyForUser(userId, fallback);
  }

  static Future<void> hydrate() async {
    final u = AuthController.instance.user;
    if (u != null) {
      await onLogin(u.id);
      return;
    }
    clearSessionPreferred();
  }

  /// User changed currency in profile.
  static Future<void> setPreferred(String code) async {
    final c = normalize(code);
    _sessionPreferred = c;
    final id = _boundUserId ?? AuthController.instance.user?.id;
    if (id != null && id > 0) {
      await AppPrefs.instance.setPreferredCurrencyForUser(id, c);
    }
  }

  static void clearSessionPreferred() {
    _sessionPreferred = null;
    _boundUserId = null;
  }

  static String symbol(String? code) {
    switch (normalize(code)) {
      case 'USD':
        return r'$';
      case 'EUR':
        return '€';
      case 'GBP':
        return '£';
      case 'BDT':
        return '৳';
      case 'INR':
        return '₹';
      case 'JPY':
      case 'CNY':
        return '¥';
      case 'AUD':
        return r'A$';
      case 'CAD':
        return r'C$';
      case 'SGD':
        return r'S$';
      case 'AED':
        return 'د.إ';
      case 'PKR':
      case 'LKR':
        return 'Rs';
      case 'NPR':
        return 'रू';
      case 'MYR':
        return 'RM';
      case 'THB':
        return '฿';
      case 'SAR':
        return '﷼';
      case 'QAR':
        return 'QR';
      default:
        final c = normalize(code);
        return c.length <= 3 ? c : r'$';
    }
  }

  static String label(String? code) {
    final c = normalize(code);
    return '$c · ${symbol(c)}';
  }

  static String normalize(String? code) {
    final t = (code ?? '').trim().toUpperCase();
    return t.isEmpty ? fallback : t;
  }

  static String get profileCode {
    if (_sessionPreferred != null && _sessionPreferred!.isNotEmpty) {
      return normalize(_sessionPreferred);
    }
    final c = AuthController.instance.user?.currency.trim() ?? '';
    if (c.isNotEmpty) return normalize(c);
    return fallback;
  }

  static String get profileSymbol => symbol(profileCode);

  static String resolve({String? groupCurrency, String? explicit}) {
    final e = (explicit ?? '').trim();
    if (e.isNotEmpty) return normalize(e);
    return profileCode;
  }

  static String format(
    double amount, {
    String? code,
    bool showCode = false,
    bool abs = false,
    int? decimals,
  }) {
    final c = normalize(code ?? profileCode);
    final v = abs ? amount.abs() : amount;
    final places = decimals ?? (c == 'JPY' ? 0 : (v % 1 == 0 ? 0 : 2));
    final numStr = v.toStringAsFixed(places);
    final s = symbol(c);
    final looksLatinWord = RegExp(r'^[A-Za-z.]+$').hasMatch(s) && s.length > 1;
    final money = looksLatinWord ? '$s $numStr' : '$s$numStr';
    if (showCode) return '$money $c';
    return money;
  }

  static String formatSigned(
    double amount, {
    String? code,
    bool? positive,
  }) {
    final c = normalize(code ?? profileCode);
    final body = format(amount.abs(), code: c);
    if (positive == null) return body;
    return positive ? '+$body' : '-$body';
  }
}
