import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'api_interceptor.dart';

/// Единственный экземпляр Dio на всё приложение.
class DioClient {
  DioClient({Dio? dio, String baseUrl = defaultBaseUrl})
      : dio = dio ??
            Dio(BaseOptions(
              baseUrl: baseUrl,
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 10),
              sendTimeout: const Duration(seconds: 10),
            )) {
    this.dio.interceptors.addAll([
      ApiInterceptor(),
      LogInterceptor(
        requestBody: true,
        responseBody: false,
        logPrint: (o) => debugPrint(o.toString()),
      ),
    ]);
  }

  static const defaultBaseUrl = 'https://jsonplaceholder.typicode.com';

  final Dio dio;
}
