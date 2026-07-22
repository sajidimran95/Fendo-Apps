import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/report_model.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/app_widgets.dart';

class ReportBucketList extends StatelessWidget {
  const ReportBucketList({super.key, required this.items, this.positive});

  final List<ReportBucket> items;
  final bool? positive;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Text(
          'No data',
          style: GoogleFonts.manrope(color: AppColors.textMuted),
        ),
      );
    }
    final max = items.map((e) => e.amount.abs()).fold<double>(0, (a, b) {
      return a > b ? a : b;
    });
    final denom = max <= 0 ? 1.0 : max;

    return Column(
      children: items.map((b) {
        return SoftTile(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      b.label,
                      style: GoogleFonts.manrope(
                        fontWeight: FontWeight.w700,
                        color: AppColors.forest,
                      ),
                    ),
                  ),
                  MoneyText(b.amount, positive: positive, size: 14),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: (b.amount.abs() / denom).clamp(0.0, 1.0),
                  minHeight: 8,
                  backgroundColor: AppColors.surfaceMuted,
                  color: AppColors.mint,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class ReportSummaryTile extends StatelessWidget {
  const ReportSummaryTile({
    super.key,
    required this.totalSpent,
    required this.totalOwed,
    this.expensesOnly,
    this.billsPaid = 0,
    this.subtitle,
  });

  /// Combined spending (expenses + bills paid).
  final double totalSpent;
  final double totalOwed;

  /// Expense-only portion when bills are merged into [totalSpent].
  final double? expensesOnly;
  final double billsPaid;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final expenses = expensesOnly ?? (totalSpent - billsPaid);
    final showBreakdown = billsPaid > 0 || expensesOnly != null;

    return SoftTile(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (subtitle != null) ...[
            Text(
              subtitle!,
              style: GoogleFonts.manrope(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 10),
          ],
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total spent',
                      style: GoogleFonts.manrope(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    MoneyText(totalSpent, positive: false, size: 22),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Owed',
                      style: GoogleFonts.manrope(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    MoneyText(totalOwed, positive: false, size: 22),
                  ],
                ),
              ),
            ],
          ),
          if (showBreakdown) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Expenses  \$${expenses.toStringAsFixed(2)}',
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.forestSoft,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Bills paid  \$${billsPaid.toStringAsFixed(2)}',
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.forestSoft,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
