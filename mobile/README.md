# AnküApp Mobil (Flutter)

AnküApp'in öğrenci tarafı. Veriye yalnızca `backend/AnkuApp.Api` üzerinden erişir.

## Gereksinimler

- Flutter (stable) — `flutter doctor` temiz olmalı
- Android SDK + bir Android emülatörü (API 35 önerilir)
- .NET 10 SDK (API'yi yerelde çalıştırmak için)

## Çalıştırma

1. API'yi başlat (depo kökünden):

   ```bash
   dotnet run --project backend/AnkuApp.Api --launch-profile http
   ```

   API `http://localhost:5098` adresinde açılır, `GET /api/health` → `{"status":"ok"}`.

2. Emülatörü aç, sonra uygulamayı çalıştır:

   ```bash
   cd mobile
   flutter pub get
   flutter run
   ```

Emülatör bilgisayarın `localhost`'una `10.0.2.2` üzerinden ulaşır; varsayılan API adresi `http://10.0.2.2:5098`. Gerçek telefonda ya da farklı bir portta:

```bash
flutter run --dart-define=API_BASE_URL=http://192.168.1.20:5098
```

Ana sayfadaki "API bağlantısı" kartı `/api/health` sonucunu gösterir; yenile düğmesiyle tekrar denenir.

## Klasör yapısı

```
lib/
  main.dart              uygulama girişi (ProviderScope)
  app.dart               MaterialApp.router + tema
  core/
    config/              API adresi, zaman aşımları
    network/             dio istemcisi
    router/              go_router yönlendirmeleri
    theme/               renkler, tema
  features/
    home/                ana sayfa, modül kartları
    health/              API bağlantı kontrolü
    map/                 Tandoğan kampüs haritası (MapLibre + OpenStreetMap)
```

## Harita

Harita OpenStreetMap raster karolarını MapLibre ile gösterir; ayrı bir API anahtarı gerekmez. Bina/tesis işaretleri, arama ve GPS 7. haftada eklenecek.
