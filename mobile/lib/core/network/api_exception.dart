import 'package:dio/dio.dart';

import 'api_client.dart';

/// Kullanıcıya gösterilecek Türkçe mesajı taşıyan API hatası.
class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;

  /// API'nin döndürdüğü HTTP durum kodu; ağ ve biçim hatalarında `null`.
  final int? statusCode;

  @override
  String toString() => message;
}

/// [call] içindeki dio, biçim ve tip hatalarını [ApiException]'a çevirir.
/// [notFound]: 404 için gösterilecek mesaj.
Future<T> guardApi<T>(
  Future<T> Function() call, {
  required String notFound,
}) async {
  try {
    return await call();
  } on DioException catch (e) {
    throw ApiException(
      _messageFor(e, notFound),
      statusCode: e.response?.statusCode,
    );
  } on FormatException {
    throw const ApiException(_unexpectedResponse);
  } on TypeError {
    // Yanıt beklenen JSON biçiminde değil (eksik/yanlış tipte alan)
    throw const ApiException(_unexpectedResponse);
  }
}

const _unexpectedResponse = 'Sunucudan beklenmeyen bir yanıt alındı.';

String _messageFor(DioException e, String notFound) {
  final data = e.response?.data;
  switch (e.response?.statusCode) {
    case 400:
      return apiMessage(data) ?? 'İstek geçersiz.';
    case 401:
      return 'Oturumun süresi doldu. Lütfen yeniden giriş yapın.';
    case 403:
      return 'Bu işlem için yetkiniz yok.';
    case 404:
      return notFound;
    case 503:
      return apiMessage(data) ?? 'Hizmet şu anda kullanılamıyor.';
  }
  return describeApiError(e);
}

/// ProblemDetails veya `{ message }` gövdesindeki açıklama.
String? apiMessage(Object? data) {
  if (data is String) return data.trim().isEmpty ? null : data.trim();
  if (data is! Map) return null;
  for (final key in const ['message', 'detail']) {
    final value = data[key];
    if (value is String && value.trim().isNotEmpty) return value.trim();
  }
  return null;
}
