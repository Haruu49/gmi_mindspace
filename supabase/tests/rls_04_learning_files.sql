-- ============================================================================
-- RLS TESTS · part 4 · Learning Hub PDF files (private bucket learning-files)
-- Uses accounts from part 1: bob ...b2 (active student), carol ...c3
-- (counsellor with content permission). All people are FICTIONAL.
-- ============================================================================
\set ON_ERROR_STOP 1
reset role;

-- A published resource with a PDF, and a draft with a PDF (as postgres).
insert into public.resources (id, title, description, category, format, content, published,
                              author_id, file_path, file_name, file_size_bytes)
values
  ('00000000-0000-4000-8000-00000000f001', 'Exam stress worksheet', 'A printable worksheet for exam weeks.',
   'stress_management', 'download', null, true, '00000000-0000-4000-8000-0000000000c3',
   'resources/pub.pdf', 'Exam stress worksheet.pdf', 120000),
  ('00000000-0000-4000-8000-00000000f002', 'Draft sleep guide', 'Not ready for students yet.',
   'sleep_wellbeing', 'download', null, false, '00000000-0000-4000-8000-0000000000c3',
   'resources/draft.pdf', 'Sleep guide.pdf', 90000);

insert into storage.objects (bucket_id, name, owner) values
  ('learning-files', 'resources/pub.pdf', '00000000-0000-4000-8000-0000000000c3'),
  ('learning-files', 'resources/draft.pdf', '00000000-0000-4000-8000-0000000000c3');

select tests.ok(
  (select public = false and file_size_limit = 20971520 and allowed_mime_types = array['application/pdf']
     from storage.buckets where id = 'learning-files'),
  'learning-files bucket is private, PDF only, 20 MB');

select tests.fails($$update public.resources set file_path = '../secret.pdf'
                     where id = '00000000-0000-4000-8000-00000000f001'$$, '23514',
  'file paths outside resources/*.pdf are rejected');
select tests.fails($$update public.resources set file_name = null
                     where id = '00000000-0000-4000-8000-00000000f001'$$, '23514',
  'path, name and size must be set together');

-- ---- Student ---------------------------------------------------------------
set role authenticated;
select tests.login('00000000-0000-4000-8000-0000000000b2');

select tests.ok(
  (select count(*) from storage.objects where bucket_id = 'learning-files' and name = 'resources/pub.pdf') = 1,
  'student can read the PDF of a published resource');
select tests.ok(
  (select count(*) from storage.objects where bucket_id = 'learning-files' and name = 'resources/draft.pdf') = 0,
  'student cannot read the PDF of a draft resource');
select tests.ok(
  (select file_name from public.resources where id = '00000000-0000-4000-8000-00000000f001') = 'Exam stress worksheet.pdf',
  'student sees the file name of a published resource');
select tests.fails($$insert into storage.objects (bucket_id, name) values ('learning-files', 'resources/student.pdf')$$,
  '42501', 'student cannot upload a PDF');
-- RLS filters the row out of the UPDATE (no error, nothing changes).
update public.resources set file_path = 'resources/other.pdf', file_name = 'x.pdf', file_size_bytes = 1
 where id = '00000000-0000-4000-8000-00000000f001';
reset role;
select tests.ok(
  (select file_path from public.resources where id = '00000000-0000-4000-8000-00000000f001') = 'resources/pub.pdf',
  'student cannot change a resource file');
set role authenticated;

-- ---- Counsellor with content permission -----------------------------------
select tests.login('00000000-0000-4000-8000-0000000000c3');
insert into storage.objects (bucket_id, name, owner)
  values ('learning-files', 'resources/new.pdf', '00000000-0000-4000-8000-0000000000c3');
select tests.ok(
  (select count(*) from storage.objects where bucket_id = 'learning-files') = 3,
  'content manager can upload and sees every PDF, drafts included');
delete from storage.objects where bucket_id = 'learning-files' and name = 'resources/new.pdf';
select tests.ok(
  (select count(*) from storage.objects where bucket_id = 'learning-files' and name = 'resources/new.pdf') = 0,
  'content manager can delete a PDF');
update public.resources set published = false where id = '00000000-0000-4000-8000-00000000f001';

-- ---- Unpublished: the student loses access immediately --------------------
select tests.login('00000000-0000-4000-8000-0000000000b2');
select tests.ok(
  (select count(*) from storage.objects where bucket_id = 'learning-files' and name = 'resources/pub.pdf') = 0,
  'unpublishing a resource blocks its PDF for students');

-- ---- Signed out -------------------------------------------------------------
reset role;
set role anon;
select set_config('request.jwt.claims', '', false);
do $$
declare n int;
begin
  begin
    select count(*) into n from storage.objects where bucket_id = 'learning-files';
    if n > 0 then raise exception 'FAIL: signed-out user can see learning files'; end if;
  exception when insufficient_privilege then null;
  end;
  raise notice 'PASS: signed-out users cannot read learning files';
end $$;
reset role;
