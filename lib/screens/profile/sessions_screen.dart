import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/network/api_exception.dart';
import '../../models/user_session.dart';
import '../../services/auth_controller.dart';
import '../../theme/app_colors.dart';
import '../../utils/api_feedback.dart';
import '../../widgets/common/app_widgets.dart';

class SessionsScreen extends StatefulWidget {
  const SessionsScreen({super.key});

  @override
  State<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends State<SessionsScreen> {
  bool _loading = true;
  List<UserSession> _sessions = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await AuthController.instance.userApi.getSessions();
      if (!mounted) return;
      setState(() => _sessions = list);
    } on ApiException catch (e) {
      if (!mounted) return;
      showApiError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _revoke(UserSession session) async {
    if (session.isCurrent) {
      showApiError(
        context,
        ApiException(message: 'You cannot revoke the current session here'),
      );
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Revoke session?'),
        content: Text('Sign out “${session.name}”?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Revoke'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await AuthController.instance.userApi.revokeSession(session.id);
      if (!mounted) return;
      showApiMessage(context, 'Session revoked');
      _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      showApiError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: Column(
          children: [
            AppHeader(
              title: 'Sessions',
              subtitle: 'Devices signed in to Fendo',
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
                      child: _sessions.isEmpty
                          ? ListView(
                              children: const [
                                EmptyHint(message: 'No active sessions found'),
                              ],
                            )
                          : ListView.builder(
                              itemCount: _sessions.length,
                              itemBuilder: (context, i) {
                                final s = _sessions[i];
                                return SoftTile(
                                  onTap: s.isCurrent ? null : () => _revoke(s),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.devices_rounded,
                                        color: s.isCurrent
                                            ? AppColors.mint
                                            : AppColors.forest,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Flexible(
                                                  child: Text(
                                                    s.name,
                                                    style: GoogleFonts.manrope(
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: AppColors.forest,
                                                    ),
                                                  ),
                                                ),
                                                if (s.isCurrent) ...[
                                                  const SizedBox(width: 8),
                                                  const StatusChip('Current'),
                                                ],
                                              ],
                                            ),
                                            if (s.lastUsed != null)
                                              Text(
                                                'Last used: ${s.lastUsed}',
                                                style: GoogleFonts.manrope(
                                                  fontSize: 12,
                                                  color:
                                                      AppColors.textSecondary,
                                                ),
                                              ),
                                            if (s.createdAt != null)
                                              Text(
                                                'Created: ${s.createdAt}',
                                                style: GoogleFonts.manrope(
                                                  fontSize: 12,
                                                  color: AppColors.textMuted,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      if (!s.isCurrent)
                                        Icon(
                                          Icons.close_rounded,
                                          color: AppColors.coral
                                              .withValues(alpha: 0.8),
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
