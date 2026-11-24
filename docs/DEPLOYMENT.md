# GMI MindSpace – Deployment guide (private testing only)

This guide covers **private** distribution to selected testers. It does **not** cover
Google Play or App Store submission, and the app must not be submitted to either store.

| Item | Value |
|---|---|
| App name | GMI MindSpace |
| Android package / iOS bundle ID | `my.edu.gmi.mindspace` |
| Version | `1.0.0+1` (`pubspec.yaml`: name `1.0.0`, build number `1`) |
| Supabase project | `gmi-mindspace-dev` (the only project that exists today) |
| Auth deep link | `my.edu.gmi.mindspace://auth-callback` |

> **Production configuration today points at the development Supabase project.** There is
> no separate production project yet. See [KNOWN_ISSUES.md](KNOWN_ISSUES.md).

---

## 1. Before every tester build

1. Bump the build number in `pubspec.yaml` (`version: 1.0.0+2`, `+3`, …). Android refuses to
   install an update with the same or a lower build number.
2. Run the checks:
   ```bash
   export PATH="$HOME/development/flutter/bin:$PATH"
   flutter analyze
   flutter test
   bash supabase/tests/run_local.sh
   ```
3. Make sure `env/dev.json` holds the project URL and the **publishable** key only.
   Never put the service-role / secret key in the app.

---

## 2. Android

### 2.1 Signing (one-time setup – already done on the development laptop)

The release key was created on 2026-11-24:

| What | Where | In git? |
|---|---|---|
| Keystore | `~/.gmi-mindspace-signing/gmi-mindspace-release.jks` | **No** (outside the repo) |
| Passwords | `android/key.properties` | **No** (`android/.gitignore`) |
| Backup copy of the passwords | `~/.gmi-mindspace-signing/key.properties.backup` | **No** |

Key alias `gmi-mindspace`, RSA 4096, valid for 10,000 days.

**Back up the whole `~/.gmi-mindspace-signing/` folder now** (encrypted USB drive or a
password manager). If the key is lost, testers cannot update the app: they must uninstall it
(losing nothing on the server, but signing in again) and install a build signed with a new key.

`android/key.properties` format (for a new machine):
```properties
storeFile=/home/<you>/.gmi-mindspace-signing/gmi-mindspace-release.jks
storePassword=<from the backup>
keyAlias=gmi-mindspace
keyPassword=<from the backup>
```

A release build **fails on purpose** if `android/key.properties` is missing, so an APK can never
be signed with the debug key by accident.

### 2.2 Build the signed APK

```bash
flutter build apk --release --dart-define-from-file=env/dev.json
```

Output: `build/app/outputs/flutter-apk/app-release.apk` (one universal APK, about 63 MB, for all
phone CPU types).

Verify the signature before sending it:
```bash
BT=$(ls -d ~/Android/Sdk/build-tools/* | sort -V | tail -1)
PATH=/snap/android-studio/current/jbr/bin:$PATH $BT/apksigner verify --print-certs \
  build/app/outputs/flutter-apk/app-release.apk
# expect: Signer #1 certificate DN: CN=GMI MindSpace, OU=Counselling Unit, ...
$BT/aapt dump badging build/app/outputs/flutter-apk/app-release.apk | head -1
# expect: package: name='my.edu.gmi.mindspace' versionCode='…' versionName='1.0.0'
```

### 2.3 Permissions

| Permission | Why |
|---|---|
| `INTERNET` | Talk to Supabase over HTTPS (cleartext traffic is disabled). |
| `POST_NOTIFICATIONS` | Appointment and activity reminders (Android 13+). Asked after sign-in, never at launch. |
| `RECEIVE_BOOT_COMPLETED` | Re-schedule reminders after the phone restarts. |
| `VIBRATE` | Added by the notifications plugin for reminder alerts. |

No camera, location, contacts, microphone or storage permission is requested. Counsellors pick
Learning Hub images through the system photo picker, which needs no permission.

### 2.4 Distribute to testers

