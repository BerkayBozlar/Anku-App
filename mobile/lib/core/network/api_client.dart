import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/session_controller.dart';
import '../config/app_config.dart';

/// AnkuApp.Api ile konuşan tek dio örneği.
final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: AppConfig.connectTimeout,
      receiveTimeout: AppConfig.receiveTimeout,
      headers: {'Accept': 'application/json'},
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final token = ref.read(sessionProvider).value?.accessToken;
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) {
        // Süresi dolmuş ya da geçersiz token: oturumu kapat, giriş ekranına dönülür
        final isAuthCall = error.requestOptions.path.startsWith('/api/auth/');
        if (error.response?.statusCode == 401 && !isAuthCall) {
          ref.read(sessionProvider.notifier).logout();
        }
        handler.next(error);
      },
    ),
  );

  ref.onDispose(dio.close);
  return dio;
});

/// Kullanıcıya gösterilecek kısa hata metni.
String describeApiError(Object error) {
  if (error is DioException) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return 'Sunucu zamanında yanıt vermedi.';
      case DioExceptionType.connectionError:
        return 'Sunucuya bağlanılamadı (${AppConfig.apiBaseUrl}).';
      case DioExceptionType.badResponse:
        return 'Sunucu hata döndürdü: ${error.response?.statusCode}.';
      default:
        return 'Beklenmeyen bir ağ hatası oluştu.';
    }
  }
  return 'Beklenmeyen bir hata oluştu.';
}
