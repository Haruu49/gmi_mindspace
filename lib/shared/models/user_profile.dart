/// Authorisation role, read from the `user_roles` table (never from
/// user-editable metadata).
enum AppRole {
  student,
  counsellor,
  admin;

  static AppRole? tryParse(String? value) {
    for (final r in AppRole.values) {
      if (r.name == value) return r;
    }
    return null;
  }

  String get label => switch (this) {
        AppRole.student => 'Student',
        AppRole.counsellor => 'Counsellor',
        AppRole.admin => 'Administrator',
      };
}

/// The signed-in user's basic profile plus approved role.
class UserProfile {
  const UserProfile({
    required this.id,
    required this.fullName,
    required this.role,
    required this.isActive,
    this.email,
    this.studentId,
    this.programmeOfStudy,
    this.avatarUrl,
    this.canManageContent = false,
  });

  final String id;
  final String fullName;
  final AppRole role;
  final bool isActive;
  final String? email;
  final String? studentId;
  final String? programmeOfStudy;
  final String? avatarUrl;
  final bool canManageContent;

  String get firstName {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    return parts.isEmpty ? fullName : parts.first;
  }

  String get initials {
    final parts = fullName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    return parts.take(2).map((p) => p[0].toUpperCase()).join();
  }

  /// Builds from a `profiles` row joined with `user_roles`.
  factory UserProfile.fromRows(
    Map<String, dynamic> profile,
    Map<String, dynamic> role, {
    String? email,
  }) {
    return UserProfile(
      id: profile['id'] as String,
      fullName: (profile['full_name'] as String?)?.trim().isNotEmpty == true
          ? profile['full_name'] as String
          : 'Friend',
      role: AppRole.tryParse(role['role'] as String?) ?? AppRole.student,
      isActive: profile['is_active'] as bool? ?? false,
      email: email,
      studentId: profile['student_id'] as String?,
      programmeOfStudy: profile['programme_of_study'] as String?,
      avatarUrl: profile['avatar_url'] as String?,
      canManageContent: role['can_manage_content'] as bool? ?? false,
    );
  }

  UserProfile copyWith({
    String? fullName,
    String? studentId,
    String? programmeOfStudy,
  }) {
    return UserProfile(
      id: id,
      fullName: fullName ?? this.fullName,
      role: role,
      isActive: isActive,
      email: email,
      studentId: studentId ?? this.studentId,
      programmeOfStudy: programmeOfStudy ?? this.programmeOfStudy,
      avatarUrl: avatarUrl,
      canManageContent: canManageContent,
    );
  }
}
