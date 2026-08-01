import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/network/api_exception.dart';
import '../../services/auth_controller.dart';
import '../../theme/app_colors.dart';
import '../../utils/api_feedback.dart';
import '../../utils/phone_number.dart';
import '../../widgets/auth/auth_background.dart';
import '../../widgets/auth/auth_widgets.dart';
import '../../widgets/auth/phone_country_field.dart';
import 'otp_verify_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen>
    with SingleTickerProviderStateMixin {
  final _phoneCtrl = TextEditingController();
  final _phoneKey = GlobalKey<PhoneCountryFieldState>();
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
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _onSubmit() async {
    final phone = _phoneKey.currentState?.normalizedPhone() ??
        PhoneNumber.normalize(_phoneCtrl.text);
    if (phone.isEmpty) {
      showApiError(context, ApiException(message: 'Enter your mobile number'));
      return;
    }
    if (!PhoneNumber.looksValid(phone)) {
      showApiError(
        context,
        ApiException(message: 'Enter a valid mobile number'),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      await AuthController.instance.forgotPassword(phone: phone);
      if (!mounted) return;
      showApiMessage(context, 'Enter the code sent to your phone.');
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => OtpVerifyScreen(
            phone: phone,
            purpose: OtpPurpose.resetPassword,
          ),
        ),
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
                    'We’ll text a one-time code to reset your password.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(height: 32),
                FadeUp(
                  animation: _enter,
                  begin: 0.3,
                  end: 0.8,
                  child: PhoneCountryField(
                    key: _phoneKey,
                    controller: _phoneCtrl,
                    textInputAction: TextInputAction.done,
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
