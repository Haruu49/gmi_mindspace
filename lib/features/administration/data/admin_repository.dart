import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/supabase_service.dart';
import '../../../core/utils/failure.dart';
import '../../../shared/models/user_profile.dart';

/// Account row returned by `admin_list_users` (no private content).
class ManagedUser {
  const ManagedUser({
    required this.id,
    required this.fullName,
    required this.role,
    required this.isActive,
    required this.canManageContent,
    required this.createdAt,
    this.email,
    this.studentId,
    this.lastSignInAt,
  });

  final String id;
  final String fullName;
  final AppRole role;
  final bool isActive;
  final bool canManageContent;
  final DateTime createdAt;
  final String? email;
  final String? studentId;
  final DateTime? lastSignInAt;

  factory ManagedUser.fromJson(Map<String, dynamic> j) => ManagedUser(
        id: j['id'] as String,
        fullName: j['full_name'] as String,
        role: AppRole.tryParse(j['role'] as String?) ?? AppRole.student,
        isActive: j['is_active'] as bool,
        canManageContent: j['can_manage_content'] as bool? ?? false,
        createdAt: DateTime.parse(j['created_at'] as String),
        email: j['email'] as String?,
        studentId: j['student_id'] as String?,
        lastSignInAt: j['last_sign_in_at'] == null ? null : DateTime.parse(j['last_sign_in_at'] as String),
      );
}

class AuditEntry {
  const AuditEntry({
    required this.id,
    required this.action,
    required this.createdAt,
    required this.details,
    this.actorId,
    this.targetUserId,
  });

  final String id;
  final String action;
  final DateTime createdAt;
  final Map<String, dynamic> details;
  final String? actorId;
  final String? targetUserId;

  factory AuditEntry.fromJson(Map<String, dynamic> j) => AuditEntry(
        id: j['id'] as String,
        action: j['action'] as String,
        createdAt: DateTime.parse(j['created_at'] as String),
        details: (j['details'] as Map?)?.cast<String, dynamic>() ?? const {},
        actorId: j['actor_id'] as String?,
        targetUserId: j['target_user_id'] as String?,
      );
}

class AppSetting {
  const AppSetting({required this.key, required this.value, this.description});

  final String key;
  final Object? value;
  final String? description;

  factory AppSetting.fromJson(Map<String, dynamic> j) =>
      AppSetting(key: j['key'] as String, value: j['value'], description: j['description'] as String?);

  String get display => value is String ? value as String : jsonEncode(value);
}

/// All admin writes go through audited SECURITY DEFINER functions that
/// refuse self-changes and keep at least one administrator.
class AdminRepository {
  AdminRepository(this._db);

  final SupabaseClient _db;

  Future<List<ManagedUser>> listUsers({String? search, AppRole? role}) => guard(() async {
        final rows = await _db.rpc('admin_list_users', params: {
          'p_search': (search?.trim().isEmpty ?? true) ? null : search!.trim(),
          'p_role': role?.name,
        }) as List<dynamic>;
        return rows.cast<Map<String, dynamic>>().map(ManagedUser.fromJson).toList();
      });

  Future<void> setRole(String userId, AppRole role) =>
      guard(() => _db.rpc('admin_set_user_role', params: {'p_user': userId, 'p_role': role.name}));

  Future<void> setActive(String userId, bool active) =>
      guard(() => _db.rpc('admin_set_account_active', params: {'p_user': userId, 'p_active': active}));

  Future<void> setContentPermission(String userId, bool allowed) =>
      guard(() => _db.rpc('admin_set_content_permission', params: {'p_user': userId, 'p_allowed': allowed}));

  Future<Map<String, dynamic>> systemHealth() => guard(() async {
        final res = await _db.rpc('admin_system_health');
        return (res as Map).cast<String, dynamic>();
      });

  Future<List<AuditEntry>> auditLog() => guard(() async {
        final rows = await _db
            .from('audit_logs')
            .select('id, actor_id, action, target_user_id, details, created_at')
            .order('created_at', ascending: false)
            .limit(200);
        return rows.map(AuditEntry.fromJson).toList();
      });

  Future<List<AppSetting>> settings() => guard(() async {
        final rows = await _db.from('app_settings').select('key, value, description').order('key');
        return rows.map(AppSetting.fromJson).toList();
      });

  Future<void> updateSetting(String key, Object value) =>
      guard(() => _db.rpc('admin_update_setting', params: {'p_key': key, 'p_value': value}));
}

final adminRepositoryProvider = Provider<AdminRepository>(
  (ref) => AdminRepository(ref.watch(supabaseClientProvider)),
);

class UserQuery {
  const UserQuery({this.search = '', this.role});

  final String search;
  final AppRole? role;

  @override
  bool operator ==(Object other) => other is UserQuery && other.search == search && other.role == role;

  @override
  int get hashCode => Object.hash(search, role);
}

final managedUsersProvider = FutureProvider.autoDispose.family<List<ManagedUser>, UserQuery>(
  (ref, q) => ref.watch(adminRepositoryProvider).listUsers(search: q.search, role: q.role),
);

final systemHealthProvider = FutureProvider.autoDispose<Map<String, dynamic>>(
  (ref) => ref.watch(adminRepositoryProvider).systemHealth(),
);

final auditLogProvider = FutureProvider.autoDispose<List<AuditEntry>>(
  (ref) => ref.watch(adminRepositoryProvider).auditLog(),
);

final appSettingsProvider = FutureProvider.autoDispose<List<AppSetting>>(
  (ref) => ref.watch(adminRepositoryProvider).settings(),
);
