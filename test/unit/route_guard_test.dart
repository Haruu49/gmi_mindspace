import 'package:flutter_test/flutter_test.dart';
import 'package:gmi_mindspace/core/routing/app_routes.dart';
import 'package:gmi_mindspace/core/routing/route_guard.dart';
import 'package:gmi_mindspace/features/authentication/presentation/auth_controller.dart';
import 'package:gmi_mindspace/shared/models/user_profile.dart';

UserProfile _user(AppRole role) =>
    UserProfile(id: 'u1', fullName: 'Test User', role: role, isActive: true);

void main() {
  group('role-based routing', () {
    test('signed-out users only reach public screens', () {
      const s = AuthSignedOut();
      expect(redirectFor(s, AppRoutes.welcome), isNull);
      expect(redirectFor(s, AppRoutes.studentLogin), isNull);
      expect(redirectFor(s, AppRoutes.register), isNull);
      expect(redirectFor(s, AppRoutes.studentHome), AppRoutes.welcome);
      expect(redirectFor(s, AppRoutes.counsellorHome), AppRoutes.welcome);
      expect(redirectFor(s, AppRoutes.adminUsers), AppRoutes.welcome);
      expect(redirectFor(s, AppRoutes.splash), AppRoutes.welcome);
    });

    test('counsellor sign-up is public, and signed-in users are sent home from it', () {
      expect(redirectFor(const AuthSignedOut(), AppRoutes.counsellorRegister), isNull);
      expect(redirectFor(AuthSignedIn(_user(AppRole.student)), AppRoutes.counsellorRegister),
          AppRoutes.studentHome);
    });

    test('help and privacy are always reachable', () {
      for (final s in <SessionState>[
        const AuthSignedOut(),
        const AuthLoading(),
        AuthSignedIn(_user(AppRole.student)),
        AuthSignedIn(_user(AppRole.admin)),
      ]) {
        expect(redirectFor(s, AppRoutes.help), isNull);
        expect(redirectFor(s, AppRoutes.privacy), isNull);
      }
    });

    test('loading state waits on the splash screen', () {
      expect(redirectFor(const AuthLoading(), AppRoutes.studentHome), AppRoutes.splash);
      expect(redirectFor(const AuthLoading(), AppRoutes.splash), isNull);
    });

    test('students are sent to the student dashboard and kept out of staff areas', () {
      final s = AuthSignedIn(_user(AppRole.student));
      expect(redirectFor(s, AppRoutes.splash), AppRoutes.studentHome);
      expect(redirectFor(s, AppRoutes.studentLogin), AppRoutes.studentHome);
      expect(redirectFor(s, AppRoutes.journal), isNull);
      expect(redirectFor(s, AppRoutes.counsellorHome), AppRoutes.studentHome);
      expect(redirectFor(s, AppRoutes.counsellorAppointments), AppRoutes.studentHome);
      expect(redirectFor(s, AppRoutes.adminUsers), AppRoutes.studentHome);
    });

    test('counsellors go to the counsellor dashboard and cannot open student journals', () {
      final s = AuthSignedIn(_user(AppRole.counsellor));
      expect(redirectFor(s, AppRoutes.splash), AppRoutes.counsellorHome);
      expect(redirectFor(s, AppRoutes.counsellorReports), isNull);
      expect(redirectFor(s, AppRoutes.journal), AppRoutes.counsellorHome);
      expect(redirectFor(s, AppRoutes.journalDetail('x')), AppRoutes.counsellorHome);
      expect(redirectFor(s, AppRoutes.moodHistory), AppRoutes.counsellorHome);
      expect(redirectFor(s, AppRoutes.adminHome), AppRoutes.counsellorHome);
    });

    test('administrators go to the admin dashboard only', () {
      final s = AuthSignedIn(_user(AppRole.admin));
      expect(redirectFor(s, AppRoutes.welcome), AppRoutes.adminHome);
      expect(redirectFor(s, AppRoutes.adminAudit), isNull);
      expect(redirectFor(s, AppRoutes.journal), AppRoutes.adminHome);
      expect(redirectFor(s, AppRoutes.counsellorAppointments), AppRoutes.adminHome);
    });

    test('a look-alike prefix does not grant access', () {
      final s = AuthSignedIn(_user(AppRole.admin));
      expect(redirectFor(s, '/administrator-hack'), AppRoutes.adminHome);
    });

    test('password recovery forces the reset screen', () {
      expect(redirectFor(const AuthPasswordRecovery(), AppRoutes.studentHome), AppRoutes.resetPassword);
      expect(redirectFor(const AuthPasswordRecovery(), AppRoutes.resetPassword), isNull);
    });
  });
}
