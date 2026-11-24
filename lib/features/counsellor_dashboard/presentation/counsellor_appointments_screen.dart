import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../counselling/data/counselling_repository.dart';
import '../../counselling/domain/appointment.dart';
import '../../counselling/presentation/widgets/appointment_card.dart';

/// Appointment management: search, status filters, quick access to detail.
/// The list shows names, type, time and status only – never student notes.
class CounsellorAppointmentsScreen extends ConsumerStatefulWidget {
  const CounsellorAppointmentsScreen({super.key});

  @override
  ConsumerState<CounsellorAppointmentsScreen> createState() => _CounsellorAppointmentsScreenState();
}

class _CounsellorAppointmentsScreenState extends ConsumerState<CounsellorAppointmentsScreen> {
  AppointmentStatus? _status = AppointmentStatus.pending;
  String _search = '';
  bool _upcomingOnly = true;

  @override
  Widget build(BuildContext context) {
    final appts = ref.watch(counsellorAppointmentsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Appointments'),
        actions: [
          IconButton(
            tooltip: 'Manage availability',
            icon: const Icon(Icons.schedule_rounded),
            onPressed: () => context.push(AppRoutes.counsellorAvailability),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          final _ = await ref.refresh(counsellorAppointmentsProvider.future);
        },
        child: ListView(
          padding: AppSpacing.page,
          children: [
            ResponsiveCenter(
              maxWidth: 900,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    onChanged: (v) => setState(() => _search = v.trim().toLowerCase()),
                    decoration: const InputDecoration(
                      hintText: 'Search by student name',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  ),
                  AppSpacing.gapSm,
                  SizedBox(
                    height: 44,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        ChoiceChip(
                          label: const Text('All'),
                          selected: _status == null,
                          onSelected: (_) => setState(() => _status = null),
                        ),
                        for (final s in AppointmentStatus.values)
                          Padding(
                            padding: const EdgeInsets.only(left: AppSpacing.xs),
                            child: ChoiceChip(
                              avatar: Icon(s.icon, size: 18, color: s.color),
                              label: Text(s.label),
                              selected: _status == s,
                              onSelected: (_) => setState(() => _status = s),
                            ),
                          ),
                      ],
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Upcoming only'),
                    value: _upcomingOnly,
                    onChanged: (v) => setState(() => _upcomingOnly = v),
                  ),
                  appts.when(
                    loading: () => const Padding(padding: EdgeInsets.all(AppSpacing.xl), child: LoadingView()),
                    error: (e, _) => SizedBox(
                      height: 300,
                      child: ErrorView(error: e, onRetry: () => ref.invalidate(counsellorAppointmentsProvider)),
                    ),
                    data: (all) {
                      final now = DateTime.now();
                      final list = all.where((a) {
                        if (_status != null && a.status != _status) return false;
                        if (_upcomingOnly && a.endsAt.isBefore(now)) return false;
                        if (_search.isNotEmpty && !(a.studentName ?? '').toLowerCase().contains(_search)) return false;
                        return true;
                      }).toList();
                      if (!_upcomingOnly) list.sort((a, b) => b.startsAt.compareTo(a.startsAt));
                      if (list.isEmpty) {
                        return const SizedBox(
                          height: 240,
                          child: EmptyView(title: 'No appointments match', icon: Icons.event_note_rounded),
                        );
                      }
                      return Column(
                        children: [
                          for (final a in list) ...[
                            AppointmentCard(
                              appointment: a,
                              showStudent: true,
                              onTap: () => context.push(AppRoutes.counsellorAppointment(a.id)),
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
