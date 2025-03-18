import 'dart:io' show Platform;

import 'package:firebase_messaging/firebase_messaging.dart'
    show FirebaseMessaging, RemoteMessage;
import 'package:flutter/material.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    show
        AndroidInitializationSettings,
        AndroidNotificationDetails,
        DarwinInitializationSettings,
        DarwinNotificationDetails,
        FlutterLocalNotificationsPlugin,
        Importance,
        InitializationSettings,
        NotificationDetails,
        NotificationResponse,
        Priority;

/// Abstract class for a notification service.
///
/// Implementations of this class should provide an [initialize] method
/// to set up notification handling.
abstract class NotificationService {
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
class FirebaseNotificationService extends NotificationService {
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
      getToken ?? (token);
    }

    FirebaseMessaging.onMessage.listen(_showLocalNotification);
    FirebaseMessaging.onMessageOpenedApp.listen(onFCMNotificationTab);
    _firebaseMessaging
        .getInitialMessage()
        .then((message) => onFCMNotificationTab ?? (message));
  }

  /// Displays a local notification when an FCM message is received.
  ///
  /// This method extracts the notification title, body, and other details
  /// from the [message] and displays it using the local notifications plugin.
  void _showLocalNotification(RemoteMessage message) async {
    AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      channelId ?? message.data['channelId'],
      channelName ?? message.data['channelName'],
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
}
