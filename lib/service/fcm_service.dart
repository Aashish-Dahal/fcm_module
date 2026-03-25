import 'dart:async';
import 'dart:convert';
import 'dart:math';


import 'package:firebase_push_notification_module/fcm_service.dart';
import 'package:flutter/material.dart' show Color, ValueNotifier, debugPrint;

/// Abstract class for a notification service.
///
/// Implementations of this class should provide an [initialize] method
/// to set up notification handling.
abstract class BaseNotificationService {
  /// Initializes the notification service.
  Future<void> initialize();
}

/// A service for handling Firebase Cloud Messaging (FCM) notifications.
///
/// This class integrates with both Firebase Cloud Messaging and local
/// notifications, allowing notifications to be displayed when the app
/// is in the foreground and handling notification interactions.
///
/// To initialize, call [initialize].
class FirebaseNotificationService extends BaseNotificationService {
  /// The Firebase Messaging instance used for push notifications.
  final FirebaseMessaging _firebaseMessaging;

  /// The Flutter Local Notifications plugin instance.
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin;

  /// Callback triggered when a local notification is tapped.
  final Function(NotificationResponse)? onLocalNotificationTab;

  /// Callback triggered when an FCM notification is tapped.
  final Function(RemoteMessage)? onFCMNotificationTab;

  /// The ID of the notification channel (Android only).
  final String? channelId;

  /// The name of the notification channel (Android only).
  final String? channelName;

  /// The description of the notification channel (Android only).
  final String? channelDescription;

  /// The color of the notification icon (Android only).
  final Color? notificationColor;

  /// Callback function to retrieve the FCM token.
  final Function(String? vapidKey)? getToken;

    /// Called whenever the token changes or is refreshed
  final Function(String)? onTokenRefreshCallback;

  /// The default notification icon for Android.
  final String defaultIcon;

  /// Whether to log or retrieve the FCM token.
  final bool showToken;

  // ═══════════════════════════════════════════════════════════
  //  BADGE SUPPORT
  // ═══════════════════════════════════════════════════════════

  /// Listen to this anywhere in your widget tree.
  ///
  /// Example:
  /// ```dart
  /// ValueListenableBuilder<int>(
  ///   valueListenable: FirebaseNotificationService.badgeNotifier,
  ///   builder: (context, count, _) => BadgeWidget(count: count),
  /// )
  /// ```
  static final ValueNotifier<int> badgeNotifier = ValueNotifier(0);
  static int _badgeCount = 0;

  /// Increment badge by 1 — called automatically on new notification.
  static void _incrementBadge() {
    _badgeCount++;
    badgeNotifier.value = _badgeCount;
  }

  /// Decrement badge by 1 — call this when a single notification is tapped.
  static void decrementBadge() {
    if (_badgeCount > 0) {
      _badgeCount--;
      badgeNotifier.value = _badgeCount;
    }
  }

  /// Reset badge to 0 — call this when user opens the notifications screen.
  static void clearBadge() {
    _badgeCount = 0;
    badgeNotifier.value = 0;
  }

  /// Set badge to an exact value — use this to sync with server unread count.
  static void setBadge(int count) {
    _badgeCount = count < 0 ? 0 : count;
    badgeNotifier.value = _badgeCount;
  }

  /// Dispose the notifier — call this only from root MyApp widget dispose().
  static void disposeBadgeNotifier() {
    badgeNotifier.dispose();
  }

  /// Creates an instance of [FirebaseNotificationService].
  ///
  /// - Requires [_firebaseMessaging] for Firebase Cloud Messaging.
  /// - Requires [_flutterLocalNotificationsPlugin] for displaying local notifications.
  FirebaseNotificationService(
      this._firebaseMessaging, this._flutterLocalNotificationsPlugin,
      {this.onLocalNotificationTab,
      this.onFCMNotificationTab,
      this.channelId,
      this.channelName,
      this.notificationColor,
      this.channelDescription,
      required this.defaultIcon,
      this.showToken = false,
      this.getToken,    
      this.onTokenRefreshCallback,
});

  /// Initializes the notification service.
  ///
  /// This method:
  /// - Requests the necessary permissions for notifications.
  /// - Configures local notifications.
  /// - Sets up Firebase listeners for incoming notifications.
  @override
  Future<void> initialize() async {
      await _requestPermissions();
    await Future.wait([
      _configureLocalNotifications(),
      _setupFirebaseListeners(),
    ]);
    _initFCMTokenCallback();

  }

  /// Requests permissions for push notifications.
  ///
  /// This method enables auto-initialization of FCM and requests user permission
  /// to receive notifications. On iOS, it includes provisional authorization.
  Future<void> _requestPermissions() async {
    FirebaseMessaging.instance.setAutoInitEnabled(true);
    await _firebaseMessaging.requestPermission(
        alert: true,
        announcement: true,
        badge: true,
        sound: true,
        provisional: false);
  }

