# 5. hafta — Berkay'ın duyuru ve yemekhane işleri

Çalışma branch'i: `feature/week5-announcements-meals`. Teknik geliştirme hazır; Berkay'ın kendi testleri ve açık onayı olmadan `main`e merge edilmez. Flutter duyuru/menü ekranları Yiğithan'ın görevidir ve bu çalışmada yapılmadı.

## Hazır olanlar

- Öğrenci İşleri duyuru kategorisinin RSS içeriği, kaynak bağlantısı ve düz metin özetiyle PostgreSQL'e alınır.
- Kaynak URL'sinin SHA-256 karşılığı `UniqueKey` üzerindeki benzersiz indeks, tekrar kayıt oluşmasını önler. URL fragment'i ve sondaki slash anahtarı değiştirmez.
- `BackgroundService` açılışta ve ardından 30 dakikada bir kontrol eder. Her kaynak için Türkiye tarihine göre günün ilk denemesi çalışır; son deneme veritabanında tutulur. Kaynak hatasında kullanıcı isteğiyle "Şimdi yenile" tekrar denenebilir.
- Yönetici portalında Duyurular ve Yemekhane listeleri, elle ekleme/düzenleme/silme, kaynak bağlantıları, son kontrol durumu ve yenileme düğmeleri vardır. MVC bütün veriyi aynı API üzerinden alır.
- Öğrenci ve kulüp yetkilisi API'den içeriği okuyabilir. Genel duyuru/menü yönetimi, yenileme ve kaynak durumunu görüntüleme yalnızca Yönetici rolüne açıktır.
- SKS aylık Excel listesinden tarih, dört yemek ve varsa toplam enerji alınır. Aynı tarihte tek ortak öğle menüsü tutulur. Akşam ve vejetaryen listeleri bu sürümün kapsamına dahil değildir.
- Bozuk RSS/Excel, kaynak kesintisi veya zaman aşımı mevcut kayıtları silmez; son başarı zamanı korunur. Yenileme HTTP 503 ve anlaşılır mesaj döndürür; aynı kaynak zaten yenileniyorsa 409 döner.

## Resmî kaynaklar ve veri biçimi

5 Kasım 2026'da gerçek içerik ve yönlendirmeleri kontrol edildi:

