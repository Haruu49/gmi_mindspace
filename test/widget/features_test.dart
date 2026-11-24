import 'package:flutter_test/flutter_test.dart';
import 'package:gmi_mindspace/features/counselling/data/counselling_repository.dart';
import 'package:gmi_mindspace/features/counselling/domain/appointment.dart';
import 'package:gmi_mindspace/features/counselling/presentation/book_appointment_screen.dart';
import 'package:gmi_mindspace/features/journal/data/journal_repository.dart';
import 'package:gmi_mindspace/features/journal/domain/journal_entry.dart';
import 'package:gmi_mindspace/features/journal/presentation/journal_detail_screen.dart';
import 'package:gmi_mindspace/features/journal/presentation/journal_editor_screen.dart';
import 'package:gmi_mindspace/features/mood_checkin/domain/mood.dart';
import 'package:gmi_mindspace/features/mood_checkin/data/mood_repository.dart';
import 'package:gmi_mindspace/features/mood_checkin/presentation/mood_reflection_screen.dart';
import 'package:gmi_mindspace/features/selfcare/presentation/breathing_exercise_screen.dart';
import 'package:gmi_mindspace/features/wellbeing_activities/data/programme_repository.dart';
import 'package:gmi_mindspace/features/wellbeing_activities/domain/programme.dart';
import 'package:gmi_mindspace/features/wellbeing_activities/presentation/feedback_screen.dart';
import 'package:gmi_mindspace/features/wellbeing_activities/presentation/programme_detail_screen.dart';
import 'package:gmi_mindspace/shared/widgets/month_calendar.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/fake_repos.dart';
import '../helpers/test_app.dart';

