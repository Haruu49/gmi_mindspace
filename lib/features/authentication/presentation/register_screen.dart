import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/failure.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/widgets.dart';
import 'auth_controller.dart';
import 'widgets/auth_scaffold.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _studentId = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _agreed = false;
  bool _loading = false;
  String? _error;
  bool _checkEmail = false;

  @override
  void dispose() {
    for (final c in [_name, _studentId, _email, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;
    if (!_agreed) {
      setState(() => _error = 'Please confirm you have read how we protect your privacy.');
      return;
    }
    setState(() => _loading = true);
    try {
      final needsConfirmation = await ref.read(authControllerProvider.notifier).registerStudent(
            fullName: _name.text,
            studentId: _studentId.text,
            email: _email.text,
            password: _password.text,
          );
      if (mounted && needsConfirmation) setState(() => _checkEmail = true);
    } catch (e) {
      if (mounted) setState(() => _error = AppFailure.from(e).message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checkEmail) {
      return AuthScaffold(
        title: 'Check your email',
        subtitle: 'We sent a confirmation link to ${_email.text.trim()}. '
            'Open it on this phone, then sign in.',
        icon: Icons.mark_email_read_outlined,
        children: [
          AppButton(
            label: 'Go to Student Login',
            onPressed: () => context.pushReplacement(AppRoutes.studentLogin),
          ),
        ],
      );
    }

    return AuthScaffold(
      title: 'Create your account',
      subtitle: 'Your space to check in, reflect and find support at your own pace.',
      children: [
        Form(
          key: _formKey,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppTextField(
                  key: const Key('register_name'),
                  controller: _name,
                  label: 'Full name',
                  prefixIcon: Icons.person_outline_rounded,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.name],
                  validator: Validators.fullName,
                  enabled: !_loading,
                ),
                AppSpacing.gapMd,
                AppTextField(
                  key: const Key('register_student_id'),
                  controller: _studentId,
                  label: 'Student ID',
                  prefixIcon: Icons.badge_outlined,
                  textCapitalization: TextCapitalization.characters,
                  textInputAction: TextInputAction.next,
                  validator: Validators.studentId,
                  enabled: !_loading,
                ),
                AppSpacing.gapMd,
                AppTextField(
                  key: const Key('register_email'),
                  controller: _email,
                  label: 'Student email',
                  prefixIcon: Icons.mail_outline_rounded,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  validator: Validators.studentEmail,
                  enabled: !_loading,
                ),
                AppSpacing.gapMd,
                AppTextField(
                  key: const Key('register_password'),
                  controller: _password,
                  label: 'Password',
                  helper: 'At least 8 characters with a letter and a number.',
                  prefixIcon: Icons.lock_outline_rounded,
                  isPassword: true,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.newPassword],
                  validator: Validators.newPassword,
                  enabled: !_loading,
                ),
                AppSpacing.gapMd,
                AppTextField(
                  key: const Key('register_confirm'),
                  controller: _confirm,
                  label: 'Confirm password',
                  prefixIcon: Icons.lock_outline_rounded,
                  isPassword: true,
                  textInputAction: TextInputAction.done,
                  validator: Validators.confirmPassword(() => _password.text),
                  onFieldSubmitted: (_) => _submit(),
                  enabled: !_loading,
                ),
                AppSpacing.gapSm,
                CheckboxListTile(
                  key: const Key('register_privacy'),
                  value: _agreed,
                  onChanged: _loading ? null : (v) => setState(() => _agreed = v ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'I have read how MindSpace protects my privacy.',
                    style: context.text.bodyMedium,
                  ),
                  subtitle: GestureDetector(
                    onTap: () => context.push(AppRoutes.privacy),
                    child: Text(
                      'Read privacy information',
                      style: context.text.bodySmall?.copyWith(
                        color: context.colors.primary,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
                AppSpacing.gapSm,
                FormErrorText(_error),
                AppButton(
                  key: const Key('register_submit'),
                  label: 'Create account',
                  isLoading: _loading,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        ),
        AppSpacing.gapMd,
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text('Already registered?', style: context.text.bodyMedium),
            AppButton.text(
              label: 'Sign in',
              onPressed: _loading ? null : () => context.pushReplacement(AppRoutes.studentLogin),
            ),
          ],
        ),
      ],
    );
  }
}
