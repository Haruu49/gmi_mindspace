import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/widgets.dart';
import '../../../shared/models/user_profile.dart';
import '../../authentication/presentation/auth_controller.dart';
import '../data/admin_repository.dart';

class UserManagementScreen extends ConsumerStatefulWidget {
  const UserManagementScreen({super.key});

  @override
  ConsumerState<UserManagementScreen> createState() => _State();
}

class _State extends ConsumerState<UserManagementScreen> {
  UserQuery _query = const UserQuery();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearch(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) setState(() => _query = UserQuery(search: v, role: _query.role));
    });
  }

  Future<void> _openActions(ManagedUser u) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _UserActionsSheet(user: u, onChanged: () => ref.invalidate(managedUsersProvider)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final users = ref.watch(managedUsersProvider(_query));
    final me = ref.watch(currentProfileProvider)?.id;
    return Scaffold(
      appBar: AppBar(title: const Text('User accounts')),
      body: ListView(
        padding: AppSpacing.page,
        children: [
          ResponsiveCenter(
            maxWidth: 900,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  onChanged: _onSearch,
                  decoration: const InputDecoration(
                    hintText: 'Search by name, email or student ID',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                ),
                AppSpacing.gapSm,
                Wrap(
                  spacing: AppSpacing.xs,
                  children: [
                    ChoiceChip(
                      label: const Text('All roles'),
                      selected: _query.role == null,
                      onSelected: (_) => setState(() => _query = UserQuery(search: _query.search)),
                    ),
                    for (final r in AppRole.values)
                      ChoiceChip(
                        label: Text(r.label),
                        selected: _query.role == r,
                        onSelected: (_) => setState(() => _query = UserQuery(search: _query.search, role: r)),
                      ),
                  ],
                ),
                AppSpacing.gapMd,
                InfoBanner(
                  message: 'New counsellors: invite them from the Supabase dashboard (Authentication › Users), '
                      'then assign the Counsellor role here.',
                  color: context.colors.secondary,
                ),
                AppSpacing.gapMd,
                users.when(
                  loading: () => const Padding(padding: EdgeInsets.all(AppSpacing.xl), child: LoadingView()),
                  error: (e, _) => SizedBox(height: 280, child: ErrorView(error: e, onRetry: () => ref.invalidate(managedUsersProvider))),
                  data: (list) => list.isEmpty
                      ? const SizedBox(height: 200, child: EmptyView(title: 'No accounts found', icon: Icons.person_search_outlined))
                      : Column(
                          children: [
                            for (final u in list)
                              Padding(
                                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                                child: AppCard(
                                  onTap: u.id == me ? null : () => _openActions(u),
                                  padding: const EdgeInsets.all(AppSpacing.sm),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: u.isActive ? context.colors.primaryContainer : context.colors.surfaceContainerHigh,
                                        child: Icon(switch (u.role) {
                                          AppRole.student => Icons.school_outlined,
                                          AppRole.counsellor => Icons.volunteer_activism_outlined,
                                          AppRole.admin => Icons.admin_panel_settings_outlined,
                                        }),
                                      ),
                                      AppSpacing.gapSm,
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(u.fullName + (u.id == me ? ' (you)' : ''), style: context.text.titleSmall),
                                            Text([u.email ?? '', if (u.studentId != null) u.studentId!].join(' · '),
                                                style: context.text.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                                            AppSpacing.gapXxs,
                                            Wrap(
                                              spacing: AppSpacing.xs,
                                              children: [
                                                StatusChip(label: u.role.label, color: context.colors.primary),
                                                if (!u.isActive) const StatusChip(label: 'Deactivated', color: AppColors.error),
                                                if (u.role == AppRole.counsellor && !u.canManageContent)
                                                  const StatusChip(label: 'No content access', color: AppColors.warning),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (u.id != me) const Icon(Icons.more_vert_rounded),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UserActionsSheet extends ConsumerStatefulWidget {
  const _UserActionsSheet({required this.user, required this.onChanged});

  final ManagedUser user;
  final VoidCallback onChanged;

  @override
  ConsumerState<_UserActionsSheet> createState() => _UserActionsSheetState();
}

class _UserActionsSheetState extends ConsumerState<_UserActionsSheet> {
  bool _busy = false;

  Future<void> _do(Future<void> Function() action, String done) async {
    setState(() => _busy = true);
    try {
      await action();
      widget.onChanged();
      if (!mounted) return;
      Navigator.of(context).pop();
      showAppSnack(context, done);
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _changeRole(AppRole role) async {
    final u = widget.user;
    final ok = await showConfirmDialog(
      context,
      title: 'Change role to ${role.label}?',
      message: '${u.fullName} will get ${role.label.toLowerCase()} access the next time the app refreshes. '
          'This is recorded in the audit log.',
      confirmLabel: 'Change role',
      destructive: role == AppRole.admin,
      typeToConfirm: role == AppRole.admin ? 'ADMIN' : null,
    );
    if (ok) await _do(() => ref.read(adminRepositoryProvider).setRole(u.id, role), 'Role updated.');
  }

  Future<void> _toggleActive() async {
    final u = widget.user;
    final deactivate = u.isActive;
    final ok = await showConfirmDialog(
      context,
      title: deactivate ? 'Deactivate account?' : 'Reactivate account?',
      message: deactivate
          ? '${u.fullName} will immediately lose access to MindSpace data. Their private content is kept, not deleted.'
          : '${u.fullName} will be able to sign in again.',
      confirmLabel: deactivate ? 'Deactivate' : 'Reactivate',
      destructive: deactivate,
      typeToConfirm: deactivate ? 'DEACTIVATE' : null,
    );
    if (ok) {
      await _do(() => ref.read(adminRepositoryProvider).setActive(u.id, !u.isActive),
          deactivate ? 'Account deactivated.' : 'Account reactivated.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.user;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(u.fullName, style: context.text.titleLarge),
            Text(u.email ?? '', style: context.text.bodySmall),
            Text(
              'Joined ${AppDates.day(u.createdAt)}'
              '${u.lastSignInAt == null ? '' : ' · last sign-in ${AppDates.relative(u.lastSignInAt!)}'}',
              style: context.text.bodySmall,
            ),
            const SectionHeader(title: 'Role'),
            SegmentedButton<AppRole>(
              segments: [for (final r in AppRole.values) ButtonSegment(value: r, label: Text(r.label))],
              selected: {u.role},
              onSelectionChanged: _busy ? null : (s) => _changeRole(s.first),
            ),
            if (u.role == AppRole.counsellor) ...[
              AppSpacing.gapSm,
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Can manage Learning Hub content'),
                value: u.canManageContent,
                onChanged: _busy
                    ? null
                    : (v) => _do(() => ref.read(adminRepositoryProvider).setContentPermission(u.id, v), 'Permission updated.'),
              ),
            ],
            AppSpacing.gapMd,
            u.isActive
                ? AppButton.danger(label: 'Deactivate account', icon: Icons.person_off_outlined, isLoading: _busy, onPressed: _toggleActive)
                : AppButton(label: 'Reactivate account', icon: Icons.person_add_alt_outlined, isLoading: _busy, onPressed: _toggleActive),
          ],
        ),
      ),
    );
  }
}
