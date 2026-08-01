// File generated for Fendo Android Firebase (project: fendo-apps).
// Keep in sync with android/app/google-services.json.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for iOS.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCAdnBSlM-jSfuOcAbAYJZ2r-FPMohA7LI',
    appId: '1:1039680987:android:06289eab53e72b6c9893fe',
    messagingSenderId: '1039680987',
    projectId: 'fendo-apps',
    storageBucket: 'fendo-apps.firebasestorage.app',
  );
}
