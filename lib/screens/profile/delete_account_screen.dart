import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/network/api_exception.dart';
import '../../services/auth_controller.dart';
import '../../theme/app_colors.dart';
import '../../utils/api_feedback.dart';
import '../../widgets/auth/auth_widgets.dart';
import '../../widgets/common/app_widgets.dart';
import '../auth/login_screen.dart';

class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  static const _requiredPhrase = 'DELETE MY ACCOUNT';

  final _confirmation = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _loading = false;

  @override
  void dispose() {
    _confirmation.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    if (_confirmation.text.trim() != _requiredPhrase) {
      showApiError(
        context,
        ApiException(message: 'Type “$_requiredPhrase” to confirm'),
      );
      return;
    }
    if (_password.text.isEmpty) {
      showApiError(context, ApiException(message: 'Enter your password'));
      return;
    }

    setState(() => _loading = true);
    try {
      await AuthController.instance.userApi.deleteAccount(
        confirmation: _confirmation.text.trim(),
        password: _password.text,
      );
      await AuthController.instance.clearSession();
      if (!mounted) return;
      showApiMessage(context, 'Account deleted');
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
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            AppHeader(
              title: 'Delete account',
              onBack: () => Navigator.pop(context),
            ),
            SoftTile(
              child: Text(
                'This permanently deletes your Fendo account and data. '
                'Type $_requiredPhrase and enter your password to continue.',
                style: GoogleFonts.manrope(
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  AuthTextField(
                    controller: _confirmation,
                    label: 'Confirmation',
                    hint: _requiredPhrase,
                  ),
                  const SizedBox(height: 14),
                  AuthTextField(
                    controller: _password,
                    label: 'Password',
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
                  const SizedBox(height: 28),
                  AuthPrimaryButton(
                    label: 'Delete my account',
                    loading: _loading,
                    onPressed: _loading ? null : _delete,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
