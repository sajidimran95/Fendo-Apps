import '../models/bill_model.dart';
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
    List<BillModel> paidBills,
  ) {
    final billsTotal = sumPaid(paidBills);
    if (billsTotal <= 0 && paidBills.isEmpty) return report;

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
      balanceTrend: report.balanceTrend,
      from: report.from,
      to: report.to,
    );
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
    // Match "2026-07" style to month short name when possible.
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
