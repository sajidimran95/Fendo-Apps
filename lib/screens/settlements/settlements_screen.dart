import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_colors.dart';
import '../../widgets/auth/auth_widgets.dart';
import '../../widgets/common/app_widgets.dart';

class SettlementsScreen extends StatelessWidget {
  const SettlementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: ListView(
          children: [
            AppHeader(
              title: 'Settlements',
              subtitle: 'Settle up & payment requests',
              onBack: () => Navigator.pop(context),
            ),
            SoftTile(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const RecordSettlementScreen(),
                  ),
                );
              },
              child: Row(
                children: [
                  const Icon(Icons.handshake_outlined, color: AppColors.mint),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Record a payment',
                      style: GoogleFonts.manrope(
                        fontWeight: FontWeight.w700,
                        color: AppColors.forest,
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
            ),
            SoftTile(
              onTap: () => showStaticSnack(context, 'Request sent (static)'),
              child: Row(
                children: [
                  const Icon(Icons.request_page_outlined, color: AppColors.amber),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Send payment request',
                      style: GoogleFonts.manrope(
                        fontWeight: FontWeight.w700,
                        color: AppColors.forest,
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
            ),
            const SectionLabel('Recent settlements'),
            SoftTile(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'You paid Sam',
                          style: GoogleFonts.manrope(
                            fontWeight: FontWeight.w700,
                            color: AppColors.forest,
                          ),
                        ),
                        Text(
                          'Bali Trip · Venmo · Jun 11',
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const MoneyText(45, positive: false, size: 16),
                ],
              ),
            ),
            SoftTile(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Maya paid you',
                          style: GoogleFonts.manrope(
                            fontWeight: FontWeight.w700,
                            color: AppColors.forest,
                          ),
                        ),
                        Text(
                          'Bali Trip · Cash · Jun 9',
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const MoneyText(30, positive: true, size: 16),
                ],
              ),
            ),
            const SectionLabel('Open requests'),
            SoftTile(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Maya requested \$30',
                          style: GoogleFonts.manrope(
                            fontWeight: FontWeight.w700,
                            color: AppColors.forest,
                          ),
                        ),
                        Text(
                          'Hotel share',
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () =>
                        showStaticSnack(context, 'Accepted (static)'),
                    child: const Text('Accept'),
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

class RecordSettlementScreen extends StatefulWidget {
  const RecordSettlementScreen({super.key});

  @override
  State<RecordSettlementScreen> createState() => _RecordSettlementScreenState();
}

class _RecordSettlementScreenState extends State<RecordSettlementScreen> {
  final _amount = TextEditingController();
  String _method = 'venmo';

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
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
              title: 'Settle up',
              onBack: () => Navigator.pop(context),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AuthTextField(
                    controller: _amount,
                    label: 'Amount',
                    hint: '45.00',
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Payment method',
                    style: GoogleFonts.manrope(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: ['cash', 'venmo', 'paypal', 'zelle', 'cashapp']
                        .map((m) {
                      return ChoiceChip(
                        label: Text(m),
                        selected: _method == m,
                        onSelected: (_) => setState(() => _method = m),
                        selectedColor: AppColors.mintWash,
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 28),
                  AuthPrimaryButton(
                    label: 'Record settlement',
                    onPressed: () {
                      showStaticSnack(context, 'Settlement recorded (static)');
                      Navigator.pop(context);
                    },
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
