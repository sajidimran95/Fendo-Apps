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
  final bool pending;
}

/// Starts FlutterFire Phone Auth SMS after the API returns its OTP.
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

    FirebasePhoneOtp.pendingPhone = phone;
    FirebasePhoneOtp.pendingApiOtp = otp;
    FirebasePhoneOtp.prepareFreshRequest(keepResendToken: false);

    if (!FirebaseBootstrap.ready) {
      return const OtpSmsResult(
        sent: false,
        error: 'Could not send the code. Please try again.',
      );
    }

    final result = await FirebasePhoneOtp.startSms(
      phone: phone,
      apiOtp: otp,
      isResend: false,
    );
    if (result.sent) {
      return const OtpSmsResult(sent: true, viaFirebase: true);
    }

    debugPrint('FlutterFire SMS failed: ${result.error}');

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
    );
  }
}
