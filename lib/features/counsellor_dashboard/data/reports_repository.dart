import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/supabase_service.dart';
import '../../../core/utils/failure.dart';

/// Aggregated, non-identifying engagement figures for counsellors.
/// No diagnoses, risk scores or individual mood data – by design.
class CounsellorStats {
  const CounsellorStats(this._m);

  final Map<String, dynamic> _m;

  int _i(String k) => (_m[k] as num?)?.toInt() ?? 0;

  int get pending => _i('pending');
  int get confirmed => _i('confirmed');
  int get upcoming7d => _i('upcoming_7d');
  int get completed => _i('completed');
  int get rescheduleRequests => _i('reschedule_requests');
  int get activeProgrammes => _i('active_programmes');
  int get registrations => _i('programme_registrations');
  int get attended => _i('programme_attended');
  int get absent => _i('programme_absent');
  int get feedbackCount => _i('feedback_count');
  int get publishedResources => _i('published_resources');
  int get bookmarks => _i('resource_bookmarks');
  double? get averageRating => (_m['average_feedback_rating'] as num?)?.toDouble();

  /// Null when fewer than 5 students used check-ins (privacy threshold).
  int? get checkinUsers30d => (_m['checkin_users_30d'] as num?)?.toInt();

  double? get attendanceRate {
    final marked = attended + absent;
    return marked == 0 ? null : attended / marked;
  }
}

class ProgrammeParticipation {
  const ProgrammeParticipation({
    required this.programmeId,
    required this.title,
    required this.startsAt,
    required this.status,
    required this.registered,
    required this.attended,
    required this.absent,
    required this.cancelled,
    this.capacity,
    this.avgRating,
  });

  final String programmeId;
  final String title;
  final DateTime startsAt;
  final String status;
  final int registered;
  final int attended;
  final int absent;
  final int cancelled;
  final int? capacity;
  final double? avgRating;

  factory ProgrammeParticipation.fromJson(Map<String, dynamic> j) => ProgrammeParticipation(
        programmeId: j['programme_id'] as String,
        title: j['title'] as String,
        startsAt: DateTime.parse(j['starts_at'] as String),
        status: j['status'] as String,
        capacity: (j['capacity'] as num?)?.toInt(),
        registered: (j['registered'] as num).toInt(),
        attended: (j['attended'] as num).toInt(),
        absent: (j['absent'] as num).toInt(),
        cancelled: (j['cancelled'] as num).toInt(),
        avgRating: (j['avg_rating'] as num?)?.toDouble(),
      );
}

class ReportsRepository {
  ReportsRepository(this._db);

  final SupabaseClient _db;

  Future<CounsellorStats> fetchStats() => guard(() async {
        final res = await _db.rpc('counsellor_dashboard_stats');
        return CounsellorStats((res as Map).cast<String, dynamic>());
      });

  Future<List<ProgrammeParticipation>> fetchParticipation() => guard(() async {
        final rows = await _db.rpc('programme_participation') as List<dynamic>;
        return rows.cast<Map<String, dynamic>>().map(ProgrammeParticipation.fromJson).toList();
      });
}

final reportsRepositoryProvider = Provider<ReportsRepository>(
  (ref) => ReportsRepository(ref.watch(supabaseClientProvider)),
);

final counsellorStatsProvider = FutureProvider.autoDispose<CounsellorStats>(
  (ref) => ref.watch(reportsRepositoryProvider).fetchStats(),
);

final participationProvider = FutureProvider.autoDispose<List<ProgrammeParticipation>>(
  (ref) => ref.watch(reportsRepositoryProvider).fetchParticipation(),
);
