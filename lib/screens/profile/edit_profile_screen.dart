import 'package:flutter/material.dart';

import '../../core/network/api_exception.dart';
import '../../services/auth_controller.dart';
import '../../theme/app_colors.dart';
import '../../utils/api_feedback.dart';
import '../../widgets/auth/auth_widgets.dart';
import '../../widgets/common/app_widgets.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _timezone;
  late final TextEditingController _currency;
  late final TextEditingController _language;
  late final TextEditingController _venmo;
  late final TextEditingController _paypal;
  late final TextEditingController _cashapp;
  bool _loading = false;
  bool _booting = true;

  @override
  void initState() {
    super.initState();
    final u = AuthController.instance.user;
    _name = TextEditingController(text: u?.name ?? '');
    _phone = TextEditingController(text: u?.phone ?? '');
    _timezone = TextEditingController(text: u?.timezone ?? '');
    _currency = TextEditingController(text: u?.currency ?? 'USD');
    _language = TextEditingController(text: u?.language ?? '');
    _venmo = TextEditingController(text: u?.venmoHandle ?? '');
    _paypal = TextEditingController(text: u?.paypalEmail ?? '');
    _cashapp = TextEditingController(text: u?.cashappTag ?? '');
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      final user = await AuthController.instance.userApi.getProfile();
      AuthController.instance.setUser(user);
      if (!mounted) return;
      _name.text = user.name;
      _phone.text = user.phone ?? '';
      _timezone.text = user.timezone ?? '';
      _currency.text = user.currency;
      _language.text = user.language ?? '';
      _venmo.text = user.venmoHandle ?? '';
      _paypal.text = user.paypalEmail ?? '';
      _cashapp.text = user.cashappTag ?? '';
    } on ApiException catch (e) {
      if (mounted) showApiError(context, e);
    } finally {
      if (mounted) setState(() => _booting = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _timezone.dispose();
    _currency.dispose();
    _language.dispose();
    _venmo.dispose();
    _paypal.dispose();
    _cashapp.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      showApiError(context, ApiException(message: 'Name is required'));
      return;
    }

    setState(() => _loading = true);
    try {
      final user = await AuthController.instance.userApi.updateProfile(
        name: _name.text.trim(),
        phone: _phone.text.trim(),
        timezone: _timezone.text.trim(),
        currency: _currency.text.trim(),
        language: _language.text.trim(),
        venmoHandle: _venmo.text.trim(),
        paypalEmail: _paypal.text.trim(),
        cashappTag: _cashapp.text.trim(),
      );
      AuthController.instance.setUser(user);
      if (!mounted) return;
      showApiMessage(context, 'Profile updated');
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
        child: _booting
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.mint),
              )
            : ListView(
                padding: const EdgeInsets.only(bottom: 32),
                children: [
                  AppHeader(
                    title: 'Edit profile',
                    onBack: () => Navigator.pop(context),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        AuthTextField(controller: _name, label: 'Name'),
                        const SizedBox(height: 14),
                        AuthTextField(
                          controller: _phone,
                          label: 'Phone',
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 14),
                        AuthTextField(
                          controller: _timezone,
                          label: 'Timezone',
                          hint: 'e.g. America/New_York',
                        ),
                        const SizedBox(height: 14),
                        AuthTextField(
                          controller: _currency,
                          label: 'Currency',
                          hint: 'USD',
                        ),
                        const SizedBox(height: 14),
                        AuthTextField(
                          controller: _language,
                          label: 'Language',
                          hint: 'en',
                        ),
                        const SizedBox(height: 14),
                        AuthTextField(
                          controller: _venmo,
                          label: 'Venmo handle',
                        ),
                        const SizedBox(height: 14),
                        AuthTextField(
                          controller: _paypal,
                          label: 'PayPal email',
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 14),
                        AuthTextField(
                          controller: _cashapp,
                          label: 'Cash App tag',
                        ),
                        const SizedBox(height: 28),
                        AuthPrimaryButton(
                          label: 'Save changes',
                          loading: _loading,
                          onPressed: _loading ? null : _save,
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