void main() {
  testWidgets('mood check-in saves mood, reason and private note', (tester) async {
    final repo = FakeMoodRepository();
    await pumpScreen(
      tester,
      const MoodReflectionScreen(initialMood: Mood.stressed),
      overrides: [moodRepositoryProvider.overrideWithValue(repo)],
    );
    await tester.tap(find.text('Academic pressure'));
    await tester.enterText(find.byKey(const Key('mood_notes')), 'Exams next week');
    await tester.ensureVisible(find.byKey(const Key('mood_save')));
    await tester.tap(find.byKey(const Key('mood_save')));
    await tester.pumpAndSettle();
    expect(repo.saved.single.mood, Mood.stressed);
    expect(repo.saved.single.reason, MoodReason.academic);
    expect(repo.saved.single.notes, 'Exams next week');
    expect(find.text('Check-in saved'), findsOneWidget);
    expect(find.text('Try a breathing exercise'), findsOneWidget, reason: 'support offered for stressed mood');
  });

  testWidgets('journal entry requires a title and content, then saves', (tester) async {
    final repo = FakeJournalRepository();
    await pumpScreen(tester, const JournalEditorScreen(), overrides: [journalRepositoryProvider.overrideWithValue(repo)]);
    await tester.tap(find.byKey(const Key('journal_save')));
    await tester.pumpAndSettle();
    expect(find.text('Title is required.'), findsOneWidget);
    expect(find.text('Entry is required.'), findsOneWidget);
    expect(repo.entries, isEmpty);

    await tester.enterText(find.byKey(const Key('journal_title')), 'A calmer day');
    await tester.enterText(find.byKey(const Key('journal_content')), 'I went for a walk after class.');
    await tester.tap(find.byKey(const Key('journal_save')));
    await tester.pumpAndSettle();
    expect(repo.entries.values.single.title, 'A calmer day');
  });

  testWidgets('journal deletion asks for confirmation first', (tester) async {
    final repo = FakeJournalRepository();
    await repo.create(JournalDraft(title: 'Private', content: 'Only for me', entryDate: DateTime(2026, 11, 20)));
    await pumpScreen(
      tester,
      const JournalDetailScreen(entryId: 'j1'),
      overrides: [journalRepositoryProvider.overrideWithValue(repo)],
    );
    await tester.tap(find.byKey(const Key('journal_delete')));
    await tester.pumpAndSettle();
    expect(find.text('Delete this entry?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(repo.deleted, isEmpty);

    await tester.tap(find.byKey(const Key('journal_delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(repo.deleted, ['j1']);
  });

  group('appointment request', () {
    final slotDay = DateUtils.dateOnly(DateTime.now()).add(const Duration(days: 2));
    final slot = OpenSlot(
      availabilityId: 'slot-1',
      counsellorId: 'counsellor-1',
      counsellorName: 'Carol Test',
      startsAt: slotDay.add(const Duration(hours: 10)),
      endsAt: slotDay.add(const Duration(hours: 11)),
      location: 'Room A',
    );

    Future<void> chooseSlot(WidgetTester tester) async {
      await tester.tap(find.text(AppointmentType.academic.label));
      await tester.pumpAndSettle();
      if (slotDay.month != DateTime.now().month) {
        await tester.tap(find.byTooltip('Next month'));
        await tester.pumpAndSettle();
      }
      final day = find.descendant(of: find.byType(MonthCalendar), matching: find.text('${slotDay.day}'));
      await tester.ensureVisible(day);
      await tester.tap(day);
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Carol Test'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('booking_submit')));
      await tester.tap(find.byKey(const Key('booking_submit')));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.widgetWithText(FilledButton, 'Send request')));
      await tester.pumpAndSettle();
    }

    testWidgets('student picks type, date and time and submits', (tester) async {
      final repo = FakeCounsellingRepository();
      await pumpScreen(tester, const BookAppointmentScreen(), overrides: [
        counsellingRepositoryProvider.overrideWithValue(repo),
        openSlotsProvider.overrideWith((ref) async => [slot]),
      ]);
      await chooseSlot(tester);
      expect(repo.requests.single.$1, 'slot-1');
      expect(repo.requests.single.$2, AppointmentType.academic);
    });

    testWidgets('a slot taken by someone else shows a clear message', (tester) async {
      final repo = FakeCounsellingRepository()..slotTaken = true;
      await pumpScreen(tester, const BookAppointmentScreen(), overrides: [
        counsellingRepositoryProvider.overrideWithValue(repo),
        openSlotsProvider.overrideWith((ref) async => [slot]),
      ]);
      await chooseSlot(tester);
      expect(find.textContaining('just been taken'), findsOneWidget);
      expect(repo.requests, isEmpty);
    });
  });

  group('well-being activities', () {
    final programme = Programme(
      id: 'p1',
      title: 'Mindfulness Workshop',
      description: 'A calm one-hour mindfulness session.',
      category: 'Workshop',
      mode: ProgrammeMode.physical,
      location: 'Hall B',
      startsAt: DateTime.now().add(const Duration(days: 3)),
      endsAt: DateTime.now().add(const Duration(days: 3, hours: 1)),
      status: ProgrammeStatus.published,
      capacity: 30,
    );

    testWidgets('student registers and sees a confirmation', (tester) async {
      final repo = FakeProgrammeRepository();
      await pumpScreen(tester, const ProgrammeDetailScreen(programmeId: 'p1'), overrides: [
        programmeRepositoryProvider.overrideWithValue(repo),
        programmeDetailProvider.overrideWith((ref, id) async => programme),
      ]);
      await tester.ensureVisible(find.byKey(const Key('programme_register')));
      await tester.tap(find.byKey(const Key('programme_register')));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.widgetWithText(FilledButton, 'Register')));
      await tester.pumpAndSettle();
      expect(repo.registeredFor, ['p1']);
      expect(find.text('You are registered!'), findsOneWidget);
    });

    testWidgets('feedback needs a rating and can be anonymous', (tester) async {
      final repo = FakeProgrammeRepository();
      await pumpScreen(tester, const ProgrammeFeedbackScreen(programmeId: 'p1'), overrides: [
        programmeRepositoryProvider.overrideWithValue(repo),
        programmeDetailProvider.overrideWith((ref, id) async => programme),
      ]);
      await tester.ensureVisible(find.text('Submit feedback'));
      await tester.tap(find.text('Submit feedback'));
      await tester.pumpAndSettle();
      expect(find.text('Please choose a rating.'), findsOneWidget);
      expect(repo.feedback, isEmpty);

      await tester.tap(find.byKey(const Key('rating_4')));
      await tester.ensureVisible(find.text('Submit anonymously'));
      await tester.tap(find.text('Submit anonymously'));
      await tester.ensureVisible(find.text('Submit feedback'));
      await tester.tap(find.text('Submit feedback'));
      await tester.pumpAndSettle();
      expect(repo.feedback.single.$2, 4);
      expect(repo.feedback.single.$4, isTrue);
    });
  });

  testWidgets('breathing exercise starts and can be stopped any time', (tester) async {
    await pumpScreen(tester, const BreathingExerciseScreen());
    await tester.ensureVisible(find.byKey(const Key('breathing_start')));
    await tester.tap(find.byKey(const Key('breathing_start')));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Breathe in'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    expect(find.text('Hold'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('breathing_stop')));
    await tester.tap(find.byKey(const Key('breathing_stop')));
    await tester.pumpAndSettle();
    expect(find.text('Ready when you are'), findsOneWidget);
  });
}
