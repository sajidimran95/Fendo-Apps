import 'package:flutter/foundation.dart';

import '../core/config/api_config.dart';
import '../core/network/api_exception.dart';
import '../models/expense_model.dart';
import 'auth_controller.dart';
import 'activity_controller.dart';
import 'dashboard_controller.dart';
import 'expenses_api.dart';
import 'groups_controller.dart';
import 'receipt_ocr_service.dart';

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
        list = list.where((e) {
          final d = e.expenseDate.length >= 10
              ? e.expenseDate.substring(0, 10)
              : e.expenseDate;
          return d.compareTo(from) >= 0;
        }).toList();
      }
      if (to != null && to.isNotEmpty) {
        list = list.where((e) {
          final d = e.expenseDate.length >= 10
              ? e.expenseDate.substring(0, 10)
              : e.expenseDate;
          return d.compareTo(to) <= 0;
        }).toList();
      }
      list.sort((a, b) => b.expenseDate.compareTo(a.expenseDate));
      notifyListeners();
      return list;
    }

    List<ExpenseModel> list = const [];
    Object? loadError;
    try {
      list = await _api.listExpenses(
        groupId: groupId,
        from: from,
        to: to,
      );
    } catch (e) {
      debugPrint('loadExpenses primary failed: $e');
      loadError = e;
    }

    // Global list empty → load every group's expenses and merge.
    if (list.isEmpty && (groupId == null || groupId <= 0)) {
      try {
        if (GroupsController.instance.groups.isEmpty) {
          await GroupsController.instance.loadGroups();
        }
        final ids = GroupsController.instance.groups.map((g) => g.id);
        final merged = await _api.listExpensesForGroups(
          ids,
          from: from,
          to: to,
        );
        if (merged.isNotEmpty) {
          list = merged;
          loadError = null;
        }
      } catch (e) {
        debugPrint('loadExpenses group merge failed: $e');
        loadError ??= e;
      }
    }

    // Merge any newly created items kept locally (same id wins from API).
    final byId = <int, ExpenseModel>{
      for (final e in list) if (e.id > 0) e.id: e,
    };
    for (final e in _expenses) {
      if (e.id > 0 && !byId.containsKey(e.id)) {
        if (groupId != null && groupId > 0 && e.groupId != groupId) continue;
        byId[e.id] = e;
      }
    }
    final combined = byId.values.toList()
      ..sort((a, b) => b.expenseDate.compareTo(a.expenseDate));

    // Surface real API failures when we have nothing to show.
    if (combined.isEmpty && loadError != null) {
      if (loadError is ApiException) throw loadError;
      throw ApiException(message: loadError.toString());
    }

    _expenses
      ..clear()
      ..addAll(combined);
    notifyListeners();
    return combined;
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
    int? groupId,
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
          (groupId == null
              ? null
              : groups
                  .where((g) => g.id == groupId)
                  .map((g) => g.name)
                  .firstOrNull);
      final expense = ExpenseModel(
        id: _nextId++,
        title: title,
        amount: amount,
        currency: currency,
        expenseDate: expenseDate,
        groupId: groupId ?? 0,
        groupName: gName ?? (groupId == null ? 'Personal' : 'Group $groupId'),
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
      // ignore: unawaited_futures
      DashboardController.instance.load(force: true);
      // ignore: unawaited_futures
      ActivityController.instance.silentRefresh();
      return expense;
    }
    try {
      final expense = await _api.createExpense(
        title: title,
        amount: amount,
        currency: currency,
        expenseDate: expenseDate,
        groupId: groupId,
        categoryId: categoryId,
        merchantName: merchantName,
        splitMethod: splitMethod,
        payers: payers,
        participants: participants,
        items: items,
        isMultiPayer: isMultiPayer,
      );
      _expenses.insert(0, expense);
      notifyListeners();
      // Balance cards use GET /balances — refresh so dashboard is not stale.
      // ignore: unawaited_futures
      DashboardController.instance.load(force: true);
      // ignore: unawaited_futures
      ActivityController.instance.silentRefresh();
      return expense;
    } on ApiException catch (e) {
      // Live API sometimes writes the expense then 500s building the response.
      if (_looksLikeExpenseResponseBug(e) && groupId != null) {
        final recovered = await _recoverCreatedExpense(
          title: title,
          amount: amount,
          groupId: groupId,
          expenseDate: expenseDate,
        );
        if (recovered != null) {
          _expenses.insert(0, recovered);
          notifyListeners();
          // ignore: unawaited_futures
          DashboardController.instance.load(force: true);
          // ignore: unawaited_futures
          ActivityController.instance.silentRefresh();
          return recovered;
        }

        // Confirmed on fendo.posquickcart.com (Postman equal body):
        // 1st POST /expenses → 201; 2nd+ for same group → bare 500 and no row.
        if ((e.statusCode ?? 0) == 500) {
          final existing = await _countGroupExpenses(groupId);
          if (existing > 0) {
            throw ApiException(
              message:
                  'This group already has expenses. Live server blocks 2nd+ '
                  'create (HTTP 500). Backend ledger must be fixed.',
              statusCode: 500,
            );
          }
        }
      }
      rethrow;
    }
  }

  Future<int> _countGroupExpenses(int groupId) async {
    try {
      final list = await _api.listGroupExpenses(groupId);
      return list.length;
    } catch (_) {
      try {
        return (await _api.listExpenses(groupId: groupId)).length;
      } catch (_) {
        return 0;
      }
    }
  }

  bool _looksLikeExpenseResponseBug(ApiException e) {
    final code = e.statusCode ?? 0;
    // 201 incomplete body after write, or 500 after write.
    if (code == 500 || code == 201 || code == 200) return true;
    final msg = e.message.toLowerCase();
    return msg.contains('query expression') ||
        msg.contains('could not be converted to string') ||
        msg.contains('no query results') ||
        msg.contains('server error while finishing') ||
        msg.contains('model not found') ||
        msg.contains('invalid expense response') ||
        msg.contains('response was incomplete') ||
        msg.contains('may have been saved');
  }

  Future<ExpenseModel?> _recoverCreatedExpense({
    required String title,
    required double amount,
    required int groupId,
    required String expenseDate,
  }) async {
    try {
      final list = await _api.listExpenses(groupId: groupId);
      final titleNorm = title.trim().toLowerCase();
      ExpenseModel? best;
      for (final e in list) {
        if (e.title.trim().toLowerCase() != titleNorm) continue;
        if ((e.amount - amount).abs() > 0.05) continue;
        final date = e.expenseDate.length >= 10
            ? e.expenseDate.substring(0, 10)
            : e.expenseDate;
        final want = expenseDate.length >= 10
            ? expenseDate.substring(0, 10)
            : expenseDate;
        if (date != want) continue;
        if (best == null || e.id > best.id) best = e;
      }
      return best;
    } catch (_) {
      return null;
    }
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

    // 1) On-device OCR — this is what actually fills fields today
    // (server /scan-receipt is often empty/stub).
    ScanReceiptResult local = const ScanReceiptResult();
    try {
      local = await ReceiptOcrService.instance.scanFile(filePath);
    } catch (e) {
      debugPrint('Receipt on-device OCR failed: $e');
    }

    final localOk = _scanHasData(local);
    ScanReceiptResult remote = const ScanReceiptResult();
    // 2) Server only as backup when local found nothing (avoid long wait).
    if (!localOk) {
      try {
        remote = await _api.scanReceipt(filePath: filePath, fileName: fileName);
      } catch (e) {
        debugPrint('Receipt API scan failed (non-fatal): $e');
      }
    }

    return _mergeScanResults(local, remote);
  }

  bool _scanHasData(ScanReceiptResult r) {
    final title = r.title?.trim() ?? r.merchantName?.trim() ?? '';
    return title.isNotEmpty ||
        r.amount != null ||
        (r.expenseDate?.trim().isNotEmpty == true) ||
        r.items.isNotEmpty;
  }

  /// Prefer whichever side has actual values; local OCR first for reliability.
  ScanReceiptResult _mergeScanResults(
    ScanReceiptResult local,
    ScanReceiptResult remote,
  ) {
    final title = _nonEmpty(local.title) ??
        _nonEmpty(local.merchantName) ??
        _nonEmpty(remote.title) ??
        _nonEmpty(remote.merchantName);
    final merchant =
        _nonEmpty(local.merchantName) ?? _nonEmpty(remote.merchantName);
    final amount = local.amount ?? remote.amount;
    final date = _nonEmpty(local.expenseDate) ?? _nonEmpty(remote.expenseDate);
    final currency = _nonEmpty(local.currency) ?? _nonEmpty(remote.currency);
    final items = local.items.isNotEmpty ? local.items : remote.items;

    return ScanReceiptResult(
      title: title,
      merchantName: merchant,
      amount: amount,
      expenseDate: date,
      currency: currency,
      items: items,
      raw: {
        if (local.raw != null) 'local': local.raw,
        if (remote.raw != null) 'remote': remote.raw,
      },
    );
  }

  String? _nonEmpty(String? s) {
    if (s == null) return null;
    final t = s.trim();
    return t.isEmpty ? null : t;
  }
}
