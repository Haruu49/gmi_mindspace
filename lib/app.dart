import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'core/constants/app_constants.dart';
import 'core/routing/app_router.dart';
import 'core/services/supabase_service.dart';
import 'core/theme/app_theme.dart';
import 'features/notifications/presentation/notification_sync.dart';

/// Root widget: theme, router and (when configured) notification sync.
class GmiMindSpaceApp extends ConsumerWidget {
  const GmiMindSpaceApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: router,
      builder: (context, child) {
        final content = child ?? const SizedBox.shrink();
        return SupabaseService.isReady ? NotificationSync(child: content) : content;
      },
    );
  }
}
