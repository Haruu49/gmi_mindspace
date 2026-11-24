import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_colors.dart';

enum ResourceCategory {
  understanding('understanding_mental_health', 'Understanding Mental Health', Icons.psychology_outlined, AppColors.lavender),
  anxiety('anxiety_awareness', 'Anxiety Awareness', Icons.waves_rounded, Color(0xFF6FA3C7)),
  stress('stress_management', 'Stress Management', Icons.self_improvement_rounded, AppColors.sageDeep),
  depression('depression_awareness', 'Depression Awareness', Icons.cloud_outlined, Color(0xFF7D7AB8)),
  selfEsteem('self_esteem', 'Self-esteem', Icons.star_outline_rounded, AppColors.warning),
  emotionalIntelligence('emotional_intelligence', 'Emotional Intelligence', Icons.emoji_emotions_outlined, AppColors.success),
  relationships('healthy_relationships', 'Healthy Relationships', Icons.people_outline_rounded, AppColors.error),
  burnout('academic_burnout', 'Academic Burnout', Icons.battery_alert_rounded, Color(0xFFD99A6C)),
  sleep('sleep_wellbeing', 'Sleep and Well-being', Icons.bedtime_outlined, Color(0xFF5E7FB1)),
  helpSeeking('help_seeking', 'Help-seeking Awareness', Icons.support_rounded, AppColors.lavenderDeep);

  const ResourceCategory(this.dbValue, this.label, this.icon, this.color);

  final String dbValue;
  final String label;
  final IconData icon;
  final Color color;

  static ResourceCategory fromDb(String v) =>
      ResourceCategory.values.firstWhere((c) => c.dbValue == v, orElse: () => ResourceCategory.understanding);
}

enum ResourceFormat {
  article('article', 'Article', Icons.article_outlined),
  infographic('infographic', 'Infographic', Icons.insert_chart_outlined_rounded),
  video('video', 'Video', Icons.play_circle_outline_rounded),
  faq('faq', 'FAQ', Icons.quiz_outlined),
  download('download', 'Download', Icons.download_rounded);

  const ResourceFormat(this.dbValue, this.label, this.icon);

  final String dbValue;
  final String label;
  final IconData icon;

  /// Video and download resources link out to approved media.
  bool get needsLink => this == video || this == download;

  static ResourceFormat fromDb(String v) =>
      ResourceFormat.values.firstWhere((f) => f.dbValue == v, orElse: () => ResourceFormat.article);
}

class LearningResource {
  const LearningResource({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.format,
    required this.published,
    required this.createdAt,
    this.content,
    this.imageUrl,
    this.mediaUrl,
    this.readMinutes,
    this.publishedAt,
  });

  final String id;
  final String title;
  final String description;
  final ResourceCategory category;
  final ResourceFormat format;
  final bool published;
  final DateTime createdAt;
  final String? content;
  final String? imageUrl;
  final String? mediaUrl;
  final int? readMinutes;
  final DateTime? publishedAt;

  factory LearningResource.fromJson(Map<String, dynamic> j) => LearningResource(
        id: j['id'] as String,
        title: j['title'] as String,
        description: j['description'] as String,
        category: ResourceCategory.fromDb(j['category'] as String),
        format: ResourceFormat.fromDb(j['format'] as String),
        published: j['published'] as bool? ?? false,
        createdAt: DateTime.parse(j['created_at'] as String),
        content: j['content'] as String?,
        imageUrl: j['image_url'] as String?,
        mediaUrl: j['media_url'] as String?,
        readMinutes: (j['read_minutes'] as num?)?.toInt(),
        publishedAt: j['published_at'] == null ? null : DateTime.parse(j['published_at'] as String),
      );
}

class ResourceDraft {
  const ResourceDraft({
    required this.title,
    required this.description,
    required this.category,
    required this.format,
    required this.published,
    this.content,
    this.imageUrl,
    this.mediaUrl,
    this.readMinutes,
  });

  final String title;
  final String description;
  final ResourceCategory category;
  final ResourceFormat format;
  final bool published;
  final String? content;
  final String? imageUrl;
  final String? mediaUrl;
  final int? readMinutes;

  Map<String, dynamic> toRow() => {
        'title': title.trim(),
        'description': description.trim(),
        'category': category.dbValue,
        'format': format.dbValue,
        'published': published,
        'content': (content?.trim().isEmpty ?? true) ? null : content!.trim(),
        'image_url': imageUrl,
        'media_url': (mediaUrl?.trim().isEmpty ?? true) ? null : mediaUrl!.trim(),
        'read_minutes': readMinutes,
      };
}