  /// Configures the local notification settings.
  ///
  /// This method sets up the initialization settings for Android and iOS
  /// and associates the notification tap callback.
  Future<void> _configureLocalNotifications() async {
    AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings(defaultIcon);
    final DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings();
    final InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    _flutterLocalNotificationsPlugin.initialize(
      initSettings,
 onDidReceiveNotificationResponse: (NotificationResponse response) {
   /// ✅ Foreground local notification tapped
  /// was incremented in _showLocalNotification → now decrement
    decrementBadge(); 
    if (onLocalNotificationTab != null) {
      onLocalNotificationTab!(response);
    }
  },   
   );
  }

  /// Sets up Firebase listeners for push notifications.
  ///
  /// - If [showToken] is enabled, retrieves and logs the FCM token.
  /// - Listens for incoming messages while the app is in the foreground.
  /// - Handles notification taps when the app is opened.
  Future<void> _setupFirebaseListeners() async {
    if (showToken) {
      final token = await _firebaseMessaging.getToken();
      if (getToken != null) {
        getToken!(token);
      }
    }

    FirebaseMessaging.onMessage.listen(_showLocalNotification);
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _incrementBadge();
      debugPrint("FCM Module::::On Message Background Notification ${message.data} ${message.notification?.android?.channelId}");

      final String? channelId = message.notification?.android?.channelId;
      final String? channelName = message.notification?.android?.channelId;
      final String? description = message.data['channelDescription'] as String?;

      if (channelId != null && channelName != null && description != null) {
        createNotificationChannel(channelId, channelName, description);
      }
      if (onFCMNotificationTab != null) {
        decrementBadge();
        onFCMNotificationTab!(message);
      }
    });
    _firebaseMessaging.getInitialMessage().then((message) {
      if (message != null) {
        _incrementBadge();
        debugPrint("FCM Module::::Initial Background Notification ${message.data} ${message.notification?.android?.channelId}");

        final String? channelId = message.notification?.android?.channelId;
        final String? channelName = message.notification?.android?.channelId;
        final String? description =
            message.data['channelDescription'] as String?;

        if (channelId != null && channelName != null && description != null) {
          createNotificationChannel(channelId, channelName, description);
        }
        if (onFCMNotificationTab != null) {
          decrementBadge();
          onFCMNotificationTab!(message);
        }
      }
    });
  }

  Future<String?> getIdToken() async {
    final token = await _firebaseMessaging.getToken();
    return token;
  }
  /// Initialize token callback: get current token + listen for refresh
  Future<void> _initFCMTokenCallback() async {
    // 1️⃣ Get current token on app start
    final token = await _firebaseMessaging.getToken();
    if (token != null && onTokenRefreshCallback != null) {
      onTokenRefreshCallback!(token);
    }

    // 2️⃣ Listen for token refresh while app is running
    _firebaseMessaging.onTokenRefresh.listen((newToken) {
      if (onTokenRefreshCallback != null) onTokenRefreshCallback!(newToken);
    });
  }

  /// Displays a local notification when an FCM message is received.
  ///
  /// This method extracts the notification title, body, and other details
  /// from the [message] and displays it using the local notifications plugin.
  void _showLocalNotification(RemoteMessage message) async {
    _incrementBadge();   
    debugPrint("FCM Module::::Local Notification ${message.data} ${message.notification?.android?.channelId}");
    AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      channelId ?? message.notification?.android?.channelId ?? "channel_id",
      channelName ?? message.notification?.android?.channelId ?? "channel_name",
      channelDescription:
          channelDescription ?? message.data['channelDescription'],
      importance: Importance.max,
      priority: Priority.high,
      color: notificationColor,
    );

    NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    final uniqueNotificationId = _generateUniqueNotificationId();

    await _flutterLocalNotificationsPlugin.show(
        uniqueNotificationId, message.notification?.title, message.notification?.body, details,
        payload: jsonEncode({
          ...message.data,
          "channelId": message.notification?.android?.channelId ?? "channel_id"
        }));
  }

  /// Create Notification Channel [createNotificationChannel]
  Future<void> createNotificationChannel(
      String id, String name, String description) async {
    /// Define the Android Notification Channel details
    final AndroidNotificationChannel androidChannel =
        AndroidNotificationChannel(
      id,

      /// channel ID (e.g., 'high_importance_channel')
      name,

      /// channel name (e.g., 'High Importance Notifications')
      description: description,

      /// channel description
      importance: Importance.max,

      /// Importance.max is equivalent to IMPORTANCE_HIGH
      playSound: true,
    );

    // Register the channel with the Android system
    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
  }

  int _generateUniqueNotificationId() {
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final randomNum = Random().nextInt(1000);
  return ((timestamp + randomNum) % 2147483647).toInt();
}
}
