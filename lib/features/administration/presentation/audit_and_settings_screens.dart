import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/widgets.dart';
import '../data/admin_repository.dart';

class AuditLogScreen extends ConsumerWidget {
  const AuditLogScreen({super.key});

  static String _label(String action) => switch (action) {
        'role_changed' => 'Role changed',
        'account_activated' => 'Account reactivated',
        'account_deactivated' => 'Account deactivated',
        'content_permission_changed' => 'Content permission changed',
        'setting_changed' => 'Setting changed',
        _ => action,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final log = ref.watch(auditLogProvider);
    // Names for actor / target ids (admins can read basic profiles).
    final users = ref.watch(managedUsersProvider(const UserQuery())).value ?? const [];
    final names = {for (final u in users) u.id: u.fullName};
    return Scaffold(
      appBar: AppBar(title: const Text('Audit log')),
      body: AsyncValueView<List<AuditEntry>>(
        value: log,
        onRetry: () => ref.invalidate(auditLogProvider),
        isEmpty: (l) => l.isEmpty,
        empty: const EmptyView(title: 'No administrative actions yet', icon: Icons.history_rounded),
        data: (list) => ListView.separated(
          padding: AppSpacing.page,
          itemCount: list.length,
          separatorBuilder: (_, _) => const Divider(),
          itemBuilder: (context, i) {
            final e = list[i];
            final detail = e.details.isEmpty ? null : const JsonEncoder().convert(e.details);
            return ResponsiveCenter(
              maxWidth: 900,
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.shield_outlined),
                title: Text(_label(e.action)),
                subtitle: Text([
                  'By ${names[e.actorId] ?? 'unknown'}',
                  if (e.targetUserId != null) 'for ${names[e.targetUserId] ?? 'a user'}',
                  ?detail,
                  AppDates.dayTime(e.createdAt),
                ].join('\n')),
                isThreeLine: true,
              ),
            );
          },
        ),
      ),
    );
  }
}

class AppSettingsScreen extends ConsumerWidget {
  const AppSettingsScreen({super.key});

  Future<void> _edit(BuildContext context, WidgetRef ref, AppSetting s) async {
    if (s.value is bool) {
      final next = !(s.value as bool);
      final ok = await showConfirmDialog(
        context,
        title: 'Change "${s.key}"?',
        message: 'Set to ${next ? 'ON' : 'OFF'}. This is recorded in the audit log.',
        confirmLabel: 'Save',
      );
      if (!ok || !context.mounted) return;
      await _save(context, ref, s.key, next);
      return;
    }
    final controller = TextEditingController(text: s.display);
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.key),
        content: TextField(controller: controller, maxLines: 3, maxLength: 200, decoration: InputDecoration(helperText: s.description)),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(controller.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    controller.dispose();
    if (value == null || value.isEmpty || !context.mounted) return;
    await _save(context, ref, s.key, value);
  }

  Future<void> _save(BuildContext context, WidgetRef ref, String key, Object value) async {
    try {
      await ref.read(adminRepositoryProvider).updateSetting(key, value);
      ref.invalidate(appSettingsProvider);
      if (context.mounted) showAppSnack(context, 'Setting saved.');
    } catch (e) {
      if (context.mounted) showErrorSnack(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('App settings')),
      body: AsyncValueView<List<AppSetting>>(
        value: settings,
        onRetry: () => ref.invalidate(appSettingsProvider),
        data: (list) => PageBody(
          children: [
            for (final s in list)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: AppCard(
                  onTap: () => _edit(context, ref, s),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.key, style: context.text.titleSmall),
                            if (s.description != null) Text(s.description!, style: context.text.bodySmall),
                            AppSpacing.gapXxs,
                            Text(s.display, style: context.text.bodyMedium),
                          ],
                        ),
                      ),
                      Icon(s.value is bool ? Icons.toggle_on_outlined : Icons.edit_outlined),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
