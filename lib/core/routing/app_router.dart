import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../features/administration/presentation/admin_dashboard_screen.dart';
import '../../features/administration/presentation/audit_and_settings_screens.dart';
import '../../features/administration/presentation/user_management_screen.dart';
import '../../features/authentication/presentation/auth_controller.dart';
import '../../features/authentication/presentation/login_screen.dart';
import '../../features/authentication/presentation/password_screens.dart';
import '../../features/authentication/presentation/privacy_screen.dart';
import '../../features/authentication/presentation/counsellor_register_screen.dart';
import '../../features/authentication/presentation/register_screen.dart';
import '../../features/authentication/presentation/splash_screen.dart';
import '../../features/authentication/presentation/welcome_screen.dart';
import '../../features/counselling/presentation/appointment_detail_screen.dart';
import '../../features/counselling/presentation/book_appointment_screen.dart';
import '../../features/counselling/presentation/counselling_home_screen.dart';
import '../../features/counsellor_dashboard/presentation/availability_screen.dart';
import '../../features/counsellor_dashboard/presentation/content_editor_screen.dart';
import '../../features/counsellor_dashboard/presentation/content_list_screen.dart';
import '../../features/counsellor_dashboard/presentation/counsellor_appointment_detail_screen.dart';
import '../../features/counsellor_dashboard/presentation/counsellor_appointments_screen.dart';
import '../../features/counsellor_dashboard/presentation/counsellor_dashboard_screen.dart';
import '../../features/counsellor_dashboard/presentation/programme_editor_screen.dart';
import '../../features/counsellor_dashboard/presentation/programme_list_screen.dart';
import '../../features/counsellor_dashboard/presentation/programme_manage_screen.dart';
import '../../features/counsellor_dashboard/presentation/reports_screen.dart';
import '../../features/journal/presentation/journal_detail_screen.dart';
import '../../features/journal/presentation/journal_editor_screen.dart';
import '../../features/journal/presentation/journal_list_screen.dart';
import '../../features/learning_hub/presentation/learning_hub_screen.dart';
import '../../features/learning_hub/presentation/resource_detail_screen.dart';
import '../../features/mood_checkin/domain/mood.dart';
import '../../features/mood_checkin/presentation/mood_analytics_screen.dart';
import '../../features/mood_checkin/presentation/mood_checkin_screen.dart';
import '../../features/mood_checkin/presentation/mood_history_screen.dart';
import '../../features/mood_checkin/presentation/mood_reflection_screen.dart';
import '../../features/mood_checkin/presentation/mood_share_screen.dart';
import '../../features/notifications/presentation/notification_settings_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/selfcare/presentation/activity_detail_screen.dart';
import '../../features/selfcare/presentation/breathing_exercise_screen.dart';
import '../../features/selfcare/presentation/completion_screen.dart';
import '../../features/selfcare/presentation/grounding_screen.dart';
import '../../features/selfcare/presentation/gratitude_screen.dart';
import '../../features/selfcare/presentation/selfcare_home_screen.dart';
import '../../features/student_dashboard/presentation/edit_profile_screen.dart';
import '../../features/student_dashboard/presentation/profile_screen.dart';
import '../../features/student_dashboard/presentation/student_dashboard_screen.dart';
import '../../features/wellbeing_activities/presentation/activities_screen.dart';
import '../../features/wellbeing_activities/presentation/feedback_screen.dart';
import '../../features/wellbeing_activities/presentation/programme_detail_screen.dart';
import '../../shared/widgets/config_needed_screen.dart';
import '../../shared/widgets/get_help_screen.dart';
import '../services/supabase_service.dart';
import '../widgets/widgets.dart';
import 'app_routes.dart';
import 'role_shell.dart';
import 'route_guard.dart';

GoRoute _r(String path, Widget Function(GoRouterState s) build, {List<RouteBase> routes = const []}) =>
    GoRoute(path: path, builder: (_, s) => build(s), routes: routes);

