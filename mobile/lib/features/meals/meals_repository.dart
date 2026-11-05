import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import 'meal_models.dart';

/// `/api/meal-menus` okuma uç noktası. Hatalar [ApiException] olarak döner.
class MealsRepository {
  MealsRepository(this._dio);

  final Dio _dio;

  /// [from] verilmezse API Türkiye tarihine göre bugünden başlar; [to]
  /// verilmezse 7 günlük aralık döner.
  Future<MealMenuRange> range({DateTime? from, DateTime? to}) {
    return guardApi(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/meal-menus',
        queryParameters: {
          if (from != null) 'from': formatApiDate(from),
          if (to != null) 'to': formatApiDate(to),
        },
      );
      return MealMenuRange.fromJson(response.data!);
    }, notFound: 'Yemek menüsü bulunamadı.');
  }
}

final mealsRepositoryProvider = Provider<MealsRepository>(
  (ref) => MealsRepository(ref.watch(dioProvider)),
);

/// Aile anahtarı haftanın ilk günüdür; `null` = bugünden başlayan 7 gün.
final mealMenuRangeProvider = FutureProvider.autoDispose
    .family<MealMenuRange, DateTime?>((ref, from) {
      return ref
          .watch(mealsRepositoryProvider)
          .range(
            from: from,
            to: from == null
                ? null
                : DateTime(from.year, from.month, from.day + 6),
          );
    }, retry: (_, _) => null);
