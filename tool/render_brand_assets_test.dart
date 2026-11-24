// Renders the code-drawn BrandLogo into PNG source images for the app icon
// and splash screen. Not part of the normal test suite (lives in tool/).
//
//   flutter test tool/render_brand_assets_test.dart
//   dart run flutter_launcher_icons && dart run flutter_native_splash:create
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gmi_mindspace/core/theme/app_theme.dart';
import 'package:gmi_mindspace/core/widgets/brand.dart';
import 'package:material_ui/material_ui.dart';

Future<void> _render(
  WidgetTester tester, {
  required String path,
  required double canvas,
  required double logoFraction,
  Color? background,
}) async {
  tester.view.physicalSize = Size(canvas, canvas);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final key = GlobalKey();
  await tester.pumpWidget(MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    home: RepaintBoundary(
      key: key,
      child: Container(
        width: canvas,
        height: canvas,
        color: background ?? const Color(0x00000000),
        alignment: Alignment.center,
        child: BrandLogo(size: canvas * logoFraction),
      ),
    ),
  ));
  await tester.pumpAndSettle();
  final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await File(path).writeAsBytes(bytes!.buffer.asUint8List());
  });
}

void main() {
  testWidgets('render icon and splash sources', (tester) async {
    // iOS / legacy icon: logo filling a solid square (iOS rounds the corners).
    await _render(tester,
        path: 'assets/branding/icon.png', canvas: 1024, logoFraction: 1, background: AppColors.lavenderSoft);
    // Android adaptive foreground: full logo on transparent; the generator insets
    // it by 16 %, which keeps it inside the adaptive-icon safe zone.
    await _render(tester, path: 'assets/branding/icon_foreground.png', canvas: 1024, logoFraction: 1);
    // Splash: logo on transparent; the splash colour comes from the config.
    await _render(tester, path: 'assets/branding/splash.png', canvas: 768, logoFraction: 0.5);
    for (final f in ['icon.png', 'icon_foreground.png', 'splash.png']) {
      expect(File('assets/branding/$f').lengthSync(), greaterThan(1000));
    }
  });
}
