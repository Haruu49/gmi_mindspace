import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// On-device notifications.
///
/// PRIVACY: every notification shown here uses generic wording and Android
/// `NotificationVisibility.private`, so the lock screen shows only
/// "GMI MindSpace" – never appointment details, moods or journal content.
class LocalNotificationService {
  LocalNotificationService._();
  static final LocalNotificationService instance = LocalNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  /// Called with the payload when the user taps a notification.
  void Function(String? payload)? onTap;

  static const _channelId = 'mindspace_updates';
  static const _channelName = 'MindSpace updates';

  Future<void> init() async {
    if (_ready || kIsWeb) return;
    try {
      tzdata.initializeTimeZones();
      // GMI is in Malaysia; reminders are scheduled in Malaysia time.
      tz.setLocalLocation(tz.getLocation('Asia/Kuala_Lumpur'));
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
        onDidReceiveNotificationResponse: (r) => onTap?.call(r.payload),
      );
      _ready = true;
    } catch (e) {
      debugPrint('Local notifications unavailable: $e');
    }
  }

  /// Asks for permission (Android 13+ / iOS). Call after sign-in, not at launch.
  Future<void> requestPermission() async {
    if (!_ready) return;
    try {
      await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      await _plugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    } catch (e) {
      debugPrint('Notification permission request failed: $e');
    }
  }

  NotificationDetails get _details => const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: 'Appointment, activity and resource updates',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          visibility: NotificationVisibility.private,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          threadIdentifier: 'mindspace',
        ),
      );

  /// Shows a generic notification immediately.
  Future<void> show({required int id, required String title, required String body, String? payload}) async {
    if (!_ready) return;
    try {
      await _plugin.show(id: id, title: title, body: body, notificationDetails: _details, payload: payload);
    } catch (e) {
      debugPrint('Could not show notification: $e');
    }
  }

  /// Schedules a generic reminder one hour before an appointment.
  Future<void> scheduleAppointmentReminder({required String appointmentId, required DateTime startsAt}) async {
    if (!_ready) return;
    final when = startsAt.subtract(const Duration(hours: 1));
    if (when.isBefore(DateTime.now())) return;
    try {
      await _plugin.zonedSchedule(
        id: _idFor(appointmentId),
        title: 'Appointment reminder',
        body: 'You have an appointment in about an hour.',
        scheduledDate: tz.TZDateTime.from(when, tz.local),
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: 'appointment:$appointmentId',
      );
    } catch (e) {
      debugPrint('Could not schedule reminder: $e');
    }
  }

  Future<void> cancelAppointmentReminder(String appointmentId) async {
    if (!_ready) return;
    try {
      await _plugin.cancel(id: _idFor(appointmentId));
    } catch (_) {}
  }

  Future<void> cancelAll() async {
    if (!_ready) return;
    try {
      await _plugin.cancelAll();
    } catch (_) {}
  }

  int _idFor(String key) => key.hashCode & 0x7fffffff;
}
