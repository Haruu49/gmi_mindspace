// End-to-end UI workflows on a real device/emulator with in-memory data:
//   flutter test integration_test/app_flow_test.dart -d <device-id>
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gmi_mindspace/app.dart';
import 'package:gmi_mindspace/core/services/supabase_service.dart';
import 'package:gmi_mindspace/features/authentication/presentation/auth_controller.dart';
import 'package:gmi_mindspace/features/journal/data/journal_repository.dart';
import 'package:gmi_mindspace/features/mood_checkin/data/mood_repository.dart';
import 'package:gmi_mindspace/features/mood_checkin/domain/mood.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';

import '../test/helpers/fake_repos.dart';
import '../test/helpers/test_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<(FakeAuthRepository, FakeMoodRepository, FakeJournalRepository)> launch(WidgetTester tester) async {
    SupabaseService.debugSetReady(true);
    addTearDown(() => SupabaseService.debugSetReady(false));
    final auth = FakeAuthRepository();
    final mood = FakeMoodRepository();
    final journal = FakeJournalRepository();
    await tester.pumpWidget(ProviderScope(
      retry: (_, _) => null,
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        ...dataOverrides(includeMoodEntries: false),
        // Use the fake repositories for the providers that read them.
        moodRepositoryProvider.overrideWithValue(mood),
        moodEntriesProvider.overrideWith((ref) => mood.fetchEntries()),
        journalRepositoryProvider.overrideWithValue(journal),
      ],
      child: const GmiMindSpaceApp(),
    ));
    await tester.pumpAndSettle();
    return (auth, mood, journal);
  }

  Future<void> signIn(WidgetTester tester, String email, {bool staff = false}) async {
    final button = find.text(staff ? 'Counsellor Login' : 'Student Login');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('login_email')), email);
    await tester.enterText(find.byKey(const Key('login_password')), testPassword);
    await tester.tap(find.byKey(const Key('login_submit')));
    await tester.pumpAndSettle();
  }

  testWidgets('student: login → mood check-in → journal entry → logout', (tester) async {
    final (auth, mood, journal) = await launch(tester);
    await signIn(tester, testStudent.email!);
    expect(find.text('Hello, Aina!'), findsOneWidget);

    // Mood check-in from the dashboard card.
    await tester.tap(find.byKey(const Key('mood_good')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('mood_notes')), 'Good class today');
    await tester.ensureVisible(find.byKey(const Key('mood_save')));
    await tester.tap(find.byKey(const Key('mood_save')));
    await tester.pumpAndSettle();
    expect(mood.saved.single.mood, Mood.good);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    // Journal entry.
    await tester.tap(find.text('Home').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('quick_journal')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('journal_new')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('journal_title')), 'Reflection');
    await tester.enterText(find.byKey(const Key('journal_content')), 'Today I learned to slow down.');
    await tester.tap(find.byKey(const Key('journal_save')));
    await tester.pumpAndSettle();
    expect(journal.entries.values.single.title, 'Reflection');

    // Logout.
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

  testWidgets('counsellor: login lands on the counsellor dashboard, not student screens', (tester) async {
    await launch(tester);
    await signIn(tester, testCounsellor.email!, staff: true);
    expect(find.text('Pending requests'), findsOneWidget);
    expect(find.text('Appointments'), findsWidgets);
    expect(find.text('Hello, Aina!'), findsNothing);
  });

  testWidgets('session expiry returns to the welcome screen', (tester) async {
    final (auth, _, _) = await launch(tester);
    await signIn(tester, testStudent.email!);
    auth.expireSession();
    await tester.pumpAndSettle();
    expect(find.text('Your session has ended. Please sign in again.'), findsOneWidget);
  });
}
