package com.fendo.fendo

import io.flutter.embedding.android.FlutterFragmentActivity

/// FlutterFragmentActivity is required for reliable Firebase Auth reCAPTCHA /
/// Chrome Custom Tabs return into the app (avoids broken session / about:blank).
class MainActivity : FlutterFragmentActivity()
