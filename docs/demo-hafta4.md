# 4. hafta — 18 Kasım ilk gösterim hazırlığı

Yiğithan'ın öğrenci kulüp/etkinlik akışı, temel harita ve Flutter/MVC entegrasyonu hazırdır. Birlikte yapılacak prova ve video çekimi ayrıca tamamlanır.

## Çalıştırma

PostgreSQL çalışırken depo kökünde:

```powershell
dotnet tool restore
dotnet ef database update --project backend/AnkuApp.Api -- --environment Development
dotnet run --project backend/AnkuApp.Api --launch-profile http
```

İkinci terminalde portal:

```powershell
dotnet run --project backend/AnkuApp.Web --launch-profile http
```

Android emülatör açıkken üçüncü terminalde:

```powershell
cd mobile
flutter pub get
flutter run
```

API `http://localhost:5080`, portal `http://localhost:5025`, Android emülatörünün API adresi `http://10.0.2.2:5080` olur. Flutter ve MVC aynı PostgreSQL verisini API üzerinden kullanır.

API'nin `ConnectionStrings:DefaultConnection`, `Jwt:Key`, `Jwt:Issuer` ve `Jwt:Audience` ayarları geliştirici makinesindeki user-secrets içinde bulunmalıdır. Mevcut kurulumda bunlar tanımlıdır. Bu hafta yeni migration veya Flutter paketi eklenmedi.

## Demo hesapları

API, **Development** ortamında aşağıdaki yerel ayarlar varsa ilgili hesapları oluşturur. Mevcut hesabın parolasını değiştirmez.

| Hesap | Rol | Yerel parola ayarı |
|---|---|---|
| `ogrenci@ankuapp.test` | Öğrenci | `Seed:StudentPassword` |
| `admin@ankuapp.test` | Yönetici | `Seed:AdminPassword` |
| `kulup@ankuapp.test` | Kulüp Yetkilisi | `Seed:ClubPassword` |

Başka bir makinede bu ayarlar `dotnet user-secrets set --project backend/AnkuApp.Api "Seed:StudentPassword" "<yerel-demo-parolası>"` biçiminde tanımlanabilir. Ardından API yeniden başlatılır. Mevcut makinede üç test hesabı da hazırlanmıştır.

## Gösterim akışı (en az 5 dakika)

1. **0:00–0:40:** Tek API, PostgreSQL, MVC portal ve Flutter yapısını göster. Mobil ana sayfadaki API bağlantısını kontrol et.
2. **0:40–2:00:** Öğrenciyle giriş yap. Ana sayfadaki Kulüpler ve Etkinlikler kartını aç. Yaklaşan/Geçmiş, arama, etkinlik ayrıntısı, kulüp ayrıntısı ve kulübe ait etkinlikleri göster. Yönetim sekmesinin görünmediğini belirt.
3. **2:00–2:40:** Tandoğan haritasında kaydırma ve yakınlaştırmayı dene; Kampüse dön düğmesini göster.
4. **2:40–4:00:** Portalda yöneticiyle giriş yap. Bir kulübe gelecekteki bir etkinlik ekle ve durumunu Yayında seç. Mobil öğrenci listesini aşağı çekip aynı kaydı ve ayrıntısını göster. Portalda tarihi Türkiye saatiyle gir; mobil tarih cihazın yerel saatinde gösterilir.
5. **4:00–4:50:** Etkinliği portalda Taslak yap; mobilde yenileyince yayındaki listeden çıkmasını göster. Yeniden Yayında yap. Yönetici mobil yönetiminden güncelleme yapıp portalı yenile. Silmeyi geçici bir kayıt üzerinde dene.
6. **4:50–5:30:** Kulüp yetkilisinin kendi kulübünü yönettiğini, öğrencinin MVC yönetimine giremediğini göster. Swagger'da JWT ile etkinlik listesini aç.
7. **5:30 ve sonrası:** Portalı telefon ve masaüstü genişliklerinde göster; test sonuçlarını ve tamamlanan görevleri özetle.

Kulüp yetkilisinin portalı kullanabilmesi için kulübün Yetkili e-posta alanına bu hesabın atanmış olması gerekir. Örnek kulüp ile yaklaşan/geçmiş demo kayıtları mevcut makinede hazırlanmıştır. Ortak veri hazırlığı Berkay'ın görev panosundaki sorumluluğudur.

## Kontrolleri tekrarlama

```powershell
dotnet build AnkuApp.slnx
cd mobile
flutter analyze
flutter test
cd ..
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/Test-Week4Integration.ps1
```

Son komut çalışırken API ve portal açık olmalıdır. Script üç demo hesabıyla giriş yapar, geçici bir kulüp ve etkinlikler oluşturur; MVC formu → API → öğrenci akışını, API güncellemesi → MVC listesini, saat dönüşümünü, taslak/iptal durumlarını ve rol kısıtlarını kontrol eder. Oluşturduğu geçici kulüp ve etkinlikleri `finally` bloğunda temizler.

Doğrulanan sonuçlar:

- .NET derlemesi: 0 hata, 0 uyarı.
- Flutter analizi: temiz; 72 test başarılı (öğrenci akışı için 11 yeni test dahil).
- Ortak PostgreSQL/API/MVC üzerinde 12 entegrasyon kontrolü başarılı.
- Portalın kulüp/etkinlik listeleri ve etkinlik ekleme formu 390 ve 1280 piksel genişlikte taşma olmadan görüntülendi.

Video çekiminden önce birlikte son prova yapın; haftalık liderlik dağılımına göre videoyu Drive'a yükleyin. Bu rehber video çekildiği veya yüklendiği anlamına gelmez.
