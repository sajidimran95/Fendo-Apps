import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/firebase/firebase_bootstrap.dart';
import '../core/firebase/firebase_phone_otp.dart';

class OtpSmsResult {
  const OtpSmsResult({
    required this.sent,
    this.error,
    this.viaFirebase = false,
    this.pending = false,
  });

  final bool sent;
  final String? error;
  final bool viaFirebase;
  /// API OTP stored; Firebase SMS will start on the OTP screen.
  final bool pending;
}

/// Delivers OTP to the phone via Firebase Phone Auth.
class OtpSmsService {
  OtpSmsService._();

  static const String smsEndpoint = String.fromEnvironment(
    'OTP_SMS_ENDPOINT',
    defaultValue: '',
  );

  static Future<OtpSmsResult> sendOtpSms({
    required String phone,
    required String otp,
  }) async {
    if (phone.isEmpty || otp.isEmpty) {
      return const OtpSmsResult(sent: false, error: 'Missing phone or OTP');
    }

    // Always keep server OTP for API verify (Firebase SMS uses a different code).
    FirebasePhoneOtp.pendingPhone = phone;
    FirebasePhoneOtp.pendingApiOtp = otp;
    FirebasePhoneOtp.prepareFreshRequest(keepResendToken: false);

    debugPrint('OTP SMS → $phone (api otp stored, starting Firebase)');

    if (FirebaseBootstrap.ready) {
      final result = await FirebasePhoneOtp.startSms(
        phone: phone,
        apiOtp: otp,
        isResend: false,
      );
      if (result.sent) {
        return const OtpSmsResult(sent: true, viaFirebase: true);
      }
      debugPrint('Firebase SMS failed: ${result.error}');

      if (smsEndpoint.isNotEmpty) {
        try {
          final dio = Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 15),
            ),
          );
          await dio.post(smsEndpoint, data: {'phone': phone, 'otp': otp});
          return const OtpSmsResult(sent: true);
        } catch (e) {
          debugPrint('OTP SMS endpoint failed: $e');
        }
      }

      return OtpSmsResult(
        sent: false,
        error: result.error ??
            'Could not send the code. Please tap Resend and try again.',
        viaFirebase: false,
      );
    }

    return const OtpSmsResult(
      sent: false,
      error: 'Could not send the code. Please try again.',
    );
  }
}
