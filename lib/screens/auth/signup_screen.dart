import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/firebase/firebase_phone_otp.dart';
import '../../core/network/api_exception.dart';
import '../../services/auth_controller.dart';
import '../../theme/app_colors.dart';
import '../../utils/api_feedback.dart';
import '../../utils/phone_number.dart';
import '../../widgets/auth/auth_background.dart';
import '../../widgets/auth/auth_widgets.dart';
import '../../widgets/auth/phone_country_field.dart';
import 'login_screen.dart';
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
  final _phoneKey = GlobalKey<PhoneCountryFieldState>();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscure = true;
  bool _obscureConfirm = true;
  bool _loading = false;
  bool _showPasswordRules = false;
  String _passwordDraft = '';

  late final AnimationController _enter;

  @override
  void initState() {
    super.initState();
    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..forward();
    _passwordCtrl.addListener(() {
      final value = _passwordCtrl.text;
      setState(() {
        _passwordDraft = value;
        _showPasswordRules = value.isNotEmpty;
      });
    });
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
    final phone = _phoneKey.currentState?.normalizedPhone() ??
        PhoneNumber.normalize(_phoneCtrl.text);
    final password = _passwordCtrl.text;
    final confirm = _confirmCtrl.text;

    if (name.isEmpty || phone.isEmpty || password.isEmpty) {
      showApiError(
        context,
        ApiException(message: 'Name, mobile number and password are required'),
      );
      return;
    }
    if (!PhoneNumber.looksValid(phone)) {
      showApiError(
        context,
        ApiException(message: 'Enter a valid mobile number'),
      );
      return;
    }
    if (email.isNotEmpty && !email.contains('@')) {
      showApiError(
        context,
        ApiException(message: 'Enter a valid email address'),
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
      await AuthController.instance.register(
        name: name,
        phone: phone,
        password: password,
        passwordConfirmation: confirm,
        email: email.isEmpty ? null : email,
      );
      if (!mounted) return;
      showApiMessage(context, 'Enter the code sent to your phone.');
      _goToOtp(phone);
    } on ApiException catch (e) {
      debugPrint('REGISTER ApiException: ${e.statusCode} ${e.displayMessage}');
      if (!mounted) return;
      final msg = e.displayMessage.toLowerCase();
      final phoneErrors =
          e.errors?['phone']?.map((m) => m.toLowerCase()).toList() ??
              const <String>[];
      final phoneTaken = e.statusCode == 409 ||
          phoneErrors.any(
            (m) =>
                m.contains('taken') ||
                m.contains('exists') ||
                m.contains('registered') ||
                m.contains('already'),
          ) ||
          msg.contains('already been taken') ||
          msg.contains('phone has already been taken') ||
          (msg.contains('phone') &&
              (msg.contains('taken') ||
                  msg.contains('already registered') ||
                  msg.contains('already exists')));
      // Do NOT treat every 422 as phone-taken (that broke resend → "no account").

      if (phoneTaken) {
        try {
          FirebasePhoneOtp.prepareFreshRequest(keepResendToken: false);
          final resolution = await AuthController.instance
              .resolvePhoneTakenConflict(phone);
          if (!mounted) return;

          switch (resolution) {
            case PhoneTakenResolution.unverifiedPending:
              showApiMessage(context, 'Enter the code sent to your phone.');
              _goToOtp(phone, purpose: OtpPurpose.register);
              return;
            case PhoneTakenResolution.closedAccount:
              showApiMessage(
                context,
                'This number belongs to a closed account and cannot be '
                'registered again yet. Contact support to free the number.',
              );
              return;
            case PhoneTakenResolution.activeAccount:
              showApiMessage(
                context,
                'This number is already registered. Please log in. '
                'If you deleted this account, contact support to free the number.',
              );
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
              return;
          }
        } on ApiException catch (resendErr) {
          debugPrint('REGISTER otp after taken failed: $resendErr');
          if (!mounted) return;
          if (AuthController.instance.isAccountMissing(resendErr)) {
            showApiMessage(
              context,
              'This number belongs to a closed account and cannot be '
              'registered again yet. Contact support to free the number.',
            );
            return;
          }
          showApiMessage(
            context,
            'This number is already registered. Please log in. '
            'If you deleted this account, contact support to free the number.',
          );
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          );
        }
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

  void _goToOtp(String phone, {OtpPurpose purpose = OtpPurpose.register}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OtpVerifyScreen(
          phone: phone,
          purpose: purpose,
        ),
      ),
    );
  }

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
                          'Verify with a code sent to your mobile.',
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
                        child: PhoneCountryField(
                          key: _phoneKey,
                          controller: _phoneCtrl,
                          textInputAction: TextInputAction.next,
                        ),
                      ),
                      const SizedBox(height: 14),
                      FadeUp(
                        animation: _enter,
                        begin: 0.3,
                        end: 0.74,
                        child: AuthTextField(
                          controller: _emailCtrl,
                          label: 'Email (optional)',
                          hint: 'Enter your email',
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          prefixIcon: Icons.mail_outline_rounded,
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
                          hint: '...........',
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
                      if (_showPasswordRules) ...[
                        const SizedBox(height: 10),
                        _PasswordRulesHint(password: _passwordDraft),
                      ],
                      const SizedBox(height: 14),
                      FadeUp(
                        animation: _enter,
                        begin: 0.42,
                        end: 0.88,
                        child: AuthTextField(
                          controller: _confirmCtrl,
                          label: 'Confirm password',
                          hint: '...........',
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

class _PasswordRulesHint extends StatelessWidget {
  const _PasswordRulesHint({required this.password});

  final String password;

  @override
  Widget build(BuildContext context) {
    bool ok(bool v) => v;
    final rules = <(String, bool)>[
      ('At least 8 characters', ok(password.length >= 8)),
      ('One uppercase letter', ok(RegExp(r'[A-Z]').hasMatch(password))),
      ('One lowercase letter', ok(RegExp(r'[a-z]').hasMatch(password))),
      ('One number', ok(RegExp(r'[0-9]').hasMatch(password))),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: rules
          .map(
            (r) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Icon(
                    r.$2 ? Icons.check_circle_rounded : Icons.circle_outlined,
                    size: 14,
                    color: r.$2 ? AppColors.mint : AppColors.textMuted,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    r.$1,
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      color: r.$2 ? AppColors.forest : AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}
