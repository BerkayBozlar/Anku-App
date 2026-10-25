# BLM4581 Ağ Tabanlı Teknolojiler ve Uygulamaları — Dönem Projesi Plan Belgesi

2026–2027 Güz Yarıyılı · Kaynak: `Ankara_Universitesi_Web_Mobil_Proje_Plani.docx` (bu dosya belgenin birebir metin karşılığıdır; öğrenci numaraları depo herkese açık olduğu için çıkarılmıştır).

| | |
|---|---|
| Proje adı | AnküApp |
| Grup adı | AnküApp |
| Grup türü | 2 kişilik |
| GitHub deposu | https://github.com/BerkayBozlar/Anku-App |
| Google Drive klasörü | https://drive.google.com/drive/folders/1nl9wWlVjwhCP9dYb0tzGQ9k32NIIHGIA?usp=sharing |

## Grup üyeleri

| Ad Soyad | GitHub kullanıcı adı |
|---|---|
| Berkay Bozlar | BerkayBozlar |
| Yiğithan Başağa | yigithan-basaga |

## 1. Projenin Kısa Özeti

Projenin amacı, Ankara Üniversitesi öğrencilerinin akademik işlerini ve kampüs yaşamını tek mobil uygulamada kolaylaştırmaktır. Öğrenciler Flutter uygulamasını; Yönetici ve Kulüp Yetkilisi ise içerik ve etkinlik yönetimi için web portalını kullanacaktır.

Sistem, ortak ASP.NET Core Web API ve Entity Framework Core veri katmanı üzerinde çalışacaktır. Web bölümü, API için yardımcı bir ekran değil; kullanıcı girişi, rol bazlı yetkilendirme, doğrulama, listeleme ve yönetim formları bulunan responsive bir ASP.NET Core MVC portalı olacaktır.

Mobil uygulamanın yedi ana modülü şunlardır: Tandoğan öncelikli interaktif kampüs haritası; ders ve sınav programı görselini yükleme, yakınlaştırma, değiştirme ve silme; resmî kaynaklardan günlük duyuru kontrolü ve bildirim; kulüp ve etkinlik işlemleri; yemekhane menüsü; akademik takvim ve hatırlatıcılar; ağırlıklı not, hedef final ve baraj hesabı yapan genel not hesaplayıcısı.

Dış veri toplama aşamalı yürütülecektir. Erişilebilir resmî RSS veya HTML kaynakları için günde bir kez çalışan görev, kaynak bağlantısı ve tekrar kayıt önleme temel sürümde yer alacaktır; kaynak yapısı değişirse yönetici girişi veya elle yenileme geçici geri dönüş olacaktır. Önce duyuruların uygulama içinde gösterilmesi ve kişisel hatırlatıcılar tamamlanacak, ardından yeni duyuruların ve takip edilen kulüplerin güncellemelerinin uygulama açık olmasa da telefona bildirim olarak gönderilmesi sağlanacaktır. Bu sıralama, yedi modülün temel sürümlerini kapsamdan çıkarmaz.

Yönetim ağırlıklı web portalının ders projesi olarak kabulü öğretim elemanının onayına sunulacaktır. Plan, onay koşulunu karşılamak için MVC portalını bağımsız, çalışan ve mobil uyumlu bir web ürünü olarak tanımlar.

## 2. Kullanılacak Teknolojiler

| Başlık | Seçim / Açıklama |
|---|---|
| Proje türü | MVC — gerçek, responsive yönetim portalı (Razor Pages değil) |
| Veritabanı | PostgreSQL |
| Kendi yazılan API | Events / Etkinlik — listeleme, ekleme, güncelleme ve silme; Swagger ile test; validation; Club-Events 1:N |
| Harici API | Maps; erişilebildiği ölçüde Ankara Üniversitesi resmî RSS/HTML duyuru, menü ve takvim kaynakları |
| Roller | Yönetici ve Kulüp Yetkilisi. Öğrenciler Flutter mobil istemcisini kullanır. |
| Diğer | Flutter/Dart, ASP.NET Core Web API, EF Core migrations, Swagger/OpenAPI, ASP.NET Core Identity, HttpClient/zamanlanmış görev, yerel bildirimler ve aşamalı FCM |

## 3. Veritabanı Tabloları (Taslak)

