import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

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
    required this.email,
    required this.purpose,
  });

  final String email;
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
  int _resendSeconds = 60;

  late final AnimationController _enter;

  @override
  void initState() {
    super.initState();
    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
    _startResendTimer();
  }

  void _startResendTimer() {
    _resendSeconds = 60;
    Future.doWhile(() async {
      await Future<void>.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() => _resendSeconds--);
      return _resendSeconds > 0;
    });
  }

  @override
  void dispose() {
    _enter.dispose();
    for (final c in _digits) {
      c.dispose();
    }
    for (final n in _nodes) {
      n.dispose();
    }
    super.dispose();
  }

  String get _otpCode => _digits.map((c) => c.text).join();

  Future<void> _onVerify() async {
    final otp = _otpCode;
    if (otp.length < 6) {
      showApiError(context, ApiException(message: 'Enter the 6-digit code'));
      return;
    }

    if (widget.purpose == OtpPurpose.resetPassword) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ResetPasswordScreen(
            email: widget.email,
            otp: otp,
          ),
        ),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      await AuthController.instance.verifyRegisterOtp(
        email: widget.email,
        otp: otp,
      );
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
    if (_resendSeconds > 0) return;

    try {
      if (widget.purpose == OtpPurpose.resetPassword) {
        await AuthController.instance.api.forgotPassword(email: widget.email);
      } else {
        await AuthController.instance.resendOtp(
          email: widget.email,
          purpose: 'register',
        );
      }
      if (!mounted) return;
      showApiMessage(context, 'Code resent');
      _startResendTimer();
    } on ApiException catch (e) {
      if (!mounted) return;
      showApiError(context, e);
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
                    'Check your\ninbox',
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
                  child: Text(
                    'Enter the 6-digit code we sent to ${widget.email}.',
                    style: Theme.of(context).textTheme.bodyMedium,
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
                          controller: _digits[i],
                          focusNode: _nodes[i],
                          textAlign: TextAlign.center,
                          keyboardType: TextInputType.number,
                          maxLength: 1,
                          style: GoogleFonts.sora(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: AppColors.forest,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: const InputDecoration(
                            counterText: '',
                            contentPadding: EdgeInsets.symmetric(vertical: 14),
                          ),
                          onChanged: (v) {
                            if (v.isNotEmpty && i < 5) {
                              _nodes[i + 1].requestFocus();
                            } else if (v.isEmpty && i > 0) {
                              _nodes[i - 1].requestFocus();
                            }
                          },
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
                    child: _resendSeconds > 0
                        ? Text(
                            'Resend in ${_resendSeconds}s',
                            style: Theme.of(context).textTheme.bodySmall,
                          )
                        : TextButton(
                            onPressed: _onResend,
                            child: const Text('Resend code'),
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
