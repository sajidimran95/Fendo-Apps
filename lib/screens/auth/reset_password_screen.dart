import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/network/api_exception.dart';
import '../../services/auth_controller.dart';
import '../../theme/app_colors.dart';
import '../../utils/api_feedback.dart';
import '../../widgets/auth/auth_background.dart';
import '../../widgets/auth/auth_widgets.dart';
import 'login_screen.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({
    super.key,
    required this.email,
    required this.otp,
  });

  final String email;
  final String otp;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;

  @override
  void dispose() {
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _onSubmit() async {
    final password = _passwordCtrl.text;
    final confirm = _confirmCtrl.text;

    if (password.isEmpty || confirm.isEmpty) {
      showApiError(context, ApiException(message: 'Enter and confirm password'));
      return;
    }
    if (password != confirm) {
      showApiError(context, ApiException(message: 'Passwords do not match'));
      return;
    }

    setState(() => _loading = true);
    try {
      final msg = await AuthController.instance.api.resetPassword(
        email: widget.email,
        otp: widget.otp,
        password: password,
        passwordConfirmation: confirm,
      );
      if (!mounted) return;
      showApiMessage(context, msg ?? 'Password updated. Sign in.');
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
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
                const FendoMark(size: 44),
                const SizedBox(height: 24),
                Text(
                  'Set new\npassword',
                  style: GoogleFonts.sora(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    color: AppColors.forest,
                    letterSpacing: -1,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Choose a new password for ${widget.email}.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 28),
                AuthTextField(
                  controller: _passwordCtrl,
                  label: 'New password',
                  hint: 'New password',
                  obscureText: _obscure,
                  prefixIcon: Icons.lock_outline_rounded,
                  suffix: IconButton(
                    onPressed: () => setState(() => _obscure = !_obscure),
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                AuthTextField(
                  controller: _confirmCtrl,
                  label: 'Confirm password',
                  hint: 'Confirm password',
                  obscureText: true,
                  prefixIcon: Icons.lock_outline_rounded,
                ),
                const SizedBox(height: 28),
                AuthPrimaryButton(
                  label: 'Update password',
                  loading: _loading,
                  onPressed: _loading ? null : _onSubmit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
