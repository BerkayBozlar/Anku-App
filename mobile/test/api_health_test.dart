import 'package:anku_app/features/health/api_health.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('health yanıtı ayrıştırılır', () {
    final health = ApiHealth.fromJson({
      'status': 'ok',
      'application': 'AnkuApp.Api',
    });

    expect(health.isOk, isTrue);
    expect(health.application, 'AnkuApp.Api');
  });

  test('eksik alanlar varsayılan değer alır', () {
    final health = ApiHealth.fromJson({});

    expect(health.isOk, isFalse);
    expect(health.status, 'unknown');
  });
}
