import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../constants/app_constants.dart';
import '../theme/app_theme.dart';

/// GMI MindSpace mark: two soft leaves (lavender + sage) forming a heart-like
/// sprout inside a rounded square. Drawn in code so it is crisp at any size
/// and needs no image assets.
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.size = 48});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${AppConstants.appName} logo',
      image: true,
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(painter: _LogoPainter(dark: context.isDark)),
      ),
    );
  }
}

class _LogoPainter extends CustomPainter {
  _LogoPainter({required this.dark});

  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final bg = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(s * 0.3),
    );
    canvas.drawRRect(
      bg,
      Paint()..color = dark ? AppColors.darkSurfaceHigh : AppColors.lavenderSoft,
    );

    Path leaf(double angle) {
      final p = Path()
        ..moveTo(0, 0)
        ..cubicTo(-s * 0.22, -s * 0.12, -s * 0.2, -s * 0.38, 0, -s * 0.46)
        ..cubicTo(s * 0.2, -s * 0.38, s * 0.22, -s * 0.12, 0, 0)
        ..close();
      final m = Matrix4.identity()
        ..translateByDouble(s * 0.5, s * 0.74, 0, 1)
        ..rotateZ(angle);
      return p.transform(m.storage);
    }

    canvas.drawPath(leaf(-math.pi / 7), Paint()..color = AppColors.lavender);
    canvas.drawPath(
      leaf(math.pi / 7),
      Paint()..color = AppColors.sage.withValues(alpha: 0.95),
    );
    // small "mind" dot
    canvas.drawCircle(
      Offset(s * 0.5, s * 0.22),
      s * 0.07,
      Paint()..color = dark ? AppColors.darkText : AppColors.navy,
    );
  }

  @override
  bool shouldRepaint(_LogoPainter old) => old.dark != dark;
}

/// Logo + wordmark row.
class BrandHeader extends StatelessWidget {
  const BrandHeader({super.key, this.logoSize = 36, this.showTagline = false});

  final double logoSize;
  final bool showTagline;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        BrandLogo(size: logoSize),
        AppSpacing.gapXs,
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                AppConstants.appName,
                style: context.text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                overflow: TextOverflow.ellipsis,
              ),
              if (showTagline)
                Text(AppConstants.tagline, style: context.text.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}

/// Calm landscape illustration (sun, clouds, rolling hills, sprouts).
/// Decorative only, so it is hidden from screen readers.
class CalmingIllustration extends StatelessWidget {
  const CalmingIllustration({super.key, this.height = 200});

  final double height;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(painter: _LandscapePainter(dark: context.isDark)),
      ),
    );
  }
}

class _LandscapePainter extends CustomPainter {
  _LandscapePainter({required this.dark});

  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final rect = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(AppRadius.xl));
    canvas.save();
    canvas.clipRRect(rect);

    // Sky
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: dark
              ? const [Color(0xFF2B2440), Color(0xFF232A36)]
              : const [AppColors.lavenderSoft, AppColors.warmWhite],
        ).createShader(Offset.zero & size),
    );

    // Sun
    canvas.drawCircle(
      Offset(w * 0.76, h * 0.3),
      h * 0.13,
      Paint()..color = AppColors.warning.withValues(alpha: dark ? 0.55 : 0.75),
    );

    // Clouds
    final cloud = Paint()..color = Colors.white.withValues(alpha: dark ? 0.12 : 0.9);
    void drawCloud(double cx, double cy, double r) {
      canvas.drawCircle(Offset(cx, cy), r, cloud);
      canvas.drawCircle(Offset(cx + r * 0.9, cy + r * 0.2), r * 0.75, cloud);
      canvas.drawCircle(Offset(cx - r * 0.9, cy + r * 0.25), r * 0.65, cloud);
    }

    drawCloud(w * 0.24, h * 0.24, h * 0.07);
    drawCloud(w * 0.55, h * 0.14, h * 0.05);

    // Hills (back to front)
    void hill(double baseY, double peakX, double peakY, Color color) {
      final p = Path()
        ..moveTo(0, baseY)
        ..quadraticBezierTo(peakX, peakY, w, baseY + h * 0.05)
        ..lineTo(w, h)
        ..lineTo(0, h)
        ..close();
      canvas.drawPath(p, Paint()..color = color);
    }

    hill(h * 0.66, w * 0.3, h * 0.38,
        dark ? const Color(0xFF3A3354) : AppColors.lavender.withValues(alpha: 0.35));
    hill(h * 0.78, w * 0.7, h * 0.5,
        dark ? const Color(0xFF34402F) : AppColors.sage.withValues(alpha: 0.75));
    hill(h * 0.9, w * 0.35, h * 0.72,
        dark ? const Color(0xFF2B3527) : AppColors.sageDeep.withValues(alpha: 0.55));

    // Sprouts
    final stem = Paint()
      ..color = dark ? AppColors.sageLight : AppColors.sageDeep
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (final x in [0.14, 0.2, 0.86]) {
      final bx = w * x;
      final by = h * 0.95;
      canvas.drawLine(Offset(bx, by), Offset(bx, by - h * 0.1), stem);
      canvas.drawOval(
        Rect.fromCenter(center: Offset(bx - 5, by - h * 0.09), width: 10, height: 6),
        Paint()..color = stem.color,
      );
      canvas.drawOval(
        Rect.fromCenter(center: Offset(bx + 5, by - h * 0.11), width: 10, height: 6),
        Paint()..color = stem.color,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_LandscapePainter old) => old.dark != dark;
}
