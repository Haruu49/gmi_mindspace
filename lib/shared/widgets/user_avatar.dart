import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_theme.dart';
import '../models/user_profile.dart';

/// Circle avatar with the user's initials (no photo upload, by design –
/// keeps personal data to a minimum).
class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, required this.profile, this.radius = 24});

  final UserProfile? profile;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final initials = profile?.initials ?? '';
    return CircleAvatar(
      radius: radius,
      backgroundColor: context.colors.primaryContainer,
      foregroundColor: context.colors.onPrimaryContainer,
      child: initials.isEmpty
          ? Icon(Icons.person_rounded, size: radius)
          : Text(
              initials,
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: radius * 0.7),
            ),
    );
  }
}
