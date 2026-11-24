import 'package:material_ui/material_ui.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';

/// Plain-language privacy information. Every statement here is enforced by
/// database Row Level Security, not just by the app.
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  static const _points = <(IconData, String, String)>[
    (Icons.menu_book_rounded, 'Your journal is yours alone',
        'Only you can read your journal entries. Counsellors and administrators '
            'cannot open them through MindSpace.'),
    (Icons.mood_rounded, 'Mood check-ins are private by default',
        'Your moods and notes are visible only to you. You may choose to share a '
            'summary (counts only, never your notes) with a counsellor, and you can '
            'stop sharing at any time.'),
    (Icons.event_available_rounded, 'Appointments',
        'Only you and the counsellor assigned to your appointment can see it. '
            'Counsellor session notes are kept separately and are never shown in lists.'),
    (Icons.admin_panel_settings_outlined, 'Administrators',
        'Administrators manage accounts and settings. They do not have access to '
            'your journal, mood records or counselling notes. Their actions are '
            'recorded in an audit log.'),
    (Icons.notifications_none_rounded, 'Notifications',
        'Notifications use general wording, so nothing private appears on your '
            'lock screen. You can turn optional notifications off.'),
    (Icons.lock_outline_rounded, 'Security',
        'Data travels over encrypted connections (HTTPS) and is stored on '
            'encrypted servers. Never share your password.'),
    (Icons.psychology_alt_outlined, 'No diagnosis',
        'MindSpace does not diagnose, score or predict anyone\'s mental health. '
            'It is a space for reflection and for finding support.'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Your privacy')),
      body: PageBody(
        children: [
          Text('How MindSpace protects you', style: context.text.headlineSmall),
          AppSpacing.gapXs,
          Text(
            'We designed ${AppConstants.appName} so you stay in control of what you share.',
            style: context.text.bodyLarge?.copyWith(color: context.colors.onSurfaceVariant),
          ),
          AppSpacing.gapLg,
          for (final (icon, title, body) in _points) ...[
            AppCard(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconBubble(icon: icon),
                  AppSpacing.gapMd,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: context.text.titleSmall),
                        AppSpacing.gapXxs,
                        Text(body, style: context.text.bodyMedium),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            AppSpacing.gapSm,
          ],
          AppSpacing.gapSm,
          InfoBanner(
            title: 'Not an emergency service',
            message: AppConstants.notMonitoredNotice,
            icon: Icons.warning_amber_rounded,
            color: context.colors.error,
          ),
        ],
      ),
    );
  }
}
