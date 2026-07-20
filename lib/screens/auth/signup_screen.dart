import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_colors.dart';
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
    // Static: any fields go to OTP then home
    setState(() => _loading = true);
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    setState(() => _loading = false);

    final email = _emailCtrl.text.trim().isEmpty
        ? 'new@fendo.app'
        : _emailCtrl.text.trim();

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OtpVerifyScreen(
          email: email,
          purpose: OtpPurpose.register,
        ),
      ),
    );
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
                          'Static preview — fill anything and continue.',
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
                          hint: 'any@email.com',
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
                          hint: 'anything',
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
                          hint: 'anything',
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
