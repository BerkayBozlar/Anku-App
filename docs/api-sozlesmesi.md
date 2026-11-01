AnküApp API Sözleşmesi
Durum: 2. hafta backend uygulamasına göre güncellenmiştir (1 Kasım 2026).
Kapsam: ASP.NET Core Web API ile Flutter ve MVC istemcilerinin veri alışverişi.
Kaynak ayrımı: Kimlik doğrulama ve sağlık kontrolü bölümleri şu anda yazılmış ve yerel ortamda test edilmiş endpoint'leri; Etkinlikler bölümü ise 3. hafta için planlanan, henüz uygulanmamış sözleşmeyi gösterir.
Temel adresler ve ortak kurallar
- API'nin mevcut yerel çalıştırma adresi: http://localhost:5080
- API ile aynı bilgisayarda çalışan standart Android emülatörünün ana makine adresi: http://10.0.2.2:5080
- Bu adresler geliştirme ortamı içindir; Yiğithan'ın başka bir bilgisayarından 10.0.2.2 ile Berkay'ın bilgisayarına erişilemez. Diğer bilgisayarda API'yi ayrı çalıştırmak veya erişilebilir bir ağ adresi yapılandırmak gerekir.
- İstek/yanıt gövdelerinde temel içerik türü: application/json (hata gövdelerinde farklı içerik türleri görülebilir).
- Tarih ve saatler: ISO 8601; üretilen JWT bitiş zamanı UTC'dir (örnek: 2026-11-01T20:00:00Z).
- JSON özellik adları camelCase biçimindedir.
- Gerçek Identity rol adları, Türkçe karakter ve boşluklar korunarak, Yönetici, Kulüp Yetkilisi, Öğrenci biçimindedir. Mobil tarafta karşılaştırma yaparken bu değerler kullanılmalıdır.
Kimlik doğrulaması gerektiren isteklerde:
Authorization: Bearer <accessToken>
Yerel Android HTTP çağrılarında emülatörün ağ izinleri / cleartext HTTP politikası ayrıca yapılandırılabilir. Dağıtım ortamında HTTPS kullanılmalıdır.
Hata yanıtları (mevcut uygulama)
Önemli: İlk taslakta tüm hataların ProblemDetails döndüreceği varsayılmıştı. Mevcut AuthController henüz ortak bir hata formatı uygulamıyor. İstemci bu nedenle yalnızca tek bir hata gövdesine güvenmemelidir.
Durum	Şu anki davranış
Eksik / geçersiz RegisterRequest veya LoginRequest alanları	400 Bad Request – [ApiController] model doğrulaması; tipik olarak ValidationProblemDetails ve errors alanı
Zaten kayıtlı e-posta (register)	400 Bad Request – "Bu e-posta zaten kayıtlı." mesajı; henüz 409 değil
Identity parola kuralları vb. (register)	400 Bad Request – Identity hata nesneleri dizisi (code, description)
Hatalı e-posta/şifre (login)	401 Unauthorized – { "message": "E-posta veya şifre hatalı." }
Geçerli JWT olmadan korumalı endpoint	401 Unauthorized
JWT geçerli fakat rol / yetki yetersiz	403 Forbidden
Kayıttan sonra rol ataması başarısız	500 Internal Server Error – "Rol atanamadı."


Eksik veya geçersiz alanların hata gövdesine örnek (alan isimleri doğrulanan isteğe bağlıdır):
{
  "type": "https://tools.ietf.org/html/rfc9110#section-15.5.1",
  "title": "One or more validation errors occurred.",
  "status": 400,
  "errors": {
    "Email": ["The Email field is required."]
  }
}
Bu örnek, doğrulama hatasının biçimini gösterir; type, metin ve alan adları çalışma ortamına / doğrulamaya göre farklı olabilir. İlerleyen aşamada ortak hata biçimi standartlaştırılabilir.

Sağlık kontrolü — UYGULANDI
GET /api/health
API'nin çalıştığını doğrular. JWT gerektirmez.

Başarılı yanıt — 200 OK:
{
  "status": "ok",
  "application": "AnkuApp.Api"
}
Kimlik doğrulama — UYGULANDI
POST /api/auth/register
Yeni kullanıcı oluşturur. Dışarıdan kayıt olan herkes Öğrenci rolünü alır; istekte yönetici veya kulüp yetkilisi rolü seçilemez.

