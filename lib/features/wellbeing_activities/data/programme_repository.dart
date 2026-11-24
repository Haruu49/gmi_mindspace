import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/supabase_service.dart';
import '../../../core/utils/failure.dart';
import '../domain/programme.dart';

class ProgrammeRepository {
  ProgrammeRepository(this._db);

  final SupabaseClient _db;
  static const _cols = 'id, title, description, category, mode, location, online_url, starts_at, '
      'ends_at, capacity, status, image_url';

  String get _uid {
    final id = _db.auth.currentUser?.id;
    if (id == null) throw const AppFailure('Please sign in again.', kind: FailureKind.sessionExpired);
    return id;
  }

  // ---------------- Students ----------------

  /// Non-draft programmes from the last 60 days onwards.
  Future<List<Programme>> fetchVisible() => guard(() async {
        final since = DateTime.now().toUtc().subtract(const Duration(days: 60));
        final rows = await _db
            .from('programmes')
            .select(_cols)
            .neq('status', 'draft')
            .gte('ends_at', since.toIso8601String())
            .order('starts_at');
        return rows.map(Programme.fromJson).toList();
      });

  Future<Programme> fetchById(String id) => guard(() async {
        final row = await _db.from('programmes').select(_cols).eq('id', id).single();
        return Programme.fromJson(row);
      });

  Future<List<ProgrammeRegistration>> fetchMyRegistrations() => guard(() async {
        final rows = await _db
            .from('programme_registrations')
            .select('id, programme_id, student_id, status, registered_at, programmes($_cols)')
            .eq('student_id', _uid)
            .order('registered_at', ascending: false);
        return rows.map(ProgrammeRegistration.fromJson).toList();
      });

  Future<void> register(String programmeId) =>
      guard(() => _db.rpc('register_for_programme', params: {'p_programme': programmeId}));

  Future<void> cancelRegistration(String programmeId) =>
      guard(() => _db.rpc('cancel_programme_registration', params: {'p_programme': programmeId}));

  Future<Set<String>> fetchMyFeedbackProgrammeIds() => guard(() async {
        final rows = await _db.from('feedback').select('programme_id').eq('student_id', _uid);
        return {for (final r in rows) r['programme_id'] as String};
      });

  Future<void> submitFeedback({
    required String programmeId,
    required int rating,
    String? comment,
    bool anonymous = false,
  }) =>
      guard(() => _db.from('feedback').insert({
            'programme_id': programmeId,
            'rating': rating,
            'comment': (comment?.trim().isEmpty ?? true) ? null : comment!.trim(),
            'is_anonymous': anonymous,
          }));

  // ---------------- Counsellors ----------------

  Future<List<Programme>> fetchAll() => guard(() async {
        final rows = await _db.from('programmes').select(_cols).order('starts_at', ascending: false);
        return rows.map(Programme.fromJson).toList();
      });

  Future<String> create(ProgrammeDraft d) => guard(() async {
        final row = await _db.from('programmes').insert(d.toRow()).select('id').single();
        return row['id'] as String;
      });

  Future<void> update(String id, ProgrammeDraft d) =>
      guard(() => _db.from('programmes').update(d.toRow()).eq('id', id));

  Future<void> setStatus(String id, ProgrammeStatus status) =>
      guard(() => _db.from('programmes').update({'status': status.name}).eq('id', id));

  Future<void> deleteDraft(String id) => guard(() => _db.from('programmes').delete().eq('id', id));

  Future<List<ProgrammeRegistration>> fetchRegistrations(String programmeId) => guard(() async {
        final rows = await _db
            .from('programme_registrations')
            .select('id, programme_id, student_id, status, registered_at')
            .eq('programme_id', programmeId)
            .order('registered_at');
        final regs = rows.map(ProgrammeRegistration.fromJson).toList();
        if (regs.isEmpty) return regs;
        final profiles = await _db
            .from('profiles')
            .select('id, full_name, student_id')
            .inFilter('id', regs.map((r) => r.studentId).toList());
        final byId = {for (final p in profiles) p['id'] as String: p};
        return [
          for (final r in regs)
            r.withStudent(byId[r.studentId]?['full_name'] as String?, byId[r.studentId]?['student_id'] as String?),
        ];
      });

  Future<void> markAttendance(String registrationId, RegistrationStatus status) => guard(
        () => _db.rpc('mark_attendance', params: {'p_registration': registrationId, 'p_status': status.name}),
      );

  Future<List<ProgrammeFeedback>> fetchFeedback(String programmeId) => guard(() async {
        final rows = await _db.rpc('get_programme_feedback', params: {'p_programme': programmeId}) as List<dynamic>;
        return rows.cast<Map<String, dynamic>>().map(ProgrammeFeedback.fromJson).toList();
      });
}

final programmeRepositoryProvider = Provider<ProgrammeRepository>(
  (ref) => ProgrammeRepository(ref.watch(supabaseClientProvider)),
);

final visibleProgrammesProvider = FutureProvider.autoDispose<List<Programme>>(
  (ref) => ref.watch(programmeRepositoryProvider).fetchVisible(),
);

final programmeDetailProvider = FutureProvider.autoDispose.family<Programme, String>(
  (ref, id) => ref.watch(programmeRepositoryProvider).fetchById(id),
);

final myRegistrationsProvider = FutureProvider.autoDispose<List<ProgrammeRegistration>>(
  (ref) => ref.watch(programmeRepositoryProvider).fetchMyRegistrations(),
);

final myFeedbackIdsProvider = FutureProvider.autoDispose<Set<String>>(
  (ref) => ref.watch(programmeRepositoryProvider).fetchMyFeedbackProgrammeIds(),
);

final allProgrammesProvider = FutureProvider.autoDispose<List<Programme>>(
  (ref) => ref.watch(programmeRepositoryProvider).fetchAll(),
);

final programmeRegistrationsProvider =
    FutureProvider.autoDispose.family<List<ProgrammeRegistration>, String>(
  (ref, id) => ref.watch(programmeRepositoryProvider).fetchRegistrations(id),
);

final programmeFeedbackProvider = FutureProvider.autoDispose.family<List<ProgrammeFeedback>, String>(
  (ref, id) => ref.watch(programmeRepositoryProvider).fetchFeedback(id),
);
