import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:gmi_mindspace/app.dart';
import 'package:gmi_mindspace/core/services/supabase_service.dart';
import 'package:gmi_mindspace/core/theme/app_theme.dart';
import 'package:gmi_mindspace/core/utils/failure.dart';
import 'package:gmi_mindspace/features/administration/data/admin_repository.dart';
import 'package:gmi_mindspace/features/authentication/domain/auth_repository.dart';
import 'package:gmi_mindspace/features/authentication/presentation/auth_controller.dart';
import 'package:gmi_mindspace/features/counselling/data/counselling_repository.dart';
import 'package:gmi_mindspace/features/counsellor_dashboard/data/reports_repository.dart';
import 'package:gmi_mindspace/features/mood_checkin/data/mood_repository.dart';
import 'package:gmi_mindspace/features/mood_checkin/domain/mood.dart';
import 'package:gmi_mindspace/features/notifications/data/notification_repository.dart';
import 'package:gmi_mindspace/features/notifications/presentation/notification_sync.dart';
import 'package:gmi_mindspace/features/wellbeing_activities/data/programme_repository.dart';
import 'package:gmi_mindspace/shared/models/user_profile.dart';
import 'package:material_ui/material_ui.dart';

/// Fictional accounts used only in tests.
const testPassword = 'calmMind42';
final testStudent = UserProfile(
  id: 'student-1', fullName: 'Aina Test', role: AppRole.student, isActive: true,
  email: 'aina.test@example.test', studentId: 'GMI00001',
);
final testCounsellor = UserProfile(
  id: 'counsellor-1', fullName: 'Carol Test', role: AppRole.counsellor, isActive: true,
  email: 'carol.test@example.test', canManageContent: true,
);
final testAdmin = UserProfile(
  id: 'admin-1', fullName: 'Erin Test', role: AppRole.admin, isActive: true, email: 'erin.test@example.test',
);
final testInactive = UserProfile(
  id: 'inactive-1', fullName: 'Ian Test', role: AppRole.student, isActive: false, email: 'ian.test@example.test',
);

/// In-memory auth for widget and integration tests. Behaves like the real
/// repository: verifies credentials, emits auth events, never hardcodes
/// anything into the production app.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({UserProfile? signedInAs}) : _current = signedInAs;

  final _events = StreamController<AuthEvent>.broadcast();
  final Map<String, UserProfile> accounts = {
    for (final p in [testStudent, testCounsellor, testAdmin, testInactive]) p.email!: p,
  };
  UserProfile? _current;
  int signOutCalls = 0;
  final List<String> registered = [];

  @override
  Stream<AuthEvent> get events => _events.stream;

  @override
  String? get currentUserId => _current?.id;

  @override
  Future<void> signIn({required String email, required String password}) async {
    final p = accounts[email.trim().toLowerCase()];
    if (p == null || password != testPassword) {
      throw const AppFailure('Incorrect email or password.', kind: FailureKind.auth);
    }
    _current = p;
    _events.add(AuthEvent.signedIn);
  }

  @override
  Future<bool> signUpStudent({
    required String fullName,
    required String studentId,
    required String email,
    required String password,
  }) async {
    registered.add(email);
    return true; // e-mail confirmation required
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
    _current = null;
    _events.add(AuthEvent.signedOut);
  }

  /// Simulates the refresh token expiring on the server.
  void expireSession() {
    _current = null;
    _events.add(AuthEvent.signedOut);
  }

  @override
  Future<void> sendPasswordReset(String email) async {}

  @override
  Future<void> updatePassword(String newPassword) async {}

  @override
  Future<UserProfile?> fetchCurrentProfile() async => _current;

  @override
  Future<void> updateProfile({required String fullName, String? studentId, String? programmeOfStudy}) async {
    _current = _current?.copyWith(fullName: fullName, studentId: studentId, programmeOfStudy: programmeOfStudy);
  }
}

/// Overrides every data provider the dashboards read on first paint.
List<Override> dataOverrides({List<MoodEntry> moods = const [], bool includeMoodEntries = true}) => [
      notificationSyncEnabledProvider.overrideWithValue(false),
      notificationsProvider.overrideWith((ref) async => const []),
      if (includeMoodEntries) moodEntriesProvider.overrideWith((ref) async => moods),
      myAppointmentsProvider.overrideWith((ref) async => const []),
      myRegistrationsProvider.overrideWith((ref) async => const []),
      counsellingInfoProvider.overrideWith((ref) async => const {}),
      counsellorAppointmentsProvider.overrideWith((ref) async => const []),
      counsellorStatsProvider.overrideWith((ref) async => const CounsellorStats({'pending': 3, 'confirmed': 2})),
      systemHealthProvider.overrideWith((ref) async => {'checked_at': '2026-11-23T08:00:00Z', 'students': 12}),
    ];

/// Pumps the real app (real router + redirects) with fakes.
Future<FakeAuthRepository> pumpFullApp(
  WidgetTester tester, {
  UserProfile? signedInAs,
  List<MoodEntry> moods = const [],
}) async {
  SupabaseService.debugSetReady(true);
  addTearDown(() => SupabaseService.debugSetReady(false));
  final auth = FakeAuthRepository(signedInAs: signedInAs);
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [authRepositoryProvider.overrideWithValue(auth), ...dataOverrides(moods: moods)],
      child: const GmiMindSpaceApp(),
    ),
  );
  await tester.pumpAndSettle();
  return auth;
}

/// Pumps a single screen inside the app theme.
Future<void> pumpScreen(WidgetTester tester, Widget screen, {List<Override> overrides = const []}) async {
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
        ...dataOverrides(),
        ...overrides,
      ],
      child: MaterialApp.router(
        theme: AppTheme.light,
        routerConfig: GoRouter(
          routes: [GoRoute(path: '/', builder: (_, _) => screen)],
          // Any navigation away from the screen under test lands here.
          errorBuilder: (_, state) => Scaffold(body: Text('Navigated to ${state.uri}')),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Sets a logical screen size for responsive tests.
void setScreenSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}
