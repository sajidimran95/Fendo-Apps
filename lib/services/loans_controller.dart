import 'package:flutter/foundation.dart';

import '../core/config/api_config.dart';
import '../core/network/api_exception.dart';
import '../data/mock_loans.dart';
import '../models/contact_match_model.dart';
import '../models/expense_model.dart';
import 'auth_controller.dart';
import 'expenses_api.dart';

/// Personal loans saved as expenses titled with [loanPrefix].
///
/// Stored as personal (no group) solo-split expenses so the server debt ledger
/// is not touched — multi-user expense creates currently 500 on this API.
class LoansController extends ChangeNotifier {
  LoansController._() {
    if (ApiConfig.demoAuth) {
      _loans = List<MockLoan>.from(MockLoans.seedLoans);
    }
  }

  static final LoansController instance = LoansController._();

  static const loanPrefix = 'Loan:';
  static const lentPrefix = 'Loan: Lent to ';
  static const borrowedPrefix = 'Loan: Borrowed from ';
  static const _uidTag = 'fendo_uid:';

  ExpensesApi get _expensesApi => AuthController.instance.expensesApi;

  List<MockLoan> _loans = [];
  int _nextId = 100;
  bool _loading = false;
  bool _loaded = false;

  List<MockLoan> get loans => List.unmodifiable(_loans);
  bool get loading => _loading;
  bool get loaded => _loaded;

  double get youLent =>
      _loans.where((l) => l.isGive).fold(0.0, (s, l) => s + l.amount);

  double get youBorrowed =>
      _loans.where((l) => !l.isGive).fold(0.0, (s, l) => s + l.amount);

  /// Positive = net you are owed from personal loans; negative = you owe.
  double get netBalance => youLent - youBorrowed;

  int get activeCount => _loans.length;

  List<MockLoan> recent({int limit = 2}) =>
      _loans.take(limit).toList(growable: false);

