import 'package:anku_app/features/auth/auth_validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parola API kurallarına göre denetlenir', () {
    expect(validateNewPassword('Kisa1!'), contains('8 karakter'));
    expect(validateNewPassword('kucukharf1!'), contains('büyük harf'));
    expect(validateNewPassword('BUYUKHARF1!'), contains('küçük harf'));
    expect(validateNewPassword('Rakamsiz!!'), contains('rakam'));
    expect(validateNewPassword('Ozelsiz123'), contains('özel karakter'));
    expect(validateNewPassword('Test1234!'), isNull);
  });
}
