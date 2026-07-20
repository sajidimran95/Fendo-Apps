import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/mock_data.dart';
import '../../theme/app_colors.dart';
import '../../widgets/auth/auth_widgets.dart';
import '../../widgets/common/app_widgets.dart';

class BillsScreen extends StatelessWidget {
  const BillsScreen({super.key});

  Color _statusColor(String s) {
    switch (s) {
      case 'due_today':
        return AppColors.amber;
      case 'overdue':
        return AppColors.coral;
      case 'paid':
        return AppColors.mint;
      default:
        return AppColors.forestSoft;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_bills',
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CreateBillScreen()),
          );
        },
        backgroundColor: AppColors.forest,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: Text(
          'New bill',
          style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: ListView(
          children: [
            const AppHeader(
              title: 'Bills',
              subtitle: 'Upcoming & recurring',
            ),
            ...MockData.bills.map((b) {
              return SoftTile(
                onTap: () => showStaticSnack(context, 'Bill detail (static)'),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            b.name,
                            style: GoogleFonts.manrope(
                              fontWeight: FontWeight.w700,
                              color: AppColors.forest,
                            ),
                          ),
                          Text(
                            '${b.groupName} · Due ${b.dueDate}',
                            style: GoogleFonts.manrope(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          StatusChip(
                            b.status.replaceAll('_', ' '),
                            color: _statusColor(b.status),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        MoneyText(b.amount, positive: false, size: 16),
                        TextButton(
                          onPressed: () =>
                              showStaticSnack(context, 'Marked paid (static)'),
                          child: const Text('Pay'),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}

class CreateBillScreen extends StatefulWidget {
  const CreateBillScreen({super.key});

  @override
  State<CreateBillScreen> createState() => _CreateBillScreenState();
}

class _CreateBillScreenState extends State<CreateBillScreen> {
  final _name = TextEditingController();
  final _amount = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
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
              title: 'New bill',
              onBack: () => Navigator.pop(context),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  AuthTextField(
                    controller: _name,
                    label: 'Bill name',
                    hint: 'Electricity',
                  ),
                  const SizedBox(height: 14),
                  AuthTextField(
                    controller: _amount,
                    label: 'Amount',
                    hint: '150.00',
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 28),
                  AuthPrimaryButton(
                    label: 'Create bill',
                    onPressed: () {
                      showStaticSnack(context, 'Bill created (static)');
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
