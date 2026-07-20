import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/mock_data.dart';
import '../../services/auth_controller.dart';
import '../../theme/app_colors.dart';
import '../../utils/api_feedback.dart';
import '../../widgets/auth/auth_widgets.dart';
import '../../widgets/common/app_widgets.dart';
import '../auth/login_screen.dart';
import '../reports/reports_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    try {
      await AuthController.instance.logout();
    } catch (e) {
      if (context.mounted) showApiError(context, e);
    }
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AuthController.instance,
      builder: (context, _) {
        final apiUser = AuthController.instance.user;
        final name = apiUser?.name ?? MockData.currentUser.name;
        final email = apiUser?.email ?? MockData.currentUser.email;
        final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

        return Scaffold(
          backgroundColor: AppColors.canvas,
          body: SafeArea(
            child: ListView(
              children: [
                const AppHeader(title: 'Profile', subtitle: 'Account & settings'),
                SoftTile(
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: AppColors.mintWash,
                        backgroundImage: apiUser?.avatar != null &&
                                apiUser!.avatar!.isNotEmpty
                            ? NetworkImage(apiUser.avatar!)
                            : null,
                        child: apiUser?.avatar == null ||
                                apiUser!.avatar!.isEmpty
                            ? Text(
                                initial,
                                style: GoogleFonts.sora(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.mint,
                                ),
                              )
                            : null,
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
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const EditProfileScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.edit_outlined),
                      ),
                    ],
                  ),
                ),
                _MenuTile(
                  icon: Icons.bar_chart_rounded,
                  label: 'Reports',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ReportsScreen()),
                    );
                  },
                ),
                _MenuTile(
                  icon: Icons.lock_outline_rounded,
                  label: 'Change password',
                  onTap: () =>
                      showStaticSnack(context, 'Change password (static)'),
                ),
                _MenuTile(
                  icon: Icons.devices_rounded,
                  label: 'Sessions',
                  onTap: () => showStaticSnack(context, 'Sessions (static)'),
                ),
                _MenuTile(
                  icon: Icons.notifications_outlined,
                  label: 'Notification settings',
                  onTap: () => showStaticSnack(
                    context,
                    'Notification settings (static)',
                  ),
                ),
                _MenuTile(
                  icon: Icons.logout_rounded,
                  label: 'Log out',
                  danger: true,
                  onTap: () => _logout(context),
                ),
                const SizedBox(height: 24),
              ],
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
          Icon(Icons.chevron_right_rounded, color: color.withValues(alpha: 0.5)),
        ],
      ),
    );
  }
}

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _currency;

  @override
  void initState() {
    super.initState();
    final apiUser = AuthController.instance.user;
    final u = MockData.currentUser;
    _name = TextEditingController(text: apiUser?.name ?? u.name);
    _phone = TextEditingController(text: apiUser?.phone ?? u.phone ?? '');
    _currency = TextEditingController(text: apiUser?.currency ?? u.currency);
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _currency.dispose();
    super.dispose();
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
              title: 'Edit profile',
              onBack: () => Navigator.pop(context),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  AuthTextField(controller: _name, label: 'Name'),
                  const SizedBox(height: 14),
                  AuthTextField(controller: _phone, label: 'Phone'),
                  const SizedBox(height: 14),
                  AuthTextField(controller: _currency, label: 'Currency'),
                  const SizedBox(height: 28),
                  AuthPrimaryButton(
                    label: 'Save changes',
                    onPressed: () {
                      showStaticSnack(context, 'Profile saved (static)');
                      Navigator.pop(context);
                    },
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
