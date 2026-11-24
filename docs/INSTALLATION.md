# GMI MindSpace – Installation guide

Two audiences:

- **[Testers](#installing-the-android-apk)** – install the app on an Android phone from an APK file.
- **[Developers](#developer-setup)** – set up the project on a computer, run tests, build the app.

- **[iPhone testers (advanced)](#installing-on-an-iphone-advanced-unsigned-test-build)** – sideload the unsigned iOS test build.

Proper iPhone distribution (TestFlight / Ad Hoc) is covered in [DEPLOYMENT.md › iOS](DEPLOYMENT.md#3-ios).

---

## Installing the Android APK

For selected testers only. The app is **not** on Google Play.

**You need:** an Android phone running **Android 7.0 or newer**, about 150 MB free space, and the
file `app-release.apk` sent to you privately by the project team.

1. **Get the file onto the phone.** On the phone, open
   <https://github.com/Haruu49/gmi_mindspace/releases>, find the newest **GMI MindSpace … test build**
   and tap the `.apk` file under *Assets* (only download it from this page). Or copy the file
   over USB into the phone's *Download* folder.
2. **Open it.** Open the **Files** (or *My Files*) app ▸ *Downloads* ▸ tap the downloaded `GMI-MindSpace-….apk`.
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

## Installing on an iPhone (advanced, unsigned test build)

GitHub builds an **unsigned** iOS file, `GMI-MindSpace-1.0.0-ios-unsigned.ipa`, on every release.
An iPhone will not install it directly: you sign it with **your own Apple ID** using a sideloading
tool on a computer. This is meant for developers and technical testers, not for students. The
proper route for students is TestFlight ([DEPLOYMENT.md › 3.7](DEPLOYMENT.md#37-testflight-internal-testers)).

**You need:** an iPhone with iOS 15 or newer, a Windows PC or Mac, a USB cable, and an Apple ID.
Using a **separate Apple ID** is recommended, because you type its password into the tool.

1. Download the `.ipa` from the newest release on
   <https://github.com/Haruu49/gmi_mindspace/releases> (on the computer).
2. Install **Sideloadly** (<https://sideloadly.io>). On Windows also install iTunes and iCloud
   from Apple's website (not the Microsoft Store version).
3. Connect the iPhone by USB, unlock it and tap **Trust**.
4. Open Sideloadly, drag the `.ipa` in, enter your Apple ID, tap **Start**. If Sideloadly reports
   that the bundle ID is unavailable, enable its option to change the bundle ID.
5. On the iPhone: **Settings ▸ Privacy & Security ▸ Developer Mode ▸ On** (restart when asked).
6. **Settings ▸ General ▸ VPN & Device Management ▸** your Apple ID **▸ Trust**.
7. Open GMI MindSpace.

**Limits of a free Apple ID:** the app **stops opening after 7 days** and must be signed again
(repeat step 4, or use AltStore, which can refresh it over Wi-Fi); at most 3 sideloaded apps at a
time. A paid Apple Developer account extends this to one year.

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
