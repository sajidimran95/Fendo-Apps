import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/mock_data.dart';
import '../../theme/app_colors.dart';
import '../../widgets/auth/auth_widgets.dart';
import '../../widgets/common/app_widgets.dart';

class ExpensesScreen extends StatelessWidget {
  const ExpensesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_expenses',
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CreateExpenseScreen()),
          );
        },
        backgroundColor: AppColors.forest,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: Text(
          'Add expense',
          style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: ListView(
          children: [
            AppHeader(
              title: 'Expenses',
              subtitle: 'All shared spending',
              onBack: () => Navigator.pop(context),
            ),
            ...MockData.expenses.map((e) {
              return SoftTile(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ExpenseDetailScreen(expense: e),
                    ),
                  );
                },
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.mintWash,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.shopping_bag_outlined,
                        color: AppColors.mint,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            e.title,
                            style: GoogleFonts.manrope(
                              fontWeight: FontWeight.w700,
                              color: AppColors.forest,
                            ),
                          ),
                          Text(
                            '${e.groupName} · ${e.paidBy} · ${e.date}',
                            style: GoogleFonts.manrope(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    MoneyText(e.amount, positive: false, size: 16),
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

class CreateExpenseScreen extends StatefulWidget {
  const CreateExpenseScreen({super.key});

  @override
  State<CreateExpenseScreen> createState() => _CreateExpenseScreenState();
}

class _CreateExpenseScreenState extends State<CreateExpenseScreen> {
  final _title = TextEditingController();
  final _amount = TextEditingController();
  String _split = 'equal';

  @override
  void dispose() {
    _title.dispose();
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
              title: 'Add expense',
              onBack: () => Navigator.pop(context),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AuthTextField(
                    controller: _title,
                    label: 'Title',
                    hint: 'Dinner at Nobu',
                  ),
                  const SizedBox(height: 14),
                  AuthTextField(
                    controller: _amount,
                    label: 'Amount',
                    hint: '120.00',
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Split method',
                    style: GoogleFonts.manrope(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: AppColors.forestSoft,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: ['equal', 'percentage', 'shares', 'custom', 'itemized']
                        .map((m) {
                      return ChoiceChip(
                        label: Text(m),
                        selected: _split == m,
                        onSelected: (_) => setState(() => _split = m),
                        selectedColor: AppColors.mintWash,
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 28),
                  AuthPrimaryButton(
                    label: 'Save expense',
                    onPressed: () {
                      showStaticSnack(context, 'Expense saved (static)');
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

class ExpenseDetailScreen extends StatelessWidget {
  const ExpenseDetailScreen({super.key, required this.expense});

  final MockExpense expense;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: ListView(
          children: [
            AppHeader(
              title: expense.title,
              subtitle: expense.groupName,
              onBack: () => Navigator.pop(context),
            ),
            SoftTile(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MoneyText(expense.amount, positive: false, size: 32),
                  const SizedBox(height: 8),
                  Text(
                    'Paid by ${expense.paidBy} · ${expense.date}',
                    style: GoogleFonts.manrope(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  StatusChip(expense.category),
                ],
              ),
            ),
            const SectionLabel('Split (equal)'),
            SoftTile(
              child: Column(
                children: ['Alex', 'Sam', 'Maya']
                    .map(
                      (n) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: AppColors.mintWash,
                              child: Text(n[0]),
                            ),
                            const SizedBox(width: 10),
                            Expanded(child: Text(n)),
                            MoneyText(
                              expense.amount / 3,
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
        ),
      ),
    );
  }
}
