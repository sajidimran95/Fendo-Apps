import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/network/api_exception.dart';
import '../../models/balances_model.dart';
import '../../services/balances_controller.dart';
import '../../theme/app_colors.dart';
import '../../utils/api_feedback.dart';
import '../../widgets/common/app_widgets.dart';

class BalanceBreakdownScreen extends StatefulWidget {
  const BalanceBreakdownScreen({super.key});

  @override
  State<BalanceBreakdownScreen> createState() =>
      _BalanceBreakdownScreenState();
}

class _BalanceBreakdownScreenState extends State<BalanceBreakdownScreen> {
  bool _loading = true;
  BalanceBreakdown? _data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await BalancesController.instance.loadBreakdown();
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
    final people = _data?.people ?? const [];

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: _loading && _data == null
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
                      title: 'Breakdown',
                      subtitle: 'Per-person balances',
                      onBack: () => Navigator.pop(context),
                    ),
                    if (people.isEmpty)
                      const EmptyHint(message: 'No balance breakdown yet')
                    else
                      ...people.map((p) => _PersonCard(person: p)),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
      ),
    );
  }
}

class _PersonCard extends StatelessWidget {
  const _PersonCard({required this.person});

  final BalanceBreakdownPerson person;

  @override
  Widget build(BuildContext context) {
    return SoftTile(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.mintWash,
                backgroundImage:
                    person.avatar != null && person.avatar!.isNotEmpty
                        ? NetworkImage(person.avatar!)
                        : null,
                child: person.avatar == null || person.avatar!.isEmpty
                    ? Text(
                        person.name.isNotEmpty
                            ? person.name[0].toUpperCase()
                            : '?',
                        style: GoogleFonts.sora(
                          fontWeight: FontWeight.w700,
                          color: AppColors.mint,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  person.name,
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: AppColors.forest,
                  ),
                ),
              ),
              MoneyText(
                person.netBalance.abs(),
                positive: person.netBalance >= 0,
                size: 16,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  'You owe \$${person.youOwe.toStringAsFixed(2)}',
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    color: AppColors.coral,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                'Owed \$${person.youAreOwed.toStringAsFixed(2)}',
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  color: AppColors.mint,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          if (person.groups.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...person.groups.map(
              (g) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        g.groupName ?? 'Group',
                        style: GoogleFonts.manrope(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    MoneyText(
                      g.amount.abs(),
                      positive: g.amount >= 0,
                      size: 14,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
