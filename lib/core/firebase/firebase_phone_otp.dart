import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'firebase_bootstrap.dart';

/// Result of starting native Firebase Phone Auth SMS.
class FirebaseSmsStartResult {
  const FirebaseSmsStartResult({
    required this.sent,
    this.error,
    this.errorCode,
  });

  final bool sent;
  final String? error;
  final String? errorCode;
}

/// Official FlutterFire Phone Authentication (native `verifyPhoneNumber`).
///
/// Backend [pendingApiOtp] is stored so after the user confirms the Firebase
/// SMS code, the app can call your API verify endpoint.
class FirebasePhoneOtp {
  FirebasePhoneOtp._();

  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static String? verificationId;
  static int? resendToken;
  static String? pendingApiOtp;
  static String? pendingPhone;
  static String? lastError;
  static String? lastErrorCode;

  static Future<FirebaseSmsStartResult>? _inFlight;

  static bool get isAvailable => FirebaseBootstrap.ready;

  static bool get smsWasSent =>
      verificationId != null && verificationId!.isNotEmpty;

  static void _log(String msg) {
    // ignore: avoid_print
    print('[FendoOTP] $msg');
  }

  static void prepareFreshRequest({bool keepResendToken = false}) {
    verificationId = null;
    lastError = null;
    lastErrorCode = null;
    if (!keepResendToken) {
      resendToken = null;
    }
  }

  static void clear() {
    verificationId = null;
    pendingApiOtp = null;
    pendingPhone = null;
    resendToken = null;
    lastError = null;
    lastErrorCode = null;
  }

  static Future<void> resetSession() async {
    _inFlight = null;
    clear();
  }

  static Future<void> signOutQuietly() async {
    try {
      if (_auth.currentUser != null) {
        await _auth.signOut();
      }
    } catch (e) {
      _log('signOut skipped: $e');
    }
  }

  /// Do not call [signOut] before this — breaks reCAPTCHA (missing initial state).
  static Future<FirebaseSmsStartResult> startSms({
    required String phone,
    required String apiOtp,
    bool isResend = false,
  }) {
    return _inFlight ??= _verifyPhoneNumber(
      phone: phone,
      apiOtp: apiOtp,
      isResend: isResend,
    ).whenComplete(() => _inFlight = null);
  }

