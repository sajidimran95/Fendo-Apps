import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_colors.dart';
import '../../widgets/auth/auth_widgets.dart';

/// One-time contacts access prompt (after first login).
class ContactsPermissionScreen extends StatelessWidget {
  const ContactsPermissionScreen({
    super.key,
    required this.onAllow,
    required this.onSkip,
    this.showSkip = true,
  });

  final VoidCallback onAllow;
  final VoidCallback onSkip;
  final bool showSkip;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.heroWash),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
            child: Column(
              children: [
                const Spacer(),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(22, 28, 22, 28),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: AppColors.border.withValues(alpha: 0.6),
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          gradient: AppColors.brandMark,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: const Icon(
                          Icons.contacts_rounded,
                          color: Colors.white,
                          size: 34,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Find friends on Fendo',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.sora(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.forest,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Allow contacts once so you can create loans with people already on Fendo. We only match phones/emails — your phonebook stays on your device.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.manrope(
                          fontSize: 14,
                          height: 1.45,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 22),
                      AuthPrimaryButton(
                        label: 'Allow contacts',
                        onPressed: onAllow,
                      ),
                      if (showSkip) ...[
                        const SizedBox(height: 10),
                        TextButton(
                          onPressed: onSkip,
                          child: Text(
                            'Not now',
                            style: GoogleFonts.manrope(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
