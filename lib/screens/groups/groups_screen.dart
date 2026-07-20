import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/network/api_exception.dart';
import '../../models/group_model.dart';
import '../../services/groups_controller.dart';
import '../../theme/app_colors.dart';
import '../../utils/api_feedback.dart';
import '../../widgets/common/app_widgets.dart';
import 'create_group_screen.dart';
import 'group_detail_screen.dart';
import 'join_group_screen.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      await GroupsController.instance.loadGroups();
    } on ApiException catch (e) {
      if (mounted) showApiError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: GroupsController.instance,
      builder: (context, _) {
        final groups = GroupsController.instance.groups
            .where((g) => !g.archived)
            .toList();

        return Scaffold(
          backgroundColor: AppColors.canvas,
          floatingActionButton: Transform.scale(
            scale: 0.88,
            alignment: Alignment.bottomRight,
            child: FloatingActionButton.extended(
              heroTag: 'fab_groups',
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CreateGroupScreen()),
                );
                _load();
              },
              backgroundColor: AppColors.mint,
              foregroundColor: Colors.white,
              elevation: 2,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              extendedIconLabelSpacing: 6,
              extendedPadding: const EdgeInsets.symmetric(horizontal: 14),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(
                'New group',
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          body: SafeArea(
            child: RefreshIndicator(
              color: AppColors.mint,
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  AppHeader(
                    title: 'Groups',
                    subtitle: 'Shared trips, rent & friends',
                    trailing: IconButton(
                      tooltip: 'Join with code',
                      onPressed: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const JoinGroupScreen(),
                          ),
                        );
                        _load();
                      },
                      icon: const Icon(Icons.link_rounded),
                      color: AppColors.forest,
                    ),
                  ),
                  if (_loading && groups.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 80),
                      child: Center(
                        child: CircularProgressIndicator(color: AppColors.mint),
                      ),
                    )
                  else if (groups.isEmpty)
                    const EmptyHint(
                      message: 'No groups yet. Create one or join with a link.',
                    )
                  else
                    ...groups.map((g) => _GroupTile(group: g)),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _GroupTile extends StatelessWidget {
  const _GroupTile({required this.group});

  final GroupModel group;

  @override
  Widget build(BuildContext context) {
    final color = Color(group.accentColor);
    return SoftTile(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => GroupDetailScreen(groupId: group.id),
          ),
        );
      },
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
              image: group.photo != null &&
                      group.photo!.startsWith('http')
                  ? DecorationImage(
                      image: NetworkImage(group.photo!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            alignment: Alignment.center,
            child: group.photo != null && group.photo!.startsWith('http')
                ? null
                : Text(
                    group.name.isNotEmpty ? group.name[0].toUpperCase() : '?',
                    style: GoogleFonts.sora(
                      fontWeight: FontWeight.w800,
                      color: color,
                      fontSize: 20,
                    ),
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        group.name,
                        style: GoogleFonts.manrope(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: AppColors.forest,
                        ),
                      ),
                    ),
                    if (group.muted) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.notifications_off_outlined, size: 16),
                    ],
                  ],
                ),
                Text(
                  '${group.type} · ${group.memberCount} members',
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          MoneyText(
            group.netBalance,
            positive: group.netBalance >= 0,
            size: 16,
          ),
        ],
      ),
    );
  }
}
