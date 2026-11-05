import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import 'event_models.dart';

class EventsException implements Exception {
  const EventsException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// `/api/events` uç noktaları (docs/api-sozlesmesi.md). Hatalar
/// [EventsException] olarak, kullanıcıya gösterilecek Türkçe mesajla döner.
class EventsRepository {
  EventsRepository(this._dio);

  final Dio _dio;

  Future<EventPage> list({
    int page = 1,
    int pageSize = 20,
    String? search,
    int? clubId,
  }) {
    return _guard(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/events',
        queryParameters: {
          'page': page,
          'pageSize': pageSize,
          if (search != null && search.trim().isNotEmpty)
            'search': search.trim(),
          'clubId': ?clubId,
        },
      );
      return EventPage.fromJson(response.data ?? const {});
    });
  }

  Future<ClubEvent> get(int id) {
    return _guard(() async {
      final response = await _dio.get<Map<String, dynamic>>('/api/events/$id');
      return ClubEvent.fromJson(response.data!);
    });
  }

  Future<ClubEvent> create(EventInput input) {
    return _guard(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/events',
        data: input.toJson(),
      );
      return ClubEvent.fromJson(response.data!);
    });
  }

  /// API 204 döner; güncel hali için [get] çağrılmalı.
  Future<void> update(int id, EventInput input) {
    return _guard(
      () => _dio.put<void>('/api/events/$id', data: input.toJson()),
    );
  }

  Future<void> delete(int id) {
    return _guard(() => _dio.delete<void>('/api/events/$id'));
  }

  static Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on DioException catch (e) {
      throw EventsException(messageFor(e));
    }
  }

  static String messageFor(DioException e) {
    final data = e.response?.data;
    switch (e.response?.statusCode) {
      case 400:
        return _badRequestMessage(data) ?? 'Gönderilen bilgiler geçerli değil.';
      case 401:
        return 'Oturumun süresi doldu. Lütfen yeniden giriş yapın.';
      case 403:
        return 'Bu işlem için yetkiniz yok.';
      case 404:
        return 'Etkinlik bulunamadı. Silinmiş olabilir.';
      case 409:
        return _message(data) ??
            'Etkinliğe yapılmış başvurular olduğu için silinemiyor. '
                'Bunun yerine durumunu "İptal edildi" yapabilirsiniz.';
    }
    return describeApiError(e);
  }

  /// ProblemDetails `errors` alanından ilk hata; alan adına göre Türkçe mesaj.
  static String? _badRequestMessage(Object? data) {
    if (data is Map) {
      final errors = data['errors'];
      if (errors is Map) {
        for (final entry in errors.entries) {
          final messages = entry.value;
          if (messages is List && messages.isNotEmpty) {
            final key = entry.key.toString().replaceFirst(r'$.', '');
            return _fieldMessages[key.toLowerCase()] ??
                messages.first.toString();
          }
        }
      }
    }
    return _message(data);
  }

  static String? _message(Object? data) {
    if (data is String) return data.trim().isEmpty ? null : data.trim();
    if (data is! Map) return null;
    for (final key in const ['detail', 'message']) {
      final value = data[key];
      if (value is String && value.isNotEmpty) return value;
    }
    return null;
  }

  /// Model doğrulama hataları İngilizce dönebilir; alan adına göre Türkçe mesaj.
  static const _fieldMessages = {
    'title': 'Başlık zorunludur ve en fazla 200 karakter olabilir.',
    'eventdate': 'Etkinlik tarihi geçmişte olamaz.',
    'capacity': 'Kontenjan sıfırdan büyük olmalıdır.',
    'clubid': 'Geçerli bir kulüp seçin.',
    'campuslocationid': 'Seçilen kampüs konumu bulunamadı.',
    'status': 'Geçerli bir durum seçin.',
  };
}

final eventsRepositoryProvider = Provider<EventsRepository>(
  (ref) => EventsRepository(ref.watch(dioProvider)),
);
