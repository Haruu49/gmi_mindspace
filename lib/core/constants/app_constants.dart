/// App-wide copy and limits. Keep user-facing wording friendly and
/// non-clinical.
abstract final class AppConstants {
  static const String appName = 'GMI MindSpace';
  static const String tagline = 'Your Space. Your Pace. Your Well-being.';
  static const String description =
      'A friendly digital space to support your mental health, emotional '
      'well-being and personal growth.';
  static const String institution = 'German-Malaysian Institute';

  /// Shown wherever we talk about support, so nobody assumes live monitoring.
  static const String notMonitoredNotice =
      'GMI MindSpace is not monitored 24/7. Nobody reads your entries in real '
      'time. If you are in danger or thinking about harming yourself, call 999 '
      'or go to the nearest hospital emergency department now.';

  /// Shown on wellbeing content so we never imply treatment or diagnosis.
  static const String notTreatmentNotice =
      'These activities support everyday well-being. They are not a diagnosis '
      'or a replacement for professional care.';

  // Validation limits (mirrored by database CHECK constraints).
  static const int minPasswordLength = 8;
  static const int maxNameLength = 80;
  static const int maxMoodNoteLength = 500;
  static const int maxJournalTitleLength = 120;
  static const int maxJournalContentLength = 10000;
  static const int maxFeedbackLength = 1000;
  static const int maxAppointmentReasonLength = 500;

  /// E-mail domains allowed to self-register as students. Leave empty to
  /// allow any domain (e.g. during testing).
  static const List<String> studentEmailDomains = <String>[];

  /// The only e-mail domain allowed to sign up as a counsellor. The database
  /// enforces the same rule; this copy only gives friendlier form errors.
  static const String counsellorEmailDomain = 'gmi.edu.my';
}
