import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/mock_data.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/app_widgets.dart';

class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key});

  IconData _icon(String type) {
    switch (type) {
      case 'settlement_recorded':
        return Icons.handshake_outlined;
      case 'member_joined':
        return Icons.person_add_alt_1_outlined;
      case 'bill_created':
        return Icons.receipt_long_outlined;
      default:
        return Icons.payments_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: ListView(
          children: [
            const AppHeader(
              title: 'Activity',
              subtitle: 'Everything happening across groups',
            ),
            ...MockData.activity.map((a) {
              return SoftTile(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppColors.mintWash,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(_icon(a.eventType), color: AppColors.mint),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            a.description,
                            style: GoogleFonts.manrope(
                              fontWeight: FontWeight.w700,
                              color: AppColors.forest,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${a.groupName ?? 'Fendo'} · ${a.timeAgo}',
                            style: GoogleFonts.manrope(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (a.amount != null)
                      MoneyText(a.amount!, positive: null, size: 14),
                  ],
                ),
              );
            }),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
