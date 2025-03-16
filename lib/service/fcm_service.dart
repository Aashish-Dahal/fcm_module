import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

abstract class NotificationService {
  Future<void> initialize();
}

class FirebaseNotificationService extends NotificationService {
  final FirebaseMessaging _firebaseMessaging;
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin;
  final void Function(NotificationResponse)? onDidReceiveNotificationResponse;
  final String? channelId;
  final String? channelName;
  final Color? notificationColor;
  final String? channelDescription;
  final void Function(String? vapidKey)? getToken;
  final String defaultIcon;

  FirebaseNotificationService(
      this._firebaseMessaging, this._flutterLocalNotificationsPlugin,
      {this.onDidReceiveNotificationResponse,
      this.channelId,
      this.channelName,
      this.notificationColor,
      this.channelDescription,
      required this.defaultIcon,
      this.getToken});

  @override
  Future<void> initialize() async {
    await _requestPermissions();
    await _configureLocalNotifications();
    await _setupFirebaseListeners();
  }

  Future<void> _requestPermissions() async {
    if (Platform.isIOS) {
      await _firebaseMessaging.requestPermission(
        alert: true,
        announcement: true,
        badge: true,
        sound: true,
      );
    }
  }

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
        onDidReceiveNotificationResponse: onDidReceiveNotificationResponse);
  }

  Future<void> _setupFirebaseListeners() async {
    final token = await _firebaseMessaging.getToken();
    if (getToken != null) getToken!(token);

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _showLocalNotification(message);
    });
  }

  void _showLocalNotification(RemoteMessage message) async {
    AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      channelId ?? 'high_importance_channel',
      channelName ?? 'High Importance Notifications',
      channelDescription: channelDescription,
      importance: Importance.max,
      priority: Priority.high,
      color: notificationColor,
      ticker: 'ticker',
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
