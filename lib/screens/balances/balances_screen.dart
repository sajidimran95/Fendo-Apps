import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/network/api_exception.dart';
import '../../models/balances_model.dart';
import '../../services/balances_controller.dart';
import '../../theme/app_colors.dart';
import '../../utils/api_feedback.dart';
import '../../widgets/common/app_widgets.dart';
import 'balance_breakdown_screen.dart';

class BalancesScreen extends StatefulWidget {
  const BalancesScreen({super.key});

  @override
  State<BalancesScreen> createState() => _BalancesScreenState();
}

class _BalancesScreenState extends State<BalancesScreen> {
  bool _loading = true;
  OverallBalances? _data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await BalancesController.instance.loadBalances();
      if (!mounted) return;
      setState(() => _data = data);
    } on ApiException catch (e) {
      if (mounted) showApiError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: _loading && d == null
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.mint),
              )
            : RefreshIndicator(
                color: AppColors.mint,
                onRefresh: _load,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    AppHeader(
                      title: 'Balances',
                      subtitle: 'Who owes whom',
                      onBack: () => Navigator.pop(context),
                      trailing: TextButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const BalanceBreakdownScreen(),
                            ),
                          );
                        },
                        child: const Text('Breakdown'),
                      ),
                    ),
                    if (d != null) ...[
                      SoftTile(
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Net',
                                    style: GoogleFonts.manrope(
                                      color: AppColors.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                  MoneyText(
                                    d.netBalance,
                                    positive: d.netBalance >= 0,
                                    size: 28,
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'Owe \$${d.totalYouOwe.toStringAsFixed(2)}',
                                  style: GoogleFonts.manrope(
                                    color: AppColors.coral,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  'Owed \$${d.totalYouAreOwed.toStringAsFixed(2)}',
                                  style: GoogleFonts.manrope(
                                    color: AppColors.mint,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      SoftTile(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const BalanceBreakdownScreen(),
                            ),
                          );
                        },
                        child: Row(
                          children: [
                            const Icon(Icons.people_outline_rounded),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Per-person breakdown',
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
                      const SectionLabel('You owe'),
                      if (d.youOwe.isEmpty)
                        const EmptyHint(message: 'You don’t owe anyone')
                      else
                        ...d.youOwe.map((r) => _BalanceTile(entry: r, owe: true)),
                      const SectionLabel('You are owed'),
                      if (d.youAreOwed.isEmpty)
                        const EmptyHint(message: 'Nobody owes you right now')
                      else
                        ...d.youAreOwed
                            .map((r) => _BalanceTile(entry: r, owe: false)),
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
              ),
      ),
    );
  }
}

class _BalanceTile extends StatelessWidget {
  const _BalanceTile({required this.entry, required this.owe});

  final BalanceEntry entry;
  final bool owe;

  @override
  Widget build(BuildContext context) {
    return SoftTile(
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.mintWash,
            backgroundImage:
                entry.avatar != null && entry.avatar!.isNotEmpty
                    ? NetworkImage(entry.avatar!)
                    : null,
            child: entry.avatar == null || entry.avatar!.isEmpty
                ? Text(
                    entry.name.isNotEmpty ? entry.name[0].toUpperCase() : '?',
                    style: GoogleFonts.sora(
                      fontWeight: FontWeight.w700,
                      color: AppColors.mint,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.name,
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.w700,
                    color: AppColors.forest,
                  ),
                ),
                if (entry.groupName != null)
                  Text(
                    entry.groupName!,
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          MoneyText(entry.amount, positive: !owe, size: 16),
        ],
      ),
    );
  }
}
