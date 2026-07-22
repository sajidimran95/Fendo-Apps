import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/network/api_exception.dart';
import '../../models/bill_model.dart';
import '../../models/report_model.dart';
import '../../services/bills_controller.dart';
import '../../services/reports_controller.dart';
import '../../theme/app_colors.dart';
import '../../utils/api_feedback.dart';
import '../../widgets/common/app_widgets.dart';
import 'export_report_screen.dart';
import 'group_report_screen.dart';
import 'report_widgets.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  PersonalReport? _report;
  List<BillModel> _paidBills = const [];
  bool _loading = true;
  DateTime _from = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _to = DateTime.now();

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  DateTime? _parseBillDate(String raw) {
    final dt = DateTime.tryParse(raw);
    if (dt != null) return dt.toLocal();
    if (raw.length >= 10) {
      return DateTime.tryParse(raw.substring(0, 10));
    }
    return null;
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final report = await ReportsController.instance.loadPersonal(
        from: _fmt(_from),
        to: _fmt(_to),
      );
      // Backend personal report is expense-only; bills come from /bills.
      final bills = await BillsController.instance.loadBills(status: 'paid');
      final paid = bills.where((b) {
        final paidAmt = b.amountPaid > 0 ? b.amountPaid : b.amount;
        if (b.status != 'paid' && paidAmt <= 0) return false;
        final d = _parseBillDate(b.dueDate);
        if (d == null) return true;
        // Paid bills may have a due date later in the month than "today".
        final fromMonth = DateTime(_from.year, _from.month, 1);
        final toMonthEnd = DateTime(_to.year, _to.month + 1, 0);
        final due = DateTime(d.year, d.month, d.day);
        return !due.isBefore(fromMonth) && !due.isAfter(toMonthEnd);
      }).toList();

      if (!mounted) return;
      setState(() {
        _report = report;
        _paidBills = paid;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      showApiError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  double get _billsPaidTotal => _paidBills.fold<double>(
        0,
        (s, b) => s + (b.amountPaid > 0 ? b.amountPaid : b.amount),
      );

  List<ReportBucket> get _billsByGroup {
    final map = <String, double>{};
    for (final b in _paidBills) {
      final key = (b.groupName?.trim().isNotEmpty == true)
          ? b.groupName!.trim()
          : 'Group ${b.groupId}';
      final amt = b.amountPaid > 0 ? b.amountPaid : b.amount;
      map[key] = (map[key] ?? 0) + amt;
    }
    final buckets = map.entries
        .map((e) => ReportBucket(label: e.key, amount: e.value))
        .toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));
    return buckets;
  }

  Future<void> _pickFrom() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _from,
      firstDate: DateTime(2020),
      lastDate: _to,
    );
    if (d == null) return;
    setState(() => _from = d);
    await _load();
  }

  Future<void> _pickTo() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _to,
      firstDate: _from,
      lastDate: DateTime(2100),
    );
    if (d == null) return;
    setState(() => _to = d);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final r = _report;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.mint,
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              AppHeader(
                title: 'Reports',
                subtitle: 'Expenses + bills paid',
                onBack: () => Navigator.pop(context),
                trailing: TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ExportReportScreen(),
                      ),
                    );
                  },
                  child: Text(
                    'Export',
                    style: GoogleFonts.manrope(
                      fontWeight: FontWeight.w700,
                      color: AppColors.mint,
                    ),
                  ),
                ),
              ),
              SoftTile(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const GroupReportScreen(),
                    ),
                  );
                },
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.mintWash,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.groups_outlined,
                        color: AppColors.mint,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Group report',
                        style: GoogleFonts.manrope(
                          fontWeight: FontWeight.w700,
                          color: AppColors.forest,
                        ),
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _pickFrom,
                        child: Text('From ${_fmt(_from)}'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _pickTo,
                        child: Text('To ${_fmt(_to)}'),
                      ),
                    ),
                  ],
                ),
              ),
              if (_loading && r == null)
                const Padding(
                  padding: EdgeInsets.all(48),
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.mint),
                  ),
                )
              else if (r == null)
                const EmptyHint(message: 'No report data')
              else ...[
                ReportSummaryTile(
                  totalSpent: r.totalSpent,
                  totalOwed: r.totalOwed,
                  billsPaid: _billsPaidTotal,
                  subtitle: '${r.from ?? _fmt(_from)} → ${r.to ?? _fmt(_to)}',
                ),
                const SectionLabel('Bills paid'),
                if (_paidBills.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    child: Text(
                      'No paid bills in this period',
                      style: GoogleFonts.manrope(color: AppColors.textMuted),
                    ),
                  )
                else ...[
                  ReportBucketList(items: _billsByGroup, positive: false),
                  ..._paidBills.map((b) {
                    final amt = b.amountPaid > 0 ? b.amountPaid : b.amount;
                    return SoftTile(
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  b.name,
                                  style: GoogleFonts.manrope(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.forest,
                                  ),
                                ),
                                Text(
                                  '${b.groupName ?? 'Bill'} · ${b.dueDate.length >= 10 ? b.dueDate.substring(0, 10) : b.dueDate}',
                                  style: GoogleFonts.manrope(
                                    fontSize: 12,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          MoneyText(amt, positive: false, size: 16),
                        ],
                      ),
                    );
                  }),
                ],
                const SectionLabel('Expenses by category'),
                ReportBucketList(items: r.byCategory, positive: false),
                const SectionLabel('Expenses by month'),
                ReportBucketList(items: r.byMonth, positive: false),
                const SectionLabel('Expenses by group'),
                ReportBucketList(items: r.byGroup, positive: false),
                const SectionLabel('Balance trend'),
                ReportBucketList(items: r.balanceTrend, positive: true),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
