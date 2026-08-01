import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../../firebase_options.dart';

/// Initializes Firebase for Fendo (Android via google-services + options).
class FirebaseBootstrap {
  FirebaseBootstrap._();

  static bool ready = false;
  static String? initError;

  static Future<void> init() async {
    try {
      if (Firebase.apps.isNotEmpty) {
        ready = true;
        debugPrint('Firebase already initialized (${Firebase.app().name})');
        return;
      }
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      ready = true;
      initError = null;
      debugPrint(
        'Firebase initialized → project=${DefaultFirebaseOptions.android.projectId}',
      );
    } catch (e, st) {
      ready = false;
      initError = e.toString();
      debugPrint('Firebase init failed: $e\n$st');
    }
  }
}
