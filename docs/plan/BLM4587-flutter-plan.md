# BLM4587 iOS ile Mobil Uygulama Geliştirme I (Flutter) — Dönem Projesi Plan Belgesi

2026–2027 Güz Yarıyılı · Kaynak: `AnkuApp_Flutter_Proje_Plani.docx` (bu dosya belgenin birebir metin karşılığıdır; öğrenci numaraları depo herkese açık olduğu için çıkarılmıştır).

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

AnküApp, Ankara Üniversitesi öğrencilerinin akademik işlerini ve kampüs yaşamını tek bir Flutter mobil uygulamasında bir araya getirir. Uygulama Android'de çalışacak, farklı telefon ve tablet boyutlarına uyum sağlayacak; iOS desteği zaman kalırsa ayrıca değerlendirilecektir. Hedef kullanıcılar öğrenciler, kulüp yetkilileri ve yöneticilerdir.

Mobil uygulamanın yedi ana modülü Tandoğan kampüs haritası, ders ve sınav programı görseli, duyurular ve bildirimler, kulüpler ve etkinlikler, yemekhane menüsü, akademik takvim ve hatırlatıcılar ile not hesaplamadır. Giriş, ana sayfa, etkinlik listesi ve ayrıntısı, yönetim ekranları, duyuru ve menü, program ve takvim, harita ve not hesaplama akışları arasında gezinme sağlanacaktır.

Flutter istemcisi veriye yalnızca grubun ASP.NET Core Web API'si üzerinden erişir; PostgreSQL'e doğrudan bağlanmaz. API, Entity Framework Core migrations, ASP.NET Core Identity ve rol tabanlı JWT kimlik doğrulaması kullanır. Yönetici, Kulüp Yetkilisi ve Öğrenci rolleri tanımlanır. Yöneticiye özel mobil içerik yönetimi ekranları rol kontrolüyle kilitlenir; Events varlığı için GET, POST, PUT ve DELETE işlemlerinin tamamı Flutter uygulamasından yapılır. Kulüp Yetkilisinin yetkisi kendi kulübünün içeriğiyle sınırlandırılır.

Tandoğan haritası OpenStreetMap verisi ve MapLibre ile gösterilir. Üniversitenin duyuru, menü ve takvim bilgileri bir hazır API olarak değil, erişilebildiği ölçüde resmî RSS veya HTML kaynakları olarak kullanılır. Kaynak değişikliklerine karşı uygulama içi yönetici girişi ve elle yenileme seçeneği korunur. Önce uygulama içi akışlar ve yerel hatırlatıcılar tamamlanır; arka planda push bildirimleri ve ayrıntılı rota, temel işlevler kararlı olduktan sonra eklenir.

Her hafta lider en az 5 dakikalık videoyu Drive klasörüne yükler. İki üye de kendi GitHub hesabından düzenli commit ve push yapar. Kasım ayındaki vize haftası dokuz haftalık plana dahil edilmez ve o hafta video yüklenmez.

## 2. Kullanılacak Teknolojiler

| Başlık | Seçim / Açıklama |
|---|---|
| Hedef platform | Android (zorunlu); iOS isteğe bağlı, seçilmedi |
| Veritabanı | PostgreSQL |
| Web API teknolojisi | C# / ASP.NET Core Web API; EF Core migrations; ASP.NET Core Identity + JWT; validation; Swagger/OpenAPI |
| Kendi yazılan API | Events / Etkinlik: Flutter'da GET, POST, PUT ve DELETE; API'de tam CRUD, doğrulama ve Swagger testi |
| Harici API | Harici hazır API yok. Harita verisi OpenStreetMap'ten, gösterim MapLibre ile; duyuru, menü ve takvim verisi üniversitenin resmî RSS/HTML kaynaklarından alınır. |
| Roller | Yönetici, Kulüp Yetkilisi ve Öğrenci. Mobil içerik yönetimi yalnızca Yönetici rolüne; kulüp işlemleri yetki kapsamına göre açılır. |
| Flutter paketleri | dio, go_router, flutter_secure_storage, flutter_riverpod, maplibre_gl, geolocator, image_picker, flutter_local_notifications, timezone, intl; FCM aşamalı |

## 3. Veritabanı Tabloları (Taslak)