  static Future<FirebaseSmsStartResult> _verifyPhoneNumber({
    required String phone,
    required String apiOtp,
    required bool isResend,
  }) async {
    pendingPhone = phone;
    pendingApiOtp = apiOtp;
    lastError = null;
    lastErrorCode = null;
    verificationId = null;

    if (!isAvailable) {
      lastErrorCode = 'firebase-not-ready';
      lastError =
          'Firebase not ready. ${FirebaseBootstrap.initError ?? "Restart the app."}';
      _log('FAIL firebase-not-ready: ${FirebaseBootstrap.initError}');
      return FirebaseSmsStartResult(
        sent: false,
        error: lastError,
        errorCode: lastErrorCode,
      );
    }

    final phoneNumber = phone.trim();
    if (!_isE164(phoneNumber)) {
      lastErrorCode = 'invalid-phone-number';
      lastError = 'Please enter a valid mobile number with country code (+…).';
      _log('FAIL invalid phone: $phoneNumber');
      return FirebaseSmsStartResult(
        sent: false,
        error: lastError,
        errorCode: lastErrorCode,
      );
    }

    final forceResendingToken = isResend ? resendToken : null;
    if (!isResend) {
      resendToken = null;
    }

    final completer = Completer<FirebaseSmsStartResult>();
    _log(
      'START $phoneNumber resend=$isResend forceToken=${forceResendingToken != null} '
      'project=${_auth.app.options.projectId}',
    );

    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        timeout: const Duration(seconds: 60),
        forceResendingToken: forceResendingToken,
        verificationCompleted: (PhoneAuthCredential credential) async {
          _log('callback verificationCompleted');
          try {
            await _auth.signInWithCredential(credential);
          } catch (e) {
            _log('auto sign-in: $e');
          }
          if (!completer.isCompleted) {
            verificationId ??= 'auto-verified';
            completer.complete(
              const FirebaseSmsStartResult(
                sent: true,
                errorCode: 'auto-verified',
              ),
            );
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          lastErrorCode = e.code;
          lastError = _userMessage(e);
          _log('FAIL verificationFailed code=${e.code} message=${e.message}');
          if (!completer.isCompleted) {
            completer.complete(
              FirebaseSmsStartResult(
                sent: false,
                error: lastError,
                errorCode: e.code,
              ),
            );
          }
        },
        codeSent: (String id, int? token) {
          verificationId = id;
          resendToken = token;
          lastError = null;
          lastErrorCode = null;
          _log('OK codeSent idLen=${id.length} token=${token != null}');
          if (!completer.isCompleted) {
            completer.complete(
              const FirebaseSmsStartResult(sent: true, errorCode: 'code-sent'),
            );
          }
        },
        codeAutoRetrievalTimeout: (String id) {
          // BUGFIX: previously this did not complete the future, so the UI
          // always timed out even when Firebase had issued a verification id.
          verificationId ??= id;
          _log('callback codeAutoRetrievalTimeout idLen=${id.length}');
          if (id.isNotEmpty && !completer.isCompleted) {
            lastError = null;
            lastErrorCode = null;
            completer.complete(
              const FirebaseSmsStartResult(
                sent: true,
                errorCode: 'code-auto-timeout',
              ),
            );
          }
        },
      );

      return await completer.future.timeout(
        const Duration(seconds: 120),
        onTimeout: () {
          if (smsWasSent) {
            return const FirebaseSmsStartResult(
              sent: true,
              errorCode: 'timeout-but-sent',
            );
          }
          lastErrorCode = 'timeout';
          lastError =
              'SMS timed out. After robot check stay in the app — do not refresh the browser. Tap Resend.';
          _log(
            'FAIL timeout. Causes: reCAPTCHA broken (missing initial state), '
            'SHA-1 missing, quota, network.',
          );
          return FirebaseSmsStartResult(
            sent: false,
            error: lastError,
            errorCode: lastErrorCode,
          );
        },
      );
    } on FirebaseAuthException catch (e) {
      lastErrorCode = e.code;
      lastError = _userMessage(e);
      _log('FAIL thrown ${e.code} ${e.message}');
      return FirebaseSmsStartResult(
        sent: false,
        error: lastError,
        errorCode: e.code,
      );
    } catch (e, st) {
      lastErrorCode = 'unexpected';
      lastError = _messageFromRaw(e.toString());
      _log('FAIL unexpected: $e\n$st');
      return FirebaseSmsStartResult(
        sent: false,
        error: lastError,
        errorCode: lastErrorCode,
      );
    }
  }

  static Future<bool> confirmSmsCode(String smsCode) async {
    if (!isAvailable) return false;
    if (verificationId == null || verificationId == 'auto-verified') {
      return true;
    }
    if (!smsWasSent) return false;

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId!,
        smsCode: smsCode.trim(),
      );
      await _auth.signInWithCredential(credential);
      _log('confirmSmsCode OK');
      return true;
    } on FirebaseAuthException catch (e) {
      lastErrorCode = e.code;
      lastError = _userMessage(e);
      _log('confirmSmsCode FAIL ${e.code} ${e.message}');
      return false;
    } catch (e) {
      lastError = 'Invalid code. Please check and try again.';
      _log('confirmSmsCode FAIL $e');
      return false;
    }
  }

  static bool _isE164(String phone) =>
      RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(phone);

  static bool _isMissingInitialState(String raw) {
    final lower = raw.toLowerCase();
    return lower.contains('missing initial state') ||
        lower.contains('unable to process request');
  }

  static String _messageFromRaw(String raw) {
    if (_isMissingInitialState(raw)) {
      return 'Robot check session expired. Return to Fendo and tap Resend once. Do not refresh the browser.';
    }
    return 'Could not send the code. Please tap Resend and try again.';
  }

  static String _userMessage(FirebaseAuthException e) {
    final raw = '${e.code} ${e.message ?? ''}';
    if (_isMissingInitialState(raw)) {
      return 'Robot check session expired. Return to Fendo and tap Resend once. Do not refresh the browser.';
    }
    switch (e.code) {
      case 'invalid-phone-number':
        return 'Please enter a valid mobile number with country code.';
      case 'too-many-requests':
      case 'quota-exceeded':
        return 'Too many SMS attempts. Wait 1–2 hours and try again.';
      case 'session-expired':
      case 'invalid-verification-code':
      case 'invalid-verification-id':
        return 'Invalid or expired code. Please tap Resend.';
      case 'missing-client-identifier':
      case 'invalid-app-credential':
      case 'app-not-authorized':
        return 'App not authorized for SMS. Add SHA-1 in Firebase (project settings), then reinstall the app.';
      case 'captcha-check-failed':
        return 'Robot check failed. Return to the app and tap Resend.';
      case 'web-context-cancelled':
        return 'Robot check was cancelled. Tap Resend and try again.';
      case 'network-request-failed':
        return 'Network error. Check internet and try again.';
      case 'operation-not-allowed':
        return 'Phone sign-in is disabled in Firebase Console.';
      case 'internal-error':
        // Firebase often maps reCAPTCHA / Play Integrity failures here (error 39).
        return 'SMS failed (Firebase internal error). Complete robot check without refreshing the page, or wait and tap Resend. If it keeps failing, check SHA-1 + Phone Auth in Firebase.';
      default:
        final detail = e.message?.trim();
        if (detail != null && detail.isNotEmpty && detail.length < 140) {
          return 'SMS failed (${e.code}): $detail';
        }
        return 'SMS failed (${e.code}). Tap Resend and try again.';
    }
  }
}
