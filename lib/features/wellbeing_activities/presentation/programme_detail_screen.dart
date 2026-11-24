import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/widgets.dart';
import '../data/programme_repository.dart';
import '../domain/programme.dart';

/// Student view of a well-being activity.
class ProgrammeDetailScreen extends ConsumerStatefulWidget {
  const ProgrammeDetailScreen({super.key, required this.programmeId});

  final String programmeId;

  @override
  ConsumerState<ProgrammeDetailScreen> createState() => _ProgrammeDetailScreenState();
}

class _ProgrammeDetailScreenState extends ConsumerState<ProgrammeDetailScreen> {
  bool _busy = false;

  void _refresh() {
    ref.invalidate(programmeDetailProvider(widget.programmeId));
    ref.invalidate(myRegistrationsProvider);
  }

  Future<void> _register(Programme p) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Register for this activity?',
      message: '${p.title}\n${AppDates.dayTime(p.startsAt)}',
      confirmLabel: 'Register',
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(programmeRepositoryProvider).register(p.id);
      _refresh();
      if (!mounted) return;
      setState(() => _busy = false);
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.celebration_rounded, color: AppColors.success, size: 40),
          title: const Text('You are registered!'),
          content: Text('See you at "${p.title}" on ${AppDates.dayTime(p.startsAt)}. '
              'We will remind you the day before.'),
          actions: [FilledButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Great'))],
        ),
      );
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel(Programme p) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Cancel your registration?',
      message: 'Your place will be offered to another student.',
      confirmLabel: 'Cancel registration',
      cancelLabel: 'Keep my place',
      destructive: true,
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(programmeRepositoryProvider).cancelRegistration(p.id);
      _refresh();
      if (mounted) showAppSnack(context, 'Registration cancelled.');
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final programme = ref.watch(programmeDetailProvider(widget.programmeId));
    final regs = ref.watch(myRegistrationsProvider).value ?? const [];
    final reg = regs.where((r) => r.programmeId == widget.programmeId).firstOrNull;
    final gaveFeedback = ref.watch(myFeedbackIdsProvider).value?.contains(widget.programmeId) ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Activity')),
      body: AsyncValueView<Programme>(
        value: programme,
        onRetry: _refresh,
        data: (p) {
          final registered = reg?.status == RegistrationStatus.registered;
          final active = reg?.status.isActive ?? false;
          return PageBody(
            children: [
              AppCard(
                gradient: LinearGradient(colors: [context.colors.primaryContainer, context.colors.secondaryContainer]),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IconBubble(icon: programmeCategoryIcon(p.category), size: 56),
                    AppSpacing.gapSm,
                    Text(p.title, style: context.text.headlineSmall),
                    AppSpacing.gapXs,
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xxs,
                      children: [
                        StatusChip(label: p.category, color: context.colors.primary),
                        StatusChip(label: p.mode.label, color: AppColors.sageDeep, icon: p.mode.icon),
                        if (p.status != ProgrammeStatus.published) StatusChip(label: p.status.label, color: p.status.color),
                        if (reg != null) StatusChip(label: reg.status.label, color: reg.status.color),
                      ],
                    ),
                  ],
                ),
              ),
              AppSpacing.gapMd,
              DetailRow(icon: Icons.event_rounded, label: 'Date', value: AppDates.day(p.startsAt)),
              DetailRow(
                icon: Icons.schedule_rounded,
                label: 'Time',
                value: '${AppDates.time(p.startsAt)} – ${AppDates.time(p.endsAt)}',
              ),
              if (p.location != null) DetailRow(icon: Icons.place_outlined, label: 'Venue', value: p.location!),
              if (p.capacity != null)
                DetailRow(icon: Icons.groups_outlined, label: 'Places', value: 'Limited to ${p.capacity} students'),
              const SectionHeader(title: 'About this activity'),
              Text(p.description, style: context.text.bodyLarge),
              if (p.onlineUrl != null && registered) ...[
                AppSpacing.gapMd,
                AppButton.outline(
                  label: 'Open online session link',
                  icon: Icons.videocam_outlined,
                  onPressed: () => launchUrl(Uri.parse(p.onlineUrl!), mode: LaunchMode.externalApplication),
                ),
              ] else if (p.mode.hasOnline && !registered && !p.hasEnded) ...[
                AppSpacing.gapSm,
                Text('The online link appears here after you register.', style: context.text.bodySmall),
              ],
              AppSpacing.gapLg,
              if (p.status == ProgrammeStatus.cancelled)
                InfoBanner(message: 'This activity has been cancelled.', color: context.colors.error)
              else if (p.openForRegistration && !registered)
                AppButton(
                  key: const Key('programme_register'),
                  label: 'Register',
                  icon: Icons.how_to_reg_rounded,
                  isLoading: _busy,
                  onPressed: () => _register(p),
                )
              else if (p.openForRegistration && registered)
                AppButton.outline(
                  label: 'Cancel registration',
                  isLoading: _busy,
                  onPressed: () => _cancel(p),
                )
              else if (!p.hasStarted)
                const InfoBanner(message: 'Registration is not open.'),
              if (p.hasStarted && active) ...[
                AppSpacing.gapSm,
                gaveFeedback
                    ? const InfoBanner(
                        message: 'Thanks for sharing your feedback!',
                        icon: Icons.favorite_rounded,
                        color: AppColors.success,
                      )
                    : AppButton(
                        label: 'Share feedback',
                        icon: Icons.rate_review_outlined,
                        onPressed: () => context.push(AppRoutes.activityFeedback(p.id)),
                      ),
              ],
            ],
          );
        },
      ),
    );
  }
}
