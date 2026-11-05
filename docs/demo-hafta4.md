# 4. hafta — 18 Kasım ilk gösterim hazırlığı

Yiğithan'ın öğrenci kulüp/etkinlik akışı, temel harita ve Flutter/MVC entegrasyonu hazırdır. Birlikte yapılacak prova ve video çekimi ayrıca tamamlanır.

Berkay'ın backend kararlılığı ve tekrar hazırlanabilir demo verisi çalışması da tamamlandı. Bu belge iki kişinin teknik hazırlığını birleştirir; birlikte prova ve video görevleri ayrıca açıktır.

## Çalıştırma

PostgreSQL çalışırken depo kökünde:

```powershell
dotnet tool restore
dotnet ef database update --project backend/AnkuApp.Api -- --environment Development
dotnet run --project backend/AnkuApp.Api --launch-profile http -- --seed-demo
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

API'nin `ConnectionStrings:DefaultConnection`, `Jwt:Key`, `Jwt:Issuer` ve `Jwt:Audience` ayarları geliştirici makinesindeki user-secrets içinde bulunmalıdır. `Jwt:Key`, en az 32 rastgele baytın Base64 karşılığı olmalıdır; giriş ve JWT doğrulaması bu biçimi kullanır. Mevcut yerel kurulumda ayarlar tanımlıdır. Bu hafta yeni migration veya Flutter paketi eklenmedi.

Yeni makinede her geliştirici kendi PostgreSQL veritabanını oluşturup aşağıdaki yer tutucuları kendi yerel değerleriyle değiştirmelidir:

```powershell
dotnet user-secrets set --project backend/AnkuApp.Api "ConnectionStrings:DefaultConnection" "Host=localhost;Port=5432;Database=ankuapp;Username=<yerel-kullanıcı>;Password=<yerel-parola>"
dotnet user-secrets set --project backend/AnkuApp.Api "Jwt:Key" "<rastgele-anahtarın-Base64-karşılığı>"
dotnet user-secrets set --project backend/AnkuApp.Api "Jwt:Issuer" "AnkuApp.Api"
dotnet user-secrets set --project backend/AnkuApp.Api "Jwt:Audience" "AnkuApp.Clients"
dotnet user-secrets set --project backend/AnkuApp.Api "Seed:AdminPassword" "<güçlü-yerel-yönetici-parolası>"
dotnet user-secrets set --project backend/AnkuApp.Api "Seed:ClubPassword" "<güçlü-yerel-kulüp-parolası>"
dotnet user-secrets set --project backend/AnkuApp.Api "Seed:StudentPassword" "<güçlü-yerel-öğrenci-parolası>"
```

Örnek parolaları gerçek parola olarak kullanmayın; Identity en az 8 karakter, büyük/küçük harf, rakam ve özel karakter ister. Gizli değerleri Git'e veya videoya koymayın. Ayarlardan sonra yukarıdaki migration ve demo komutlarını çalıştırın. `--seed-demo` sunucu portu açmadan çıkar; normal API başlangıcı demo içeriklerini eklemez.

## Demo hesapları

API, **Development** ortamında aşağıdaki yerel ayarlar varsa ilgili hesapları oluşturur. Mevcut hesabın parolasını değiştirmez.

| Hesap | Rol | Yerel parola ayarı |
|---|---|---|
| `ogrenci@ankuapp.test` | Öğrenci | `Seed:StudentPassword` |
| `admin@ankuapp.test` | Yönetici | `Seed:AdminPassword` |
| `kulup@ankuapp.test` | Kulüp Yetkilisi | `Seed:ClubPassword` |

Başka bir makinede bu ayarlar `dotnet user-secrets set --project backend/AnkuApp.Api "Seed:StudentPassword" "<yerel-demo-parolası>"` biçiminde tanımlanabilir. Ardından API yeniden başlatılır. Mevcut makinede üç test hesabı da hazırlanmıştır.

## Tekrar hazırlanabilir demo verisi

`--seed-demo` komutu üç hesabı ve rollerini kontrol eder; eksik hesap/rol varsa anlaşılır hata verir. İçerik ekleme tek veritabanı işlemi içinde tamamlanır. Production ortamında komut veritabanına erişmeden reddedilir.

| Veri | İçerik |
|---|---|
| Kulüpler | `[Demo] Teknoloji Topluluğu` (`kulup@ankuapp.test` yetkili), `[Demo] Kültür ve Sanat Topluluğu` (yetkilisiz; sahiplik sınırı gösterimi) |
| Konumlar | `[Demo] Tandoğan Buluşma Alanı`, `[Demo] Tandoğan Etkinlik Alanı` |
| Yayındaki etkinlikler | İki yaklaşan, iki geçmiş etkinlik; iki kulübe dağıtılmış |
| Diğer durumlar | Bir taslak atölye ve bir iptal edilen söyleşi |

Kayıtlar temsili gösterim verisidir; konumlar gerçek bina/GPS işaretleri değildir. Gerçek kampüs konumları ve mobil işaretler 7. haftanın kapsamındadır. Yaklaşan tarihler ilk oluşturma gününün UTC 15:00 (Türkiye 18:00) saatinden 14–16 gün sonrasına, taslak 21 gün sonrasına, geçmiş kayıtlar 7 ve 14 gün öncesine ayarlanır.

Komut kulüp/konum adı ve kulüp içindeki etkinlik başlığı üzerinden eksikleri ekler; aynı veride tekrar çalıştırmak kayıt çoğaltmaz. Mevcut kayıtların içeriğini, tarihini, yetkilisini ve parolasını değiştirmez. Demo adlarını/başlıklarını değiştirirseniz sonraki çalıştırma özgün isimli kaydı yeniden ekler. Zamanla geçmişe düşen kayıtları tekrar geleceğe taşımaz; yeni demo tarihi için portalda ilgili yaklaşan kaydı düzenleyin. Taslak ve geçmiş kayıtları gösterirken öğrencinin taslağı görmediğini, geçmiş etkinliklerin portalda salt okunur olduğunu belirtin.

## Gösterim akışı (en az 5 dakika)

1. **0:00–0:40:** Tek API, PostgreSQL, MVC portal ve Flutter yapısını göster. Mobil ana sayfadaki API bağlantısını kontrol et.
2. **0:40–2:00:** Öğrenciyle giriş yap. Ana sayfadaki Kulüpler ve Etkinlikler kartını aç. Yaklaşan/Geçmiş, arama, etkinlik ayrıntısı, kulüp ayrıntısı ve kulübe ait etkinlikleri göster. Yönetim sekmesinin görünmediğini belirt.
3. **2:00–2:40:** Tandoğan haritasında kaydırma ve yakınlaştırmayı dene; Kampüse dön düğmesini göster.
4. **2:40–4:00:** Portalda yöneticiyle giriş yap. Bir kulübe gelecekteki bir etkinlik ekle ve durumunu Yayında seç. Mobil öğrenci listesini aşağı çekip aynı kaydı ve ayrıntısını göster. Portalda tarihi Türkiye saatiyle gir; mobil tarih cihazın yerel saatinde gösterilir.
5. **4:00–4:50:** Etkinliği portalda Taslak yap; mobilde yenileyince yayındaki listeden çıkmasını göster. Yeniden Yayında yap. Yönetici mobil yönetiminden güncelleme yapıp portalı yenile. Silmeyi geçici bir kayıt üzerinde dene.
6. **4:50–5:30:** Kulüp yetkilisinin kendi kulübünü yönettiğini, öğrencinin MVC yönetimine giremediğini göster. Swagger'da JWT ile etkinlik listesini aç.
7. **5:30 ve sonrası:** Portalı telefon ve masaüstü genişliklerinde göster; test sonuçlarını ve tamamlanan görevleri özetle.

Kulüp yetkilisinin portalı kullanabilmesi için kulübün Yetkili e-posta alanına bu hesabın atanmış olması gerekir. Demo komutu bunu Teknoloji Topluluğu için yapar. CRUD ve silme gösteriminde geçici bir kayıt kullanın; hazırlanmış demo başlıklarını koruyun.

## Kontrolleri tekrarlama

```powershell
dotnet build AnkuApp.slnx
cd mobile
flutter analyze
flutter test
cd ..
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/Test-Week4Integration.ps1 -CheckDemoData
```

Son komut çalışırken API ve portal açık olmalıdır. Script üç demo hesabıyla giriş yapar, geçici iki kulüp ve etkinlikler oluşturur; MVC formu → API → öğrenci akışını, API güncellemesi → MVC listesini, saat dönüşümünü, taslak/iptal durumlarını, JWT/Swagger yapılandırmasını, ekleme/güncelleme doğrulamalarını, sayfalama sınırlarını ve kulüp sahipliğini kontrol eder. Oluşturduğu geçici kulüp ve etkinlikleri `finally` bloğunda temizler. `-CheckDemoData` ayrıca yukarıdaki demo veri kümesini ve yaklaşan/geçmiş tarihlerini doğrular; bu anahtar olmadan yalnızca 33 uygulama kontrolü çalışır.

5 Kasım 2026 backend doğrulaması:

- .NET derlemesi: 0 hata, 0 uyarı.
- Ortak PostgreSQL/API/MVC üzerinde demo verisi dahil 45 entegrasyon kontrolü başarılı.
- Demo komutunun ilk çalıştırması: 2 kulüp, 2 konum, 6 etkinlik; ikinci çalıştırması: 0/0/0 yeni kayıt.
- Çok büyük sayfa numaraları artık tamsayı taşması ve sunucu hatası yerine HTTP 400 döndürür.

Bu kontrol sırasında açık yerel API/portalın derleme dosyalarını kilitlemesi nedeniyle `dotnet build AnkuApp.slnx --artifacts-path tmp/week4-artifacts` kullanıldı. Yeni derlenen API 5086, portal 5026 portunda çalıştırıldı; script'e `-ApiBaseUrl http://localhost:5086 -PortalBaseUrl http://localhost:5026` verildi. Normal kurulumda yukarıdaki 5080/5025 adresleri geçerlidir. Çalışan süreçler derleme dosyalarını kilitlerse önce kendi API/portal terminallerinizi kapatın.

Yiğithan'ın önceki entegrasyon çalışmasında Flutter analizi temiz, 72 test başarılıydı; portalın 390 ve 1280 piksel genişlik kontrolleri yapılmıştı. Bu backend çalışmasında Flutter veya portal arayüzü değiştirilmedi ve mobil/görsel kontroller tekrar çalıştırılmadı.

Video çekiminden önce birlikte son prova yapın; haftalık liderlik dağılımına göre videoyu Drive'a yükleyin. Bu rehber video çekildiği veya yüklendiği anlamına gelmez.
