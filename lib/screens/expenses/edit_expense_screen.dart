import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/network/api_exception.dart';
import '../../models/category_model.dart';
import '../../models/expense_model.dart';
import '../../services/auth_controller.dart';
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
  late final TextEditingController _amount;
  late DateTime _date;
  int? _categoryId;
  List<CategoryModel> _categories = const [];
  bool _loading = false;
  bool _booting = true;

  @override
  void initState() {
    super.initState();
    final e = widget.expense;
    _title = TextEditingController(text: e.title);
    _merchant = TextEditingController(text: e.merchantName ?? '');
    _amount = TextEditingController(text: e.amount.toStringAsFixed(2));
    _date = DateTime.tryParse(e.expenseDate) ?? DateTime.now();
    _categoryId = e.categoryId;
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCategories());
  }

  Future<void> _loadCategories() async {
    try {
      final categories =
          await AuthController.instance.categoriesApi.listCategories();
      if (!mounted) return;
      setState(() {
        _categories = categories;
        _booting = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _categories = const [
          CategoryModel(id: 1, name: 'Food & Drink'),
          CategoryModel(id: 2, name: 'Transport'),
          CategoryModel(id: 3, name: 'Accommodation'),
          CategoryModel(id: 4, name: 'Entertainment'),
          CategoryModel(id: 5, name: 'Shopping'),
          CategoryModel(id: 6, name: 'Utilities'),
          CategoryModel(id: 7, name: 'Health'),
          CategoryModel(id: 8, name: 'Groceries'),
          CategoryModel(id: 9, name: 'Education'),
          CategoryModel(id: 10, name: 'Other'),
        ];
        _booting = false;
      });
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _merchant.dispose();
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
        merchantName: _merchant.text.trim().isEmpty
            ? null
            : _merchant.text.trim(),
        categoryId: _categoryId,
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
        child: _booting
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.mint),
              )
            : ListView(
                padding: const EdgeInsets.only(bottom: 32),
                children: [
                  AppHeader(
                    title: 'Edit expense',
                    onBack: () => Navigator.pop(context),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AuthTextField(controller: _title, label: 'Title'),
                        const SizedBox(height: 14),
                        AuthTextField(
                          controller: _amount,
                          label: 'Amount',
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                        ),
                        const SizedBox(height: 14),
                        AuthTextField(
                          controller: _merchant,
                          label: 'Merchant name',
                          hint: 'optional',
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Category',
                          style: GoogleFonts.manrope(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.forestSoft,
                            letterSpacing: 0.15,
                          ),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<int?>(
                          key: ValueKey('edit-cat-$_categoryId'),
                          initialValue: _categoryId,
                          items: [
                            const DropdownMenuItem<int?>(
                              value: null,
                              child: Text('None'),
                            ),
                            ..._categories.map(
                              (c) => DropdownMenuItem<int?>(
                                value: c.id,
                                child: Text(c.name),
                              ),
                            ),
                          ],
                          onChanged: (id) =>
                              setState(() => _categoryId = id),
                          decoration: const InputDecoration(
                            hintText: 'optional',
                          ),
                        ),
                        const SizedBox(height: 14),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Expense date'),
                          subtitle: Text(_dateStr),
                          trailing:
                              const Icon(Icons.calendar_today_outlined),
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
