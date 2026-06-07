import 'package:firedart/auth/exceptions.dart' as fd_auth;

import 'app_exception.dart';

class AuthErrorMapper {
  const AuthErrorMapper._();

  static bool canMap(Object error) {
    return error is fd_auth.AuthException ||
        error is fd_auth.SignedOutException;
  }

  static AppException toAppException(Object error) {
    if (error is fd_auth.AuthException) {
      return AppException(messageForCode(_safeErrorCode(error)));
    }
    if (error is fd_auth.SignedOutException) {
      return const AppException(
        'Your session has expired. Please sign in again.',
      );
    }
    if (error is AppException) {
      return error;
    }
    return const AppException('Authentication failed. Please try again.');
  }

  static String messageForCode(String code) {
    switch (_normalize(code)) {
      case 'INVALID_EMAIL':
        return 'Please enter a valid email address.';
      case 'EMAIL_NOT_FOUND':
      case 'USER_NOT_FOUND':
        return 'No account was found with this email address.';
      case 'INVALID_PASSWORD':
      case 'WRONG_PASSWORD':
        return 'Incorrect password.';
      case 'INVALID_LOGIN_CREDENTIALS':
        return 'Email or password is incorrect.';
      case 'EMAIL_EXISTS':
        return 'An account already exists with this email.';
      case 'USER_DISABLED':
        return 'This account has been disabled.';
      case 'WEAK_PASSWORD':
        return 'Use a stronger password.';
      case 'TOO_MANY_ATTEMPTS_TRY_LATER':
        return 'Too many login attempts. Please try again later.';
      case 'NETWORK_REQUEST_FAILED':
      case 'TIMEOUT':
      case 'UNAVAILABLE':
        return 'Unable to connect to the server. Please check your internet connection.';
      case 'TOKEN_EXPIRED':
      case 'INVALID_ID_TOKEN':
      case 'INVALID_REFRESH_TOKEN':
      case 'USER_TOKEN_EXPIRED':
        return 'Your session has expired. Please sign in again.';
      case 'MISSING_PASSWORD':
        return 'Enter your password.';
      case 'MISSING_EMAIL':
        return 'Enter your email address.';
      default:
        return 'Authentication failed. Please try again.';
    }
  }

  static String _safeErrorCode(fd_auth.AuthException error) {
    try {
      return error.errorCode;
    } catch (_) {
      return '';
    }
  }

  static String _normalize(String code) {
    return code.trim().toUpperCase().replaceAll('-', '_');
  }
}
