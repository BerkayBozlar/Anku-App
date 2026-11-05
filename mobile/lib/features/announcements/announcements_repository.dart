import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import 'announcement_models.dart';

/// `/api/announcements` okuma uç noktaları. Hatalar [ApiException] olarak döner.
class AnnouncementsRepository {
  AnnouncementsRepository(this._dio);

  final Dio _dio;

  static const _notFound = 'Duyuru bulunamadı. Kaldırılmış olabilir.';

  /// En yeni yayın tarihi önce gelir; [search] başlıkta aranır.
  Future<AnnouncementPage> list({
    int page = 1,
    int pageSize = 20,
    String? search,
  }) {
    return guardApi(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/announcements',
        queryParameters: {
          'page': page,
          'pageSize': pageSize,
          if (search != null && search.trim().isNotEmpty)
            'search': search.trim(),
        },
      );
      return AnnouncementPage.fromJson(response.data ?? const {});
    }, notFound: _notFound);
  }

  Future<Announcement> get(int id) {
    return guardApi(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/announcements/$id',
      );
      return Announcement.fromJson(response.data!);
    }, notFound: _notFound);
  }
}

final announcementsRepositoryProvider = Provider<AnnouncementsRepository>(
  (ref) => AnnouncementsRepository(ref.watch(dioProvider)),
);

final announcementDetailsProvider = FutureProvider.autoDispose
    .family<Announcement, int>(
      (ref, id) => ref.watch(announcementsRepositoryProvider).get(id),
      retry: (_, _) => null,
    );
