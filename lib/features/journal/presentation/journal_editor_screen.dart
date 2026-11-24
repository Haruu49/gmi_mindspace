import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/widgets.dart';
import '../data/journal_repository.dart';
import '../domain/journal_entry.dart';

/// Create (entryId == null) or edit a journal entry.
class JournalEditorScreen extends ConsumerWidget {
  const JournalEditorScreen({super.key, this.entryId, this.prompt, this.gratitude = false});

  final String? entryId;
  final String? prompt;
  final bool gratitude;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (entryId == null) {
      return _EditorForm(initialPrompt: prompt, initialGratitude: gratitude);
    }
    final entry = ref.watch(journalEntryProvider(entryId!));
    return entry.when(
      data: (e) => _EditorForm(existing: e),
      loading: () => const Scaffold(body: LoadingView()),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: ErrorView(error: e, onRetry: () => ref.invalidate(journalEntryProvider(entryId!))),
      ),
    );
  }
}

class _EditorForm extends ConsumerStatefulWidget {
  const _EditorForm({this.existing, this.initialPrompt, this.initialGratitude = false});

  final JournalEntry? existing;
  final String? initialPrompt;
  final bool initialGratitude;

  @override
  ConsumerState<_EditorForm> createState() => _EditorFormState();
}

class _EditorFormState extends ConsumerState<_EditorForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _content;
  late DateTime _date;
  String? _prompt;
  late bool _gratitude;
  bool _saving = false;
  bool _dirty = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _prompt = e?.prompt ?? widget.initialPrompt;
    _gratitude = e?.isGratitude ?? widget.initialGratitude;
    _date = e?.entryDate ?? DateTime.now();
    _title = TextEditingController(
      text: e?.title ?? (_gratitude ? 'Grateful for…' : ''),
    )..addListener(_markDirty);
    _content = TextEditingController(
      text: e?.content ?? (_gratitude ? '1. \n2. \n3. ' : ''),
    )..addListener(_markDirty);
  }

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(DateTime.now().year - 2),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _date = picked;
        _dirty = true;
      });
    }
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final draft = JournalDraft(
      title: _title.text,
      content: _content.text,
      entryDate: _date,
      prompt: _prompt,
      isGratitude: _gratitude,
    );
    try {
      final repo = ref.read(journalRepositoryProvider);
      if (_isEdit) {
        await repo.update(widget.existing!.id, draft);
        ref.invalidate(journalEntryProvider(widget.existing!.id));
      } else {
        await repo.create(draft);
      }
      ref.invalidate(journalEntriesProvider);
      if (!mounted) return;
      showAppSnack(context, _isEdit ? 'Entry updated.' : 'Entry saved.');
      _dirty = false;
      context.pop();
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<bool> _confirmDiscard() async {
    if (!_dirty) return true;
    return showConfirmDialog(
      context,
      title: 'Discard changes?',
      message: 'Your unsaved writing will be lost.',
      confirmLabel: 'Discard',
      destructive: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmDiscard() && context.mounted) {
          setState(() => _dirty = false);
          context.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isEdit ? 'Edit entry' : 'New entry'),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.xs),
              child: AppButton.text(
                key: const Key('journal_save'),
                label: 'Save',
                isLoading: _saving,
                onPressed: _save,
              ),
            ),
          ],
        ),
        body: Form(
          key: _formKey,
          child: PageBody(
            children: [
              Row(
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.calendar_today_rounded, size: 18),
                    label: Text(AppDates.day(_date)),
                    onPressed: _pickDate,
                  ),
                  AppSpacing.gapXs,
                  FilterChip(
                    avatar: const Icon(Icons.favorite_border_rounded, size: 18),
                    label: const Text('Gratitude'),
                    selected: _gratitude,
                    onSelected: (v) => setState(() {
                      _gratitude = v;
                      _dirty = true;
                    }),
                  ),
                ],
              ),
              if (_prompt != null) ...[
                AppSpacing.gapSm,
                InfoBanner(message: _prompt!, icon: Icons.lightbulb_outline_rounded),
              ],
              AppSpacing.gapMd,
              AppTextField(
                key: const Key('journal_title'),
                controller: _title,
                label: 'Title',
                maxLength: AppConstants.maxJournalTitleLength,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
                validator: (v) => Validators.requiredText(
                  v, field: 'Title', maxLength: AppConstants.maxJournalTitleLength),
              ),
              AppSpacing.gapSm,
              AppTextField(
                key: const Key('journal_content'),
                controller: _content,
                label: _gratitude ? 'Three good things' : 'Write freely',
                hint: _gratitude
                    ? 'List three things that went well or that you appreciate.'
                    : 'This space is just for you…',
                maxLines: 14,
                minLines: 8,
                maxLength: AppConstants.maxJournalContentLength,
                textCapitalization: TextCapitalization.sentences,
                validator: (v) => Validators.requiredText(
                  v, field: 'Entry', maxLength: AppConstants.maxJournalContentLength),
              ),
              AppSpacing.gapSm,
              Row(
                children: [
                  Icon(Icons.lock_outline_rounded, size: 16, color: context.colors.onSurfaceVariant),
                  AppSpacing.gapXs,
                  Expanded(
                    child: Text(
                      'Private: counsellors and administrators cannot read your journal.',
                      style: context.text.bodySmall,
                    ),
                  ),
                ],
              ),
              AppSpacing.gapLg,
              AppButton(label: _isEdit ? 'Save changes' : 'Save entry', isLoading: _saving, onPressed: _save),
            ],
          ),
        ),
      ),
    );
  }
}
