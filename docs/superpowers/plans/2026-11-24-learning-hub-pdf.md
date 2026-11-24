# Learning Hub PDF Materials Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Counsellors attach one PDF (≤ 20 MB) to a Learning Hub resource; signed-in students open it from the resource page through a one-hour signed link.

**Architecture:** New private storage bucket `learning-files` whose read policy only lets active users read an object referenced by a *published* resource; three nullable columns on `resources`; repository methods for upload / signed URL / delete; editor attach UI behind an injectable picker; "Open PDF" button on the resource page.

**Tech Stack:** Supabase Storage + RLS, Flutter, Riverpod, `file_picker`, `url_launcher`.

**Spec:** `docs/superpowers/specs/2026-11-24-learning-hub-pdf-design.md`

## Global Constraints

- Bucket `learning-files`, private, `application/pdf` only, 20,971,520 bytes (20 MB).
- Object path format: `resources/<millis>-<random>.pdf` (DB check `^resources/[A-Za-z0-9._-]+\.pdf$`).
- Signed URL lifetime 3600 s. One PDF per resource.
- Students: read only objects of **published** resources, and only while active. Content managers (`private.can_manage_content()`): insert / select / update / delete.
- No commit/push until the user asks. Test data fictional only.

## Review Focus

- Draft resource with a PDF: student must not be able to read the file even with the exact path.
- Unpublishing a resource immediately blocks new signed URLs for its PDF.
- Replacing / removing a PDF, deleting a resource, or leaving the editor after an unsaved upload must not leave orphan files (best effort, never blocks the user).
- A `.pdf`-named file over 20 MB or a non-PDF is refused with a friendly message before upload.
- Opening a PDF offline shows the friendly offline message, not a crash.

---

### Task 1: Database (migration 016) + SQL tests
**Files:** create `supabase/migrations/20261124000016_learning_files.sql`, `supabase/tests/rls_04_learning_files.sql`; modify `supabase/tests/run_local.sh`.
- [ ] Tests first (`rls_04`, users from part 1: bob `…b2` active student, carol `…c3` counsellor with content permission, erin `…e5` admin). As postgres insert a published resource with `file_path='resources/pub.pdf'` and a draft with `resources/draft.pdf`, plus matching `storage.objects` rows in `learning-files`. Assert: bob reads `pub.pdf` object; bob cannot read `draft.pdf`; anon reads nothing; bob cannot insert an object; carol can insert and delete objects; bob cannot set `file_path` on a resource; bad `file_path` (`../x.pdf`) rejected by check; after unpublishing, bob cannot read `pub.pdf`; incomplete file trio rejected.
- [ ] Run `bash supabase/tests/run_local.sh` → fails (column missing).
- [ ] Migration: columns + checks + completeness constraint + partial index on `file_path`; column grants (insert/update); bucket row; five storage policies.
- [ ] Run again → `ALL RLS TESTS PASSED`.

### Task 2: Domain + repository
**Files:** `lib/features/learning_hub/domain/learning_resource.dart`, `lib/features/learning_hub/data/learning_repository.dart`; test `test/unit/learning_pdf_test.dart`.
- Produces: `LearningResource.filePath/fileName/fileSizeBytes`, `bool get hasFile`; `ResourceDraft` same three fields in `toRow()`; top-level `String? validatePdf({required String fileName, required int sizeBytes})` (messages: `'Please choose a PDF file.'`, `'PDFs must be 20 MB or smaller.'`, empty file `'This file is empty.'`); `String formatFileSize(int bytes)` (`'850 KB'`, `'1.2 MB'`); `const maxPdfBytes = 20 * 1024 * 1024`. Repository: `uploadPdf(Uint8List bytes, String fileName) -> Future<String>` (path), `signedPdfUrl(String path) -> Future<String>`, `deleteFile(String path) -> Future<void>` (best effort, never throws); select columns include the three fields.
- [ ] Unit tests first (validation messages incl. `report.PDF` accepted, `notes.docx` refused, 20 MB exactly accepted, 20 MB + 1 refused, 0 bytes refused; size formatting; `toRow` includes file fields; `fromJson` reads them, `hasFile`).
- [ ] Implement; `flutter test test/unit` green.

### Task 3: UI (editor + resource page + card)
**Files:** `content_editor_screen.dart`, `resource_detail_screen.dart`, `resource_card.dart`, new `lib/features/learning_hub/data/pdf_picker.dart`; tests `test/widget/learning_pdf_test.dart`, `test/helpers/fake_repos.dart`.
- Produces: `class PickedPdf { String name; Uint8List bytes; }`, `final pdfPickerProvider = Provider<Future<PickedPdf?> Function()>` (real impl uses `file_picker`, `withData: true`, `allowedExtensions: ['pdf']`); keys `content_attach_pdf`, `content_remove_pdf`, `resource_open_pdf`.
- [ ] Widget tests first with `FakeLearningRepository` (records uploads, deletes, signed-URL requests): editor attach shows file name + size and saves path/name/size; too-large pick shows message and does not upload; Remove + Save deletes the original file; resource page shows Open PDF only when `hasFile`, tapping requests a signed URL for that path; card shows a "PDF" chip.
- [ ] Implement; editor deletes replaced/removed originals after a successful save, deletes an unsaved new upload on dispose, and deletes the file after deleting the resource; a `download`-format resource with a PDF needs no link.
- [ ] `flutter analyze`, `flutter test` green.

### Task 4: Apply to dev project, live check, docs
- [ ] Apply migration 016 via MCP; verify bucket + policies exist.
- [ ] Live API check (script in scratchpad, test accounts): counsellor uploads a small real PDF and creates a published resource; student gets a signed URL and downloads `%PDF` bytes; student cannot upload; counsellor upload of a non-PDF and of > 20 MB is refused by the bucket; draft PDF unreadable by the student; clean up resource + file.
- [ ] Build release APK; on the emulator open a PDF resource and tap Open PDF (screenshot).
- [ ] Update `docs/DATABASE.md`, `docs/COUNSELLOR_GUIDE.md`, `docs/USER_GUIDE.md`, `docs/TESTING_REPORT.md`, `docs/KNOWN_ISSUES.md`, `README.md` (counts, migration list).
