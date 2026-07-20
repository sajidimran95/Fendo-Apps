import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../navigation/app_nav.dart';
import '../../theme/app_colors.dart';
import '../../widgets/auth/auth_background.dart';
import '../../widgets/auth/auth_widgets.dart';
import 'forgot_password_screen.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailCtrl = TextEditingController();
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
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _onLogin() async {
    // Static: any id / password goes to home
    setState(() => _loading = true);
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    setState(() => _loading = false);
    goToHome(context);
  }

  void _socialLogin() async {
    setState(() => _loading = true);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    setState(() => _loading = false);
    goToHome(context);
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
                    'Static preview — any email & password works.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(height: 36),
                FadeUp(
                  animation: _enter,
                  begin: 0.28,
                  end: 0.7,
                  child: AuthTextField(
                    controller: _emailCtrl,
                    label: 'Email',
                    hint: 'any@email.com',
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    prefixIcon: Icons.mail_outline_rounded,
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
                    hint: 'anything',
                    obscureText: _obscure,
                    textInputAction: TextInputAction.done,
                    prefixIcon: Icons.lock_outline_rounded,
                    onFieldSubmitted: (_) => _onLogin(),
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
                      child: const Text('Forgot password?'),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                FadeUp(
                  animation: _enter,
                  begin: 0.45,
                  end: 0.88,
                  child: AuthPrimaryButton(
                    label: 'Sign in',
                    loading: _loading,
                    onPressed: _loading ? null : _onLogin,
                  ),
                ),
                const SizedBox(height: 28),
                FadeUp(
                  animation: _enter,
                  begin: 0.52,
                  end: 0.92,
                  child: const AuthDivider(),
                ),
                const SizedBox(height: 18),
                FadeUp(
                  animation: _enter,
                  begin: 0.58,
                  end: 0.96,
                  child: AuthSocialRow(
                    onGoogle: _socialLogin,
                    onApple: _socialLogin,
                  ),
                ),
                const SizedBox(height: 32),
                FadeUp(
                  animation: _enter,
                  begin: 0.65,
                  end: 1,
                  child: Center(
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          'New to Fendo? ',
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
                            'Create account',
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
