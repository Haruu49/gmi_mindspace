import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/supabase_service.dart';
import '../../../core/utils/failure.dart';
import '../domain/learning_resource.dart';

class LearningRepository {
  LearningRepository(this._db);

  final SupabaseClient _db;
  static const bucket = 'learning-media';
  static const _cols = 'id, title, description, category, format, content, image_url, media_url, '
      'read_minutes, published, published_at, created_at';
  static const _listCols = 'id, title, description, category, format, image_url, media_url, '
      'read_minutes, published, published_at, created_at';

  String get _uid {
    final id = _db.auth.currentUser?.id;
    if (id == null) throw const AppFailure('Please sign in again.', kind: FailureKind.sessionExpired);
    return id;
  }

  // ---------------- Students ----------------

  Future<List<LearningResource>> fetchPublished({ResourceCategory? category, String? search}) =>
      guard(() async {
        var q = _db.from('resources').select(_listCols).eq('published', true);
        if (category != null) q = q.eq('category', category.dbValue);
        final term = search?.trim() ?? '';
        if (term.isNotEmpty) {
          final safe = term.replaceAll(RegExp(r'[%,()*\\]'), ' ');
          q = q.or('title.ilike.%$safe%,description.ilike.%$safe%,content.ilike.%$safe%');
        }
        final rows = await q.order('published_at', ascending: false).limit(200);
        return rows.map(LearningResource.fromJson).toList();
      });

  Future<LearningResource> fetchById(String id) => guard(() async {
        final row = await _db.from('resources').select(_cols).eq('id', id).single();
        return LearningResource.fromJson(row);
      });

  Future<Set<String>> fetchBookmarkIds() => guard(() async {
        final rows = await _db.from('resource_bookmarks').select('resource_id');
        return {for (final r in rows) r['resource_id'] as String};
      });

  Future<List<LearningResource>> fetchBookmarked() => guard(() async {
        final rows = await _db
            .from('resource_bookmarks')
            .select('created_at, resources($_listCols)')
            .order('created_at', ascending: false);
        return [
          for (final r in rows)
            if (r['resources'] != null) LearningResource.fromJson(r['resources'] as Map<String, dynamic>),
        ];
      });

  Future<void> addBookmark(String resourceId) =>
      guard(() => _db.from('resource_bookmarks').insert({'resource_id': resourceId}));

  Future<void> removeBookmark(String resourceId) => guard(
        () => _db.from('resource_bookmarks').delete().eq('resource_id', resourceId).eq('user_id', _uid),
      );

  /// Records (or refreshes) "recently viewed". Failures are ignored – this
  /// must never block reading.
  Future<void> recordView(String resourceId) async {
    try {
      await _db.from('resource_views').upsert(
        {'resource_id': resourceId, 'viewed_at': DateTime.now().toUtc().toIso8601String()},
        onConflict: 'user_id,resource_id',
      );
    } catch (_) {}
  }

  Future<List<LearningResource>> fetchRecent() => guard(() async {
        final rows = await _db
            .from('resource_views')
            .select('viewed_at, resources($_listCols)')
            .order('viewed_at', ascending: false)
            .limit(10);
        return [
          for (final r in rows)
            if (r['resources'] != null) LearningResource.fromJson(r['resources'] as Map<String, dynamic>),
        ];
      });

  // ---------------- Content managers ----------------

  Future<List<LearningResource>> fetchAllForManagement() => guard(() async {
        final rows = await _db.from('resources').select(_listCols).order('created_at', ascending: false);
        return rows.map(LearningResource.fromJson).toList();
      });

  Future<void> create(ResourceDraft d) => guard(() => _db.from('resources').insert(d.toRow()));

  Future<void> update(String id, ResourceDraft d) =>
      guard(() => _db.from('resources').update(d.toRow()).eq('id', id));

  Future<void> setPublished(String id, bool published) =>
      guard(() => _db.from('resources').update({'published': published}).eq('id', id));

  Future<void> delete(String id) => guard(() => _db.from('resources').delete().eq('id', id));

  /// Uploads an approved image and returns its public URL.
  Future<String> uploadImage(Uint8List bytes, String extension) => guard(() async {
        final ext = extension.toLowerCase().replaceAll('.', '');
        const allowed = {'jpg': 'image/jpeg', 'jpeg': 'image/jpeg', 'png': 'image/png', 'webp': 'image/webp'};
        final type = allowed[ext];
        if (type == null) throw const AppFailure('Please choose a JPG, PNG or WebP image.');
        if (bytes.lengthInBytes > 5 * 1024 * 1024) {
          throw const AppFailure('Images must be 5 MB or smaller.');
        }
        final name = '${DateTime.now().millisecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}.$ext';
        final path = 'resources/$name';
        await _db.storage.from(bucket).uploadBinary(path, bytes, fileOptions: FileOptions(contentType: type));
        return _db.storage.from(bucket).getPublicUrl(path);
      });
}

final learningRepositoryProvider = Provider<LearningRepository>(
  (ref) => LearningRepository(ref.watch(supabaseClientProvider)),
);

class ResourceQuery {
  const ResourceQuery({this.category, this.search = ''});

  final ResourceCategory? category;
  final String search;

  @override
  bool operator ==(Object other) =>
      other is ResourceQuery && other.category == category && other.search == search;

  @override
  int get hashCode => Object.hash(category, search);
}

final publishedResourcesProvider =
    FutureProvider.autoDispose.family<List<LearningResource>, ResourceQuery>(
  (ref, q) => ref.watch(learningRepositoryProvider).fetchPublished(category: q.category, search: q.search),
);

final resourceDetailProvider = FutureProvider.autoDispose.family<LearningResource, String>(
  (ref, id) => ref.watch(learningRepositoryProvider).fetchById(id),
);

final bookmarkIdsProvider = FutureProvider.autoDispose<Set<String>>(
  (ref) => ref.watch(learningRepositoryProvider).fetchBookmarkIds(),
);

final bookmarkedResourcesProvider = FutureProvider.autoDispose<List<LearningResource>>(
  (ref) => ref.watch(learningRepositoryProvider).fetchBookmarked(),
);

final recentResourcesProvider = FutureProvider.autoDispose<List<LearningResource>>(
  (ref) => ref.watch(learningRepositoryProvider).fetchRecent(),
);

final managedResourcesProvider = FutureProvider.autoDispose<List<LearningResource>>(
  (ref) => ref.watch(learningRepositoryProvider).fetchAllForManagement(),
);
