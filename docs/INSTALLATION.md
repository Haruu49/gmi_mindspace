# GMI MindSpace – Installation guide

Two audiences:

- **[Testers](#installing-the-android-apk)** – install the app on an Android phone from an APK file.
- **[Developers](#developer-setup)** – set up the project on a computer, run tests, build the app.

iPhone installation is covered in [DEPLOYMENT.md › iOS](DEPLOYMENT.md#3-ios) (it needs a Mac).

---

## Installing the Android APK

For selected testers only. The app is **not** on Google Play.

**You need:** an Android phone running **Android 7.0 or newer**, about 150 MB free space, and the
file `app-release.apk` sent to you privately by the project team.

1. **Get the file onto the phone.** Download it from the private link you were sent, or copy it
   over USB into the phone's *Download* folder.
2. **Open it.** Open the **Files** (or *My Files*) app ▸ *Downloads* ▸ tap `app-release.apk`.
3. **Allow the install.** Android asks whether to allow apps from this source. Tap
   **Settings** ▸ switch on **Allow from this source** for the app you used (Files or Chrome) ▸
   press back.
   - Samsung: Settings ▸ Apps ▸ ⋮ ▸ Special access ▸ Install unknown apps.
   - Xiaomi / Redmi: Settings ▸ Privacy protection ▸ Special permissions ▸ Install unknown apps.
4. **Install.** Tap **Install**. If **Google Play Protect** says the app is unrecognised, tap
   **More details ▸ Install anyway**. This warning appears for every app installed outside the
   Play Store.
5. **Open GMI MindSpace** from the app drawer (lavender-and-green leaf icon).
6. **Sign in** with the account the team gave you, or create a student account.
7. When asked, **allow notifications** if you want appointment and activity reminders.
8. **Switch "Allow from this source" off again** (step 3) for safety.

**Updating:** install the newer APK the same way; your account and data stay (they live on the
server). If Android says *"App not installed as package conflicts with an existing package"*,
the new file was signed with a different key: uninstall GMI MindSpace first, then install.

**Uninstalling:** long-press the icon ▸ *Uninstall*. Your journal and mood entries stay on the
server under your account.

**Problems?** See [USER_GUIDE.md › Troubleshooting](USER_GUIDE.md#troubleshooting).

---

## Developer setup

Tested on Pop!_OS 24.04 (Linux). macOS works the same way; iOS builds need macOS.

### 1. Tools

| Tool | Version used |
|---|---|
| Flutter SDK | stable, in `~/development/flutter` |
| Android Studio | with Android SDK (API 37), build-tools 36, an emulator image |
| JDK | Android Studio's bundled JBR (`/snap/android-studio/current/jbr`) |
| PostgreSQL 16 | only for the local database security tests |

```bash
export PATH="$HOME/development/flutter/bin:$PATH"
flutter doctor
```

### 2. Get the code and dependencies

```bash
git clone https://github.com/Haruu49/gmi_mindspace.git
cd gmi_mindspace
flutter pub get
```

### 3. Configure Supabase

```bash
cp env/dev.example.json env/dev.json
```
Edit `env/dev.json` with the project URL and the **publishable** key (Supabase dashboard ▸
Project Settings ▸ API). `env/dev.json` is git-ignored. Never use the secret / service-role key.
Backend setup is in [README › Supabase setup](../README.md#supabase-setup) and the
[database documentation](DATABASE.md).

### 4. Run checks

```bash
flutter analyze                    # No issues found
flutter test                       # All tests passed
bash supabase/tests/run_local.sh   # ALL RLS TESTS PASSED
```

### 5. Run the app

```bash
flutter devices
flutter run -d <device-id> --dart-define-from-file=env/dev.json
```
Without `env/dev.json` the app opens a *Setup needed* screen (Get Help Now still works).

### 6. Live tests against the dev database (optional)

Uses fictional accounts listed in `env/test_accounts.json` (git-ignored):
```json
{"TEST_STUDENT_A": "...", "TEST_STUDENT_B": "...", "TEST_COUNSELLOR": "...", "TEST_PASSWORD": "..."}
```
```bash
flutter test integration_test/live_smoke_test.dart -d <device-id> \
  --dart-define-from-file=env/dev.json --dart-define-from-file=env/test_accounts.json
```

### 7. Build for testers

See [DEPLOYMENT.md](DEPLOYMENT.md).
