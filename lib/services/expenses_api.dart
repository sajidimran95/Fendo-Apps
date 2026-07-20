import 'package:dio/dio.dart';

import '../core/network/api_client.dart';
import '../core/network/api_exception.dart';
import '../models/expense_model.dart';

/// Expenses endpoints 4.1 – 4.7.
class ExpensesApi {
  ExpensesApi(this._client);

  final ApiClient _client;

  ExpenseModel _parseExpense(dynamic body) {
    final map = unwrapMap(body);
    final expense = map['expense'] ?? map;
    if (expense is! Map) {
      throw ApiException(message: 'Invalid expense response');
    }
    return ExpenseModel.fromJson(Map<String, dynamic>.from(expense));
  }

  /// 4.1 GET /expenses · ?group_id · ?from · ?to
  Future<List<ExpenseModel>> listExpenses({
    int? groupId,
    String? from,
    String? to,
  }) async {
    final res = await _client.get(
      '/expenses',
      queryParameters: {
        if (groupId != null) 'group_id': groupId,
        if (from != null && from.isNotEmpty) 'from': from,
        if (to != null && to.isNotEmpty) 'to': to,
      },
    );
    return unwrapList(res.data, key: 'expenses')
        .map(ExpenseModel.fromJson)
        .toList();
  }

  /// 4.2 POST /expenses
  Future<ExpenseModel> createExpense({
    required String title,
    required double amount,
    required String currency,
    required String expenseDate,
    required int groupId,
    int? categoryId,
    required String splitMethod,
    required List<ExpensePayer> payers,
    required List<ExpenseParticipant> participants,
    List<ExpenseItem> items = const [],
    bool isMultiPayer = false,
    String? merchantName,
  }) async {
    final res = await _client.post(
      '/expenses',
      data: {
        'title': title,
        'amount': amount,
        'currency': currency,
        'expense_date': expenseDate,
        'group_id': groupId,
        if (categoryId != null) 'category_id': categoryId,
        'split_method': splitMethod,
        'payers': payers.map((e) => e.toJson()).toList(),
        'participants': participants.map((e) => e.toJson()).toList(),
        if (items.isNotEmpty) 'items': items.map((e) => e.toJson()).toList(),
        'is_multi_payer': isMultiPayer,
        if (merchantName != null && merchantName.isNotEmpty)
          'merchant_name': merchantName,
      },
    );
    return _parseExpense(res.data);
  }

  /// 4.3 GET /expenses/{id}
  Future<ExpenseModel> getExpense(int id) async {
    final res = await _client.get('/expenses/$id');
    return _parseExpense(res.data);
  }

  /// 4.4 PUT /expenses/{id}
  Future<ExpenseModel> updateExpense(
    int id, {
    String? title,
    int? categoryId,
    String? merchantName,
    double? amount,
    String? expenseDate,
    String? splitMethod,
    List<ExpensePayer>? payers,
    List<ExpenseParticipant>? participants,
    List<ExpenseItem>? items,
    bool? isMultiPayer,
  }) async {
    final res = await _client.put(
      '/expenses/$id',
      data: {
        if (title != null) 'title': title,
        if (categoryId != null) 'category_id': categoryId,
        if (merchantName != null) 'merchant_name': merchantName,
        if (amount != null) 'amount': amount,
        if (expenseDate != null) 'expense_date': expenseDate,
        if (splitMethod != null) 'split_method': splitMethod,
        if (payers != null) 'payers': payers.map((e) => e.toJson()).toList(),
        if (participants != null)
          'participants': participants.map((e) => e.toJson()).toList(),
        if (items != null) 'items': items.map((e) => e.toJson()).toList(),
        if (isMultiPayer != null) 'is_multi_payer': isMultiPayer,
      },
    );
    return _parseExpense(res.data);
  }

  /// 4.5 DELETE /expenses/{id}
  Future<void> deleteExpense(int id) async {
    await _client.delete('/expenses/$id');
  }

  /// 4.6 GET /groups/{id}/expenses
  Future<List<ExpenseModel>> listGroupExpenses(int groupId) async {
    final res = await _client.get('/groups/$groupId/expenses');
    return unwrapList(res.data, key: 'expenses')
        .map(ExpenseModel.fromJson)
        .toList();
  }

  /// 4.7 POST /expenses/scan-receipt
  Future<ScanReceiptResult> scanReceipt({
    required String filePath,
    required String fileName,
  }) async {
    final form = FormData.fromMap({
      'receipt': await MultipartFile.fromFile(filePath, filename: fileName),
    });
    final res =
        await _client.postMultipart('/expenses/scan-receipt', data: form);
    return ScanReceiptResult.fromJson(unwrapMap(res.data));
  }
}
