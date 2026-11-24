import '../../features/authentication/presentation/auth_controller.dart';
import '../../shared/models/user_profile.dart';
import 'app_routes.dart';

/// Home route for each approved role.
String homeForRole(AppRole role) => switch (role) {
      AppRole.student => AppRoutes.studentHome,
      AppRole.counsellor => AppRoutes.counsellorHome,
      AppRole.admin => AppRoutes.adminHome,
    };

String _areaForRole(AppRole role) => switch (role) {
      AppRole.student => '/student',
      AppRole.counsellor => '/counsellor',
      AppRole.admin => '/admin',
    };

/// Pure redirect rules (unit-tested). Returns the path to redirect to, or
/// null to allow [path].
///
/// UI routing is a convenience only – the database enforces every
/// permission with Row Level Security regardless of what the app shows.
String? redirectFor(SessionState state, String path) {
  if (AppRoutes.alwaysAllowed.contains(path)) return null;

  switch (state) {
    case AuthLoading():
    case AuthProfileError():
      return path == AppRoutes.splash ? null : AppRoutes.splash;
    case AuthPasswordRecovery():
      return path == AppRoutes.resetPassword ? null : AppRoutes.resetPassword;
    case AuthSignedOut():
      final isPublic = AppRoutes.publicRoutes.contains(path) &&
          path != AppRoutes.splash &&
          path != AppRoutes.resetPassword &&
          path != AppRoutes.configNeeded;
      return isPublic ? null : AppRoutes.welcome;
    case AuthSignedIn(:final profile):
      final area = _areaForRole(profile.role);
      if (path == area || path.startsWith('$area/')) return null;
      return homeForRole(profile.role);
  }
}
