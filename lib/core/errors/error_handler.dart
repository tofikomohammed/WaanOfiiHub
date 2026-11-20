import 'package:flutter/material.dart';

import 'app_exception.dart';

/// Utility class for catching and presenting application errors to users.
class ErrorHandler {
  ErrorHandler._();

  /// Formats an error into a user-friendly string message.
  static String getUserMessage(dynamic error) {
    if (error is AppException) {
      return error.message;
    }
    return AppException.from(error).message;
  }

  /// Displays a SnackBar with an error message and optional retry action.
  static void showSnackBar(
    BuildContext context,
    dynamic error, {
    VoidCallback? onRetry,
  }) {
    final message = getUserMessage(error);
    final scaffoldMessenger = ScaffoldMessenger.maybeOf(context);
    if (scaffoldMessenger == null) return;

    scaffoldMessenger.removeCurrentSnackBar();
    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
        action: onRetry != null
            ? SnackBarAction(
                label: 'Retry',
                textColor: Colors.white,
                onPressed: onRetry,
              )
            : null,
      ),
    );
  }
}
