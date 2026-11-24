// Live security checks against a DEVELOPMENT Supabase project, through the
// same public API the app uses (publishable key + RLS). Uses only fictional
// test accounts that you create for this purpose – never real students.
//
// Setup (once): in the dev project create three users in Authentication,
// then in the SQL editor make one of them a counsellor:
//   update public.user_roles set role = 'counsellor'
//   where user_id = (select id from auth.users where email = '<counsellor test email>');
//
// Run:
//   flutter test integration_test/supabase_security_test.dart -d <device> \
//     --dart-define-from-file=env/dev.json --dart-define-from-file=env/test_accounts.json
// env/test_accounts.json (git-ignored):
//   {"TEST_STUDENT_A": "...", "TEST_STUDENT_B": "...", "TEST_COUNSELLOR": "...", "TEST_PASSWORD": "..."}
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _url = String.fromEnvironment('SUPABASE_URL');
const _key = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
const _studentA = String.fromEnvironment('TEST_STUDENT_A');
const _studentB = String.fromEnvironment('TEST_STUDENT_B');
const _counsellor = String.fromEnvironment('TEST_COUNSELLOR');
const _password = String.fromEnvironment('TEST_PASSWORD');

final _configured = [_url, _key, _studentA, _studentB, _counsellor, _password].every((v) => v.isNotEmpty);

Future<SupabaseClient> _signedIn(String email) async {
  final c = SupabaseClient(_url, _key, authOptions: const AuthClientOptions(autoRefreshToken: false));
  await c.auth.signInWithPassword(email: email, password: _password);
  return c;
}

void main() {
  group('Supabase RLS (live)', skip: _configured ? false : 'Test accounts not configured', () {
    late SupabaseClient a;
    late SupabaseClient b;
    late SupabaseClient counsellor;
    late String journalId;

    setUpAll(() async {
      a = await _signedIn(_studentA);
      b = await _signedIn(_studentB);
      counsellor = await _signedIn(_counsellor);
      final row = await a
          .from('journal_entries')
          .insert({'title': 'RLS test', 'content': 'Private test content – safe to delete'})
          .select('id')
          .single();
      journalId = row['id'] as String;
      await a.from('mood_entries').insert({'mood': 'neutral', 'notes': 'RLS test note'});
    });

    tearDownAll(() async {
      await a.from('journal_entries').delete().eq('id', journalId);
      await a.from('mood_entries').delete().eq('notes', 'RLS test note');
      for (final c in [a, b, counsellor]) {
        await c.auth.signOut();
        await c.dispose();
      }
    });

    test('student cannot read another student\'s journal', () async {
      final rows = await b.from('journal_entries').select().eq('id', journalId);
      expect(rows, isEmpty);
    });

    test('student cannot read another student\'s mood records', () async {
      final rows = await b.from('mood_entries').select().eq('notes', 'RLS test note');
      expect(rows, isEmpty);
    });

    test('counsellor cannot read private journal content or mood notes', () async {
      expect(await counsellor.from('journal_entries').select().eq('id', journalId), isEmpty);
      expect(await counsellor.from('mood_entries').select().eq('notes', 'RLS test note'), isEmpty);
    });

    test('student cannot assign themselves a counsellor role', () async {
      await expectLater(
        b.from('user_roles').update({'role': 'counsellor'}).eq('user_id', b.auth.currentUser!.id),
        throwsA(isA<PostgrestException>()),
      );
      await expectLater(
        b.rpc('admin_set_user_role', params: {'p_user': b.auth.currentUser!.id, 'p_role': 'counsellor'}),
        throwsA(isA<PostgrestException>()),
      );
      final role = await b.from('user_roles').select('role').single();
      expect(role['role'], 'student');
    });

    test('unauthorised users cannot publish resources', () async {
      await expectLater(
        b.from('resources').insert({
          'title': 'Not allowed',
          'description': 'Student should be blocked',
          'category': 'self_esteem',
          'content': 'This insert must be rejected by RLS.',
          'published': true,
        }),
        throwsA(isA<PostgrestException>()),
      );
    });

    test('appointments follow ownership', () async {
      final mine = await b.from('appointments').select('student_id');
      for (final r in mine) {
        expect(r['student_id'], b.auth.currentUser!.id);
      }
    });
  });
}
