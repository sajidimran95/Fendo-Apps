import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/firebase/firebase_bootstrap.dart';
import 'core/network/api_http_overrides.dart';
import 'navigation/auth_gate.dart';
import 'services/auth_controller.dart';
import 'services/ip_country_service.dart';
import 'services/push_notification_service.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';

final GlobalKey<NavigatorState> fendoNavigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = ApiHttpOverrides();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: AppColors.canvas,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  await FirebaseBootstrap.init();
  PushNotificationService.instance.navigatorKey = fendoNavigatorKey;
  await PushNotificationService.instance.init();
  // Warm IP→country for phone dial code (non-blocking for UI).
  // ignore: unawaited_futures
  IpCountryService.instance.ensureLoaded();
  await AuthController.instance.bootstrap();
  if (AuthController.instance.isAuthenticated) {
    // ignore: unawaited_futures
    PushNotificationService.instance.syncWithBackend();
  }
  runApp(const FendoApp());
}

class FendoApp extends StatelessWidget {
  const FendoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fendo',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      navigatorKey: fendoNavigatorKey,
      home: const AuthGate(),
    );
  }
}
