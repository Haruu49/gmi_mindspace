import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/widgets.dart';
import '../../../shared/models/user_profile.dart';
import '../../../shared/widgets/user_avatar.dart';
import '../../authentication/presentation/auth_controller.dart';

/// Account screen shared by students (Profile tab) and staff.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Sign out?',
      message: 'You will need your email and password to sign in again.',
      confirmLabel: 'Sign out',
    );
    if (!ok) return;
    try {
      await ref.read(authControllerProvider.notifier).signOut();
    } catch (e) {
      if (context.mounted) showErrorSnack(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider);
    if (profile == null) return const Scaffold(body: LoadingView());
    final isStudent = profile.role == AppRole.student;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: PageBody(
        children: [
          AppCard(
            child: Row(
              children: [
                UserAvatar(profile: profile, radius: 32),
                AppSpacing.gapMd,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(profile.fullName, style: context.text.titleLarge),
                      if (profile.email != null) Text(profile.email!, style: context.text.bodySmall),
                      AppSpacing.gapXxs,
                      StatusChip(label: profile.role.label, color: context.colors.primary),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (isStudent) ...[
            AppSpacing.gapSm,
            AppCard(
              child: Column(
                children: [
                  DetailRow(icon: Icons.badge_outlined, label: 'Student ID', value: profile.studentId ?? 'Not set'),
                  DetailRow(
                    icon: Icons.school_outlined,
                    label: 'Programme of study',
                    value: profile.programmeOfStudy ?? 'Not set',
                  ),
                ],
              ),
            ),
          ],
          const SectionHeader(title: 'Account'),
          _Tile(
            icon: Icons.edit_outlined,
            title: 'Edit profile',
            onTap: () => context.push(switch (profile.role) {
              AppRole.student => AppRoutes.profileEdit,
              AppRole.counsellor => AppRoutes.counsellorProfileEdit,
              AppRole.admin => AppRoutes.adminProfileEdit,
            }),
          ),
          _Tile(icon: Icons.password_rounded, title: 'Change password', onTap: () => _changePassword(context, ref)),
          if (isStudent) ...[
            _Tile(
              icon: Icons.notifications_none_rounded,
              title: 'Notification settings',
              onTap: () => context.push(AppRoutes.notificationSettings),
            ),
            _Tile(icon: Icons.share_outlined, title: 'Mood sharing', onTap: () => context.go(AppRoutes.moodShare)),
          ],
          const SectionHeader(title: 'Support & privacy'),
          _Tile(icon: Icons.shield_outlined, title: 'Your privacy', onTap: () => context.push(AppRoutes.privacy)),
          _Tile(
            icon: Icons.support_rounded,
            title: 'Get Help Now',
            color: context.colors.error,
            onTap: () => context.push(AppRoutes.help),
          ),
          AppSpacing.gapLg,
          AppButton.outline(
            key: const Key('profile_sign_out'),
            label: 'Sign out',
            icon: Icons.logout_rounded,
            onPressed: () => _signOut(context, ref),
          ),
          AppSpacing.gapMd,
          Text('${AppConstants.appName} · ${AppConstants.tagline}',
              style: context.text.bodySmall, textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Future<void> _changePassword(BuildContext context, WidgetRef ref) async {
    final changed = await showDialog<bool>(context: context, builder: (_) => const _ChangePasswordDialog());
    if (changed == true && context.mounted) showAppSnack(context, 'Password updated.');
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.icon, required this.title, required this.onTap, this.color});

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        child: Row(
          children: [
            Icon(icon, color: color ?? context.colors.primary),
            AppSpacing.gapMd,
            Expanded(child: Text(title, style: context.text.titleSmall)),
            Icon(Icons.chevron_right_rounded, color: context.colors.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _ChangePasswordDialog extends ConsumerStatefulWidget {
  const _ChangePasswordDialog();

  @override
  ConsumerState<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends ConsumerState<_ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(authControllerProvider.notifier).changePassword(_password.text);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Change password'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppTextField(
                controller: _password,
                label: 'New password',
                isPassword: true,
                validator: Validators.newPassword,
              ),
              AppSpacing.gapSm,
              AppTextField(
                controller: _confirm,
                label: 'Confirm new password',
                isPassword: true,
                validator: Validators.confirmPassword(() => _password.text),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.of(context).pop(false), child: const Text('Cancel')),
        FilledButton(onPressed: _saving ? null : _save, child: const Text('Save')),
      ],
    );
  }
}
