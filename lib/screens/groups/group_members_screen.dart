import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/network/api_exception.dart';
import '../../models/group_member.dart';
import '../../services/auth_controller.dart';
import '../../services/groups_controller.dart';
import '../../theme/app_colors.dart';
import '../../utils/api_feedback.dart';
import '../../widgets/common/app_widgets.dart';

class GroupMembersScreen extends StatefulWidget {
  const GroupMembersScreen({super.key, required this.groupId});

  final int groupId;

  @override
  State<GroupMembersScreen> createState() => _GroupMembersScreenState();
}

class _GroupMembersScreenState extends State<GroupMembersScreen> {
  bool _loading = true;
  List<GroupMember> _members = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list =
          await GroupsController.instance.getMembers(widget.groupId);
      if (!mounted) return;
      setState(() => _members = list);
    } on ApiException catch (e) {
      if (!mounted) return;
      showApiError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _setRole(GroupMember m, String role) async {
    try {
      await GroupsController.instance.updateMemberRole(
        widget.groupId,
        m.userId,
        role: role,
      );
      if (!mounted) return;
      showApiMessage(context, '${m.name} is now $role');
      _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      showApiError(context, e);
    }
  }

  Future<void> _remove(GroupMember m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove member?'),
        content: Text('Remove ${m.name} from this group?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await GroupsController.instance.removeMember(
        widget.groupId,
        m.userId,
      );
      if (!mounted) return;
      showApiMessage(context, 'Member removed');
      _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      showApiError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final myId = AuthController.instance.user?.id;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: Column(
          children: [
            AppHeader(
              title: 'Members',
              onBack: () => Navigator.pop(context),
            ),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.mint),
                    )
                  : RefreshIndicator(
                      color: AppColors.mint,
                      onRefresh: _load,
                      child: _members.isEmpty
                          ? ListView(
                              children: const [
                                EmptyHint(message: 'No members yet'),
                              ],
                            )
                          : ListView.builder(
                              itemCount: _members.length,
                              itemBuilder: (context, i) {
                                final m = _members[i];
                                final isMe = myId != null && m.userId == myId;
                                return SoftTile(
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: AppColors.mintWash,
                                        backgroundImage: m.avatar != null &&
                                                m.avatar!.isNotEmpty
                                            ? NetworkImage(m.avatar!)
                                            : null,
                                        child: m.avatar == null ||
                                                m.avatar!.isEmpty
                                            ? Text(
                                                m.name.isNotEmpty
                                                    ? m.name[0].toUpperCase()
                                                    : '?',
                                                style: GoogleFonts.sora(
                                                  fontWeight: FontWeight.w700,
                                                  color: AppColors.mint,
                                                ),
                                              )
                                            : null,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              isMe ? '${m.name} (you)' : m.name,
                                              style: GoogleFonts.manrope(
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.forest,
                                              ),
                                            ),
                                            Text(
                                              m.email,
                                              style: GoogleFonts.manrope(
                                                fontSize: 12,
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      StatusChip(
                                        m.role,
                                        color: m.isAdmin
                                            ? AppColors.mint
                                            : AppColors.textMuted,
                                      ),
                                      if (!isMe)
                                        PopupMenuButton<String>(
                                          onSelected: (v) {
                                            if (v == 'admin') {
                                              _setRole(m, 'admin');
                                            } else if (v == 'member') {
                                              _setRole(m, 'member');
                                            } else if (v == 'remove') {
                                              _remove(m);
                                            }
                                          },
                                          itemBuilder: (_) => const [
                                            PopupMenuItem(
                                              value: 'admin',
                                              child: Text('Make admin'),
                                            ),
                                            PopupMenuItem(
                                              value: 'member',
                                              child: Text('Make member'),
                                            ),
                                            PopupMenuItem(
                                              value: 'remove',
                                              child: Text('Remove'),
                                            ),
                                          ],
                                        ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
