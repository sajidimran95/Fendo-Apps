import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/network/api_exception.dart';
import '../../models/group_balances.dart';
import '../../services/groups_controller.dart';
import '../../theme/app_colors.dart';
import '../../utils/api_feedback.dart';
import '../../widgets/common/app_widgets.dart';

class GroupBalancesScreen extends StatefulWidget {
  const GroupBalancesScreen({super.key, required this.groupId});

  final int groupId;

  @override
  State<GroupBalancesScreen> createState() => _GroupBalancesScreenState();
}

class _GroupBalancesScreenState extends State<GroupBalancesScreen> {
  bool _loading = true;
  GroupBalances? _balances;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final bal =
          await GroupsController.instance.getBalances(widget.groupId);
      if (!mounted) return;
      setState(() => _balances = bal);
    } on ApiException catch (e) {
      if (!mounted) return;
      showApiError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = _balances;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: _loading && b == null
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.mint),
              )
            : RefreshIndicator(
                color: AppColors.mint,
                onRefresh: _load,
                child: ListView(
                  children: [
                    AppHeader(
                      title: 'Balances',
                      onBack: () => Navigator.pop(context),
                    ),
                    if (b != null) ...[
                      SoftTile(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Summary',
                              style: GoogleFonts.manrope(
                                fontWeight: FontWeight.w700,
                                color: AppColors.forest,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _RowStat(
                              label: 'You owe',
                              amount: b.summary.youOwe,
                              positive: false,
                            ),
                            const SizedBox(height: 8),
                            _RowStat(
                              label: 'You are owed',
                              amount: b.summary.youAreOwed,
                              positive: true,
                            ),
                            const SizedBox(height: 8),
                            _RowStat(
                              label: 'Net balance',
                              amount: b.summary.netBalance,
                              positive: b.summary.netBalance >= 0,
                            ),
                          ],
                        ),
                      ),
                      if (b.balances.isNotEmpty) ...[
                        const SectionLabel('Balances'),
                        ...b.balances.map(
                          (row) => SoftTile(
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    row.name,
                                    style: GoogleFonts.manrope(
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.forest,
                                    ),
                                  ),
                                ),
                                MoneyText(
                                  row.amount.abs(),
                                  positive: row.amount >= 0,
                                  size: 16,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      if (b.simplified.isNotEmpty) ...[
                        const SectionLabel('Simplified'),
                        ...b.simplified.map(
                          (row) => SoftTile(
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    row.name,
                                    style: GoogleFonts.manrope(
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.forest,
                                    ),
                                  ),
                                ),
                                MoneyText(
                                  row.amount.abs(),
                                  positive: row.amount >= 0,
                                  size: 16,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
              ),
      ),
    );
  }
}

class _RowStat extends StatelessWidget {
  const _RowStat({
    required this.label,
    required this.amount,
    required this.positive,
  });

  final String label;
  final double amount;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.manrope(color: AppColors.textSecondary),
          ),
        ),
        MoneyText(amount, positive: positive, size: 16),
      ],
    );
  }
}
