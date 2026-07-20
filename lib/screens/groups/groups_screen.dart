import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/mock_data.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/app_widgets.dart';
import 'create_group_screen.dart';
import 'group_detail_screen.dart';

class GroupsScreen extends StatelessWidget {
  const GroupsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_groups',
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CreateGroupScreen()),
          );
        },
        backgroundColor: AppColors.forest,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: Text(
          'New group',
          style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: ListView(
          children: [
            const AppHeader(
              title: 'Groups',
              subtitle: 'Shared trips, rent & friends',
            ),
            ...MockData.groups.map((g) {
              return SoftTile(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => GroupDetailScreen(group: g),
                    ),
                  );
                },
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Color(g.color).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        g.name[0],
                        style: GoogleFonts.sora(
                          fontWeight: FontWeight.w800,
                          color: Color(g.color),
                          fontSize: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            g.name,
                            style: GoogleFonts.manrope(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: AppColors.forest,
                            ),
                          ),
                          Text(
                            '${g.type} · ${g.memberCount} members',
                            style: GoogleFonts.manrope(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    MoneyText(
                      g.netBalance,
                      positive: g.netBalance >= 0,
                      size: 16,
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}
