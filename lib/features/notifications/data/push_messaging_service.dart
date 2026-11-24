import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Remote push (Firebase Cloud Messaging) integration point.
///
/// The app ships with [NoopPushMessagingService] so it builds and runs
/// without Firebase configuration. To enable FCM:
///
///  1. Create a Firebase project, add the Android/iOS apps, download
///     `google-services.json` / `GoogleService-Info.plist` (keep them out of
///     git), and run `flutterfire configure`.
///  2. `flutter pub add firebase_core firebase_messaging`.
///  3. Implement [PushMessagingService] with `FirebaseMessaging.instance`:
///     request permission, read `getToken()`, listen to `onTokenRefresh`,
///     and pass the token to `NotificationRepository.registerDeviceToken`.
///  4. Override [pushMessagingServiceProvider] in `main.dart`.
///  5. Deploy `supabase/functions/send-push` and add a Database Webhook on
///     INSERT into `public.notifications` that calls it.
///
/// Push payloads only ever contain the generic notification title/body
/// already stored in `notifications` – never mood, journal or appointment
/// details.
abstract interface class PushMessagingService {
  /// Requests permission and registers the device token for the signed-in user.
  Future<void> register();

  /// Removes this device's token (on sign-out or when push is disabled).
  Future<void> unregister();
}

class NoopPushMessagingService implements PushMessagingService {
  const NoopPushMessagingService();

  @override
  Future<void> register() async {}

  @override
  Future<void> unregister() async {}
}

final pushMessagingServiceProvider =
    Provider<PushMessagingService>((ref) => const NoopPushMessagingService());