İstek:
{
  "fullName": "Örnek Öğrenci",
  "email": "ogrenci.test@example.com",
  "password": "Test1234!"
}
Başarılı yanıt — 201 Created (gerçek alan adları):
{
  "message": "Kullanıcı oluşturuldu.",
  "userId": "8c781f34-6a32-4ddb-b72d-62f68c17b964",
  "role": "Öğrenci"
}
Notlar:
- fullName, email, password gereklidir; e-posta biçimi doğrulanır.
- Parola en az 8 karakter olmalı ve mevcut Identity ayarlarına uygun büyük/küçük harf, rakam, özel karakter kurallarını sağlamalıdır.
- Kullanıcı AspNetUsers, rol ilişkisi AspNetUserRoles içine yazılır; parola düz metin saklanmaz.
- Başarılı kayıt JWT döndürmez. Giriş için ayrıca /api/auth/login çağrılmalıdır.
- Aynı e-posta tekrar kullanılırsa mevcut kod 400 verir; bu aşamada 409 Conflict beklenmemelidir.
POST /api/auth/login
Kullanıcıyı e-posta ve parola ile doğrular, rol bilgisi içeren 2 saat geçerli JWT üretir.

İstek:
{
  "email": "ogrenci.test@example.com",
  "password": "Test1234!"
}
Başarılı yanıt — 200 OK (örnek değerler):
{
  "accessToken": "eyJhbGciOiJIUzI1NiIs...",
  "expiresAt": "2026-11-01T20:00:00Z",
  "user": {
    "id": "8c781f34-6a32-4ddb-b72d-62f68c17b964",
    "fullName": "Örnek Öğrenci",
    "email": "ogrenci.test@example.com",
    "roles": ["Öğrenci"]
  }
}
Kritik: user.role adlı tekil alan yoktur; Flutter ve MVC istemcileri user.roles dizisini okumalıdır. Yetkilendirme sadece istemcideki yönlendirmeye bırakılmamalı, API'de de [Authorize] / rol kontrolleriyle korunmalıdır.

Hatalar: eksik/geçersiz alanlarda 400; yanlış e-posta veya parolada 401.
GET /api/auth/me
Zorunlu JWT: Authorization: Bearer <accessToken>.

Başarılı yanıt — 200 OK:
{
  "userId": "8c781f34-6a32-4ddb-b72d-62f68c17b964",
  "email": "ogrenci.test@example.com",
  "roles": ["Öğrenci"]
}
Geçerli token olmadan istek 401 Unauthorized döner. Bu endpoint'te fullName bulunmaz.
Geliştirme ortamı test hesapları
- admin@ankuapp.test: Yönetici
- kulup@ankuapp.test: Kulüp Yetkilisi
- ogrenci.test@example.com: Öğrenci (elle kayıt testi sırasında oluşturulduysa)
İlk iki hesap yalnızca geliştirme ortamında seed işlemiyle oluşturulur. Şifreleri yerel User Secrets içinde Seed:AdminPassword ve Seed:ClubPassword olarak saklanır; GitHub'a, belgeye veya koda yazılmamalıdır. Girişleri normal /api/auth/login üzerinden yapılır.

Entegrasyon notu: API'nin çalışması MVC portalında girişin otomatik olarak tamamlandığı anlamına gelmez; MVC tarafının bu kullanıcıları aynı Identity altyapısıyla doğrulayabildiği ayrıca test edilmelidir. Flutter JWT'yi güvenli biçimde saklamalıdır.
Etkinlikler — 3. HAFTA İÇİN PLANLANAN SÖZLEŞME (HENÜZ UYGULANMADI)
Etkinlik durumları Draft, Published ve Cancelled değerlerinden biridir.

Yetkilendirme kuralları:
- Öğrenci: Etkinlik listesini ve ayrıntısını görüntüler.
- Kulüp Yetkilisi: Görüntüler; yalnızca yetkilisi olduğu kulübün etkinliklerini oluşturur, günceller ve siler.
- Yönetici: Tüm etkinliklerde görüntüleme ve yönetim işlemlerini yapar.
- Flutter'daki ilk yönetim arayüzü yalnızca Yönetici rolüne açılır. Kulüp yetkilisinin yönetim akışı MVC portalında sunulur.
GET /api/events
Etkinlikleri filtreli ve sayfalı olarak listeler.

