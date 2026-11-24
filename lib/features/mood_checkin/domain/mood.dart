import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_colors.dart';

/// The five mood options. `score` is used only to draw the user's own
/// charts (5 = very happy … 1 = stressed). It is never a clinical measure.
enum Mood {
  veryHappy('very_happy', 'Very Happy', '😄', 5, AppColors.success),
  good('good', 'Good', '🙂', 4, AppColors.sage),
  neutral('neutral', 'Neutral', '😐', 3, AppColors.warning),
  sad('sad', 'Sad', '😢', 2, Color(0xFF7FA7D9)),
  stressed('stressed', 'Stressed', '😣', 1, AppColors.lavender);

  const Mood(this.dbValue, this.label, this.emoji, this.score, this.color);

  final String dbValue;
  final String label;
  final String emoji;
  final int score;
  final Color color;

  static Mood fromDb(String value) =>
      Mood.values.firstWhere((m) => m.dbValue == value, orElse: () => Mood.neutral);

  /// Gentle reflection prompts – supportive, never diagnostic.
  List<String> get prompts => switch (this) {
        Mood.veryHappy => const [
            'What made today feel so good?',
            'Who would you like to share this feeling with?',
            'How can you carry some of this energy into tomorrow?',
          ],
        Mood.good => const [
            'What went well today?',
            'What is one small thing you are grateful for?',
            'What helped you feel steady today?',
          ],
        Mood.neutral => const [
            'What is on your mind right now?',
            'Is there something small that could lift your day a little?',
            'What do you need more of this week?',
          ],
        Mood.sad => const [
            'What is weighing on you today?',
            'What would you say to a friend feeling this way?',
            'Who is someone you could reach out to?',
          ],
        Mood.stressed => const [
            'What is the biggest pressure on you right now?',
            'What is one thing you can let go of for today?',
            'What would help you feel 10% calmer?',
          ],
      };

  /// A short supportive message after check-in.
  String get encouragement => switch (this) {
        Mood.veryHappy => 'Wonderful! Enjoy this moment.',
        Mood.good => 'Glad to hear it. Keep doing what helps you.',
        Mood.neutral => 'Thanks for checking in. Every day counts.',
        Mood.sad => 'Thank you for being honest. Be gentle with yourself today.',
        Mood.stressed => 'That sounds heavy. A short breathing exercise might help.',
      };

  bool get suggestsSupport => this == Mood.sad || this == Mood.stressed;
}

enum MoodReason {
  academic('academic_pressure', 'Academic pressure', Icons.school_outlined),
  family('family', 'Family', Icons.family_restroom_rounded),
  relationships('relationships', 'Relationships', Icons.favorite_border_rounded),
  financial('financial', 'Financial concerns', Icons.account_balance_wallet_outlined),
  personal('personal', 'Personal issues', Icons.person_outline_rounded),
  health('health', 'Health', Icons.health_and_safety_outlined),
  other('other', 'Other', Icons.more_horiz_rounded);

  const MoodReason(this.dbValue, this.label, this.icon);

  final String dbValue;
  final String label;
  final IconData icon;

  static MoodReason? tryFromDb(String? value) {
    for (final r in MoodReason.values) {
      if (r.dbValue == value) return r;
    }
    return null;
  }
}

class MoodEntry {
  const MoodEntry({
    required this.id,
    required this.mood,
    required this.createdAt,
    this.reason,
    this.notes,
  });

  final String id;
  final Mood mood;
  final MoodReason? reason;
  final String? notes;
  final DateTime createdAt;

  factory MoodEntry.fromJson(Map<String, dynamic> json) => MoodEntry(
        id: json['id'] as String,
        mood: Mood.fromDb(json['mood'] as String),
        reason: MoodReason.tryFromDb(json['reason'] as String?),
        notes: json['notes'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

/// A counsellor the student may choose to share a summary with.
class CounsellorOption {
  const CounsellorOption({required this.id, required this.name});

  final String id;
  final String name;
}

class MoodShareConsent {
  const MoodShareConsent({
    required this.id,
    required this.counsellorId,
    required this.periodDays,
    required this.createdAt,
    required this.expiresAt,
    this.revokedAt,
    this.counsellorName,
  });

  final String id;
  final String counsellorId;
  final String? counsellorName;
  final int periodDays;
  final DateTime createdAt;
  final DateTime expiresAt;
  final DateTime? revokedAt;

  bool get isActive => revokedAt == null && expiresAt.isAfter(DateTime.now());

  factory MoodShareConsent.fromJson(Map<String, dynamic> json) => MoodShareConsent(
        id: json['id'] as String,
        counsellorId: json['counsellor_id'] as String,
        counsellorName: (json['counsellor'] as Map<String, dynamic>?)?['full_name'] as String?,
        periodDays: json['period_days'] as int,
        createdAt: DateTime.parse(json['created_at'] as String),
        expiresAt: DateTime.parse(json['expires_at'] as String),
        revokedAt: json['revoked_at'] == null ? null : DateTime.parse(json['revoked_at'] as String),
      );
}

/// Pure analytics over the user's own entries (computed on device).
class MoodStats {
  MoodStats(this.entries);

  final List<MoodEntry> entries;

  Map<Mood, int> get counts {
    final map = {for (final m in Mood.values) m: 0};
    for (final e in entries) {
      map[e.mood] = map[e.mood]! + 1;
    }
    return map;
  }

  Mood? get mostCommon {
    if (entries.isEmpty) return null;
    final c = counts;
    return c.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  MoodReason? get topReason {
    final map = <MoodReason, int>{};
    for (final e in entries) {
      if (e.reason != null) map[e.reason!] = (map[e.reason!] ?? 0) + 1;
    }
    if (map.isEmpty) return null;
    return map.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  /// Average score per day for [days] days ending today (null = no entry).
  List<double?> dailyAverages(int days, {DateTime? now}) {
    final today = DateUtils.dateOnly(now ?? DateTime.now());
    return List.generate(days, (i) {
      final day = today.subtract(Duration(days: days - 1 - i));
      final scores = entries
          .where((e) => DateUtils.isSameDay(e.createdAt.toLocal(), day))
          .map((e) => e.mood.score)
          .toList();
      if (scores.isEmpty) return null;
      return scores.reduce((a, b) => a + b) / scores.length;
    });
  }

  /// Consecutive days (ending today or yesterday) with at least one check-in.
  int streak({DateTime? now}) {
    final days = entries.map((e) => DateUtils.dateOnly(e.createdAt.toLocal())).toSet();
    var day = DateUtils.dateOnly(now ?? DateTime.now());
    if (!days.contains(day)) day = day.subtract(const Duration(days: 1));
    var count = 0;
    while (days.contains(day)) {
      count++;
      day = day.subtract(const Duration(days: 1));
    }
    return count;
  }
}
