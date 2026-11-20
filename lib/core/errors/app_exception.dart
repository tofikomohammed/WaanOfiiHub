import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart' as sb;

/// Base application exception with user-friendly error messages and technical details.
class AppException implements Exception {
  final String message;
  final String? code;
  final dynamic technicalDetails;
  final StackTrace? stackTrace;

  const AppException(
    this.message, {
    this.code,
    this.technicalDetails,
    this.stackTrace,
  });

  @override
  String toString() =>
      'AppException(code: $code, message: $message, details: $technicalDetails)';

  /// Creates a typed [AppException] from any caught error.
  factory AppException.from(dynamic error, [StackTrace? stackTrace]) {
    if (error is AppException) {
      return error;
    }

    if (error is sb.AuthException) {
      return AuthException(
        error.message,
        technicalDetails: error,
        stackTrace: stackTrace,
      );
    }

    if (error is sb.PostgrestException) {
      return AppException(
        error.message,
        code: error.code,
        technicalDetails: error,
        stackTrace: stackTrace,
      );
    }

    if (error is SocketException || error is TimeoutException) {
      return NetworkException(
        'Unable to connect to the server. Please check your internet connection.',
        technicalDetails: error,
        stackTrace: stackTrace,
      );
    }

    final errorStr = error.toString();
    if (errorStr.contains('Failed host lookup') ||
        errorStr.contains('Failed to fetch') ||
        errorStr.contains('ClientException')) {
      return NetworkException(
        'Unable to reach Supabase backend. Please check your network and Supabase URL.',
        technicalDetails: error,
        stackTrace: stackTrace,
      );
    }

    if (errorStr.contains('JWT') ||
        errorStr.contains('Invalid login credentials')) {
      return AuthException(
        'Authentication failed. Please check your credentials.',
        technicalDetails: error,
        stackTrace: stackTrace,
      );
    }

    if (errorStr.contains('permission denied') ||
        errorStr.contains('not authorized')) {
      return PermissionException(
        'You do not have permission to perform this action.',
        technicalDetails: error,
        stackTrace: stackTrace,
      );
    }

    return UnknownException(
      errorStr.replaceFirst(RegExp(r'^Exception: '), ''),
      technicalDetails: error,
      stackTrace: stackTrace,
    );
  }
}

class NetworkException extends AppException {
  const NetworkException(
    super.message, {
    super.code = 'NETWORK_ERROR',
    super.technicalDetails,
    super.stackTrace,
  });
}

class AuthException extends AppException {
  const AuthException(
    super.message, {
    super.code = 'AUTH_ERROR',
    super.technicalDetails,
    super.stackTrace,
  });
}

class PermissionException extends AppException {
  const PermissionException(
    super.message, {
    super.code = 'PERMISSION_DENIED',
    super.technicalDetails,
    super.stackTrace,
  });
}

class NotFoundException extends AppException {
  const NotFoundException(
    super.message, {
    super.code = 'NOT_FOUND',
    super.technicalDetails,
    super.stackTrace,
  });
}

class ValidationException extends AppException {
  const ValidationException(
    super.message, {
    super.code = 'VALIDATION_ERROR',
    super.technicalDetails,
    super.stackTrace,
  });
}

class ConfigurationException extends AppException {
  const ConfigurationException(
    super.message, {
    super.code = 'CONFIG_ERROR',
    super.technicalDetails,
    super.stackTrace,
  });
}

class UnknownException extends AppException {
  const UnknownException(
    super.message, {
    super.code = 'UNKNOWN_ERROR',
    super.technicalDetails,
    super.stackTrace,
  });
}
