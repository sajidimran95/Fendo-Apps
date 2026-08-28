import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

import '../core/firebase/firebase_bootstrap.dart';
import '../firebase_options.dart';
import '../utils/notification_router.dart';
import 'auth_controller.dart';
import 'activity_controller.dart';
import 'notifications_controller.dart';

/// Android / iOS channel used for bill reminders and all Fendo pushes.
const String kFendoPushChannelId = 'fendo_default';
const String kFendoPushChannelName = 'Fendo alerts';

/// Top-level FCM background handler (required by Firebase Messaging).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (_) {}
  debugPrint(
    'FCM background: ${message.messageId} '
    'title=${message.notification?.title}',
  );
}

/// Requests OS permission, registers FCM token with API, shows system trays.
class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  GlobalKey<NavigatorState>? navigatorKey;
  bool _initialized = false;
  bool _handlersBound = false;

  /// Call once from [main] after Firebase is ready.
  Future<void> init() async {
    if (_initialized) return;
    if (!FirebaseBootstrap.ready || kIsWeb) {
      debugPrint('Push: skip init (Firebase not ready / web)');
      return;
    }

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _local.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: _onLocalTap,
    );

    final androidPlugin = _local.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        kFendoPushChannelId,
        kFendoPushChannelName,
        description: 'Bill reminders, expenses, settlements, and group alerts',
        importance: Importance.high,
      ),
    );

    if (!_handlersBound) {
      FirebaseMessaging.onMessage.listen(_onForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpened);
      _messaging.onTokenRefresh.listen((token) {
        // ignore: unawaited_futures
        _uploadToken(token);
      });
      _handlersBound = true;
    }

    final initial = await _messaging.getInitialMessage();
    if (initial != null) {
      // Deep-link after first frame when user cold-started from a push.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openFromPushData(Map<String, dynamic>.from(initial.data));
      });
    }

    _initialized = true;
    debugPrint('Push: local notifications ready');
  }

  /// OS permission dialog. Returns true if notifications are allowed.
  Future<bool> requestPermission() async {
    if (kIsWeb) return false;
    if (!FirebaseBootstrap.ready) await FirebaseBootstrap.init();
    if (!FirebaseBootstrap.ready) return false;

    if (!_initialized) await init();

    if (Platform.isAndroid) {
      final status = await Permission.notification.request();
      if (!status.isGranted && !status.isLimited) {
        debugPrint('Push: Android notification denied ($status)');
        return false;
      }
    }

    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    final ok = settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
    debugPrint('Push: permission status=${settings.authorizationStatus}');
    return ok;
  }

  /// After login / register / app launch with session: upload FCM token.
  Future<void> syncWithBackend({bool requestIfNeeded = false}) async {
    if (kIsWeb || !AuthController.instance.isAuthenticated) return;
    if (!FirebaseBootstrap.ready) return;
    if (!_initialized) await init();

    if (requestIfNeeded) {
      await requestPermission();
    }

    try {
      // iOS / some Android builds need this for reliable delivery.
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (_) {}

    try {
      final token = await _messaging.getToken();
      if (token == null || token.isEmpty) {
        debugPrint('Push: no FCM token yet');
        return;
      }
      await _uploadToken(token);
    } catch (e) {
      debugPrint('Push: token sync failed: $e');
    }
  }

  Future<void> _uploadToken(String token) async {
    if (!AuthController.instance.isAuthenticated) return;
    try {
      await AuthController.instance.userApi.updateFcmToken(token);
      debugPrint('Push: FCM token uploaded (${token.length} chars)');
    } catch (e) {
      debugPrint('Push: FCM token upload failed: $e');
    }
  }

  Future<void> _onForegroundMessage(RemoteMessage message) async {
    debugPrint(
      'FCM foreground: ${message.notification?.title} '
      'data=${message.data}',
    );
    await _showLocalFromRemote(message);
    // Keep in-app badge fresh when a push arrives while open.
    try {
      await NotificationsController.instance.loadUnreadCount();
    } catch (_) {}
    // New push often means new group/expense activity — refresh without reload.
    // ignore: unawaited_futures
    ActivityController.instance.silentRefresh();
  }

  void _onMessageOpened(RemoteMessage message) {
    debugPrint('FCM opened: ${message.messageId}');
    _openFromPushData(Map<String, dynamic>.from(message.data));
  }

  void _onLocalTap(NotificationResponse response) {
    final raw = response.payload;
    if (raw == null || raw.isEmpty) {
      _openFromPushData(const {});
      return;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        _openFromPushData(Map<String, dynamic>.from(decoded));
        return;
      }
    } catch (_) {}
    _openFromPushData(const {});
  }

  Future<void> _showLocalFromRemote(RemoteMessage message) async {
    final notification = message.notification;
    final title = notification?.title ??
        message.data['title']?.toString() ??
        'Fendo';
    final body = notification?.body ??
        message.data['body']?.toString() ??
        message.data['message']?.toString() ??
        '';
    if (title.isEmpty && body.isEmpty) return;

    final payload = <String, dynamic>{
      ...message.data,
      if (title.isNotEmpty) 'title': title,
      if (body.isNotEmpty) 'body': body,
      if (notification?.title != null) 'title': notification!.title,
      if (notification?.body != null) 'body': notification!.body,
    };

    final id = message.hashCode & 0x7fffffff;
    await _local.show(
      id,
      title.isEmpty ? 'Fendo' : title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          kFendoPushChannelId,
          kFendoPushChannelName,
          channelDescription:
              'Bill reminders, expenses, settlements, and group alerts',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          styleInformation: body.isNotEmpty
              ? BigTextStyleInformation(body)
              : null,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: jsonEncode(payload),
    );
  }

  void _openFromPushData(Map<String, dynamic> data) {
    final nav = navigatorKey?.currentState;
    final ctx = navigatorKey?.currentContext;
    if (nav == null || ctx == null) return;
    // Enrich data with notification fields FCM may only put on `notification`.
    final enriched = Map<String, dynamic>.from(data);
    // ignore: unawaited_futures
    NotificationRouter.open(ctx, pushData: enriched);
    // ignore: unawaited_futures
    NotificationsController.instance.loadUnreadCount();
  }
}
