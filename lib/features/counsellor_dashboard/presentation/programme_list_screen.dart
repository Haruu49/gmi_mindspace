import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../wellbeing_activities/data/programme_repository.dart';
import '../../wellbeing_activities/domain/programme.dart';
import '../../wellbeing_activities/presentation/activities_screen.dart' show ProgrammeCard;

class CounsellorProgrammesScreen extends ConsumerStatefulWidget {
  const CounsellorProgrammesScreen({super.key});

  @override
  ConsumerState<CounsellorProgrammesScreen> createState() => _State();
}

class _State extends ConsumerState<CounsellorProgrammesScreen> {
  ProgrammeStatus? _filter;

  @override
  Widget build(BuildContext context) {
    final programmes = ref.watch(allProgrammesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Programmes')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.counsellorProgrammeNew),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New programme'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          final _ = await ref.refresh(allProgrammesProvider.future);
        },
        child: ListView(
          padding: AppSpacing.page.copyWith(bottom: 96),
          children: [
            ResponsiveCenter(
              maxWidth: 900,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 44,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        ChoiceChip(
                          label: const Text('All'),
                          selected: _filter == null,
                          onSelected: (_) => setState(() => _filter = null),
                        ),
                        for (final s in ProgrammeStatus.values)
                          Padding(
                            padding: const EdgeInsets.only(left: AppSpacing.xs),
                            child: ChoiceChip(
                              label: Text(s.label),
                              selected: _filter == s,
                              onSelected: (_) => setState(() => _filter = s),
                            ),
                          ),
                      ],
                    ),
                  ),
                  AppSpacing.gapMd,
                  programmes.when(
                    loading: () => const Padding(padding: EdgeInsets.all(AppSpacing.xl), child: LoadingView()),
                    error: (e, _) => SizedBox(
                      height: 300,
                      child: ErrorView(error: e, onRetry: () => ref.invalidate(allProgrammesProvider)),
                    ),
                    data: (all) {
                      final list = _filter == null ? all : all.where((p) => p.status == _filter).toList();
                      if (list.isEmpty) {
                        return const SizedBox(
                          height: 240,
                          child: EmptyView(
                            title: 'No programmes yet',
                            message: 'Create a workshop, webinar, campaign or challenge.',
                            icon: Icons.celebration_outlined,
                          ),
                        );
                      }
                      return Column(
                        children: [
                          for (final p in list) ...[
                            ProgrammeCard(
                              programme: p,
                              onTap: () => context.push(AppRoutes.counsellorProgramme(p.id)),
                            ),
                            AppSpacing.gapSm,
                          ],
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
