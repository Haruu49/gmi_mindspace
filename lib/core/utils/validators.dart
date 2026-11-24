import '../constants/app_constants.dart';

/// Pure form validators. Each returns `null` when valid, otherwise a short,
/// friendly message. Kept framework-free so they are trivial to unit test.
abstract final class Validators {
  static final RegExp _email = RegExp(
    r"^[A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]+@[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)+$",
  );

  static String? email(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Please enter your email.';
    if (v.length > 254 || !_email.hasMatch(v)) {
      return 'Please enter a valid email address.';
    }
    return null;
  }

  /// Student e-mail: valid address, and (optionally) an approved domain.
  static String? studentEmail(String? value) {
    final base = email(value);
    if (base != null) return base;
    final domains = AppConstants.studentEmailDomains;
    if (domains.isEmpty) return null;
    final domain = value!.trim().split('@').last.toLowerCase();
    if (!domains.contains(domain)) {
      return 'Please use your GMI student email.';
    }
    return null;
  }

  /// Login only needs a non-empty password (never reveal the policy rules).
  static String? loginPassword(String? value) {
    if (value == null || value.isEmpty) return 'Please enter your password.';
    return null;
  }

  /// Registration / reset password strength rules.
  static String? newPassword(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Please create a password.';
    if (v.length < AppConstants.minPasswordLength) {
      return 'Use at least ${AppConstants.minPasswordLength} characters.';
    }
    if (!RegExp('[A-Za-z]').hasMatch(v) || !RegExp('[0-9]').hasMatch(v)) {
      return 'Include at least one letter and one number.';
    }
    return null;
  }

  static String? Function(String?) confirmPassword(String Function() other) {
    return (value) {
      if (value == null || value.isEmpty) return 'Please confirm your password.';
      if (value != other()) return 'Passwords do not match.';
      return null;
    };
  }

  static String? requiredText(
    String? value, {
    String field = 'This field',
    int? maxLength,
    int minLength = 1,
  }) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return '$field is required.';
    if (v.length < minLength) {
      return '$field must be at least $minLength characters.';
    }
    if (maxLength != null && v.length > maxLength) {
      return '$field must be $maxLength characters or fewer.';
    }
    return null;
  }

  static String? optionalText(String? value, {required int maxLength}) {
    final v = value?.trim() ?? '';
    if (v.length > maxLength) return 'Please keep this under $maxLength characters.';
    return null;
  }

  static String? fullName(String? value) => requiredText(
        value,
        field: 'Name',
        minLength: 2,
        maxLength: AppConstants.maxNameLength,
      );

  /// GMI student ID: letters/digits, 5–20 chars.
  static String? studentId(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Please enter your student ID.';
    if (!RegExp(r'^[A-Za-z0-9]{5,20}$').hasMatch(v)) {
      return 'Student ID should be 5–20 letters or numbers.';
    }
    return null;
  }

  static String? url(String? value, {bool required = false}) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return required ? 'Please enter a link.' : null;
    final uri = Uri.tryParse(v);
    if (uri == null || !(uri.isScheme('https') || uri.isScheme('http')) ||
        uri.host.isEmpty) {
      return 'Please enter a valid link starting with https://';
    }
    return null;
  }

  static String? positiveInt(String? value, {String field = 'Value', int max = 100000}) {
    final v = int.tryParse(value?.trim() ?? '');
    if (v == null || v <= 0) return '$field must be a whole number above 0.';
    if (v > max) return '$field must be $max or less.';
    return null;
  }
}
