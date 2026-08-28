import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/utils/format_date.dart';
import '../../models/contact_match_model.dart';
import '../../services/loans_controller.dart';
import '../../theme/app_colors.dart';
import '../../utils/api_feedback.dart';
import '../../widgets/auth/auth_widgets.dart';
import '../../widgets/common/app_widgets.dart';
import 'create_loan_screen.dart';

class LoansScreen extends StatefulWidget {
  const LoansScreen({super.key});

  @override
  State<LoansScreen> createState() => _LoansScreenState();
}

class _LoansScreenState extends State<LoansScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load({bool force = false}) async {
    try {
      await LoansController.instance.load(force: force);
    } catch (e) {
      if (!mounted) return;
      showApiError(context, e);
    }
  }

  Future<void> _openCreate() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CreateLoanScreen()),
    );
    await _load(force: true);
  }

  Future<void> _markPaid(MockLoan loan) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Mark as paid?',
          style: GoogleFonts.sora(fontWeight: FontWeight.w700),
        ),
        content: Text(
          loan.isGive
              ? '${loan.personName} repaid you. This clears the loan IOU — it is not recorded as a new expense.'
              : 'You repaid ${loan.personName}. This clears the loan IOU — it is not recorded as a new expense.',
          style: GoogleFonts.manrope(height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.mint),
            child: const Text('Mark paid'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await LoansController.instance.markPaid(loan.id);
      if (!mounted) return;
      showApiMessage(context, 'Loan marked as paid');
    } catch (e) {
      if (!mounted) return;
      showApiError(context, e);
    }
  }

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
                subtitle: 'IOUs · not spending expenses',
                onBack: () => Navigator.pop(context),
                trailing: IconButton(
                  tooltip: 'New loan',
                  onPressed: _openCreate,
                  icon: const Icon(Icons.add_rounded),
                  color: AppColors.forest,
                ),
              ),
              Expanded(
                child: ListenableBuilder(
                  listenable: LoansController.instance,
                  builder: (context, _) {
                    final ctrl = LoansController.instance;
                    final open = ctrl.openLoans;
                    final paid = ctrl.paidLoans;
                    if (ctrl.loading && ctrl.loans.isEmpty) {
                      return const Center(
                        child: CircularProgressIndicator(color: AppColors.mint),
                      );
                    }
                    return RefreshIndicator(
                      color: AppColors.mint,
                      onRefresh: () => _load(force: true),
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                        children: [
                          SoftTile(
                            margin: EdgeInsets.zero,
                            child: Text(
                              'Lent / borrowed money is an IOU, not a group expense. '
                              'Mark paid when settled — that closes the loan without creating spending.',
                              style: GoogleFonts.manrope(
                                fontSize: 12,
                                height: 1.4,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
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
                                color:
                                    AppColors.border.withValues(alpha: 0.7),
                              ),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  'Net open',
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
                            'Open loans (${ctrl.activeCount})',
                            style: GoogleFonts.sora(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: AppColors.forest,
                            ),
                          ),
                          const SizedBox(height: 10),
                          if (open.isEmpty)
                            SoftTile(
                              margin: EdgeInsets.zero,
                              child: Text(
                                'No open loans. Tap + to lend or borrow. Group bills stay under Expenses.',
                                style: GoogleFonts.manrope(
                                  color: AppColors.textMuted,
                                ),
                              ),
                            )
                          else
                            ...open.map(
                              (l) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _LoanTile(
                                  loan: l,
                                  onMarkPaid: () => _markPaid(l),
                                ),
                              ),
                            ),
                          if (paid.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text(
                              'Paid (${paid.length})',
                              style: GoogleFonts.sora(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                                color: AppColors.forest,
                              ),
                            ),
                            const SizedBox(height: 10),
                            ...paid.map(
                              (l) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _LoanTile(loan: l),
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),
                          AuthPrimaryButton(
                            label: 'Create loan',
                            onPressed: _openCreate,
                          ),
                        ],
                      ),
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
  const _LoanTile({required this.loan, this.onMarkPaid});

  final MockLoan loan;
  final VoidCallback? onMarkPaid;

  @override
  Widget build(BuildContext context) {
    final give = loan.isGive;
    final paid = loan.isPaid;
    return SoftTile(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: paid
                    ? AppColors.surfaceMuted
                    : give
                        ? AppColors.mintWash
                        : AppColors.coral.withValues(alpha: 0.12),
                child: Icon(
                  paid
                      ? Icons.check_rounded
                      : give
                          ? Icons.north_east_rounded
                          : Icons.south_west_rounded,
                  color: paid
                      ? AppColors.textMuted
                      : give
                          ? AppColors.mint
                          : AppColors.coral,
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
                      '${paid ? 'Paid' : (give ? 'You lent' : 'You borrowed')} · ${formatDisplayDate(loan.date)}'
                      '${loan.note != null && loan.note!.isNotEmpty ? ' · ${loan.note}' : ''}',
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              MoneyText(
                loan.amount,
                currency: loan.currency,
                positive: give,
                size: 16,
              ),
            ],
          ),
          if (onMarkPaid != null && !paid) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonal(
                onPressed: onMarkPaid,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.mintWash,
                  foregroundColor: AppColors.forest,
                ),
                child: Text(
                  'Mark paid',
                  style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
          if (paid) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: StatusChip('Paid', color: AppColors.mint),
            ),
          ],
        ],
      ),
    );
  }
}
