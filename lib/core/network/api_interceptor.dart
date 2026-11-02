import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Добавляет технические заголовки и логирует ошибки для разработчика.
class ApiInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.headers['Accept'] = 'application/json';
    options.headers['X-Client'] = 'post-explorer-flutter';
    options.headers['X-Request-Id'] =
        DateTime.now().microsecondsSinceEpoch.toString();
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    debugPrint(
        '[ApiInterceptor] ${err.requestOptions.method} ${err.requestOptions.uri} '
        '-> ${err.type} ${err.response?.statusCode} ${err.message}');
    handler.next(err);
  }
}
