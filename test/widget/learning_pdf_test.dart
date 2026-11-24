import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:gmi_mindspace/features/counsellor_dashboard/presentation/content_editor_screen.dart';
import 'package:gmi_mindspace/features/learning_hub/data/learning_repository.dart';
import 'package:gmi_mindspace/features/learning_hub/data/pdf_picker.dart';
import 'package:gmi_mindspace/features/learning_hub/domain/learning_resource.dart';
import 'package:gmi_mindspace/features/learning_hub/presentation/resource_detail_screen.dart';
import 'package:gmi_mindspace/features/learning_hub/presentation/widgets/resource_card.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/fake_repos.dart';
import '../helpers/test_app.dart';

LearningResource _resource({bool withFile = true, ResourceFormat format = ResourceFormat.download}) => LearningResource(
  id: 'r1',
  title: 'Exam stress worksheet',
  description: 'A printable worksheet for exam weeks.',
  category: ResourceCategory.stress,
  format: format,
  published: true,
  createdAt: DateTime(2026, 11, 24),
  content: format == ResourceFormat.article ? 'A short introduction for students to read first.' : null,
  filePath: withFile ? 'resources/original.pdf' : null,
  fileName: withFile ? 'Exam stress worksheet.pdf' : null,
  fileSizeBytes: withFile ? 120 * 1024 : null,
);

PickedPdf _picked(String name, int size) =>
    PickedPdf(name: name, sizeBytes: size, readBytes: () async => Uint8List(size));

