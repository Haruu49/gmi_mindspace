import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';

enum _Phase { idle, inhale, hold, exhale }

/// Visual breathing guide with adjustable inhale / hold / exhale. The student
/// can stop at any moment.
class BreathingExerciseScreen extends StatefulWidget {
  const BreathingExerciseScreen({super.key});

  @override
  State<BreathingExerciseScreen> createState() => _BreathingExerciseScreenState();
}

class _BreathingExerciseScreenState extends State<BreathingExerciseScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _circle = AnimationController(vsync: this, value: 0);
  Timer? _ticker;
  int _inhale = 4;
  int _hold = 4;
  int _exhale = 6;
  _Phase _phase = _Phase.idle;
  int _remaining = 0;
  int _cycles = 0;
  bool _running = false;

  @override
  void dispose() {
    _ticker?.cancel();
    _circle.dispose();
    super.dispose();
  }

  void _start() {
    setState(() {
      _running = true;
      _cycles = 0;
    });
    _runPhase(_Phase.inhale);
  }

  void _stop() {
    _ticker?.cancel();
    _running = false;
    _circle.animateTo(0, duration: const Duration(milliseconds: 600));
    setState(() => _phase = _Phase.idle);
  }

  void _runPhase(_Phase p) {
    if (!_running || !mounted) return;
    if (p == _Phase.hold && _hold == 0) return _runPhase(_Phase.exhale);
    final secs = switch (p) {
      _Phase.inhale => _inhale,
      _Phase.hold => _hold,
      _Phase.exhale => _exhale,
      _Phase.idle => 0,
    };
    setState(() {
      _phase = p;
      _remaining = secs;
    });
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final d = Duration(seconds: reduceMotion ? 0 : secs);
    if (p == _Phase.inhale) _circle.animateTo(1, duration: d, curve: Curves.easeInOut);
    if (p == _Phase.exhale) _circle.animateTo(0, duration: d, curve: Curves.easeInOut);

    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted || !_running) {
        t.cancel();
        return;
      }
      setState(() => _remaining--);
      if (_remaining <= 0) {
        t.cancel();
        if (p == _Phase.exhale) setState(() => _cycles++);
        _runPhase(switch (p) {
          _Phase.inhale => _Phase.hold,
          _Phase.hold => _Phase.exhale,
          _ => _Phase.inhale,
        });
      }
    });
  }

  String get _label => switch (_phase) {
        _Phase.idle => 'Ready when you are',
        _Phase.inhale => 'Breathe in',
        _Phase.hold => 'Hold',
        _Phase.exhale => 'Breathe out',
      };

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final size = (MediaQuery.sizeOf(context).shortestSide * 0.62).clamp(180.0, 320.0);
    return Scaffold(
      appBar: AppBar(title: const Text('Calm breathing')),
      body: PageBody(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            height: size,
            width: size,
            child: AnimatedBuilder(
              animation: _circle,
              builder: (context, _) {
                final scale = 0.45 + 0.55 * _circle.value;
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: scheme.primary.withValues(alpha: 0.08),
                      ),
                    ),
                    Transform.scale(
                      scale: scale,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              scheme.secondary.withValues(alpha: 0.9),
                              scheme.primary.withValues(alpha: 0.85),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Semantics(
                      liveRegion: true,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_label,
                              style: context.text.titleLarge?.copyWith(color: Colors.white),
                              textAlign: TextAlign.center),
                          if (_running)
                            Text('$_remaining',
                                style: context.text.displaySmall?.copyWith(color: Colors.white)),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          AppSpacing.gapMd,
          Text(_cycles == 1 ? '1 breath completed' : '$_cycles breaths completed',
              style: context.text.bodyMedium),
          AppSpacing.gapLg,
          if (!_running) ...[
            _DurationSlider(
              label: 'Breathe in',
              value: _inhale,
              min: 2,
              max: 8,
              onChanged: (v) => setState(() => _inhale = v),
            ),
            _DurationSlider(
              label: 'Hold',
              value: _hold,
              min: 0,
              max: 7,
              onChanged: (v) => setState(() => _hold = v),
            ),
            _DurationSlider(
              label: 'Breathe out',
              value: _exhale,
              min: 2,
              max: 10,
              onChanged: (v) => setState(() => _exhale = v),
            ),
            AppSpacing.gapMd,
            AppButton(
              key: const Key('breathing_start'),
              label: _cycles > 0 ? 'Start again' : 'Start',
              icon: Icons.play_arrow_rounded,
              onPressed: _start,
            ),
            if (_cycles > 0) ...[
              AppSpacing.gapSm,
              AppButton.outline(
                label: 'Finish',
                icon: Icons.check_rounded,
                onPressed: () => context.pushReplacement(
                  Uri(path: AppRoutes.selfCareComplete, queryParameters: {'activity': 'calm-breathing'})
                      .toString(),
                ),
              ),
            ],
          ] else
            AppButton.outline(
              key: const Key('breathing_stop'),
              label: 'Stop',
              icon: Icons.stop_rounded,
              onPressed: _stop,
            ),
          AppSpacing.gapMd,
          Text(
            'Feeling dizzy? Stop and breathe normally.',
            style: context.text.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _DurationSlider extends StatelessWidget {
  const _DurationSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 96, child: Text(label, style: context.text.labelMedium)),
        Expanded(
          child: Slider(
            value: value.toDouble(),
            min: min.toDouble(),
            max: max.toDouble(),
            divisions: max - min,
            label: '$value s',
            semanticFormatterCallback: (v) => '$label ${v.round()} seconds',
            onChanged: (v) => onChanged(v.round()),
          ),
        ),
        SizedBox(width: 36, child: Text('${value}s', style: context.text.titleSmall)),
      ],
    );
  }
}
