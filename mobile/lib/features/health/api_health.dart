import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';

/// `GET /api/health` yanıtı.
class ApiHealth {
  const ApiHealth({required this.status, required this.application});

  factory ApiHealth.fromJson(Map<String, dynamic> json) {
    return ApiHealth(
      status: json['status'] as String? ?? 'unknown',
      application: json['application'] as String? ?? '',
    );
  }

  final String status;
  final String application;

  bool get isOk => status == 'ok';
}

final apiHealthProvider = FutureProvider.autoDispose<ApiHealth>(
  (ref) async {
    final dio = ref.watch(dioProvider);
    final response = await dio.get<Map<String, dynamic>>('/api/health');
    return ApiHealth.fromJson(response.data ?? const {});
  },
  // Hata durumunu hemen göster, yeniden denemeyi kullanıcı yapsın.
  retry: (_, _) => null,
);
