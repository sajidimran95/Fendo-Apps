import 'package:flutter/foundation.dart';

import '../core/config/api_config.dart';
import '../core/network/api_exception.dart';
import '../models/settlement_model.dart';
import 'auth_controller.dart';
import 'settlements_api.dart';

class SettlementsController extends ChangeNotifier {
  SettlementsController._();

  static final SettlementsController instance = SettlementsController._();

  SettlementsApi get _api => AuthController.instance.settlementsApi;

  final List<SettlementModel> _settlements = [];
  final List<SettlementRequest> _requests = [];
  int _nextSettlementId = 400;
  int _nextRequestId = 500;
  bool _seeded = false;

  List<SettlementModel> get settlements => List.unmodifiable(_settlements);
  List<SettlementRequest> get requests => List.unmodifiable(_requests);

  List<SettlementRequest> get pendingRequests =>
      _requests.where((r) => r.isPending).toList();

  void _seedDemoIfNeeded() {
    if (_seeded) return;
    _seeded = true;
    _settlements.addAll([
      const SettlementModel(
        id: 1,
        payeeId: 2,
        payerId: 1,
        groupId: 1,
        amount: 45,
        paymentMethod: 'venmo',
        settlementDate: '2026-06-11',
        payeeName: 'Sam',
        payerName: 'You',
        groupName: 'Bali Trip',
        notes: 'Dinner split',
      ),
      const SettlementModel(
        id: 2,
        payeeId: 1,
        payerId: 3,
        groupId: 1,
        amount: 30,
        paymentMethod: 'cash',
        settlementDate: '2026-06-09',
        payeeName: 'You',
        payerName: 'Maya',
        groupName: 'Bali Trip',
      ),
    ]);
    _requests.addAll([
      const SettlementRequest(
        id: 1,
        debtorId: 1,
        requesterId: 3,
        groupId: 1,
        amount: 30,
        message: 'Hotel share',
        status: 'pending',
        debtorName: 'You',
        requesterName: 'Maya',
        groupName: 'Bali Trip',
        createdAt: '2026-07-18',
      ),
      const SettlementRequest(
        id: 2,
        debtorId: 2,
        requesterId: 1,
        groupId: 2,
        amount: 20,
        message: 'Groceries',
        status: 'pending',
        debtorName: 'Sam',
        requesterName: 'You',
        groupName: 'Apartment 4B',
        createdAt: '2026-07-19',
      ),
    ]);
  }

  Future<List<SettlementModel>> loadSettlements() async {
    if (ApiConfig.demoAuth) {
      _seedDemoIfNeeded();
      notifyListeners();
      return settlements;
    }
    final list = await _api.listSettlements();
    _settlements
      ..clear()
      ..addAll(list);
    notifyListeners();
    return settlements;
  }

  Future<SettlementModel> getSettlement(int id) async {
    if (ApiConfig.demoAuth) {
      _seedDemoIfNeeded();
      return _settlements.firstWhere(
        (s) => s.id == id,
        orElse: () => throw ApiException(message: 'Settlement not found'),
      );
    }
    return _api.getSettlement(id);
  }

  Future<SettlementModel> createSettlement({
    required int payeeId,
    required int groupId,
    required double amount,
    String currency = 'USD',
    required String paymentMethod,
    String? paymentReference,
    String? notes,
    String? settlementDate,
    String? payeeName,
    String? groupName,
  }) async {
    if (ApiConfig.demoAuth) {
      _seedDemoIfNeeded();
      final me = AuthController.instance.user;
      final settlement = SettlementModel(
        id: _nextSettlementId++,
        payeeId: payeeId,
        payerId: me?.id ?? 1,
        groupId: groupId,
        amount: amount,
        currency: currency,
        paymentMethod: paymentMethod,
        paymentReference: paymentReference,
        notes: notes,
        settlementDate: settlementDate ??
            DateTime.now().toIso8601String().split('T').first,
        payeeName: payeeName,
        payerName: me?.name ?? 'You',
        groupName: groupName,
      );
      _settlements.insert(0, settlement);
      notifyListeners();
      return settlement;
    }
    final settlement = await _api.createSettlement(
      payeeId: payeeId,
      groupId: groupId,
      amount: amount,
      currency: currency,
      paymentMethod: paymentMethod,
      paymentReference: paymentReference,
      notes: notes,
      settlementDate: settlementDate,
    );
    _settlements.insert(0, settlement);
    notifyListeners();
    return settlement;
  }

