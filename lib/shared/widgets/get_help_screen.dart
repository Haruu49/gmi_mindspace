import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/emergency_contacts.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/widgets.dart';

/// "Get Help Now" – reachable from every screen, signed in or not.
class GetHelpScreen extends StatelessWidget {
  const GetHelpScreen({super.key});

  Future<void> _call(BuildContext context, String number) async {
    final uri = Uri(scheme: 'tel', path: number);
    final ok = await canLaunchUrl(uri) && await launchUrl(uri);
    if (!ok && context.mounted) {
      showAppSnack(context, 'Please dial $number from your phone.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return Scaffold(
      appBar: AppBar(title: const Text('Get Help Now')),
      body: PageBody(
        children: [
          AppCard(
            color: scheme.errorContainer,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.emergency_rounded, color: scheme.error, size: 28),
                    AppSpacing.gapSm,
                    Expanded(
                      child: Text(
                        'In immediate danger?',
                        style: context.text.titleLarge?.copyWith(color: scheme.onErrorContainer),
                      ),
                    ),
                  ],
                ),
                AppSpacing.gapXs,
                Text(
                  'If you or someone else might be harmed, call 999 now or go to the '
                  'nearest hospital emergency department.',
                  style: context.text.bodyLarge?.copyWith(color: scheme.onErrorContainer),
                ),
                AppSpacing.gapMd,
                AppButton.danger(
                  label: 'Call 999',
                  icon: Icons.call_rounded,
                  onPressed: () => _call(context, '999'),
                ),
              ],
            ),
          ),
          AppSpacing.gapMd,
          const InfoBanner(message: AppConstants.notMonitoredNotice),
          const SectionHeader(title: 'Talk to someone'),
          for (final c in EmergencyContacts.all.where((c) => c.phone != '999')) ...[
            _ContactCard(contact: c, onCall: c.phone == null ? null : () => _call(context, c.phone!)),
            AppSpacing.gapSm,
          ],
          const SectionHeader(title: 'Right now, you could'),
          const _Tip(icon: Icons.air_rounded, text: 'Breathe slowly: in for 4, hold for 4, out for 6.'),
          const _Tip(icon: Icons.people_alt_outlined, text: 'Reach out to someone you trust and tell them how you feel.'),
          const _Tip(icon: Icons.place_outlined, text: 'Move to a safe, calm place with other people nearby.'),
        ],
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  const _ContactCard({required this.contact, this.onCall});

  final EmergencyContact contact;
  final VoidCallback? onCall;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          IconBubble(
            icon: contact.isEmergency ? Icons.emergency_outlined : Icons.support_agent_rounded,
            color: contact.isEmergency ? context.colors.error : context.colors.primary,
          ),
          AppSpacing.gapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(contact.name, style: context.text.titleSmall),
                Text(contact.description, style: context.text.bodySmall),
                AppSpacing.gapXxs,
                Text(contact.availability, style: context.text.labelSmall),
              ],
            ),
          ),
          if (onCall != null)
            IconButton.filledTonal(
              tooltip: 'Call ${contact.name}',
              onPressed: onCall,
              icon: const Icon(Icons.call_rounded),
            ),
        ],
      ),
    );
  }
}

class _Tip extends StatelessWidget {
  const _Tip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          IconBubble(icon: icon, color: AppColors.sageDeep, size: 38),
          AppSpacing.gapSm,
          Expanded(child: Text(text, style: context.text.bodyMedium)),
        ],
      ),
    );
  }
}
