import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_colors.dart';
import '../../widgets/auth/auth_background.dart';
import '../../widgets/auth/auth_widgets.dart';
import 'otp_verify_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen>
    with SingleTickerProviderStateMixin {
  final _emailCtrl = TextEditingController();
  bool _loading = false;
  late final AnimationController _enter;

  @override
  void initState() {
    super.initState();
    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
  }

  @override
  void dispose() {
    _enter.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _onSubmit() async {
    setState(() => _loading = true);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    setState(() => _loading = false);

    final email = _emailCtrl.text.trim().isEmpty
        ? 'user@fendo.app'
        : _emailCtrl.text.trim();

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OtpVerifyScreen(
          email: email,
          purpose: OtpPurpose.resetPassword,
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
                const SizedBox(height: 20),
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
                    'Forgot your\npassword?',
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
                  begin: 0.2,
                  end: 0.65,
                  child: Text(
                    'Enter any email to continue (static).',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(height: 32),
                FadeUp(
                  animation: _enter,
                  begin: 0.3,
                  end: 0.8,
                  child: AuthTextField(
                    controller: _emailCtrl,
                    label: 'Email',
                    hint: 'any@email.com',
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    prefixIcon: Icons.mail_outline_rounded,
                    onFieldSubmitted: (_) => _onSubmit(),
                  ),
                ),
                const SizedBox(height: 28),
                FadeUp(
                  animation: _enter,
                  begin: 0.42,
                  end: 0.95,
                  child: AuthPrimaryButton(
                    label: 'Send reset code',
                    loading: _loading,
                    onPressed: _loading ? null : _onSubmit,
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
