import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/supabase_service.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/failure.dart';
import '../domain/journal_entry.dart';

/// CRUD for the signed-in student's journal. RLS restricts every query to
/// the owner, so no other user can read or change these rows.
class JournalRepository {
  JournalRepository(this._db);

  final SupabaseClient _db;
  static const _cols = 'id, title, content, entry_date, prompt, is_gratitude, created_at, updated_at';

  Future<List<JournalEntry>> fetchEntries({String? search, bool gratitudeOnly = false}) =>
      guard(() async {
        var q = _db.from('journal_entries').select(_cols);
        final term = search?.trim() ?? '';
        if (term.isNotEmpty) {
          // Escape PostgREST filter syntax characters in user input.
          final safe = term.replaceAll(RegExp(r'[%,()*\\]'), ' ');
          q = q.or('title.ilike.%$safe%,content.ilike.%$safe%');
        }
        if (gratitudeOnly) q = q.eq('is_gratitude', true);
        final rows = await q
            .order('entry_date', ascending: false)
            .order('created_at', ascending: false)
            .limit(300);
        return rows.map(JournalEntry.fromJson).toList();
      });

  Future<JournalEntry> fetchEntry(String id) => guard(() async {
        final row = await _db.from('journal_entries').select(_cols).eq('id', id).single();
        return JournalEntry.fromJson(row);
      });

  Map<String, dynamic> _toRow(JournalDraft d) => {
        'title': d.title.trim(),
        'content': d.content.trim(),
        'entry_date': AppDates.isoDate(d.entryDate),
        'prompt': d.prompt,
        'is_gratitude': d.isGratitude,
      };

  Future<JournalEntry> create(JournalDraft draft) => guard(() async {
        final row = await _db.from('journal_entries').insert(_toRow(draft)).select(_cols).single();
        return JournalEntry.fromJson(row);
      });

  Future<JournalEntry> update(String id, JournalDraft draft) => guard(() async {
        final row = await _db
            .from('journal_entries')
            .update(_toRow(draft))
            .eq('id', id)
            .select(_cols)
            .single();
        return JournalEntry.fromJson(row);
      });

  Future<void> delete(String id) => guard(() => _db.from('journal_entries').delete().eq('id', id));
}

final journalRepositoryProvider = Provider<JournalRepository>(
  (ref) => JournalRepository(ref.watch(supabaseClientProvider)),
);

/// Search/filter state for the journal list.
class JournalQuery {
  const JournalQuery({this.search = '', this.gratitudeOnly = false});

  final String search;
  final bool gratitudeOnly;

  @override
  bool operator ==(Object other) =>
      other is JournalQuery && other.search == search && other.gratitudeOnly == gratitudeOnly;

  @override
  int get hashCode => Object.hash(search, gratitudeOnly);
}

final journalEntriesProvider =
    FutureProvider.autoDispose.family<List<JournalEntry>, JournalQuery>(
  (ref, q) => ref
      .watch(journalRepositoryProvider)
      .fetchEntries(search: q.search, gratitudeOnly: q.gratitudeOnly),
);

final journalEntryProvider = FutureProvider.autoDispose.family<JournalEntry, String>(
  (ref, id) => ref.watch(journalRepositoryProvider).fetchEntry(id),
);
