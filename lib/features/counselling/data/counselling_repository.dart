import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/supabase_service.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/failure.dart';
import '../domain/appointment.dart';

/// Appointments and availability. Writes go through database workflow
/// functions that validate ownership, assignment and status transitions.
class CounsellingRepository {
  CounsellingRepository(this._db);

  final SupabaseClient _db;

  String get _uid {
    final id = _db.auth.currentUser?.id;
    if (id == null) throw const AppFailure('Please sign in again.', kind: FailureKind.sessionExpired);
    return id;
  }

  static const _listCols =
      'id, student_id, counsellor_id, appointment_type, status, starts_at, ends_at, '
      'reschedule_requested, created_at, student_name, counsellor_name';

  // ---------------- Student ----------------

  Future<List<Appointment>> fetchMyAppointments() => guard(() async {
        final rows = await _db
            .from('appointment_list')
            .select(_listCols)
            .eq('student_id', _uid)
            .order('starts_at', ascending: false)
            .limit(200);
        return rows.map(Appointment.fromJson).toList();
      });

  /// Detail view (includes the student's note and status explanation).
  Future<Appointment> fetchAppointment(String id) => guard(() async {
        final row = await _db
            .from('appointments')
            .select('id, student_id, counsellor_id, appointment_type, status, starts_at, ends_at, '
                'student_reason, status_reason, reschedule_requested, reschedule_note, created_at')
            .eq('id', id)
            .single();
        final names = await _db
            .from('appointment_list')
            .select('student_name, counsellor_name')
            .eq('id', id)
            .maybeSingle();
        return Appointment.fromJson(row).withNames(
          studentName: names?['student_name'] as String?,
          counsellorName: names?['counsellor_name'] as String?,
        );
      });

  Future<List<OpenSlot>> fetchOpenSlots({DateTime? from, int days = 30}) => guard(() async {
        final rows = await _db.rpc('get_open_slots', params: {
          'p_from': AppDates.isoDate(from ?? DateTime.now()),
          'p_days': days,
        }) as List<dynamic>;
        return rows.cast<Map<String, dynamic>>().map(OpenSlot.fromJson).toList();
      });

  Future<String> requestAppointment({
    required String availabilityId,
    required AppointmentType type,
    String? reason,
  }) =>
      guard(() async {
        final id = await _db.rpc('request_appointment', params: {
          'p_availability_id': availabilityId,
          'p_type': type.dbValue,
          'p_reason': (reason?.trim().isEmpty ?? true) ? null : reason!.trim(),
        });
        return id as String;
      });

  Future<void> cancelMyAppointment(String id, {String? reason}) => guard(
        () => _db.rpc('cancel_my_appointment', params: {'p_id': id, 'p_reason': reason}),
      );

  Future<void> requestReschedule(String id, String note) =>
      guard(() => _db.rpc('request_reschedule', params: {'p_id': id, 'p_note': note}));

  Future<Map<String, String>> fetchCounsellingInfo() => guard(() async {
        final rows = await _db
            .from('app_settings')
            .select('key, value')
            .inFilter('key', ['counselling_hours', 'counselling_location']);
        return {for (final r in rows) r['key'] as String: '${r['value']}'};
      });

  // ---------------- Counsellor ----------------

  Future<List<Appointment>> fetchCounsellorAppointments() => guard(() async {
        final rows = await _db
            .from('appointment_list')
            .select(_listCols)
            .eq('counsellor_id', _uid)
            .order('starts_at', ascending: true)
            .limit(500);
        return rows.map(Appointment.fromJson).toList();
      });

  Future<void> setStatus(String id, AppointmentStatus status, {String? reason}) => guard(
        () => _db.rpc('counsellor_set_appointment_status', params: {
          'p_id': id,
          'p_status': status.dbValue,
          'p_reason': reason,
        }),
      );

  Future<void> reschedule(String id, String newAvailabilityId) => guard(
        () => _db.rpc('counsellor_reschedule_appointment', params: {
          'p_id': id,
          'p_new_availability_id': newAvailabilityId,
        }),
      );

