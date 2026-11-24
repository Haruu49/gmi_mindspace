import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

/// A user-presentable error. Repositories throw this so the UI never shows
/// raw stack traces or database internals.
class AppFailure implements Exception {
  const AppFailure(this.message, {this.kind = FailureKind.unknown, this.cause});

  final String message;
  final FailureKind kind;
  final Object? cause;

  /// Converts any thrown object into a friendly [AppFailure].
  factory AppFailure.from(Object error) {
    if (error is AppFailure) return error;

    if (error is SocketException || error is TimeoutException ||
        _looksLikeNetwork(error)) {
      return AppFailure(
        'You seem to be offline. Check your connection and try again.',
        kind: FailureKind.network,
        cause: error,
      );
    }

    if (error is AuthException) return _fromAuth(error);

    if (error is PostgrestException) return _fromPostgrest(error);

    if (error is StorageException) {
      return AppFailure(
        'The file could not be uploaded. Please try a smaller image.',
        kind: FailureKind.server,
        cause: error,
      );
    }

    return AppFailure(
      'Something went wrong. Please try again.',
      cause: error,
    );
  }

  static bool _looksLikeNetwork(Object error) {
    final s = error.toString();
    return s.contains('SocketException') ||
        s.contains('ClientException') ||
        s.contains('Failed host lookup') ||
        s.contains('Connection refused') ||
        s.contains('Network is unreachable');
  }

  static AppFailure _fromAuth(AuthException e) {
    final msg = e.message.toLowerCase();
    if (msg.contains('invalid login credentials')) {
      return AppFailure('Incorrect email or password.',
          kind: FailureKind.auth, cause: e);
    }
    if (msg.contains('email not confirmed')) {
      return AppFailure(
          'Please confirm your email first. Check your inbox for the link.',
          kind: FailureKind.auth,
          cause: e);
    }
    if (msg.contains('already registered') || msg.contains('already exists')) {
      return AppFailure('An account with this email already exists.',
          kind: FailureKind.auth, cause: e);
    }
    if (msg.contains('rate limit') || e.statusCode == '429') {
      return AppFailure('Too many attempts. Please wait a minute and try again.',
          kind: FailureKind.auth, cause: e);
    }
    // Wrong or expired e-mail code (checked before the session-expiry rule,
    // because the message also contains "expired").
    if (msg.contains('token') &&
        !msg.contains('refresh') &&
        (msg.contains('expired') || msg.contains('invalid'))) {
      return AppFailure('That code is not right or has expired. Request a new one.',
          kind: FailureKind.auth, cause: e);
    }
    if (msg.contains('jwt') || msg.contains('expired') ||
        msg.contains('refresh token')) {
      return AppFailure('Your session has expired. Please sign in again.',
          kind: FailureKind.sessionExpired, cause: e);
    }
    if (msg.contains('password')) {
      return AppFailure(e.message, kind: FailureKind.auth, cause: e);
    }
    return AppFailure('We could not sign you in. Please try again.',
        kind: FailureKind.auth, cause: e);
  }

  static AppFailure _fromPostgrest(PostgrestException e) {
    switch (e.code) {
      case '23505': // unique_violation
        return AppFailure(_uniqueMessage(e), kind: FailureKind.conflict, cause: e);
      case '23P01': // exclusion_violation (double booking)
        return AppFailure(
            'That time slot has just been taken. Please choose another.',
            kind: FailureKind.conflict,
            cause: e);
      case '23514': // check_violation
        return AppFailure('Some details are not valid. Please review the form.',
            kind: FailureKind.validation, cause: e);
      case '42501': // insufficient_privilege (RLS)
        return AppFailure('You do not have permission to do that.',
            kind: FailureKind.permission, cause: e);
      case 'PGRST301':
      case 'PGRST303':
        return AppFailure('Your session has expired. Please sign in again.',
            kind: FailureKind.sessionExpired, cause: e);
      case 'PGRST116': // no rows for .single()
        return AppFailure('We could not find that item. It may have been removed.',
            kind: FailureKind.notFound, cause: e);
      case 'P0001': // raise exception from our SQL functions – safe message
        return AppFailure(e.message, kind: FailureKind.validation, cause: e);
    }
    if (e.message.toLowerCase().contains('jwt expired')) {
      return AppFailure('Your session has expired. Please sign in again.',
          kind: FailureKind.sessionExpired, cause: e);
    }
    return AppFailure('The server could not complete that request.',
        kind: FailureKind.server, cause: e);
  }

  static String _uniqueMessage(PostgrestException e) {
    final d = '${e.message} ${e.details ?? ''}';
    if (d.contains('programme_registrations')) {
      return 'You are already registered for this activity.';
    }
    if (d.contains('bookmark')) return 'Already saved to your bookmarks.';
    if (d.contains('feedback')) return 'You have already submitted feedback.';
    if (d.contains('availability')) return 'That slot already exists.';
    return 'This already exists.';
  }

  @override
  String toString() => message;
}

enum FailureKind {
  network,
  auth,
  sessionExpired,
  permission,
  validation,
  conflict,
  notFound,
  server,
  unknown,
}

/// Runs [action] and rethrows any error as an [AppFailure].
Future<T> guard<T>(Future<T> Function() action) async {
  try {
    return await action().timeout(const Duration(seconds: 20));
  } catch (e) {
    throw AppFailure.from(e);
  }
}
