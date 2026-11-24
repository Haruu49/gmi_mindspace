# GMI MindSpace – Counsellor guide

For GMI counsellors (and administrators, who use the same sign-in screen).

---

## 1. Getting an account

**Option A – sign up yourself** (needs migration 015 and the email setup in
[DEPLOYMENT.md › Supabase checklist](DEPLOYMENT.md#4-supabase-checklist-for-each-environment)):

1. Welcome screen ▸ **Counsellor Login** ▸ **New counsellor? Sign up**.
2. Enter full name, **Staff ID** (3–20 letters or numbers), your **@gmi.edu.my** email and a password.
3. Tap **Send me a code**. Enter the **6-digit code** from the email ▸ **Verify and continue**.
4. You land on the counsellor dashboard.

If you see *"Your email is verified, but counsellor access could not be activated"*, your Staff ID
is already registered (or was typed incorrectly). Contact the administrator.
Student addresses (`@student.gmi.edu.my`) cannot sign up as counsellors.

**Option B – an administrator promotes you:** sign up through the app, then an administrator
assigns the Counsellor role in **Admin ▸ User accounts**.

Every self-registration is recorded in the audit log. Administrators can demote or deactivate
accounts at any time.

## 2. What you can and cannot see

| You **can** see | You **cannot** see |
|---|---|
| Names of students who booked with you or registered for activities | Any student's **journal** |
| Appointments assigned to you, and the student's short booking note | Mood **notes** or **reasons** |
| Mood **counts per mood**, only if a student shares them with you (max 30 days, revocable) | Other counsellors' private notes |
| Your own private appointment notes | Appointments assigned to other counsellors |
| Aggregated reports (counts only) and programme feedback (names hidden when anonymous) | Students' passwords or sign-in details |

These limits are enforced by the database, not just the app.

## 3. The counsellor area

Tabs: **Overview · Appointments · Programmes · Content**

### Overview
Pending requests, confirmed sessions, the next 7 days, completed sessions, active programmes and
participation, with shortcuts to *Appointments, Availability, Programmes, Learning Hub* and
*Feedback & Reports*.

### Availability (open your slots)
Add the times students may book. Overlapping slots are refused. Students only see slots that are
free; each slot can hold one appointment.

### Appointments
- Search and filter requests.
- **Confirm**, **Reject** (an explanation is required and shown to the student),
  **Reschedule** to another of your slots, or mark **Completed**.
- Add **private notes**. Only you can read them, never the student or administrators.
- Double booking is impossible: the database rejects overlapping appointments.

### Programmes (Well-being Activities)
Create a programme (online, physical or hybrid), keep it as a draft, then **publish**. View
registrations, **mark attendance**, and read feedback. Online links are shown to students only
after they register (see the note in KNOWN_ISSUES.md).

### Content (Learning Hub)
If an administrator gave you content permission: create, edit and publish articles, videos,
infographics and FAQs, with an optional image from your photo library.

**Sharing a PDF with all students** (worksheets, guides, slides saved as PDF):
1. Content ▸ **New resource** (or open an existing one).
2. Fill in the title and description. For a pure handout, choose the format **Download**; it then
   needs no link and no long text.
3. Under *PDF for students* tap **Attach PDF** and choose the file (PDF only, up to 20 MB).
   The file name and size appear; **Replace PDF** swaps it, ✕ removes it.
4. Switch **Published** on and tap **Save**. Students see a **PDF** label on the card and an
   **Open PDF** button on the resource.

Notes: one PDF per resource. Drafts stay hidden: students cannot open a draft's PDF. Replacing or
removing a PDF, or deleting the resource, also deletes the old file. Share only material you have
the right to share, and nothing about individual students.

### Feedback & Reports
Aggregated numbers only (appointment counts, programme participation). No individual mood or
journal data is ever included.

## 4. Good practice

- Keep booking notes and private notes brief and factual; they are stored in the database.
- The app is **not monitored 24/7**. Make sure students know the emergency numbers on the
  **Get help** screen and the Counselling Unit's real opening hours.
- Before each release, check every number and opening hour in the Get Help screen
  (`lib/core/constants/emergency_contacts.dart`) with the Counselling Unit.
- Use only fictional data while the app is in testing.
