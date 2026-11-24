import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/mood.dart';

/// Row of five tappable emoji moods. Wraps gracefully on narrow screens.
class MoodSelector extends StatelessWidget {
  const MoodSelector({super.key, required this.onSelected, this.selected});

  final ValueChanged<Mood> onSelected;
  final Mood? selected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth / 5).clamp(56.0, 96.0);
        return Wrap(
          alignment: WrapAlignment.spaceBetween,
          runSpacing: AppSpacing.xs,
          children: [
            for (final m in Mood.values)
              SizedBox(
                width: itemWidth,
                child: _MoodButton(
                  mood: m,
                  selected: selected == m,
                  onTap: () => onSelected(m),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _MoodButton extends StatelessWidget {
  const _MoodButton({required this.mood, required this.selected, required this.onTap});

  final Mood mood;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: mood.label,
      excludeSemantics: true,
      child: InkWell(
        key: Key('mood_${mood.dbValue}'),
        onTap: onTap,
        borderRadius: AppRadius.mdAll,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          decoration: BoxDecoration(
            color: selected ? mood.color.withValues(alpha: 0.22) : Colors.transparent,
            borderRadius: AppRadius.mdAll,
            border: Border.all(
              color: selected ? mood.color : Colors.transparent,
              width: 1.6,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedScale(
                scale: selected ? 1.15 : 1,
                duration: const Duration(milliseconds: 200),
                child: Text(mood.emoji, style: const TextStyle(fontSize: 34)),
              ),
              AppSpacing.gapXxs,
              Text(
                mood.label,
                style: context.text.labelSmall?.copyWith(
                  color: context.colors.onSurface,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
