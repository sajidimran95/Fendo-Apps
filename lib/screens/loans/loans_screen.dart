import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/contact_match_model.dart';
import '../../services/loans_controller.dart';
import '../../theme/app_colors.dart';
import '../../widgets/auth/auth_widgets.dart';
import '../../widgets/common/app_widgets.dart';
import 'create_loan_screen.dart';

class LoansScreen extends StatelessWidget {
  const LoansScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.heroWash),
        child: SafeArea(
          child: Column(
            children: [
              AppHeader(
                title: 'Loans',
                subtitle: 'Personal lend & borrow',
                onBack: () => Navigator.pop(context),
                trailing: IconButton(
                  tooltip: 'New loan',
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const CreateLoanScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.add_rounded),
                  color: AppColors.forest,
                ),
              ),
              Expanded(
                child: ListenableBuilder(
                  listenable: LoansController.instance,
                  builder: (context, _) {
                    final ctrl = LoansController.instance;
                    final loans = ctrl.loans;
                    return ListView(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _SummaryCard(
                                label: 'You lent',
                                amount: ctrl.youLent,
                                positive: true,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _SummaryCard(
                                label: 'You borrowed',
                                amount: ctrl.youBorrowed,
                                positive: false,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppColors.border.withValues(alpha: 0.7),
                            ),
                          ),
                          child: Row(
                            children: [
                              Text(
                                'Net balance',
                                style: GoogleFonts.manrope(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.forestSoft,
                                ),
                              ),
                              const Spacer(),
                              MoneyText(
                                ctrl.netBalance,
                                positive: ctrl.netBalance >= 0,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'All loans (${ctrl.activeCount})',
                          style: GoogleFonts.sora(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.forest,
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (loans.isEmpty)
                          Text(
                            'No loans yet',
                            style: GoogleFonts.manrope(
                              color: AppColors.textMuted,
                            ),
                          )
                        else
                          ...loans.map(
                            (l) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _LoanTile(loan: l),
                            ),
                          ),
                        const SizedBox(height: 8),
                        AuthPrimaryButton(
                          label: 'Create loan',
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const CreateLoanScreen(),
                              ),
                            );
                          },
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.amount,
    required this.positive,
  });

  final String label;
  final double amount;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 6),
          MoneyText(amount, positive: positive, size: 22),
        ],
      ),
    );
  }
}

class _LoanTile extends StatelessWidget {
  const _LoanTile({required this.loan});

  final MockLoan loan;

  @override
  Widget build(BuildContext context) {
    final give = loan.isGive;
    return SoftTile(
      margin: EdgeInsets.zero,
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: give
                ? AppColors.mintWash
                : AppColors.coral.withValues(alpha: 0.12),
            child: Icon(
              give ? Icons.north_east_rounded : Icons.south_west_rounded,
              color: give ? AppColors.mint : AppColors.coral,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  loan.personName,
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.w700,
                    color: AppColors.forest,
                  ),
                ),
                Text(
                  '${give ? 'You lent' : 'You borrowed'} · ${loan.date}'
                  '${loan.note != null && loan.note!.isNotEmpty ? ' · ${loan.note}' : ''}',
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          MoneyText(loan.amount, positive: give, size: 16),
        ],
      ),
    );
  }
}
