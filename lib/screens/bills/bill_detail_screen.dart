import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/network/api_exception.dart';
import '../../models/bill_model.dart';
import '../../services/bills_controller.dart';
import '../../theme/app_colors.dart';
import '../../utils/api_feedback.dart';
import '../../widgets/auth/auth_widgets.dart';
import '../../widgets/common/app_widgets.dart';

class BillDetailScreen extends StatefulWidget {
  const BillDetailScreen({super.key, required this.billId});

  final int billId;

  @override
  State<BillDetailScreen> createState() => _BillDetailScreenState();
}

class _BillDetailScreenState extends State<BillDetailScreen> {
  BillModel? _bill;
  bool _loading = true;
  bool _paying = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final bill = await BillsController.instance.getBill(widget.billId);
      if (!mounted) return;
      setState(() => _bill = bill);
    } on ApiException catch (e) {
      if (!mounted) return;
      showApiError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _payFull() async {
    final b = _bill;
    if (b == null) return;
    final method = await _showPaySheet(
      title: 'Pay bill',
      amountLabel: 'Amount due',
      amount: b.remaining > 0 ? b.remaining : b.amount,
      requireAmount: false,
    );
    if (method == null || !mounted) return;
    setState(() => _paying = true);
    try {
      final bill = await BillsController.instance.payBill(
        widget.billId,
        paymentMethod: method.paymentMethod,
      );
      if (!mounted) return;
      setState(() => _bill = bill);
      showApiMessage(context, 'Bill paid');
    } on ApiException catch (e) {
      if (!mounted) return;
      showApiError(context, e);
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  Future<void> _payPartial() async {
    final b = _bill;
    if (b == null) return;
    final result = await _showPaySheet(
      title: 'Partial pay',
      amountLabel: 'Amount',
      amount: b.remaining > 0 ? b.remaining : b.amount,
      requireAmount: true,
    );
    if (result == null || !mounted) return;
    final amount = result.amount;
    if (amount == null || amount <= 0) {
      showApiError(context, ApiException(message: 'Enter a valid amount'));
      return;
    }
    setState(() => _paying = true);
    try {
      final bill = await BillsController.instance.partialPayBill(
        widget.billId,
        amount: amount,
        paymentMethod: result.paymentMethod,
      );
      if (!mounted) return;
      setState(() => _bill = bill);
      showApiMessage(context, 'Partial payment saved');
    } on ApiException catch (e) {
      if (!mounted) return;
      showApiError(context, e);
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  Future<_PaySheetResult?> _showPaySheet({
    required String title,
    required String amountLabel,
    required double amount,
    required bool requireAmount,
  }) {
    return showModalBottomSheet<_PaySheetResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _BillPaySheet(
        title: title,
        billName: _bill?.name ?? 'Bill',
        amountLabel: amountLabel,
        suggestedAmount: amount,
        requireAmount: requireAmount,
      ),
    );
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete bill?'),
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
      await BillsController.instance.deleteBill(widget.billId);
      if (!mounted) return;
      Navigator.pop(context);
    } on ApiException catch (e) {
      if (!mounted) return;
      showApiError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = _bill;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: _loading && b == null
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.mint),
              )
            : b == null
                ? const EmptyHint(message: 'Bill not found')
                : RefreshIndicator(
                    color: AppColors.mint,
                    onRefresh: _load,
                    child: ListView(
                      children: [
                        AppHeader(
                          title: b.name,
                          subtitle: b.groupName,
                          onBack: () => Navigator.pop(context),
                          trailing: IconButton(
                            onPressed: _delete,
                            icon: const Icon(Icons.delete_outline_rounded),
                            color: AppColors.coral,
                          ),
                        ),
                        SoftTile(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              MoneyText(b.amount, positive: false, size: 32),
                              const SizedBox(height: 8),
                              Text(
                                'Due ${b.dueDate}',
                                style: GoogleFonts.manrope(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              if (b.amountPaid > 0) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Paid \$${b.amountPaid.toStringAsFixed(2)} · Remaining \$${b.remaining.toStringAsFixed(2)}',
                                  style: GoogleFonts.manrope(
                                    color: AppColors.textMuted,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                children: [
                                  StatusChip(b.status.replaceAll('_', ' ')),
                                  if (b.isRecurring)
                                    StatusChip(b.frequency ?? 'recurring'),
                                ],
                              ),
                              if (b.notes != null && b.notes!.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Text(
                                  b.notes!,
                                  style: GoogleFonts.manrope(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (b.splits.isNotEmpty) ...[
                          const SectionLabel('Splits'),
                          ...b.splits.map(
                            (s) => SoftTile(
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      s.name ?? 'User ${s.userId}',
                                      style: GoogleFonts.manrope(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  MoneyText(
                                    s.amountOwed,
                                    positive: false,
                                    size: 14,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        if (b.status != 'paid') ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                            child: AuthPrimaryButton(
                              label: 'Pay full',
                              loading: _paying,
                              onPressed: _paying ? null : _payFull,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                            child: OutlinedButton(
                              onPressed: _paying ? null : _payPartial,
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(52),
                                foregroundColor: AppColors.forest,
                              ),
                              child: Text(
                                'Partial pay',
                                style: GoogleFonts.manrope(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
      ),
    );
  }
}

class _PaySheetResult {
  const _PaySheetResult({this.amount, this.paymentMethod});

  final double? amount;
  final String? paymentMethod;
}

class _BillPaySheet extends StatefulWidget {
  const _BillPaySheet({
    required this.title,
    required this.billName,
    required this.amountLabel,
    required this.suggestedAmount,
    required this.requireAmount,
  });

  final String title;
  final String billName;
  final String amountLabel;
  final double suggestedAmount;
  final bool requireAmount;

  @override
  State<_BillPaySheet> createState() => _BillPaySheetState();
}

class _BillPaySheetState extends State<_BillPaySheet> {
  static const _methods = [
    'cash',
    'bank_transfer',
    'venmo',
    'paypal',
    'zelle',
    'cashapp',
    'apple_pay',
    'other',
  ];

  late final TextEditingController _amountCtrl;
  late final TextEditingController _otherCtrl;
  String? _method;

  @override
  void initState() {
    super.initState();
    _amountCtrl = TextEditingController(
      text: widget.requireAmount
          ? ''
          : widget.suggestedAmount.toStringAsFixed(2),
    );
    _otherCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _otherCtrl.dispose();
    super.dispose();
  }

  String? get _resolvedMethod {
    final other = _otherCtrl.text.trim();
    if (other.isNotEmpty) return other;
    return _method;
  }

  void _submit() {
    double? amount;
    if (widget.requireAmount) {
      amount = double.tryParse(_amountCtrl.text.trim());
      if (amount == null || amount <= 0) {
        showApiError(context, ApiException(message: 'Enter a valid amount'));
        return;
      }
    }
    Navigator.pop(
      context,
      _PaySheetResult(amount: amount, paymentMethod: _resolvedMethod),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.title,
                  style: GoogleFonts.sora(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.forest,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.billName,
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.mintWash,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.requireAmount
                              ? 'Remaining'
                              : widget.amountLabel,
                          style: GoogleFonts.manrope(
                            fontWeight: FontWeight.w600,
                            color: AppColors.forestSoft,
                          ),
                        ),
                      ),
                      MoneyText(
                        widget.suggestedAmount,
                        positive: false,
                        size: 22,
                      ),
                    ],
                  ),
                ),
                if (widget.requireAmount) ...[
                  const SizedBox(height: 16),
                  AuthTextField(
                    controller: _amountCtrl,
                    label: widget.amountLabel,
                    hint: widget.suggestedAmount.toStringAsFixed(2),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Text(
                  'Payment method',
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.forestSoft,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Optional',
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _methods.map((m) {
                    final selected = _method == m;
                    return ChoiceChip(
                      label: Text(
                        m,
                        style: GoogleFonts.manrope(
                          fontWeight: FontWeight.w600,
                          color: selected
                              ? AppColors.forest
                              : AppColors.textSecondary,
                        ),
                      ),
                      selected: selected,
                      onSelected: (_) => setState(() {
                        _method = selected ? null : m;
                        if (_method != null) _otherCtrl.clear();
                      }),
                      selectedColor: AppColors.mintWash,
                      backgroundColor: AppColors.surfaceMuted,
                      side: BorderSide(
                        color: selected ? AppColors.mint : AppColors.border,
                      ),
                      showCheckmark: false,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                AuthTextField(
                  controller: _otherCtrl,
                  label: 'Other',
                  hint: 'Bank transfer, etc.',
                  onFieldSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          foregroundColor: AppColors.forest,
                          side: const BorderSide(color: AppColors.border),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.manrope(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: AuthPrimaryButton(
                        label: 'Pay',
                        onPressed: _submit,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
