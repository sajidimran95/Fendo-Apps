import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'firebase_bootstrap.dart';

class FirebaseSmsStartResult {
  const FirebaseSmsStartResult({
    required this.sent,
    this.error,
  });

  final bool sent;
  final String? error;
}

/// Production Firebase Phone Auth helper for Fendo.
///
/// Hybrid flow:
/// 1) Firebase sends SMS (user types that code)
/// 2) App confirms Firebase SMS, then verifies API with [pendingApiOtp]
class FirebasePhoneOtp {
  FirebasePhoneOtp._();

  static String? verificationId;
  static int? resendToken;
  static String? pendingApiOtp;
  static String? pendingPhone;
  static String? lastError;

  static Future<FirebaseSmsStartResult>? _inFlight;
  static int _requestGen = 0;

  static bool get isAvailable => FirebaseBootstrap.ready;

  static bool get smsWasSent =>
      verificationId != null && verificationId!.isNotEmpty;

  /// Soft reset for a new phone / new OTP request.
  /// Does NOT sign out mid-flight (that causes "missing initial state").
  static void prepareFreshRequest({bool keepResendToken = false}) {
    verificationId = null;
    lastError = null;
    if (!keepResendToken) {
      resendToken = null;
    }
  }

  static Future<void> resetSession() async {
    _requestGen++;
    _inFlight = null;
    prepareFreshRequest(keepResendToken: false);
    pendingApiOtp = null;
    pendingPhone = null;
    // Sign-out only when no verify is in flight.
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
  }

  static Future<FirebaseSmsStartResult> startSms({
    required String phone,
    required String apiOtp,
    bool isResend = false,
  }) {
    return _inFlight ??= _startSmsBody(
      phone: phone,
      apiOtp: apiOtp,
      isResend: isResend,
    ).whenComplete(() => _inFlight = null);
  }

  static Future<FirebaseSmsStartResult> _startSmsBody({
    required String phone,
    required String apiOtp,
    required bool isResend,
  }) async {
    final gen = ++_requestGen;
    pendingPhone = phone;
    pendingApiOtp = apiOtp;
    lastError = null;
    verificationId = null;

    if (!isAvailable) {
      lastError = 'Could not send the code. Please try again.';
      debugPrint(
        'Firebase not ready: ${FirebaseBootstrap.initError ?? 'unknown'}',
      );
      return FirebaseSmsStartResult(sent: false, error: lastError);
    }

    final e164 = phone.trim();
    if (!_looksLikeE164(e164)) {
      lastError = 'Please enter a valid mobile number.';
      return FirebaseSmsStartResult(sent: false, error: lastError);
    }

    // Only use force-resend token on explicit resend with same session.
    final token = isResend ? resendToken : null;
    if (!isResend) {
      resendToken = null;
    }

    final completer = Completer<FirebaseSmsStartResult>();
    var codeSentReceived = false;

    debugPrint(
      'Firebase verifyPhoneNumber → $e164 resend=$isResend token=${token != null}',
    );

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: e164,
        // Auto-retrieval window only. Do NOT treat this as "SMS failed".
        timeout: const Duration(seconds: 60),
        forceResendingToken: token,
        verificationCompleted: (credential) async {
          if (gen != _requestGen) return;
          try {
            await FirebaseAuth.instance.signInWithCredential(credential);
            debugPrint('Firebase phone auto-verified (Play Integrity / SMS)');
          } catch (e) {
            debugPrint('Auto-verify sign-in skipped: $e');
          }
          // Instant verification still means the number is trusted.
          if (!completer.isCompleted) {
            verificationId ??= 'auto-verified';
            completer.complete(const FirebaseSmsStartResult(sent: true));
          }
        },
        verificationFailed: (e) {
          if (gen != _requestGen) return;
          lastError = _friendlyAuthError(e);
          debugPrint('verificationFailed: ${e.code} | ${e.message}');
          if (!isResend) {
            resendToken = null;
          }
          if (!completer.isCompleted) {
            completer.complete(
              FirebaseSmsStartResult(sent: false, error: lastError),
            );
          }
        },
        codeSent: (id, forceToken) {
          if (gen != _requestGen) return;
          codeSentReceived = true;
          verificationId = id;
          resendToken = forceToken;
          lastError = null;
          debugPrint('codeSent OK → SMS should arrive at $e164');
          if (!completer.isCompleted) {
            completer.complete(const FirebaseSmsStartResult(sent: true));
          }
        },
        codeAutoRetrievalTimeout: (id) {
          if (gen != _requestGen) return;
          // SMS auto-read timed out. If codeSent already ran, keep id.
          // Do NOT complete success here if codeSent never fired — that was
          // a major bug causing "sent" with no SMS + broken reCAPTCHA state.
          if (id.isNotEmpty) {
            verificationId ??= id;
          }
          debugPrint(
            'codeAutoRetrievalTimeout (codeSent=$codeSentReceived id=${id.isNotEmpty})',
          );
        },
      );

