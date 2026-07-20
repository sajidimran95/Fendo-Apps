import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_colors.dart';
import '../../widgets/common/app_widgets.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final categories = const [
      ('Food & Drink', 180.0, 0xFFF97316),
      ('Transport', 90.0, 0xFF5B8DEF),
      ('Groceries', 89.4, 0xFF00B894),
      ('Entertainment', 22.0, 0xFFF0A500),
    ];

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: ListView(
          children: [
            AppHeader(
              title: 'Reports',
              subtitle: 'Jun 2026 spending',
              onBack: () => Navigator.pop(context),
              trailing: TextButton(
                onPressed: () =>
                    showStaticSnack(context, 'Export CSV (static)'),
                child: const Text('Export'),
              ),
            ),
            SoftTile(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total spent',
                    style: GoogleFonts.manrope(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '\$450',
                    style: GoogleFonts.sora(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      color: AppColors.forest,
                    ),
                  ),
                ],
              ),
            ),
            const SectionLabel('By category'),
            ...categories.map((c) {
              final max = 180.0;
              return SoftTile(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            c.$1,
                            style: GoogleFonts.manrope(
                              fontWeight: FontWeight.w700,
                              color: AppColors.forest,
                            ),
                          ),
                        ),
                        MoneyText(c.$2, positive: false, size: 14),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: c.$2 / max,
                        minHeight: 8,
                        backgroundColor: AppColors.surfaceMuted,
                        color: Color(c.$3),
                      ),
                    ),
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
