import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_push_notification_module/fcm_service.dart';
import 'package:flutter/material.dart' show Color;

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

  /// The default notification icon for Android.
  final String defaultIcon;

  /// Whether to log or retrieve the FCM token.
  final bool showToken;

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
      this.getToken});

  /// Initializes the notification service.
  ///
  /// This method:
  /// - Requests the necessary permissions for notifications.
  /// - Configures local notifications.
  /// - Sets up Firebase listeners for incoming notifications.
  @override
  Future<void> initialize() async {
    await _requestPermissions();
    await _configureLocalNotifications();
    await _setupFirebaseListeners();
  }

  /// Requests permissions for push notifications.
  ///
  /// This method enables auto-initialization of FCM and requests user permission
  /// to receive notifications. On iOS, it includes provisional authorization.
  Future<void> _requestPermissions() async {
    await FirebaseMessaging.instance.setAutoInitEnabled(true);
    await _firebaseMessaging.requestPermission(
        alert: true,
        announcement: true,
        badge: true,
        sound: true,
        provisional: Platform.isIOS);
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
    _flutterLocalNotificationsPlugin.initialize(initSettings,
        onDidReceiveNotificationResponse: onLocalNotificationTab);
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
      final String? channelId = message.data['channelId'] as String?;
      final String? channelName = message.data['channelName'] as String?;
      final String? description = message.data['channelDescription'] as String?;

      if (channelId != null && channelName != null && description != null) {
        createNotificationChannel(channelId, channelName, description);
      }
      if (onFCMNotificationTab != null) {
        onFCMNotificationTab!(message);
      }
    });
    _firebaseMessaging.getInitialMessage().then((message) {
      if (message != null) {
        final String? channelId = message.data['channelId'] as String?;
        final String? channelName = message.data['channelName'] as String?;
        final String? description =
            message.data['channelDescription'] as String?;

        if (channelId != null && channelName != null && description != null) {
          createNotificationChannel(channelId, channelName, description);
        }
        if (onFCMNotificationTab != null) {
          onFCMNotificationTab!(message);
        }
      }
    });
  }

  Future<String?> getIdToken() async {
    final token = await _firebaseMessaging.getToken();
    return token;
  }

  StreamSubscription<String> onTokenRefresh(
    void Function(String) getRefreshToken,
  ) {
    final sub = _firebaseMessaging.onTokenRefresh.listen(getRefreshToken);
    return sub;
  }

  /// Displays a local notification when an FCM message is received.
  ///
  /// This method extracts the notification title, body, and other details
  /// from the [message] and displays it using the local notifications plugin.
  void _showLocalNotification(RemoteMessage message) async {
    AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      channelId ?? message.data['channelId'] ?? "channel_id",
      channelName ?? message.data['channelName'] ?? "channel_name",
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
    await _flutterLocalNotificationsPlugin.show(
      0,
      message.notification?.title,
      message.notification?.body,
      details,
    );
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
}
