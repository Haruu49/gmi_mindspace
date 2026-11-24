import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/failure.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/widgets.dart';
import 'auth_controller.dart';
import 'widgets/auth_scaffold.dart';

/// Sends a password-reset e-mail. Always shows the same confirmation so the
/// screen cannot be used to discover which e-mails have accounts.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _loading = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ref.read(authControllerProvider.notifier).sendPasswordReset(_email.text);
      if (mounted) setState(() => _sent = true);
    } catch (e) {
      final f = AppFailure.from(e);
      // Only surface connectivity / rate-limit problems.
      if (mounted) {
        setState(() {
          if (f.kind == FailureKind.network || f.message.contains('Too many')) {
            _error = f.message;
          } else {
            _sent = true;
          }
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: _sent ? 'Check your inbox' : 'Forgot password',
      subtitle: _sent
          ? 'If an account exists for ${_email.text.trim()}, a reset link is on its '
              'way. Open it on this phone to choose a new password.'
          : 'Enter your email and we will send you a link to reset your password.',
      icon: _sent ? Icons.mark_email_read_outlined : Icons.key_rounded,
      children: [
        if (!_sent)
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppTextField(
                  key: const Key('forgot_email'),
                  controller: _email,
                  label: 'Email',
                  prefixIcon: Icons.mail_outline_rounded,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  validator: Validators.email,
                  onFieldSubmitted: (_) => _submit(),
                  enabled: !_loading,
                ),
                AppSpacing.gapLg,
                FormErrorText(_error),
                AppButton(label: 'Send reset link', isLoading: _loading, onPressed: _submit),
              ],
            ),
          )
        else
          AppButton.outline(
            label: 'Send again',
            onPressed: () => setState(() => _sent = false),
          ),
      ],
    );
  }
}

/// Shown after opening a password-reset link (AuthPasswordRecovery state).
class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ref.read(authControllerProvider.notifier).setNewPassword(_password.text);
    } catch (e) {
      if (mounted) setState(() => _error = AppFailure.from(e).message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Choose a new password',
      subtitle: 'Pick something you have not used before.',
      icon: Icons.lock_reset_rounded,
      children: [
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTextField(
                controller: _password,
                label: 'New password',
                helper: 'At least 8 characters with a letter and a number.',
                isPassword: true,
                textInputAction: TextInputAction.next,
                validator: Validators.newPassword,
                enabled: !_loading,
              ),
              AppSpacing.gapMd,
              AppTextField(
                controller: _confirm,
                label: 'Confirm new password',
                isPassword: true,
                textInputAction: TextInputAction.done,
                validator: Validators.confirmPassword(() => _password.text),
                onFieldSubmitted: (_) => _submit(),
                enabled: !_loading,
              ),
              AppSpacing.gapLg,
              FormErrorText(_error),
              AppButton(label: 'Save password', isLoading: _loading, onPressed: _submit),
              AppSpacing.gapSm,
              AppButton.text(
                label: 'Cancel and sign out',
                onPressed: _loading
                    ? null
                    : () => ref.read(authControllerProvider.notifier).signOut(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
