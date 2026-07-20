import 'package:flutter/material.dart';

import '../../core/network/api_exception.dart';
import '../../services/groups_controller.dart';
import '../../theme/app_colors.dart';
import '../../utils/api_feedback.dart';
import '../../widgets/auth/auth_widgets.dart';
import '../../widgets/common/app_widgets.dart';
import 'group_detail_screen.dart';

class JoinGroupScreen extends StatefulWidget {
  const JoinGroupScreen({super.key});

  @override
  State<JoinGroupScreen> createState() => _JoinGroupScreenState();
}

class _JoinGroupScreenState extends State<JoinGroupScreen> {
  final _token = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _token.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final token = _token.text.trim();
    if (token.isEmpty) {
      showApiError(context, ApiException(message: 'Enter an invite token'));
      return;
    }

    // Allow pasting full links like .../join/TOKEN
    final cleaned = token.contains('/')
        ? token.split('/').where((p) => p.isNotEmpty).last
        : token;

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
              subtitle: 'Paste invite token or link',
              onBack: () => Navigator.pop(context),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  AuthTextField(
                    controller: _token,
                    label: 'Invite token / link',
                    hint: 'demo-invite-1',
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
