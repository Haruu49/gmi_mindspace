import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/widgets.dart';
import '../../wellbeing_activities/data/programme_repository.dart';
import '../../wellbeing_activities/domain/programme.dart';

/// Create (programmeId == null) or edit a well-being programme.
class ProgrammeEditorScreen extends ConsumerWidget {
  const ProgrammeEditorScreen({super.key, this.programmeId});

  final String? programmeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (programmeId == null) return const _Form();
    final p = ref.watch(programmeDetailProvider(programmeId!));
    return p.when(
      data: (prog) => _Form(existing: prog),
      loading: () => const Scaffold(body: LoadingView()),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: ErrorView(error: e, onRetry: () => ref.invalidate(programmeDetailProvider(programmeId!))),
      ),
    );
  }
}

class _Form extends ConsumerStatefulWidget {
  const _Form({this.existing});

  final Programme? existing;

  @override
  ConsumerState<_Form> createState() => _FormState();
}

class _FormState extends ConsumerState<_Form> {
  final _formKey = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.existing?.title);
  late final _description = TextEditingController(text: widget.existing?.description);
  late final _location = TextEditingController(text: widget.existing?.location);
  late final _url = TextEditingController(text: widget.existing?.onlineUrl);
  late final _capacity = TextEditingController(text: widget.existing?.capacity?.toString());
  late String _category = widget.existing?.category ?? 'Workshop';
  late ProgrammeMode _mode = widget.existing?.mode ?? ProgrammeMode.physical;
  late DateTime _start = widget.existing?.startsAt.toLocal() ??
      DateTime.now().add(const Duration(days: 7)).copyWith(hour: 14, minute: 0, second: 0, millisecond: 0, microsecond: 0);
  late DateTime _end = widget.existing?.endsAt.toLocal() ?? _start.add(const Duration(hours: 1, minutes: 30));
  late bool _publish = widget.existing?.status == ProgrammeStatus.published;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_title, _description, _location, _url, _capacity]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _start,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d == null) return;
    setState(() {
      final duration = _end.difference(_start);
      _start = DateTime(d.year, d.month, d.day, _start.hour, _start.minute);
      _end = _start.add(duration);
    });
  }

  Future<void> _pickTime({required bool start}) async {
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(start ? _start : _end));
    if (t == null) return;
    setState(() {
      if (start) {
        final duration = _end.difference(_start);
        _start = DateTime(_start.year, _start.month, _start.day, t.hour, t.minute);
        _end = _start.add(duration);
      } else {
        _end = DateTime(_start.year, _start.month, _start.day, t.hour, t.minute);
      }
    });
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    if (!_end.isAfter(_start)) {
      showAppSnack(context, 'The end time must be after the start time.', isError: true);
      return;
    }
    final keepStatus = widget.existing?.status;
    final status = _publish
        ? ProgrammeStatus.published
        : (keepStatus == ProgrammeStatus.cancelled || keepStatus == ProgrammeStatus.completed
            ? keepStatus!
            : ProgrammeStatus.draft);
    final draft = ProgrammeDraft(
      title: _title.text,
      description: _description.text,
      category: _category,
      mode: _mode,
      startsAt: _start,
      endsAt: _end,
      status: status,
      location: _location.text,
      onlineUrl: _url.text,
      capacity: int.tryParse(_capacity.text.trim()),
      imageUrl: widget.existing?.imageUrl,
    );
    setState(() => _saving = true);
    try {
      final repo = ref.read(programmeRepositoryProvider);
      if (widget.existing == null) {
        final id = await repo.create(draft);
        ref.invalidate(allProgrammesProvider);
        if (mounted) context.pushReplacement(AppRoutes.counsellorProgramme(id));
      } else {
        await repo.update(widget.existing!.id, draft);
        ref
          ..invalidate(allProgrammesProvider)
          ..invalidate(programmeDetailProvider(widget.existing!.id));
        if (mounted) context.pop();
      }
      if (mounted) showAppSnack(context, _publish ? 'Programme saved and published.' : 'Programme saved as draft.');
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.existing == null ? 'New programme' : 'Edit programme')),
      body: Form(
        key: _formKey,
        child: PageBody(
          children: [
            AppTextField(
              controller: _title,
              label: 'Title',
              maxLength: 150,
              textCapitalization: TextCapitalization.sentences,
              validator: (v) => Validators.requiredText(v, field: 'Title', minLength: 3, maxLength: 150),
            ),
            AppSpacing.gapSm,
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Type'),
              items: [for (final c in programmeCategories) DropdownMenuItem(value: c, child: Text(c))],
              onChanged: (v) => setState(() => _category = v ?? _category),
            ),
            AppSpacing.gapMd,
            AppTextField(
              controller: _description,
              label: 'Description',
              maxLines: 6,
              minLines: 3,
              maxLength: 4000,
              textCapitalization: TextCapitalization.sentences,
              validator: (v) => Validators.requiredText(v, field: 'Description', minLength: 10, maxLength: 4000),
            ),
            const SectionHeader(title: 'When'),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                ActionChip(avatar: const Icon(Icons.event_rounded, size: 18), label: Text(AppDates.day(_start)), onPressed: _pickDate),
                ActionChip(
                  avatar: const Icon(Icons.schedule_rounded, size: 18),
                  label: Text('Starts ${AppDates.time(_start)}'),
                  onPressed: () => _pickTime(start: true),
                ),
                ActionChip(
                  avatar: const Icon(Icons.schedule_rounded, size: 18),
                  label: Text('Ends ${AppDates.time(_end)}'),
                  onPressed: () => _pickTime(start: false),
                ),
              ],
            ),
            const SectionHeader(title: 'Where'),
            SegmentedButton<ProgrammeMode>(
              segments: [
                for (final m in ProgrammeMode.values) ButtonSegment(value: m, label: Text(m.label), icon: Icon(m.icon)),
              ],
              selected: {_mode},
              onSelectionChanged: (s) => setState(() => _mode = s.first),
            ),
            AppSpacing.gapMd,
            if (_mode.hasVenue) ...[
              AppTextField(
                controller: _location,
                label: 'Venue',
                maxLength: 150,
                validator: (v) => Validators.requiredText(v, field: 'Venue', maxLength: 150),
              ),
              AppSpacing.gapSm,
            ],
            if (_mode.hasOnline) ...[
              AppTextField(
                controller: _url,
                label: 'Online meeting link',
                hint: 'https://…',
                keyboardType: TextInputType.url,
                helper: 'Shown only to registered students.',
                validator: (v) {
                  final base = Validators.url(v, required: true);
                  if (base != null) return base;
                  return v!.trim().startsWith('https://') ? null : 'Please use a secure https:// link.';
                },
              ),
              AppSpacing.gapSm,
            ],
            AppTextField(
              controller: _capacity,
              label: 'Capacity (optional)',
              hint: 'Leave empty for unlimited',
              keyboardType: TextInputType.number,
              validator: (v) => (v?.trim().isEmpty ?? true) ? null : Validators.positiveInt(v, field: 'Capacity', max: 5000),
            ),
            AppSpacing.gapSm,
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Publish now'),
              subtitle: const Text('Students can see and register once published.'),
              value: _publish,
              onChanged: (v) => setState(() => _publish = v),
            ),
            AppSpacing.gapLg,
            AppButton(label: 'Save programme', isLoading: _saving, onPressed: _save),
          ],
        ),
      ),
    );
  }
}
