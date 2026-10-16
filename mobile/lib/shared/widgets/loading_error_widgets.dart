import 'package:flutter/material.dart';

/// Widget hiển thị loading state toàn màn hình.
class LoadingWidget extends StatelessWidget {
  const LoadingWidget({super.key});

  @override
  Widget build(BuildContext context) => const Center(
        child: CircularProgressIndicator(),
      );
}

/// Widget hiển thị error state toàn màn hình.
class ErrorWidget extends StatelessWidget {
  const ErrorWidget({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              if (onRetry != null) ...[
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: onRetry,
                  child: const Text('Thử lại'),
                ),
              ],
            ],
          ),
        ),
      );
}
