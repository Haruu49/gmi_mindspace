import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../authentication/presentation/auth_controller.dart';
import '../../learning_hub/data/learning_repository.dart';
import '../../learning_hub/domain/learning_resource.dart';

class ContentListScreen extends ConsumerWidget {
  const ContentListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canManage = ref.watch(currentProfileProvider)?.canManageContent ?? false;
    if (!canManage) {
      return Scaffold(
        appBar: AppBar(title: const Text('Learning Hub content')),
        body: const EmptyView(
          title: 'No content permission',
          message: 'An administrator has not enabled content management for your account.',
          icon: Icons.lock_outline_rounded,
        ),
      );
    }
    final items = ref.watch(managedResourcesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Learning Hub content')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.counsellorContentNew),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New resource'),
      ),
      body: AsyncValueView<List<LearningResource>>(
        value: items,
        onRetry: () => ref.invalidate(managedResourcesProvider),
        isEmpty: (l) => l.isEmpty,
        empty: const EmptyView(
          title: 'No resources yet',
          message: 'Add articles, infographics, videos, FAQs or downloads for students.',
          icon: Icons.auto_stories_outlined,
        ),
        data: (list) => RefreshIndicator(
          onRefresh: () async {
            final _ = await ref.refresh(managedResourcesProvider.future);
          },
          child: ListView.separated(
            padding: AppSpacing.page.copyWith(bottom: 96),
            itemCount: list.length,
            separatorBuilder: (_, _) => AppSpacing.gapSm,
            itemBuilder: (context, i) {
              final r = list[i];
              return ResponsiveCenter(
                maxWidth: 900,
                child: AppCard(
                  onTap: () => context.push(AppRoutes.counsellorContentEdit(r.id)),
                  child: Row(
                    children: [
                      IconBubble(icon: r.format.icon, color: r.category.color),
                      AppSpacing.gapMd,
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(r.title, style: context.text.titleSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                            Text('${r.category.label} · ${r.format.label}', style: context.text.bodySmall),
                          ],
                        ),
                      ),
                      Column(
                        children: [
                          Switch(
                            value: r.published,
                            onChanged: (v) async {
                              try {
                                await ref.read(learningRepositoryProvider).setPublished(r.id, v);
                                ref.invalidate(managedResourcesProvider);
                                if (context.mounted) showAppSnack(context, v ? 'Published.' : 'Unpublished.');
                              } catch (e) {
                                if (context.mounted) showErrorSnack(context, e);
                              }
                            },
                          ),
                          Text(r.published ? 'Published' : 'Draft', style: context.text.labelSmall),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
