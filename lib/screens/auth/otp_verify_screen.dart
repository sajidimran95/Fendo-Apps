import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/firebase/firebase_phone_otp.dart';
import '../../core/network/api_exception.dart';
import '../../navigation/app_nav.dart';
import '../../services/auth_controller.dart';
import '../../theme/app_colors.dart';
import '../../utils/api_feedback.dart';
import '../../widgets/auth/auth_background.dart';
import '../../widgets/auth/auth_widgets.dart';
import 'reset_password_screen.dart';

enum OtpPurpose { register, resetPassword }

class OtpVerifyScreen extends StatefulWidget {
  const OtpVerifyScreen({
    super.key,
    required this.phone,
    required this.purpose,
  });

  final String phone;
  final OtpPurpose purpose;

  @override
  State<OtpVerifyScreen> createState() => _OtpVerifyScreenState();
}

class _OtpVerifyScreenState extends State<OtpVerifyScreen>
    with SingleTickerProviderStateMixin {
  final List<TextEditingController> _digits =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _nodes = List.generate(6, (_) => FocusNode());
  bool _loading = false;
  bool _smsSending = false;
  String? _smsHint;
  /// Isolated from setState so OTP fields (and keyboard) are not rebuilt.
  final ValueNotifier<int> _resendSeconds = ValueNotifier<int>(0);

  late final AnimationController _enter;
  Timer? _resendTimer;

  static const _resendCooldownSec = 60;

  @override
  void initState() {
    super.initState();
    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
    // Always start 60 → 59 → 58… so Resend stays locked until cooldown ends.
    _startResendTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _nodes[0].requestFocus();
      _ensureOtpAndSendSms();
    });
  }

  /// Makes sure we have an API OTP, then sends Firebase SMS.
  Future<void> _ensureOtpAndSendSms({bool isResend = false}) async {
    setState(() {
      _smsSending = true;
      _smsHint = 'Sending code…';
    });

    try {
      if (FirebasePhoneOtp.pendingApiOtp == null ||
          FirebasePhoneOtp.pendingApiOtp!.isEmpty) {
        if (widget.purpose == OtpPurpose.resetPassword) {
          await AuthController.instance.forgotPassword(
            phone: widget.phone,
            awaitSms: false,
          );
        } else {
          await AuthController.instance.preparePhoneOtp(widget.phone);
        }
      }

      final apiOtp = FirebasePhoneOtp.pendingApiOtp;
      if (apiOtp == null || apiOtp.isEmpty) {
        // ignore: avoid_print
        print('[FendoOTP] UI: API did not return otp field');
        if (!mounted) return;
        setState(() {
          _smsSending = false;
          _smsHint =
              'Server did not return OTP. Check API register/resend response.';
        });
        showApiError(
          context,
          ApiException(
            message:
                'Server did not return OTP. Check API register/resend response.',
          ),
        );
        return;
      }

      if (!isResend &&
          FirebasePhoneOtp.smsWasSent &&
          FirebasePhoneOtp.pendingPhone == widget.phone) {
        if (!mounted) return;
        setState(() {
          _smsSending = false;
          _smsHint = 'Code sent. Please check your messages.';
        });
        return;
      }

      // Never signOut here — that breaks Firebase reCAPTCHA ("missing initial state").
      FirebasePhoneOtp.prepareFreshRequest(keepResendToken: isResend);

      final result = await FirebasePhoneOtp.startSms(
        phone: widget.phone,
        apiOtp: apiOtp,
        isResend: isResend,
      );
      if (!mounted) return;

      // ignore: avoid_print
      print(
        '[FendoOTP] UI result sent=${result.sent} '
        'code=${result.errorCode} error=${result.error}',
      );

      setState(() {
        _smsSending = false;
        if (result.sent) {
          _smsHint = 'Code sent. Please check your messages.';
        } else if (isPhoneTakenMessage(result.error ?? '')) {
          _smsHint = 'This number is already registered. Please log in.';
        } else {
          final msg = (result.error ?? '').trim().isNotEmpty
              ? result.error!.trim()
              : 'Could not send the code. Please wait and tap Resend.';
          final code = result.errorCode;
          _smsHint = (code != null &&
                  code.isNotEmpty &&
                  !msg.toLowerCase().contains(code.toLowerCase()))
              ? '$msg [$code]'
              : msg;
        }
      });
      if (isPhoneTakenMessage(result.error ?? '')) {
        showApiError(
          context,
          ApiException(
            message: 'This number is already registered. Please log in.',
          ),
        );
      } else if (!result.sent) {
        showApiError(
          context,
          ApiException(message: _smsHint ?? 'Could not send the code.'),
        );
      }
    } on ApiException catch (e) {
      // ignore: avoid_print
      print('[FendoOTP] UI ApiException: ${e.displayMessage}');
      if (!mounted) return;
      final hint = isPhoneTakenMessage(e)
          ? 'This number is already registered. Please log in.'
          : sanitizeUserMessage(
              e.displayMessage,
              fallback: 'Could not send the code. Please wait and tap Resend.',
            );
      setState(() {
        _smsSending = false;
        _smsHint = hint;
      });
      showApiError(context, e);
    } catch (e, st) {
      // ignore: avoid_print
      print('[FendoOTP] UI unexpected: $e\n$st');
      if (!mounted) return;
      setState(() {
        _smsSending = false;
        _smsHint = isPhoneTakenMessage(e)
            ? 'This number is already registered. Please log in.'
            : 'Could not send the code. Please wait and tap Resend.';
      });
      showApiError(
        context,
        ApiException(message: _smsHint ?? 'Could not send the code.'),
      );
    }
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    _resendSeconds.value = _resendCooldownSec;
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final next = _resendSeconds.value - 1;
      if (next <= 0) {
        _resendSeconds.value = 0;
        timer.cancel();
        return;
      }
      _resendSeconds.value = next;
    });
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _resendSeconds.dispose();
    _enter.dispose();
    for (final c in _digits) {
      c.dispose();
    }
    for (final n in _nodes) {
      n.dispose();
    }
    super.dispose();
  }

  void _onDigitChanged(int i, String v) {
    if (v.length > 1) {
      // Paste: distribute digits across boxes without losing keyboard.
      final chars = v.replaceAll(RegExp(r'\D'), '');
      for (var j = 0; j < 6 && j < chars.length; j++) {
        _digits[j].text = chars[j];
      }
      final focusAt = chars.length.clamp(0, 5);
      _nodes[focusAt].requestFocus();
      return;
    }
    if (v.isNotEmpty && i < 5) {
      _nodes[i + 1].requestFocus();
    } else if (v.isEmpty && i > 0) {
      _nodes[i - 1].requestFocus();
    }
  }

  String get _otpCode => _digits.map((c) => c.text).join();

  /// User must type the SMS / Firebase test code. Never auto-filled.
  /// After Firebase confirms SMS, API is verified with stored server OTP.
  Future<String> _resolveApiOtp(String entered) async {
    if (FirebasePhoneOtp.smsWasSent) {
      final ok = await FirebasePhoneOtp.confirmSmsCode(entered);
      if (!ok) {
        throw ApiException(
          message: 'Invalid code. Please check and try again.',
        );
      }
      final serverOtp = FirebasePhoneOtp.pendingApiOtp;
      if (serverOtp == null || serverOtp.isEmpty) {
        throw ApiException(
          message: 'Code expired. Please tap Resend.',
        );
      }
      return serverOtp;
    }

    // No Firebase SMS session — verify API with what the user typed.
    return entered;
  }

  Future<void> _onVerify() async {
    final entered = _otpCode;
    if (entered.length < 6) {
      showApiError(context, ApiException(message: 'Enter the 6-digit code'));
      return;
    }

    if (widget.purpose == OtpPurpose.resetPassword) {
      setState(() => _loading = true);
      try {
        final apiOtp = await _resolveApiOtp(entered);
        if (!mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ResetPasswordScreen(
              phone: widget.phone,
              otp: apiOtp,
            ),
          ),
        );
      } on ApiException catch (e) {
        if (!mounted) return;
        showApiError(context, e);
      } catch (e) {
        if (!mounted) return;
        showApiError(context, e);
      } finally {
        if (mounted) setState(() => _loading = false);
      }
      return;
    }

    setState(() => _loading = true);
    try {
      final apiOtp = await _resolveApiOtp(entered);
      await AuthController.instance.verifyRegisterOtp(
        phone: widget.phone,
        otp: apiOtp,
      );
      FirebasePhoneOtp.clear();
      if (!mounted) return;
      goToHome(context);
    } on ApiException catch (e) {
      if (!mounted) return;
      showApiError(context, e);
    } catch (e) {
      if (!mounted) return;
      showApiError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _onResend() async {
    if (_resendSeconds.value > 0 || _smsSending) return;

    // Lock Resend immediately with a fresh 60 → 59 → 58… countdown.
    _startResendTimer();
    setState(() {
      _smsSending = true;
      _smsHint = 'Sending code…';
    });

    try {
      // Fresh API OTP; keep Firebase force-resend token when possible.
      FirebasePhoneOtp.pendingApiOtp = null;
      FirebasePhoneOtp.pendingPhone = widget.phone;

      if (widget.purpose == OtpPurpose.resetPassword) {
        await AuthController.instance.forgotPassword(
          phone: widget.phone,
          awaitSms: false,
        );
      } else {
        try {
          await AuthController.instance.resendOtp(
            phone: widget.phone,
            purpose: 'register',
            awaitSms: false,
          );
        } on ApiException catch (e) {
          if (isPhoneTakenMessage(e) ||
              AuthController.instance.isAlreadyVerifiedAccount(e)) {
            if (!mounted) return;
            setState(() {
              _smsSending = false;
              _smsHint =
                  'This number is already registered. Please log in.';
            });
            showApiError(
              context,
              ApiException(
                message:
                    'This number is already registered. Please log in.',
              ),
            );
            return;
          }
          final m = e.displayMessage.toLowerCase();
          final fallback = m.contains('no account') ||
              m.contains('not found') ||
              m.contains('already verified') ||
              m.contains('no pending');
          if (!fallback) rethrow;
          await AuthController.instance.forgotPassword(
            phone: widget.phone,
            awaitSms: false,
          );
        }
      }

      if (!mounted) return;
      for (final c in _digits) {
        c.clear();
      }
      _nodes[0].requestFocus();

      await _ensureOtpAndSendSms(isResend: true);
    } on ApiException catch (e) {
      if (!mounted) return;
      final hint = isPhoneTakenMessage(e)
          ? 'This number is already registered. Please log in.'
          : sanitizeUserMessage(
              e.displayMessage,
              fallback: 'Could not send the code. Please try again.',
            );
      setState(() {
        _smsSending = false;
        _smsHint = hint;
      });
      showApiError(context, e);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _smsSending = false;
        _smsHint = 'Could not send the code. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      body: AuthBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(24, 8, 24, 24 + bottom),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  padding: EdgeInsets.zero,
                  alignment: Alignment.centerLeft,
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back_rounded),
                  color: AppColors.forest,
                ),
                const SizedBox(height: 16),
                FadeUp(
                  animation: _enter,
                  begin: 0,
                  end: 0.45,
                  child: const FendoMark(size: 44),
                ),
                const SizedBox(height: 24),
                FadeUp(
                  animation: _enter,
                  begin: 0.1,
                  end: 0.55,
                  child: Text(
                    'Check your\nphone',
                    style: GoogleFonts.sora(
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      color: AppColors.forest,
                      letterSpacing: -1,
                      height: 1.1,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                FadeUp(
                  animation: _enter,
                  begin: 0.18,
                  end: 0.65,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Enter the 6-digit code sent to your phone.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      if (_smsHint != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _smsHint!,
                          style: GoogleFonts.manrope(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _smsSending
                                ? AppColors.mintDim
                                : AppColors.textMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 36),
                FadeUp(
                  animation: _enter,
                  begin: 0.28,
                  end: 0.8,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(6, (i) {
                      return SizedBox(
                        width: 48,
                        child: TextField(
                          key: ValueKey('otp-digit-$i'),
                          controller: _digits[i],
                          focusNode: _nodes[i],
                          textAlign: TextAlign.center,
                          keyboardType: TextInputType.number,
                          textInputAction: i < 5
                              ? TextInputAction.next
                              : TextInputAction.done,
                          maxLength: 1,
                          style: GoogleFonts.sora(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: AppColors.forest,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(1),
                          ],
                          decoration: const InputDecoration(
                            counterText: '',
                            contentPadding: EdgeInsets.symmetric(vertical: 14),
                          ),
                          onChanged: (v) => _onDigitChanged(i, v),
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 32),
                FadeUp(
                  animation: _enter,
                  begin: 0.4,
                  end: 0.92,
                  child: AuthPrimaryButton(
                    label: 'Verify code',
                    loading: _loading,
                    onPressed: _loading ? null : _onVerify,
                  ),
                ),
                const SizedBox(height: 20),
                FadeUp(
                  animation: _enter,
                  begin: 0.5,
                  end: 1,
                  child: Center(
                    child: ListenableBuilder(
                      listenable: _resendSeconds,
                      builder: (context, _) {
                        final seconds = _resendSeconds.value;
                        if (_smsSending && seconds <= 0) {
                          return Text(
                            'Sending…',
                            style: GoogleFonts.manrope(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          );
                        }
                        if (seconds > 0) {
                          return Text(
                            _smsSending
                                ? 'Sending… Resend in ${seconds}s'
                                : 'Resend code in ${seconds}s',
                            style: GoogleFonts.manrope(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          );
                        }
                        return TextButton(
                          onPressed: _onResend,
                          child: Text(
                            'Resend code',
                            style: GoogleFonts.manrope(
                              fontWeight: FontWeight.w700,
                              color: AppColors.forest,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
