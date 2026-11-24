import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/supabase_service.dart';
import '../../../core/utils/failure.dart';
import '../domain/mood.dart';

/// Data access for the student's own mood check-ins. RLS guarantees every
/// query only ever touches the signed-in user's rows.
class MoodRepository {
  MoodRepository(this._db);

  final SupabaseClient _db;

  Future<List<MoodEntry>> fetchEntries({int days = 90}) => guard(() async {
        final since = DateTime.now().toUtc().subtract(Duration(days: days));
        final rows = await _db
            .from('mood_entries')
            .select('id, mood, reason, notes, created_at')
            .gte('created_at', since.toIso8601String())
            .order('created_at', ascending: false)
            .limit(1000);
        return rows.map(MoodEntry.fromJson).toList();
      });

  Future<MoodEntry> addEntry({required Mood mood, MoodReason? reason, String? notes}) =>
      guard(() async {
        final row = await _db
            .from('mood_entries')
            .insert({
              'mood': mood.dbValue,
              'reason': reason?.dbValue,
              'notes': (notes?.trim().isEmpty ?? true) ? null : notes!.trim(),
            })
            .select('id, mood, reason, notes, created_at')
            .single();
        return MoodEntry.fromJson(row);
      });

  Future<void> deleteEntry(String id) =>
      guard(() => _db.from('mood_entries').delete().eq('id', id));

  // ---- Consent to share a SUMMARY (counts only) ----

  Future<List<CounsellorOption>> listCounsellors() => guard(() async {
        final rows = await _db.rpc('list_counsellors') as List<dynamic>;
        return rows
            .cast<Map<String, dynamic>>()
            .map((r) => CounsellorOption(id: r['id'] as String, name: r['full_name'] as String))
            .toList();
      });

  Future<List<MoodShareConsent>> fetchConsents() => guard(() async {
        final rows = await _db
            .from('mood_share_consents')
            .select('id, counsellor_id, period_days, created_at, expires_at, revoked_at')
            .order('created_at', ascending: false);
        return rows.map(MoodShareConsent.fromJson).toList();
      });

  Future<void> grantConsent({required String counsellorId, required int periodDays}) =>
      guard(() => _db.from('mood_share_consents').insert({
            'counsellor_id': counsellorId,
            'period_days': periodDays,
          }));

  Future<void> revokeConsent(String id) => guard(() => _db
      .from('mood_share_consents')
      .update({'revoked_at': DateTime.now().toUtc().toIso8601String()})
      .eq('id', id));
}

final moodRepositoryProvider = Provider<MoodRepository>(
  (ref) => MoodRepository(ref.watch(supabaseClientProvider)),
);

/// Last 90 days of the user's own entries, newest first.
final moodEntriesProvider = FutureProvider.autoDispose<List<MoodEntry>>(
  (ref) => ref.watch(moodRepositoryProvider).fetchEntries(),
);

/// Today's most recent check-in, if any.
final todayMoodProvider = Provider.autoDispose<AsyncValue<MoodEntry?>>((ref) {
  return ref.watch(moodEntriesProvider).whenData((entries) {
    final now = DateTime.now();
    for (final e in entries) {
      final d = e.createdAt.toLocal();
      if (d.year == now.year && d.month == now.month && d.day == now.day) return e;
    }
    return null;
  });
});

final counsellorOptionsProvider = FutureProvider.autoDispose<List<CounsellorOption>>(
  (ref) => ref.watch(moodRepositoryProvider).listCounsellors(),
);

final moodConsentsProvider = FutureProvider.autoDispose<List<MoodShareConsent>>(
  (ref) => ref.watch(moodRepositoryProvider).fetchConsents(),
);
