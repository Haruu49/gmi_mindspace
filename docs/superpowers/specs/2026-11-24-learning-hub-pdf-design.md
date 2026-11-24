# Learning Hub PDF materials (short design)

Date: 2026-11-24 · Status: **approved 2026-11-24**

## Intent
Counsellors upload PDF materials (worksheets, guides, slides saved as PDF) for **all students**.
Students open them from the Learning Hub.

## Goals / non-goals / anti-goals
- Goals: attach one PDF to a Learning Hub resource; students open it from the resource page.
- Non-goals: files for one specific student; other file types (Word, PowerPoint, audio); an
  in-app PDF reader.
- Anti-goals: a PDF readable by people who are not signed-in, active GMI MindSpace users; a
  draft's PDF visible to students before it is published.

## Approaches
1. **Private storage bucket + one-hour signed link opened in the phone's PDF viewer (chosen).**
2. Public bucket like cover images. Rejected: anyone with the link (and drafts) can read it.
3. In-app PDF viewer. Rejected for now: extra dependency, larger APK; can be added later.

## Design
**Database (migration 016)**
- `resources`: new columns `file_path text`, `file_name text`, `file_size_bytes integer`
  (all nullable; `file_path` set means "has a PDF"). Added to the insert/update column grants.
- New **private** storage bucket `learning-files`: `application/pdf` only, **20 MB** limit.
- Storage policies: content managers (counsellors with content permission, admins) upload,
  replace, delete and read every object; **active users read an object only when a
  published resource points at it** (`resources.file_path = storage.objects.name`).

**App**
- Dependency `file_picker` (system document picker; no new Android/iOS permissions).
- Content editor: "Attach PDF" button → pick a `.pdf` ≤ 20 MB → upload → shows file name and
  size with "Replace" and "Remove". Saving stores path, name and size.
- Replacing/removing a PDF, or deleting the resource, also deletes the old file from storage.
- Resource page (student): if a PDF is attached, an **Open PDF** button (file name + size)
  creates a signed URL valid for 1 hour and opens it with the system viewer.
- Resource list cards show a small "PDF" marker.
- Errors use the existing friendly messages (offline, too large, not a PDF, could not open).

## My calls
- 20 MB limit; one PDF per resource; signed link valid 1 hour.
- Counsellors can attach a PDF to any format (article, download, etc.); the format list is unchanged.

## Tests
- SQL: student reads the PDF of a published resource; cannot read a draft's PDF; signed-out
  cannot read; student cannot upload; content manager can upload/delete; non-PDF rejected
  by the bucket's allowed types (checked via bucket config).
- Unit: file validation (extension, size). Widget: editor shows attached file and Remove;
  resource page shows Open PDF only when a file is attached.
- Live (emulator, dev project): counsellor-side upload not automatable without the picker;
  verify the student can open a PDF attached via SQL seed of a test file.
