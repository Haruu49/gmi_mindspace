import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/supabase_service.dart';
import '../../../core/utils/failure.dart';
import '../../../shared/models/user_profile.dart';
import '../data/supabase_auth_repository.dart';
import '../domain/auth_repository.dart';

/// App-wide authentication state used by the router and screens.
sealed class SessionState {
  const SessionState();
}

class AuthLoading extends SessionState {
  const AuthLoading();
}

class AuthSignedOut extends SessionState {
  const AuthSignedOut({this.message});

  /// Optional reason, e.g. session expired or account deactivated.
  final String? message;
}

class AuthSignedIn extends SessionState {
  const AuthSignedIn(this.profile);
  final UserProfile profile;
}

/// User opened a password-reset link and must choose a new password.
class AuthPasswordRecovery extends SessionState {
  const AuthPasswordRecovery();
}

/// A session exists but the profile could not be loaded (e.g. offline).
class AuthProfileError extends SessionState {
  const AuthProfileError(this.error);
  final Object error;
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => SupabaseAuthRepository(ref.watch(supabaseClientProvider)),
);

final authControllerProvider =
    NotifierProvider<AuthController, SessionState>(AuthController.new);

/// Convenience: the signed-in profile or null.
final currentProfileProvider = Provider<UserProfile?>((ref) {
  final s = ref.watch(authControllerProvider);
  return s is AuthSignedIn ? s.profile : null;
});

class AuthController extends Notifier<SessionState> {
  StreamSubscription<AuthEvent>? _sub;
  bool _userSignedOut = false;
  bool _signingIn = false;

  AuthRepository get _repo => ref.read(authRepositoryProvider);

  @override
  SessionState build() {
    final repo = ref.watch(authRepositoryProvider);
    _sub = repo.events.listen(_onEvent, onError: (_) {});
    ref.onDispose(() => _sub?.cancel());
    if (repo.currentUserId == null) return const AuthSignedOut();
    scheduleMicrotask(_loadProfile);
    return const AuthLoading();
  }

  void _onEvent(AuthEvent event) {
    switch (event) {
      case AuthEvent.signedIn:
      case AuthEvent.userUpdated:
        if (!_signingIn && state is! AuthPasswordRecovery) _loadProfile();
      case AuthEvent.refreshed:
        if (state is AuthProfileError) _loadProfile();
      case AuthEvent.passwordRecovery:
        state = const AuthPasswordRecovery();
      case AuthEvent.signedOut:
        final wasSignedIn = state is AuthSignedIn;
        final expired = wasSignedIn && !_userSignedOut;
        _userSignedOut = false;
        if (state is AuthSignedOut && (state as AuthSignedOut).message != null) return;
        state = AuthSignedOut(
          message: expired ? 'Your session has ended. Please sign in again.' : null,
        );
    }
  }

  Future<void> _loadProfile() async {
    if (_repo.currentUserId == null) {
      state = const AuthSignedOut();
      return;
    }
    try {
      final profile = await _repo.fetchCurrentProfile();
      if (profile == null) {
        state = const AuthSignedOut();
      } else if (!profile.isActive) {
        await _forceSignOut(
          'This account has been deactivated. Please contact the GMI Counselling Unit.',
        );
      } else {
        state = AuthSignedIn(profile);
      }
    } catch (e) {
      final failure = AppFailure.from(e);
      if (failure.kind == FailureKind.sessionExpired) {
        await _forceSignOut(failure.message);
      } else {
        state = AuthProfileError(failure);
      }
    }
  }

  Future<void> _forceSignOut(String message) async {
    _userSignedOut = true;
    state = AuthSignedOut(message: message);
    try {
      await _repo.signOut();
    } catch (_) {
      // Local session is cleared by supabase_flutter even if offline.
    }
  }

  /// Signs in and loads the approved role from the database.
  ///
  /// [staffPortal] is true on the Counsellor login screen: student accounts
  /// are signed out again with a helpful message.
  Future<void> signIn({
    required String email,
    required String password,
    bool staffPortal = false,
  }) async {
    _signingIn = true;
    try {
      await _repo.signIn(email: email, password: password);
      final profile = await _repo.fetchCurrentProfile();
      if (profile == null) {
        throw const AppFailure('We could not load your account. Please try again.');
      }
      if (!profile.isActive) {
        _userSignedOut = true;
        await _repo.signOut();
        throw const AppFailure(
          'This account has been deactivated. Please contact the GMI Counselling Unit.',
          kind: FailureKind.permission,
        );
      }
      if (staffPortal && profile.role == AppRole.student) {
        _userSignedOut = true;
        await _repo.signOut();
        throw const AppFailure(
          'This is a student account. Please use Student Login instead.',
          kind: FailureKind.permission,
        );
      }
      state = AuthSignedIn(profile);
    } finally {
      _signingIn = false;
    }
  }

  Future<bool> registerStudent({
    required String fullName,
    required String studentId,
    required String email,
    required String password,
  }) {
    return _repo.signUpStudent(
      fullName: fullName,
      studentId: studentId,
      email: email,
      password: password,
    );
  }

  Future<void> signOut() async {
    _userSignedOut = true;
    try {
      await _repo.signOut();
    } finally {
      state = const AuthSignedOut();
    }
  }

  Future<void> sendPasswordReset(String email) => _repo.sendPasswordReset(email);

  /// Completes the password-recovery flow, then continues signed in.
  Future<void> setNewPassword(String password) async {
    await _repo.updatePassword(password);
    await _loadProfile();
  }

  Future<void> retry() async {
    state = const AuthLoading();
    await _loadProfile();
  }

  /// Re-reads the profile (e.g. after editing it).
  Future<void> refreshProfile() => _loadProfile();

  /// Changes the password of the signed-in user.
  Future<void> changePassword(String newPassword) => _repo.updatePassword(newPassword);

  Future<void> updateProfile({
    required String fullName,
    String? studentId,
    String? programmeOfStudy,
  }) async {
    await _repo.updateProfile(
      fullName: fullName,
      studentId: studentId,
      programmeOfStudy: programmeOfStudy,
    );
    await _loadProfile();
  }
}
