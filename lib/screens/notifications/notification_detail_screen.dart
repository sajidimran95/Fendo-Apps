import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/network/api_exception.dart';
import '../../core/utils/format_date.dart';
import '../../models/notification_model.dart';
import '../../services/notifications_controller.dart';
import '../../theme/app_colors.dart';
import '../../utils/api_feedback.dart';
import '../../utils/notification_router.dart';
import '../../widgets/common/app_widgets.dart';

class NotificationDetailScreen extends StatefulWidget {
  const NotificationDetailScreen({super.key, required this.notification});

  final AppNotification notification;

  @override
  State<NotificationDetailScreen> createState() =>
      _NotificationDetailScreenState();
}

class _NotificationDetailScreenState extends State<NotificationDetailScreen> {
  late AppNotification _n;

  @override
  void initState() {
    super.initState();
    _n = widget.notification;
    WidgetsBinding.instance.addPostFrameCallback((_) => _markReadIfNeeded());
  }

  Future<void> _markReadIfNeeded() async {
    if (_n.read) return;
    try {
      final updated =
          await NotificationsController.instance.markRead(_n.id);
      if (!mounted) return;
      setState(
        () => _n = updated.title.isNotEmpty ? updated : _n.copyWith(read: true),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      showApiError(context, e);
    }
  }

  IconData get _icon {
    final t = (_n.type ?? '').toLowerCase();
    if (t.contains('expense')) return Icons.payments_outlined;
    if (t.contains('settlement_request') || t.contains('payment_request')) {
      return Icons.request_page_outlined;
    }
    if (t.contains('bill')) return Icons.receipt_long_outlined;
    if (t.contains('settlement')) return Icons.handshake_outlined;
    if (t.contains('group')) return Icons.groups_outlined;
    return Icons.notifications_outlined;
  }

  String get _typeLabel {
    final t = _n.type;
    if (t == null || t.isEmpty) return 'General';
    return formatDisplayLabel(t);
  }

  String get _fullDate {
    final raw = _n.createdAt;
    if (raw == null || raw.isEmpty) return '—';
    final dt = DateTime.tryParse(raw)?.toLocal();
    if (dt == null) return raw;
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year} · $h:$m';
  }

  String? get _actionLabel {
    final t = (_n.type ?? '').toLowerCase();
    if (t.contains('settlement_request') ||
        t.contains('settlement_requested') ||
        t.contains('payment_request') ||
        (_n.requestId != null && _n.requestId! > 0)) {
      return 'Open settlements & pay';
    }
    if (t.contains('settlement')) return 'View settlements';
    if (t.contains('expense')) return 'View expense';
    if (t.contains('bill') || t.contains('reminder')) return 'View bill';
    if (t.contains('group') || t.contains('member')) return 'Open group';
    if (_n.isActionable) return 'Open related item';
    return null;
  }

  Future<void> _openRelated() async {
    await NotificationRouter.open(
      context,
      notification: _n,
      markRead: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final action = _actionLabel;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: ListView(
          children: [
            AppHeader(
              title: 'Notification',
              subtitle: _n.read ? 'Read' : 'Unread',
              onBack: () => Navigator.pop(context, true),
            ),
            SoftTile(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.mintWash,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(_icon, color: AppColors.mint),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            StatusChip(_typeLabel),
                            const SizedBox(height: 6),
                            Text(
                              _fullDate,
                              style: GoogleFonts.manrope(
                                fontSize: 12,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _n.title,
                    style: GoogleFonts.sora(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.forest,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _n.body,
                    style: GoogleFonts.manrope(
                      fontSize: 15,
                      height: 1.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            SoftTile(
              child: Column(
                children: [
                  _metaRow('Status', _n.read ? 'Read' : 'Unread'),
                  _metaRow('Type', _typeLabel),
                  _metaRow('When', _n.timeAgo.isEmpty ? '—' : _n.timeAgo),
                  if (_n.groupId != null)
                    _metaRow('Group', '#${_n.groupId}'),
                  if (_n.requestId != null)
                    _metaRow('Request', '#${_n.requestId}'),
                  if (_n.expenseId != null)
                    _metaRow('Expense', '#${_n.expenseId}'),
                  if (_n.billId != null) _metaRow('Bill', '#${_n.billId}'),
                  if (_n.settlementId != null)
                    _metaRow('Settlement', '#${_n.settlementId}'),
                ],
              ),
            ),
            if (action != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: FilledButton(
                  onPressed: _openRelated,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.mint,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: Text(action),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Text(
                  'This notification is for viewing only.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _metaRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: GoogleFonts.manrope(
                color: AppColors.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w600,
                color: AppColors.forest,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
