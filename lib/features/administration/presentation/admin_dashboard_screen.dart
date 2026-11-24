import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/widgets.dart';
import '../../../shared/widgets/user_avatar.dart';
import '../../authentication/presentation/auth_controller.dart';
import '../../counsellor_dashboard/presentation/counsellor_dashboard_screen.dart' show StatCard;
import '../data/admin_repository.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider);
    final health = ref.watch(systemHealthProvider);
    return Scaffold(
      appBar: AppBar(
        title: const BrandHeader(logoSize: 30),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => context.push(AppRoutes.adminProfile),
              child: Semantics(label: 'Profile', button: true, child: UserAvatar(profile: profile, radius: 18)),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          final _ = await ref.refresh(systemHealthProvider.future);
        },
        child: ListView(
          padding: AppSpacing.page,
          children: [
            ResponsiveCenter(
              maxWidth: 900,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Administration', style: context.text.headlineSmall),
                  AppSpacing.gapXs,
                  const InfoBanner(
                    icon: Icons.admin_panel_settings_outlined,
                    message: 'You manage accounts, roles and settings. Student journals, mood records '
                        'and counselling notes are not accessible to administrators. Every change you '
                        'make is recorded in the audit log.',
                  ),
                  const SectionHeader(title: 'System health'),
                  health.when(
                    loading: () => const SizedBox(height: 160, child: LoadingView()),
                    error: (e, _) => SizedBox(height: 260, child: ErrorView(error: e, onRetry: () => ref.invalidate(systemHealthProvider))),
                    data: (h) {
                      String v(String k) => '${h[k] ?? 0}';
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.check_circle_rounded, color: AppColors.success),
                              AppSpacing.gapXs,
                              Expanded(
                                child: Text(
                                  'Database reachable · checked ${AppDates.time(DateTime.parse('${h['checked_at']}'))}',
                                  style: context.text.bodyMedium,
                                ),
                              ),
                            ],
                          ),
                          AppSpacing.gapSm,
                          ResponsiveGrid(
                            minTileWidth: 150,
                            children: [
                              StatCard(label: 'Students', value: v('students'), icon: Icons.school_outlined, color: context.colors.primary),
                              StatCard(label: 'Counsellors', value: v('counsellors'), icon: Icons.volunteer_activism_outlined, color: AppColors.sageDeep),
                              StatCard(label: 'Administrators', value: v('admins'), icon: Icons.admin_panel_settings_outlined, color: AppColors.lavenderDeep),
                              StatCard(label: 'Inactive accounts', value: v('inactive_accounts'), icon: Icons.person_off_outlined, color: AppColors.slate),
                              StatCard(label: 'New sign-ups (7d)', value: v('signups_7d'), icon: Icons.person_add_alt_outlined, color: AppColors.success),
                              StatCard(label: 'Pending appointments', value: v('pending_appointments'), icon: Icons.hourglass_top_rounded, color: AppColors.warning),
                              StatCard(label: 'Database size', value: '${v('database_size_mb')} MB', icon: Icons.storage_rounded, color: const Color(0xFF4F7FA8)),
                              StatCard(label: 'Admin actions (24h)', value: v('audit_events_24h'), icon: Icons.history_rounded, color: AppColors.lavender),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                  const SectionHeader(title: 'Manage'),
                  ResponsiveGrid(
                    minTileWidth: 150,
                    children: [
                      FeatureCard(
                        icon: Icons.manage_accounts_outlined,
                        title: 'User accounts',
                        subtitle: 'Roles, activation, permissions',
                        onTap: () => context.push(AppRoutes.adminUsers),
                      ),
                      FeatureCard(
                        icon: Icons.history_rounded,
                        title: 'Audit log',
                        subtitle: 'Administrative actions',
                        tint: AppColors.sageSoft,
                        iconColor: AppColors.sageDeep,
                        onTap: () => context.push(AppRoutes.adminAudit),
                      ),
                      FeatureCard(
                        icon: Icons.tune_rounded,
                        title: 'App settings',
                        subtitle: 'Hours, messages, maintenance',
                        tint: AppColors.peachSoft,
                        iconColor: const Color(0xFFC07A45),
                        onTap: () => context.push(AppRoutes.adminSettings),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
