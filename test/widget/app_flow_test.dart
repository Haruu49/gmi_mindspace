import 'package:flutter_test/flutter_test.dart';
import 'package:gmi_mindspace/core/constants/app_constants.dart';
import 'package:gmi_mindspace/features/mood_checkin/domain/mood.dart';
import 'package:material_ui/material_ui.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gmi_mindspace/app.dart';
import 'package:gmi_mindspace/core/services/supabase_service.dart';
import 'package:gmi_mindspace/features/authentication/presentation/auth_controller.dart';
import 'package:gmi_mindspace/features/mood_checkin/data/mood_repository.dart';

import '../helpers/fake_repos.dart';
import '../helpers/test_app.dart';

Future<void> _login(WidgetTester tester, String email, {bool staff = false}) async {
  await tester.ensureVisible(find.text(staff ? 'Counsellor Login' : 'Student Login'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(staff ? 'Counsellor Login' : 'Student Login'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('login_email')), email);
  await tester.enterText(find.byKey(const Key('login_password')), testPassword);
  await tester.tap(find.byKey(const Key('login_submit')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('welcome screen shows brand, tagline, description and actions', (tester) async {
    await pumpFullApp(tester);
    expect(find.text(AppConstants.appName), findsWidgets);
    expect(find.text(AppConstants.tagline), findsOneWidget);
    expect(find.text(AppConstants.description), findsOneWidget);
    expect(find.text('Student Login'), findsOneWidget);
    expect(find.text('Counsellor Login'), findsOneWidget);
    expect(find.text('Get Help Now'), findsOneWidget);
  });

  testWidgets('Get Help Now works while signed out and never claims 24/7 monitoring', (tester) async {
    await pumpFullApp(tester);
    await tester.ensureVisible(find.text('Get Help Now'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Get Help Now'));
    await tester.pumpAndSettle();
    expect(find.text('Call 999'), findsOneWidget);
    expect(find.textContaining('not monitored 24/7'), findsOneWidget);
  });

  testWidgets('student login routes to the student dashboard with their name', (tester) async {
    await pumpFullApp(tester);
    await _login(tester, testStudent.email!);
    expect(find.text('Hello, Aina!'), findsOneWidget);
    expect(find.text('How are you feeling today?'), findsOneWidget);
    for (final m in Mood.values) {
      expect(find.byKey(Key('mood_${m.dbValue}')), findsOneWidget);
    }
    for (final label in ['Home', 'Mood', 'Self-care', 'Booking', 'Profile']) {
      expect(find.text(label), findsWidgets);
    }
  });

  testWidgets('counsellor login routes to the counsellor dashboard', (tester) async {
    await pumpFullApp(tester);
    await _login(tester, testCounsellor.email!, staff: true);
    expect(find.text('Pending requests'), findsOneWidget);
    expect(find.textContaining('never available here'), findsOneWidget);
    expect(find.text('Hello, Aina!'), findsNothing);
  });

  testWidgets('administrator login routes to the admin dashboard', (tester) async {
    await pumpFullApp(tester);
    await _login(tester, testAdmin.email!, staff: true);
    expect(find.text('Administration'), findsOneWidget);
    expect(find.text('User accounts'), findsOneWidget);
  });

  testWidgets('saved session restores straight to the right dashboard', (tester) async {
    await pumpFullApp(tester, signedInAs: testStudent);
    expect(find.text('Hello, Aina!'), findsOneWidget);
  });

  testWidgets('bottom navigation switches between student tabs', (tester) async {
    await pumpFullApp(tester, signedInAs: testStudent);
    await tester.tap(find.text('Self-care').last);
    await tester.pumpAndSettle();
    expect(find.text('Self-care Corner'), findsOneWidget);
    await tester.tap(find.text('Booking').last);
    await tester.pumpAndSettle();
    expect(find.text('GMI Counselling Unit'), findsOneWidget);
    await tester.tap(find.text('Mood').last);
    await tester.pumpAndSettle();
    expect(find.text('Mood Check-in'), findsOneWidget);
    await tester.tap(find.text('Home').last);
    await tester.pumpAndSettle();
    expect(find.text('Hello, Aina!'), findsOneWidget);
  });

  testWidgets('dashboard quick access opens the journal', (tester) async {
    await pumpFullApp(tester, signedInAs: testStudent);
    await tester.tap(find.byKey(const Key('quick_journal')));
    await tester.pump();
    expect(find.text('My Journal'), findsWidgets);
  });

  testWidgets('logout returns to the welcome screen', (tester) async {
    final auth = await pumpFullApp(tester, signedInAs: testStudent);
    await tester.tap(find.text('Profile').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('profile_sign_out')));
    await tester.tap(find.byKey(const Key('profile_sign_out')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Sign out'));
    await tester.pumpAndSettle();
    expect(auth.signOutCalls, 1);
    expect(find.text('Student Login'), findsOneWidget);
  });

  testWidgets('session expiry sends the user back to welcome with a message', (tester) async {
    final auth = await pumpFullApp(tester, signedInAs: testStudent);
    auth.expireSession();
    await tester.pumpAndSettle();
    expect(find.text('Your session has ended. Please sign in again.'), findsOneWidget);
    expect(find.text('Student Login'), findsOneWidget);
  });

  testWidgets('dashboard shows today\'s mood when already checked in', (tester) async {
    await pumpFullApp(tester, signedInAs: testStudent, moods: [
      MoodEntry(id: 'm1', mood: Mood.good, createdAt: DateTime.now()),
    ]);
    expect(find.textContaining('Earlier you felt good'), findsOneWidget);
  });

  testWidgets('cross-tab navigation leaves no stale pages (mood check-in from Home)', (tester) async {
    SupabaseService.debugSetReady(true);
    addTearDown(() => SupabaseService.debugSetReady(false));
    final mood = FakeMoodRepository();
    await tester.pumpWidget(ProviderScope(
      retry: (_, _) => null,
      overrides: [
        authRepositoryProvider.overrideWithValue(FakeAuthRepository(signedInAs: testStudent)),
        ...dataOverrides(includeMoodEntries: false),
        moodRepositoryProvider.overrideWithValue(mood),
        moodEntriesProvider.overrideWith((ref) => mood.fetchEntries()),
      ],
      child: const GmiMindSpaceApp(),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('mood_good')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('mood_save')));
    await tester.tap(find.byKey(const Key('mood_save')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('Mood Check-in'), findsOneWidget, reason: 'returns to the Mood tab');
    await tester.tap(find.text('Home').last);
    await tester.pumpAndSettle();
    expect(find.text('Hello, Aina!'), findsOneWidget, reason: 'Home tab shows the dashboard, not the old reflect page');
    expect(find.textContaining('Earlier you felt good'), findsOneWidget);
  });
}
