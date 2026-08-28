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
import '../../utils/media_url.dart';
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
    final groups = GroupsController.instance.groups
        .where((g) => !g.archived)
        .toList();
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

  Future<void> _pickGroup() async {
    if (_groups.isEmpty) return;
    final chosen = await showModalBottomSheet<GroupModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _GroupPickerSheet(
          groups: _groups,
          selectedId: _group?.id,
        );
      },
    );
    if (chosen == null || !mounted) return;
    if (chosen.id == _group?.id) return;
    setState(() {
      _group = chosen;
      _report = null;
    });
    await _load(chosen);
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
    final g = _group;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.heroWash),
        child: SafeArea(
          child: RefreshIndicator(
            color: AppColors.mint,
            onRefresh: () async {
              final cur = _group;
              if (cur != null) await _load(cur);
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                AppHeader(
                  title: 'Group report',
                  subtitle: 'Spending by category, member & month',
                  onBack: () => Navigator.pop(context),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Group',
                        style: GoogleFonts.manrope(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.forestSoft,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (_groups.isEmpty)
                        _EmptyGroupsCard()
                      else
                        _SelectedGroupCard(
                          group: g,
                          loading: _loading,
                          onTap: _pickGroup,
                        ),
                      if (_groups.length > 1) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 40,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _groups.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(width: 8),
                            itemBuilder: (context, i) {
                              final item = _groups[i];
                              final on = item.id == g?.id;
                              return _GroupChip(
                                label: item.name,
                                selected: on,
                                accent: Color(item.accentColor),
                                onTap: () async {
                                  if (on) return;
                                  setState(() {
                                    _group = item;
                                    _report = null;
                                  });
                                  await _load(item);
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
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
                  if (_loading)
                    const LinearProgressIndicator(
                      minHeight: 2,
                      color: AppColors.mint,
                      backgroundColor: AppColors.mintWash,
                    ),
                  ReportSummaryTile(
                    totalSpent: r.totalSpent,
                    totalOwed: r.totalOwed,
                    expensesOnly: _expensesOnly,
                    billsPaid: _billsPaid,
                    subtitle: r.groupName ?? g?.name,
                  ),
                  const SectionLabel('By category'),
                  ReportBucketList(items: r.byCategory, positive: false),
                  const SectionLabel('By member'),
                  ReportBucketList(items: r.byMember, positive: false),
                  const SectionLabel('By month'),
                  ReportBucketList(items: r.byMonth, positive: false),
                ],
                const SizedBox(height: 28),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyGroupsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.8)),
      ),
      child: Text(
        'Create a group first to see reports.',
        style: GoogleFonts.manrope(
          color: AppColors.coral,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SelectedGroupCard extends StatelessWidget {
  const _SelectedGroupCard({
    required this.group,
    required this.loading,
    required this.onTap,
  });

  final GroupModel? group;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final g = group;
    final accent = Color(g?.accentColor ?? AppColors.mint.toARGB32());
    final name = g?.name ?? 'Select a group';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final meta = g == null
        ? 'Tap to choose'
        : [
            g.type,
            if (g.memberCount > 0)
              '${g.memberCount} ${g.memberCount == 1 ? 'member' : 'members'}',
            g.currency,
          ].where((s) => s.trim().isNotEmpty).join(' · ');
    final photoUrl = resolveMediaUrl(g?.photo);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.85)),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.08),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 5,
                height: 78,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(20),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                  image: photoUrl != null && photoUrl.isNotEmpty
                      ? DecorationImage(
                          image: NetworkImage(photoUrl),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                alignment: Alignment.center,
                child: photoUrl != null && photoUrl.isNotEmpty
                    ? null
                    : Text(
                        initial,
                        style: GoogleFonts.sora(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: accent,
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.sora(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.forest,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (loading)
                const Padding(
                  padding: EdgeInsets.only(right: 16),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.mint,
                    ),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.mintWash,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Change',
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: AppColors.mintDim,
                          ),
                        ),
                        const SizedBox(width: 2),
                        const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 18,
                          color: AppColors.mintDim,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupChip extends StatelessWidget {
  const _GroupChip({
    required this.label,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? accent.withValues(alpha: 0.16) : AppColors.surface,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? accent.withValues(alpha: 0.55)
                  : AppColors.border.withValues(alpha: 0.8),
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              color: selected ? accent : AppColors.forestSoft,
            ),
          ),
        ),
      ),
    );
  }
}

class _GroupPickerSheet extends StatefulWidget {
  const _GroupPickerSheet({
    required this.groups,
    required this.selectedId,
  });

  final List<GroupModel> groups;
  final int? selectedId;

  @override
  State<_GroupPickerSheet> createState() => _GroupPickerSheetState();
}

class _GroupPickerSheetState extends State<_GroupPickerSheet> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<GroupModel> get _filtered {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return widget.groups;
    return widget.groups.where((g) {
      return g.name.toLowerCase().contains(q) ||
          g.type.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final height = MediaQuery.sizeOf(context).height * 0.72;

    return Container(
      height: height,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Choose group',
                  style: GoogleFonts.sora(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.forest,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Reports load for the group you select',
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Search groups',
                    prefixIcon: const Icon(Icons.search_rounded),
                    filled: true,
                    fillColor: AppColors.surfaceMuted,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _filtered.isEmpty
                ? Center(
                    child: Text(
                      'No groups match',
                      style: GoogleFonts.manrope(color: AppColors.textMuted),
                    ),
                  )
                : ListView.separated(
                    padding: EdgeInsets.fromLTRB(16, 4, 16, 16 + bottom),
                    itemCount: _filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final g = _filtered[i];
                      final on = g.id == widget.selectedId;
                      final accent = Color(g.accentColor);
                      final photoUrl = resolveMediaUrl(g.photo);
                      final initial = g.name.isNotEmpty
                          ? g.name[0].toUpperCase()
                          : '?';
                      final meta = [
                        g.type,
                        if (g.memberCount > 0)
                          '${g.memberCount} '
                              '${g.memberCount == 1 ? 'member' : 'members'}',
                      ].join(' · ');

                      return Material(
                        color: on
                            ? accent.withValues(alpha: 0.10)
                            : AppColors.surfaceMuted.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          onTap: () => Navigator.pop(context, g),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: on
                                    ? accent.withValues(alpha: 0.5)
                                    : Colors.transparent,
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: accent.withValues(alpha: 0.16),
                                    borderRadius: BorderRadius.circular(12),
                                    image: photoUrl != null &&
                                            photoUrl.isNotEmpty
                                        ? DecorationImage(
                                            image: NetworkImage(photoUrl),
                                            fit: BoxFit.cover,
                                          )
                                        : null,
                                  ),
                                  alignment: Alignment.center,
                                  child: photoUrl != null &&
                                          photoUrl.isNotEmpty
                                      ? null
                                      : Text(
                                          initial,
                                          style: GoogleFonts.sora(
                                            fontWeight: FontWeight.w700,
                                            color: accent,
                                            fontSize: 18,
                                          ),
                                        ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        g.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.manrope(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 15,
                                          color: AppColors.forest,
                                        ),
                                      ),
                                      if (meta.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          meta,
                                          style: GoogleFonts.manrope(
                                            fontSize: 12,
                                            color: AppColors.textMuted,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                if (on)
                                  Icon(
                                    Icons.check_circle_rounded,
                                    color: accent,
                                    size: 22,
                                  )
                                else
                                  Icon(
                                    Icons.chevron_right_rounded,
                                    color: AppColors.textMuted
                                        .withValues(alpha: 0.6),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