Share the APK privately (e.g. a restricted Google Drive / OneDrive link or USB). Do not post it
publicly. Testers follow [INSTALLATION.md › Installing the APK](INSTALLATION.md#installing-the-android-apk).

---

## 3. iOS

> iOS apps can only be built on **macOS with Xcode**. This repository was prepared on Linux:
> the iOS project is configured, but **no iOS build, simulator run or iPhone test has been done**.
> A Windows or Linux machine cannot compile a native iOS app.

### 3.1 What is already configured

| Setting | Value |
|---|---|
| Bundle ID | `my.edu.gmi.mindspace` (`ios/Runner.xcodeproj`) |
| Display name / bundle name | GMI MindSpace |
| Minimum iOS | 15.0 |
| App icon + launch screen | Generated from the GMI MindSpace logo (`assets/branding/`) |
| URL scheme | `my.edu.gmi.mindspace` (e-mail confirmation / password reset) |
| Permissions | `NSPhotoLibraryUsageDescription` only (counsellors choosing a Learning Hub image). No camera, location or microphone. Notifications are requested at runtime and need no Info.plist key. |
| Supabase | Same `--dart-define-from-file=env/dev.json` as Android |

### 3.2 Requirements on the Mac

1. macOS with a current **Xcode** (App Store) and the iOS Simulator runtime.
2. CocoaPods: `sudo gem install cocoapods` (or `brew install cocoapods`).
3. Flutter SDK, then `flutter doctor` showing Xcode ✓.
4. Copy the project **and** `env/dev.json` (not in git) to the Mac.
5. `flutter pub get`, then `cd ios && pod install && cd ..`.

### 3.3 Simulator test (no Apple account needed)

```bash
open -a Simulator
flutter run -d "iPhone 16" --dart-define-from-file=env/dev.json
```
Then work through the checklist in [TESTING_REPORT.md › Manual device checklist](TESTING_REPORT.md#manual-device-checklist).

### 3.4 Apple signing – what you need

| Route | Apple account | Devices | Valid for | Good for |
|---|---|---|---|---|
| **Direct development install** (Xcode ▸ Run) | Free Apple ID works; paid account better | Phones plugged into the Mac | Free: 7 days. Paid: 1 year | The developer's own iPhone, quick checks |
| **Ad Hoc** | **Apple Developer Program** (paid, yearly) | Up to 100 registered iPhones per year, by UDID | Until the profile expires (1 year) | A small fixed group, no TestFlight |
| **TestFlight – internal** | Apple Developer Program | Up to 100 members of your App Store Connect team | Each build 90 days | **Recommended** once there are more than a few testers |
| TestFlight – external | Apple Developer Program | Up to 10,000 by e-mail / link | 90 days | Needs Apple's Beta App Review; not needed for this project |

Every route needs the bundle ID `my.edu.gmi.mindspace` registered to your team. TestFlight needs
an app record in App Store Connect; creating that record and uploading a TestFlight build is
**not** an App Store submission, as long as you never press "Submit for Review" for the App Store.

### 3.5 Direct development install on a physical iPhone

1. Open `ios/Runner.xcworkspace` in Xcode.
2. Runner ▸ Signing & Capabilities ▸ tick *Automatically manage signing* ▸ choose your Team.
3. iPhone: Settings ▸ Privacy & Security ▸ **Developer Mode** ▸ On (restart).
4. Plug in the iPhone, trust the Mac, select it in Xcode, or run
   `flutter run -d <iphone-id> --release --dart-define-from-file=env/dev.json`.
5. Free Apple ID only: on the iPhone, Settings ▸ General ▸ VPN & Device Management ▸ trust the developer.

### 3.6 Ad Hoc distribution

1. Collect each tester's iPhone **UDID** (Finder ▸ select the iPhone ▸ click the serial number line).
2. developer.apple.com ▸ Certificates, IDs & Profiles: register the devices, create an
   **Ad Hoc** provisioning profile for `my.edu.gmi.mindspace` including them.
3. Build: `flutter build ipa --release --export-method ad-hoc --dart-define-from-file=env/dev.json`
4. Install the `.ipa` from `build/ios/ipa/` with Apple Configurator or Finder (drag onto the device).
5. Adding a new tester means adding the UDID, regenerating the profile and rebuilding.

### 3.7 TestFlight (internal testers)

1. App Store Connect ▸ Apps ▸ ＋ New App ▸ bundle ID `my.edu.gmi.mindspace` (record only).
2. `flutter build ipa --release --dart-define-from-file=env/dev.json`
3. Upload `build/ios/ipa/*.ipa` with the **Transporter** app (or Xcode Organizer).
4. App Store Connect ▸ TestFlight ▸ Internal Testing ▸ add testers (team members).
5. Testers install **TestFlight** from the App Store and accept the invitation.
6. Answer the export-compliance question: the app uses only standard HTTPS encryption.

---

## 4. Supabase checklist for each environment

- [ ] All migrations applied in order (`supabase db push`), including `015_counsellor_signup`.
- [ ] Authentication ▸ URL configuration: `my.edu.gmi.mindspace://auth-callback` in redirect URLs.
- [ ] Authentication ▸ Providers ▸ Email: *Confirm email* **on**.
- [ ] Authentication ▸ Email templates ▸ Confirm signup: contains `{{ .Token }}` **and** `{{ .ConfirmationURL }}`.
- [ ] Authentication ▸ SMTP: your own provider (built-in sender is rate-limited).
- [ ] Authentication ▸ Password security: enable **leaked password protection** (currently off).
- [ ] Database ▸ Extensions: `pg_cron` on (reminders).
- [ ] At least one administrator assigned (see README › Supabase setup).
