import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../core/config/api_config.dart';
import '../models/report_model.dart';
import 'auth_controller.dart';
import 'bills_controller.dart';
import 'reports_api.dart';
import 'spending_totals.dart';

class ReportsController extends ChangeNotifier {
  ReportsController._();

  static final ReportsController instance = ReportsController._();

  ReportsApi get _api => AuthController.instance.reportsApi;

  PersonalReport? _personal;
  GroupReport? _group;
  ReportExport? _lastExport;

  PersonalReport? get personal => _personal;
  GroupReport? get group => _group;
  ReportExport? get lastExport => _lastExport;

  PersonalReport _demoPersonal({String? from, String? to}) {
    return PersonalReport(
      totalSpent: 450,
      totalOwed: 85.5,
      from: from ?? '2026-06-01',
      to: to ?? '2026-06-30',
      byCategory: const [
        ReportBucket(label: 'Food & Drink', amount: 180),
        ReportBucket(label: 'Transport', amount: 90),
        ReportBucket(label: 'Groceries', amount: 89.4),
        ReportBucket(label: 'Entertainment', amount: 22),
        ReportBucket(label: 'Utilities', amount: 68.6),
      ],
      byMonth: const [
        ReportBucket(label: 'Apr', amount: 320),
        ReportBucket(label: 'May', amount: 410),
        ReportBucket(label: 'Jun', amount: 450),
      ],
      byGroup: const [
        ReportBucket(label: 'Bali Trip', amount: 210),
        ReportBucket(label: 'Apartment 4B', amount: 180),
        ReportBucket(label: 'Weekend Crew', amount: 60),
      ],
      byPerson: const [
        ReportBucket(label: 'Alice', amount: 120),
        ReportBucket(label: 'Sam', amount: 95),
        ReportBucket(label: 'Maya', amount: 80),
        ReportBucket(label: 'Internet bill', amount: 45),
      ],
      balanceTrend: const [
        ReportBucket(label: 'Apr', amount: 40),
        ReportBucket(label: 'May', amount: 95),
        ReportBucket(label: 'Jun', amount: 124.5),
      ],
    );
  }

  GroupReport _demoGroup(int groupId, {String? groupName}) {
    final name = groupName ??
        (groupId == 2
            ? 'Apartment 4B'
            : groupId == 3
                ? 'Weekend Crew'
                : 'Bali Trip');
    return GroupReport(
      groupId: groupId,
      groupName: name,
      totalSpent: groupId == 2 ? 820 : 640,
      totalOwed: groupId == 2 ? 120 : 45,
      byCategory: const [
        ReportBucket(label: 'Food & Drink', amount: 260),
        ReportBucket(label: 'Lodging', amount: 180),
        ReportBucket(label: 'Transport', amount: 120),
        ReportBucket(label: 'Other', amount: 80),
      ],
      byMember: const [
        ReportBucket(label: 'You', amount: 210),
        ReportBucket(label: 'Sam', amount: 180),
        ReportBucket(label: 'Maya', amount: 150),
      ],
      byMonth: const [
        ReportBucket(label: 'Apr', amount: 180),
        ReportBucket(label: 'May', amount: 220),
        ReportBucket(label: 'Jun', amount: 240),
      ],
    );
  }

  Future<PersonalReport> loadPersonal({String? from, String? to}) async {
    if (ApiConfig.demoAuth) {
      _personal = _demoPersonal(from: from, to: to);
      notifyListeners();
      return _personal!;
    }
    _personal = await _api.personalReport(from: from, to: to);
    notifyListeners();
    return _personal!;
  }

  Future<GroupReport> loadGroup(int groupId, {String? groupName}) async {
    if (ApiConfig.demoAuth) {
      _group = _demoGroup(groupId, groupName: groupName);
      notifyListeners();
      return _group!;
    }
    _group = await _api.groupReport(groupId);
    notifyListeners();
    return _group!;
  }

  /// Personal report with paid bills folded into totals and buckets.
  Future<PersonalReport> loadPersonalWithBills({
    String? from,
    String? to,
  }) async {
    final report = await loadPersonal(from: from, to: to);
    try {
      final bills = await BillsController.instance.loadBills();
      final paid = SpendingTotals.paidInRange(
        bills,
        from: from == null ? null : DateTime.tryParse(from),
        to: to == null ? null : DateTime.tryParse(to),
      );
      final merged = SpendingTotals.mergePersonal(report, paid);
      _personal = merged;
      notifyListeners();
      return merged;
    } catch (_) {
      return report;
    }
  }

  Future<ReportExport> export({String format = 'csv'}) async {
    // Client-merge so exports include bill payments (API export is expense-only).
    final personal = await loadPersonalWithBills(
      from: _personal?.from,
      to: _personal?.to,
    );
    if (format == 'json') {
      final payload = {
        'total_spent': personal.totalSpent,
        'total_owed': personal.totalOwed,
        'from': personal.from,
        'to': personal.to,
        'by_category': personal.byCategory
            .map((e) => {'label': e.label, 'amount': e.amount})
            .toList(),
        'by_month': personal.byMonth
            .map((e) => {'label': e.label, 'amount': e.amount})
            .toList(),
        'by_group': personal.byGroup
            .map((e) => {'label': e.label, 'amount': e.amount})
            .toList(),
        'by_person': personal.byPerson
            .map((e) => {'label': e.label, 'amount': e.amount})
            .toList(),
        'balance_trend': personal.balanceTrend
            .map((e) => {'label': e.label, 'amount': e.amount})
            .toList(),
      };
      _lastExport = ReportExport(
        format: 'json',
        content: const JsonEncoder.withIndent('  ').convert(payload),
        filename: 'fendo-report.json',
      );
    } else {
      final buf = StringBuffer()
        ..writeln('section,label,amount')
        ..writeln('summary,total_spent,${personal.totalSpent}')
        ..writeln('summary,total_owed,${personal.totalOwed}');
      for (final b in personal.byCategory) {
        buf.writeln('by_category,${b.label},${b.amount}');
      }
      for (final b in personal.byMonth) {
        buf.writeln('by_month,${b.label},${b.amount}');
      }
      for (final b in personal.byGroup) {
        buf.writeln('by_group,${b.label},${b.amount}');
      }
      for (final b in personal.byPerson) {
        buf.writeln('by_person,${b.label},${b.amount}');
      }
      for (final b in personal.balanceTrend) {
        buf.writeln('balance_trend,${b.label},${b.amount}');
      }
      _lastExport = ReportExport(
        format: 'csv',
        content: buf.toString(),
        filename: 'fendo-report.csv',
      );
    }
    notifyListeners();
    return _lastExport!;
  }
}
