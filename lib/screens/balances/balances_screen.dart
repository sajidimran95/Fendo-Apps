import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/mock_data.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/app_widgets.dart';

class BalancesScreen extends StatelessWidget {
  const BalancesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: ListView(
          children: [
            AppHeader(
              title: 'Balances',
              subtitle: 'Who owes whom',
              onBack: () => Navigator.pop(context),
            ),
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
                        MoneyText(MockData.netBalance, positive: true, size: 28),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Owe ${MockData.totalYouOwe}',
                        style: GoogleFonts.manrope(
                          color: AppColors.coral,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Owed ${MockData.totalYouAreOwed}',
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
            const SectionLabel('You owe'),
            ...MockData.youOwe.map(
              (r) => SoftTile(
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppColors.mintWash,
                      child: Text(r.name[0]),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r.name,
                            style: GoogleFonts.manrope(
                              fontWeight: FontWeight.w700,
                              color: AppColors.forest,
                            ),
                          ),
                          Text(
                            r.groupName,
                            style: GoogleFonts.manrope(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    MoneyText(r.amount, positive: false, size: 16),
                  ],
                ),
              ),
            ),
            const SectionLabel('You are owed'),
            ...MockData.youAreOwed.map(
              (r) => SoftTile(
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppColors.mintWash,
                      child: Text(r.name[0]),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r.name,
                            style: GoogleFonts.manrope(
                              fontWeight: FontWeight.w700,
                              color: AppColors.forest,
                            ),
                          ),
                          Text(
                            r.groupName,
                            style: GoogleFonts.manrope(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    MoneyText(r.amount, positive: true, size: 16),
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
