// Live end-to-end smoke test: the REAL app against the DEVELOPMENT Supabase
// project, signed in with fictional test accounts. It writes a mood entry and
// a journal entry, checks they reached the database, and deletes them again.
//
//   flutter test integration_test/live_smoke_test.dart -d <device-id> \
//     --dart-define-from-file=env/dev.json \
//     --dart-define-from-file=env/test_accounts.json
//
// env/test_accounts.json is git-ignored. Never use real student accounts.
import 'package:flutter_test/flutter_test.dart';
import 'package:gmi_mindspace/main.dart' as app;
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _student = String.fromEnvironment('TEST_STUDENT_A');
const _counsellor = String.fromEnvironment('TEST_COUNSELLOR');
const _password = String.fromEnvironment('TEST_PASSWORD');
const _configured = _student != '' && _counsellor != '' && _password != '';

/// Phrases shown by the app's error views. None may appear on a working screen.
const _errorPhrases = [
  'Something went wrong',
  'could not complete',
  'You do not have permission',
  'You seem to be offline',
  'not set up yet',
];

Future<void> _pumpUntil(WidgetTester tester, Finder finder,
    {Duration timeout = const Duration(seconds: 30)}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 250));
    if (finder.evaluate().isNotEmpty) return;
  }
  fail('Timed out waiting for $finder');
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await _pumpUntil(tester, finder);
  await tester.ensureVisible(finder.first);
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(finder.first);
  await tester.pump(const Duration(milliseconds: 600));
}

void _expectNoErrors(String where) {
  for (final p in _errorPhrases) {
    expect(find.textContaining(p), findsNothing, reason: 'error "$p" shown on $where');
  }
}

Future<void> _settleBriefly(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

Future<void> _tab(WidgetTester tester, String label) async {
  await _tap(tester, find.text(label).last);
  await _settleBriefly(tester);
}

/// Home keeps its own page stack; tapping it while active returns to the
/// dashboard (standard tab behaviour), so tap twice.
Future<void> _home(WidgetTester tester) async {
  await _tab(tester, 'Home');
  await _tab(tester, 'Home');
}

Future<void> _signIn(WidgetTester tester, String email, {bool staff = false}) async {
  await _tap(tester, find.text(staff ? 'Counsellor Login' : 'Student Login'));
  await _pumpUntil(tester, find.byKey(const Key('login_email')));
  await tester.enterText(find.byKey(const Key('login_email')), email);
  await tester.enterText(find.byKey(const Key('login_password')), _password);
  await _tap(tester, find.byKey(const Key('login_submit')));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('live: student modules and counsellor login against the dev database',
      skip: !_configured, (tester) async {
    final marker = 'live-smoke-${DateTime.now().millisecondsSinceEpoch}';
    await app.main();
    final db = Supabase.instance.client;
    // Start signed out, whatever a previous run left behind.
    await db.auth.signOut();
    await _settleBriefly(tester);

    // ---- Login + database connectivity -------------------------------------
    await _signIn(tester, _student);
    await _pumpUntil(tester, find.text('Hello, Test!'));
    _expectNoErrors('student dashboard');
    expect(db.auth.currentSession, isNotNull);

    // ---- 1. Mood Check-in (writes to mood_entries) -------------------------
    await _tap(tester, find.byKey(const Key('mood_good')));
    await _pumpUntil(tester, find.byKey(const Key('mood_notes')));
    await tester.enterText(find.byKey(const Key('mood_notes')), marker);
    await _tap(tester, find.byKey(const Key('mood_save')));
    await _pumpUntil(tester, find.text('Done'));
    final moods = await db.from('mood_entries').select('id, mood').eq('notes', marker);
    expect(moods, hasLength(1), reason: 'mood entry reached the database');
    expect(moods.single['mood'], 'good');
    await _tap(tester, find.text('Done'));
    await _settleBriefly(tester);

    // ---- 2. My Journal (writes to journal_entries) -------------------------
    await _home(tester);
    await _tap(tester, find.byKey(const Key('quick_journal')));
    await _tap(tester, find.byKey(const Key('journal_new')));
    await _pumpUntil(tester, find.byKey(const Key('journal_title')));
    await tester.enterText(find.byKey(const Key('journal_title')), marker);
    await tester.enterText(find.byKey(const Key('journal_content')), 'Live smoke test entry, safe to delete.');
    await _tap(tester, find.byKey(const Key('journal_save')));
    await _settleBriefly(tester);
    final journals = await db.from('journal_entries').select('id').eq('title', marker);
    expect(journals, hasLength(1), reason: 'journal entry reached the database');
    _expectNoErrors('journal');

    // ---- 3. Self-care Corner ----------------------------------------------
    await _tab(tester, 'Self-care');
    _expectNoErrors('self-care home');
    await _tap(tester, find.text('Breathe'));
    await _tap(tester, find.byKey(const Key('breathing_start')));
    await _tap(tester, find.byKey(const Key('breathing_stop')));
    await tester.pageBack();
    await _settleBriefly(tester);

    // ---- 4. Counselling Appointment (request form + appointment list) ------
    // Counsellor names appear only next to free time slots, and the fictional
    // counsellor has none, so this checks the form loads without errors.
    await _tab(tester, 'Booking');
    _expectNoErrors('counselling home');
    await _tap(tester, find.byKey(const Key('booking_new')));
    await _pumpUntil(tester, find.text('Request appointment'));
    await _pumpUntil(tester, find.text('2. Pick a date'));
    await _settleBriefly(tester);
    _expectNoErrors('booking form');
    await tester.pageBack();
    await _settleBriefly(tester);

    // ---- 5. Mental Health Learning Hub ------------------------------------
    await _home(tester);
    await _tap(tester, find.byKey(const Key('quick_learn')));
    await _pumpUntil(tester, find.text('Explore topics'));
    _expectNoErrors('learning hub');
    await tester.pageBack();
    await _settleBriefly(tester);

    // ---- 6. Well-being Activities -----------------------------------------
    await _tap(tester, find.text('Well-being Activities'));
    await _pumpUntil(tester, find.widgetWithText(AppBar, 'Well-being Activities'));
    await _settleBriefly(tester);
    _expectNoErrors('activities');
    await tester.pageBack();
    await _settleBriefly(tester);

    // ---- Clean up the test rows (owner-only RLS allows this) ---------------
    await db.from('mood_entries').delete().eq('notes', marker);
    await db.from('journal_entries').delete().eq('title', marker);
    expect(await db.from('mood_entries').select('id').eq('notes', marker), isEmpty);
    expect(await db.from('journal_entries').select('id').eq('title', marker), isEmpty);

    // ---- Sign out ---------------------------------------------------------
    await _tab(tester, 'Profile');
    await _tap(tester, find.byKey(const Key('profile_sign_out')));
    await _tap(tester, find.widgetWithText(FilledButton, 'Sign out'));
    await _pumpUntil(tester, find.text('Student Login'));
    expect(db.auth.currentSession, isNull);

    // ---- Counsellor login routes to the counsellor area --------------------
    await _signIn(tester, _counsellor, staff: true);
    await _pumpUntil(tester, find.text('Pending requests'));
    _expectNoErrors('counsellor dashboard');
    expect(find.text('Hello, Test!'), findsNothing);
    await db.auth.signOut();
    await _settleBriefly(tester);
  });
}
