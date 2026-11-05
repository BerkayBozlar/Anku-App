import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import 'club_models.dart';

class ClubsRepository {
  ClubsRepository(this._dio);

  final Dio _dio;

  Future<List<Club>> list() async {
    final response = await _dio.get<List<dynamic>>('/api/clubs');
    return [
      for (final item in response.data ?? const [])
        Club.fromJson(item as Map<String, dynamic>),
    ];
  }
}

final clubsRepositoryProvider = Provider<ClubsRepository>(
  (ref) => ClubsRepository(ref.watch(dioProvider)),
);

/// Etkinlik formundaki kulüp seçimi için.
final clubsProvider = FutureProvider.autoDispose<List<Club>>(
  (ref) => ref.watch(clubsRepositoryProvider).list(),
  retry: (_, _) => null,
);
