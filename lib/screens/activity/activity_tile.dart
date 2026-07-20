import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/activity_model.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/app_widgets.dart';

class ActivityTile extends StatelessWidget {
  const ActivityTile({super.key, required this.item, this.compact = false});

  final ActivityItem item;
  final bool compact;

  IconData get _icon {
    switch (item.eventType) {
      case 'settlement_recorded':
        return Icons.handshake_outlined;
      case 'member_joined':
        return Icons.person_add_alt_1_outlined;
      case 'bill_created':
        return Icons.receipt_long_outlined;
      case 'expense_added':
        return Icons.payments_outlined;
      default:
        return Icons.notifications_none_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final meta = [
      if (item.groupName != null && item.groupName!.isNotEmpty) item.groupName!,
      if (item.actorName != null && item.actorName!.isNotEmpty) item.actorName!,
      if (item.timeAgo.isNotEmpty) item.timeAgo,
    ].join(' · ');

    return SoftTile(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: compact ? 36 : 42,
            height: compact ? 36 : 42,
            decoration: BoxDecoration(
              color: AppColors.mintWash,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_icon, color: AppColors.mint, size: compact ? 18 : 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.description,
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.w700,
                    color: AppColors.forest,
                    fontSize: compact ? 13 : 14,
                  ),
                ),
                if (meta.isNotEmpty) ...[
                  const SizedBox(height: 4),
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
          if (item.amount != null)
            MoneyText(item.amount!, positive: null, size: compact ? 13 : 14),
        ],
      ),
    );
  }
}