| Tablo | İçeriği | İlişkili tablo(lar) |
|---|---|---|
| ApplicationUsers | Identity kullanıcı bilgileri, roller ve temel profil alanları | Clubs; EventParticipants |
| Clubs | Kulüp adı, açıklama, sosyal bağlantılar ve yetkili kullanıcı | ApplicationUsers; Events (1:N) |
| Events | ClubId, CampusLocationId, başlık, tarih, konum, kontenjan ve durum | Clubs (N:1); CampusLocations (N:1); EventParticipants (1:N) |
| EventParticipants | EventId, UserId, katılım ve başvuru durumu, belge yolu | Events (N:1); ApplicationUsers (N:1) |
| Announcements | Resmî kaynak, başlık, bağlantı, yayın tarihi ve tekrar kontrol anahtarı | Bağımsız; mobil istemciye Web API ile sunulur |
| CampusLocations | Kampüs, bina veya tesis türü, koordinat ve erişilebilirlik bilgisi | Events (1:N) |

## 4. Liderlik Dağılımı

| Lider | Haftalar |
|---|---|
| Berkay Bozlar | 1, 2, 3, 4 (4 hafta) |
| Yiğithan Başağa | 5, 6, 7, 8, 9 (5 hafta) |

## 5. 9 Haftalık Plan

| Hafta | Lider | Yapılacak işler | Sorumlu üye(ler) |
|---|---|---|---|
| 1 | Berkay | Flutter proje iskeleti; Android emülatörde çalışan ilk ekranlar; /mobile ve /api klasörleri; Web API bağlantı ayarı; kabul ölçütleri ve görev panosu. | Berkay: API sözleşmesi ve ilk bağlantı. Yiğithan: Flutter iskeleti ve emülatör. |
| 2 | Berkay | API üzerinden giriş; Yönetici, Kulüp Yetkilisi ve Öğrenci rolleri; rol bazlı gezinme; güvenli JWT saklama; PostgreSQL modelleri ve EF Core migration. | Berkay: Identity, PostgreSQL ve migration. Yiğithan: giriş ve navigation. |
| 3 | Berkay | Events API'sinde tam CRUD, validation ve Swagger; Flutter'da yöneticiye özel etkinlik listesi, ekleme, düzenleme ve silme ekranları; hata durumları ve örnek veri. | Berkay: CRUD API, Swagger ve test. Yiğithan: mobil yönetim ekranları. |
| 4 | Berkay | Vize haftası planın dışındadır ve videosuzdur. 18 Kasım ilk gösterimi: çalışan Flutter uygulaması, API girişi ve roller, Events CRUD yönetimi, etkinlik akışı ve temel Tandoğan haritası. | Berkay: backend ve demo verisi. Yiğithan: mobil entegrasyon ve demo. |
| 5 | Yiğithan | Resmî RSS/HTML kaynakları için günlük kontrol, kaynak bağlantısı ve tekrar önleme; kaynak değişirse yönetici girişi veya elle yenileme; mobil duyuru akışı ve yemekhane menüsü. | Berkay: veri alma görevi ve Web API. Yiğithan: duyuru ve menü ekranları. |
| 6 | Yiğithan | Ders ve sınav programı görselini seçme, saklama, yakınlaştırma, değiştirme ve silme; akademik takvim; cihazda kişisel hatırlatıcı ve yerel bildirim. | Berkay: takvim verisi ve API desteği. Yiğithan: görsel ve hatırlatıcı akışları. |
| 7 | Yiğithan | MapLibre ve OpenStreetMap ile Tandoğan bina ve tesis işaretleri, arama, GPS konumu ve temel yönlendirme; not hesaplamada ağırlık, hedef final ve baraj kontrolü. | Berkay: harita verisi ve test. Yiğithan: harita ve not hesaplama arayüzü. |
| 8 | Yiğithan | Kulüp takip akışı; etkinliğe katılım, kontenjan ve başvuru durumu; yetki ve gizli bilgi kontrolleri. Önce uygulama içi bildirim, kararlıysa takip edilen kulüpler için FCM entegrasyonu. | Berkay: katılım API'si ve güvenlik. Yiğithan: takip ve bildirim akışları. |
| 9 | Yiğithan | 23 Aralık teslimi: yedi modülün uçtan uca testi, farklı cihaz boyutları, hata düzeltme, örnek veri, README kurulum ve migration adımları, sunum ve final demo. | Berkay: backend, migration, Swagger ve README. Yiğithan: mobil paket ve sunum. |

Her hafta: iki üye de kendi hesabından ayrı commit/push yapar; o haftanın lideri en az 5 dakikalık videoyu yükler.
