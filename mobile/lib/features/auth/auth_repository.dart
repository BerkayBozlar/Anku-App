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
  Future<AuthUser> register({
    required String fullName,
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/auth/register',
        data: {'fullName': fullName, 'email': email, 'password': password},
      );
      return AuthUser.fromJson(response.data!);
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
      return _problemMessage(e.response?.data) ??
          'Gönderilen bilgiler geçerli değil.';
    }
    return describeApiError(e);
  }

  /// ProblemDetails gövdesinden ilk alan hatasını ya da `detail` metnini alır.
  static String? _problemMessage(Object? data) {
    if (data is! Map) return null;
    final errors = data['errors'];
    if (errors is Map) {
      for (final messages in errors.values) {
        if (messages is List && messages.isNotEmpty) {
          return messages.first.toString();
        }
      }
    }
    final detail = data['detail'];
    return detail is String && detail.isNotEmpty ? detail : null;
  }
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(dioProvider)),
);
