# 6. hafta — Akademik takvim verisi ve API desteği

## Kapsam ve branch

İki plan belgesinin 6. haftasında Berkay'ın görevi aynı işi tanımlar: [Web planı](plan/BLM4581-web-plan.md) "takvim API/veri desteği", [Flutter planı](plan/BLM4587-flutter-plan.md) "takvim verisi ve API desteği". Ortak backend uygulaması iki dersin bu görevini karşılar.

Branch: `feature/week6-academic-calendar`. Bu çalışma branch üzerinde yerel commit olarak hazırlanır; kullanıcı onayı olmadan `main`e merge veya push yapılmaz. Ders/sınav programı görseli, mobil takvim ekranı, kişisel hatırlatıcı ve yerel bildirimler Yiğithan'ın 6. hafta görevleridir; bu değişiklik bunları gerçekleştirmez. Sonraki haftanın harita, not hesaplayıcı veya katılım işleri kapsamda değildir.

## Veri kaynağı ve sınırlar

15 Kasım 2026'da [Öğrenci İşleri ana sayfasındaki](https://oidb.ankara.edu.tr/) 2026–2027 takvim bağlantısı izlenerek [resmî PDF](https://oidb.ankara.edu.tr/wp-content/uploads/sites/91/2026/06/2026-2027_Yili_Akademik_Takvimi-SON.pdf) doğrulandı. İlk iki sayfa **ön lisans ve lisans genel takvimi**: 30 güz ve 25 bahar kaydıdır. Tarihler koda sabitlenmez; PDF'den okunup PostgreSQL'e kaydedilir.

Kapsam adı `Ön lisans ve lisans (genel takvim)` olarak açıkça verilir. Açık/uzaktan eğitim ve diğer öğrenci gruplarına ait farklılıklar kaynak başlıklarında aynen korunur; örneğin "... hariç" ve "... Fakültesi" farklı kayıtlardır. PDF'nin sonraki sayfalarındaki fakülteye özel takvimler genel tarihlere karıştırılmaz. Kullanıcı, kendi programının kapsamını ve kaynak belgesini kontrol etmelidir. Hazırlık programı için henüz tarih verilmeyen açıklamaya gün uydurulmaz.

`PdfPig` 0.1.16 ile metin ve koordinatlar okunur. Tarih sütunu ve satır sayıları doğrulanan PDF düzenine bağlıdır. Her iki genel sayfanın başlığı, akademik yılı, temel ders/final/bütünleme satırları ve 30/25 satır sayısı doğrulanmadan veri yazılmaz. Kaynak yeni satır ekler veya düzeni değişirse otomatik aktarım kontrollü hata verir; okuyucu güncellenene kadar yönetici elle giriş API'sini kullanabilir. Bu tercih, kısmi okumayı tam takvim sayıp eski satırları silmeyi önler.

## API davranışı

- `AcademicCalendarEntries` tablosu: akademik yıl, kapsam, dönem, başlık/açıklama, başlangıç ve bitiş günü, kaynak adı/linki/sayfası, anahtar, son kayıt zamanı, manuel kayıt işareti.
- `StartDate` ve `EndDate` PostgreSQL `date` alanıdır; iki uç da dahildir. Aynı gün başlayıp biten sınav/başvuru desteklenir. Tarih aralığının ortasındaki gün sorgulandığında devam eden dönem kaydı da döner.
- Liste, ayrıntı ve mevcut yıllar JWT sahibi üç role açıktır. Ekleme/düzenleme/silme ve kaynak yenileme yalnızca Yönetici rolüne açıktır.
- Kaynak satır anahtarı yıl, kapsam, dönem, başlık ve aynı başlığın kaynak içindeki tekrar sırasından üretilir. Aynı PDF yeniden alınırken kayıt kimlikleri korunur; tarihler değişirse aynı kaynak kaydı güncellenir. Tekrarlanan danışman/onay satırları ayrı kalır. Başlık veya tekrar sırası değişirse kimlik değişebilir.
- Elle düzeltilen kayıt `isManual=true` olur ve otomatik yenilemede üzerine yazılmaz. Kaynak anahtarı düzenlemede korunur. Aynı yıl/kapsam/dönem/başlık/tarih aralığı ikinci kez eklenemez.
- Tam kaynak başarıyla doğrulandığında artık kaynakta olmayan otomatik satırlar aynı yıl ve kapsam içinde temizlenir. Manuel kayıtlar ve başka akademik yıllar korunur. Kaynaktan silinen bir kaydı mobil istemci 404 ile karşılayabilir.
- Silinen bir resmî kayıt sonraki kaynak yenilemesinde yeniden gelebilir. Manuel düzeltmeyi bırakıp yeniden resmî veriyi kullanmak için kayıt silinip kaynak yenilenebilir; bu durumda kimlik değişebilir.
- Ortak günlük göreve `academic-calendar` kaynağı eklendi. Açılışta ve 30 dakikalık kontrolde Türkiye tarihine göre günde bir deneme yapılır; son deneme kalıcıdır. Yönetici `refresh` ile beklemeden yeniden deneyebilir.
- Kaynak/kayıt hatasında işlem geri alınır, önceki içerik ve son başarı zamanı korunur. Bozuk PDF/HTML kaynak 503; aynı kaynak zaten yenileniyorsa 409; son durum yöneticiye `/api/content-sync` üzerinden sunulur.

