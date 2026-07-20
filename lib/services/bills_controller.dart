import 'package:flutter/foundation.dart';

import '../core/config/api_config.dart';
import '../core/network/api_exception.dart';
import '../models/bill_model.dart';
import 'auth_controller.dart';
import 'bills_api.dart';
import 'groups_controller.dart';

class BillsController extends ChangeNotifier {
  BillsController._();

  static final BillsController instance = BillsController._();

  BillsApi get _api => AuthController.instance.billsApi;

  final List<BillModel> _bills = [];
  int _nextId = 300;
  bool _seeded = false;

  List<BillModel> get bills => List.unmodifiable(_bills);

  void _seedDemoIfNeeded() {
    if (_seeded) return;
    _seeded = true;
    _bills.addAll([
      const BillModel(
        id: 1,
        name: 'Electricity',
        amount: 150,
        dueDate: '2026-07-22',
        groupId: 2,
        groupName: 'Apartment 4B',
        status: 'due_today',
        reminderDays: [3, 1],
        splits: [
          BillSplit(userId: 1, amountOwed: 50, name: 'You'),
          BillSplit(userId: 2, amountOwed: 50, name: 'Sam'),
          BillSplit(userId: 3, amountOwed: 50, name: 'Maya'),
        ],
      ),
      const BillModel(
        id: 2,
        name: 'Internet',
        amount: 80,
        dueDate: '2026-07-28',
        groupId: 2,
        groupName: 'Apartment 4B',
        status: 'upcoming',
        billType: 'recurring',
        frequency: 'monthly',
        reminderDays: [7],
        splits: [
          BillSplit(userId: 1, amountOwed: 40, name: 'You'),
          BillSplit(userId: 2, amountOwed: 40, name: 'Sam'),
        ],
      ),
      const BillModel(
        id: 3,
        name: 'Rent',
        amount: 2400,
        dueDate: '2026-07-01',
        groupId: 2,
        groupName: 'Apartment 4B',
        status: 'overdue',
        amountPaid: 800,
        billType: 'recurring',
        frequency: 'monthly',
      ),
      const BillModel(
        id: 4,
        name: 'Water',
        amount: 45,
        dueDate: '2026-06-15',
        groupId: 2,
        groupName: 'Apartment 4B',
        status: 'paid',
        amountPaid: 45,
      ),
    ]);
  }

  Future<List<BillModel>> loadBills({String? status}) async {
    if (ApiConfig.demoAuth) {
      _seedDemoIfNeeded();
      var list = List<BillModel>.from(_bills);
      if (status != null && status.isNotEmpty) {
        list = list.where((b) => b.status == status).toList();
      }
      notifyListeners();
      return list;
    }
    final list = await _api.listBills(status: status);
    _bills
      ..clear()
      ..addAll(list);
    notifyListeners();
    return list;
  }

  Future<BillModel> getBill(int id) async {
    if (ApiConfig.demoAuth) {
      _seedDemoIfNeeded();
      return _bills.firstWhere(
        (b) => b.id == id,
        orElse: () => throw ApiException(message: 'Bill not found'),
      );
    }
    return _api.getBill(id);
  }

  Future<BillModel> createBill({
    required String name,
    required double amount,
    required String dueDate,
    required int groupId,
    String? notes,
    List<int> reminderDays = const [],
    List<BillSplit> splits = const [],
    String billType = 'one_time',
    String? frequency,
    String? recurrenceEndDate,
  }) async {
    if (ApiConfig.demoAuth) {
      _seedDemoIfNeeded();
      final gName = GroupsController.instance
              .groupById(groupId)
              ?.name ??
          'Group $groupId';
      final bill = BillModel(
        id: _nextId++,
        name: name,
        amount: amount,
        dueDate: dueDate,
        groupId: groupId,
        groupName: gName,
        notes: notes,
        status: 'upcoming',
        reminderDays: reminderDays,
        splits: splits,
        billType: billType,
        frequency: frequency,
        recurrenceEndDate: recurrenceEndDate,
      );
      _bills.insert(0, bill);
      notifyListeners();
      return bill;
    }
    final bill = await _api.createBill(
      name: name,
      amount: amount,
      dueDate: dueDate,
      groupId: groupId,
      notes: notes,
      reminderDays: reminderDays,
      splits: splits,
      billType: billType,
      frequency: frequency,
      recurrenceEndDate: recurrenceEndDate,
    );
    _bills.insert(0, bill);
    notifyListeners();
    return bill;
  }

  Future<BillModel> updateBill(
    int id, {
    String? name,
    double? amount,
    String? dueDate,
    String? notes,
  }) async {
    if (ApiConfig.demoAuth) {
      final i = _bills.indexWhere((b) => b.id == id);
      if (i < 0) throw ApiException(message: 'Bill not found');
      _bills[i] = _bills[i].copyWith(
        name: name,
        amount: amount,
        dueDate: dueDate,
        notes: notes,
      );
      notifyListeners();
      return _bills[i];
    }
    final bill = await _api.updateBill(
      id,
      name: name,
      amount: amount,
      dueDate: dueDate,
      notes: notes,
    );
    final i = _bills.indexWhere((b) => b.id == id);
    if (i >= 0) _bills[i] = bill;
    notifyListeners();
    return bill;
  }

  Future<void> deleteBill(int id) async {
    if (!ApiConfig.demoAuth) {
      await _api.deleteBill(id);
    }
    _bills.removeWhere((b) => b.id == id);
    notifyListeners();
  }

  Future<BillModel> payBill(int id, {String? paymentMethod}) async {
    if (ApiConfig.demoAuth) {
      final i = _bills.indexWhere((b) => b.id == id);
      if (i < 0) throw ApiException(message: 'Bill not found');
      final b = _bills[i];
      _bills[i] = b.copyWith(
        status: 'paid',
        amountPaid: b.amount,
        paymentMethod: paymentMethod,
      );
      notifyListeners();
      return _bills[i];
    }
    final bill = await _api.payBill(id, paymentMethod: paymentMethod);
    final i = _bills.indexWhere((b) => b.id == id);
    if (i >= 0) _bills[i] = bill;
    notifyListeners();
    return bill;
  }

  Future<BillModel> partialPayBill(
    int id, {
    required double amount,
    String? paymentMethod,
  }) async {
    if (ApiConfig.demoAuth) {
      final i = _bills.indexWhere((b) => b.id == id);
      if (i < 0) throw ApiException(message: 'Bill not found');
      final b = _bills[i];
      final paid = (b.amountPaid + amount).clamp(0.0, b.amount).toDouble();
      _bills[i] = b.copyWith(
        amountPaid: paid,
        status: paid >= b.amount ? 'paid' : 'partial',
        paymentMethod: paymentMethod,
      );
      notifyListeners();
      return _bills[i];
    }
    final bill = await _api.partialPayBill(
      id,
      amount: amount,
      paymentMethod: paymentMethod,
    );
    final i = _bills.indexWhere((b) => b.id == id);
    if (i >= 0) _bills[i] = bill;
    notifyListeners();
    return bill;
  }
}
