import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/network/api_exception.dart';
import '../../models/bill_model.dart';
import '../../models/group_model.dart';
import '../../models/report_model.dart';
import '../../services/bills_controller.dart';
import '../../services/groups_controller.dart';
import '../../services/reports_controller.dart';
import '../../services/spending_totals.dart';
import '../../theme/app_colors.dart';
import '../../utils/api_feedback.dart';
import '../../widgets/common/app_widgets.dart';
import 'report_widgets.dart';

class GroupReportScreen extends StatefulWidget {
  const GroupReportScreen({super.key, this.initialGroupId});

  final int? initialGroupId;

  @override
  State<GroupReportScreen> createState() => _GroupReportScreenState();
}

class _GroupReportScreenState extends State<GroupReportScreen> {
  List<GroupModel> _groups = const [];
  GroupModel? _group;
  GroupReport? _report;
  double _expensesOnly = 0;
  double _billsPaid = 0;
  bool _booting = true;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    await GroupsController.instance.loadGroups();
    if (!mounted) return;
    final groups = GroupsController.instance.groups;
    final selected = GroupsController.instance.groupById(widget.initialGroupId) ??
        (groups.isNotEmpty ? groups.first : null);
    setState(() {
      _groups = groups;
      _group = selected;
      _booting = false;
    });
    if (selected != null) await _load(selected);
  }

  Future<void> _load(GroupModel group) async {
    setState(() => _loading = true);
    try {
      final report = await ReportsController.instance.loadGroup(
        group.id,
        groupName: group.name,
      );
      List<BillModel> bills = const [];
      try {
        bills = await BillsController.instance.loadBills();
      } catch (_) {
        bills = await BillsController.instance.loadBills(status: 'paid');
      }
      final paid = SpendingTotals.paidInRange(bills, groupId: group.id);
      final merged = SpendingTotals.mergeGroup(report, paid);
      if (!mounted) return;
      setState(() {
        _expensesOnly = report.totalSpent;
        _billsPaid = SpendingTotals.sumPaid(paid);
        _report = merged;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      showApiError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_booting) {
      return const Scaffold(
        backgroundColor: AppColors.canvas,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.mint),
        ),
      );
    }

    final r = _report;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.mint,
          onRefresh: () async {
            final g = _group;
            if (g != null) await _load(g);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              AppHeader(
                title: 'Group report',
                subtitle: _group?.name,
                onBack: () => Navigator.pop(context),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _groups.isEmpty
                    ? Text(
                        'Create a group first',
                        style: GoogleFonts.manrope(color: AppColors.coral),
                      )
                    : DropdownButtonFormField<int>(
                        key: ValueKey('report-group-${_group?.id}'),
                        initialValue: _group?.id,
                        items: _groups
                            .map(
                              (g) => DropdownMenuItem(
                                value: g.id,
                                child: Text(g.name),
                              ),
                            )
                            .toList(),
                        onChanged: (id) async {
                          if (id == null) return;
                          final g = _groups.firstWhere((e) => e.id == id);
                          setState(() => _group = g);
                          await _load(g);
                        },
                        decoration: const InputDecoration(
                          labelText: 'Group',
                        ),
                      ),
              ),
              const SizedBox(height: 8),
              if (_loading && r == null)
                const Padding(
                  padding: EdgeInsets.all(48),
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.mint),
                  ),
                )
              else if (r == null)
                const EmptyHint(message: 'No group report data')
              else ...[
                ReportSummaryTile(
                  totalSpent: r.totalSpent,
                  totalOwed: r.totalOwed,
                  expensesOnly: _expensesOnly,
                  billsPaid: _billsPaid,
                  subtitle: r.groupName,
                ),
                const SectionLabel('By category'),
                ReportBucketList(items: r.byCategory, positive: false),
                const SectionLabel('By member'),
                ReportBucketList(items: r.byMember, positive: false),
                const SectionLabel('By month'),
                ReportBucketList(items: r.byMonth, positive: false),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
