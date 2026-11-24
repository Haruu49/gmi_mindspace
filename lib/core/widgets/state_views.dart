import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';
import '../utils/failure.dart';
import 'app_button.dart';

/// Centered spinner with an optional message.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(semanticsLabel: 'Loading'),
            if (message != null) ...[
              AppSpacing.gapMd,
              Text(message!, style: context.text.bodyMedium, textAlign: TextAlign.center),
            ],
          ],
        ),
      ),
    );
  }
}

/// Friendly empty state with an icon bubble and optional action.
class EmptyView extends StatelessWidget {
  const EmptyView({
    super.key,
    required this.title,
    this.message,
    this.icon = Icons.spa_outlined,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40, color: scheme.primary),
            ),
            AppSpacing.gapMd,
            Text(title, style: context.text.titleMedium, textAlign: TextAlign.center),
            if (message != null) ...[
              AppSpacing.gapXs,
              Text(
                message!,
                style: context.text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              AppSpacing.gapLg,
              AppButton(label: actionLabel!, onPressed: onAction, expand: false),
            ],
          ],
        ),
      ),
    );
  }
}

/// Error state with a retry button. Accepts any error and shows a safe,
/// friendly message via [AppFailure].
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.error, this.onRetry});

  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final failure = AppFailure.from(error);
    final icon = switch (failure.kind) {
      FailureKind.network => Icons.wifi_off_rounded,
      FailureKind.permission => Icons.lock_outline_rounded,
      FailureKind.sessionExpired => Icons.timer_off_outlined,
      _ => Icons.cloud_off_rounded,
    };
    return EmptyView(
      icon: icon,
      title: failure.kind == FailureKind.network
          ? 'No connection'
          : 'Something went wrong',
      message: failure.message,
      actionLabel: onRetry == null ? null : 'Try again',
      onAction: onRetry,
    );
  }
}

/// Renders an [AsyncValue] with consistent loading / error / empty states.
class AsyncValueView<T> extends StatelessWidget {
  const AsyncValueView({
    super.key,
    required this.value,
    required this.data,
    this.onRetry,
    this.isEmpty,
    this.empty,
    this.loadingMessage,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final VoidCallback? onRetry;
  final bool Function(T data)? isEmpty;
  final Widget? empty;
  final String? loadingMessage;

  @override
  Widget build(BuildContext context) {
    return value.when(
      skipLoadingOnRefresh: true,
      skipLoadingOnReload: true,
      data: (d) {
        if (empty != null && (isEmpty?.call(d) ?? false)) return empty!;
        return data(d);
      },
      loading: () => LoadingView(message: loadingMessage),
      error: (e, _) => ErrorView(error: e, onRetry: onRetry),
    );
  }
}