      final result = await completer.future.timeout(
        const Duration(seconds: 90),
        onTimeout: () {
          if (codeSentReceived ||
              (verificationId != null &&
                  verificationId!.isNotEmpty &&
                  verificationId != 'auto-verified')) {
            return const FirebaseSmsStartResult(sent: true);
          }
          lastError =
              'Could not send the code. Please tap Resend and try again.';
          debugPrint('SMS timeout (no codeSent) for $e164');
          return FirebaseSmsStartResult(sent: false, error: lastError);
        },
      );

      return result;
    } on FirebaseAuthException catch (e) {
      lastError = _friendlyAuthError(e);
      debugPrint('verifyPhoneNumber FirebaseAuthException: ${e.code}');
      return FirebaseSmsStartResult(sent: false, error: lastError);
    } catch (e) {
      debugPrint('verifyPhoneNumber error: $e');
      lastError = 'Could not send the code. Please tap Resend and try again.';
      return FirebaseSmsStartResult(sent: false, error: lastError);
    }
  }

  static bool _looksLikeE164(String phone) {
    return RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(phone);
  }

  static String _friendlyAuthError(FirebaseAuthException e) {
    final code = e.code.toLowerCase();
    final msg = (e.message ?? '').toLowerCase();

    if (code == 'invalid-phone-number' || msg.contains('invalid-phone')) {
      return 'Please enter a valid mobile number.';
    }
    if (code == 'too-many-requests' ||
        code == 'quota-exceeded' ||
        msg.contains('error code:39') ||
        msg.contains('too many')) {
      return 'Too many attempts. Please wait a moment and try again.';
    }
    if (code == 'session-expired' ||
        msg.contains('session') ||
        msg.contains('expired')) {
      return 'Code expired. Please tap Resend.';
    }
    // Never expose Firebase / reCAPTCHA / browser / SHA details to users.
    return 'Could not send the code. Please tap Resend and try again.';
  }

  static Future<bool> confirmSmsCode(String smsCode) async {
    if (!isAvailable) return false;
    if (!smsWasSent || verificationId == null || verificationId == 'auto-verified') {
      // Auto-verified already signed in; accept and continue to API OTP.
      return true;
    }
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId!,
        smsCode: smsCode.trim(),
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
      debugPrint('Firebase SMS code confirmed');
      return true;
    } on FirebaseAuthException catch (e) {
      lastError = e.message ?? e.code;
      debugPrint('confirmSmsCode failed: ${e.code} ${e.message}');
      return false;
    } catch (e) {
      lastError = e.toString();
      debugPrint('confirmSmsCode failed: $e');
      return false;
    }
  }

  static void clear() {
    verificationId = null;
    pendingApiOtp = null;
    pendingPhone = null;
    resendToken = null;
    lastError = null;
  }
}
