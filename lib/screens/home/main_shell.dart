import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/storage/app_prefs.dart';
import '../../services/activity_controller.dart';
import '../../services/contacts_match_service.dart';
import '../../services/dashboard_controller.dart';
import '../../services/push_notification_service.dart';
import '../../theme/app_colors.dart';
import '../activity/activity_screen.dart';
import '../bills/bills_screen.dart';
import '../groups/groups_screen.dart';
import '../loans/contacts_permission_screen.dart';
import '../notifications/notifications_permission_screen.dart';
import '../profile/profile_screen.dart';
import 'dashboard_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  int _index = 0;
  bool _checkingSetup = true;
  bool _needsNotificationsPrompt = false;
  bool _needsContactsPrompt = false;

  final _pages = const [
    DashboardScreen(),
    GroupsScreen(),
    BillsScreen(),
    ActivityScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkSetupPrompts());
    ActivityController.instance.startLiveUpdates();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ActivityController.instance.stopLiveUpdates();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ActivityController.instance.startLiveUpdates();
      // ignore: unawaited_futures
      ActivityController.instance.silentRefresh();
      if (_index == 0) {
        // ignore: unawaited_futures
        DashboardController.instance.load(force: true);
      }
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      ActivityController.instance.stopLiveUpdates();
    }
  }

  Future<void> _checkSetupPrompts() async {
    final notifPrompted = await AppPrefs.instance.notificationsPrompted;
    final contactsPrompted = await AppPrefs.instance.contactsPrompted;
    if (!mounted) return;
    setState(() {
      _needsNotificationsPrompt = !notifPrompted;
      _needsContactsPrompt = !contactsPrompted;
      _checkingSetup = false;
    });

    // Returning users: refresh FCM token for bill reminders & alerts.
    if (notifPrompted) {
      // ignore: unawaited_futures
      PushNotificationService.instance.syncWithBackend();
    }
  }

  Future<void> _finishNotificationsPrompt({required bool allowed}) async {
    var granted = false;
    if (allowed) {
      granted = await PushNotificationService.instance.requestPermission();
      if (granted) {
        await PushNotificationService.instance.syncWithBackend();
      }
    }
    await AppPrefs.instance.setNotificationsAllowed(granted);
    if (!mounted) return;
    setState(() => _needsNotificationsPrompt = false);
  }

  Future<void> _finishContactsPrompt({required bool allowed}) async {
    if (allowed) {
      final granted = await ContactsMatchService.requestPermission();
      await AppPrefs.instance.setContactsAllowed(granted);
    } else {
      await AppPrefs.instance.setContactsAllowed(false);
    }
    if (!mounted) return;
    setState(() => _needsContactsPrompt = false);
  }

  void _goTab(int index) {
    setState(() => _index = index);
    if (index == 0) {
      // ignore: unawaited_futures
      DashboardController.instance.load(force: true);
    } else if (index == 3) {
      // ignore: unawaited_futures
      ActivityController.instance.silentRefresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingSetup) {
      return const Scaffold(
        backgroundColor: AppColors.canvas,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.mint),
        ),
      );
    }

    // After register/login: ask for push first (bills, reminders, all alerts).
    if (_needsNotificationsPrompt) {
      return NotificationsPermissionScreen(
        onAllow: () => _finishNotificationsPrompt(allowed: true),
        onSkip: () => _finishNotificationsPrompt(allowed: false),
      );
    }

    if (_needsContactsPrompt) {
      return ContactsPermissionScreen(
        onAllow: () => _finishContactsPrompt(allowed: true),
        onSkip: () => _finishContactsPrompt(allowed: false),
      );
    }

    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border(
            top: BorderSide(color: AppColors.border.withValues(alpha: 0.8)),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                _NavItem(
                  icon: Icons.home_rounded,
                  label: 'Home',
                  selected: _index == 0,
                  onTap: () => _goTab(0),
                ),
                _NavItem(
                  icon: Icons.groups_rounded,
                  label: 'Groups',
                  selected: _index == 1,
                  onTap: () => _goTab(1),
                ),
                _NavItem(
                  icon: Icons.receipt_long_rounded,
                  label: 'Bills',
                  selected: _index == 2,
                  onTap: () => _goTab(2),
                ),
                _NavItem(
                  icon: Icons.timeline_rounded,
                  label: 'Activity',
                  selected: _index == 3,
                  onTap: () => _goTab(3),
                ),
                _NavItem(
                  icon: Icons.person_rounded,
                  label: 'Profile',
                  selected: _index == 4,
                  onTap: () => _goTab(4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? AppColors.mintWash : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 22,
                color: selected ? AppColors.mint : AppColors.textMuted,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.manrope(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? AppColors.mint : AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
