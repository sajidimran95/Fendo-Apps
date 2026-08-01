import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../utils/country_dial_codes.dart';

/// Detects visitor country from public IP (for default phone dial code).
class IpCountryService extends ChangeNotifier {
  IpCountryService._();

  static final IpCountryService instance = IpCountryService._();

  static const _fallbackIso = 'BD';
  static const _fallbackDial = '880';

  String? _iso;
  String? _dial;
  String? _countryName;
  Future<void>? _inFlight;

  String get iso => _iso ?? _fallbackIso;
  String get dialCode => _dial ?? _fallbackDial;
  String get countryName => _countryName ?? countryNameForIso(iso);
  String get dialPrefix => '+$dialCode';

  bool get isReady => _iso != null;

  /// Loads country from IP once (cached for app session).
  Future<void> ensureLoaded() {
    if (_iso != null) return Future.value();
    return _inFlight ??= _load().whenComplete(() => _inFlight = null);
  }

  Future<void> _load() async {
    try {
      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 8),
          headers: {'Accept': 'application/json'},
        ),
      );

      final res = await dio.get<Map<String, dynamic>>('https://ipapi.co/json/');
      final map = res.data ?? const {};
      final code = (map['country_code'] ?? map['country'])?.toString().trim();
      if (code != null && code.length == 2) {
        _applyIso(code.toUpperCase());
        debugPrint('IP country → $iso ($countryName) dial +$dialCode');
        return;
      }
    } catch (e) {
      debugPrint('IP country lookup failed: $e');
    }

    try {
      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 8),
        ),
      );
      final res = await dio.get<Map<String, dynamic>>('https://ipwho.is/');
      final map = res.data ?? const {};
      if (map['success'] == true) {
        final code = map['country_code']?.toString().trim();
        if (code != null && code.length == 2) {
          _applyIso(code.toUpperCase());
          debugPrint('IP country → $iso ($countryName) dial +$dialCode');
          return;
        }
      }
    } catch (e) {
      debugPrint('IP country fallback failed: $e');
    }

    _applyIso(_fallbackIso);
    debugPrint('IP country → fallback BD (+880)');
  }

  void _applyIso(String iso) {
    final nextIso = iso.toUpperCase();
    final nextDial = dialCodeForIso(nextIso, fallback: _fallbackDial);
    final nextName = countryNameForIso(nextIso);
    if (_iso == nextIso && _dial == nextDial && _countryName == nextName) {
      return;
    }
    _iso = nextIso;
    _dial = nextDial;
    _countryName = nextName;
    notifyListeners();
  }

  /// Manual override (user picked another country).
  void setCountry(String iso) {
    _applyIso(iso.toUpperCase());
  }
}
