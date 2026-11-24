import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/widgets.dart';
import '../../journal/data/journal_repository.dart';
import '../../journal/domain/journal_entry.dart';

/// Record three positive things. Saved privately as a gratitude journal entry.
class GratitudeScreen extends ConsumerStatefulWidget {
  const GratitudeScreen({super.key});

  @override
  ConsumerState<GratitudeScreen> createState() => _GratitudeScreenState();
}

class _GratitudeScreenState extends ConsumerState<GratitudeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _items = List.generate(3, (_) => TextEditingController());
  bool _saving = false;

  @override
  void dispose() {
    for (final c in _items) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final content = [
        for (var i = 0; i < 3; i++) '${i + 1}. ${_items[i].text.trim()}',
      ].join('\n');
      await ref.read(journalRepositoryProvider).create(
            JournalDraft(
              title: 'Three good things',
              content: content,
              entryDate: DateTime.now(),
              prompt: 'What are you grateful for?',
              isGratitude: true,
            ),
          );
      ref.invalidate(journalEntriesProvider);
      if (!mounted) return;
      context.pushReplacement(
        Uri(path: AppRoutes.selfCareComplete, queryParameters: {'activity': 'three-good-things'}).toString(),
      );
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const hints = ['A moment that made you smile', 'Someone you appreciate', 'Something you did well'];
    return Scaffold(
      appBar: AppBar(title: const Text('Three good things')),
      body: Form(
        key: _formKey,
        child: PageBody(
          children: [
            Text('What went well today?', style: context.text.titleLarge),
            AppSpacing.gapXs,
            Text('Big or small – everything counts.', style: context.text.bodyMedium),
            AppSpacing.gapLg,
            for (var i = 0; i < 3; i++) ...[
              AppTextField(
                key: Key('gratitude_$i'),
                controller: _items[i],
                label: 'Good thing ${i + 1}',
                hint: hints[i],
                prefixIcon: Icons.favorite_border_rounded,
                maxLength: 200,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: i < 2 ? TextInputAction.next : TextInputAction.done,
                validator: (v) => Validators.requiredText(v, field: 'This', minLength: 2, maxLength: 200),
              ),
              AppSpacing.gapSm,
            ],
            Row(
              children: [
                Icon(Icons.lock_outline_rounded, size: 16, color: context.colors.onSurfaceVariant),
                AppSpacing.gapXs,
                Expanded(
                  child: Text('Saved privately in your journal.', style: context.text.bodySmall),
                ),
              ],
            ),
            AppSpacing.gapLg,
            AppButton(label: 'Save', isLoading: _saving, onPressed: _save),
          ],
        ),
      ),
    );
  }
}
