import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/network/api_exception.dart';
import '../../models/notification_model.dart';
import '../../services/notifications_controller.dart';
import '../../theme/app_colors.dart';
import '../../utils/api_feedback.dart';
import '../../widgets/common/app_widgets.dart';
import 'notification_detail_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<AppNotification> _items = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final items =
          await NotificationsController.instance.loadNotifications();
      if (!mounted) return;
      setState(() => _items = items);
    } on ApiException catch (e) {
      if (!mounted) return;
      showApiError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openDetail(AppNotification n) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NotificationDetailScreen(notification: n),
      ),
    );
    if (!mounted) return;
    setState(() {
      _items = NotificationsController.instance.items;
    });
  }

  Future<void> _markAllRead() async {
    try {
      await NotificationsController.instance.markAllRead();
      if (!mounted) return;
      setState(() {
        _items = NotificationsController.instance.items;
      });
      showApiMessage(context, 'All marked as read');
    } on ApiException catch (e) {
      if (!mounted) return;
      showApiError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final unread = _items.where((n) => !n.read).length;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.mint,
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              AppHeader(
                title: 'Notifications',
                subtitle: unread == 0 ? 'All caught up' : '$unread unread',
                onBack: () => Navigator.pop(context),
                trailing: unread > 0
                    ? TextButton(
                        onPressed: _markAllRead,
                        child: Text(
                          'Read all',
                          style: GoogleFonts.manrope(
                            fontWeight: FontWeight.w700,
                            color: AppColors.mint,
                          ),
                        ),
                      )
                    : null,
              ),
              if (_loading && _items.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(48),
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.mint),
                  ),
                )
              else if (_items.isEmpty)
                const EmptyHint(message: 'No notifications yet')
              else
                ..._items.map((n) {
                  return SoftTile(
                    onTap: () => _openDetail(n),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: n.read
                                  ? AppColors.border
                                  : AppColors.mint,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                n.title,
                                style: GoogleFonts.manrope(
                                  fontWeight: n.read
                                      ? FontWeight.w600
                                      : FontWeight.w800,
                                  color: AppColors.forest,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                n.body,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.manrope(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (n.timeAgo.isNotEmpty)
                              Text(
                                n.timeAgo,
                                style: GoogleFonts.manrope(
                                  fontSize: 12,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            const SizedBox(height: 8),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: AppColors.textMuted,
                              size: 20,
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