Örnek istek:
GET /api/events?page=1&pageSize=20&search=konser&clubId=12&from=2026-11-01T00:00:00Z
Başarılı yanıt - 200 OK:
{
  "items": [
    {
      "id": 45,
      "clubId": 12,
      "clubName": "Müzik Topluluğu",
      "campusLocationId": 3,
      "title": "Kampüs Konseri",
      "description": "Öğrenci toplulukları konseri.",
      "eventDate": "2026-11-18T15:00:00Z",
      "capacity": 250,
      "status": "Published"
    }
  ],
  "page": 1,
  "pageSize": 20,
  "totalCount": 1
}
GET /api/events/{id}
Tek etkinliğin ayrıntısını döndürür.

Başarılı yanıt - 200 OK:
{
  "id": 45,
  "clubId": 12,
  "clubName": "Müzik Topluluğu",
  "campusLocationId": 3,
  "campusLocationName": "Tandoğan Yerleşkesi",
  "title": "Kampüs Konseri",
  "description": "Öğrenci toplulukları konseri.",
  "eventDate": "2026-11-18T15:00:00Z",
  "capacity": 250,
  "status": "Published"
}
Hata: Etkinlik yoksa 404 Not Found.
POST /api/events
Yeni etkinlik oluşturur. Yönetici veya ilgili kulübün Kulüp Yetkilisi rolü gerekir.

İstek:
{
  "clubId": 12,
  "campusLocationId": 3,
  "title": "Kampüs Konseri",
  "description": "Öğrenci toplulukları konseri.",
  "eventDate": "2026-11-18T15:00:00Z",
  "capacity": 250,
  "status": "Published"
}
Başarılı yanıt - 201 Created:
{
  "id": 45,
  "clubId": 12,
  "campusLocationId": 3,
  "title": "Kampüs Konseri",
  "description": "Öğrenci toplulukları konseri.",
  "eventDate": "2026-11-18T15:00:00Z",
  "capacity": 250,
  "status": "Published"
}
Doğrulamalar:
- title zorunludur ve en fazla 200 karakterdir.
- eventDate geçmişte olamaz.
- capacity sıfırdan büyük olmalıdır.
- clubId mevcut olmalıdır.
- campusLocationId verildiyse mevcut olmalıdır.
PUT /api/events/{id}
Var olan etkinliği günceller. Yetkilendirme ve istek alanları POST /api/events ile aynıdır.

Başarılı yanıt: 204 No Content.

Hatalar:
- 400 Bad Request: Doğrulama hatası.
- 403 Forbidden: Kulüp yetkilisi başka kulübün etkinliğini değiştirmeye çalıştı.
- 404 Not Found: Etkinlik bulunamadı.
DELETE /api/events/{id}
Etkinliği siler. Yönetici veya ilgili kulübün Kulüp Yetkilisi rolü gerekir.

Başarılı yanıt: 204 No Content.

Hatalar:
- 403 Forbidden: Kullanıcının silme yetkisi yok.
- 404 Not Found: Etkinlik bulunamadı.
- 409 Conflict: Etkinlik ilişkili başvurular nedeniyle doğrudan silinemiyor.
Uygulama ve entegrasyon sırası
1. 2. hafta — yapıldı: PostgreSQL/Identity, roller, register, login, me, JWT doğrulama ve temel yetki testleri.
2. 2. hafta — entegrasyon testi bekliyor: Flutter/MVC istemcilerinde gerçek API'ye karşı oturum açma ve rol bazlı ekranlar; geliştirici makinelerinde veritabanı / User Secrets kurulumu veya uygun ağ erişimi.
3. 3. hafta — plan: Events modeli, ilişkiler, DTO'lar, doğrulamalar ve GET/POST/PUT/DELETE endpoint'leri.
4. Plan: Swagger/OpenAPI üzerinden uç noktaları ve yanıt kodlarını doğrulama; Flutter yönetim ekranlarında Events CRUD işlemlerini test etme.
Yeni endpoint veya yanıt biçimi eklendiğinde belge gerçek Controllers ve DTO koduyla birlikte güncellenmelidir.