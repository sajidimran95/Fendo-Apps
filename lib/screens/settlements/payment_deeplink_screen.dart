import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/network/api_exception.dart';
import '../../services/auth_controller.dart';
import '../../services/settlements_controller.dart';
import '../../theme/app_colors.dart';
import '../../utils/api_feedback.dart';
import '../../widgets/auth/auth_widgets.dart';
import '../../widgets/common/app_widgets.dart';

class PaymentDeeplinkScreen extends StatefulWidget {
  const PaymentDeeplinkScreen({super.key});

  @override
  State<PaymentDeeplinkScreen> createState() => _PaymentDeeplinkScreenState();
}

class _PaymentDeeplinkScreenState extends State<PaymentDeeplinkScreen> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  bool _loading = false;
  String? _url;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    final amount = double.tryParse(_amount.text.trim());
    if (amount == null || amount <= 0) {
      showApiError(context, ApiException(message: 'Enter a valid amount'));
      return;
    }
    final payeeId = AuthController.instance.user?.id ?? 1;

    setState(() => _loading = true);
    try {
      final link = await SettlementsController.instance.getDeepLink(
        payeeId: payeeId,
        amount: amount,
        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      );
      if (!mounted) return;
      setState(() => _url = link.url.isEmpty ? null : link.url);
      if (_url == null) {
        showApiError(context, ApiException(message: 'No link returned'));
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      showApiError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _copy() async {
    final url = _url;
    if (url == null) return;
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    showApiMessage(context, 'Link copied');
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
              title: 'Payment link',
              subtitle: 'Generate a deep link',
              onBack: () => Navigator.pop(context),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AuthTextField(
                    controller: _amount,
                    label: 'Amount *',
                    hint: '45.00',
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                  const SizedBox(height: 14),
                  AuthTextField(
                    controller: _note,
                    label: 'Note',
                    hint: 'optional',
                  ),
                  const SizedBox(height: 24),
                  AuthPrimaryButton(
                    label: 'Generate link',
                    loading: _loading,
                    onPressed: _loading ? null : _generate,
                  ),
                  if (_url != null) ...[
                    const SizedBox(height: 20),
                    SoftTile(
                      margin: EdgeInsets.zero,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Deep link',
                            style: GoogleFonts.manrope(
                              fontWeight: FontWeight.w700,
                              color: AppColors.forestSoft,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 8),
                          SelectableText(
                            _url!,
                            style: GoogleFonts.manrope(
                              color: AppColors.mint,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: _copy,
                            icon: const Icon(Icons.copy_rounded, size: 18),
                            label: const Text('Copy'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
