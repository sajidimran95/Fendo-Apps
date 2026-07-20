import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/mock_data.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/app_widgets.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: ListView(
          children: [
            AppHeader(
              title: 'Notifications',
              subtitle: '${MockData.unreadCount} unread',
              onBack: () => Navigator.pop(context),
              trailing: TextButton(
                onPressed: () =>
                    showStaticSnack(context, 'All marked read (static)'),
                child: const Text('Read all'),
              ),
            ),
            ...MockData.notifications.map((n) {
              return SoftTile(
                onTap: () => showStaticSnack(context, 'Opened (static)'),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: AppColors.mint,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            n['title']!,
                            style: GoogleFonts.manrope(
                              fontWeight: FontWeight.w700,
                              color: AppColors.forest,
                            ),
                          ),
                          Text(
                            n['body']!,
                            style: GoogleFonts.manrope(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      n['time']!,
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
