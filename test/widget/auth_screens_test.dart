import 'package:flutter_test/flutter_test.dart';
import 'package:gmi_mindspace/features/authentication/presentation/counsellor_register_screen.dart';
import 'package:gmi_mindspace/features/authentication/presentation/login_screen.dart';
import 'package:gmi_mindspace/features/authentication/presentation/password_screens.dart';
import 'package:gmi_mindspace/features/authentication/presentation/register_screen.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/test_app.dart';

void main() {
  group('Login form', () {
    testWidgets('shows validation errors for empty fields', (tester) async {
      await pumpScreen(tester, const LoginScreen());
      await tester.tap(find.byKey(const Key('login_submit')));
      await tester.pumpAndSettle();
      expect(find.text('Please enter your email.'), findsOneWidget);
      expect(find.text('Please enter your password.'), findsOneWidget);
    });

    testWidgets('rejects an invalid email', (tester) async {
      await pumpScreen(tester, const LoginScreen());
      await tester.enterText(find.byKey(const Key('login_email')), 'not-an-email');
      await tester.tap(find.byKey(const Key('login_submit')));
      await tester.pumpAndSettle();
      expect(find.text('Please enter a valid email address.'), findsOneWidget);
    });

    testWidgets('password can be shown and hidden', (tester) async {
      await pumpScreen(tester, const LoginScreen());
      EditableText field() => tester.widget<EditableText>(
            find.descendant(of: find.byKey(const Key('login_password')), matching: find.byType(EditableText)),
          );
      expect(field().obscureText, isTrue);
      await tester.tap(find.byTooltip('Show password'));
      await tester.pump();
      expect(field().obscureText, isFalse);
      await tester.tap(find.byTooltip('Hide password'));
      await tester.pump();
      expect(field().obscureText, isTrue);
    });

    testWidgets('wrong password shows a friendly error and stays on the form', (tester) async {
      await pumpScreen(tester, const LoginScreen());
      await tester.enterText(find.byKey(const Key('login_email')), testStudent.email!);
      await tester.enterText(find.byKey(const Key('login_password')), 'wrongPass1');
      await tester.tap(find.byKey(const Key('login_submit')));
      await tester.pumpAndSettle();
      expect(find.text('Incorrect email or password.'), findsOneWidget);
      expect(find.text('Student Login'), findsOneWidget);
    });

    testWidgets('counsellor portal refuses student accounts', (tester) async {
      await pumpScreen(tester, const LoginScreen(staffPortal: true));
      expect(find.text('Counsellor Login'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('login_email')), testStudent.email!);
      await tester.enterText(find.byKey(const Key('login_password')), testPassword);
      await tester.tap(find.byKey(const Key('login_submit')));
      await tester.pumpAndSettle();
      expect(find.text('This is a student account. Please use Student Login instead.'), findsOneWidget);
    });

    testWidgets('deactivated accounts cannot sign in', (tester) async {
      await pumpScreen(tester, const LoginScreen());
      await tester.enterText(find.byKey(const Key('login_email')), testInactive.email!);
      await tester.enterText(find.byKey(const Key('login_password')), testPassword);
      await tester.tap(find.byKey(const Key('login_submit')));
      await tester.pumpAndSettle();
      expect(find.textContaining('deactivated'), findsOneWidget);
    });
  });

  group('Registration form', () {
    Future<void> fill(WidgetTester tester, {String confirm = testPassword}) async {
      await tester.enterText(find.byKey(const Key('register_name')), 'Aina Sofea');
      await tester.enterText(find.byKey(const Key('register_student_id')), 'GMI00999');
      await tester.enterText(find.byKey(const Key('register_email')), 'aina.new@example.test');
      await tester.enterText(find.byKey(const Key('register_password')), testPassword);
      await tester.enterText(find.byKey(const Key('register_confirm')), confirm);
    }

    Future<void> submit(WidgetTester tester) async {
      await tester.ensureVisible(find.byKey(const Key('register_submit')));
      await tester.tap(find.byKey(const Key('register_submit')));
      await tester.pumpAndSettle();
    }

    testWidgets('validates every field', (tester) async {
      await pumpScreen(tester, const RegisterScreen());
      await submit(tester);
      expect(find.text('Name is required.'), findsOneWidget);
      expect(find.text('Please enter your student ID.'), findsOneWidget);
      expect(find.text('Please enter your email.'), findsOneWidget);
      expect(find.text('Please create a password.'), findsOneWidget);
    });

    testWidgets('detects mismatched passwords', (tester) async {
      await pumpScreen(tester, const RegisterScreen());
      await fill(tester, confirm: 'different1');
      await submit(tester);
      expect(find.text('Passwords do not match.'), findsOneWidget);
    });

    testWidgets('requires privacy acknowledgement, then asks to confirm email', (tester) async {
      await pumpScreen(tester, const RegisterScreen());
      await fill(tester);
      await submit(tester);
      expect(find.textContaining('privacy'), findsWidgets);
      await tester.ensureVisible(find.byKey(const Key('register_privacy')));
      await tester.tap(find.byKey(const Key('register_privacy')));
      await submit(tester);
      expect(find.text('Check your email'), findsOneWidget);
    });
  });

  group('Counsellor sign-up', () {
    Future<FakeAuthRepository> open(WidgetTester tester) async {
      final fake = FakeAuthRepository();
      await pumpScreen(tester, const CounsellorRegisterScreen(), auth: fake);
      return fake;
    }

    Future<void> tapKey(WidgetTester tester, String key) async {
      await tester.ensureVisible(find.byKey(Key(key)));
      await tester.tap(find.byKey(Key(key)));
      await tester.pumpAndSettle();
    }

    Future<void> fillForm(WidgetTester tester, {String email = 'carla.new@gmi.edu.my'}) async {
      await tester.enterText(find.byKey(const Key('counsellor_register_name')), 'Carla New');
      await tester.enterText(find.byKey(const Key('counsellor_register_staff_id')), 'stf001');
      await tester.enterText(find.byKey(const Key('counsellor_register_email')), email);
      await tester.enterText(find.byKey(const Key('counsellor_register_password')), testPassword);
      await tester.enterText(find.byKey(const Key('counsellor_register_confirm')), testPassword);
    }

    testWidgets('validates every field', (tester) async {
      await open(tester);
      await tapKey(tester, 'counsellor_register_submit');
      expect(find.text('Name is required.'), findsOneWidget);
      expect(find.text('Please enter your Staff ID.'), findsOneWidget);
      expect(find.text('Please enter your email.'), findsOneWidget);
      expect(find.text('Please create a password.'), findsOneWidget);
    });

    testWidgets('rejects a student email address', (tester) async {
      final fake = await open(tester);
      await fillForm(tester, email: 'carla.new@student.gmi.edu.my');
      await tapKey(tester, 'counsellor_register_submit');
      expect(find.text('Please use your GMI counsellor email (name@gmi.edu.my).'), findsOneWidget);
      expect(fake.counsellorSignups, isEmpty);
    });

    testWidgets('a valid form asks for the emailed code', (tester) async {
      final fake = await open(tester);
      await fillForm(tester);
      await tapKey(tester, 'counsellor_register_submit');
      expect(fake.counsellorSignups, ['carla.new@gmi.edu.my']);
      expect(find.textContaining('carla.new@gmi.edu.my'), findsWidgets);
      expect(find.byKey(const Key('counsellor_code')), findsOneWidget);
    });

    testWidgets('a wrong code shows a friendly message and stays on the code step', (tester) async {
      await open(tester);
      await fillForm(tester);
      await tapKey(tester, 'counsellor_register_submit');
      await tester.enterText(find.byKey(const Key('counsellor_code')), '000000');
      await tapKey(tester, 'counsellor_code_submit');
      expect(find.text('That code is not right or has expired. Request a new one.'), findsOneWidget);
      expect(find.byKey(const Key('counsellor_code')), findsOneWidget);
    });

    testWidgets('a code that is not six digits is refused before any request', (tester) async {
      final fake = await open(tester);
      await fillForm(tester);
      await tapKey(tester, 'counsellor_register_submit');
      await tester.enterText(find.byKey(const Key('counsellor_code')), '12345');
      await tapKey(tester, 'counsellor_code_submit');
      expect(find.text('The code is 6 digits.'), findsOneWidget);
      expect(fake.signOutCalls, 0);
    });

    testWidgets('the right code (with stray spaces) opens the counsellor dashboard', (tester) async {
      await pumpFullApp(tester);
      await tester.ensureVisible(find.text('Counsellor Login'));
      await tester.tap(find.text('Counsellor Login'));
      await tester.pumpAndSettle();
      await tapKey(tester, 'counsellor_login_signup');
      await fillForm(tester);
      await tapKey(tester, 'counsellor_register_submit');
      await tester.enterText(find.byKey(const Key('counsellor_code')), ' 123456 ');
      await tapKey(tester, 'counsellor_code_submit');
      expect(find.text('Pending requests'), findsOneWidget);
    });

    testWidgets('a taken Staff ID: email verified but no counsellor access, signed out', (tester) async {
      final fake = await open(tester);
      fake.takenStaffIds.add('STF001');
      await fillForm(tester);
      await tapKey(tester, 'counsellor_register_submit');
      await tester.enterText(find.byKey(const Key('counsellor_code')), '123456');
      await tapKey(tester, 'counsellor_code_submit');
      expect(find.textContaining('counsellor access could not be activated'), findsOneWidget);
      expect(fake.signOutCalls, 1);
    });

    testWidgets('resend is blocked for 60 seconds, then sends a new code', (tester) async {
      final fake = await open(tester);
      await fillForm(tester);
      await tapKey(tester, 'counsellor_register_submit');
      await tapKey(tester, 'counsellor_code_resend');
      expect(fake.resent, isEmpty);
      await tester.pump(const Duration(seconds: 61));
      await tapKey(tester, 'counsellor_code_resend');
      expect(fake.resent, ['carla.new@gmi.edu.my']);
    });
  });

  testWidgets('counsellor login offers sign-up instead of "ask an administrator"', (tester) async {
    await pumpScreen(tester, const LoginScreen(staffPortal: true));
    expect(find.byKey(const Key('counsellor_login_signup')), findsOneWidget);
    expect(find.textContaining('created and approved by a GMI administrator'), findsNothing);
  });

  testWidgets('forgot password always shows the same confirmation', (tester) async {
    await pumpScreen(tester, const ForgotPasswordScreen());
    await tester.enterText(find.byKey(const Key('forgot_email')), 'someone@example.test');
    await tester.tap(find.text('Send reset link'));
    await tester.pumpAndSettle();
    expect(find.text('Check your inbox'), findsOneWidget);
  });
}
