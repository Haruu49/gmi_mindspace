import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/widgets.dart';
import '../../../shared/widgets/month_calendar.dart';
import '../data/programme_repository.dart';
import '../domain/programme.dart';

enum _View { upcoming, mine, completed, calendar }

class ActivitiesScreen extends ConsumerStatefulWidget {
  const ActivitiesScreen({super.key});

  @override
  ConsumerState<ActivitiesScreen> createState() => _ActivitiesScreenState();
}

class _ActivitiesScreenState extends ConsumerState<ActivitiesScreen> {
  _View _view = _View.upcoming;
  DateTime _day = DateUtils.dateOnly(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final programmes = ref.watch(visibleProgrammesProvider);
    final regs = ref.watch(myRegistrationsProvider).value ?? const [];
    final regByProgramme = {for (final r in regs) r.programmeId: r};

    return Scaffold(
      appBar: AppBar(title: const Text('Well-being Activities')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(myRegistrationsProvider);
          final _ = await ref.refresh(visibleProgrammesProvider.future);
        },
        child: ListView(
          padding: AppSpacing.page,
          children: [
            ResponsiveCenter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SegmentedButton<_View>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(value: _View.upcoming, label: Text('Upcoming')),
                        ButtonSegment(value: _View.mine, label: Text('My activities')),
                        ButtonSegment(value: _View.completed, label: Text('Completed')),
                        ButtonSegment(value: _View.calendar, icon: Icon(Icons.calendar_month_rounded), label: Text('Calendar')),
                      ],
                      selected: {_view},
                      onSelectionChanged: (s) => setState(() => _view = s.first),
                    ),
                  ),
                  AppSpacing.gapMd,
                  programmes.when(
                    loading: () => const Padding(padding: EdgeInsets.all(AppSpacing.xl), child: LoadingView()),
                    error: (e, _) => SizedBox(
                      height: 320,
                      child: ErrorView(error: e, onRetry: () => ref.invalidate(visibleProgrammesProvider)),
                    ),
                    data: (all) {
                      List<Programme> list;
                      switch (_view) {
                        case _View.upcoming:
                          list = all.where((p) => !p.hasEnded && p.status == ProgrammeStatus.published).toList();
                        case _View.mine:
                          list = all
                              .where((p) => regByProgramme[p.id]?.status == RegistrationStatus.registered && !p.hasEnded)
                              .toList();
                        case _View.completed:
                          list = all
                              .where((p) => p.hasEnded && (regByProgramme[p.id]?.status.isActive ?? false))
                              .toList()
                            ..sort((a, b) => b.startsAt.compareTo(a.startsAt));
                        case _View.calendar:
                          list = all.where((p) => DateUtils.isSameDay(p.startsAt.toLocal(), _day)).toList();
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_view == _View.calendar) ...[
                            AppCard(
                              padding: const EdgeInsets.all(AppSpacing.xs),
                              child: MonthCalendar(
                                selected: _day,
                                markedDays: {
                                  for (final p in all.where((p) => p.status != ProgrammeStatus.cancelled))
                                    DateUtils.dateOnly(p.startsAt.toLocal()),
                                },
                                onSelected: (d) => setState(() => _day = d),
                              ),
                            ),
                            SectionHeader(title: AppDates.day(_day)),
                          ],
                          if (list.isEmpty)
                            SizedBox(
                              height: 240,
                              child: EmptyView(
                                title: switch (_view) {
                                  _View.upcoming => 'No upcoming activities',
                                  _View.mine => 'You have not joined anything yet',
                                  _View.completed => 'No completed activities yet',
                                  _View.calendar => 'Nothing on this day',
                                },
                                message: _view == _View.mine
                                    ? 'Browse upcoming activities and register for one that interests you.'
                                    : null,
                                icon: Icons.celebration_outlined,
                              ),
                            )
                          else
                            for (final p in list) ...[
                              ProgrammeCard(programme: p, registration: regByProgramme[p.id]?.status),
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

class ProgrammeCard extends StatelessWidget {
  const ProgrammeCard({super.key, required this.programme, this.registration, this.onTap});

  final Programme programme;
  final RegistrationStatus? registration;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = programme;
    return AppCard(
      onTap: onTap ?? () => context.push(AppRoutes.activityDetail(p.id)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconBubble(icon: programmeCategoryIcon(p.category), size: 52, color: AppColors.lavenderDeep),
          AppSpacing.gapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.title, style: context.text.titleSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                AppSpacing.gapXxs,
                Text(AppDates.dayTime(p.startsAt), style: context.text.bodySmall),
                AppSpacing.gapXs,
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xxs,
                  children: [
                    StatusChip(label: p.mode.label, color: AppColors.sageDeep, icon: p.mode.icon),
                    StatusChip(label: p.category, color: context.colors.primary),
                    if (p.status != ProgrammeStatus.published) StatusChip(label: p.status.label, color: p.status.color),
                    if (registration != null && registration != RegistrationStatus.cancelled)
                      StatusChip(label: registration!.label, color: registration!.color, icon: Icons.check_rounded),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
