import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// The picture in a push (a book cover, a product photo…), for notifications
/// the app draws itself.
///
/// When the app is closed or in the background, the system draws the push
/// and loads its image unaided. When the app is open, nothing is drawn, so
/// the app shows a local copy, which only has a picture if one is fetched
/// and attached. That's what this does.
class NotificationImage {
  NotificationImage._(this.url, this.bytes);

  final String url;
  final Uint8List bytes;

  /// The image address FCM put on the push: Android's or Apple's, or an
  /// `image` / `imageUrl` key in the data, for data-only senders.
  static String? urlOf(RemoteMessage message) {
    final n = message.notification;
    for (final candidate in [
      n?.android?.imageUrl,
      n?.apple?.imageUrl,
      message.data['image'],
      message.data['imageUrl'],
    ]) {
      if (candidate is String && candidate.startsWith('http')) {
        return candidate;
      }
    }
    return null;
  }

  /// Downloads the push's image, or null when there's none, or it's too
  /// slow or can't be reached. The notification is shown either way.
  static Future<NotificationImage?> of(
    RemoteMessage message, {
    Duration timeout = const Duration(seconds: 6),
  }) async {
    final url = urlOf(message);
    if (url == null) return null;
    final client = HttpClient()..connectionTimeout = timeout;
    try {
      final request = await client.getUrl(Uri.parse(url)).timeout(timeout);
      final response = await request.close().timeout(timeout);
      if (response.statusCode != HttpStatus.ok) return null;
      final builder = BytesBuilder(copy: false);
      await response.forEach(builder.add).timeout(timeout);
      final bytes = builder.takeBytes();
      return bytes.isEmpty ? null : NotificationImage._(url, bytes);
    } catch (error) {
      debugPrint('FCM Module::::Notification image not loaded ($url): $error');
      return null;
    } finally {
      client.close(force: true);
    }
  }

  AndroidBitmap<Object> get _bitmap => ByteArrayAndroidBitmap(bytes);

  /// Android: the picture as a thumbnail beside the text, and full width
  /// when the notification is expanded.
  AndroidNotificationDetails android(
    AndroidNotificationDetails base, {
    String? title,
    String? body,
  }) => AndroidNotificationDetails(
    base.channelId,
    base.channelName,
    channelDescription: base.channelDescription,
    importance: base.importance,
    priority: base.priority,
    color: base.color,
    icon: base.icon,
    playSound: base.playSound,
    largeIcon: _bitmap,
    styleInformation: BigPictureStyleInformation(
      _bitmap,
      largeIcon: _bitmap,
      hideExpandedLargeIcon: true,
      contentTitle: title,
      summaryText: body,
    ),
  );

  /// iOS / macOS: the picture as an attachment, which must be a file.
  Future<DarwinNotificationDetails> darwin() async {
    try {
      final name = Uri.parse(url).pathSegments.lastOrNull ?? 'image';
      final ext = name.contains('.') ? name.substring(name.lastIndexOf('.')) : '.jpg';
      final file = File(
        '${Directory.systemTemp.path}/fcm_${DateTime.now().microsecondsSinceEpoch}$ext',
      );
      await file.writeAsBytes(bytes, flush: true);
      return DarwinNotificationDetails(
        attachments: [DarwinNotificationAttachment(file.path)],
      );
    } catch (error) {
      debugPrint('FCM Module::::Notification image not attached: $error');
      return const DarwinNotificationDetails();
    }
  }
}