  Future<List<AvailabilitySlot>> fetchMyAvailability() => guard(() async {
        final since = DateTime.now().toUtc().subtract(const Duration(days: 1));
        final rows = await _db
            .from('counsellor_availability')
            .select('id, starts_at, ends_at, location, is_active')
            .eq('counsellor_id', _uid)
            .gte('starts_at', since.toIso8601String())
            .order('starts_at');
        return rows.map(AvailabilitySlot.fromJson).toList();
      });

  Future<void> addAvailability({
    required DateTime startsAt,
    required DateTime endsAt,
    String? location,
  }) =>
      guard(() => _db.from('counsellor_availability').insert({
            'starts_at': startsAt.toUtc().toIso8601String(),
            'ends_at': endsAt.toUtc().toIso8601String(),
            'location': (location?.trim().isEmpty ?? true) ? null : location!.trim(),
          }));

  Future<void> setAvailabilityActive(String id, bool active) => guard(
        () => _db.from('counsellor_availability').update({'is_active': active}).eq('id', id),
      );

  Future<void> deleteAvailability(String id) =>
      guard(() => _db.from('counsellor_availability').delete().eq('id', id));

  Future<List<AppointmentNote>> fetchNotes(String appointmentId) => guard(() async {
        final rows = await _db
            .from('appointment_notes')
            .select('id, note, created_at')
            .eq('appointment_id', appointmentId)
            .order('created_at', ascending: false);
        return rows.map(AppointmentNote.fromJson).toList();
      });

  Future<void> addNote(String appointmentId, String note) => guard(
        () => _db.from('appointment_notes').insert({'appointment_id': appointmentId, 'note': note.trim()}),
      );

  Future<void> deleteNote(String id) => guard(() => _db.from('appointment_notes').delete().eq('id', id));

  /// Only succeeds while the student has an active consent for this counsellor.
  Future<SharedMoodSummary?> fetchSharedMoodSummary(String studentId) async {
    try {
      final rows = await _db.rpc('get_shared_mood_summary', params: {'p_student': studentId}) as List<dynamic>;
      final list = rows.cast<Map<String, dynamic>>();
      if (list.isEmpty) return const SharedMoodSummary(counts: {}, periodDays: 0);
      return SharedMoodSummary(
        counts: {for (final r in list) r['mood'] as String: (r['total'] as num).toInt()},
        periodDays: (list.first['period_days'] as num).toInt(),
      );
    } on PostgrestException catch (e) {
      if (e.code == '42501') return null; // no consent – expected
      throw AppFailure.from(e);
    } catch (e) {
      throw AppFailure.from(e);
    }
  }
}

final counsellingRepositoryProvider = Provider<CounsellingRepository>(
  (ref) => CounsellingRepository(ref.watch(supabaseClientProvider)),
);

final myAppointmentsProvider = FutureProvider.autoDispose<List<Appointment>>(
  (ref) => ref.watch(counsellingRepositoryProvider).fetchMyAppointments(),
);

final appointmentDetailProvider = FutureProvider.autoDispose.family<Appointment, String>(
  (ref, id) => ref.watch(counsellingRepositoryProvider).fetchAppointment(id),
);

final openSlotsProvider = FutureProvider.autoDispose<List<OpenSlot>>(
  (ref) => ref.watch(counsellingRepositoryProvider).fetchOpenSlots(),
);

final counsellingInfoProvider = FutureProvider.autoDispose<Map<String, String>>(
  (ref) => ref.watch(counsellingRepositoryProvider).fetchCounsellingInfo(),
);

final counsellorAppointmentsProvider = FutureProvider.autoDispose<List<Appointment>>(
  (ref) => ref.watch(counsellingRepositoryProvider).fetchCounsellorAppointments(),
);

final myAvailabilityProvider = FutureProvider.autoDispose<List<AvailabilitySlot>>(
  (ref) => ref.watch(counsellingRepositoryProvider).fetchMyAvailability(),
);

final appointmentNotesProvider = FutureProvider.autoDispose.family<List<AppointmentNote>, String>(
  (ref, id) => ref.watch(counsellingRepositoryProvider).fetchNotes(id),
);

final sharedMoodSummaryProvider = FutureProvider.autoDispose.family<SharedMoodSummary?, String>(
  (ref, studentId) => ref.watch(counsellingRepositoryProvider).fetchSharedMoodSummary(studentId),
);
