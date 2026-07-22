import 'package:flutter/foundation.dart';

import '../core/config/api_config.dart';
import '../core/network/api_exception.dart';
import '../models/expense_model.dart';
import 'auth_controller.dart';
import 'expenses_api.dart';
import 'groups_controller.dart';

class ExpensesController extends ChangeNotifier {
  ExpensesController._();

  static final ExpensesController instance = ExpensesController._();

  ExpensesApi get _api => AuthController.instance.expensesApi;

  final List<ExpenseModel> _expenses = [];
  int _nextId = 200;
  bool _seeded = false;

  List<ExpenseModel> get expenses => List.unmodifiable(_expenses);

  void _seedDemoIfNeeded() {
    if (_seeded) return;
    _seeded = true;
    _expenses.addAll([
      ExpenseModel(
        id: 1,
        title: 'Dinner at Nobu',
        amount: 186,
        currency: 'USD',
        expenseDate: '2026-07-18',
        groupId: 1,
        groupName: 'Bali Trip',
        categoryId: 1,
        categoryName: 'Food',
        splitMethod: 'equal',
        payers: const [
          ExpensePayer(userId: 1, amountPaid: 186, name: 'You'),
        ],
        participants: const [
          ExpenseParticipant(userId: 1, name: 'You', amount: 62),
          ExpenseParticipant(userId: 2, name: 'Sam', amount: 62),
          ExpenseParticipant(userId: 3, name: 'Maya', amount: 62),
        ],
      ),
      ExpenseModel(
        id: 2,
        title: 'Airbnb deposit',
        amount: 420,
        currency: 'USD',
        expenseDate: '2026-07-10',
        groupId: 1,
        groupName: 'Bali Trip',
        categoryId: 2,
        categoryName: 'Stay',
        splitMethod: 'equal',
        payers: const [
          ExpensePayer(userId: 2, amountPaid: 420, name: 'Sam'),
        ],
        participants: const [
          ExpenseParticipant(userId: 1, name: 'You', amount: 105),
          ExpenseParticipant(userId: 2, name: 'Sam', amount: 105),
          ExpenseParticipant(userId: 3, name: 'Maya', amount: 105),
          ExpenseParticipant(userId: 4, name: 'Jordan', amount: 105),
        ],
      ),
      ExpenseModel(
        id: 3,
        title: 'Groceries',
        amount: 84.20,
        currency: 'USD',
        expenseDate: '2026-07-15',
        groupId: 2,
        groupName: 'Apartment 4B',
        categoryId: 1,
        categoryName: 'Food',
        splitMethod: 'shares',
        payers: const [
          ExpensePayer(userId: 1, amountPaid: 84.20, name: 'You'),
        ],
        participants: const [
          ExpenseParticipant(userId: 1, name: 'You', shares: 1),
          ExpenseParticipant(userId: 2, name: 'Sam', shares: 1),
          ExpenseParticipant(userId: 3, name: 'Maya', shares: 1),
        ],
      ),
    ]);
  }

  Future<List<ExpenseModel>> loadExpenses({
    int? groupId,
    String? from,
    String? to,
  }) async {
    if (ApiConfig.demoAuth) {
      _seedDemoIfNeeded();
      var list = List<ExpenseModel>.from(_expenses);
      if (groupId != null) {
        list = list.where((e) => e.groupId == groupId).toList();
      }
      if (from != null && from.isNotEmpty) {
        list = list.where((e) => e.expenseDate.compareTo(from) >= 0).toList();
      }
      if (to != null && to.isNotEmpty) {
        list = list.where((e) => e.expenseDate.compareTo(to) <= 0).toList();
      }
      list.sort((a, b) => b.expenseDate.compareTo(a.expenseDate));
      notifyListeners();
      return list;
    }
    final list = await _api.listExpenses(
      groupId: groupId,
      from: from,
      to: to,
    );
    _expenses
      ..clear()
      ..addAll(list);
    notifyListeners();
    return list;
  }

  Future<ExpenseModel> getExpense(int id) async {
    if (ApiConfig.demoAuth) {
      _seedDemoIfNeeded();
      return _expenses.firstWhere(
        (e) => e.id == id,
        orElse: () => throw ApiException(message: 'Expense not found'),
      );
    }
    return _api.getExpense(id);
  }

