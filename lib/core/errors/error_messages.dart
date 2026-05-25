import 'app_exception.dart';
import 'auth_error_mapper.dart';

String userFacingErrorMessage(Object error) {
  if (error is AppException) {
    return error.message;
  }
  if (AuthErrorMapper.canMap(error)) {
    return AuthErrorMapper.toAppException(error).message;
  }
  return 'Something went wrong. Please try again.';
}
