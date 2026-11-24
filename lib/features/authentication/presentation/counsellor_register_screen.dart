import 'dart:async';

import 'package:flutter/services.dart';
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

/// Counsellor self sign-up in two steps: details, then the 6-digit code that
/// is e-mailed to the counsellor. The database grants the counsellor role
/// once the code is accepted; this screen never decides a role.
class CounsellorRegisterScreen extends ConsumerStatefulWidget {
  const CounsellorRegisterScreen({super.key});

  @override
  ConsumerState<CounsellorRegisterScreen> createState() => _CounsellorRegisterScreenState();
}

class _CounsellorRegisterScreenState extends ConsumerState<CounsellorRegisterScreen> {
  static const _resendCooldownSeconds = 60;

  final _formKey = GlobalKey<FormState>();
  final _codeFormKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _staffId = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _code = TextEditingController();

  bool _loading = false;
  bool _awaitingCode = false;
  String? _error;
  String? _info;
  int _cooldown = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in [_name, _staffId, _email, _password, _confirm, _code]) {
      c.dispose();
    }
    super.dispose();
  }

  void _startCooldown() {
    _timer?.cancel();
    setState(() => _cooldown = _resendCooldownSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted || _cooldown <= 1) {
        t.cancel();
        if (mounted) setState(() => _cooldown = 0);
        return;
      }
      setState(() => _cooldown--);
    });
  }

  Future<void> _submitDetails() async {
    if (_loading) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _error = null;
      _info = null;
    });
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ref.read(authControllerProvider.notifier).registerCounsellor(
            fullName: _name.text,
            staffId: _staffId.text,
            email: _email.text,
            password: _password.text,
          );
      if (!mounted) return;
      setState(() => _awaitingCode = true);
      _startCooldown();
    } catch (e) {
      if (mounted) setState(() => _error = AppFailure.from(e).message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verify() async {
    if (_loading) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _error = null;
      _info = null;
    });
    if (!_codeFormKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ref.read(authControllerProvider.notifier).verifyCounsellorCode(
            email: _email.text,
            code: _code.text,
          );
      // On success the router sends the new counsellor to their dashboard.
    } catch (e) {
      if (mounted) setState(() => _error = AppFailure.from(e).message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    if (_loading || _cooldown > 0) return;
    setState(() {
      _loading = true;
      _error = null;
      _info = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).resendCounsellorCode(_email.text);
      if (!mounted) return;
      setState(() => _info = 'A new code is on its way.');
      _startCooldown();
    } catch (e) {
      if (mounted) setState(() => _error = AppFailure.from(e).message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _awaitingCode ? _buildCodeStep(context) : _buildDetailsStep(context);
  }

  Widget _buildDetailsStep(BuildContext context) {
    return AuthScaffold(
      title: 'Counsellor sign-up',
      subtitle: 'For GMI counsellors. We will email you a code to confirm it is you.',
      icon: Icons.volunteer_activism_rounded,
      accent: AppColors.sageDeep,
      children: [
        Form(
          key: _formKey,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppTextField(
                  key: const Key('counsellor_register_name'),
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
                  key: const Key('counsellor_register_staff_id'),
                  controller: _staffId,
                  label: 'Staff ID',
                  prefixIcon: Icons.badge_outlined,
                  textCapitalization: TextCapitalization.characters,
                  textInputAction: TextInputAction.next,
                  validator: Validators.staffId,
                  enabled: !_loading,
                ),
                AppSpacing.gapMd,
                AppTextField(
                  key: const Key('counsellor_register_email'),
                  controller: _email,
                  label: 'Counsellor email',
                  hint: 'name@gmi.edu.my',
                  prefixIcon: Icons.mail_outline_rounded,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  validator: Validators.counsellorEmail,
                  enabled: !_loading,
                ),
                AppSpacing.gapMd,
                AppTextField(
                  key: const Key('counsellor_register_password'),
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
                  key: const Key('counsellor_register_confirm'),
                  controller: _confirm,
                  label: 'Confirm password',
                  prefixIcon: Icons.lock_outline_rounded,
                  isPassword: true,
                  textInputAction: TextInputAction.done,
                  validator: Validators.confirmPassword(() => _password.text),
                  onFieldSubmitted: (_) => _submitDetails(),
                  enabled: !_loading,
                ),
                AppSpacing.gapMd,
                FormErrorText(_error),
                AppButton(
                  key: const Key('counsellor_register_submit'),
                  label: 'Send me a code',
                  isLoading: _loading,
                  onPressed: _submitDetails,
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
              onPressed: _loading ? null : () => context.pushReplacement(AppRoutes.counsellorLogin),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCodeStep(BuildContext context) {
    return AuthScaffold(
      title: 'Check your email',
      subtitle: 'We sent a 6-digit code to ${_email.text.trim()}. '
          'Enter it below to finish signing up.',
      icon: Icons.mark_email_read_outlined,
      accent: AppColors.sageDeep,
      children: [
        Form(
          key: _codeFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTextField(
                key: const Key('counsellor_code'),
                controller: _code,
                label: '6-digit code',
                prefixIcon: Icons.pin_outlined,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                maxLength: 6,
                validator: Validators.verificationCode,
                onFieldSubmitted: (_) => _verify(),
                enabled: !_loading,
              ),
              AppSpacing.gapSm,
              if (_info != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(_info!, style: context.text.bodySmall, textAlign: TextAlign.center),
                ),
              FormErrorText(_error),
              AppButton(
                key: const Key('counsellor_code_submit'),
                label: 'Verify and continue',
                isLoading: _loading,
                onPressed: _verify,
              ),
            ],
          ),
        ),
        AppSpacing.gapSm,
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            AppButton.text(
              key: const Key('counsellor_code_resend'),
              label: _cooldown > 0 ? 'Resend code (${_cooldown}s)' : 'Resend code',
              onPressed: (_loading || _cooldown > 0) ? null : _resend,
            ),
            AppButton.text(
              label: 'Use a different email',
              onPressed: _loading
                  ? null
                  : () => setState(() {
                        _awaitingCode = false;
                        _error = null;
                        _info = null;
                      }),
            ),
          ],
        ),
      ],
    );
  }
}
