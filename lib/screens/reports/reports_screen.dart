import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/network/api_exception.dart';
import '../../models/bill_model.dart';
import '../../models/report_model.dart';
import '../../services/bills_controller.dart';
import '../../services/reports_controller.dart';
import '../../services/spending_totals.dart';
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
  PersonalReport? _expenseOnly;
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

  Future<List<BillModel>> _loadBillPayments() async {
    try {
      return await BillsController.instance.loadBills();
    } catch (_) {
      return BillsController.instance.loadBills(status: 'paid');
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final report = await ReportsController.instance.loadPersonal(
        from: _fmt(_from),
        to: _fmt(_to),
      );
      final allBills = await _loadBillPayments();
      final paid = SpendingTotals.paidInRange(
        allBills,
        from: _from,
        to: _to,
      );
      final merged = SpendingTotals.mergePersonal(report, paid);

      if (!mounted) return;
      setState(() {
        _expenseOnly = report;
        _report = merged;
        _paidBills = paid;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      showApiError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  double get _billsPaidTotal => SpendingTotals.sumPaid(_paidBills);

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
                  expensesOnly: _expenseOnly?.totalSpent ?? 0,
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
                else
                  ..._paidBills.map((b) {
                    final amt = SpendingTotals.paidAmount(b);
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
                const SectionLabel('By category'),
                ReportBucketList(items: r.byCategory, positive: false),
                const SectionLabel('By month'),
                ReportBucketList(items: r.byMonth, positive: false),
                const SectionLabel('By group'),
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
