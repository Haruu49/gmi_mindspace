import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants/env.dart';

/// Initialises Supabase once at start-up. Returns false (instead of
/// crashing) when the build was made without credentials, so the app can
/// show a clear "configuration needed" screen.
abstract final class SupabaseService {
  static bool _initialised = false;
  static bool get isReady => _initialised;

  /// Lets widget/integration tests run the full app with faked repositories.
  @visibleForTesting
  static void debugSetReady(bool ready) => _initialised = ready;

  static Future<bool> initialise() async {
    if (_initialised) return true;
    if (!Env.isSupabaseConfigured) return false;
    await Supabase.initialize(
      url: Env.supabaseUrl,
      publishableKey: Env.supabasePublishableKey,
      // PKCE is the secure default for mobile deep-link auth flows. The
      // session is persisted by supabase_flutter (SharedPreferences, app
      // sandbox only). Hardening option: a flutter_secure_storage-backed
      // LocalStorage (Keychain / Android Keystore).
      authOptions: const FlutterAuthClientOptions(authFlowType: AuthFlowType.pkce),
    );
    _initialised = true;
    return true;
  }
}

/// The Supabase client. Overridden with a fake in tests.
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});
