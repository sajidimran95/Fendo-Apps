import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/mock_data.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/app_widgets.dart';

class GroupDetailScreen extends StatelessWidget {
  const GroupDetailScreen({super.key, required this.group});

  final MockGroup group;

  @override
  Widget build(BuildContext context) {
    final expenses =
        MockData.expenses.where((e) => e.groupName == group.name).toList();

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: ListView(
          children: [
            AppHeader(
              title: group.name,
              subtitle: '${group.type} · ${group.memberCount} members',
              onBack: () => Navigator.pop(context),
            ),
            SoftTile(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your balance in this group',
                    style: GoogleFonts.manrope(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 6),
                  MoneyText(
                    group.netBalance,
                    positive: group.netBalance >= 0,
                    size: 28,
                  ),
                ],
              ),
            ),
            SectionLabel(
              'Members',
              actionLabel: 'Invite',
              onAction: () => showStaticSnack(context, 'Invite (static)'),
            ),
            SoftTile(
              child: Wrap(
                spacing: 10,
                children: ['Alex', 'Sam', 'Maya', 'Jordan']
                    .take(group.memberCount)
                    .map(
                      (n) => Chip(
                        avatar: CircleAvatar(
                          backgroundColor: AppColors.mintWash,
                          child: Text(n[0]),
                        ),
                        label: Text(n),
                      ),
                    )
                    .toList(),
              ),
            ),
            const SectionLabel('Expenses'),
            if (expenses.isEmpty)
              const EmptyHint(message: 'No expenses in this group yet')
            else
              ...expenses.map(
                (e) => SoftTile(
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              e.title,
                              style: GoogleFonts.manrope(
                                fontWeight: FontWeight.w700,
                                color: AppColors.forest,
                              ),
                            ),
                            Text(
                              'Paid by ${e.paidBy} · ${e.date}',
                              style: GoogleFonts.manrope(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      MoneyText(e.amount, positive: false, size: 16),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
