import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:gmi_mindspace/core/utils/failure.dart';
import 'package:gmi_mindspace/features/counselling/data/counselling_repository.dart';
import 'package:gmi_mindspace/features/counselling/domain/appointment.dart';
import 'package:gmi_mindspace/features/journal/data/journal_repository.dart';
import 'package:gmi_mindspace/features/journal/domain/journal_entry.dart';
import 'package:gmi_mindspace/features/learning_hub/data/learning_repository.dart';
import 'package:gmi_mindspace/features/learning_hub/domain/learning_resource.dart';
import 'package:gmi_mindspace/features/mood_checkin/data/mood_repository.dart';
import 'package:gmi_mindspace/features/mood_checkin/domain/mood.dart';
import 'package:gmi_mindspace/features/wellbeing_activities/data/programme_repository.dart';

/// In-memory repositories. `Fake` throws for anything a test did not expect.
class FakeMoodRepository extends Fake implements MoodRepository {
  final List<MoodEntry> saved = [];

  @override
  Future<List<MoodEntry>> fetchEntries({int days = 90}) async => List.of(saved.reversed);

  @override
  Future<MoodEntry> addEntry({required Mood mood, MoodReason? reason, String? notes}) async {
    final e = MoodEntry(id: 'm${saved.length}', mood: mood, reason: reason, notes: notes, createdAt: DateTime.now());
    saved.add(e);
    return e;
  }
}

class FakeJournalRepository extends Fake implements JournalRepository {
  final Map<String, JournalEntry> entries = {};
  final List<String> deleted = [];

  JournalEntry _toEntry(String id, JournalDraft d) => JournalEntry(
        id: id,
        title: d.title,
        content: d.content,
        entryDate: d.entryDate,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        prompt: d.prompt,
        isGratitude: d.isGratitude,
      );

  @override
  Future<List<JournalEntry>> fetchEntries({String? search, bool gratitudeOnly = false}) async =>
      entries.values.where((e) => !gratitudeOnly || e.isGratitude).toList();

  @override
  Future<JournalEntry> fetchEntry(String id) async =>
      entries[id] ?? (throw const AppFailure('Not found', kind: FailureKind.notFound));

  @override
  Future<JournalEntry> create(JournalDraft draft) async {
    final e = _toEntry('j${entries.length + 1}', draft);
    entries[e.id] = e;
    return e;
  }

  @override
  Future<JournalEntry> update(String id, JournalDraft draft) async => entries[id] = _toEntry(id, draft);

  @override
  Future<void> delete(String id) async {
    entries.remove(id);
    deleted.add(id);
  }
}

class FakeCounsellingRepository extends Fake implements CounsellingRepository {
  final List<(String, AppointmentType, String?)> requests = [];
  bool slotTaken = false;

  @override
  Future<String> requestAppointment({required String availabilityId, required AppointmentType type, String? reason}) async {
    if (slotTaken) {
      throw const AppFailure('That time slot has just been taken. Please choose another.', kind: FailureKind.conflict);
    }
    requests.add((availabilityId, type, reason));
    return 'appt-1';
  }

  @override
  Future<Appointment> fetchAppointment(String id) async => Appointment(
        id: id,
        studentId: 'student-1',
        counsellorId: 'counsellor-1',
        type: requests.isEmpty ? AppointmentType.other : requests.last.$2,
        status: AppointmentStatus.pending,
        startsAt: DateTime.now().add(const Duration(days: 1)),
        endsAt: DateTime.now().add(const Duration(days: 1, hours: 1)),
        createdAt: DateTime.now(),
        counsellorName: 'Carol Test',
      );
}

class FakeProgrammeRepository extends Fake implements ProgrammeRepository {
  final List<String> registeredFor = [];
  final List<(String, int, String?, bool)> feedback = [];

  @override
  Future<void> register(String programmeId) async => registeredFor.add(programmeId);

  @override
  Future<Set<String>> fetchMyFeedbackProgrammeIds() async => feedback.map((f) => f.$1).toSet();

  @override
  Future<void> submitFeedback({required String programmeId, required int rating, String? comment, bool anonymous = false}) async =>
      feedback.add((programmeId, rating, comment, anonymous));
}

class FakeLearningRepository extends Fake implements LearningRepository {
  final List<String> uploadedNames = [];
  final List<String> deletedFiles = [];
  final List<String> signedUrlRequests = [];
  final List<ResourceDraft> created = [];
  final List<(String, ResourceDraft)> updated = [];
  final List<String> deletedResources = [];
  int _uploads = 0;

  @override
  Future<String> uploadPdf(Uint8List bytes, String fileName) async {
    uploadedNames.add(fileName);
    return 'resources/upload-${++_uploads}.pdf';
  }

  @override
  Future<void> deleteFile(String path) async => deletedFiles.add(path);

  @override
  Future<String> signedPdfUrl(String path) async {
    signedUrlRequests.add(path);
    return 'https://storage.example.test/signed/${path.split('/').last}?token=t';
  }

  @override
  Future<void> create(ResourceDraft d) async => created.add(d);

  @override
  Future<void> update(String id, ResourceDraft d) async => updated.add((id, d));

  @override
  Future<void> delete(String id) async => deletedResources.add(id);

  @override
  Future<void> recordView(String resourceId) async {}
}
