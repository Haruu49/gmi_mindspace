import 'package:flutter_test/flutter_test.dart';
import 'package:gmi_mindspace/core/utils/validators.dart';

void main() {
  group('email', () {
    test('rejects empty and malformed addresses', () {
      expect(Validators.email(''), isNotNull);
      expect(Validators.email('   '), isNotNull);
      expect(Validators.email('student'), isNotNull);
      expect(Validators.email('student@'), isNotNull);
      expect(Validators.email('student@gmi'), isNotNull);
      expect(Validators.email('a b@gmi.edu.my'), isNotNull);
    });

    test('accepts valid addresses (trimmed)', () {
      expect(Validators.email('student@gmi.edu.my'), isNull);
      expect(Validators.email('  first.last+tag@example.com  '), isNull);
    });
  });

  group('passwords', () {
    test('login only requires a value', () {
      expect(Validators.loginPassword(''), isNotNull);
      expect(Validators.loginPassword('x'), isNull);
    });

    test('new password needs 8+ chars with a letter and a number', () {
      expect(Validators.newPassword(''), isNotNull);
      expect(Validators.newPassword('abc123'), contains('8'));
      expect(Validators.newPassword('abcdefgh'), contains('number'));
      expect(Validators.newPassword('12345678'), contains('letter'));
      expect(Validators.newPassword('calmMind42'), isNull);
    });

    test('confirm password must match', () {
      final v = Validators.confirmPassword(() => 'calmMind42');
      expect(v(''), isNotNull);
      expect(v('calmMind43'), 'Passwords do not match.');
      expect(v('calmMind42'), isNull);
    });
  });

  group('profile fields', () {
    test('student id is 5–20 letters or digits', () {
      expect(Validators.studentId(''), isNotNull);
      expect(Validators.studentId('GM1'), isNotNull);
      expect(Validators.studentId('GMI-001'), isNotNull);
      expect(Validators.studentId('GMI00123'), isNull);
    });

    test('full name length', () {
      expect(Validators.fullName('A'), isNotNull);
      expect(Validators.fullName('A' * 81), isNotNull);
      expect(Validators.fullName('Aina Sofea'), isNull);
    });

    test('optional text respects max length', () {
      expect(Validators.optionalText('', maxLength: 5), isNull);
      expect(Validators.optionalText('123456', maxLength: 5), isNotNull);
    });

    test('url requires http(s) with host', () {
      expect(Validators.url('', required: true), isNotNull);
      expect(Validators.url(''), isNull);
      expect(Validators.url('ftp://x.com'), isNotNull);
      expect(Validators.url('https://gmi.edu.my/video'), isNull);
    });

    test('positive int bounds', () {
      expect(Validators.positiveInt('0'), isNotNull);
      expect(Validators.positiveInt('abc'), isNotNull);
      expect(Validators.positiveInt('5001', max: 5000), isNotNull);
      expect(Validators.positiveInt('30', max: 5000), isNull);
    });
  });
}