| Tablo | İçeriği | İlişkili tablo(lar) |
|---|---|---|
| ApplicationUsers | Giriş, rol ve temel kullanıcı bilgileri | Clubs; EventParticipants |
| Clubs | Kulüp adı, açıklama, sosyal bağlantılar, yetkili kullanıcı | ApplicationUsers; Events (1:N) |
| Events | ClubId, başlık, tarih, konum, kontenjan ve durum | Clubs; CampusLocations; EventParticipants (1:N) |
| EventParticipants | EventId, katılımcı bilgisi, başvuru durumu, belge yolu | Events (N:1) |
| Announcements | Resmî kaynak, başlık, bağlantı, yayın tarihi ve tekrar kontrol anahtarı | Bağımsız; mobil istemciye API ile sunulur |
| CampusLocations | Kampüs, bina/tür, koordinat ve erişilebilirlik bilgisi | Events (1:N) |

## 4. Liderlik Dağılımı

| Lider | Haftalar |
|---|---|
| Berkay Bozlar | 1, 3, 5, 7 (4 hafta) |
| Yiğithan Başağa | 2, 4, 6, 8, 9 (5 hafta) |

## 5. 9 Haftalık Plan

| Hafta | Lider | Yapılacak işler | Sorumlu üye(ler) |
|---|---|---|---|
| 1 | Berkay | 21 Ekim başlangıcı: kapsam ve kabul ölçütleri, public tek depo, MVC + Web API + Flutter çözüm yapısı, ilk veri modeli ve görev panosu. 25 Ekim'e kadar ilk video ve çalışan iskelet. | Berkay: web/API iskeleti ve video. Yiğithan: Flutter iskeleti ve harita denemesi. İkisi de kendi hesabından commit/push. |
| 2 | Yiğithan | ASP.NET Core Identity ile giriş; Yönetici ve Kulüp Yetkilisi rolleri; PostgreSQL için EF Core migration; kullanıcı/kulüp modeli; responsive MVC ana düzeni. | Berkay: veri modeli ve migration. Yiğithan: giriş, roller ve MVC düzeni. Karşılıklı kod inceleme ve haftalık push. |
| 3 | Berkay | Events/Etkinlik Web API'sinde tam CRUD, Swagger, validation ve Club-Events bire-çok ilişkisi. MVC portalında kulüp/etkinlik yönetimi; örnek veri ve temel testler. | Berkay: API, Swagger ve test. Yiğithan: MVC yönetim formları ve Flutter API istemcisi. İkisi de commit/push. |
| 4 | Yiğithan | 18 Kasım ilk gösterim paketi: çalışan giriş ve roller, responsive MVC portalı, Events CRUD/Swagger, Flutter'da kulüp-etkinlik akışı ve Tandoğan haritasının temel sürümü; demo provası. | Berkay: backend ve demo verisi. Yiğithan: Flutter/MVC entegrasyonu ve video. İkisi birlikte test ve gösterim. |
| 5 | Berkay | Resmî duyuru kaynağı için günlük kontrol görevi, kaynak bağlantısı ve tekrar önleme; kaynak değişikliği için yönetici girişi/elle yenileme. Resmî yemekhane menüsünün temel gösterimi. | Berkay: veri çekme, zamanlanmış görev ve API. Yiğithan: duyuru/menü mobil ekranları. İkisi de commit/push. |
| 6 | Yiğithan | Ders/sınav programı görselini galeriden seçme, saklama, yakınlaştırma, değiştirme ve silme. Resmî akademik tarihlerin gösterimi ve cihazda kişisel hatırlatıcı/yerel bildirim. | Berkay: takvim API/veri desteği. Yiğithan: görsel ve hatırlatıcı akışları. İkisi birlikte test ve haftalık push. |
| 7 | Berkay | Tandoğan haritasında bina/tesis işaretleri, arama, GPS konumu ve temel rota yönlendirmesi. Not hesaplayıcıda sınırsız kalem, ağırlık, hedef final, ulaşılamayan hedef ve baraj kontrolü. | Berkay: harita verisi/API desteği ve test. Yiğithan: harita/not hesaplayıcı mobil arayüzü. İkisi de commit/push. |
| 8 | Yiğithan | Öğrencilerin takip ettikleri kulüplerden bildirim almasının geliştirilmesi ve denenmesi; gerekirse duyuruların uygulama içinde gösterilmesi. Etkinliğe katılım, kontenjan ve belge yükleme işlemlerinin tamamlanması; kullanıcı yetkilerinin ve gizli bilgilerin korunmasının kontrol edilmesi. | Berkay: katılım API'si ve güvenlik. Yiğithan: FCM/mobil akışlar ve video. İkisi birlikte entegrasyon testi ve push. |
| 9 | Yiğithan | 23 Aralık ikinci gösterim ve teslim: yedi modülün uçtan uca testi, hata düzeltme, responsive portal kontrolü, örnek veri, README'de kurulum/migration adımları ve final video/demosu. | Berkay: backend, migration, Swagger ve README. Yiğithan: mobil paket, son entegrasyon ve video. İkisi birlikte gösterim ve son push. |
