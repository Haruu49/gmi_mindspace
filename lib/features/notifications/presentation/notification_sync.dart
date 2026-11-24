import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/local_notification_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../authentication/presentation/auth_controller.dart';
import '../data/notification_repository.dart';
import '../data/push_messaging_service.dart';

/// Disabled in tests so no realtime socket is opened.
final notificationSyncEnabledProvider = Provider<bool>((ref) => true);

/// Keeps in-app notifications fresh while a user is signed in:
///  * realtime subscription to the user's own notification rows (RLS-scoped),
///  * shows a generic on-device notification for each new row,
///  * refreshes when the app returns to the foreground.
class NotificationSync extends ConsumerStatefulWidget {
  const NotificationSync({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<NotificationSync> createState() => _NotificationSyncState();
}

class _NotificationSyncState extends ConsumerState<NotificationSync> with WidgetsBindingObserver {
  RealtimeChannel? _channel;
  String? _userId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _unsubscribe();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _userId != null) {
      ref.invalidate(notificationsProvider);
    }
  }

  void _subscribe(String uid) {
    if (!SupabaseService.isReady || _userId == uid || !ref.read(notificationSyncEnabledProvider)) return;
    _unsubscribe();
    _userId = uid;
    final client = ref.read(supabaseClientProvider);
    _channel = client
        .channel('notifications-$uid')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: uid,
          ),
          callback: (payload) {
            final row = payload.newRecord;
            ref.invalidate(notificationsProvider);
            LocalNotificationService.instance.show(
              id: (row['id'] as String? ?? '').hashCode & 0x7fffffff,
              title: row['title'] as String? ?? 'GMI MindSpace',
              body: row['body'] as String? ?? 'You have a new update.',
              payload: row['id'] as String?,
            );
          },
        )
        .subscribe();
    LocalNotificationService.instance.requestPermission();
    ref.read(pushMessagingServiceProvider).register();
  }

  void _unsubscribe() {
    final ch = _channel;
    _channel = null;
    _userId = null;
    if (ch != null && SupabaseService.isReady) {
      ref.read(supabaseClientProvider).removeChannel(ch);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<SessionState>(authControllerProvider, (prev, next) {
      if (next is AuthSignedIn) {
        _subscribe(next.profile.id);
      } else if (prev is AuthSignedIn) {
        _unsubscribe();
        ref.read(pushMessagingServiceProvider).unregister();
        LocalNotificationService.instance.cancelAll();
      }
    });
    final s = ref.read(authControllerProvider);
    if (s is AuthSignedIn && _userId == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _subscribe(s.profile.id);
      });
    }
    return widget.child;
  }
}
