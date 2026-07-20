import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/network/api_exception.dart';
import '../../services/groups_controller.dart';
import '../../theme/app_colors.dart';
import '../../utils/api_feedback.dart';
import '../../widgets/auth/auth_widgets.dart';
import '../../widgets/common/app_widgets.dart';

class GroupInviteScreen extends StatefulWidget {
  const GroupInviteScreen({super.key, required this.groupId});

  final int groupId;

  @override
  State<GroupInviteScreen> createState() => _GroupInviteScreenState();
}

class _GroupInviteScreenState extends State<GroupInviteScreen> {
  final _emails = TextEditingController();
  bool _sending = false;
  bool _linking = false;
  String? _inviteLink;
  String? _inviteToken;
  String? _expiresAt;

  @override
  void dispose() {
    _emails.dispose();
    super.dispose();
  }

  List<String> get _parsedEmails => _emails.text
      .split(RegExp(r'[,;\s]+'))
      .map((e) => e.trim())
      .where((e) => e.contains('@'))
      .toList();

  Future<void> _sendEmails() async {
    final emails = _parsedEmails;
    if (emails.isEmpty) {
      showApiError(context, ApiException(message: 'Enter at least one email'));
      return;
    }
    setState(() => _sending = true);
    try {
      await GroupsController.instance.inviteByEmail(
        widget.groupId,
        emails: emails,
      );
      if (!mounted) return;
      showApiMessage(context, 'Invites sent');
      _emails.clear();
    } on ApiException catch (e) {
      if (!mounted) return;
      showApiError(context, e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _createLink() async {
    setState(() => _linking = true);
    try {
      final link =
          await GroupsController.instance.createInviteLink(widget.groupId);
      if (!mounted) return;
      setState(() {
        _inviteLink = link.inviteLink;
        _inviteToken = link.inviteToken;
        _expiresAt = link.expiresAt;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      showApiError(context, e);
    } finally {
      if (mounted) setState(() => _linking = false);
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
              title: 'Invite',
              subtitle: 'Email or shareable link',
              onBack: () => Navigator.pop(context),
            ),
            const SectionLabel('Invite by email'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  AuthTextField(
                    controller: _emails,
                    label: 'Emails',
                    hint: 'a@mail.com, b@mail.com',
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),
                  AuthPrimaryButton(
                    label: 'Send invites',
                    loading: _sending,
                    onPressed: _sending ? null : _sendEmails,
                  ),
                ],
              ),
            ),
            const SectionLabel('Invite link'),
            SoftTile(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_inviteLink == null)
                    Text(
                      'Generate a link others can use to join.',
                      style: GoogleFonts.manrope(
                        color: AppColors.textSecondary,
                      ),
                    )
                  else ...[
                    SelectableText(
                      _inviteLink!,
                      style: GoogleFonts.manrope(
                        fontWeight: FontWeight.w600,
                        color: AppColors.forest,
                      ),
                    ),
                    if (_inviteToken != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Token: $_inviteToken',
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                    if (_expiresAt != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Expires: $_expiresAt',
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(text: _inviteLink!),
                        );
                        if (!context.mounted) return;
                        showApiMessage(context, 'Link copied');
                      },
                      icon: const Icon(Icons.copy_rounded),
                      label: const Text('Copy link'),
                    ),
                  ],
                  const SizedBox(height: 8),
                  AuthPrimaryButton(
                    label: _inviteLink == null
                        ? 'Create invite link'
                        : 'Refresh link',
                    loading: _linking,
                    onPressed: _linking ? null : _createLink,
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
