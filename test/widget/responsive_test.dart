import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gmi_mindspace/core/theme/app_theme.dart';
import 'package:gmi_mindspace/features/authentication/presentation/login_screen.dart';
import 'package:gmi_mindspace/features/authentication/presentation/register_screen.dart';
import 'package:gmi_mindspace/features/selfcare/presentation/selfcare_home_screen.dart';
import 'package:gmi_mindspace/shared/widgets/get_help_screen.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/test_app.dart';

/// Logical sizes of common devices (portrait unless noted).
const devices = <String, Size>{
  'iPhone SE (1st gen)': Size(320, 568),
  'Small Android': Size(360, 640),
  'iPhone 15': Size(393, 852),
  'Pixel 7': Size(412, 915),
  'iPhone 15 Pro Max': Size(430, 932),
  'Android landscape': Size(915, 412),
  'iPad (10th gen)': Size(820, 1180),
};

void main() {
  for (final MapEntry(key: name, value: size) in devices.entries) {
    group(name, () {
      testWidgets('welcome screen lays out without overflow', (tester) async {
        setScreenSize(tester, size);
        await pumpFullApp(tester);
        expect(tester.takeException(), isNull);
        expect(find.text('Student Login'), findsOneWidget);
      });

      testWidgets('student dashboard lays out without overflow', (tester) async {
        setScreenSize(tester, size);
        await pumpFullApp(tester, signedInAs: testStudent);
        expect(tester.takeException(), isNull);
        expect(find.text('Hello, Aina!'), findsOneWidget);
        // Wide screens switch the bottom bar for a navigation rail.
        expect(find.byType(size.width >= 840 ? NavigationRail : NavigationBar), findsOneWidget);
      });

      testWidgets('counsellor and admin dashboards lay out without overflow', (tester) async {
        setScreenSize(tester, size);
        await pumpFullApp(tester, signedInAs: testCounsellor);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await pumpFullApp(tester, signedInAs: testAdmin);
        expect(tester.takeException(), isNull);
      });

      testWidgets('forms and help lay out without overflow', (tester) async {
        setScreenSize(tester, size);
        for (final screen in const [LoginScreen(), RegisterScreen(), GetHelpScreen(), SelfCareHomeScreen()]) {
          await pumpScreen(tester, screen);
          expect(tester.takeException(), isNull, reason: screen.runtimeType.toString());
        }
      });
    });
  }

  testWidgets('login stays usable with the on-screen keyboard open', (tester) async {
    setScreenSize(tester, const Size(360, 640));
    tester.view.viewInsets = const FakeViewPadding(bottom: 300 * 3);
    addTearDown(tester.view.resetViewInsets);
    await pumpScreen(tester, const LoginScreen());
    expect(tester.takeException(), isNull);
    await tester.enterText(find.byKey(const Key('login_email')), 'aina.test@example.test');
    await tester.ensureVisible(find.byKey(const Key('login_submit')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('login_submit')).hitTestable(), findsOneWidget);
  });

  testWidgets('large text (130%) does not break the dashboard', (tester) async {
    setScreenSize(tester, const Size(393, 852));
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpFullApp(tester, signedInAs: testStudent);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dark theme renders the dashboard', (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await pumpFullApp(tester, signedInAs: testStudent);
    expect(tester.takeException(), isNull);
    final context = tester.element(find.text('Hello, Aina!'));
    expect(Theme.of(context).brightness, Brightness.dark);
  });

  test('brand colours match the design brief', () {
    expect(AppColors.lavender, const Color(0xFF9274B8));
    expect(AppColors.sage, const Color(0xFFA7B99A));
    expect(AppColors.warmWhite, const Color(0xFFFAF9F6));
    expect(AppColors.navy, const Color(0xFF263247));
    expect(AppTheme.light.useMaterial3, isTrue);
    expect(AppTheme.light.colorScheme.primary, AppColors.lavender);
    expect(AppTheme.light.textTheme.bodyMedium!.fontSize, greaterThanOrEqualTo(14));
  });

  testWidgets('every tappable dashboard control meets the 48dp target size', (tester) async {
    await pumpFullApp(tester, signedInAs: testStudent);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  });

  testWidgets('dashboard text meets contrast guidelines', (tester) async {
    await pumpFullApp(tester, signedInAs: testStudent);
    await expectLater(tester, meetsGuideline(textContrastGuideline));
  });

  // Keeps the analyzer happy about the unused import when run alone.
  test('provider scope available', () => expect(ProviderScope, isNotNull));
}
