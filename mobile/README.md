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

   API `http://localhost:5080` adresinde açılır, `GET /api/health` → `{"status":"ok"}`.

2. Emülatörü aç, sonra uygulamayı çalıştır:

   ```bash
   cd mobile
   flutter pub get
   flutter run
   ```

Emülatör bilgisayarın `localhost`'una `10.0.2.2` üzerinden ulaşır; varsayılan API adresi `http://10.0.2.2:5080`. Gerçek telefonda ya da farklı bir portta:

```bash
flutter run --dart-define=API_BASE_URL=http://192.168.1.20:5080
```

Ana sayfadaki "API bağlantısı" kartı `/api/health` sonucunu gösterir; yenile düğmesiyle tekrar denenir.

## Giriş ve roller

- Giriş `POST /api/auth/login`, öğrenci kaydı `POST /api/auth/register` ile yapılır. Roller yanıttaki `user.roles` dizisinden okunur ("Yönetici", "Kulüp Yetkilisi", "Öğrenci"); birden çok rol varsa en yetkilisi kullanılır.
- Kayıt formu parolayı API ile aynı kurallarla denetler: en az 8 karakter, büyük ve küçük harf, rakam, özel karakter.
- Dönen oturum (JWT, bitiş zamanı, kullanıcı) `flutter_secure_storage` ile cihazda şifreli saklanır; uygulama yeniden açılınca oturum devam eder, süresi dolmuşsa silinir.
- Her API isteğine `Authorization: Bearer <token>` eklenir; API 401 dönerse oturum kapatılıp giriş ekranına dönülür.
- Sekmeler role göre gösterilir: herkes Ana Sayfa, Keşfet, Harita, Profil; **Yönetim** sekmesi yalnızca Yönetici rolüne açıktır (doğrudan `/admin` adresine gitmek de engellenir).

## Kulüpler ve etkinlikler (öğrenci akışı)

Ana sayfadaki **Kulüpler ve Etkinlikler** kartı veya **Keşfet** sekmesi (`/discover`) bu akışı açar.

- Etkinliklerde Yaklaşan/Geçmiş ayrımı, başlığa göre arama, aşağı çekerek yenileme ve 20'şer sayfalama bulunur. Yalnızca yayındaki kayıtlar `status=Published` filtresiyle istenir; taslaklar öğrenciye API tarafından da gösterilmez.
- Etkinlik ayrıntısında açıklama, kulüp, cihazın yerel saatinde tarih, konum ve kontenjan gösterilir. Kulüp adına dokunarak o kulübün bilgileri ve etkinlikleri açılır.
- Kulüpler sekmesinde Türkçe büyük/küçük harf uyumlu ad araması vardır. Kulüp ayrıntısı yalnızca ilgili kulübün etkinliklerini listeler.
- Bağlantı hatası, boş liste, kaldırılmış kayıt ve sonradan iptal edilmiş etkinlik için ayrı durumlar bulunur. Bu akışta yönetim veya başvuru düğmeleri yoktur; takip/katılım 8. hafta kapsamındadır.
- Kulüp ayrıntısındaki yenile düğmesi kulüp bilgisini, listeyi aşağı çekme hareketi etkinlikleri yeniler.

İlk gösterim adımları ve ortak API entegrasyon kontrolü: [4. hafta demo rehberi](../docs/demo-hafta4.md).

## Duyurular ve yemekhane

Ana sayfadaki **Duyurular** (`/announcements`) ve **Yemekhane** (`/meals`) kartları açar. Veriler API'nin resmî kaynaklardan günlük aldığı kayıtlardır; uç noktalar `docs/api-sozlesmesi.md`'deki 5. hafta bölümündedir.

- Duyurular en yeni yayın tarihi önce, 20'şer sayfalı gelir; başlıkta arama, aşağı çekerek yenileme, "Daha fazla göster". Ayrıntıda özet, yayın tarihi ve kaynak bulunur; **Kaynakta aç** tam metni tarayıcıda açar (`url_launcher`).
- Yemekhane bugünden başlayan 7 günün ortak öğle menüsünü (`GET /api/meal-menus?from&to`) gösterir. Önceki/sonraki 7 güne geçilir, bugün vurgulanır; menüsü olmayan günler (hafta sonu, tatil) ayrıca belirtilir. Kalori, kaynak adı, son güncelleme ve resmî kaynak bağlantısı listenin altındadır.
- Bağlantı hatası (API mesajı + tekrar dene), boş liste ve kaldırılmış duyuru için Türkçe durumlar vardır. Yeni içerik bildirimi 8. hafta kapsamındadır.

## Etkinlik yönetimi (Yönetici)

Yönetim → Etkinlikler (`/admin/events`). Uç noktalar `docs/api-sozlesmesi.md`'deki Events sözleşmesidir.

- Liste `GET /api/events` ile 20'şer sayfalı gelir; başlıkta arama, aşağı çekerek yenileme, "Daha fazla göster" ile sonraki sayfa.
- İki sekme: **Yaklaşan** (`from=şimdi`, en yakın önce) ve **Geçmiş** (`to=şimdi&order=desc`, en yeni önce). Arama iki sekmeye de uygulanır. Tarihi geçmiş etkinlikler düzenlenemez; ayrıntısı görüntülenir ve silinebilir.
- Ekleme `POST`, düzenleme `PUT /api/events/{id}`, silme onay penceresinden sonra `DELETE`. Kulüp seçimi `GET /api/clubs` listesinden yapılır.
- Form, API ile aynı kuralları denetler: kulüp ve başlık zorunlu (en fazla 200 karakter), tarih geçmişte olamaz, kontenjan sıfırdan büyük. Tarih cihaz saatiyle seçilir, API'ye UTC gider.
- Boş liste, bağlantı hatası (tekrar dene), 403/404 ve silinemeyen etkinlik (409) için Türkçe mesaj gösterilir.
- Kulüp yetkilisinin etkinlik yönetimi mobilde değil, MVC portalındadır.

## Klasör yapısı

```
lib/
  main.dart              uygulama girişi (ProviderScope)
  app.dart               MaterialApp.router + tema
  core/
    config/              API adresi, zaman aşımları
    network/             dio istemcisi, ortak API hata dönüşümü
    router/              go_router yönlendirmeleri
    theme/               renkler, tema
    format.dart          tarih biçimleri, Türkçe gün adları
    open_link.dart       bağlantıyı tarayıcıda açma
  features/
    home/                ana sayfa, modül kartları
    events/              etkinlik modelleri, API istemcisi, yönetim ekranları
    clubs/               kulüp modelleri, liste ve ayrıntı istemcisi
    discover/            öğrenci kulüp/etkinlik listeleri ve ayrıntıları
    announcements/       duyuru listesi ve ayrıntısı
    meals/               yemekhane haftalık menüsü
    health/              API bağlantı kontrolü
    map/                 Tandoğan kampüs haritası (MapLibre + OpenStreetMap)
```

## Harita

Harita OpenStreetMap raster karolarını MapLibre ile gösterir; ayrı bir API anahtarı gerekmez. Bina/tesis işaretleri, arama ve GPS 7. haftada eklenecek.
