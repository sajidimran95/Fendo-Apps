import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/network/api_exception.dart';
import '../../services/groups_controller.dart';
import '../../theme/app_colors.dart';
import '../../utils/api_feedback.dart';
import '../../utils/group_invite_link.dart';
import '../../widgets/auth/auth_widgets.dart';
import '../../widgets/common/app_widgets.dart';
import 'group_detail_screen.dart';

class JoinGroupScreen extends StatefulWidget {
  const JoinGroupScreen({super.key, this.initialToken});

  /// Optional token or full link (from paste / deep link).
  final String? initialToken;

  @override
  State<JoinGroupScreen> createState() => _JoinGroupScreenState();
}

class _JoinGroupScreenState extends State<JoinGroupScreen> {
  late final TextEditingController _token;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final seed = widget.initialToken?.trim() ?? '';
    _token = TextEditingController(
      text: seed.isEmpty ? '' : GroupInviteLink.extractToken(seed),
    );
  }

  @override
  void dispose() {
    _token.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final raw = _token.text.trim();
    if (raw.isEmpty) {
      showApiError(context, ApiException(message: 'Enter an invite code'));
      return;
    }

    // Accept full URLs or bare tokens; join is always POST inside the app.
    final cleaned = GroupInviteLink.extractToken(raw);
    if (cleaned.isEmpty) {
      showApiError(context, ApiException(message: 'Invalid invite code'));
      return;
    }

    setState(() => _loading = true);
    try {
      final group = await GroupsController.instance.joinByToken(cleaned);
      if (!mounted) return;
      showApiMessage(context, 'Joined ${group.name}');
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => GroupDetailScreen(groupId: group.id),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      showApiError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            AppHeader(
              title: 'Join group',
              subtitle: 'Paste invite code or share link',
              onBack: () => Navigator.pop(context),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'You must be logged in. Join is done inside Fendo (POST), '
                    'not by opening an API URL in the browser.',
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  AuthTextField(
                    controller: _token,
                    label: 'Invite code / link',
                    hint: 'Paste code or full invite link',
                  ),
                  const SizedBox(height: 24),
                  AuthPrimaryButton(
                    label: 'Join group',
                    loading: _loading,
                    onPressed: _loading ? null : _join,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
