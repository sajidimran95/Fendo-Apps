import '../models/bill_model.dart';
import '../models/expense_model.dart';
import '../models/report_model.dart';

/// Helpers to treat bill payments as spending (backend reports are expense-only).
class SpendingTotals {
  SpendingTotals._();

  static const billsCategoryLabel = 'Bills';

  static double paidAmount(BillModel b) {
    if (b.amountPaid > 0) return b.amountPaid;
    if (b.status == 'paid') return b.amount;
    return 0;
  }

  static DateTime? parseDate(String raw) {
    final dt = DateTime.tryParse(raw);
    if (dt != null) return dt.toLocal();
    if (raw.length >= 10) {
      return DateTime.tryParse(raw.substring(0, 10));
    }
    return null;
  }

  /// Bills with a paid amount whose due date falls in [from]..[to] (inclusive months).
  static List<BillModel> paidInRange(
    Iterable<BillModel> bills, {
    DateTime? from,
    DateTime? to,
    int? groupId,
  }) {
    final fromMonth = from == null ? null : DateTime(from.year, from.month, 1);
    final toMonthEnd =
        to == null ? null : DateTime(to.year, to.month + 1, 0);

    return bills.where((b) {
      final amt = paidAmount(b);
      if (amt <= 0) return false;
      if (groupId != null && b.groupId != groupId) return false;
      if (fromMonth == null && toMonthEnd == null) return true;
      final d = parseDate(b.dueDate);
      if (d == null) return true;
      final due = DateTime(d.year, d.month, d.day);
      if (fromMonth != null && due.isBefore(fromMonth)) return false;
      if (toMonthEnd != null && due.isAfter(toMonthEnd)) return false;
      return true;
    }).toList();
  }

  static double sumPaid(Iterable<BillModel> bills) =>
      bills.fold<double>(0, (s, b) => s + paidAmount(b));

  /// Merge paid bills into a personal report so all spending calcs include them.
  static PersonalReport mergePersonal(
    PersonalReport report,
    List<BillModel> paidBills, {
    List<ReportBucket> byPerson = const [],
  }) {
    final billsTotal = sumPaid(paidBills);
    final billPeople = _billNameBuckets(paidBills);
    final people = _mergeBuckets(
      byPerson.isNotEmpty ? byPerson : report.byPerson,
      billPeople,
    );

    if (billsTotal <= 0 && paidBills.isEmpty && people.isEmpty) {
      return report.copyWith(byPerson: people);
    }

    return PersonalReport(
      totalSpent: report.totalSpent + billsTotal,
      totalOwed: report.totalOwed,
      byCategory: _mergeBuckets(
        report.byCategory,
        _categoryBuckets(paidBills),
      ),
      byMonth: _mergeBuckets(
        report.byMonth,
        _monthBuckets(paidBills),
      ),
      byGroup: _mergeBuckets(
        report.byGroup,
        _groupBuckets(paidBills),
      ),
      byPerson: people,
      balanceTrend: report.balanceTrend,
      from: report.from,
      to: report.to,
    );
  }

