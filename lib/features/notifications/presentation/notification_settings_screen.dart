import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../data/notification_repository.dart';
import '../data/push_messaging_service.dart';
import '../domain/app_notification.dart';

class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends ConsumerState<NotificationSettingsScreen> {
  bool _saving = false;

  Future<void> _update(NotificationPreferences next) async {
    setState(() => _saving = true);
    try {
      await ref.read(notificationRepositoryProvider).savePreferences(next);
      final push = ref.read(pushMessagingServiceProvider);
      next.pushEnabled ? await push.register() : await push.unregister();
      ref.invalidate(notificationPreferencesProvider);
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(notificationPreferencesProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification settings'),
        bottom: _saving
            ? const PreferredSize(preferredSize: Size.fromHeight(3), child: LinearProgressIndicator())
            : null,
      ),
      body: AsyncValueView<NotificationPreferences>(
        value: prefs,
        onRetry: () => ref.invalidate(notificationPreferencesProvider),
        data: (p) => PageBody(
          children: [
            const InfoBanner(
              icon: Icons.lock_outline_rounded,
              message: 'Notifications use general wording, so nothing private shows on '
                  'your lock screen. Appointment confirmations and changes are always '
                  'shown in the app.',
            ),
            const SectionHeader(title: 'Optional notifications'),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Appointment reminders'),
                    subtitle: const Text('A reminder the day before'),
                    value: p.appointmentReminders,
                    onChanged: _saving ? null : (v) => _update(p.copyWith(appointmentReminders: v)),
                  ),
                  const Divider(),
                  SwitchListTile(
                    title: const Text('Upcoming activities'),
                    subtitle: const Text('Reminders for activities you joined'),
                    value: p.programmeUpdates,
                    onChanged: _saving ? null : (v) => _update(p.copyWith(programmeUpdates: v)),
                  ),
                  const Divider(),
                  SwitchListTile(
                    title: const Text('New learning resources'),
                    subtitle: const Text('When the Learning Hub adds something new'),
                    value: p.newResources,
                    onChanged: _saving ? null : (v) => _update(p.copyWith(newResources: v)),
                  ),
                ],
              ),
            ),
            const SectionHeader(title: 'Delivery'),
            AppCard(
              padding: EdgeInsets.zero,
              child: SwitchListTile(
                title: const Text('Push notifications on this device'),
                subtitle: Text(
                  'Turn off to only see updates inside the app.',
                  style: context.text.bodySmall,
                ),
                value: p.pushEnabled,
                onChanged: _saving ? null : (v) => _update(p.copyWith(pushEnabled: v)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
