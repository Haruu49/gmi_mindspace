import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'app.dart';
import 'core/services/local_notification_service.dart';
import 'core/services/supabase_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Bundled font licence (Nunito, SIL OFL) for the in-app licence page.
  LicenseRegistry.addLicense(() async* {
    final ofl = await rootBundle.loadString('assets/fonts/OFL.txt');
    yield LicenseEntryWithLineBreaks(const ['Nunito'], ofl);
  });

  try {
    await SupabaseService.initialise();
  } catch (e) {
    // The app shows the setup screen instead of crashing.
    debugPrint('Supabase initialisation failed: $e');
  }
  await LocalNotificationService.instance.init();

  runApp(
    ProviderScope(
      // Show errors immediately instead of silently retrying in a loop;
      // every screen offers its own "Try again" button.
      retry: (_, _) => null,
      child: const GmiMindSpaceApp(),
    ),
  );
}