  /// Build name-wise totals from expenses (your share per other person).
  static List<ReportBucket> byPersonFromExpenses(
    List<ExpenseModel> expenses, {
    required int meId,
    DateTime? from,
    DateTime? to,
  }) {
    final fromDay =
        from == null ? null : DateTime(from.year, from.month, from.day);
    final toDay = to == null ? null : DateTime(to.year, to.month, to.day);
    final map = <String, double>{};

    for (final e in expenses) {
      final d = parseDate(e.expenseDate);
      if (d != null) {
        final day = DateTime(d.year, d.month, d.day);
        if (fromDay != null && day.isBefore(fromDay)) continue;
        if (toDay != null && day.isAfter(toDay)) continue;
      }

      final myShare = _myShare(e, meId);
      if (myShare <= 0) continue;

      final others = _otherNames(e, meId);
      if (others.isEmpty) {
        final key = _loanPersonFromTitle(e.title) ??
            (e.title.trim().isNotEmpty ? e.title.trim() : 'Personal');
        map[key] = (map[key] ?? 0) + myShare;
        continue;
      }

      final each = myShare / others.length;
      for (final name in others) {
        map[name] = (map[name] ?? 0) + each;
      }
    }

    final buckets = map.entries
        .map((e) => ReportBucket(label: e.key, amount: e.value))
        .toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));
    return buckets;
  }

  static double _myShare(ExpenseModel e, int meId) {
    var owed = 0.0;
    for (final s in e.participants) {
      if (s.userId == meId) owed += s.amount ?? 0;
    }
    if (owed > 0) return owed;

    var paid = 0.0;
    for (final p in e.payers) {
      if (p.userId == meId) paid += p.amountPaid;
    }
    if (paid > 0) return paid;
    return 0;
  }

  static Set<String> _otherNames(ExpenseModel e, int meId) {
    final names = <String>{};
    void add(int userId, String? name) {
      if (userId == meId) return;
      final n = name?.trim();
      names.add((n != null && n.isNotEmpty) ? n : 'User $userId');
    }

    for (final p in e.participants) {
      add(p.userId, p.name);
    }
    for (final p in e.payers) {
      add(p.userId, p.name);
    }

    final fromTitle = _loanPersonFromTitle(e.title);
    if (fromTitle != null && names.isEmpty) {
      names.add(fromTitle);
    }
    return names;
  }

  static String? _loanPersonFromTitle(String title) {
    final t = title.trim();
    const lent = 'Loan: Lent to ';
    const borrowed = 'Loan: Borrowed from ';
    if (t.startsWith(lent)) return t.substring(lent.length).trim();
    if (t.startsWith(borrowed)) return t.substring(borrowed.length).trim();
    return null;
  }

  static List<ReportBucket> _billNameBuckets(Iterable<BillModel> bills) {
    final map = <String, double>{};
    for (final b in bills) {
      final key = b.name.trim().isNotEmpty ? b.name.trim() : 'Bill';
      map[key] = (map[key] ?? 0) + paidAmount(b);
    }
    return map.entries
        .map((e) => ReportBucket(label: e.key, amount: e.value))
        .toList();
  }

  static GroupReport mergeGroup(
    GroupReport report,
    List<BillModel> paidBills,
  ) {
    final forGroup = paidBills.where((b) => b.groupId == report.groupId);
    final billsTotal = sumPaid(forGroup);
    if (billsTotal <= 0) return report;

    return GroupReport(
      groupId: report.groupId,
      groupName: report.groupName,
      totalSpent: report.totalSpent + billsTotal,
      totalOwed: report.totalOwed,
      byCategory: _mergeBuckets(
        report.byCategory,
        _categoryBuckets(forGroup),
      ),
      byMember: report.byMember,
      byMonth: _mergeBuckets(
        report.byMonth,
        _monthBuckets(forGroup),
      ),
    );
  }

  static List<ReportBucket> _categoryBuckets(Iterable<BillModel> bills) {
    final total = sumPaid(bills);
    if (total <= 0) return const [];
    return [ReportBucket(label: billsCategoryLabel, amount: total)];
  }

  static List<ReportBucket> _groupBuckets(Iterable<BillModel> bills) {
    final map = <String, double>{};
    for (final b in bills) {
      final key = (b.groupName?.trim().isNotEmpty == true)
          ? b.groupName!.trim()
          : 'Group ${b.groupId}';
      map[key] = (map[key] ?? 0) + paidAmount(b);
    }
    return map.entries
        .map((e) => ReportBucket(label: e.key, amount: e.value))
        .toList();
  }

  static List<ReportBucket> _monthBuckets(Iterable<BillModel> bills) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final map = <String, double>{};
    for (final b in bills) {
      final d = parseDate(b.dueDate);
      if (d == null) continue;
      final key = months[d.month - 1];
      map[key] = (map[key] ?? 0) + paidAmount(b);
    }
    return map.entries
        .map((e) => ReportBucket(label: e.key, amount: e.value))
        .toList();
  }

  static List<ReportBucket> _mergeBuckets(
    List<ReportBucket> base,
    List<ReportBucket> extra,
  ) {
    if (extra.isEmpty) return base;
    final map = <String, double>{};
    for (final b in base) {
      map[_norm(b.label)] = (map[_norm(b.label)] ?? 0) + b.amount;
    }
    final labels = <String, String>{
      for (final b in base) _norm(b.label): b.label,
    };
    for (final b in extra) {
      final key = _norm(b.label);
      map[key] = (map[key] ?? 0) + b.amount;
      labels.putIfAbsent(key, () => b.label);
    }
    final merged = map.entries
        .map(
          (e) => ReportBucket(
            label: labels[e.key] ?? e.key,
            amount: e.value,
          ),
        )
        .toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));
    return merged;
  }

  static String _norm(String label) {
    final t = label.trim().toLowerCase();
    final ym = RegExp(r'^(\d{4})-(\d{2})$').firstMatch(t);
    if (ym != null) {
      final m = int.tryParse(ym.group(2)!);
      if (m != null && m >= 1 && m <= 12) {
        const months = [
          'jan',
          'feb',
          'mar',
          'apr',
          'may',
          'jun',
          'jul',
          'aug',
          'sep',
          'oct',
          'nov',
          'dec',
        ];
        return months[m - 1];
      }
    }
    if (t.length >= 3) {
      const months = {
        'january': 'jan',
        'february': 'feb',
        'march': 'mar',
        'april': 'apr',
        'may': 'may',
        'june': 'jun',
        'july': 'jul',
        'august': 'aug',
        'september': 'sep',
        'october': 'oct',
        'november': 'nov',
        'december': 'dec',
      };
      if (months.containsKey(t)) return months[t]!;
    }
    return t;
  }
}
