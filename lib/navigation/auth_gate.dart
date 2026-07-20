import 'package:flutter/material.dart';

import '../screens/auth/login_screen.dart';
import '../screens/home/main_shell.dart';
import '../services/auth_controller.dart';
import '../theme/app_colors.dart';

/// Shows login or home based on saved token + /auth/me.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AuthController.instance,
      builder: (context, _) {
        final auth = AuthController.instance;
        if (!auth.isReady) {
          return const Scaffold(
            backgroundColor: AppColors.canvas,
            body: Center(
              child: CircularProgressIndicator(color: AppColors.mint),
            ),
          );
        }
        if (auth.isAuthenticated) {
          return const MainShell();
        }
        return const LoginScreen();
      },
    );
  }
}
