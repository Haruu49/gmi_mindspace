import 'package:material_ui/material_ui.dart';

enum NotificationKind {
  appointmentConfirmed('appointment_confirmed', Icons.event_available_rounded),
  appointmentRescheduled('appointment_rescheduled', Icons.update_rounded),
  appointmentReminder('appointment_reminder', Icons.alarm_rounded),
  appointmentUpdate('appointment_update', Icons.event_note_rounded),
  programmeRegistration('programme_registration', Icons.how_to_reg_rounded),
  programmeUpcoming('programme_upcoming', Icons.celebration_outlined),
  newResource('new_resource', Icons.auto_stories_outlined),
  general('general', Icons.notifications_none_rounded);

  const NotificationKind(this.dbValue, this.icon);

  final String dbValue;
  final IconData icon;

  static NotificationKind fromDb(String v) =>
      NotificationKind.values.firstWhere((k) => k.dbValue == v, orElse: () => NotificationKind.general);
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.data,
    required this.createdAt,
    this.readAt,
  });

  final String id;
  final NotificationKind kind;
  final String title;
  final String body;
  final Map<String, dynamic> data;
  final DateTime createdAt;
  final DateTime? readAt;

  bool get isRead => readAt != null;
  String? get appointmentId => data['appointment_id'] as String?;
  String? get programmeId => data['programme_id'] as String?;
  String? get resourceId => data['resource_id'] as String?;

  factory AppNotification.fromJson(Map<String, dynamic> json) => AppNotification(
        id: json['id'] as String,
        kind: NotificationKind.fromDb(json['type'] as String),
        title: json['title'] as String,
        body: json['body'] as String,
        data: (json['data'] as Map?)?.cast<String, dynamic>() ?? const {},
        createdAt: DateTime.parse(json['created_at'] as String),
        readAt: json['read_at'] == null ? null : DateTime.parse(json['read_at'] as String),
      );
}

/// Optional notification categories the student controls. Essential
/// messages (appointment confirmations/changes, registration confirmations)
/// are always delivered in-app.
class NotificationPreferences {
  const NotificationPreferences({
    this.appointmentReminders = true,
    this.programmeUpdates = true,
    this.newResources = true,
    this.pushEnabled = true,
  });

  final bool appointmentReminders;
  final bool programmeUpdates;
  final bool newResources;
  final bool pushEnabled;

  factory NotificationPreferences.fromJson(Map<String, dynamic> j) => NotificationPreferences(
        appointmentReminders: j['appointment_reminders'] as bool? ?? true,
        programmeUpdates: j['programme_updates'] as bool? ?? true,
        newResources: j['new_resources'] as bool? ?? true,
        pushEnabled: j['push_enabled'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
        'appointment_reminders': appointmentReminders,
        'programme_updates': programmeUpdates,
        'new_resources': newResources,
        'push_enabled': pushEnabled,
      };

  NotificationPreferences copyWith({
    bool? appointmentReminders,
    bool? programmeUpdates,
    bool? newResources,
    bool? pushEnabled,
  }) =>
      NotificationPreferences(
        appointmentReminders: appointmentReminders ?? this.appointmentReminders,
        programmeUpdates: programmeUpdates ?? this.programmeUpdates,
        newResources: newResources ?? this.newResources,
        pushEnabled: pushEnabled ?? this.pushEnabled,
      );
}
