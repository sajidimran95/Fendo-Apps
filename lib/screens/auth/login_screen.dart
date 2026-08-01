import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/network/api_exception.dart';
import '../../navigation/app_nav.dart';
import '../../services/auth_controller.dart';
import '../../theme/app_colors.dart';
import '../../utils/api_feedback.dart';
import '../../utils/phone_number.dart';
import '../../widgets/auth/auth_background.dart';
import '../../widgets/auth/auth_widgets.dart';
import '../../widgets/auth/phone_country_field.dart';
import 'forgot_password_screen.dart';
import 'otp_verify_screen.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _phoneCtrl = TextEditingController();
  final _phoneKey = GlobalKey<PhoneCountryFieldState>();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;

  late final AnimationController _enter;

  @override
  void initState() {
    super.initState();
    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..forward();
  }

  @override
  void dispose() {
    _enter.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _onLogin() async {
    final phone = _phoneKey.currentState?.normalizedPhone() ??
        PhoneNumber.normalize(_phoneCtrl.text);
    final password = _passwordCtrl.text;

    if (phone.isEmpty || password.isEmpty) {
      showApiError(
        context,
        ApiException(message: 'Enter phone number and password'),
      );
      return;
    }
    if (!PhoneNumber.looksValid(phone)) {
      showApiError(
        context,
        ApiException(message: 'Enter a valid phone number'),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      await AuthController.instance.login(phone: phone, password: password);
      if (!mounted) return;
      goToHome(context);
    } on ApiException catch (e) {
      if (!mounted) return;
      final msg = e.displayMessage.toLowerCase();
      final needsVerify = e.isForbidden ||
          msg.contains('verify your phone') ||
          msg.contains('phone not verified') ||
          msg.contains('please verify');
      if (needsVerify) {
        showApiMessage(
          context,
          'Enter the code sent to your phone',
        );
        try {
          await AuthController.instance.preparePhoneOtp(phone);
        } catch (_) {}
        if (!mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => OtpVerifyScreen(
              phone: phone,
              purpose: OtpPurpose.register,
            ),
          ),
        );
        return;
      }
      showApiError(context, e);
    } catch (e) {
      if (!mounted) return;
      showApiError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _socialComingSoon() {
    showApiMessage(context, 'Social sign-in coming soon');
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      body: AuthBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(24, 20, 24, 20 + bottom),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FadeUp(
                  animation: _enter,
                  begin: 0,
                  end: 0.35,
                  child: const FendoMark(size: 52),
                ),
                const SizedBox(height: 28),
                FadeUp(
                  animation: _enter,
                  begin: 0.08,
                  end: 0.45,
                  child: Text(
                    'Fendo',
                    style: GoogleFonts.sora(
                      fontSize: 44,
                      fontWeight: FontWeight.w800,
                      color: AppColors.forest,
                      letterSpacing: -1.6,
                      height: 1,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                FadeUp(
                  animation: _enter,
                  begin: 0.14,
                  end: 0.5,
                  child: Text(
                    'Split expenses.\nSettle in seconds.',
                    style: GoogleFonts.sora(
                      fontSize: 26,
                      fontWeight: FontWeight.w600,
                      color: AppColors.forestSoft,
                      letterSpacing: -0.6,
                      height: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                FadeUp(
                  animation: _enter,
                  begin: 0.18,
                  end: 0.55,
                  child: Text(
                    'Sign in with your mobile number.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(height: 36),
                FadeUp(
                  animation: _enter,
                  begin: 0.28,
                  end: 0.7,
                  child: PhoneCountryField(
                    key: _phoneKey,
                    controller: _phoneCtrl,
                    textInputAction: TextInputAction.next,
                  ),
                ),
                const SizedBox(height: 16),
                FadeUp(
                  animation: _enter,
                  begin: 0.34,
                  end: 0.78,
                  child: AuthTextField(
                    controller: _passwordCtrl,
                    label: 'Password',
                    hint: '...........',
                    obscureText: _obscure,
                    textInputAction: TextInputAction.done,
                    prefixIcon: Icons.lock_outline_rounded,
                    onFieldSubmitted: (_) => _onLogin(),
                    autofillHints: const [AutofillHints.password],
                    suffix: IconButton(
                      onPressed: () => setState(() => _obscure = !_obscure),
                      icon: Icon(
                        _obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: AppColors.textMuted,
                        size: 20,
                      ),
                    ),
                  ),
                ),
                FadeUp(
                  animation: _enter,
                  begin: 0.4,
                  end: 0.82,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const ForgotPasswordScreen(),
                          ),
                        );
                      },
                      child: Text(
                        'Forgot password?',
                        style: GoogleFonts.manrope(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.mintDim,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                FadeUp(
                  animation: _enter,
                  begin: 0.46,
                  end: 0.9,
                  child: AuthPrimaryButton(
                    label: 'Sign in',
                    loading: _loading,
                    onPressed: _loading ? null : _onLogin,
                  ),
                ),
                const SizedBox(height: 28),
                FadeUp(
                  animation: _enter,
                  begin: 0.55,
                  end: 0.95,
                  child: Row(
                    children: [
                      const Expanded(child: Divider()),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'or continue with',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      const Expanded(child: Divider()),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                FadeUp(
                  animation: _enter,
                  begin: 0.6,
                  end: 1,
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _socialComingSoon,
                          icon: const Icon(Icons.g_mobiledata_rounded, size: 28),
                          label: const Text('Google'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _socialComingSoon,
                          icon: const Icon(Icons.apple_rounded),
                          label: const Text('Apple'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                FadeUp(
                  animation: _enter,
                  begin: 0.7,
                  end: 1,
                  child: Center(
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          "Don't have an account? ",
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const SignupScreen(),
                              ),
                            );
                          },
                          child: Text(
                            'Sign up',
                            style: GoogleFonts.manrope(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppColors.mint,
                            ),
                          ),
                        ),
                      ],
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
