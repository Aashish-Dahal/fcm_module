# Firebase push notification module

A new Flutter module project.

## Getting Started

For help getting started with Flutter development, view the online
[documentation](https://flutter.dev/).

For instructions integrating Flutter modules to your existing applications,
see the [add-to-app documentation](https://flutter.dev/to/add-to-app).

## Pictures in notifications

Send an image with the push (FCM `notification.image`, or an `image` /
`imageUrl` key in `data`).

- **App in the background or closed:** the system draws the push and loads
  the image itself.
- **App open:** `FirebaseNotificationService` downloads the image and shows
  it in its local notification: beside the text, and full width when
  expanded, on Android; as an attachment on iOS. Turn this off with
  `showImages: false`.

Apps that draw their own notifications can use the same helper:

```dart
final image = await NotificationImage.of(message); // null if none or unreachable
final android = image == null ? details : image.android(details, title: t, body: b);
final ios = image == null ? const DarwinNotificationDetails() : await image.darwin();
```

The image address must be reachable from the phone (not `localhost`), and
release builds need `https`.

## Versions

`firebase_messaging` 16 (with `firebase_core` 4) or 17 (with `firebase_core`
5) both work.
