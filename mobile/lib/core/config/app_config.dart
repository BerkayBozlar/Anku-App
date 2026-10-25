/// Uygulama genelindeki ayarlar.
///
/// API adresi derleme sırasında değiştirilebilir:
/// `flutter run --dart-define=API_BASE_URL=http://192.168.1.20:5098`
class AppConfig {
  const AppConfig._();

  /// Android emülatörü bilgisayardaki localhost'a 10.0.2.2 üzerinden erişir.
  /// 5098, AnkuApp.Api'nin `http` profilindeki porttur.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:5098',
  );

  static const Duration connectTimeout = Duration(seconds: 5);
  static const Duration receiveTimeout = Duration(seconds: 10);
}
