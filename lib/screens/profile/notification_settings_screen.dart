import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/network/api_exception.dart';
import '../../models/notification_settings.dart';
import '../../services/auth_controller.dart';
import '../../theme/app_colors.dart';
import '../../utils/api_feedback.dart';
import '../../widgets/auth/auth_widgets.dart';
import '../../widgets/common/app_widgets.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  bool _loading = true;
  bool _saving = false;
  NotificationSettings _settings = const NotificationSettings();
  late final TextEditingController _quietStart;
  late final TextEditingController _quietEnd;

  @override
  void initState() {
    super.initState();
    _quietStart = TextEditingController();
    _quietEnd = TextEditingController();
    _load();
  }

  @override
  void dispose() {
    _quietStart.dispose();
    _quietEnd.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final s = await AuthController.instance.userApi.getNotificationSettings();
      if (!mounted) return;
      setState(() {
        _settings = s;
        _quietStart.text = s.quietHoursStart ?? '';
        _quietEnd.text = s.quietHoursEnd ?? '';
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      showApiError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final updated = await AuthController.instance.userApi
          .updateNotificationSettings(
        _settings.copyWith(
          quietHoursStart: _quietStart.text.trim().isEmpty
              ? null
              : _quietStart.text.trim(),
          quietHoursEnd:
              _quietEnd.text.trim().isEmpty ? null : _quietEnd.text.trim(),
        ),
      );
      if (!mounted) return;
      setState(() => _settings = updated);
      showApiMessage(context, 'Notification settings saved');
    } on ApiException catch (e) {
      if (!mounted) return;
      showApiError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toggle(NotificationSettings Function(NotificationSettings) update) {
    setState(() => _settings = update(_settings));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.mint),
              )
            : ListView(
                padding: const EdgeInsets.only(bottom: 32),
                children: [
                  AppHeader(
                    title: 'Notifications',
                    subtitle: 'Choose what you want to hear about',
                    onBack: () => Navigator.pop(context),
                  ),
                  _SwitchTile(
                    label: 'All notifications',
                    value: _settings.allEnabled,
                    onChanged: (v) =>
                        _toggle((s) => s.copyWith(allEnabled: v)),
                  ),
                  _SwitchTile(
                    label: 'Expense added',
                    value: _settings.expenseAdded,
                    onChanged: (v) =>
                        _toggle((s) => s.copyWith(expenseAdded: v)),
                  ),
                  _SwitchTile(
                    label: 'Expense edited',
                    value: _settings.expenseEdited,
                    onChanged: (v) =>
                        _toggle((s) => s.copyWith(expenseEdited: v)),
                  ),
                  _SwitchTile(
                    label: 'Settlement received',
                    value: _settings.settlementReceived,
                    onChanged: (v) =>
                        _toggle((s) => s.copyWith(settlementReceived: v)),
                  ),
                  _SwitchTile(
                    label: 'Settlement requested',
                    value: _settings.settlementRequested,
                    onChanged: (v) =>
                        _toggle((s) => s.copyWith(settlementRequested: v)),
                  ),
                  _SwitchTile(
                    label: 'Bill reminder',
                    value: _settings.billReminder,
                    onChanged: (v) =>
                        _toggle((s) => s.copyWith(billReminder: v)),
                  ),
                  _SwitchTile(
                    label: 'Bill overdue',
                    value: _settings.billOverdue,
                    onChanged: (v) =>
                        _toggle((s) => s.copyWith(billOverdue: v)),
                  ),
                  _SwitchTile(
                    label: 'Group invitation',
                    value: _settings.groupInvitation,
                    onChanged: (v) =>
                        _toggle((s) => s.copyWith(groupInvitation: v)),
                  ),
                  _SwitchTile(
                    label: 'Member joined',
                    value: _settings.memberJoined,
                    onChanged: (v) =>
                        _toggle((s) => s.copyWith(memberJoined: v)),
                  ),
                  _SwitchTile(
                    label: 'Weekly summary',
                    value: _settings.weeklySummary,
                    onChanged: (v) =>
                        _toggle((s) => s.copyWith(weeklySummary: v)),
                  ),
                  _SwitchTile(
                    label: 'Email notifications',
                    value: _settings.emailNotifications,
                    onChanged: (v) =>
                        _toggle((s) => s.copyWith(emailNotifications: v)),
                  ),
                  const SectionLabel('Quiet hours'),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Expanded(
                          child: AuthTextField(
                            controller: _quietStart,
                            label: 'Start',
                            hint: '22:00',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AuthTextField(
                            controller: _quietEnd,
                            label: 'End',
                            hint: '07:00',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: AuthPrimaryButton(
                      label: 'Save settings',
                      loading: _saving,
                      onPressed: _saving ? null : _save,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SoftTile(
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w600,
                color: AppColors.forest,
              ),
            ),
          ),
          Switch.adaptive(
            value: value,
            activeThumbColor: AppColors.mint,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
