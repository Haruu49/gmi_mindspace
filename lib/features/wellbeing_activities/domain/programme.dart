import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_colors.dart';

enum ProgrammeMode {
  online('online', 'Online', Icons.videocam_outlined),
  physical('physical', 'On campus', Icons.place_outlined),
  hybrid('hybrid', 'Hybrid', Icons.devices_rounded);

  const ProgrammeMode(this.dbValue, this.label, this.icon);

  final String dbValue;
  final String label;
  final IconData icon;

  bool get hasOnline => this != physical;
  bool get hasVenue => this != online;

  static ProgrammeMode fromDb(String v) =>
      ProgrammeMode.values.firstWhere((m) => m.dbValue == v, orElse: () => ProgrammeMode.physical);
}

enum ProgrammeStatus {
  draft('Draft', AppColors.slate),
  published('Published', AppColors.success),
  cancelled('Cancelled', AppColors.error),
  completed('Completed', AppColors.lavender);

  const ProgrammeStatus(this.label, this.color);

  final String label;
  final Color color;

  static ProgrammeStatus fromDb(String v) =>
      ProgrammeStatus.values.firstWhere((s) => s.name == v, orElse: () => ProgrammeStatus.draft);
}

enum RegistrationStatus {
  registered('Registered', AppColors.success),
  cancelled('Cancelled', AppColors.slate),
  attended('Attended', AppColors.lavender),
  absent('Absent', AppColors.warning);

  const RegistrationStatus(this.label, this.color);

  final String label;
  final Color color;

  static RegistrationStatus fromDb(String v) =>
      RegistrationStatus.values.firstWhere((s) => s.name == v, orElse: () => RegistrationStatus.registered);

  bool get isActive => this == registered || this == attended;
}

/// Category values allowed by the database CHECK constraint.
const programmeCategories = ['Campaign', 'Webinar', 'Workshop', 'Challenge', 'Quiz', 'Programme', 'Talk'];

IconData programmeCategoryIcon(String c) => switch (c) {
      'Campaign' => Icons.campaign_outlined,
      'Webinar' => Icons.cast_for_education_rounded,
      'Workshop' => Icons.handyman_outlined,
      'Challenge' => Icons.emoji_events_outlined,
      'Quiz' => Icons.quiz_outlined,
      'Talk' => Icons.record_voice_over_outlined,
      _ => Icons.spa_outlined,
    };

class Programme {
  const Programme({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.mode,
    required this.startsAt,
    required this.endsAt,
    required this.status,
    this.location,
    this.onlineUrl,
    this.capacity,
    this.imageUrl,
  });

  final String id;
  final String title;
  final String description;
  final String category;
  final ProgrammeMode mode;
  final DateTime startsAt;
  final DateTime endsAt;
  final ProgrammeStatus status;
  final String? location;
  final String? onlineUrl;
  final int? capacity;
  final String? imageUrl;

  bool get hasStarted => !startsAt.isAfter(DateTime.now());
  bool get hasEnded => endsAt.isBefore(DateTime.now());
  bool get openForRegistration => status == ProgrammeStatus.published && !hasStarted;

  factory Programme.fromJson(Map<String, dynamic> j) => Programme(
        id: j['id'] as String,
        title: j['title'] as String,
        description: j['description'] as String,
        category: j['category'] as String,
        mode: ProgrammeMode.fromDb(j['mode'] as String),
        startsAt: DateTime.parse(j['starts_at'] as String),
        endsAt: DateTime.parse(j['ends_at'] as String),
        status: ProgrammeStatus.fromDb(j['status'] as String),
        location: j['location'] as String?,
        onlineUrl: j['online_url'] as String?,
        capacity: (j['capacity'] as num?)?.toInt(),
        imageUrl: j['image_url'] as String?,
      );
}

class ProgrammeRegistration {
  const ProgrammeRegistration({
    required this.id,
    required this.programmeId,
    required this.studentId,
    required this.status,
    required this.registeredAt,
    this.programme,
    this.studentName,
    this.studentNumber,
  });

  final String id;
  final String programmeId;
  final String studentId;
  final RegistrationStatus status;
  final DateTime registeredAt;
  final Programme? programme;
  final String? studentName;
  final String? studentNumber;

  factory ProgrammeRegistration.fromJson(Map<String, dynamic> j) => ProgrammeRegistration(
        id: j['id'] as String,
        programmeId: j['programme_id'] as String,
        studentId: j['student_id'] as String,
        status: RegistrationStatus.fromDb(j['status'] as String),
        registeredAt: DateTime.parse(j['registered_at'] as String),
        programme: j['programmes'] == null ? null : Programme.fromJson(j['programmes'] as Map<String, dynamic>),
      );

  ProgrammeRegistration withStudent(String? name, String? number) => ProgrammeRegistration(
        id: id,
        programmeId: programmeId,
        studentId: studentId,
        status: status,
        registeredAt: registeredAt,
        programme: programme,
        studentName: name,
        studentNumber: number,
      );
}

class ProgrammeFeedback {
  const ProgrammeFeedback({
    required this.id,
    required this.rating,
    required this.createdAt,
    this.comment,
    this.studentName,
  });

  final String id;
  final int rating;
  final String? comment;

  /// Null when the student chose to stay anonymous.
  final String? studentName;
  final DateTime createdAt;

  factory ProgrammeFeedback.fromJson(Map<String, dynamic> j) => ProgrammeFeedback(
        id: j['id'] as String,
        rating: (j['rating'] as num).toInt(),
        comment: j['comment'] as String?,
        studentName: j['student_name'] as String?,
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}

class ProgrammeDraft {
  const ProgrammeDraft({
    required this.title,
    required this.description,
    required this.category,
    required this.mode,
    required this.startsAt,
    required this.endsAt,
    required this.status,
    this.location,
    this.onlineUrl,
    this.capacity,
    this.imageUrl,
  });

  final String title;
  final String description;
  final String category;
  final ProgrammeMode mode;
  final DateTime startsAt;
  final DateTime endsAt;
  final ProgrammeStatus status;
  final String? location;
  final String? onlineUrl;
  final int? capacity;
  final String? imageUrl;

  Map<String, dynamic> toRow() => {
        'title': title.trim(),
        'description': description.trim(),
        'category': category,
        'mode': mode.dbValue,
        'starts_at': startsAt.toUtc().toIso8601String(),
        'ends_at': endsAt.toUtc().toIso8601String(),
        'status': status.name,
        'location': mode.hasVenue && (location?.trim().isNotEmpty ?? false) ? location!.trim() : null,
        'online_url': mode.hasOnline && (onlineUrl?.trim().isNotEmpty ?? false) ? onlineUrl!.trim() : null,
        'capacity': capacity,
        'image_url': imageUrl,
      };
}