## Yerel kurulum ve deneme

PostgreSQL ve mevcut [yerel JWT/demo hesap ayarları](demo-hafta4.md) gereklidir. Depo kökünde:

```powershell
git branch --show-current
dotnet tool restore
dotnet ef database update --project backend/AnkuApp.Api -- --environment Development
dotnet run --project backend/AnkuApp.Api --launch-profile http
```

API `http://localhost:5080`, Swagger `http://localhost:5080/swagger`; emülatörden `http://10.0.2.2:5080`. `20261115111458_AddAcademicCalendar` migration'ı sadece yeni takvim tablosunu, indekslerini ve tarih aralığı kısıtını ekler. Yerel geliştirme veritabanına uygulandı. Başka makinede update komutu çalıştırılmalıdır. Geri alma bu yeni tabloyu ve içindeki takvim verisini kaldırır.

API açıldıktan sonra günlük görev takvimi hazırlayabilir. Yönetici token'ıyla `POST /api/academic-calendar/refresh` çağrısı da kullanılabilir. Başarılı aktarım ardından:

```http
GET /api/academic-calendar?academicYear=2026-2027&pageSize=100
Authorization: Bearer <token>
```

Kaynak `ContentSources:AcademicCalendarUrl` ayarıyla değiştirilir; ayar değişiminden sonra API yeniden başlatılır. Kaynak adresi API isteğinden alınmaz. `ContentSources:Enabled=false` yalnızca arka plan toplamayı kapatır; yönetici yenilemesi kullanılabilir. İnternet olmadığında önceden kaydedilmiş veri okunur ve yönetici elle giriş yapabilir.

Swagger'da ayrıca yıl/dönem/tarih filtresini, boş sonucu, öğrenci için yazma işleminin 403 dönmesini, yönetici geçici kayıt ekle/düzenle/sil akışını ve aynı kaydı tekrar eklerken 409 durumunu deneyin. Geçici kayıtları genel kaynakla karıştırmamak için ayrı bir `scope` kullanın.

## Yiğithan için mobil takvim/hatırlatıcı sözleşmesi

[API sözleşmesinin](api-sozlesmesi.md) 6. hafta bölümü istek/yanıt örneklerini içerir:

| İşlem | Uç nokta |
|---|---|
| Mevcut yıllar | `GET /api/academic-calendar/years` |
| Liste | `GET /api/academic-calendar?academicYear=2026-2027&term=Fall&from=2026-11-01&to=2026-11-30` |
| Ayrıntı | `GET /api/academic-calendar/{id}` |
| Yönetici elle giriş/düzeltme | `POST /api/academic-calendar`, `PUT /api/academic-calendar/{id}` |
| Yönetici silme/yenileme | `DELETE /api/academic-calendar/{id}`, `POST /api/academic-calendar/refresh` |

