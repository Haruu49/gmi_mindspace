import 'package:flutter_test/flutter_test.dart';
import 'package:gmi_mindspace/core/utils/failure.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('verification code errors', () {
    test('an expired or wrong code is a code problem, not an expired session', () {
      for (final msg in ['Token has expired or is invalid', 'Invalid token']) {
        final f = AppFailure.from(AuthException(msg));
        expect(f.message, 'That code is not right or has expired. Request a new one.');
        expect(f.kind, FailureKind.auth);
      }
    });

    test('other auth errors keep their friendly messages', () {
      expect(AppFailure.from(const AuthException('Invalid login credentials')).message,
          'Incorrect email or password.');
      expect(AppFailure.from(const AuthException('JWT expired')).kind, FailureKind.sessionExpired);
    });
  });
}
