import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import 'auth_models.dart';

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AuthRepository {
  AuthRepository(this._dio);

  final Dio _dio;

  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/auth/login',
        data: {'email': email, 'password': password},
      );
      return AuthSession.fromJson(response.data!);
    } on DioException catch (e) {
      throw AuthException(
        _messageFor(e, unauthorized: 'E-posta veya parola hatalı.'),
      );
    }
  }

  /// Yalnızca öğrenci hesabı açar; yönetici ve kulüp yetkilisi rolleri sistemden atanır.
  /// Yanıtta oturum dönmez, ardından [login] çağrılmalıdır.
  Future<void> register({
    required String fullName,
    required String email,
    required String password,
  }) async {
    try {
      await _dio.post<Object>(
        '/api/auth/register',
        data: {'fullName': fullName, 'email': email, 'password': password},
      );
    } on DioException catch (e) {
      throw AuthException(
        _messageFor(e, conflict: 'Bu e-posta adresi zaten kayıtlı.'),
      );
    }
  }

  static String _messageFor(
    DioException e, {
    String? unauthorized,
    String? conflict,
  }) {
    final status = e.response?.statusCode;
    if (status == 401 && unauthorized != null) return unauthorized;
    if (status == 409 && conflict != null) return conflict;
    if (status == 400) {
      return _badRequestMessage(e.response?.data) ??
          'Gönderilen bilgiler geçerli değil.';
    }
    return describeApiError(e);
  }

  /// API'nin 400 gövdeleri: düz metin, Identity hata listesi
  /// (`[{code, description}]`) ya da ProblemDetails.
  static String? _badRequestMessage(Object? data) {
    if (data is String) return data.trim().isEmpty ? null : data.trim();
    if (data is List) {
      for (final error in data) {
        if (error is Map) {
          final message =
              _identityMessages[error['code']] ?? error['description'];
          if (message is String && message.isNotEmpty) return message;
        }
      }
      return null;
    }
    if (data is! Map) return null;
    final errors = data['errors'];
    if (errors is Map) {
      for (final entry in errors.entries) {
        final messages = entry.value;
        if (messages is List && messages.isNotEmpty) {
          return _fieldMessages[entry.key.toString().toLowerCase()] ??
              messages.first.toString();
        }
      }
    }
    for (final key in const ['detail', 'message']) {
      final value = data[key];
      if (value is String && value.isNotEmpty) return value;
    }
    return null;
  }

  /// ASP.NET Core Identity hata kodlarının Türkçesi.
  static const _identityMessages = {
    'DuplicateEmail': 'Bu e-posta adresi zaten kayıtlı.',
    'DuplicateUserName': 'Bu e-posta adresi zaten kayıtlı.',
    'InvalidEmail': 'Geçerli bir e-posta adresi girin.',
    'PasswordTooShort': 'Parola en az 8 karakter olmalıdır.',
    'PasswordRequiresUpper': 'Parola en az bir büyük harf içermelidir.',
    'PasswordRequiresLower': 'Parola en az bir küçük harf içermelidir.',
    'PasswordRequiresDigit': 'Parola en az bir rakam içermelidir.',
    'PasswordRequiresNonAlphanumeric':
        'Parola en az bir özel karakter (! . * gibi) içermelidir.',
  };

  /// Model doğrulama hataları İngilizce döner; alan adına göre Türkçe mesaj.
  static const _fieldMessages = {
    'fullname': 'Ad soyad zorunludur.',
    'email': 'Geçerli bir e-posta adresi girin.',
    'password': 'Parola en az 8 karakter olmalıdır.',
  };
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(dioProvider)),
);
