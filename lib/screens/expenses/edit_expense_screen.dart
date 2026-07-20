import 'package:flutter/material.dart';

import '../../core/network/api_exception.dart';
import '../../models/expense_model.dart';
import '../../services/expenses_controller.dart';
import '../../theme/app_colors.dart';
import '../../utils/api_feedback.dart';
import '../../widgets/auth/auth_widgets.dart';
import '../../widgets/common/app_widgets.dart';

class EditExpenseScreen extends StatefulWidget {
  const EditExpenseScreen({super.key, required this.expense});

  final ExpenseModel expense;

  @override
  State<EditExpenseScreen> createState() => _EditExpenseScreenState();
}

class _EditExpenseScreenState extends State<EditExpenseScreen> {
  late final TextEditingController _title;
  late final TextEditingController _merchant;
  late final TextEditingController _categoryId;
  late final TextEditingController _amount;
  late DateTime _date;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final e = widget.expense;
    _title = TextEditingController(text: e.title);
    _merchant = TextEditingController(text: e.merchantName ?? '');
    _categoryId = TextEditingController(
      text: e.categoryId?.toString() ?? '',
    );
    _amount = TextEditingController(text: e.amount.toStringAsFixed(2));
    _date = DateTime.tryParse(e.expenseDate) ?? DateTime.now();
  }

  @override
  void dispose() {
    _title.dispose();
    _merchant.dispose();
    _categoryId.dispose();
    _amount.dispose();
    super.dispose();
  }

  String get _dateStr =>
      '${_date.year.toString().padLeft(4, '0')}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}';

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      showApiError(context, ApiException(message: 'Title is required'));
      return;
    }
    setState(() => _loading = true);
    try {
      await ExpensesController.instance.updateExpense(
        widget.expense.id,
        title: _title.text.trim(),
        merchantName: _merchant.text.trim(),
        categoryId: int.tryParse(_categoryId.text.trim()),
        amount: double.tryParse(_amount.text.trim()),
        expenseDate: _dateStr,
      );
      if (!mounted) return;
      showApiMessage(context, 'Expense updated');
      Navigator.pop(context);
    } on ApiException catch (e) {
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
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            AppHeader(
              title: 'Edit expense',
              onBack: () => Navigator.pop(context),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  AuthTextField(controller: _title, label: 'Title'),
                  const SizedBox(height: 14),
                  AuthTextField(
                    controller: _amount,
                    label: 'Amount',
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                  const SizedBox(height: 14),
                  AuthTextField(
                    controller: _merchant,
                    label: 'Merchant name',
                  ),
                  const SizedBox(height: 14),
                  AuthTextField(
                    controller: _categoryId,
                    label: 'Category ID',
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 14),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Expense date'),
                    subtitle: Text(_dateStr),
                    trailing: const Icon(Icons.calendar_today_outlined),
                    onTap: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: _date,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (d != null) setState(() => _date = d);
                    },
                  ),
                  const SizedBox(height: 24),
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