  Future<ExpenseModel> createExpense({
    required String title,
    required double amount,
    required String currency,
    required String expenseDate,
    required int groupId,
    String? groupName,
    int? categoryId,
    String? categoryName,
    required String splitMethod,
    required List<ExpensePayer> payers,
    required List<ExpenseParticipant> participants,
    List<ExpenseItem> items = const [],
    bool isMultiPayer = false,
    String? merchantName,
  }) async {
    if (ApiConfig.demoAuth) {
      _seedDemoIfNeeded();
      final groups = GroupsController.instance.groups;
      final gName = groupName ??
          groups
              .where((g) => g.id == groupId)
              .map((g) => g.name)
              .firstOrNull;
      final expense = ExpenseModel(
        id: _nextId++,
        title: title,
        amount: amount,
        currency: currency,
        expenseDate: expenseDate,
        groupId: groupId,
        groupName: gName ?? 'Group $groupId',
        categoryId: categoryId,
        categoryName: categoryName,
        splitMethod: splitMethod,
        payers: payers,
        participants: participants,
        items: items,
        isMultiPayer: isMultiPayer,
        merchantName: merchantName,
      );
      _expenses.insert(0, expense);
      notifyListeners();
      return expense;
    }
    final expense = await _api.createExpense(
      title: title,
      amount: amount,
      currency: currency,
      expenseDate: expenseDate,
      groupId: groupId,
      categoryId: categoryId,
      splitMethod: splitMethod,
      payers: payers,
      participants: participants,
      items: items,
      isMultiPayer: isMultiPayer,
    );
    _expenses.insert(0, expense);
    notifyListeners();
    return expense;
  }

  Future<ExpenseModel> updateExpense(
    int id, {
    String? title,
    int? categoryId,
    String? categoryName,
    String? merchantName,
    double? amount,
    String? expenseDate,
    String? splitMethod,
    List<ExpensePayer>? payers,
    List<ExpenseParticipant>? participants,
    List<ExpenseItem>? items,
    bool? isMultiPayer,
  }) async {
    if (ApiConfig.demoAuth) {
      final i = _expenses.indexWhere((e) => e.id == id);
      if (i < 0) throw ApiException(message: 'Expense not found');
      final updated = _expenses[i].copyWith(
        title: title,
        categoryId: categoryId,
        categoryName: categoryName,
        merchantName: merchantName,
        amount: amount,
        expenseDate: expenseDate,
        splitMethod: splitMethod,
        payers: payers,
        participants: participants,
        items: items,
        isMultiPayer: isMultiPayer,
      );
      _expenses[i] = updated;
      notifyListeners();
      return updated;
    }
    final expense = await _api.updateExpense(
      id,
      title: title,
      categoryId: categoryId,
      merchantName: merchantName,
      amount: amount,
      expenseDate: expenseDate,
      splitMethod: splitMethod,
      payers: payers,
      participants: participants,
      items: items,
      isMultiPayer: isMultiPayer,
    );
    final i = _expenses.indexWhere((e) => e.id == id);
    if (i >= 0) _expenses[i] = expense;
    notifyListeners();
    return expense;
  }

  Future<void> deleteExpense(int id) async {
    if (!ApiConfig.demoAuth) {
      await _api.deleteExpense(id);
    }
    _expenses.removeWhere((e) => e.id == id);
    notifyListeners();
  }

  Future<ScanReceiptResult> scanReceipt({
    required String filePath,
    required String fileName,
  }) async {
    if (ApiConfig.demoAuth) {
      return const ScanReceiptResult(
        title: 'Scanned receipt',
        amount: 48.75,
        merchantName: 'Demo Market',
        expenseDate: '2026-07-20',
        currency: 'USD',
        items: [
          ExpenseItem(name: 'Coffee', amount: 12.50),
          ExpenseItem(name: 'Sandwich', amount: 16.25),
          ExpenseItem(name: 'Pastry', amount: 20.00),
        ],
      );
    }
    return _api.scanReceipt(filePath: filePath, fileName: fileName);
  }
}
