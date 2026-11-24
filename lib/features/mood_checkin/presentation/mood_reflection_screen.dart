import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/widgets.dart';
import '../data/mood_repository.dart';
import '../domain/mood.dart';
import 'widgets/mood_selector.dart';

/// Step 2 of a check-in: optional reason, note and a reflection prompt.
class MoodReflectionScreen extends ConsumerStatefulWidget {
  const MoodReflectionScreen({super.key, required this.initialMood});

  final Mood initialMood;

  @override
  ConsumerState<MoodReflectionScreen> createState() => _MoodReflectionScreenState();
}

class _MoodReflectionScreenState extends ConsumerState<MoodReflectionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _notes = TextEditingController();
  late Mood _mood = widget.initialMood;
  MoodReason? _reason;
  late String _prompt = _pickPrompt(widget.initialMood);
  bool _saving = false;

  String _pickPrompt(Mood m) => m.prompts[Random().nextInt(m.prompts.length)];

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(moodRepositoryProvider).addEntry(
            mood: _mood,
            reason: _reason,
            notes: _notes.text,
          );
      ref.invalidate(moodEntriesProvider);
      if (!mounted) return;
      setState(() => _saving = false);
      await _showSaved();
      if (mounted) context.go(AppRoutes.mood);
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _showSaved() {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(_mood.emoji, style: const TextStyle(fontSize: 56), textAlign: TextAlign.center),
              AppSpacing.gapSm,
              Text('Check-in saved', style: ctx.text.titleLarge, textAlign: TextAlign.center),
              AppSpacing.gapXs,
              Text(_mood.encouragement, style: ctx.text.bodyLarge, textAlign: TextAlign.center),
              AppSpacing.gapLg,
              if (_mood.suggestsSupport) ...[
                AppButton(
                  label: 'Try a breathing exercise',
                  icon: Icons.air_rounded,
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    context.go(AppRoutes.breathing);
                  },
                ),
                AppSpacing.gapSm,
                AppButton.outline(
                  label: 'Talk to a counsellor',
                  icon: Icons.event_available_rounded,
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    context.go(AppRoutes.booking);
                  },
                ),
                AppSpacing.gapSm,
              ],
              AppButton.text(
                label: 'Done',
                expand: true,
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reflect')),
      body: Form(
        key: _formKey,
        child: PageBody(
          children: [
            Text('You are feeling', style: context.text.labelMedium),
            AppSpacing.gapXs,
            MoodSelector(
              selected: _mood,
              onSelected: (m) => setState(() {
                _mood = m;
                _prompt = _pickPrompt(m);
              }),
            ),
            const SectionHeader(title: 'What is it related to? (optional)'),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final r in MoodReason.values)
                  FilterChip(
                    avatar: Icon(r.icon, size: 18),
                    label: Text(r.label),
                    selected: _reason == r,
                    onSelected: (v) => setState(() => _reason = v ? r : null),
                  ),
              ],
            ),
            const SectionHeader(title: 'Reflection prompt'),
            AppCard(
              color: context.colors.secondaryContainer,
              child: Row(
                children: [
                  Icon(Icons.lightbulb_outline_rounded, color: context.colors.onSecondaryContainer),
                  AppSpacing.gapSm,
                  Expanded(child: Text(_prompt, style: context.text.titleSmall)),
                  IconButton(
                    tooltip: 'Another prompt',
                    icon: const Icon(Icons.refresh_rounded),
                    onPressed: () => setState(() => _prompt = _pickPrompt(_mood)),
                  ),
                ],
              ),
            ),
            AppSpacing.gapMd,
            AppTextField(
              key: const Key('mood_notes'),
              controller: _notes,
              label: 'Notes (optional, private)',
              hint: 'Write as much or as little as you like…',
              maxLines: 5,
              minLines: 3,
              maxLength: AppConstants.maxMoodNoteLength,
              textCapitalization: TextCapitalization.sentences,
              validator: (v) =>
                  Validators.optionalText(v, maxLength: AppConstants.maxMoodNoteLength),
            ),
            AppSpacing.gapSm,
            Row(
              children: [
                Icon(Icons.lock_outline_rounded, size: 16, color: context.colors.onSurfaceVariant),
                AppSpacing.gapXs,
                Expanded(
                  child: Text(
                    'Only you can see this check-in.',
                    style: context.text.bodySmall,
                  ),
                ),
              ],
            ),
            AppSpacing.gapLg,
            AppButton(
              key: const Key('mood_save'),
              label: 'Save check-in',
              isLoading: _saving,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}
