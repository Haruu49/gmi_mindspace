import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';

/// 5-4-3-2-1 grounding. Anything typed here stays on the device and is
/// discarded when the screen closes.
class GroundingScreen extends StatefulWidget {
  const GroundingScreen({super.key});

  @override
  State<GroundingScreen> createState() => _GroundingScreenState();
}

class _GroundingScreenState extends State<GroundingScreen> {
  static const _steps = <(int, String, IconData)>[
    (5, 'things you can see', Icons.visibility_outlined),
    (4, 'things you can touch', Icons.back_hand_outlined),
    (3, 'things you can hear', Icons.hearing_rounded),
    (2, 'things you can smell', Icons.local_florist_outlined),
    (1, 'thing you can taste', Icons.restaurant_outlined),
  ];

  int _index = 0;
  final Map<int, List<bool>> _ticked = {
    for (var i = 0; i < _steps.length; i++) i: List.filled(_steps[i].$1, false),
  };

  @override
  Widget build(BuildContext context) {
    final (count, text, icon) = _steps[_index];
    final last = _index == _steps.length - 1;
    return Scaffold(
      appBar: AppBar(title: const Text('5-4-3-2-1 grounding')),
      body: PageBody(
        children: [
          LinearProgressIndicator(value: (_index + 1) / _steps.length, minHeight: 6),
          AppSpacing.gapLg,
          Center(child: IconBubble(icon: icon, size: 72, color: AppColors.sageDeep)),
          AppSpacing.gapMd,
          Semantics(
            liveRegion: true,
            child: Text(
              'Notice $count $text',
              style: context.text.headlineSmall,
              textAlign: TextAlign.center,
            ),
          ),
          AppSpacing.gapXs,
          Text(
            'Take your time. Look around and tap each one as you notice it.',
            style: context.text.bodyMedium,
            textAlign: TextAlign.center,
          ),
          AppSpacing.gapLg,
          Wrap(
            alignment: WrapAlignment.center,
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (var i = 0; i < count; i++)
                FilterChip(
                  label: Text('${i + 1}'),
                  selected: _ticked[_index]![i],
                  onSelected: (v) => setState(() => _ticked[_index]![i] = v),
                ),
            ],
          ),
          AppSpacing.gapXl,
          Row(
            children: [
              if (_index > 0)
                Expanded(
                  child: AppButton.outline(
                    label: 'Back',
                    onPressed: () => setState(() => _index--),
                  ),
                ),
              if (_index > 0) AppSpacing.gapSm,
              Expanded(
                child: AppButton(
                  label: last ? 'Finish' : 'Next',
                  onPressed: () {
                    if (last) {
                      context.pushReplacement(
                        Uri(path: AppRoutes.selfCareComplete, queryParameters: {'activity': 'grounding-54321'})
                            .toString(),
                      );
                    } else {
                      setState(() => _index++);
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
