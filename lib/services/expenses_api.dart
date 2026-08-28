import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/network/api_client.dart';
import '../core/network/api_exception.dart';
import '../core/utils/app_currency.dart';
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

  /// Parse any common Laravel / Fendo list envelope.
  List<ExpenseModel> _parseExpenseList(dynamic body) {
    final rows = _extractMaps(
      body,
      keys: const [
        'expenses',
        'data',
        'items',
        'results',
        'records',
      ],
    );
    final out = <ExpenseModel>[];
    for (final row in rows) {
      try {
        final nested = row['expense'];
        if (nested is Map) {
          out.add(
            ExpenseModel.fromJson(Map<String, dynamic>.from(nested)),
          );
        } else {
          out.add(ExpenseModel.fromJson(row));
        }
      } catch (e) {
        debugPrint('Expense parse skip: $e');
      }
    }
    return out;
  }

  static List<Map<String, dynamic>> _extractMaps(
    dynamic body, {
    required List<String> keys,
  }) {
    if (body is String) {
      final t = body.trim();
      if (t.startsWith('{') || t.startsWith('[')) {
        try {
          body = jsonDecode(t);
        } catch (_) {
          return const [];
        }
      } else {
        return const [];
      }
    }

    if (body is List) {
      return body
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }

    if (body is! Map) return const [];
    final map = Map<String, dynamic>.from(body);

    for (final k in keys) {
      final v = map[k];
      if (v is List) {
        return v
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      if (v is Map) {
        final inner = Map<String, dynamic>.from(v);
        if (inner['data'] is List) {
          return (inner['data'] as List)
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
        for (final k2 in keys) {
          if (inner[k2] is List) {
            return (inner[k2] as List)
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList();
          }
        }
      }
    }

    final data = map['data'];
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    if (data is Map) {
      return _extractMaps(data, keys: keys);
    }

    return const [];
  }

  /// 4.1 GET /expenses · ?group_id · ?from · ?to
  Future<List<ExpenseModel>> listExpenses({
    int? groupId,
    String? from,
    String? to,
  }) async {
    if (groupId != null && groupId > 0) {
      try {
        final groupList = await listGroupExpenses(groupId);
        if (groupList.isNotEmpty) {
          return _filterByDate(groupList, from: from, to: to);
        }
      } catch (e) {
        debugPrint('listGroupExpenses failed, fallback GET /expenses: $e');
      }
    }

    final res = await _client.get(
      '/expenses',
      queryParameters: {
        if (groupId != null && groupId > 0) 'group_id': groupId,
        if (from != null && from.isNotEmpty) 'from': from,
        if (to != null && to.isNotEmpty) 'to': to,
      },
    );
    var list = _parseExpenseList(res.data);
    if (list.isEmpty &&
        ((from != null && from.isNotEmpty) || (to != null && to.isNotEmpty))) {
      final res2 = await _client.get(
        '/expenses',
        queryParameters: {
          if (groupId != null && groupId > 0) 'group_id': groupId,
        },
      );
      list = _filterByDate(
        _parseExpenseList(res2.data),
        from: from,
        to: to,
      );
    }
    return list;
  }

  List<ExpenseModel> _filterByDate(
    List<ExpenseModel> input, {
    String? from,
    String? to,
  }) {
    if ((from == null || from.isEmpty) && (to == null || to.isEmpty)) {
      return input;
    }
    return input.where((e) {
      final d = e.expenseDate.length >= 10
          ? e.expenseDate.substring(0, 10)
          : e.expenseDate;
      if (from != null && from.isNotEmpty && d.compareTo(from) < 0) {
        return false;
      }
      if (to != null && to.isNotEmpty && d.compareTo(to) > 0) {
        return false;
      }
      return true;
    }).toList();
  }

  /// Load expenses across groups (fills gaps when global GET is empty).
  Future<List<ExpenseModel>> listExpensesForGroups(
    Iterable<int> groupIds, {
    String? from,
    String? to,
  }) async {
    final byId = <int, ExpenseModel>{};
    for (final id in groupIds) {
      if (id <= 0) continue;
      try {
        final list = await listGroupExpenses(id);
        for (final e in _filterByDate(list, from: from, to: to)) {
          byId[e.id] = e;
        }
      } catch (_) {}
    }
    final all = byId.values.toList()
      ..sort((a, b) => b.expenseDate.compareTo(a.expenseDate));
    return all;
  }

  /// 4.2 POST /expenses — body matches API_DOCS equal / multi-payer examples.
  Future<ExpenseModel> createExpense({
    required String title,
    required double amount,
    required String currency,
    required String expenseDate,
    int? groupId,
    int? categoryId,
    String? merchantName,
    required String splitMethod,
    required List<ExpensePayer> payers,
    required List<ExpenseParticipant> participants,
    List<ExpenseItem> items = const [],
    bool isMultiPayer = false,
  }) async {
    final cleanPayers = payers
        .where((p) => p.userId > 0 && p.amountPaid > 0)
        .map(
          (p) => ExpensePayer(
            userId: p.userId,
            amountPaid: roundMoney(p.amountPaid),
            name: p.name,
          ),
        )
        .toList();
    final cleanParticipants =
        participants.where((p) => p.userId > 0).toList();
    if (cleanPayers.isEmpty) {
      throw ApiException(message: 'Add at least one payer with amount > 0');
    }
    if (cleanParticipants.isEmpty && splitMethod != 'itemized') {
      throw ApiException(message: 'Select at least one participant');
    }

    // Date must be yyyy-MM-dd (API sample). Strip ISO / time tails.
    var date = expenseDate.trim();
    if (date.length >= 10) date = date.substring(0, 10);

    final method = splitMethod.trim().isEmpty ? 'equal' : splitMethod.trim();

    // Build payload exactly like API docs — no extra null fields.
    final payload = <String, dynamic>{
      'title': title.trim(),
      'amount': roundMoney(amount),
      'currency': currency.trim().isEmpty
          ? AppCurrency.profileCode
          : currency.trim().toUpperCase(),
      'expense_date': date,
      if (groupId != null && groupId > 0) 'group_id': groupId,
      // Only send category when set — bad IDs cause server 500 on some builds.
      if (categoryId != null && categoryId > 0) 'category_id': categoryId,
      if (merchantName != null && merchantName.trim().isNotEmpty)
        'merchant_name': merchantName.trim(),
      'split_method': method,
      'payers': cleanPayers
          .map(
            (p) => <String, dynamic>{
              'user_id': p.userId,
              'amount_paid': roundMoney(p.amountPaid),
            },
          )
          .toList(),
      'participants': cleanParticipants.map((p) {
        final row = <String, dynamic>{'user_id': p.userId};
        if (method == 'percentage' && p.percentage != null) {
          row['percentage'] = roundMoney(p.percentage!);
        }
        if (method == 'shares' && p.shares != null) {
          // Integer share counts preferred by some backends.
          final s = p.shares!;
          row['shares'] = s == s.roundToDouble() ? s.round() : s;
        }
        if (method == 'custom' && p.amount != null) {
          row['amount'] = roundMoney(p.amount!);
        }
        return row;
      }).toList(),
    };
    if (items.isNotEmpty && method == 'itemized') {
      payload['items'] = items
          .map(
            (i) => <String, dynamic>{
              'name': i.name,
              'amount': roundMoney(i.amount),
              'assigned_to': i.assignedTo.where((id) => id > 0).toList(),
            },
          )
          .toList();
    }
    // Docs only set this for true multi-payer rows.
    if (cleanPayers.length > 1 || isMultiPayer) {
      payload['is_multi_payer'] = true;
    }

    debugPrint('POST /expenses payload=$payload');

    final res = await _client.post('/expenses', data: payload);
    try {
      return _parseExpense(res.data);
    } catch (e) {
      // Many APIs write the row then fail building JSON; caller recovers.
      debugPrint('createExpense parse failed: $e body=${res.data}');
      throw ApiException(
        message:
            'Expense may have been saved, but the server response was incomplete. Refresh Expenses.',
        statusCode: res.statusCode ?? 201,
      );
    }
  }

  Future<ExpenseModel> getExpense(int id) async {
    final res = await _client.get('/expenses/$id');
    return _parseExpense(res.data);
  }

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
    var date = expenseDate?.trim();
    if (date != null && date.length >= 10) date = date.substring(0, 10);

    final payload = <String, dynamic>{
      if (title != null) 'title': title.trim(),
      if (categoryId != null && categoryId > 0) 'category_id': categoryId,
      if (merchantName != null) 'merchant_name': merchantName.trim(),
      if (amount != null) 'amount': roundMoney(amount),
      if (date != null && date.isNotEmpty) 'expense_date': date,
      'split_method': ?splitMethod,
      if (payers != null)
        'payers': payers
            .where((p) => p.userId > 0 && p.amountPaid > 0)
            .map(
              (p) => <String, dynamic>{
                'user_id': p.userId,
                'amount_paid': roundMoney(p.amountPaid),
              },
            )
            .toList(),
      if (participants != null)
        'participants': participants
            .where((p) => p.userId > 0)
            .map((p) => p.toJson())
            .toList(),
      if (items != null)
        'items': items.map((e) => e.toJson()).toList(),
      'is_multi_payer': ?isMultiPayer,
    };

    final res = await _client.put('/expenses/$id', data: payload);
    try {
      return _parseExpense(res.data);
    } catch (e) {
      debugPrint('updateExpense parse failed: $e body=${res.data}');
      throw ApiException(
        message:
            'Expense may have been updated, but the server response was incomplete. Refresh Expenses.',
        statusCode: res.statusCode ?? 200,
      );
    }
  }

  Future<void> deleteExpense(int id) async {
    await _client.delete('/expenses/$id');
  }

  Future<List<ExpenseModel>> listGroupExpenses(int groupId) async {
    final res = await _client.get('/groups/$groupId/expenses');
    return _parseExpenseList(res.data);
  }

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
