import 'dart:async';
import 'dart:io';

import 'app_exception.dart';
import 'auth_error_mapper.dart';
import '../network/network_providers.dart';

String userFacingErrorMessage(Object error) {
  if (error is OfflineException) {
    return noInternetMessage;
  }
  if (error is AppException) {
    return error.message;
  }
  if (AuthErrorMapper.canMap(error)) {
    return AuthErrorMapper.toAppException(error).message;
  }
  if (error is SocketException || error is TimeoutException) {
    return 'Unable to connect to the server. Please check your internet connection.';
  }
  return 'Something went wrong. Please try again.';
}
