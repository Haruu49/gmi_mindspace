import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_colors.dart';

enum AppointmentType {
  individual('individual_counselling', 'Individual Counselling', Icons.person_rounded,
      'A private one-to-one conversation with a counsellor.'),
  academic('academic_support', 'Academic Support', Icons.school_rounded,
      'Study stress, motivation, time management or academic worries.'),
  wellbeing('emotional_wellbeing', 'Emotional Well-being Consultation', Icons.favorite_rounded,
      'Talk through feelings, stress or anything weighing on you.'),
  other('other_support', 'Other Support', Icons.support_rounded,
      'Anything else you would like help with.');

  const AppointmentType(this.dbValue, this.label, this.icon, this.description);

  final String dbValue;
  final String label;
  final IconData icon;
  final String description;

  static AppointmentType fromDb(String v) =>
      AppointmentType.values.firstWhere((t) => t.dbValue == v, orElse: () => AppointmentType.other);
}

enum AppointmentStatus {
  pending('Pending', AppColors.warning, Icons.hourglass_top_rounded),
  confirmed('Confirmed', AppColors.success, Icons.check_circle_rounded),
  rejected('Rejected', AppColors.error, Icons.cancel_rounded),
  cancelled('Cancelled', AppColors.slate, Icons.event_busy_rounded),
  completed('Completed', AppColors.lavender, Icons.task_alt_rounded);

  const AppointmentStatus(this.label, this.color, this.icon);

  final String label;
  final Color color;
  final IconData icon;

  String get dbValue => name;

  static AppointmentStatus fromDb(String v) =>
      AppointmentStatus.values.firstWhere((s) => s.name == v, orElse: () => AppointmentStatus.pending);

  bool get isLive => this == pending || this == confirmed;
}

class Appointment {
  const Appointment({
    required this.id,
    required this.studentId,
    required this.counsellorId,
    required this.type,
    required this.status,
    required this.startsAt,
    required this.endsAt,
    required this.createdAt,
    this.studentReason,
    this.statusReason,
    this.rescheduleRequested = false,
    this.rescheduleNote,
    this.studentName,
    this.counsellorName,
  });

  final String id;
  final String studentId;
  final String counsellorId;
  final AppointmentType type;
  final AppointmentStatus status;
  final DateTime startsAt;
  final DateTime endsAt;
  final DateTime createdAt;

  /// Only present on detail queries (never in list views).
  final String? studentReason;
  final String? statusReason;
  final bool rescheduleRequested;
  final String? rescheduleNote;
  final String? studentName;
  final String? counsellorName;

  bool get isUpcoming => status.isLive && startsAt.isAfter(DateTime.now());
  bool get canStudentChange => status.isLive && startsAt.isAfter(DateTime.now());

  factory Appointment.fromJson(Map<String, dynamic> j) => Appointment(
        id: j['id'] as String,
        studentId: j['student_id'] as String,
        counsellorId: j['counsellor_id'] as String,
        type: AppointmentType.fromDb(j['appointment_type'] as String),
        status: AppointmentStatus.fromDb(j['status'] as String),
        startsAt: DateTime.parse(j['starts_at'] as String),
        endsAt: DateTime.parse(j['ends_at'] as String),
        createdAt: DateTime.parse(j['created_at'] as String),
        studentReason: j['student_reason'] as String?,
        statusReason: j['status_reason'] as String?,
        rescheduleRequested: j['reschedule_requested'] as bool? ?? false,
        rescheduleNote: j['reschedule_note'] as String?,
        studentName: j['student_name'] as String?,
        counsellorName: j['counsellor_name'] as String?,
      );

  Appointment withNames({String? studentName, String? counsellorName}) => Appointment(
        id: id,
        studentId: studentId,
        counsellorId: counsellorId,
        type: type,
        status: status,
        startsAt: startsAt,
        endsAt: endsAt,
        createdAt: createdAt,
        studentReason: studentReason,
        statusReason: statusReason,
        rescheduleRequested: rescheduleRequested,
        rescheduleNote: rescheduleNote,
        studentName: studentName ?? this.studentName,
        counsellorName: counsellorName ?? this.counsellorName,
      );
}

/// A bookable slot returned by `get_open_slots` (no student data).
class OpenSlot {
  const OpenSlot({
    required this.availabilityId,
    required this.counsellorId,
    required this.counsellorName,
    required this.startsAt,
    required this.endsAt,
    this.location,
  });

  final String availabilityId;
  final String counsellorId;
  final String counsellorName;
  final DateTime startsAt;
  final DateTime endsAt;
  final String? location;

  factory OpenSlot.fromJson(Map<String, dynamic> j) => OpenSlot(
        availabilityId: j['availability_id'] as String,
        counsellorId: j['counsellor_id'] as String,
        counsellorName: j['counsellor_name'] as String,
        startsAt: DateTime.parse(j['starts_at'] as String),
        endsAt: DateTime.parse(j['ends_at'] as String),
        location: j['location'] as String?,
      );
}

/// A counsellor's own availability slot.
class AvailabilitySlot {
  const AvailabilitySlot({
    required this.id,
    required this.startsAt,
    required this.endsAt,
    required this.isActive,
    this.location,
  });

  final String id;
  final DateTime startsAt;
  final DateTime endsAt;
  final bool isActive;
  final String? location;

  factory AvailabilitySlot.fromJson(Map<String, dynamic> j) => AvailabilitySlot(
        id: j['id'] as String,
        startsAt: DateTime.parse(j['starts_at'] as String),
        endsAt: DateTime.parse(j['ends_at'] as String),
        isActive: j['is_active'] as bool,
        location: j['location'] as String?,
      );
}

class AppointmentNote {
  const AppointmentNote({required this.id, required this.note, required this.createdAt});

  final String id;
  final String note;
  final DateTime createdAt;

  factory AppointmentNote.fromJson(Map<String, dynamic> j) => AppointmentNote(
        id: j['id'] as String,
        note: j['note'] as String,
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}

/// Counts per mood a student chose to share (never notes).
class SharedMoodSummary {
  const SharedMoodSummary({required this.counts, required this.periodDays});

  final Map<String, int> counts;
  final int periodDays;
}