`academicYear` verilmezse Türkiye tarihine göre ağustosta değişen akademik yıl kullanılır; bu uygulama varsayımıdır, üniversitenin resmî dönem başlangıç tarihi değildir. İstemci `/years` ile mevcut yılları seçtirebilir. Dönem değerleri `Fall`, `Spring`, `YearRound`; resmî genel kaynak güz/bahar üretir. `scope` isteğe bağlı tam eşleşme filtresidir. Başlıklardaki öğrenci grubu açıklamaları kullanıcıya görünmelidir.

Liste `{ items, page, pageSize, totalCount, academicYear, message }` döndürür; varsayılan 20 kayıt, en fazla 100 kayıt. Mobil ekran bütün sayfaları almalı veya kullanıcı kaydırdıkça devamını yüklemelidir. `from` ve `to` kesişim filtresidir: başlangıcı önceki ayda olsa da devam eden ders dönemi sonuca dahil olur. Boş sonuç HTTP 200, `items: []` ve mesajdır.

**Hatırlatıcı tarihi:** `startDate`/`endDate` saat dilimsiz `yyyy-MM-dd` günleridir. `2027-01-02` değerini UTC gece yarısı olarak çevirip bir gün kaydırmayın. Seçilen gün ve hatırlatma saatiyle cihazda/zaman dilimi paketinde bildirim oluşturun. Kampüs takvimini Türkiye saatine sabitlemek istiyorsanız `Europe/Istanbul` kullanın; cihazın yerel saati tercih ediliyorsa bu seçim kullanıcıya açık olmalıdır. Backend kişisel hatırlatıcı/bildirim oluşturmaz.

Yerel hatırlatıcıyla ilişkilendirmek için kayıt `id` değerini saklayabilirsiniz. Yenileme sonrasında gün değişikliği, silinmiş kaynak kaydı veya yeni kimlik olasılığını ele alın; önceden kurulmuş cihaz bildirimleri backend değişince kendiliğinden güncellenmez. `retrievedAt` UTC kayıt zamanıdır, etkinliğin gerçekleşeceği gün değildir. `sourceUrl` ve `sourcePage` kullanıcının kaynağı kontrol edebilmesi içindir.

## Doğrulama

```powershell
dotnet build AnkuApp.slnx
dotnet test backend/AnkuApp.Api.Tests
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/Test-Week6Integration.ps1 -CheckSources
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/Test-Week5Integration.ps1 -CheckSources
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/Test-Week4Integration.ps1 -CheckDemoData
```

Entegrasyon script'leri çalışırken API açık olmalı; önceki haftaların portal kontrolleri için ayrıca `dotnet run --project backend/AnkuApp.Web --launch-profile http` gereklidir. Script parolaları yerel user-secrets'ten okur ve yalnızca kendisinin oluşturduğu test kayıtlarını temizler. `-CheckSources` olmadan manuel API akışı internetsiz test edilir; bu anahtarla resmî PDF verisi alınır ve veritabanında bırakılır.

Bozuk kaynak testi için ikinci bir terminalde:

```powershell
dotnet run --project backend/AnkuApp.Api --launch-profile http -- --urls http://localhost:5087 --ContentSources:Enabled=false --ContentSources:AcademicCalendarUrl=https://oidb.ankara.edu.tr/duyurular/
```

Ardından `powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/Test-Week6Integration.ps1 -CheckSources -FailureApiBaseUrl http://localhost:5087` çalıştırılır. PDF yerine HTML verilen kaynak 503 döndürmeli; mevcut takvim, manuel veri ve son başarı zamanı korunmalıdır.

15 Kasım 2026 sonuçları: 57 birim testi, kaynak hatası dahil 45 takvim entegrasyon kontrolü, 39 duyuru/menü ve 45 etkinlik regresyon kontrolü başarılı. Derleme 0 hata/0 uyarı; model ve migration uyumu doğrulandı. Resmî PDF'nin 55 kaydı ikinci bir PDF aracıyla başlık, tarih aralığı ve kaynak sayfası düzeyinde bağımsız karşılaştırıldı; iki sayfa görsel olarak incelendi. Önceki haftanın test script'inde kaynak sayısının sabit iki olacağı varsayımı kaldırılarak yalnızca o haftanın kaynakları kontrol edildi.

Birlikte mobil bildirim/görsel akışının cihaz testi ve kullanıcı merge onayı bu backend kontrolleriyle yapılmış sayılmaz.
