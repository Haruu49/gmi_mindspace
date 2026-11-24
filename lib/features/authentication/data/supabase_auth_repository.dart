import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/env.dart';
import '../../../core/utils/failure.dart';
import '../../../shared/models/user_profile.dart';
import '../domain/auth_repository.dart';

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client);

  final SupabaseClient _client;

  @override
  Stream<AuthEvent> get events => _client.auth.onAuthStateChange
      .map((s) => switch (s.event) {
            AuthChangeEvent.signedIn || AuthChangeEvent.initialSession =>
              s.session == null ? AuthEvent.signedOut : AuthEvent.signedIn,
            AuthChangeEvent.tokenRefreshed => AuthEvent.refreshed,
            AuthChangeEvent.passwordRecovery => AuthEvent.passwordRecovery,
            AuthChangeEvent.userUpdated => AuthEvent.userUpdated,
            _ => AuthEvent.signedOut,
          });

  @override
  String? get currentUserId => _client.auth.currentUser?.id;

  @override
  Future<void> signIn({required String email, required String password}) =>
      guard(() => _client.auth.signInWithPassword(
            email: email.trim().toLowerCase(),
            password: password,
          ));

  @override
  Future<bool> signUpStudent({
    required String fullName,
    required String studentId,
    required String email,
    required String password,
  }) {
    return guard(() async {
      final res = await _client.auth.signUp(
        email: email.trim().toLowerCase(),
        password: password,
        emailRedirectTo: Env.authRedirectUrl,
        // Only display data. The role is decided by the database trigger.
        data: {'full_name': fullName.trim(), 'student_id': studentId.trim().toUpperCase()},
      );
      return res.session == null;
    });
  }

  @override
  Future<void> signOut() => guard(() => _client.auth.signOut());

  @override
  Future<void> sendPasswordReset(String email) => guard(
        () => _client.auth.resetPasswordForEmail(
          email.trim().toLowerCase(),
          redirectTo: Env.authRedirectUrl,
        ),
      );

  @override
  Future<void> updatePassword(String newPassword) =>
      guard(() => _client.auth.updateUser(UserAttributes(password: newPassword)));

  @override
  Future<UserProfile?> fetchCurrentProfile() {
    return guard(() async {
      final user = _client.auth.currentUser;
      if (user == null) return null;
      final profile = await _client
          .from('profiles')
          .select('id, full_name, student_id, programme_of_study, avatar_url, is_active')
          .eq('id', user.id)
          .maybeSingle();
      final role = await _client
          .from('user_roles')
          .select('role, can_manage_content')
          .eq('user_id', user.id)
          .maybeSingle();
      if (profile == null || role == null) {
        throw const AppFailure(
          'Your account is not set up yet. Please contact the Counselling Unit.',
          kind: FailureKind.permission,
        );
      }
      return UserProfile.fromRows(profile, role, email: user.email);
    });
  }

  @override
  Future<void> updateProfile({
    required String fullName,
    String? studentId,
    String? programmeOfStudy,
  }) {
    return guard(() async {
      final id = _client.auth.currentUser?.id;
      if (id == null) {
        throw const AppFailure('Please sign in again.', kind: FailureKind.sessionExpired);
      }
      await _client.from('profiles').update({
        'full_name': fullName.trim(),
        'student_id': (studentId?.trim().isEmpty ?? true) ? null : studentId!.trim().toUpperCase(),
        'programme_of_study':
            (programmeOfStudy?.trim().isEmpty ?? true) ? null : programmeOfStudy!.trim(),
      }).eq('id', id);
    });
  }
}