  Future<void> load({bool force = false}) async {
    if (ApiConfig.demoAuth) {
      if (!_loaded) {
        _loans = List<MockLoan>.from(MockLoans.seedLoans);
        _loaded = true;
        notifyListeners();
      }
      return;
    }
    if (_loading) return;
    if (_loaded && !force) return;

    _loading = true;
    notifyListeners();
    try {
      final meId = AuthController.instance.user?.id;
      final expenses = await _expensesApi.listExpenses();
      _loans = expenses
          .where((e) => e.title.trim().toLowerCase().startsWith('loan:'))
          .map((e) => _fromExpense(e, meId))
          .toList();
      _loaded = true;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Creates a loan on the server (or local demo). Counterparty must be On Fendo.
  Future<MockLoan> createLoan({
    required String personName,
    required double amount,
    required LoanDirection direction,
    String currency = 'USD',
    String? note,
    required int counterpartyUserId,
    String? counterpartyEmail,
  }) async {
    final trimmedNote = note?.trim();
    final noteOrNull =
        (trimmedNote == null || trimmedNote.isEmpty) ? null : trimmedNote;

    if (ApiConfig.demoAuth) {
      return addLoan(
        personName: personName,
        amount: amount,
        direction: direction,
        currency: currency,
        note: noteOrNull,
        counterpartyUserId: counterpartyUserId,
      );
    }

    final me = AuthController.instance.user;
    final meId = me?.id;
    if (meId == null) {
      throw ApiException(message: 'Sign in to save loans');
    }
    if (counterpartyUserId == meId) {
      throw ApiException(message: 'Pick someone else for this loan');
    }

    final currencyCode = currency.trim().isEmpty
        ? ((me?.currency.trim().isNotEmpty == true) ? me!.currency : 'USD')
        : currency;
    final now = DateTime.now();
    final date =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    final title = direction == LoanDirection.give
        ? '$lentPrefix$personName'
        : '$borrowedPrefix$personName';

    // Solo personal expense — avoids broken multi-user DebtService updates.
    final expense = await _expensesApi.createExpense(
      title: title,
      amount: amount,
      currency: currencyCode,
      expenseDate: date,
      merchantName: _encodeMeta(
        counterpartyUserId: counterpartyUserId,
        note: noteOrNull,
      ),
      splitMethod: 'equal',
      payers: [ExpensePayer(userId: meId, amountPaid: amount)],
      participants: [ExpenseParticipant(userId: meId)],
    );

    final loan = _fromExpense(expense, meId).copyWith(
      personName: personName,
      note: noteOrNull,
      counterpartyUserId: counterpartyUserId,
      direction: direction,
      amount: amount,
    );
    _loans.insert(0, loan);
    _loaded = true;
    notifyListeners();
    return loan;
  }

  /// Local-only add (demo). Prefer [createLoan] for live API.
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

  String _encodeMeta({required int counterpartyUserId, String? note}) {
    final base = '$_uidTag$counterpartyUserId';
    if (note == null || note.isEmpty) return base;
    return '$base|$note';
  }

  ({int? userId, String? note}) _decodeMeta(String? raw) {
    if (raw == null || raw.isEmpty) {
      return (userId: null, note: null);
    }
    if (!raw.startsWith(_uidTag)) {
      return (userId: null, note: raw);
    }
    final rest = raw.substring(_uidTag.length);
    final pipe = rest.indexOf('|');
    if (pipe < 0) {
      return (userId: int.tryParse(rest.trim()), note: null);
    }
    return (
      userId: int.tryParse(rest.substring(0, pipe).trim()),
      note: rest.substring(pipe + 1).trim().isEmpty
          ? null
          : rest.substring(pipe + 1).trim(),
    );
  }

  MockLoan _fromExpense(ExpenseModel e, int? meId) {
    final title = e.title.trim();
    final titleLower = title.toLowerCase();
    final titledGive = titleLower.contains('lent to');
    final titledTake = titleLower.contains('borrowed from');

    final meta = _decodeMeta(e.merchantName);
    final isGive = titledGive
        ? true
        : titledTake
            ? false
            : true;

    // Older multi-user loan expenses: amount may be 2x with both participants.
    var amount = e.amount;
    if (meId != null &&
        e.participants.length >= 2 &&
        e.participants.any((p) => p.userId == meId) &&
        e.participants.any((p) => p.userId != meId)) {
      amount = e.amount / 2;
    }

    String personName = _nameFromTitle(title, isGive: isGive);
    if (personName.isEmpty) personName = 'Someone';

    int? counterpartyId = meta.userId;
    if (counterpartyId == null && meId != null) {
      counterpartyId = e.participants
          .where((p) => p.userId != meId)
          .map((p) => p.userId)
          .firstOrNull;
      counterpartyId ??= e.payers
          .where((p) => p.userId != meId)
          .map((p) => p.userId)
          .firstOrNull;
    }

    final dateRaw = e.expenseDate;
    final date = dateRaw.length >= 10 ? dateRaw.substring(0, 10) : dateRaw;

    return MockLoan(
      id: e.id,
      personName: personName,
      amount: amount,
      currency: e.currency,
      direction: isGive ? LoanDirection.give : LoanDirection.take,
      date: date,
      note: meta.note,
      counterpartyUserId: counterpartyId,
    );
  }

  String _nameFromTitle(String title, {required bool isGive}) {
    final prefix = isGive ? lentPrefix : borrowedPrefix;
    if (title.startsWith(prefix)) {
      return title.substring(prefix.length).trim();
    }
    if (title.startsWith(loanPrefix)) {
      return title.substring(loanPrefix.length).trim();
    }
    return title;
  }
}

extension on MockLoan {
  MockLoan copyWith({
    String? personName,
    double? amount,
    LoanDirection? direction,
    String? note,
    int? counterpartyUserId,
  }) {
    return MockLoan(
      id: id,
      personName: personName ?? this.personName,
      amount: amount ?? this.amount,
      currency: currency,
      direction: direction ?? this.direction,
      date: date,
      note: note ?? this.note,
      isAppUser: isAppUser,
      counterpartyUserId: counterpartyUserId ?? this.counterpartyUserId,
    );
  }
}
