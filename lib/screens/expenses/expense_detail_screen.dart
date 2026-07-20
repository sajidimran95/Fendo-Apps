import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/network/api_exception.dart';
import '../../models/expense_model.dart';
import '../../services/expenses_controller.dart';
import '../../theme/app_colors.dart';
import '../../utils/api_feedback.dart';
import '../../widgets/common/app_widgets.dart';
import 'edit_expense_screen.dart';

class ExpenseDetailScreen extends StatefulWidget {
  const ExpenseDetailScreen({super.key, required this.expenseId});

  final int expenseId;

  @override
  State<ExpenseDetailScreen> createState() => _ExpenseDetailScreenState();
}

class _ExpenseDetailScreenState extends State<ExpenseDetailScreen> {
  ExpenseModel? _expense;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final e = await ExpensesController.instance.getExpense(widget.expenseId);
      if (!mounted) return;
      setState(() => _expense = e);
    } on ApiException catch (e) {
      if (!mounted) return;
      showApiError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete expense?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ExpensesController.instance.deleteExpense(widget.expenseId);
      if (!mounted) return;
      showApiMessage(context, 'Expense deleted');
      Navigator.pop(context);
    } on ApiException catch (e) {
      if (!mounted) return;
      showApiError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = _expense;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: _loading && e == null
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.mint),
              )
            : e == null
                ? const EmptyHint(message: 'Expense not found')
                : RefreshIndicator(
                    color: AppColors.mint,
                    onRefresh: _load,
                    child: ListView(
                      children: [
                        AppHeader(
                          title: e.title,
                          subtitle: e.groupName,
                          onBack: () => Navigator.pop(context),
                          trailing: PopupMenuButton<String>(
                            onSelected: (v) async {
                              if (v == 'edit') {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        EditExpenseScreen(expense: e),
                                  ),
                                );
                                _load();
                              } else if (v == 'delete') {
                                await _delete();
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: 'edit',
                                child: Text('Edit'),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text('Delete'),
                              ),
                            ],
                          ),
                        ),
                        SoftTile(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              MoneyText(e.amount, positive: false, size: 32),
                              const SizedBox(height: 8),
                              Text(
                                'Paid by ${e.paidByLabel} · ${e.expenseDate}',
                                style: GoogleFonts.manrope(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              if (e.merchantName != null &&
                                  e.merchantName!.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  e.merchantName!,
                                  style: GoogleFonts.manrope(
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                children: [
                                  StatusChip(e.splitMethod),
                                  if (e.categoryName != null)
                                    StatusChip(e.categoryName!),
                                  if (e.isMultiPayer)
                                    const StatusChip('multi-payer'),
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (e.payers.isNotEmpty) ...[
                          const SectionLabel('Payers'),
                          SoftTile(
                            child: Column(
                              children: e.payers
                                  .map(
                                    (p) => Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 8,
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              p.name ?? 'User ${p.userId}',
                                              style: GoogleFonts.manrope(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          MoneyText(
                                            p.amountPaid,
                                            positive: false,
                                            size: 14,
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                        ],
                        if (e.participants.isNotEmpty) ...[
                          SectionLabel('Split (${e.splitMethod})'),
                          SoftTile(
                            child: Column(
                              children: e.participants
                                  .map(
                                    (p) => Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 8,
                                      ),
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 16,
                                            backgroundColor: AppColors.mintWash,
                                            child: Text(
                                              (p.name ?? '?')[0].toUpperCase(),
                                              style: GoogleFonts.sora(
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.mint,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              p.name ?? 'User ${p.userId}',
                                            ),
                                          ),
                                          Text(
                                            _participantShareLabel(p),
                                            style: GoogleFonts.manrope(
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.forest,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                        ],
                        if (e.items.isNotEmpty) ...[
                          const SectionLabel('Items'),
                          ...e.items.map(
                            (item) => SoftTile(
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      item.name,
                                      style: GoogleFonts.manrope(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  MoneyText(
                                    item.amount,
                                    positive: false,
                                    size: 14,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
      ),
    );
  }

  String _participantShareLabel(ExpenseParticipant p) {
    if (p.amount != null) return '\$${p.amount!.toStringAsFixed(2)}';
    if (p.percentage != null) return '${p.percentage}%';
    if (p.shares != null) return '${p.shares} shares';
    return 'equal';
  }
}
