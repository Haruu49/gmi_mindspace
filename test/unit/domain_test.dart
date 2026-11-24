import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gmi_mindspace/core/utils/failure.dart';
import 'package:gmi_mindspace/features/journal/domain/journal_entry.dart';
import 'package:gmi_mindspace/features/mood_checkin/domain/mood.dart';
import 'package:gmi_mindspace/features/selfcare/domain/selfcare_content.dart';
import 'package:gmi_mindspace/shared/models/user_profile.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

MoodEntry _e(Mood m, DateTime at, [MoodReason? r]) =>
    MoodEntry(id: '${at.millisecondsSinceEpoch}', mood: m, createdAt: at, reason: r);

void main() {
  group('MoodStats', () {
    final now = DateTime(2026, 11, 20, 12);

    test('counts, most common mood and top reason', () {
      final s = MoodStats([
        _e(Mood.good, now, MoodReason.academic),
        _e(Mood.good, now.subtract(const Duration(days: 1)), MoodReason.academic),
        _e(Mood.stressed, now.subtract(const Duration(days: 2)), MoodReason.family),
      ]);
      expect(s.counts[Mood.good], 2);
      expect(s.counts[Mood.sad], 0);
      expect(s.mostCommon, Mood.good);
      expect(s.topReason, MoodReason.academic);
    });

    test('daily averages leave gaps for days without check-ins', () {
      final s = MoodStats([
        _e(Mood.veryHappy, now),
        _e(Mood.neutral, now),
        _e(Mood.sad, now.subtract(const Duration(days: 2))),
      ]);
      final avg = s.dailyAverages(3, now: now);
      expect(avg, [2.0, null, 4.0]);
    });

    test('streak counts consecutive days ending today or yesterday', () {
      final s = MoodStats([
        _e(Mood.good, now.subtract(const Duration(days: 1))),
        _e(Mood.good, now.subtract(const Duration(days: 2))),
        _e(Mood.good, now.subtract(const Duration(days: 4))),
      ]);
      expect(s.streak(now: now), 2);
      expect(MoodStats(const []).streak(now: now), 0);
    });

    test('empty stats are safe', () {
      final s = MoodStats(const []);
      expect(s.mostCommon, isNull);
      expect(s.topReason, isNull);
    });

    test('every mood has prompts and the db mapping round-trips', () {
      for (final m in Mood.values) {
        expect(m.prompts, isNotEmpty);
        expect(Mood.fromDb(m.dbValue), m);
      }
    });
  });

  group('AppFailure', () {
    test('network errors become a friendly offline message', () {
      final f = AppFailure.from(const SocketException('Failed host lookup'));
      expect(f.kind, FailureKind.network);
      expect(f.message, contains('offline'));
    });

    test('double booking conflict', () {
      final f = AppFailure.from(const PostgrestException(message: 'conflicting key', code: '23P01'));
      expect(f.kind, FailureKind.conflict);
      expect(f.message, contains('slot'));
    });

    test('RLS denial never leaks database details', () {
      final f = AppFailure.from(
          const PostgrestException(message: 'new row violates row-level security policy for table "x"', code: '42501'));
      expect(f.kind, FailureKind.permission);
      expect(f.message, isNot(contains('row-level')));
    });

    test('duplicate registration message', () {
      final f = AppFailure.from(const PostgrestException(
          message: 'duplicate key value violates unique constraint "programme_registrations_unique"', code: '23505'));
      expect(f.message, contains('already registered'));
    });

    test('invalid credentials and expired sessions', () {
      expect(AppFailure.from(const AuthException('Invalid login credentials')).message, 'Incorrect email or password.');
      expect(AppFailure.from(const AuthException('JWT expired')).kind, FailureKind.sessionExpired);
    });

    test('unknown errors get a generic message', () {
      expect(AppFailure.from(StateError('boom')).message, 'Something went wrong. Please try again.');
    });
  });

  group('content and models', () {
    test('journal prompt rotates daily through the five prompts', () {
      final seen = {for (var d = 0; d < 5; d++) JournalPrompts.forToday(DateTime(2026, 1, 1 + d))};
      expect(seen.length, 5);
    });

    test('self-care library covers all seven categories with unique ids', () {
      final cats = SelfCareLibrary.activities.map((a) => a.category).toSet();
      expect(cats, SelfCareCategory.values.toSet());
      final ids = SelfCareLibrary.activities.map((a) => a.id).toList();
      expect(ids.toSet().length, ids.length);
      expect(SelfCareLibrary.byId('calm-breathing')?.kind, ActivityKind.breathing);
    });

    test('self-care wording never claims to treat or cure', () {
      for (final a in SelfCareLibrary.activities) {
        final text = '${a.title} ${a.summary} ${a.steps.join(' ')} ${a.tip ?? ''}'.toLowerCase();
        expect(text, isNot(contains('cure')));
        expect(text, isNot(contains('treat')));
        expect(text, isNot(contains('diagnos')));
      }
    });

    test('user profile initials and unknown roles', () {
      final p = UserProfile.fromRows(
        {'id': '1', 'full_name': 'Nur Aisyah Binti Ali', 'is_active': true},
        {'role': 'superuser'},
      );
      expect(p.initials, 'NA');
      expect(p.firstName, 'Nur');
      expect(p.role, AppRole.student, reason: 'unknown roles fall back to least privilege');
    });
  });
}
