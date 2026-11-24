import '../../../shared/models/user_profile.dart';

/// Auth events the app cares about (mapped from Supabase's AuthChangeEvent).
enum AuthEvent { signedIn, signedOut, refreshed, passwordRecovery, userUpdated }

/// Contract for authentication. The UI depends on this, never on Supabase
/// directly, which keeps screens testable with a fake implementation.
abstract interface class AuthRepository {
  /// Emits whenever the session changes (sign in/out, token refresh,
  /// password-recovery deep link, session expiry).
  Stream<AuthEvent> get events;

  /// The signed-in user's id, or null.
  String? get currentUserId;

  Future<void> signIn({required String email, required String password});

  /// Registers a student. The database ALWAYS assigns the `student` role.
  /// Returns true when the user must confirm their e-mail before signing in.
  Future<bool> signUpStudent({
    required String fullName,
    required String studentId,
    required String email,
    required String password,
  });

  Future<void> signOut();

  Future<void> sendPasswordReset(String email);

  Future<void> updatePassword(String newPassword);

  /// Loads the approved role and profile from the database.
  Future<UserProfile?> fetchCurrentProfile();

  Future<void> updateProfile({
    required String fullName,
    String? studentId,
    String? programmeOfStudy,
  });
}