final _publicRoutes = <RouteBase>[
  _r(AppRoutes.splash, (_) => const SplashScreen()),
  _r(AppRoutes.welcome, (_) => const WelcomeScreen()),
  _r(AppRoutes.studentLogin, (_) => const LoginScreen()),
  _r(AppRoutes.counsellorLogin, (_) => const LoginScreen(staffPortal: true)),
  _r(AppRoutes.register, (_) => const RegisterScreen()),
  _r(AppRoutes.counsellorRegister, (_) => const CounsellorRegisterScreen()),
  _r(AppRoutes.forgotPassword, (_) => const ForgotPasswordScreen()),
  _r(AppRoutes.resetPassword, (_) => const ResetPasswordScreen()),
  _r(AppRoutes.privacy, (_) => const PrivacyScreen()),
  _r(AppRoutes.help, (_) => const GetHelpScreen()),
  _r(AppRoutes.configNeeded, (_) => const ConfigNeededScreen()),
];

final _studentShell = StatefulShellRoute.indexedStack(
  builder: (_, _, shell) => RoleShell(shell: shell, destinations: studentDestinations),
  branches: [
    StatefulShellBranch(routes: [
      _r(AppRoutes.studentHome, (_) => const StudentDashboardScreen(), routes: [
        _r('journal', (_) => const JournalListScreen(), routes: [
          _r('new', (s) => JournalEditorScreen(
                prompt: s.uri.queryParameters['prompt'],
                gratitude: s.uri.queryParameters['gratitude'] == '1',
              )),
          _r(':id', (s) => JournalDetailScreen(entryId: s.pathParameters['id']!), routes: [
            _r('edit', (s) => JournalEditorScreen(entryId: s.pathParameters['id'])),
          ]),
        ]),
        _r('learn', (_) => const LearningHubScreen(), routes: [
          _r('bookmarks', (_) => const BookmarksScreen()),
          _r(':id', (s) => ResourceDetailScreen(resourceId: s.pathParameters['id']!)),
        ]),
        _r('activities', (_) => const ActivitiesScreen(), routes: [
          _r(':id', (s) => ProgrammeDetailScreen(programmeId: s.pathParameters['id']!), routes: [
            _r('feedback', (s) => ProgrammeFeedbackScreen(programmeId: s.pathParameters['id']!)),
          ]),
        ]),
        _r('notifications', (_) => const NotificationsScreen()),
      ]),
    ]),
    StatefulShellBranch(routes: [
      _r(AppRoutes.mood, (_) => const MoodCheckinScreen(), routes: [
        _r('reflect', (s) => MoodReflectionScreen(
              initialMood: Mood.fromDb(s.uri.queryParameters['mood'] ?? Mood.neutral.dbValue),
            )),
        _r('history', (_) => const MoodHistoryScreen()),
        _r('analytics', (_) => const MoodAnalyticsScreen()),
        _r('share', (_) => const MoodShareScreen()),
      ]),
    ]),
    StatefulShellBranch(routes: [
      _r(AppRoutes.selfCare, (_) => const SelfCareHomeScreen(), routes: [
        _r('activity/:id', (s) => ActivityDetailScreen(activityId: s.pathParameters['id']!)),
        _r('breathing', (_) => const BreathingExerciseScreen()),
        _r('grounding', (_) => const GroundingScreen()),
        _r('gratitude', (_) => const GratitudeScreen()),
        _r('complete', (s) => SelfCareCompletionScreen(activityId: s.uri.queryParameters['activity'])),
      ]),
    ]),
    StatefulShellBranch(routes: [
      _r(AppRoutes.booking, (_) => const CounsellingHomeScreen(), routes: [
        _r('new', (_) => const BookAppointmentScreen()),
        _r(':id', (s) => AppointmentDetailScreen(appointmentId: s.pathParameters['id']!)),
      ]),
    ]),
    StatefulShellBranch(routes: [
      _r(AppRoutes.profile, (_) => const ProfileScreen(), routes: [
        _r('edit', (_) => const EditProfileScreen()),
        _r('notifications', (_) => const NotificationSettingsScreen()),
      ]),
    ]),
  ],
);

