import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/network/api_exception.dart';
import '../../services/auth_controller.dart';
import '../../theme/app_colors.dart';
import '../../utils/api_feedback.dart';
import '../../widgets/auth/auth_background.dart';
import '../../widgets/auth/auth_widgets.dart';
import 'otp_verify_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen>
    with SingleTickerProviderStateMixin {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscure = true;
  bool _obscureConfirm = true;
  bool _loading = false;

  late final AnimationController _enter;

  @override
  void initState() {
    super.initState();
    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..forward();
  }

  @override
  void dispose() {
    _enter.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _onSignup() async {
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final password = _passwordCtrl.text;
    final confirm = _confirmCtrl.text;

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      showApiError(
        context,
        ApiException(message: 'Name, email and password are required'),
      );
      return;
    }
    if (password != confirm) {
      showApiError(
        context,
        ApiException(message: 'Passwords do not match'),
      );
      return;
    }
    final passwordError = _passwordRuleError(password);
    if (passwordError != null) {
      showApiError(context, ApiException(message: passwordError));
      return;
    }

    setState(() => _loading = true);
    try {
      debugPrint(
        'REGISTER → ${AuthController.instance.client.dio.options.baseUrl}',
      );
      final result = await AuthController.instance.register(
        name: name,
        email: email,
        password: password,
        passwordConfirmation: confirm,
        phone: phone.isEmpty ? null : phone,
      );
      if (!mounted) return;
      final apiMsg = result['message']?.toString();
      if (apiMsg != null && apiMsg.isNotEmpty) {
        showApiMessage(context, apiMsg);
      }
      _goToOtp(email);
    } on ApiException catch (e) {
      debugPrint('REGISTER ApiException: ${e.statusCode} ${e.displayMessage}');
      if (!mounted) return;
      final msg = e.displayMessage.toLowerCase();
      final emailTaken = msg.contains('already been taken') ||
          msg.contains('already taken') ||
          (e.errors?['email']?.any(
                (m) => m.toLowerCase().contains('taken'),
              ) ??
              false);
      if (emailTaken) {
        showApiMessage(
          context,
          'This email is already registered. Enter the OTP sent to your email.',
        );
        _goToOtp(email);
        return;
      }
      showApiError(context, e);
    } catch (e, st) {
      debugPrint('REGISTER unexpected: $e\n$st');
      if (!mounted) return;
      showApiError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _goToOtp(String email) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OtpVerifyScreen(
          email: email,
          purpose: OtpPurpose.register,
        ),
      ),
    );
  }

  /// Live API: min 8, upper + lower + number.
  String? _passwordRuleError(String password) {
    if (password.length < 8) {
      return 'Password must be at least 8 characters';
    }
    if (!RegExp(r'[A-Z]').hasMatch(password)) {
      return 'Password needs at least one uppercase letter';
    }
    if (!RegExp(r'[a-z]').hasMatch(password)) {
      return 'Password needs at least one lowercase letter';
    }
    if (!RegExp(r'[0-9]').hasMatch(password)) {
      return 'Password needs at least one number';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      body: AuthBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 20, 0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_rounded),
                      color: AppColors.forest,
                    ),
                    const Spacer(),
                    const FendoMark(size: 36),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(24, 8, 24, 24 + bottom),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FadeUp(
                        animation: _enter,
                        begin: 0,
                        end: 0.4,
                        child: Text(
                          'Create your\nFendo account',
                          style: GoogleFonts.sora(
                            fontSize: 34,
                            fontWeight: FontWeight.w800,
                            color: AppColors.forest,
                            letterSpacing: -1.1,
                            height: 1.1,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      FadeUp(
                        animation: _enter,
                        begin: 0.1,
                        end: 0.5,
                        child: Text(
                          'Password needs 8+ chars, upper, lower, and a number.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      const SizedBox(height: 28),
                      FadeUp(
                        animation: _enter,
                        begin: 0.18,
                        end: 0.6,
                        child: AuthTextField(
                          controller: _nameCtrl,
                          label: 'Full name',
                          hint: 'John Doe',
                          textInputAction: TextInputAction.next,
                          prefixIcon: Icons.person_outline_rounded,
                        ),
                      ),
                      const SizedBox(height: 14),
                      FadeUp(
                        animation: _enter,
                        begin: 0.24,
                        end: 0.68,
                        child: AuthTextField(
                          controller: _emailCtrl,
                          label: 'Email',
                          hint: 'you@email.com',
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          prefixIcon: Icons.mail_outline_rounded,
                        ),
                      ),
                      const SizedBox(height: 14),
                      FadeUp(
                        animation: _enter,
                        begin: 0.3,
                        end: 0.74,
                        child: AuthTextField(
                          controller: _phoneCtrl,
                          label: 'Phone (optional)',
                          hint: '+1 234 567 890',
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.next,
                          prefixIcon: Icons.phone_outlined,
                        ),
                      ),
                      const SizedBox(height: 14),
                      FadeUp(
                        animation: _enter,
                        begin: 0.36,
                        end: 0.8,
                        child: AuthTextField(
                          controller: _passwordCtrl,
                          label: 'Password',
                          hint: 'e.g. Password1',
                          obscureText: _obscure,
                          textInputAction: TextInputAction.next,
                          prefixIcon: Icons.lock_outline_rounded,
                          suffix: IconButton(
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
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
                      const SizedBox(height: 14),
                      FadeUp(
                        animation: _enter,
                        begin: 0.42,
                        end: 0.88,
                        child: AuthTextField(
                          controller: _confirmCtrl,
                          label: 'Confirm password',
                          hint: 'Repeat password',
                          obscureText: _obscureConfirm,
                          textInputAction: TextInputAction.done,
                          prefixIcon: Icons.lock_outline_rounded,
                          onFieldSubmitted: (_) => _onSignup(),
                          suffix: IconButton(
                            onPressed: () => setState(
                              () => _obscureConfirm = !_obscureConfirm,
                            ),
                            icon: Icon(
                              _obscureConfirm
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: AppColors.textMuted,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      FadeUp(
                        animation: _enter,
                        begin: 0.5,
                        end: 0.95,
                        child: AuthPrimaryButton(
                          label: 'Create account',
                          loading: _loading,
                          onPressed: _loading ? null : _onSignup,
                        ),
                      ),
                      const SizedBox(height: 24),
                      FadeUp(
                        animation: _enter,
                        begin: 0.6,
                        end: 1,
                        child: Center(
                          child: Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                'Already have an account? ',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              GestureDetector(
                                onTap: () => Navigator.of(context).pop(),
                                child: Text(
                                  'Sign in',
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
            ],
          ),
        ),
      ),
    );
  }
}
