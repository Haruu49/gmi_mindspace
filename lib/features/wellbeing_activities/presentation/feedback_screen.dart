import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/widgets.dart';
import '../data/programme_repository.dart';

class ProgrammeFeedbackScreen extends ConsumerStatefulWidget {
  const ProgrammeFeedbackScreen({super.key, required this.programmeId});

  final String programmeId;

  @override
  ConsumerState<ProgrammeFeedbackScreen> createState() => _ProgrammeFeedbackScreenState();
}

class _ProgrammeFeedbackScreenState extends ConsumerState<ProgrammeFeedbackScreen> {
  final _formKey = GlobalKey<FormState>();
  final _comment = TextEditingController();
  int _rating = 0;
  bool _anonymous = false;
  bool _saving = false;
  String? _ratingError;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _ratingError = _rating == 0 ? 'Please choose a rating.' : null);
    if (!_formKey.currentState!.validate() || _rating == 0) return;
    setState(() => _saving = true);
    try {
      await ref.read(programmeRepositoryProvider).submitFeedback(
            programmeId: widget.programmeId,
            rating: _rating,
            comment: _comment.text,
            anonymous: _anonymous,
          );
      ref.invalidate(myFeedbackIdsProvider);
      if (!mounted) return;
      showAppSnack(context, 'Thank you for your feedback!');
      context.pop();
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final programme = ref.watch(programmeDetailProvider(widget.programmeId)).value;
    return Scaffold(
      appBar: AppBar(title: const Text('Share feedback')),
      body: Form(
        key: _formKey,
        child: PageBody(
          children: [
            if (programme != null) Text(programme.title, style: context.text.titleLarge),
            AppSpacing.gapXs,
            Text('Your feedback helps the Counselling Unit plan better activities.', style: context.text.bodyMedium),
            const SectionHeader(title: 'How was it overall?'),
            Semantics(
              label: 'Rating: $_rating out of 5',
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 1; i <= 5; i++)
                    IconButton(
                      key: Key('rating_$i'),
                      tooltip: '$i star${i == 1 ? '' : 's'}',
                      iconSize: 40,
                      onPressed: () => setState(() {
                        _rating = i;
                        _ratingError = null;
                      }),
                      icon: Icon(
                        i <= _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                        color: AppColors.warning,
                      ),
                    ),
                ],
              ),
            ),
            if (_ratingError != null)
              Text(_ratingError!, style: context.text.bodySmall?.copyWith(color: context.colors.error), textAlign: TextAlign.center),
            AppSpacing.gapMd,
            AppTextField(
              controller: _comment,
              label: 'Comments (optional)',
              hint: 'What did you enjoy? What could be better?',
              maxLines: 5,
              minLines: 3,
              maxLength: AppConstants.maxFeedbackLength,
              textCapitalization: TextCapitalization.sentences,
              validator: (v) => Validators.optionalText(v, maxLength: AppConstants.maxFeedbackLength),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Submit anonymously'),
              subtitle: const Text('Counsellors will not see your name with this feedback.'),
              value: _anonymous,
              onChanged: (v) => setState(() => _anonymous = v),
            ),
            AppSpacing.gapLg,
            AppButton(label: 'Submit feedback', isLoading: _saving, onPressed: _submit),
          ],
        ),
      ),
    );
  }
}
