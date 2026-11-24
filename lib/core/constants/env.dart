/// Build-time configuration.
///
/// Values are injected with `--dart-define-from-file=env/dev.json` (see
/// `env/dev.example.json`). Nothing secret is ever committed:
///
/// * `SUPABASE_URL`              – your project URL.
/// * `SUPABASE_PUBLISHABLE_KEY`  – the *publishable* (anon) key. It is safe in
///   a mobile app only because every table is protected by Row Level Security.
///
/// NEVER put the service-role / secret key in the Flutter app.
abstract final class Env {
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );

  /// Deep link used by Supabase password-reset e-mails.
  static const String authRedirectUrl = String.fromEnvironment(
    'AUTH_REDIRECT_URL',
    defaultValue: 'my.edu.gmi.mindspace://auth-callback',
  );

  static bool get isSupabaseConfigured =>
      supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty;
}