- [Öğrenci İşleri duyuruları](https://oidb.ankara.edu.tr/duyurular/) ve [duyuru kategorisi RSS](https://oidb.ankara.edu.tr/category/duyurular/feed/).
- [SKS Yemek Hizmetleri](https://sks.ankara.edu.tr/yemek-hizmetleri-2/) sayfası günlük bilgiyi görsel, [aylık listeyi Excel dosyası](https://sksbasvuru.ankara.edu.tr/kayit/moduller/yemeklistesi/aylikmenu.php) olarak sunar. API görsele OCR uygulamak yerine aynı resmî sayfanın aylık listesini okur.

Menü okuyucusu ilk çalışma sayfasının A sütunundaki Excel tarihini, B–E yemek hücrelerini ve F enerji hücresini kullanır. Shared strings, inline strings ve 1900/1904 tarih sistemleri desteklenir. Beklenen yapı okunamıyorsa eksik/verisiz başarı yerine hata kaydedilir. Kaynak ayarları `backend/AnkuApp.Api/appsettings.json` içindeki `ContentSources` bölümündedir; adres değişirse yapılandırma güncellenebilir. İndirme yalnızca Ankara Üniversitesi alanlarındaki http/https adreslerine ve bu alanlar içindeki yönlendirmelere izin verir; HTTP süre ve boyut sınırları uygulanır.

## Yerel kurulum

PostgreSQL ve [4. hafta rehberindeki](demo-hafta4.md) bağlantı/JWT/demo hesap ayarları mevcut olmalıdır. Depo kökünde:

```powershell
git branch --show-current
dotnet tool restore
dotnet ef database update --project backend/AnkuApp.Api -- --environment Development
dotnet run --project backend/AnkuApp.Api --launch-profile http
```

Ayrı terminalde:

```powershell
dotnet run --project backend/AnkuApp.Web --launch-profile http
```

API `http://localhost:5080`, Swagger `http://localhost:5080/swagger`, portal `http://localhost:5025`. Android emülatörünün API adresi `http://10.0.2.2:5080`. İlk kaynak kontrolü arka planda çalışır; verinin gelmesini bekleyebilir veya yönetici portalından yenileyebilirsiniz. İnternet olmadan otomatik toplama çalışmaz; mevcut kayıtlar ve elle giriş kullanılabilir.

`20261105131740_AddAnnouncementsAndMealMenus` migration'ı yalnızca üç yeni tablo ve indekslerini ekler. Mevcut yerel geliştirme veritabanına uygulandı; başka makinelerde yukarıdaki update komutu gereklidir. Migration geri alındığında yeni içerik tablolarındaki veriler de kaldırılır.

Otomatik toplamayı kapatmak için `ContentSources:Enabled=false` verin. Bu ayar yalnızca arka plan görevini kapatır; yönetici "Şimdi yenile" işlemi çalışmaya devam eder. Parolalar ve bağlantı dizesi depoya eklenmez.

## Berkay'ın kendi testleri

1. Yönetici hesabıyla portalı açın. Panelde ve üst menüde Duyurular/Yemekhane bağlantılarını deneyin.
2. Duyurularda "Şimdi yenile"ye iki kez basın. Kaynak bağlantısını açın; ikinci yenilemede aynı duyuruların çoğalmadığını görün.
3. Resmî kaynak bağlantısıyla geçici bir duyuru ekleyin, başlıkla arayın, düzenleyin ve silin. Portalda girdiğiniz yayın saati Türkiye saatidir; API UTC saklar.
4. Yemekhane ekranında başlangıç tarihi seçip yedi günlük listeyi kontrol edin. Yeni bir güne elle menü ekleyin; her satıra bir yemek girin, düzenleyin ve silin. Aynı tarihe iki kayıt eklenmediğini doğrulayın.
5. Kaynaktan gelen bir menüyü elle düzenlerseniz sonraki otomatik yenileme bu düzeltmeyi korur. Öğrenci API'sinde de aynı menü görünür.
6. Kulüp yetkilisinin portalında bu yönetim menülerinin olmadığını; doğrudan adresleri açtığında erişim reddedildiğini kontrol edin.
7. Swagger'da öğrenci token'ıyla liste/detay çağrılarını, menü olmayan tarih için boş durumu deneyin. POST/PUT/DELETE ve yenileme öğrenciye 403 dönmelidir.
8. Portalı telefon genişliğinde de inceleyin. Bu çalışmada MVC formları HTTP üzerinden doğrulandı; tarayıcıda farklı genişliklerde görsel prova kullanıcı testinin parçasıdır.

Elle girilen içerik işaretlenir; içe aktarma mevcut duyuruları güncellemez ve elle girilen/düzeltilen menüleri değiştirmez. Resmî kaynaktan alınan bir kaydı silerseniz sonraki yenileme aynı kaydı yeniden getirebilir. Kaynak mevcut ayı değiştirdiğinde eski tarihli menüler kendi tarihleriyle korunur; geçmiş bir menü "bugün" gibi gösterilmez.

## Otomatik kontroller

```powershell
dotnet build AnkuApp.slnx
dotnet test backend/AnkuApp.Api.Tests
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/Test-Week5Integration.ps1 -CheckSources
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/Test-Week4Integration.ps1 -CheckDemoData
```

Entegrasyon sırasında API ve portal çalışmalıdır. Script'ler parolaları yalnızca yerel user-secrets dosyasından okur. 5. hafta script'i geçici test duyuruları/menüleri oluşturup `finally` içinde temizler; `-CheckSources` gerçek resmî içerikleri alır ve veritabanında bırakır. Bu anahtar olmadan manuel API/MVC akışları internetsiz denenebilir.

Bozuk kaynak biçimi için isteğe bağlı ikinci API'yi ayrı terminalde çalıştırın:

```powershell
dotnet run --project backend/AnkuApp.Api --launch-profile http -- --urls http://localhost:5087 --ContentSources:Enabled=false --ContentSources:AnnouncementsUrl=https://oidb.ankara.edu.tr/duyurular/ --ContentSources:MealMenusUrl=https://oidb.ankara.edu.tr/duyurular/
```

Burada resmî HTML sayfası bilinçli olarak RSS/Excel kaynağı yerine verilir. Ardından:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/Test-Week5Integration.ps1 -CheckSources -FailureApiBaseUrl http://localhost:5087
```

5 Kasım 2026 doğrulaması: derleme 0 hata/0 uyarı; 23 birim testi; bozuk kaynak senaryosu dahil 45 adet 5. hafta entegrasyon kontrolü; önceki haftanın 45 entegrasyon kontrolü başarılı. HTTP 404 kaynak kesintisi ve HTTP 200 ile gelen yanlış RSS/Excel biçimi ayrı ayrı denendi. Yeni API'nin tekrar başlangıcında aynı gün kaynakların tekrar indirilmediği gözlendi. Birim testleri bozuk XML/DTD, eksik/yinelenen menü tarihleri, Türkçe metin, tarih dönüşümleri, dosya boyutu ve alan dışına yönlendirmeyi de kapsar.

Çalışan .NET süreçleri derleme dosyalarını kilitlerse önce ilgili terminalde Ctrl+C kullanın. Bu çalışma için ayrı çıktı klasörüyle derleme de doğrulandı: `dotnet build AnkuApp.slnx --artifacts-path tmp/week5-artifacts`.

## Yiğithan için mobil entegrasyon

Tüm çağrılar JWT ister. [API sözleşmesindeki](api-sozlesmesi.md) 5. hafta bölümü alanları ve örnekleri içerir:

- Duyuru listesi: `GET /api/announcements?page=1&pageSize=20&search=...`; `items/page/pageSize/totalCount`.
- Duyuru ayrıntısı: `GET /api/announcements/{id}`; metin özeti ve açılabilir `sourceUrl`.
- Bugünün ortak öğle menüsü: `GET /api/meal-menus/today`; `{ date, menu, message }`. Menü yoksa `menu: null` ve açıklayıcı mesaj; bu durum 200 döner.
- Tarih aralığı: `GET /api/meal-menus?from=2026-11-01&to=2026-11-07`; `{ items, from, to }`. Tarihler gün düzeyindedir; saat dilimine çevrilmez.
- `retrievedAt` son kaydetme/indirme zamanıdır, menünün tarihi değildir. Yemekler `dishes` dizisinde, toplam enerji `totalCalories` alanında isteğe bağlıdır.

5. hafta Web dersi videosu Berkay'ın, Flutter videosu Yiğithan'ın sorumluluğundadır. Video ve kullanıcının kendi testleri bu teknik tamamlanma kaydıyla yapılmış sayılmaz.
