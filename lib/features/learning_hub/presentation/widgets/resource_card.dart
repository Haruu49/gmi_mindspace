import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/learning_resource.dart';

/// Image (or category illustration) shown at the top of resources.
class ResourceImage extends StatelessWidget {
  const ResourceImage({super.key, required this.resource, this.height = 140});

  final LearningResource resource;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = resource.category;
    final fallback = Container(
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [c.color.withValues(alpha: 0.35), c.color.withValues(alpha: 0.12)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(child: Icon(c.icon, size: height * 0.38, color: c.color)),
    );
    if (resource.imageUrl == null) return fallback;
    return Image.network(
      resource.imageUrl!,
      height: height,
      width: double.infinity,
      fit: BoxFit.cover,
      semanticLabel: 'Illustration for ${resource.title}',
      errorBuilder: (_, _, _) => fallback,
      loadingBuilder: (context, child, progress) => progress == null ? child : fallback,
    );
  }
}

class ResourceCard extends StatelessWidget {
  const ResourceCard({super.key, required this.resource, this.compact = false});

  final LearningResource resource;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final r = resource;
    return AppCard(
      padding: EdgeInsets.zero,
      onTap: () => context.push(AppRoutes.learnDetail(r.id)),
      semanticLabel: '${r.title}. ${r.format.label}. ${r.category.label}',
      child: ClipRRect(
        borderRadius: AppRadius.lgAll,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ResourceImage(resource: r, height: compact ? 90 : 130),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xxs,
                    children: [
                      StatusChip(label: r.format.label, color: r.category.color, icon: r.format.icon),
                      if (r.readMinutes != null && !compact)
                        StatusChip(label: '${r.readMinutes} min', color: context.colors.primary),
                    ],
                  ),
                  AppSpacing.gapXs,
                  Text(r.title, style: context.text.titleSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                  if (!compact) ...[
                    AppSpacing.gapXxs,
                    Text(r.description, style: context.text.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
