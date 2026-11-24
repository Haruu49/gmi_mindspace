import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/supabase_service.dart';
import '../../../core/utils/failure.dart';
import '../domain/app_notification.dart';

class NotificationRepository {
  NotificationRepository(this._db);

  final SupabaseClient _db;

  Future<List<AppNotification>> fetch() => guard(() async {
        final rows = await _db
            .from('notifications')
            .select('id, type, title, body, data, read_at, created_at')
            .order('created_at', ascending: false)
            .limit(100);
        return rows.map(AppNotification.fromJson).toList();
      });

  Future<void> markRead(String id) => guard(() => _db
      .from('notifications')
      .update({'read_at': DateTime.now().toUtc().toIso8601String()})
      .eq('id', id)
      .isFilter('read_at', null));

  Future<void> markAllRead() => guard(() async {
        final uid = _db.auth.currentUser?.id;
        if (uid == null) return;
        await _db
            .from('notifications')
            .update({'read_at': DateTime.now().toUtc().toIso8601String()})
            .eq('user_id', uid)
            .isFilter('read_at', null);
      });

  Future<void> delete(String id) => guard(() => _db.from('notifications').delete().eq('id', id));

  Future<NotificationPreferences> fetchPreferences() => guard(() async {
        final row = await _db
            .from('notification_preferences')
            .select('appointment_reminders, programme_updates, new_resources, push_enabled')
            .maybeSingle();
        return row == null ? const NotificationPreferences() : NotificationPreferences.fromJson(row);
      });

  Future<void> savePreferences(NotificationPreferences p) => guard(() async {
        final uid = _db.auth.currentUser?.id;
        if (uid == null) throw const AppFailure('Please sign in again.', kind: FailureKind.sessionExpired);
        final existing = await _db.from('notification_preferences').select('user_id').maybeSingle();
        if (existing == null) {
          await _db.from('notification_preferences').insert(p.toJson());
        } else {
          await _db.from('notification_preferences').update(p.toJson()).eq('user_id', uid);
        }
      });

  /// Stores an FCM token so the server-side `send-push` function can reach
  /// this device. Called only when push is enabled and configured.
  Future<void> registerDeviceToken({required String token, required String platform}) =>
      guard(() async {
        final existing =
            await _db.from('device_tokens').select('id').eq('token', token).maybeSingle();
        if (existing == null) {
          await _db.from('device_tokens').insert({'token': token, 'platform': platform});
        } else {
          await _db
              .from('device_tokens')
              .update({'last_seen_at': DateTime.now().toUtc().toIso8601String()})
              .eq('token', token);
        }
      });

  Future<void> removeDeviceToken(String token) =>
      guard(() => _db.from('device_tokens').delete().eq('token', token));
}

final notificationRepositoryProvider = Provider<NotificationRepository>(
  (ref) => NotificationRepository(ref.watch(supabaseClientProvider)),
);

final notificationsProvider = FutureProvider.autoDispose<List<AppNotification>>(
  (ref) => ref.watch(notificationRepositoryProvider).fetch(),
);

final unreadCountProvider = Provider.autoDispose<int>((ref) {
  final list = ref.watch(notificationsProvider).value ?? const [];
  return list.where((n) => !n.isRead).length;
});

final notificationPreferencesProvider = FutureProvider.autoDispose<NotificationPreferences>(
  (ref) => ref.watch(notificationRepositoryProvider).fetchPreferences(),
);
