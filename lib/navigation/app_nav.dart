import 'package:flutter/material.dart';

import '../screens/home/main_shell.dart';

/// Clears auth stack and opens the static main app.
void goToHome(BuildContext context) {
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const MainShell()),
    (_) => false,
  );
}
