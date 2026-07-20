import 'package:flutter/material.dart';

import '../../core/network/api_exception.dart';
import '../../services/auth_controller.dart';
import '../../theme/app_colors.dart';
import '../../utils/api_feedback.dart';
import '../../widgets/auth/auth_widgets.dart';
import '../../widgets/common/app_widgets.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _current = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _loading = false;

  @override
  void dispose() {
    _current.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_current.text.isEmpty ||
        _password.text.isEmpty ||
        _confirm.text.isEmpty) {
      showApiError(context, ApiException(message: 'Fill all password fields'));
      return;
    }
    if (_password.text != _confirm.text) {
      showApiError(context, ApiException(message: 'Passwords do not match'));
      return;
    }

    setState(() => _loading = true);
    try {
      final msg = await AuthController.instance.userApi.changePassword(
        currentPassword: _current.text,
        password: _password.text,
        passwordConfirmation: _confirm.text,
      );
      if (!mounted) return;
      showApiMessage(context, msg ?? 'Password updated');
      Navigator.pop(context);
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
              title: 'Change password',
              onBack: () => Navigator.pop(context),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  AuthTextField(
                    controller: _current,
                    label: 'Current password',
                    obscureText: _obscureCurrent,
                    prefixIcon: Icons.lock_outline_rounded,
                    suffix: IconButton(
                      onPressed: () =>
                          setState(() => _obscureCurrent = !_obscureCurrent),
                      icon: Icon(
                        _obscureCurrent
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  AuthTextField(
                    controller: _password,
                    label: 'New password',
                    obscureText: _obscureNew,
                    prefixIcon: Icons.lock_outline_rounded,
                    suffix: IconButton(
                      onPressed: () =>
                          setState(() => _obscureNew = !_obscureNew),
                      icon: Icon(
                        _obscureNew
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  AuthTextField(
                    controller: _confirm,
                    label: 'Confirm password',
                    obscureText: true,
                    prefixIcon: Icons.lock_outline_rounded,
                  ),
                  const SizedBox(height: 28),
                  AuthPrimaryButton(
                    label: 'Update password',
                    loading: _loading,
                    onPressed: _loading ? null : _submit,
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