void main() {
  group('Counsellor attaches a PDF', () {
    Future<void> tapKey(WidgetTester tester, String key) async {
      await tester.ensureVisible(find.byKey(Key(key)));
      await tester.tap(find.byKey(Key(key)));
      await tester.pumpAndSettle();
    }

    testWidgets('new resource: attach shows the file, save stores path, name and size', (tester) async {
      final repo = FakeLearningRepository();
      await pumpScreen(
        tester,
        const ContentEditorScreen(),
        overrides: [
          learningRepositoryProvider.overrideWithValue(repo),
          pdfPickerProvider.overrideWithValue(() async => _picked('Worksheet.pdf', 120 * 1024)),
        ],
      );
      await tester.enterText(find.byKey(const Key('content_title')), 'Exam stress worksheet');
      await tester.enterText(find.byKey(const Key('content_description')), 'A printable worksheet for exam weeks.');
      await tester.enterText(find.byKey(const Key('content_body')), 'Print this and fill it in before each exam.');
      await tapKey(tester, 'content_attach_pdf');
      expect(repo.uploadedNames, ['Worksheet.pdf']);
      expect(find.text('Worksheet.pdf'), findsOneWidget);
      expect(find.textContaining('120 KB'), findsOneWidget);

      await tapKey(tester, 'content_save');
      final d = repo.created.single;
      expect(d.filePath, 'resources/upload-1.pdf');
      expect(d.fileName, 'Worksheet.pdf');
      expect(d.fileSizeBytes, 120 * 1024);
      expect(repo.deletedFiles, isEmpty);
    });

    testWidgets('a PDF over 20 MB is refused before upload', (tester) async {
      final repo = FakeLearningRepository();
      await pumpScreen(
        tester,
        const ContentEditorScreen(),
        overrides: [
          learningRepositoryProvider.overrideWithValue(repo),
          pdfPickerProvider.overrideWithValue(() async => _picked('huge.pdf', maxPdfBytes + 1)),
        ],
      );
      await tapKey(tester, 'content_attach_pdf');
      expect(find.text('PDFs must be 20 MB or smaller.'), findsOneWidget);
      expect(repo.uploadedNames, isEmpty);
    });

    testWidgets('a Download resource with a PDF saves without a media link', (tester) async {
      final repo = FakeLearningRepository();
      await pumpScreen(
        tester,
        const ContentEditorScreen(resourceId: 'r1'),
        overrides: [
          learningRepositoryProvider.overrideWithValue(repo),
          resourceDetailProvider('r1').overrideWith((ref) async => _resource()),
        ],
      );
      expect(find.text('Exam stress worksheet.pdf'), findsOneWidget);

      // Saving as-is works without a media link because a PDF is attached.
      await tapKey(tester, 'content_save');
      expect(repo.updated.single.$2.filePath, 'resources/original.pdf');
      expect(repo.deletedFiles, isEmpty);
    });

    testWidgets('removing the PDF clears it and deletes the stored file after saving', (tester) async {
      final repo = FakeLearningRepository();
      await pumpScreen(
        tester,
        const ContentEditorScreen(resourceId: 'r1'),
        overrides: [
          learningRepositoryProvider.overrideWithValue(repo),
          resourceDetailProvider('r1').overrideWith((ref) async => _resource(format: ResourceFormat.article)),
        ],
      );
      await tapKey(tester, 'content_remove_pdf');
      expect(find.text('Exam stress worksheet.pdf'), findsNothing);
      expect(repo.deletedFiles, isEmpty, reason: 'nothing is deleted until the change is saved');
      await tapKey(tester, 'content_save');
      expect(repo.updated.single.$2.filePath, isNull);
      expect(repo.deletedFiles, ['resources/original.pdf']);
    });

    testWidgets('replacing the PDF deletes the original after saving', (tester) async {
      final repo = FakeLearningRepository();
      await pumpScreen(
        tester,
        const ContentEditorScreen(resourceId: 'r1'),
        overrides: [
          learningRepositoryProvider.overrideWithValue(repo),
          resourceDetailProvider('r1').overrideWith((ref) async => _resource()),
          pdfPickerProvider.overrideWithValue(() async => _picked('New version.pdf', 2 * 1024 * 1024)),
        ],
      );
      await tapKey(tester, 'content_attach_pdf');
      expect(find.text('New version.pdf'), findsOneWidget);
      await tapKey(tester, 'content_save');
      expect(repo.updated.single.$2.filePath, 'resources/upload-1.pdf');
      expect(repo.deletedFiles, ['resources/original.pdf']);
    });

    testWidgets('leaving without saving removes the unsaved upload', (tester) async {
      final repo = FakeLearningRepository();
      await pumpScreen(
        tester,
        const ContentEditorScreen(),
        overrides: [
          learningRepositoryProvider.overrideWithValue(repo),
          pdfPickerProvider.overrideWithValue(() async => _picked('Draft.pdf', 1024)),
        ],
      );
      await tapKey(tester, 'content_attach_pdf');
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(repo.deletedFiles, ['resources/upload-1.pdf']);
    });

    testWidgets('deleting a resource also deletes its PDF', (tester) async {
      final repo = FakeLearningRepository();
      await pumpScreen(
        tester,
        const ContentEditorScreen(resourceId: 'r1'),
        overrides: [
          learningRepositoryProvider.overrideWithValue(repo),
          resourceDetailProvider('r1').overrideWith((ref) async => _resource()),
        ],
      );
      await tester.tap(find.byTooltip('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();
      expect(repo.deletedResources, ['r1']);
      expect(repo.deletedFiles, ['resources/original.pdf']);
    });
  });

  group('Student opens a PDF', () {
    testWidgets('Open PDF requests a signed link for the file and opens it', (tester) async {
      final repo = FakeLearningRepository();
      final opened = <Uri>[];
      await pumpScreen(
        tester,
        const ResourceDetailScreen(resourceId: 'r1'),
        overrides: [
          learningRepositoryProvider.overrideWithValue(repo),
          resourceDetailProvider('r1').overrideWith((ref) async => _resource()),
          bookmarkIdsProvider.overrideWith((ref) async => <String>{}),
          pdfOpenerProvider.overrideWithValue((uri) async {
            opened.add(uri);
            return true;
          }),
        ],
      );
      expect(find.textContaining('Exam stress worksheet.pdf'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('resource_open_pdf')));
      await tester.tap(find.byKey(const Key('resource_open_pdf')));
      await tester.pumpAndSettle();
      expect(repo.signedUrlRequests, ['resources/original.pdf']);
      expect(opened.single.host, 'storage.example.test');
    });

    testWidgets('no Open PDF button when nothing is attached', (tester) async {
      await pumpScreen(
        tester,
        const ResourceDetailScreen(resourceId: 'r1'),
        overrides: [
          learningRepositoryProvider.overrideWithValue(FakeLearningRepository()),
          resourceDetailProvider('r1')
              .overrideWith((ref) async => _resource(withFile: false, format: ResourceFormat.article)),
          bookmarkIdsProvider.overrideWith((ref) async => <String>{}),
        ],
      );
      expect(find.byKey(const Key('resource_open_pdf')), findsNothing);
    });

    testWidgets('resource cards mark resources that include a PDF', (tester) async {
      await pumpScreen(
        tester,
        Scaffold(
          body: ListView(children: [ResourceCard(resource: _resource())]),
        ),
      );
      expect(find.text('PDF'), findsOneWidget);
    });
  });
}
