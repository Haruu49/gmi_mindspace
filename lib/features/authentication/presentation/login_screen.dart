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

/// Student and Counsellor login share this screen. After sign-in the router
/// sends each user to the dashboard for the role stored in the database.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, this.staffPortal = false});

  /// true = Counsellor / staff login.
  final bool staffPortal;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ref.read(authControllerProvider.notifier).signIn(
            email: _email.text,
            password: _password.text,
            staffPortal: widget.staffPortal,
          );
      // Router redirect takes over from here.
    } catch (e) {
      if (mounted) setState(() => _error = AppFailure.from(e).message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final staff = widget.staffPortal;
    return AuthScaffold(
      title: staff ? 'Counsellor Login' : 'Student Login',
      subtitle: staff
          ? 'For authorised GMI counsellors and staff.'
          : 'Welcome back. Take a breath — this is your space.',
      icon: staff ? Icons.volunteer_activism_rounded : Icons.school_rounded,
      accent: staff ? AppColors.sageDeep : null,
      children: [
        AutofillGroup(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppTextField(
                  key: const Key('login_email'),
                  controller: _email,
                  label: staff ? 'Staff email' : 'Student email',
                  hint: 'name@example.com',
                  prefixIcon: Icons.mail_outline_rounded,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  validator: Validators.email,
                  enabled: !_loading,
                ),
                AppSpacing.gapMd,
                AppTextField(
                  key: const Key('login_password'),
                  controller: _password,
                  label: 'Password',
                  prefixIcon: Icons.lock_outline_rounded,
                  isPassword: true,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  validator: Validators.loginPassword,
                  onFieldSubmitted: (_) => _submit(),
                  enabled: !_loading,
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: AppButton.text(
                    label: 'Forgot password?',
                    onPressed: _loading ? null : () => context.push(AppRoutes.forgotPassword),
                  ),
                ),
                AppSpacing.gapSm,
                FormErrorText(_error),
                AppButton(
                  key: const Key('login_submit'),
                  label: 'Sign in',
                  isLoading: _loading,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        ),
        AppSpacing.gapLg,
        if (!staff)
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('New to MindSpace?', style: context.text.bodyMedium),
              AppButton.text(
                label: 'Create an account',
                onPressed: _loading ? null : () => context.pushReplacement(AppRoutes.register),
              ),
            ],
          )
        else
          Text(
            'Counsellor accounts are created and approved by a GMI administrator.',
            style: context.text.bodySmall,
            textAlign: TextAlign.center,
          ),
      ],
    );
  }
}
