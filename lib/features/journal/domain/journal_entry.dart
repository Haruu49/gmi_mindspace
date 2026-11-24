/// A private journal entry. Only its owner can read it (enforced by RLS).
class JournalEntry {
  const JournalEntry({
    required this.id,
    required this.title,
    required this.content,
    required this.entryDate,
    required this.createdAt,
    required this.updatedAt,
    this.prompt,
    this.isGratitude = false,
  });

  final String id;
  final String title;
  final String content;
  final DateTime entryDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? prompt;
  final bool isGratitude;

  bool get wasEdited => updatedAt.difference(createdAt).inSeconds > 5;

  factory JournalEntry.fromJson(Map<String, dynamic> json) => JournalEntry(
        id: json['id'] as String,
        title: json['title'] as String,
        content: json['content'] as String,
        entryDate: DateTime.parse(json['entry_date'] as String),
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
        prompt: json['prompt'] as String?,
        isGratitude: json['is_gratitude'] as bool? ?? false,
      );
}

/// Daily reflection prompts from the brief.
abstract final class JournalPrompts {
  static const reflection = <String>[
    'What made you happy today?',
    'What is troubling you?',
    'What are you grateful for?',
    'What did you learn today?',
    'What would you like to improve tomorrow?',
  ];

  /// Same prompt all day, rotating daily.
  static String forToday([DateTime? now]) {
    final d = now ?? DateTime.now();
    final dayOfYear = d.difference(DateTime(d.year)).inDays;
    return reflection[dayOfYear % reflection.length];
  }
}

/// Draft used when creating or editing.
class JournalDraft {
  const JournalDraft({
    required this.title,
    required this.content,
    required this.entryDate,
    this.prompt,
    this.isGratitude = false,
  });

  final String title;
  final String content;
  final DateTime entryDate;
  final String? prompt;
  final bool isGratitude;
}
