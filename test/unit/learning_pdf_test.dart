import 'package:flutter_test/flutter_test.dart';
import 'package:gmi_mindspace/features/learning_hub/domain/learning_resource.dart';

void main() {
  group('validatePdf', () {
    test('accepts a PDF up to exactly 20 MB, any letter case', () {
      expect(validatePdf(fileName: 'worksheet.pdf', sizeBytes: 1000), isNull);
      expect(validatePdf(fileName: 'REPORT.PDF', sizeBytes: maxPdfBytes), isNull);
    });

    test('refuses other file types', () {
      expect(validatePdf(fileName: 'notes.docx', sizeBytes: 1000), 'Please choose a PDF file.');
      expect(validatePdf(fileName: 'pdf', sizeBytes: 1000), 'Please choose a PDF file.');
      expect(validatePdf(fileName: 'slides.pdf.exe', sizeBytes: 1000), 'Please choose a PDF file.');
    });

    test('refuses files over 20 MB and empty files', () {
      expect(validatePdf(fileName: 'big.pdf', sizeBytes: maxPdfBytes + 1), 'PDFs must be 20 MB or smaller.');
      expect(validatePdf(fileName: 'empty.pdf', sizeBytes: 0), 'This file is empty.');
    });
  });

  test('formatFileSize uses KB below 1 MB and one decimal for MB', () {
    expect(formatFileSize(850 * 1024), '850 KB');
    expect(formatFileSize(500), '1 KB');
    expect(formatFileSize((1.2 * 1024 * 1024).round()), '1.2 MB');
    expect(formatFileSize(maxPdfBytes), '20.0 MB');
  });

  group('resource file fields', () {
    final base = {
      'id': 'r1',
      'title': 'Exam stress worksheet',
      'description': 'A printable worksheet.',
      'category': 'stress_management',
      'format': 'download',
      'published': true,
      'created_at': '2026-11-24T08:00:00Z',
    };

    test('fromJson reads the attached PDF', () {
      final r = LearningResource.fromJson({
        ...base,
        'file_path': 'resources/1-2.pdf',
        'file_name': 'Worksheet.pdf',
        'file_size_bytes': 120000,
      });
      expect(r.hasFile, isTrue);
      expect(r.filePath, 'resources/1-2.pdf');
      expect(r.fileName, 'Worksheet.pdf');
      expect(r.fileSizeBytes, 120000);
    });

    test('a resource without a PDF has no file', () {
      expect(LearningResource.fromJson(base).hasFile, isFalse);
    });

    test('ResourceDraft.toRow writes the three file fields together', () {
      const withFile = ResourceDraft(
        title: 'Exam stress worksheet',
        description: 'A printable worksheet.',
        category: ResourceCategory.stress,
        format: ResourceFormat.download,
        published: true,
        filePath: 'resources/1-2.pdf',
        fileName: 'Worksheet.pdf',
        fileSizeBytes: 120000,
      );
      expect(withFile.toRow(), containsPair('file_path', 'resources/1-2.pdf'));
      expect(withFile.toRow(), containsPair('file_name', 'Worksheet.pdf'));
      expect(withFile.toRow(), containsPair('file_size_bytes', 120000));

      const noFile = ResourceDraft(
        title: 'Exam stress worksheet',
        description: 'A printable worksheet.',
        category: ResourceCategory.stress,
        format: ResourceFormat.article,
        published: false,
      );
      final row = noFile.toRow();
      expect(row['file_path'], isNull);
      expect(row['file_name'], isNull);
      expect(row['file_size_bytes'], isNull);
      expect(row.containsKey('file_path'), isTrue, reason: 'removing a PDF must clear the column');
    });
  });
}
