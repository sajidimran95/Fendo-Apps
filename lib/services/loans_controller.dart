import 'package:flutter/foundation.dart';

import '../core/config/api_config.dart';
import '../data/mock_loans.dart';
import '../models/contact_match_model.dart';

/// Local loan ledger (API has no dedicated loans endpoint yet).
class LoansController extends ChangeNotifier {
  LoansController._() {
    _loans = ApiConfig.demoAuth
        ? List<MockLoan>.from(MockLoans.seedLoans)
        : <MockLoan>[];
  }

  static final LoansController instance = LoansController._();

  List<MockLoan> _loans = [];
  int _nextId = 100;

  List<MockLoan> get loans => List.unmodifiable(_loans);

  double get youLent =>
      _loans.where((l) => l.isGive).fold(0.0, (s, l) => s + l.amount);

  double get youBorrowed =>
      _loans.where((l) => !l.isGive).fold(0.0, (s, l) => s + l.amount);

  /// Positive = net you are owed from personal loans; negative = you owe.
  double get netBalance => youLent - youBorrowed;

  int get activeCount => _loans.length;

  List<MockLoan> recent({int limit = 2}) =>
      _loans.take(limit).toList(growable: false);

  MockLoan addLoan({
    required String personName,
    required double amount,
    required LoanDirection direction,
    String currency = 'USD',
    String? note,
    int? counterpartyUserId,
  }) {
    final now = DateTime.now();
    final date =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final loan = MockLoan(
      id: _nextId++,
      personName: personName,
      amount: amount,
      currency: currency,
      direction: direction,
      date: date,
      note: note,
      counterpartyUserId: counterpartyUserId,
    );
    _loans.insert(0, loan);
    notifyListeners();
    return loan;
  }
}
