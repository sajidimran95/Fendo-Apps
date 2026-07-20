import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/network/api_exception.dart';
import '../../models/group_model.dart';
import '../../services/groups_controller.dart';
import '../../theme/app_colors.dart';
import '../../utils/api_feedback.dart';
import '../../widgets/common/app_widgets.dart';
import 'edit_group_screen.dart';
import 'group_balances_screen.dart';
import 'group_invite_screen.dart';
import 'group_members_screen.dart';
import '../activity/group_activity_screen.dart';

class GroupDetailScreen extends StatefulWidget {
  const GroupDetailScreen({super.key, required this.groupId});

  final int groupId;

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  GroupModel? _group;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final g = await GroupsController.instance.getGroup(widget.groupId);
      if (!mounted) return;
      setState(() => _group = g);
    } on ApiException catch (e) {
      if (!mounted) return;
      showApiError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickPhoto() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (file == null) return;
    if (kIsWeb) {
      if (!mounted) return;
      showApiError(
        context,
        ApiException(message: 'Photo upload on web is not supported yet'),
      );
      return;
    }
    try {
      final g = await GroupsController.instance.uploadPhoto(
        id: widget.groupId,
        filePath: file.path,
        fileName: file.name,
      );
      if (!mounted) return;
      setState(() => _group = g);
      showApiMessage(context, 'Group photo updated');
    } on ApiException catch (e) {
      if (!mounted) return;
      showApiError(context, e);
    }
  }

  Future<void> _toggleMute() async {
    final g = _group;
    if (g == null) return;
    try {
      final updated = await GroupsController.instance.muteNotifications(
        g.id,
        muted: !g.muted,
      );
      if (!mounted) return;
      setState(() => _group = updated);
      showApiMessage(
        context,
        updated.muted ? 'Notifications muted' : 'Notifications unmuted',
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      showApiError(context, e);
    }
  }

  Future<void> _archive(bool archive) async {
    try {
      final g = await GroupsController.instance.archiveGroup(
        widget.groupId,
        archive: archive,
      );
      if (!mounted) return;
      setState(() => _group = g);
      showApiMessage(context, archive ? 'Group archived' : 'Group restored');
    } on ApiException catch (e) {
      if (!mounted) return;
      showApiError(context, e);
    }
  }

  Future<void> _leave() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave group?'),
        content: const Text('You will no longer see this group.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await GroupsController.instance.leaveGroup(widget.groupId);
      if (!mounted) return;
      Navigator.pop(context);
    } on ApiException catch (e) {
      if (!mounted) return;
      showApiError(context, e);
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete group?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await GroupsController.instance.deleteGroup(widget.groupId);
      if (!mounted) return;
      Navigator.pop(context);
    } on ApiException catch (e) {
      if (!mounted) return;
      showApiError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = _group;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: _loading && g == null
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.mint),
              )
            : g == null
                ? const EmptyHint(message: 'Group not found')
                : RefreshIndicator(
                    color: AppColors.mint,
                    onRefresh: _load,
                    child: ListView(
                      children: [
                        AppHeader(
                          title: g.name,
                          subtitle:
                              '${g.type} · ${g.memberCount} members'
                              '${g.archived ? ' · archived' : ''}',
                          onBack: () => Navigator.pop(context),
                          trailing: PopupMenuButton<String>(
                            onSelected: (v) async {
                              if (v == 'edit') {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => EditGroupScreen(group: g),
                                  ),
                                );
                                _load();
                              } else if (v == 'photo') {
                                await _pickPhoto();
                              } else if (v == 'mute') {
                                await _toggleMute();
                              } else if (v == 'archive') {
                                await _archive(!g.archived);
                              } else if (v == 'leave') {
                                await _leave();
                              } else if (v == 'delete') {
                                await _delete();
                              }
                            },
                            itemBuilder: (_) => [
                              if (g.isAdmin)
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Text('Edit group'),
                                ),
                              if (g.isAdmin)
                                const PopupMenuItem(
                                  value: 'photo',
                                  child: Text('Upload photo'),
                                ),
                              PopupMenuItem(
                                value: 'mute',
                                child: Text(
                                  g.muted
                                      ? 'Unmute notifications'
                                      : 'Mute notifications',
                                ),
                              ),
                              if (g.isAdmin)
                                PopupMenuItem(
                                  value: 'archive',
                                  child: Text(
                                    g.archived ? 'Unarchive' : 'Archive',
                                  ),
                                ),
                              const PopupMenuItem(
                                value: 'leave',
                                child: Text('Leave group'),
                              ),
                              if (g.isAdmin)
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Delete group'),
                                ),
                            ],
                          ),
                        ),
                        SoftTile(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    GroupBalancesScreen(groupId: g.id),
                              ),
                            );
                          },
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
                                g.netBalance,
                                positive: g.netBalance >= 0,
                                size: 28,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'View balances →',
                                style: GoogleFonts.manrope(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.mint,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SoftTile(
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    GroupMembersScreen(groupId: g.id),
                              ),
                            );
                            _load();
                          },
                          child: Row(
                            children: [
                              const Icon(Icons.groups_rounded),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Members',
                                  style: GoogleFonts.manrope(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.forest,
                                  ),
                                ),
                              ),
                              Text(
                                '${g.memberCount}',
                                style: GoogleFonts.manrope(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const Icon(Icons.chevron_right_rounded),
                            ],
                          ),
                        ),
                        SoftTile(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => GroupActivityScreen(
                                  groupId: g.id,
                                  groupName: g.name,
                                ),
                              ),
                            );
                          },
                          child: Row(
                            children: [
                              const Icon(Icons.timeline_rounded),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Activity',
                                  style: GoogleFonts.manrope(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.forest,
                                  ),
                                ),
                              ),
                              const Icon(Icons.chevron_right_rounded),
                            ],
                          ),
                        ),
                        SoftTile(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    GroupInviteScreen(groupId: g.id),
                              ),
                            );
                          },
                          child: Row(
                            children: [
                              const Icon(Icons.person_add_alt_1_rounded),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Invite',
                                  style: GoogleFonts.manrope(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.forest,
                                  ),
                                ),
                              ),
                              const Icon(Icons.chevron_right_rounded),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
      ),
    );
  }
}
