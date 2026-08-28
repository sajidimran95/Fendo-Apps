import 'package:flutter/foundation.dart';

import '../core/config/api_config.dart';
import '../core/network/api_exception.dart';
import '../data/mock_loans.dart';
import '../models/contact_match_model.dart';
import '../models/expense_model.dart';
import 'auth_controller.dart';
import 'expenses_api.dart';

/// Personal loans are IOUs (assets/liabilities), **not** spending expenses.
///
/// They are stored on the backend as personal expenses with a `Loan:` /
/// `Loan paid:` title so they can be listed/repaid without multi-user API bugs.
/// Spending reports and expense lists should [exclude] those titles.
class LoansController extends ChangeNotifier {
  LoansController._() {
    if (ApiConfig.demoAuth) {
      _loans = List<MockLoan>.from(MockLoans.seedLoans);
    }
  }

  static final LoansController instance = LoansController._();

  static const loanPrefix = 'Loan:';
  static const loanPaidPrefix = 'Loan paid:';
  static const lentPrefix = 'Loan: Lent to ';
  static const borrowedPrefix = 'Loan: Borrowed from ';
  static const lentPaidPrefix = 'Loan paid: Lent to ';
  static const borrowedPaidPrefix = 'Loan paid: Borrowed from ';
  static const _uidTag = 'fendo_uid:';
  static const _phoneTag = 'fendo_phone:';
  static const _emailTag = 'fendo_email:';

  ExpensesApi get _expensesApi => AuthController.instance.expensesApi;

  List<MockLoan> _loans = [];
  int _nextId = 100;
  bool _loading = false;
  bool _loaded = false;

  List<MockLoan> get loans => List.unmodifiable(_loans);
  List<MockLoan> get openLoans =>
      _loans.where((l) => l.isOpen).toList(growable: false);
  List<MockLoan> get paidLoans =>
      _loans.where((l) => l.isPaid).toList(growable: false);

  bool get loading => _loading;
  bool get loaded => _loaded;

  /// Open loans only (paid loans leave the net / “active” totals).
  double get youLent =>
      openLoans.where((l) => l.isGive).fold(0.0, (s, l) => s + l.amount);

  double get youBorrowed =>
      openLoans.where((l) => !l.isGive).fold(0.0, (s, l) => s + l.amount);

  /// Positive = net you are owed from personal loans; negative = you owe.
  double get netBalance => youLent - youBorrowed;

  int get activeCount => openLoans.length;

  List<MockLoan> recent({int limit = 2}) =>
      openLoans.take(limit).toList(growable: false);

  /// Title helpers for loans stored as personal expenses (not real spending).
  static bool isLoanExpenseTitle(String? title) {
    final t = (title ?? '').trim().toLowerCase();
    return t.startsWith('loan:') || t.startsWith('loan paid:');
  }

  static bool isLoanPaidTitle(String? title) {
    final t = (title ?? '').trim().toLowerCase();
    return t.startsWith('loan paid:');
  }

