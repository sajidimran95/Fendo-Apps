import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/mock_data.dart';
import '../../models/contact_match_model.dart';
import '../../services/loans_controller.dart';
import '../../services/notifications_controller.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/app_widgets.dart';
import '../balances/balances_screen.dart';
import '../expenses/create_expense_screen.dart';
import '../expenses/expenses_screen.dart';
import '../loans/create_loan_screen.dart';
import '../loans/loans_screen.dart';
import '../notifications/notifications_screen.dart';
import '../settlements/settlements_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationsController.instance.loadUnreadCount();
    });
  }

  Future<void> _openNotifications() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
    );
    await NotificationsController.instance.loadUnreadCount();
  }

  @override
  Widget build(BuildContext context) {
    final user = MockData.currentUser;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Fendo',
                            style: GoogleFonts.sora(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.mint,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Hi, ${user.name.split(' ').first}',
                            style: GoogleFonts.sora(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: AppColors.forest,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ListenableBuilder(
                      listenable: NotificationsController.instance,
                      builder: (context, _) {
                        final count =
                            NotificationsController.instance.unreadCount;
                        return IconButton(
                          onPressed: _openNotifications,
                          icon: Badge(
                            isLabelVisible: count > 0,
                            label: Text('$count'),
                            child: const Icon(Icons.notifications_outlined),
                          ),
                          color: AppColors.forest,
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SoftTile(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const BalancesScreen()),
                  );
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Net balance',
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    MoneyText(
                      MockData.netBalance,
                      positive: true,
                      size: 34,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _MiniStat(
                            label: 'You owe',
                            value: MockData.totalYouOwe,
                            positive: false,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _MiniStat(
                            label: 'You are owed',
                            value: MockData.totalYouAreOwed,
                            positive: true,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: _QuickAction(
                        icon: Icons.add_rounded,
                        label: 'Expense',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const CreateExpenseScreen(),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _QuickAction(
                        icon: Icons.handshake_outlined,
                        label: 'Settle',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const SettlementsScreen(),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _QuickAction(
                        icon: Icons.volunteer_activism_outlined,
                        label: 'Loan',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const CreateLoanScreen(),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _QuickAction(
                        icon: Icons.account_balance_wallet_outlined,
                        label: 'Balances',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const BalancesScreen(),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SectionLabel(
                'Loans',
                actionLabel: 'See all',
                onAction: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const LoansScreen()),
                  );
                },
              ),
            ),
            SliverToBoxAdapter(
              child: ListenableBuilder(
                listenable: LoansController.instance,
                builder: (context, _) {
                  final loans = LoansController.instance;
                  return SoftTile(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const LoansScreen(),
                        ),
                      );
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _MiniStat(
                                label: 'You lent',
                                value: loans.youLent,
                                positive: true,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _MiniStat(
                                label: 'You borrowed',
                                value: loans.youBorrowed,
                                positive: false,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceMuted,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Text(
                                'Net',
                                style: GoogleFonts.manrope(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const Spacer(),
                              MoneyText(
                                loans.netBalance,
                                positive: loans.netBalance >= 0,
                                size: 16,
                              ),
                            ],
                          ),
                        ),
                        if (loans.recent().isNotEmpty) ...[
                          const SizedBox(height: 14),
                          ...loans.recent().map((l) {
                            final give = l.direction == LoanDirection.give;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundColor: give
                                        ? AppColors.mintWash
                                        : AppColors.coral
                                            .withValues(alpha: 0.12),
                                    child: Icon(
                                      give
                                          ? Icons.north_east_rounded
                                          : Icons.south_west_rounded,
                                      size: 14,
                                      color: give
                                          ? AppColors.mint
                                          : AppColors.coral,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      '${give ? 'Lent to' : 'Borrowed from'} ${l.personName}',
                                      style: GoogleFonts.manrope(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                        color: AppColors.forest,
                                      ),
                                    ),
                                  ),
                                  MoneyText(
                                    l.amount,
                                    positive: give,
                                    size: 14,
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
            SliverToBoxAdapter(
              child: SectionLabel(
                'Quick stats',
                actionLabel: 'All expenses',
                onAction: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ExpensesScreen()),
                  );
                },
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: _StatBox(
                        label: 'Groups',
                        value: '${MockData.groups.length}',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _StatBox(
                        label: 'This month',
                        value:
                            '\$${MockData.expensesThisMonth.toStringAsFixed(0)}',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _StatBox(
                        label: 'Bills due',
                        value: '${MockData.bills.length}',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(
              child: SectionLabel('Upcoming bills'),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) {
                  final b = MockData.bills[i];
                  return SoftTile(
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: AppColors.mintWash,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.receipt_outlined,
                            color: AppColors.mint,
                          ),
                        ),
                        const SizedBox(width: 12),
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
                                '${b.groupName} · Due ${b.dueDate}',
                                style: GoogleFonts.manrope(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        MoneyText(b.amount, positive: false, size: 16),
                      ],
                    ),
                  );
                },
                childCount: MockData.bills.length,
              ),
            ),
            const SliverToBoxAdapter(
              child: SectionLabel('Recent activity'),
            ),
            ...MockData.activity.take(3).map(
              (a) => SliverToBoxAdapter(
                child: SoftTile(
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: AppColors.mintWash,
                        child: Text(
                          a.actorName[0],
                          style: GoogleFonts.sora(
                            fontWeight: FontWeight.w700,
                            color: AppColors.mint,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              a.description,
                              style: GoogleFonts.manrope(
                                fontWeight: FontWeight.w600,
                                color: AppColors.forest,
                              ),
                            ),
                            Text(
                              '${a.groupName ?? ''} · ${a.timeAgo}',
                              style: GoogleFonts.manrope(
                                fontSize: 12,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    required this.positive,
  });

  final String label;
  final double value;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          MoneyText(value, positive: positive, size: 18),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              Icon(icon, color: AppColors.forest),
              const SizedBox(height: 6),
              Text(
                label,
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.forest,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: GoogleFonts.sora(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.forest,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
