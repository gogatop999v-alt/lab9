import 'package:dio/dio.dart';

/// Единая иерархия ошибок приложения. UI показывает [userMessage],
/// технические детали ([technical]) попадают только в логи.
sealed class AppException implements Exception {
  const AppException(this.userMessage, {this.technical});

  final String userMessage;
  final String? technical;

  @override
  String toString() => '$runtimeType: ${technical ?? userMessage}';

  factory AppException.fromDio(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return RequestTimeoutException(technical: e.message);
      case DioExceptionType.connectionError:
        return NoConnectionException(technical: e.message);
      case DioExceptionType.badResponse:
        final code = e.response?.statusCode ?? 0;
        if (code >= 500) {
          return ServerErrorException(code, technical: e.message);
        }
        if (code >= 400) {
          return ClientErrorException(code, technical: e.message);
        }
        return UnknownException(technical: e.message);
      case DioExceptionType.badCertificate:
      case DioExceptionType.cancel:
      case DioExceptionType.unknown:
        final err = e.error;
        if (err is FormatException || err is TypeError) {
          return ParseException(technical: err.toString());
        }
        if (err.toString().contains('SocketException')) {
          return NoConnectionException(technical: err.toString());
        }
        return UnknownException(technical: e.toString());
    }
  }
}

class NoConnectionException extends AppException {
  const NoConnectionException({String? technical})
      : super('Нет подключения к интернету. Проверьте соединение.',
            technical: technical);
}

class RequestTimeoutException extends AppException {
  const RequestTimeoutException({String? technical})
      : super('Сервер слишком долго отвечает. Попробуйте ещё раз.',
            technical: technical);
}

class ClientErrorException extends AppException {
  ClientErrorException(this.statusCode, {String? technical})
      : super(
          statusCode == 404
              ? 'Данные не найдены.'
              : 'Не удалось выполнить запрос (код $statusCode).',
          technical: technical,
        );
  final int statusCode;
}

class ServerErrorException extends AppException {
  ServerErrorException(this.statusCode, {String? technical})
      : super('Сервер временно недоступен (код $statusCode). Попробуйте позже.',
            technical: technical);
  final int statusCode;
}

class ParseException extends AppException {
  const ParseException({String? technical})
      : super('Сервер вернул некорректные данные.', technical: technical);
}

class UnknownException extends AppException {
  const UnknownException({String? technical})
      : super('Что-то пошло не так. Попробуйте ещё раз.', technical: technical);
}