  Future<void> load({bool force = false}) async {
    if (ApiConfig.demoAuth) {
      if (!_loaded || force) {
        // Keep local mutations (paid) when reloading without force.
        if (!_loaded) {
          _loans = List<MockLoan>.from(MockLoans.seedLoans);
        }
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
          .where((e) => isLoanExpenseTitle(e.title))
          .map((e) => _fromExpense(e, meId))
          .toList()
        ..sort((a, b) {
          // Open first, then newest date.
          if (a.isOpen != b.isOpen) return a.isOpen ? -1 : 1;
          return b.date.compareTo(a.date);
        });
      _loaded = true;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Creates a loan IOU (stored as titled expense; **not** weekly spending).
  Future<MockLoan> createLoan({
    required String personName,
    required double amount,
    required LoanDirection direction,
    String currency = 'USD',
    String? note,
    int? counterpartyUserId,
    String? counterpartyEmail,
    String? counterpartyPhone,
    bool isAppUser = true,
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
        isAppUser: isAppUser,
      );
    }

    final me = AuthController.instance.user;
    final meId = me?.id;
    if (meId == null) {
      throw ApiException(message: 'Sign in to save loans');
    }
    if (counterpartyUserId != null && counterpartyUserId == meId) {
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

    // Solo personal expense — storage only; exclude from spend reports.
    final expense = await _expensesApi.createExpense(
      title: title,
      amount: amount,
      currency: currencyCode,
      expenseDate: date,
      merchantName: _encodeMeta(
        counterpartyUserId: counterpartyUserId,
        phone: counterpartyPhone,
        email: counterpartyEmail,
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
      isAppUser: isAppUser,
      status: LoanStatus.open,
    );
    _loans.insert(0, loan);
    _loaded = true;
    notifyListeners();
    return loan;
  }

  /// Mark loan as repaid. Does **not** create a new spending expense.
  Future<MockLoan> markPaid(int loanId) async {
    final i = _loans.indexWhere((l) => l.id == loanId);
    if (i < 0) throw ApiException(message: 'Loan not found');
    final loan = _loans[i];
    if (loan.isPaid) return loan;

    if (ApiConfig.demoAuth) {
      final updated = loan.copyWith(status: LoanStatus.paid);
      _loans[i] = updated;
      notifyListeners();
      return updated;
    }

    final title = loan.isGive
        ? '$lentPaidPrefix${loan.personName}'
        : '$borrowedPaidPrefix${loan.personName}';

    try {
      await _expensesApi.updateExpense(loanId, title: title);
    } on ApiException {
      // If update fails, still try so UI can recover after reload.
      rethrow;
    }

    final updated = loan.copyWith(status: LoanStatus.paid);
    _loans[i] = updated;
    notifyListeners();
    return updated;
  }

  /// Local-only add (demo). Prefer [createLoan] for live API.
  MockLoan addLoan({
    required String personName,
    required double amount,
    required LoanDirection direction,
    String currency = 'USD',
    String? note,
    int? counterpartyUserId,
    bool isAppUser = true,
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
      isAppUser: isAppUser,
      status: LoanStatus.open,
    );
    _loans.insert(0, loan);
    notifyListeners();
    return loan;
  }

  String _encodeMeta({
    int? counterpartyUserId,
    String? phone,
    String? email,
    String? note,
  }) {
    final parts = <String>[];
    if (counterpartyUserId != null && counterpartyUserId > 0) {
      parts.add('$_uidTag$counterpartyUserId');
    } else if (phone != null && phone.trim().isNotEmpty) {
      parts.add('$_phoneTag${phone.trim()}');
    } else if (email != null && email.trim().isNotEmpty) {
      parts.add('$_emailTag${email.trim()}');
    }
    if (note != null && note.isNotEmpty) {
      if (parts.isEmpty) return note;
      return '${parts.join('|')}|$note';
    }
    return parts.join('|');
  }

  ({int? userId, String? note}) _decodeMeta(String? raw) {
    if (raw == null || raw.isEmpty) {
      return (userId: null, note: null);
    }
    if (raw.startsWith(_uidTag)) {
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
    if (raw.startsWith(_phoneTag) || raw.startsWith(_emailTag)) {
      final pipe = raw.indexOf('|');
      if (pipe < 0) return (userId: null, note: null);
      final note = raw.substring(pipe + 1).trim();
      return (userId: null, note: note.isEmpty ? null : note);
    }
    return (userId: null, note: raw);
  }

  MockLoan _fromExpense(ExpenseModel e, int? meId) {
    final title = e.title.trim();
    final titleLower = title.toLowerCase();
    final paid = isLoanPaidTitle(title);
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
      status: paid ? LoanStatus.paid : LoanStatus.open,
    );
  }

  String _nameFromTitle(String title, {required bool isGive}) {
    for (final prefix in [
      if (isGive) lentPaidPrefix else borrowedPaidPrefix,
      if (isGive) lentPrefix else borrowedPrefix,
      loanPaidPrefix,
      loanPrefix,
    ]) {
      if (title.startsWith(prefix)) {
        return title.substring(prefix.length).trim();
      }
    }
    // Strip generic paid/open markers then leftover verb phrases.
    var rest = title;
    if (rest.toLowerCase().startsWith('loan paid:')) {
      rest = rest.substring('Loan paid:'.length).trim();
    } else if (rest.toLowerCase().startsWith('loan:')) {
      rest = rest.substring('Loan:'.length).trim();
    }
    final lower = rest.toLowerCase();
    if (lower.startsWith('lent to ')) {
      return rest.substring('lent to '.length).trim();
    }
    if (lower.startsWith('borrowed from ')) {
      return rest.substring('borrowed from '.length).trim();
    }
    return rest;
  }
}

extension on MockLoan {
  MockLoan copyWith({
    String? personName,
    double? amount,
    LoanDirection? direction,
    String? note,
    int? counterpartyUserId,
    bool? isAppUser,
    LoanStatus? status,
  }) {
    return MockLoan(
      id: id,
      personName: personName ?? this.personName,
      amount: amount ?? this.amount,
      currency: currency,
      direction: direction ?? this.direction,
      date: date,
      note: note ?? this.note,
      isAppUser: isAppUser ?? this.isAppUser,
      counterpartyUserId: counterpartyUserId ?? this.counterpartyUserId,
      status: status ?? this.status,
    );
  }
}
