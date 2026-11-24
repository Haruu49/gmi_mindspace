import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/widgets.dart';
import '../data/learning_repository.dart';
import '../data/pdf_picker.dart';
import '../domain/learning_resource.dart';
import 'widgets/resource_card.dart';

class ResourceDetailScreen extends ConsumerStatefulWidget {
  const ResourceDetailScreen({super.key, required this.resourceId});

  final String resourceId;

  @override
  ConsumerState<ResourceDetailScreen> createState() => _ResourceDetailScreenState();
}

class _ResourceDetailScreenState extends ConsumerState<ResourceDetailScreen> {
  bool _toggling = false;
  bool _openingPdf = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(learningRepositoryProvider).recordView(widget.resourceId);
      if (mounted) ref.invalidate(recentResourcesProvider);
    });
  }

  Future<void> _toggleBookmark(bool saved) async {
    setState(() => _toggling = true);
    final repo = ref.read(learningRepositoryProvider);
    try {
      saved ? await repo.removeBookmark(widget.resourceId) : await repo.addBookmark(widget.resourceId);
      ref.invalidate(bookmarkIdsProvider);
      ref.invalidate(bookmarkedResourcesProvider);
      if (mounted) showAppSnack(context, saved ? 'Removed from saved.' : 'Saved for later.');
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _toggling = false);
    }
  }

  Future<void> _openLink(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.isScheme('https')) return;
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) showAppSnack(context, 'Could not open the link.', isError: true);
  }

  /// Gets a one-hour signed link (storage checks the student may read it)
  /// and opens it in the phone's PDF viewer.
  Future<void> _openPdf(String path) async {
    setState(() => _openingPdf = true);
    try {
      final url = await ref.read(learningRepositoryProvider).signedPdfUrl(path);
      final ok = await ref.read(pdfOpenerProvider)(Uri.parse(url));
      if (!ok && mounted) showAppSnack(context, 'Could not open the PDF.', isError: true);
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _openingPdf = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final res = ref.watch(resourceDetailProvider(widget.resourceId));
    final saved = ref.watch(bookmarkIdsProvider).value?.contains(widget.resourceId) ?? false;
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            tooltip: saved ? 'Remove from saved' : 'Save for later',
            icon: Icon(saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded),
            onPressed: _toggling || !res.hasValue ? null : () => _toggleBookmark(saved),
          ),
        ],
      ),
      body: AsyncValueView<LearningResource>(
        value: res,
        onRetry: () => ref.invalidate(resourceDetailProvider(widget.resourceId)),
        data: (r) => PageBody(
          children: [
            ClipRRect(borderRadius: AppRadius.lgAll, child: ResourceImage(resource: r, height: 190)),
            AppSpacing.gapMd,
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xxs,
              children: [
                StatusChip(label: r.category.label, color: r.category.color, icon: r.category.icon),
                StatusChip(label: r.format.label, color: context.colors.primary, icon: r.format.icon),
                if (r.readMinutes != null)
                  StatusChip(label: '${r.readMinutes} min', color: AppColors.sageDeep, icon: Icons.schedule_rounded),
              ],
            ),
            AppSpacing.gapSm,
            Text(r.title, style: context.text.headlineSmall),
            AppSpacing.gapXs,
            Text(r.description, style: context.text.bodyLarge?.copyWith(color: context.colors.onSurfaceVariant)),
            if (r.publishedAt != null) ...[
              AppSpacing.gapXs,
              Text('Published ${AppDates.day(r.publishedAt!)}', style: context.text.bodySmall),
            ],
            const Divider(height: AppSpacing.xl),
            if (r.content != null) SelectableText(r.content!, style: context.text.bodyLarge?.copyWith(height: 1.65)),
            if (r.hasFile) ...[
              AppSpacing.gapLg,
              Text(
                '${r.fileName ?? 'PDF'} · ${formatFileSize(r.fileSizeBytes ?? 0)}',
                style: context.text.bodySmall,
              ),
              AppSpacing.gapXs,
              AppButton(
                key: const Key('resource_open_pdf'),
                label: 'Open PDF',
                icon: Icons.picture_as_pdf_outlined,
                isLoading: _openingPdf,
                onPressed: () => _openPdf(r.filePath!),
              ),
            ],
            if (r.mediaUrl != null) ...[
              AppSpacing.gapLg,
              AppButton(
                label: r.format == ResourceFormat.video ? 'Watch video' : 'Open resource',
                icon: r.format == ResourceFormat.video ? Icons.play_arrow_rounded : Icons.open_in_new_rounded,
                onPressed: () => _openLink(r.mediaUrl!),
              ),
            ],
            AppSpacing.gapLg,
            const InfoBanner(
              message: 'This resource is for general education and is not a diagnosis. '
                  'If something here resonates with you, a GMI counsellor is happy to talk.',
            ),
          ],
        ),
      ),
    );
  }
}

class BookmarksScreen extends ConsumerWidget {
  const BookmarksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(bookmarkedResourcesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Saved resources')),
      body: AsyncValueView<List<LearningResource>>(
        value: items,
        onRetry: () => ref.invalidate(bookmarkedResourcesProvider),
        isEmpty: (l) => l.isEmpty,
        empty: const EmptyView(
          title: 'No saved resources',
          message: 'Tap the bookmark icon on any resource to keep it here.',
          icon: Icons.bookmark_border_rounded,
        ),
        data: (list) => PageBody(
          children: [
            ResponsiveGrid(minTileWidth: 260, children: [for (final r in list) ResourceCard(resource: r)]),
          ],
        ),
      ),
    );
  }
}