  Future<List<SettlementRequest>> loadRequests() async {
    if (ApiConfig.demoAuth) {
      _seedDemoIfNeeded();
      notifyListeners();
      return requests;
    }
    final list = await _api.listRequests();
    _requests
      ..clear()
      ..addAll(list);
    notifyListeners();
    return requests;
  }

  Future<SettlementRequest> createRequest({
    required int debtorId,
    required int groupId,
    required double amount,
    String currency = 'USD',
    String? message,
    String? debtorName,
    String? groupName,
  }) async {
    if (ApiConfig.demoAuth) {
      _seedDemoIfNeeded();
      final me = AuthController.instance.user;
      final request = SettlementRequest(
        id: _nextRequestId++,
        debtorId: debtorId,
        requesterId: me?.id ?? 1,
        groupId: groupId,
        amount: amount,
        currency: currency,
        message: message,
        status: 'pending',
        debtorName: debtorName,
        requesterName: me?.name ?? 'You',
        groupName: groupName,
        createdAt: DateTime.now().toIso8601String().split('T').first,
      );
      _requests.insert(0, request);
      notifyListeners();
      return request;
    }
    final request = await _api.createRequest(
      debtorId: debtorId,
      groupId: groupId,
      amount: amount,
      currency: currency,
      message: message,
    );
    _requests.insert(0, request);
    notifyListeners();
    return request;
  }

  Future<SettlementRequest> acceptRequest(
    int id, {
    String? paymentMethod,
    String? paymentReference,
  }) async {
    if (ApiConfig.demoAuth) {
      _seedDemoIfNeeded();
      final i = _requests.indexWhere((r) => r.id == id);
      if (i < 0) throw ApiException(message: 'Request not found');
      final req = _requests[i];
      final updated = req.copyWith(status: 'accepted');
      _requests[i] = updated;

      final me = AuthController.instance.user;
      _settlements.insert(
        0,
        SettlementModel(
          id: _nextSettlementId++,
          payeeId: req.requesterId,
          payerId: me?.id ?? req.debtorId,
          groupId: req.groupId,
          amount: req.amount,
          currency: req.currency,
          paymentMethod: paymentMethod ?? 'other',
          paymentReference: paymentReference,
          notes: req.message,
          settlementDate: DateTime.now().toIso8601String().split('T').first,
          payeeName: req.requesterName,
          payerName: me?.name ?? req.debtorName ?? 'You',
          groupName: req.groupName,
        ),
      );
      notifyListeners();
      return updated;
    }
    final updated = await _api.acceptRequest(
      id,
      paymentMethod: paymentMethod,
      paymentReference: paymentReference,
    );
    final i = _requests.indexWhere((r) => r.id == id);
    if (i >= 0) {
      _requests[i] = updated;
    } else {
      _requests.insert(0, updated);
    }
    notifyListeners();
    return updated;
  }

  Future<SettlementRequest> declineRequest(int id) async {
    if (ApiConfig.demoAuth) {
      _seedDemoIfNeeded();
      final i = _requests.indexWhere((r) => r.id == id);
      if (i < 0) throw ApiException(message: 'Request not found');
      final updated = _requests[i].copyWith(status: 'declined');
      _requests[i] = updated;
      notifyListeners();
      return updated;
    }
    final updated = await _api.declineRequest(id);
    final i = _requests.indexWhere((r) => r.id == id);
    if (i >= 0) {
      _requests[i] = updated;
    } else {
      _requests.insert(0, updated);
    }
    notifyListeners();
    return updated;
  }

  Future<SettlementDeepLink> getDeepLink({
    required int payeeId,
    required double amount,
    String? note,
  }) async {
    if (ApiConfig.demoAuth) {
      final params = <String, String>{
        'payee_id': '$payeeId',
        'amount': amount.toStringAsFixed(2),
        if (note != null && note.isNotEmpty) 'note': note,
      };
      final query = params.entries
          .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
          .join('&');
      return SettlementDeepLink(
        url: 'https://fendo.app/pay?$query',
        payeeId: payeeId,
        amount: amount,
        note: note,
      );
    }
    return _api.getDeepLink(payeeId: payeeId, amount: amount, note: note);
  }
}
