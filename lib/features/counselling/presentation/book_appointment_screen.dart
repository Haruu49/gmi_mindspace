import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/failure.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/widgets.dart';
import '../../../shared/widgets/month_calendar.dart';
import '../data/counselling_repository.dart';
import '../domain/appointment.dart';

class BookAppointmentScreen extends ConsumerStatefulWidget {
  const BookAppointmentScreen({super.key});

  @override
  ConsumerState<BookAppointmentScreen> createState() => _BookAppointmentScreenState();
}

class _BookAppointmentScreenState extends ConsumerState<BookAppointmentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _reason = TextEditingController();
  AppointmentType? _type;
  DateTime? _day;
  OpenSlot? _slot;
  bool _submitting = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_type == null || _slot == null) {
      showAppSnack(context, 'Please choose a type, date and time.', isError: true);
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    final ok = await showConfirmDialog(
      context,
      title: 'Send this request?',
      message: '${_type!.label}\n${AppDates.dayTime(_slot!.startsAt)}\nwith ${_slot!.counsellorName}\n\n'
          'The counsellor will confirm or suggest another time.',
      confirmLabel: 'Send request',
    );
    if (!ok || !mounted) return;
    setState(() => _submitting = true);
    try {
      final id = await ref.read(counsellingRepositoryProvider).requestAppointment(
            availabilityId: _slot!.availabilityId,
            type: _type!,
            reason: _reason.text,
          );
      ref.invalidate(myAppointmentsProvider);
      ref.invalidate(openSlotsProvider);
      if (!mounted) return;
      showAppSnack(context, 'Request sent. We will let you know when it is confirmed.');
      context.pushReplacement(AppRoutes.bookingDetail(id));
    } catch (e) {
      final f = AppFailure.from(e);
      if (f.kind == FailureKind.conflict) {
        ref.invalidate(openSlotsProvider);
        setState(() => _slot = null);
      }
      if (mounted) showErrorSnack(context, f);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final slots = ref.watch(openSlotsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Request appointment')),
      body: Form(
        key: _formKey,
        child: PageBody(
          children: [
            const SectionHeader(title: '1. What would you like support with?', padding: EdgeInsets.only(bottom: AppSpacing.sm)),
            for (final t in AppointmentType.values) ...[
              AppCard(
                onTap: () => setState(() => _type = t),
                borderColor: _type == t ? context.colors.primary : null,
                color: _type == t ? context.colors.primaryContainer : null,
                child: Row(
                  children: [
                    IconBubble(icon: t.icon),
                    AppSpacing.gapMd,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t.label, style: context.text.titleSmall),
                          Text(t.description, style: context.text.bodySmall),
                        ],
                      ),
                    ),
                    Icon(
                      _type == t ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                      color: context.colors.primary,
                    ),
                  ],
                ),
              ),
              AppSpacing.gapSm,
            ],
            const SectionHeader(title: '2. Pick a date'),
            slots.when(
              loading: () => const SizedBox(height: 200, child: LoadingView(message: 'Finding open times…')),
              error: (e, _) => SizedBox(
                height: 300,
                child: ErrorView(error: e, onRetry: () => ref.invalidate(openSlotsProvider)),
              ),
              data: (list) {
                if (list.isEmpty) {
                  return const InfoBanner(
                    icon: Icons.event_busy_rounded,
                    message: 'There are no open times in the next 30 days. Please check again '
                        'soon, or visit the Counselling Unit in person.',
                  );
                }
                final days = {for (final s in list) DateUtils.dateOnly(s.startsAt.toLocal())};
                final daySlots = _day == null
                    ? const <OpenSlot>[]
                    : list.where((s) => DateUtils.isSameDay(s.startsAt.toLocal(), _day)).toList();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppCard(
                      padding: const EdgeInsets.all(AppSpacing.xs),
                      child: MonthCalendar(
                        selected: _day,
                        markedDays: days,
                        firstDay: DateTime.now(),
                        lastDay: DateTime.now().add(const Duration(days: 31)),
                        onlyMarkedSelectable: true,
                        onSelected: (d) => setState(() {
                          _day = d;
                          _slot = null;
                        }),
                      ),
                    ),
                    const SectionHeader(title: '3. Choose a time'),
                    if (_day == null)
                      Text('Days with a dot have open times.', style: context.text.bodyMedium)
                    else
                      Wrap(
                        spacing: AppSpacing.xs,
                        runSpacing: AppSpacing.xs,
                        children: [
                          for (final s in daySlots)
                            ChoiceChip(
                              label: Text('${AppDates.time(s.startsAt)} · ${s.counsellorName}'),
                              selected: _slot?.availabilityId == s.availabilityId,
                              onSelected: (_) => setState(() => _slot = s),
                            ),
                        ],
                      ),
                    if (_slot?.location != null) ...[
                      AppSpacing.gapSm,
                      DetailRow(icon: Icons.place_outlined, label: 'Location', value: _slot!.location!),
                    ],
                  ],
                );
              },
            ),
            const SectionHeader(title: '4. Anything you would like to mention? (optional)'),
            AppTextField(
              controller: _reason,
              label: 'Short note for the counsellor',
              hint: 'For example: exam stress, feeling low lately…',
              helper: 'Keep it brief – you can share more in person. Only your counsellor sees this.',
              maxLines: 4,
              minLines: 2,
              maxLength: AppConstants.maxAppointmentReasonLength,
              textCapitalization: TextCapitalization.sentences,
              validator: (v) =>
                  Validators.optionalText(v, maxLength: AppConstants.maxAppointmentReasonLength),
            ),
            AppSpacing.gapLg,
            AppButton(
              key: const Key('booking_submit'),
              label: 'Send request',
              isLoading: _submitting,
              onPressed: _submit,
            ),
            AppSpacing.gapMd,
            Text(
              'Need help urgently? Use Get Help Now instead – appointment requests are not monitored 24/7.',
              style: context.text.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
