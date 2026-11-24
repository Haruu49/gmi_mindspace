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

/// Largest PDF a counsellor may attach (mirrors the storage bucket limit).
const int maxPdfBytes = 20 * 1024 * 1024;

/// Checks a picked file before upload. Returns null when it is acceptable.
String? validatePdf({required String fileName, required int sizeBytes}) {
  final name = fileName.trim().toLowerCase();
  if (name.length <= 4 || !name.endsWith('.pdf')) return 'Please choose a PDF file.';
  if (sizeBytes <= 0) return 'This file is empty.';
  if (sizeBytes > maxPdfBytes) return 'PDFs must be 20 MB or smaller.';
  return null;
}

/// Human-readable size, e.g. "850 KB" or "1.2 MB".
String formatFileSize(int bytes) {
  const mb = 1024 * 1024;
  if (bytes < mb) return '${(bytes / 1024).ceil()} KB';
  return '${(bytes / mb).toStringAsFixed(1)} MB';
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
    this.filePath,
    this.fileName,
    this.fileSizeBytes,
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

  /// Attached PDF (path inside the private `learning-files` bucket).
  final String? filePath;
  final String? fileName;
  final int? fileSizeBytes;

  bool get hasFile => filePath != null;

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
        filePath: j['file_path'] as String?,
        fileName: j['file_name'] as String?,
        fileSizeBytes: (j['file_size_bytes'] as num?)?.toInt(),
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
    this.filePath,
    this.fileName,
    this.fileSizeBytes,
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
  final String? filePath;
  final String? fileName;
  final int? fileSizeBytes;

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
        // Always written, so removing a PDF clears all three columns.
        'file_path': filePath,
        'file_name': filePath == null ? null : fileName,
        'file_size_bytes': filePath == null ? null : fileSizeBytes,
      };
}
