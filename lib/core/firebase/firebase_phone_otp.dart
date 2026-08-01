import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'firebase_bootstrap.dart';

/// Result of starting native Firebase Phone Auth SMS.
class FirebaseSmsStartResult {
  const FirebaseSmsStartResult({
    required this.sent,
    this.error,
  });

  final bool sent;
  final String? error;
}

/// Official FlutterFire Phone Authentication (native `verifyPhoneNumber`).
///
/// Matches: https://firebase.google.com/docs/auth/flutter/phone-auth
///
/// Fendo still stores [pendingApiOtp] from your backend so after the user
/// confirms the Firebase SMS code, the app can call your API verify endpoint.
class FirebasePhoneOtp {
  FirebasePhoneOtp._();

  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// From FlutterFire `codeSent` / `codeAutoRetrievalTimeout`.
  static String? verificationId;

  /// Android-only; pass to `forceResendingToken` on resend (official docs).
  static int? resendToken;

  /// Backend OTP (not the Firebase SMS code).
  static String? pendingApiOtp;
  static String? pendingPhone;
  static String? lastError;

  static Future<FirebaseSmsStartResult>? _inFlight;

  static bool get isAvailable => FirebaseBootstrap.ready;

  static bool get smsWasSent =>
      verificationId != null && verificationId!.isNotEmpty;

  static void prepareFreshRequest({bool keepResendToken = false}) {
    verificationId = null;
    lastError = null;
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
  }

  /// Soft clear without signing the user out of Firebase mid-flow.
  static Future<void> resetSession() async {
    _inFlight = null;
    clear();
  }

  /// Clears Firebase phone session after logout / account delete.
  static Future<void> signOutQuietly() async {
    try {
      if (_auth.currentUser != null) {
        await _auth.signOut();
      }
    } catch (e) {
      debugPrint('Firebase signOut skipped: $e');
    }
  }

  /// Starts native phone verification (FlutterFire `verifyPhoneNumber`).
  ///
  /// On Android, Play Integrity / reCAPTCHA is handled entirely by the SDK —
  /// do not add custom browser handling.
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
    verificationId = null;

    if (!isAvailable) {
      lastError = 'Could not send the code. Please try again.';
      return FirebaseSmsStartResult(sent: false, error: lastError);
    }

    final phoneNumber = phone.trim();
    if (!_isE164(phoneNumber)) {
      lastError = 'Please enter a valid mobile number.';
      return FirebaseSmsStartResult(sent: false, error: lastError);
    }

    final forceResendingToken = isResend ? resendToken : null;
    if (!isResend) {
      resendToken = null;
    }

    final completer = Completer<FirebaseSmsStartResult>();

    debugPrint(
      'FlutterFire verifyPhoneNumber → $phoneNumber '
      '(resend=$isResend, forceToken=${forceResendingToken != null})',
    );

    try {
      // Official FlutterFire native API:
      // https://firebase.google.com/docs/auth/flutter/phone-auth
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        timeout: const Duration(seconds: 60),
        forceResendingToken: forceResendingToken,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // ANDROID ONLY — SMS auto-retrieved by the device.
          try {
            await _auth.signInWithCredential(credential);
            debugPrint('verificationCompleted → signed in');
          } catch (e) {
            debugPrint('verificationCompleted sign-in: $e');
          }
          if (!completer.isCompleted) {
            verificationId ??= 'auto-verified';
            completer.complete(const FirebaseSmsStartResult(sent: true));
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          // Official: handle invalid number / quota / other errors here.
          debugPrint('verificationFailed: ${e.code} ${e.message}');
          lastError = _userMessage(e);
          if (!completer.isCompleted) {
            completer.complete(
              FirebaseSmsStartResult(sent: false, error: lastError),
            );
          }
        },
        codeSent: (String id, int? token) {
          // Official: store verificationId; prompt user for SMS code.
          verificationId = id;
          resendToken = token;
          lastError = null;
          debugPrint('codeSent → verificationId stored');
          if (!completer.isCompleted) {
            completer.complete(const FirebaseSmsStartResult(sent: true));
          }
        },
        codeAutoRetrievalTimeout: (String id) {
          // Official: auto SMS resolution timed out; keep id for manual entry.
          verificationId ??= id;
          debugPrint('codeAutoRetrievalTimeout');
        },
      );

      // Wait until one of the official callbacks finishes the request.
      return await completer.future.timeout(
        const Duration(seconds: 90),
        onTimeout: () {
          if (smsWasSent) {
            return const FirebaseSmsStartResult(sent: true);
          }
          lastError = 'Could not send the code. Please tap Resend and try again.';
          return FirebaseSmsStartResult(sent: false, error: lastError);
        },
      );
    } on FirebaseAuthException catch (e) {
      lastError = _userMessage(e);
      return FirebaseSmsStartResult(sent: false, error: lastError);
    } catch (e) {
      debugPrint('verifyPhoneNumber error: $e');
      lastError = 'Could not send the code. Please tap Resend and try again.';
      return FirebaseSmsStartResult(sent: false, error: lastError);
    }
  }

  /// Official: create credential from verificationId + SMS code, then sign in.
  static Future<bool> confirmSmsCode(String smsCode) async {
    if (!isAvailable) return false;

    // Auto-verified path already signed in via verificationCompleted.
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
      debugPrint('signInWithCredential OK');
      return true;
    } on FirebaseAuthException catch (e) {
      lastError = _userMessage(e);
      debugPrint('confirmSmsCode: ${e.code}');
      return false;
    } catch (e) {
      lastError = 'Invalid code. Please check and try again.';
      debugPrint('confirmSmsCode: $e');
      return false;
    }
  }

  static bool _isE164(String phone) =>
      RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(phone);

  static String _userMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-phone-number':
        return 'Please enter a valid mobile number.';
      case 'too-many-requests':
      case 'quota-exceeded':
        return 'Too many attempts. Please wait a moment and try again.';
      case 'session-expired':
      case 'invalid-verification-code':
      case 'invalid-verification-id':
        return 'Invalid or expired code. Please tap Resend.';
      default:
        return 'Could not send the code. Please tap Resend and try again.';
    }
  }
}
