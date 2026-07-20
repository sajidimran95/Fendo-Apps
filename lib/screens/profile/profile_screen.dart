import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/network/api_exception.dart';
import '../../services/auth_controller.dart';
import '../../theme/app_colors.dart';
import '../../utils/api_feedback.dart';
import '../../widgets/common/app_widgets.dart';
import '../auth/login_screen.dart';
import '../reports/reports_screen.dart';
import 'change_password_screen.dart';
import 'delete_account_screen.dart';
import 'edit_profile_screen.dart';
import 'notification_settings_screen.dart';
import 'sessions_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _uploadingAvatar = false;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    if (_refreshing) return;
    if (AuthController.instance.isDemo) return;
    setState(() => _refreshing = true);
    try {
      final user = await AuthController.instance.userApi.getProfile();
      AuthController.instance.setUser(user);
    } on ApiException {
      // Keep cached session user if profile fetch fails.
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _logout() async {
    try {
      await AuthController.instance.logout();
    } catch (e) {
      if (mounted) showApiError(context, e);
    }
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  Future<void> _pickAndUploadAvatar() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
    );
    if (file == null) return;

    final bytes = await file.length();
    if (bytes > 2 * 1024 * 1024) {
      if (!mounted) return;
      showApiError(
        context,
        ApiException(message: 'Avatar must be 2MB or smaller'),
      );
      return;
    }

    final ext = file.name.split('.').last.toLowerCase();
    if (!['jpg', 'jpeg', 'png', 'webp'].contains(ext)) {
      if (!mounted) return;
      showApiError(
        context,
        ApiException(message: 'Use jpg, png, or webp'),
      );
      return;
    }

    if (kIsWeb) {
      if (!mounted) return;
      showApiError(
        context,
        ApiException(message: 'Avatar upload on web is not supported yet'),
      );
      return;
    }

    setState(() => _uploadingAvatar = true);
    try {
      final user = await AuthController.instance.userApi.uploadAvatar(
        filePath: file.path,
        fileName: file.name,
      );
      AuthController.instance.setUser(user);
      if (!mounted) return;
      showApiMessage(context, 'Avatar updated');
    } on ApiException catch (e) {
      if (!mounted) return;
      showApiError(context, e);
    } catch (e) {
      if (!mounted) return;
      showApiError(context, e);
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AuthController.instance,
      builder: (context, _) {
        final user = AuthController.instance.user;
        final name = user?.name ?? 'User';
        final email = user?.email ?? '';
        final phone = user?.phone;
        final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
        final avatarUrl = user?.avatar;

        return Scaffold(
          backgroundColor: AppColors.canvas,
          body: SafeArea(
            child: RefreshIndicator(
              color: AppColors.mint,
              onRefresh: _loadProfile,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const AppHeader(
                    title: 'Profile',
                    subtitle: 'Account & settings',
                  ),
                  SoftTile(
                    child: Row(
                      children: [
                        Stack(
                          children: [
                            CircleAvatar(
                              radius: 34,
                              backgroundColor: AppColors.mintWash,
                              backgroundImage:
                                  avatarUrl != null && avatarUrl.isNotEmpty
                                      ? NetworkImage(avatarUrl)
                                      : null,
                              child: avatarUrl == null || avatarUrl.isEmpty
                                  ? Text(
                                      initial,
                                      style: GoogleFonts.sora(
                                        fontSize: 26,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.mint,
                                      ),
                                    )
                                  : null,
                            ),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Material(
                                color: AppColors.forest,
                                shape: const CircleBorder(),
                                child: InkWell(
                                  customBorder: const CircleBorder(),
                                  onTap: _uploadingAvatar
                                      ? null
                                      : _pickAndUploadAvatar,
                                  child: SizedBox(
                                    width: 28,
                                    height: 28,
                                    child: _uploadingAvatar
                                        ? const Padding(
                                            padding: EdgeInsets.all(6),
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Icon(
                                            Icons.camera_alt_rounded,
                                            size: 14,
                                            color: Colors.white,
                                          ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: GoogleFonts.sora(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.forest,
                                ),
                              ),
                              Text(
                                email,
                                style: GoogleFonts.manrope(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              if (phone != null && phone.isNotEmpty)
                                Text(
                                  phone,
                                  style: GoogleFonts.manrope(
                                    fontSize: 13,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const EditProfileScreen(),
                              ),
                            );
                            _loadProfile();
                          },
                          icon: const Icon(Icons.edit_outlined),
                        ),
                      ],
                    ),
                  ),
                  if (user != null)
                    SoftTile(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (user.currency.isNotEmpty)
                            StatusChip(user.currency),
                          if (user.timezone != null &&
                              user.timezone!.isNotEmpty)
                            StatusChip(user.timezone!),
                          if (user.language != null &&
                              user.language!.isNotEmpty)
                            StatusChip(user.language!),
                        ],
                      ),
                    ),
                  _MenuTile(
                    icon: Icons.bar_chart_rounded,
                    label: 'Reports',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ReportsScreen(),
                        ),
                      );
                    },
                  ),
                  _MenuTile(
                    icon: Icons.lock_outline_rounded,
                    label: 'Change password',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ChangePasswordScreen(),
                        ),
                      );
                    },
                  ),
                  _MenuTile(
                    icon: Icons.devices_rounded,
                    label: 'Sessions',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const SessionsScreen(),
                        ),
                      );
                    },
                  ),
                  _MenuTile(
                    icon: Icons.notifications_outlined,
                    label: 'Notification settings',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const NotificationSettingsScreen(),
                        ),
                      );
                    },
                  ),
                  _MenuTile(
                    icon: Icons.delete_outline_rounded,
                    label: 'Delete account',
                    danger: true,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const DeleteAccountScreen(),
                        ),
                      );
                    },
                  ),
                  _MenuTile(
                    icon: Icons.logout_rounded,
                    label: 'Log out',
                    danger: true,
                    onTap: _logout,
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.coral : AppColors.forest;
    return SoftTile(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: color.withValues(alpha: 0.5),
          ),
        ],
      ),
    );
  }
}
