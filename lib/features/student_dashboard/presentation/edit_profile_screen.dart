import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/widgets.dart';
import '../../../shared/models/user_profile.dart';
import '../../authentication/presentation/auth_controller.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final UserProfile? _profile = ref.read(currentProfileProvider);
  late final _name = TextEditingController(text: _profile?.fullName);
  late final _studentId = TextEditingController(text: _profile?.studentId);
  late final _programme = TextEditingController(text: _profile?.programmeOfStudy);
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _studentId.dispose();
    _programme.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(authControllerProvider.notifier).updateProfile(
            fullName: _name.text,
            studentId: _studentId.text,
            programmeOfStudy: _programme.text,
          );
      if (!mounted) return;
      showAppSnack(context, 'Profile updated.');
      context.pop();
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isStudent = _profile?.role == AppRole.student;
    return Scaffold(
      appBar: AppBar(title: const Text('Edit profile')),
      body: Form(
        key: _formKey,
        child: PageBody(
          children: [
            AppTextField(
              controller: _name,
              label: 'Full name',
              prefixIcon: Icons.person_outline_rounded,
              textCapitalization: TextCapitalization.words,
              validator: Validators.fullName,
            ),
            if (isStudent) ...[
              AppSpacing.gapMd,
              AppTextField(
                controller: _studentId,
                label: 'Student ID',
                prefixIcon: Icons.badge_outlined,
                textCapitalization: TextCapitalization.characters,
                validator: Validators.studentId,
              ),
              AppSpacing.gapMd,
              AppTextField(
                controller: _programme,
                label: 'Programme of study (optional)',
                prefixIcon: Icons.school_outlined,
                maxLength: 120,
                validator: (v) => Validators.optionalText(v, maxLength: 120),
              ),
            ],
            AppSpacing.gapLg,
            AppButton(label: 'Save', isLoading: _saving, onPressed: _save),
          ],
        ),
      ),
    );
  }
}
