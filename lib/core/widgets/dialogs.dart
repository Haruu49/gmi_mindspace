import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';
import '../utils/failure.dart';

/// Asks the user to confirm an action. Returns `true` only on confirm.
///
/// For sensitive admin operations pass [typeToConfirm]; the confirm button
/// stays disabled until the user types that exact word.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool destructive = false,
  String? typeToConfirm,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (_) => _ConfirmDialog(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      destructive: destructive,
      typeToConfirm: typeToConfirm,
    ),
  );
  return result ?? false;
}

class _ConfirmDialog extends StatefulWidget {
  const _ConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.destructive,
    this.typeToConfirm,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final bool destructive;
  final String? typeToConfirm;

  @override
  State<_ConfirmDialog> createState() => _ConfirmDialogState();
}

class _ConfirmDialogState extends State<_ConfirmDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _canConfirm =>
      widget.typeToConfirm == null ||
      _controller.text.trim() == widget.typeToConfirm;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.message),
            if (widget.typeToConfirm != null) ...[
              AppSpacing.gapMd,
              Text('Type "${widget.typeToConfirm}" to continue.',
                  style: context.text.labelMedium),
              AppSpacing.gapXs,
              TextField(
                controller: _controller,
                autofocus: true,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(hintText: widget.typeToConfirm),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(widget.cancelLabel),
        ),
        FilledButton(
          style: widget.destructive
              ? FilledButton.styleFrom(
                  backgroundColor: scheme.error,
                  foregroundColor: scheme.onError,
                )
              : null,
          onPressed: _canConfirm ? () => Navigator.of(context).pop(true) : null,
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}

/// Asks for a short required reason (e.g. rejecting an appointment).
Future<String?> showReasonDialog(
  BuildContext context, {
  required String title,
  required String label,
  String confirmLabel = 'Submit',
  int maxLength = 300,
  bool required = true,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _ReasonDialog(
      title: title,
      label: label,
      confirmLabel: confirmLabel,
      maxLength: maxLength,
      required: required,
    ),
  );
}

class _ReasonDialog extends StatefulWidget {
  const _ReasonDialog({
    required this.title,
    required this.label,
    required this.confirmLabel,
    required this.maxLength,
    required this.required,
  });

  final String title;
  final String label;
  final String confirmLabel;
  final int maxLength;
  final bool required;

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          autofocus: true,
          maxLines: 4,
          minLines: 2,
          maxLength: widget.maxLength,
          decoration: InputDecoration(labelText: widget.label),
          validator: (v) {
            final t = v?.trim() ?? '';
            if (widget.required && t.length < 5) {
              return 'Please write at least 5 characters.';
            }
            return null;
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.of(context).pop(_controller.text.trim());
            }
          },
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}

/// Floating snackbar. Pass an error object to show a safe failure message.
void showAppSnack(BuildContext context, String message, {bool isError = false}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  final scheme = Theme.of(context).colorScheme;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? scheme.error : null,
      ),
    );
}

void showErrorSnack(BuildContext context, Object error) =>
    showAppSnack(context, AppFailure.from(error).message, isError: true);
