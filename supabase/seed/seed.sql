-- ============================================================================
-- GMI MindSpace · sample content (safe to run on a development project)
--
-- Contains ONLY general learning content and example programmes.
-- It creates no users and no student data. Run it after the migrations,
-- in the Supabase SQL editor (runs as postgres, so RLS does not block it).
--
-- First administrator (run once, with a real staff e-mail that has already
-- signed up through the app):
--   update public.user_roles set role = 'admin'
--   where user_id = (select id from auth.users where email = 'it-admin@your-institution');
-- After that, assign every other role from the app (Admin › User accounts).
-- ============================================================================

insert into public.resources (title, description, category, format, content, read_minutes, published, author_id)
values
  ('What is mental health?',
   'A simple introduction to mental health and well-being.',
   'understanding_mental_health', 'article',
   'Mental health is about how we think, feel and cope with everyday life. Like physical health, it '
   || 'changes over time. Everyone has mental health – it is not only about illness.' || chr(10) || chr(10)
   || 'Good days and hard days are both normal. Looking after sleep, movement, connection with others '
   || 'and time to rest all support well-being. If difficult feelings last a long time or get in the '
   || 'way of daily life, talking to someone you trust or a GMI counsellor can help.',
   4, true, null),
  ('Managing exam stress',
   'Practical ways to stay steady during assessment weeks.',
   'stress_management', 'article',
   'Some stress before exams is normal and can even help you focus. These steps can keep it manageable:' || chr(10)
   || '• Break revision into short, specific tasks.' || chr(10)
   || '• Take real breaks – step away from screens.' || chr(10)
   || '• Keep regular sleep; all-nighters reduce memory.' || chr(10)
   || '• Eat regular meals and drink water.' || chr(10)
   || '• Talk to classmates, lecturers or the Counselling Unit if you feel overwhelmed.',
   5, true, null),
  ('Recognising academic burnout',
   'Signs of burnout and small steps to recover your energy.',
   'academic_burnout', 'article',
   'Burnout can feel like constant tiredness, losing interest in studies, or feeling that nothing you do '
   || 'is enough. It usually builds up slowly when demands stay high for a long time without rest.' || chr(10) || chr(10)
   || 'Helpful steps include protecting time for rest, reducing what you can, asking for extensions early '
   || 'when allowed, and reaching out for support. Burnout is a signal to change pace, not a personal failure.',
   5, true, null),
  ('Sleep and well-being FAQ',
   'Common questions about sleep for busy students.',
   'sleep_wellbeing', 'faq',
   'Q: How much sleep do students need?' || chr(10)
   || 'A: Most young adults feel best with around 7–9 hours.' || chr(10) || chr(10)
   || 'Q: Is it okay to catch up at weekends?' || chr(10)
   || 'A: A little extra rest helps, but a regular schedule works better.' || chr(10) || chr(10)
   || 'Q: What if I cannot fall asleep?' || chr(10)
   || 'A: Get up, do something calm in dim light, and return to bed when sleepy.',
   3, true, null),
  ('When and how to ask for help',
   'Reaching out is a strength. Here is how to start.',
   'help_seeking', 'article',
   'You do not need to wait for a crisis to talk to someone. If something has been on your mind for a '
   || 'while, a counsellor can listen and help you think it through.' || chr(10) || chr(10)
   || 'You can request an appointment in the Booking tab, speak to someone you trust, or use the Get Help '
   || 'Now screen for urgent support. If you or someone else is in danger, call 999.',
   3, true, null)
on conflict do nothing;

insert into public.programmes (title, description, category, mode, location, online_url, starts_at, ends_at, capacity, status, created_by)
values
  ('Mindfulness Webinar',
   'A relaxed 45-minute introduction to mindfulness with simple practices you can use between classes.',
   'Webinar', 'online', null, 'https://example.com/replace-with-meeting-link',
   now() + interval '7 days', now() + interval '7 days 45 minutes', null, 'draft', null),
  ('Stress Management Workshop',
   'Hands-on workshop on planning, breaks and coping skills for busy weeks.',
   'Workshop', 'physical', 'Student Activity Centre', null,
   now() + interval '10 days', now() + interval '10 days 2 hours', 40, 'draft', null),
  ('Gratitude Challenge',
   'Write down three good things every day for one week and notice what changes.',
   'Challenge', 'online', null, 'https://example.com/replace-with-challenge-page',
   now() + interval '3 days', now() + interval '10 days', null, 'draft', null)
on conflict do nothing;
-- Programmes are seeded as drafts: a counsellor reviews and publishes them.