final _counsellorShell = StatefulShellRoute.indexedStack(
  builder: (_, _, shell) => RoleShell(shell: shell, destinations: counsellorDestinations),
  branches: [
    StatefulShellBranch(routes: [
      _r(AppRoutes.counsellorHome, (_) => const CounsellorDashboardScreen(), routes: [
        _r('availability', (_) => const AvailabilityScreen()),
        _r('reports', (_) => const ReportsScreen()),
        _r('notifications', (_) => const NotificationsScreen()),
        _r('profile', (_) => const ProfileScreen(), routes: [
          _r('edit', (_) => const EditProfileScreen()),
        ]),
      ]),
    ]),
    StatefulShellBranch(routes: [
      _r(AppRoutes.counsellorAppointments, (_) => const CounsellorAppointmentsScreen(), routes: [
        _r(':id', (s) => CounsellorAppointmentDetailScreen(appointmentId: s.pathParameters['id']!)),
      ]),
    ]),
    StatefulShellBranch(routes: [
      _r(AppRoutes.counsellorProgrammes, (_) => const CounsellorProgrammesScreen(), routes: [
        _r('new', (_) => const ProgrammeEditorScreen()),
        _r(':id', (s) => ProgrammeManageScreen(programmeId: s.pathParameters['id']!), routes: [
          _r('edit', (s) => ProgrammeEditorScreen(programmeId: s.pathParameters['id'])),
        ]),
      ]),
    ]),
    StatefulShellBranch(routes: [
      _r(AppRoutes.counsellorContent, (_) => const ContentListScreen(), routes: [
        _r('new', (_) => const ContentEditorScreen()),
        _r(':id/edit', (s) => ContentEditorScreen(resourceId: s.pathParameters['id'])),
      ]),
    ]),
  ],
);

final _adminRoutes = _r(AppRoutes.adminHome, (_) => const AdminDashboardScreen(), routes: [
  _r('users', (_) => const UserManagementScreen()),
  _r('audit', (_) => const AuditLogScreen()),
  _r('settings', (_) => const AppSettingsScreen()),
  _r('profile', (_) => const ProfileScreen(), routes: [
    _r('edit', (_) => const EditProfileScreen()),
  ]),
]);

Widget _notFound(BuildContext context, GoRouterState state) => Scaffold(
      appBar: AppBar(),
      body: EmptyView(
        title: 'Page not found',
        message: 'This page does not exist or you do not have access to it.',
        icon: Icons.explore_off_outlined,
        actionLabel: 'Go home',
        onAction: () => context.go(AppRoutes.splash),
      ),
    );

/// The app router. Re-evaluates redirects whenever the session changes.
final appRouterProvider = Provider<GoRouter>((ref) {
  // Without credentials the app shows a setup screen (and emergency help).
  if (!SupabaseService.isReady) {
    final router = GoRouter(
      initialLocation: AppRoutes.configNeeded,
      routes: _publicRoutes,
      redirect: (_, s) => AppRoutes.alwaysAllowed.contains(s.uri.path) || s.uri.path == AppRoutes.configNeeded
          ? null
          : AppRoutes.configNeeded,
      errorBuilder: _notFound,
    );
    ref.onDispose(router.dispose);
    return router;
  }

  final session = ValueNotifier<SessionState>(ref.read(authControllerProvider));
  ref.listen<SessionState>(authControllerProvider, (_, next) => session.value = next);

  final router = GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: session,
    redirect: (_, state) => redirectFor(session.value, state.uri.path),
    routes: [..._publicRoutes, _studentShell, _counsellorShell, _adminRoutes],
    errorBuilder: _notFound,
  );
  ref.onDispose(() {
    router.dispose();
    session.dispose();
  });
  return router;
});
