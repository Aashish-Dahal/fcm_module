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
  final Function(String? vapidKey)? getToken;
  final String defaultIcon;
  final bool showToken;

  FirebaseNotificationService(
      this._firebaseMessaging, this._flutterLocalNotificationsPlugin,
      {this.onDidReceiveNotificationResponse,
      this.channelId,
      this.channelName,
      this.notificationColor,
      this.channelDescription,
      required this.defaultIcon,
      this.showToken = false,
      this.getToken});

  @override
  Future<void> initialize() async {
    await _requestPermissions();
    await _configureLocalNotifications();
    await _setupFirebaseListeners();
  }

  Future<void> _requestPermissions() async {
    await FirebaseMessaging.instance.setAutoInitEnabled(true);
    await _firebaseMessaging.requestPermission(
        alert: true,
        announcement: true,
        badge: true,
        sound: true,
        provisional: Platform.isIOS);
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
    if (showToken) {
      final token = await _firebaseMessaging.getToken();
      getToken!(token);
    }

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _showLocalNotification(message);
    });
  }

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
