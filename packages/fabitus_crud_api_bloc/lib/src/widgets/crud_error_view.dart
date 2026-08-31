import 'package:fabitus_crud_api/fabitus_crud_api.dart';
import 'package:flutter/material.dart';

/// The default rendering of a [CrudException].
///
/// Deliberately plain: this package ships no design system, so it uses the
/// ambient [TextTheme] and [ColorScheme] and nothing else. Replace it with your
/// own through the `onError` argument of [LoadBuilder], or use it as the body of
/// that replacement.
///
/// Validation failures list their field errors, because "please check the
/// highlighted fields" is useless on a screen with no highlighting.
class CrudErrorView extends StatelessWidget {
  /// Shows [error], with a retry button when [onRetry] is given.
  const CrudErrorView({required this.error, this.onRetry, super.key});

  /// What went wrong.
  final CrudException error;

  /// Called when the user asks to try again. No button is shown without it.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: theme.colorScheme.error, size: 32),
            const SizedBox(height: 12),
            Text(error.message, style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
            if (error.violations.isNotEmpty) ...[
              const SizedBox(height: 8),
              for (final violation in error.violations)
                Text(
                  '$violation',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                  textAlign: TextAlign.center,
                ),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
            ],
          ],
        ),
      ),
    );
  }
}
