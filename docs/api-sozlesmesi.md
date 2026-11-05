AnküApp API Sözleşmesi
Durum: 5. hafta backend ve entegrasyon uygulamasına göre güncellenmiştir (5 Kasım 2026).
Kapsam: ASP.NET Core Web API ile Flutter ve MVC istemcilerinin veri alışverişi.
Kimlik doğrulama, sağlık kontrolü, kulüpler ve etkinlikler bölümleri uygulanmış uç noktaları anlatır. API/MVC entegrasyon kontrolü ve demo verisi için docs/demo-hafta4.md belgesini kullanın.
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
- ogrenci@ankuapp.test: Öğrenci
Üç hesap yalnızca geliştirme ortamında ilgili parola ayarları mevcutsa seed işlemiyle oluşturulur. Şifreleri yerel User Secrets içinde Seed:AdminPassword, Seed:ClubPassword ve Seed:StudentPassword olarak saklanır; GitHub'a, belgeye veya koda yazılmamalıdır. Girişleri normal /api/auth/login üzerinden yapılır. Mevcut hesapların parolaları seed sırasında değiştirilmez.

Entegrasyon: MVC portalı API'nin login ucundan JWT alıp cookie oturumu oluşturur; sonraki API istekleri bu JWT ile gider. Öğrenci portal yönetimine giremez. Flutter JWT'yi flutter_secure_storage içinde saklar. Üç rolün API/MVC akışı scripts/Test-Week4Integration.ps1 ile doğrulanır.
Kulüpler — UYGULANDI (3. hafta)
Tüm uç noktalar JWT ister. MVC portalının kulüp yönetimi ve etkinlik formlarındaki kulüp seçimi bu uç noktaları kullanır.

Yetkilendirme kuralları:
- Giriş yapmış her kullanıcı: Kulüp listesini ve ayrıntısını görüntüler.
- Kulüp Yetkilisi: Yalnızca yetkilisi olduğu kulübün adını, açıklamasını ve sosyal medya bağlantısını günceller; yetkili kullanıcıyı değiştiremez.
- Yönetici: Kulüp ekler, günceller, siler ve kulübe yetkili atar.
GET /api/clubs
Kulüpleri ada göre sıralı listeler. mine=true verilirse yalnızca giriş yapan kullanıcının yetkilisi olduğu kulüpler döner.

Örnek istek:
GET /api/clubs?mine=true
Başarılı yanıt - 200 OK:
[
  {
    "id": 12,
    "name": "Müzik Topluluğu",
    "description": "Öğrenci müzik topluluğu.",
    "socialMediaUrl": "https://instagram.com/ornek",
    "authorizedUserName": "Test Kulüp Yetkilisi",
    "authorizedUserEmail": "kulup@ankuapp.test"
  }
]
authorizedUserEmail yalnızca Yönetici'ye döner; diğer rollerde null'dır. Yetkili atanmamışsa authorizedUserName ve authorizedUserEmail null'dır.
GET /api/clubs/{id}
Tek kulübün bilgisini aynı biçimde döndürür. Kulüp yoksa 404 Not Found.
POST /api/clubs
Yalnızca Yönetici. Yeni kulüp oluşturur.

İstek:
{
  "name": "Müzik Topluluğu",
  "description": "Öğrenci müzik topluluğu.",
  "socialMediaUrl": "https://instagram.com/ornek",
  "authorizedUserEmail": "kulup@ankuapp.test"
}
Başarılı yanıt: 201 Created, gövdede GET /api/clubs/{id} biçimindeki kulüp.

Doğrulamalar:
- name zorunludur, en fazla 100 karakterdir ve başka bir kulüple aynı olamaz (büyük/küçük harf duyarsız).
- description en fazla 2000 karakterdir; socialMediaUrl verilirse http veya https ile başlayan mutlak bir bağlantı olmalı (javascript: vb. reddedilir), en fazla 300 karakterdir. Boş metin "yok" sayılır.
- authorizedUserEmail isteğe bağlıdır; verilirse kayıtlı ve Kulüp Yetkilisi rolünde bir kullanıcıya ait olmalıdır. Boş/null verilirse kulübün yetkilisi kaldırılır.
- Hatalar 400 ValidationProblemDetails olarak, errors içinde alan adıyla (Name, SocialMediaUrl, AuthorizedUserEmail) döner.
PUT /api/clubs/{id}
Yönetici veya kulübün kendi Kulüp Yetkilisi. İstek gövdesi POST ile aynıdır; Kulüp Yetkilisi gönderdiğinde authorizedUserEmail yok sayılır.

Başarılı yanıt: 204 No Content. Hatalar: 400 doğrulama, 403 başka kulübü güncelleme, 404 kulüp yok.
DELETE /api/clubs/{id}
Yalnızca Yönetici. Başarılı yanıt: 204 No Content.

Hatalar:
- 404 Not Found: Kulüp bulunamadı.
- 409 Conflict: Kulübe bağlı kayıtlar (ör. etkinlikler) olduğu için silinemiyor - { "message": "Kulübe bağlı kayıtlar olduğu için silinemiyor." }. Bunun için Events → Clubs yabancı anahtarı silmede Restrict olmalıdır; Cascade olursa kulüple birlikte etkinlikleri de silinir.
Etkinlikler — UYGULANDI
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

Sorgu parametreleri (hepsi isteğe bağlı):
- page (varsayılan 1, en az 1), pageSize (varsayılan 20, 1–100). Hesaplanan sayfa başlangıcı int.MaxValue değerini aşarsa 400 döner.
- search: Başlıkta büyük/küçük harf duyarsız arama.
- clubId: Yalnızca bu kulübün etkinlikleri.
- from: eventDate >= from (UTC). Yaklaşan etkinlikler için from=şimdi.
- to: eventDate < to (UTC). Geçmiş etkinlikler için to=şimdi.
- order: asc (varsayılan, en yakın tarih önce) veya desc (en yeni tarih önce). Liste her zaman eventDate'e göre sıralanır; eşit tarihlerde id'ye göre.
- status: Draft, Published veya Cancelled (büyük/küçük harf duyarsız). Filtre toplam sayıya ve sayfalamaya da uygulanır. Geçersiz değer 400 döner.

Öğrenci rolünde taslak etkinlikler, filtre verilmese bile listeye ve toplam sayıya girmez. Taslak kimliğiyle ayrıntı istendiğinde 404 döner. Yönetici ve Kulüp Yetkilisi yönetim akışlarında taslakları görmeye devam eder.

Öğrenci Keşfet ekranı yaklaşan ve geçmiş listelerde `status=Published` gönderir. İptal edilen etkinlik yayındaki listeden çıkar; daha önce açılmış ayrıntı yenilenirse `Cancelled` durumu gösterilir.

Portal ve mobil yönetim ekranları "Yaklaşan" sekmesi için from=<şimdi>&order=asc, "Geçmiş" sekmesi için to=<şimdi>&order=desc gönderir.
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
Hata: Etkinlik yoksa veya öğrenci bir taslağı açmaya çalışıyorsa 404 Not Found.
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
- eventDate gelecekte olmalıdır (UTC'ye dönüştürülerek saklanır). Geçmiş demo kayıtları yalnızca veri hazırlama komutuyla oluşturulur; normal POST/PUT geçmiş tarihi reddeder.
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
Not: Katılım tablosu ve ilişkili başvuru nedeniyle 409 davranışı 8. haftanın kapsamındadır; mevcut etkinlik silme işleminde henüz bu kontrol yoktur.
Uygulama ve entegrasyon sırası
1. 2. hafta — yapıldı: PostgreSQL/Identity, roller, register, login, me, JWT doğrulama ve temel yetki testleri.
2. 2–4. hafta — uygulandı: Flutter/MVC oturumları ve rol bazlı akışlar. Her geliştirici kendi veritabanı ve User Secrets ayarlarını yapmalıdır.
3. 3. hafta — uygulandı: Events modeli, Club-Events 1:N ilişkisi, DTO'lar, doğrulamalar, GET/POST/PUT/DELETE ve Development ortamında /swagger ile /openapi/v1.json.
4. 4. hafta — doğrulandı: Tekrar çalıştırılabilir --seed-demo komutu, JWT/Swagger, rol ve sahiplik sınırları, MVC/API veri paylaşımı, yayın görünürlüğü, saat dönüşümü ve doğrulama testleri. Demo verisi dahil 45 otomatik entegrasyon kontrolü.
Yeni endpoint veya yanıt biçimi eklendiğinde belge gerçek Controllers ve DTO koduyla birlikte güncellenmelidir.

## 5. hafta — Duyurular ve ortak öğle menüsü (uygulandı)

Bu bölüm `feature/week5-announcements-meals` branch'indedir. [Kurulum, kaynaklar ve test rehberi](hafta5-backend.md). Tüm uç noktalar JWT ister; okuma giriş yapan her role, yönetim ve yenileme yalnızca **Yönetici** rolüne açıktır. Öğrenci ve Kulüp Yetkilisi yazma/yenileme çağrılarında 403 alır.

### Duyurular

`GET /api/announcements?page=1&pageSize=20&search=duyuru`

Sayfa en az 1, pageSize 1–100. Büyük sayfa başlangıçları 400 ile reddedilir. Başlıkta büyük/küçük harf duyarsız arama yapılır. Sıralama yayın zamanı ve id azalan biçimdedir.

```json
{
  "items": [
    {
      "id": 1,
      "title": "Örnek duyuru",
      "summary": "HTML içermeyen düz metin özeti.",
      "sourceName": "Ankara Üniversitesi Öğrenci İşleri",
      "sourceUrl": "https://oidb.ankara.edu.tr/duyurular/",
      "uniqueKey": "<64-karakter-SHA256>",
      "publishedAt": "2026-11-05T10:00:00Z",
      "retrievedAt": "2026-11-05T12:00:00Z",
      "isManual": false
    }
  ],
  "page": 1,
  "pageSize": 20,
  "totalCount": 1
}
```

`GET /api/announcements/{id}` aynı öğe biçimini döndürür; kayıt yoksa 404.

`POST /api/announcements` yönetici elle girişi, `PUT /api/announcements/{id}` yönetici düzenlemesidir:

```json
{
  "title": "Örnek elle duyuru",
  "summary": "İsteğe bağlı düz metin özet.",
  "sourceName": "Ankara Üniversitesi Öğrenci İşleri",
  "sourceUrl": "https://oidb.ankara.edu.tr/duyurular/",
  "publishedAt": "2026-11-05T10:00:00Z"
}
```

Başlık zorunlu/en fazla 300, özet en fazla 4000, kaynak adı zorunlu/en fazla 150 karakterdir. Kaynak bağlantısı en fazla 2000 karakter, ankara.edu.tr veya alt alanında http/https olmalıdır; kullanıcı bilgisi/özel port kabul edilmez. Yayın tarihi zorunlu, 2000–2100 aralığında ve saat dilimi içeren ISO 8601 biçimindedir; UTC saklanır. İstemci `uniqueKey`, `retrievedAt` ve `isManual` göndermez. POST 201 ve öğe, PUT 204 döner. Aynı normalize kaynak bağlantısı zaten varsa 409 `{ "message": "..." }`; geçersiz alanlar 400 ValidationProblemDetails. URL fragment'i ve sondaki slash tekrar anahtarını değiştirmez. Elle oluşturma/düzenleme `isManual=true` yapar.

`DELETE /api/announcements/{id}`: yönetici, başarı 204, olmayan kayıt 404. Kaynakta hâlâ bulunan duyuru bir sonraki içe aktarmada yeniden gelebilir.

### Yemekhane menüsü

Bu sürüm SKS'nin bütün kampüslerde sunulan ortak **öğle** menüsüdür; kampüs/akşam/vejetaryen seçimi yoktur.

`GET /api/meal-menus/today` Türkiye tarihini kullanır:

```json
{
  "date": "2026-11-05",
  "menu": {
    "id": 1,
    "menuDate": "2026-11-05",
    "dishes": ["Örnek çorba", "Örnek ana yemek", "Örnek pilav", "Örnek tatlı"],
    "totalCalories": 1200,
    "sourceName": "Ankara Üniversitesi SKS",
    "sourceUrl": "https://sksbasvuru.ankara.edu.tr/kayit/moduller/yemeklistesi/aylikmenu.php",
    "retrievedAt": "2026-11-05T12:00:00Z",
    "isManual": false
  },
  "message": null
}
```

Menü yoksa **200** ile `{ "date": "2026-11-05", "menu": null, "message": "Bugün için yayımlanmış öğle menüsü bulunmuyor." }` döner. Eski bir günün menüsü bugün için kullanılmaz.

`GET /api/meal-menus?from=2026-11-01&to=2026-11-07` yanıtı `{ "items": [<menü>], "from": "2026-11-01", "to": "2026-11-07" }`. Her iki sınır dahildir, tarih artan sıralanır. Varsayılan başlangıç bugün, bitiş başlangıç +6 gündür. En fazla 63 gün istenebilir; ters/uzun aralık 400. Tarihler yalnız gün bilgisidir; Flutter bunları UTC'ye/yerel saate çevirmemelidir. Menü yoksa `items: []`.

`GET /api/meal-menus/{id}`: tek menü veya 404.

`POST /api/meal-menus` ve `PUT /api/meal-menus/{id}` yönetici isteği:

```json
{
  "menuDate": "2026-11-05",
  "dishes": ["Örnek çorba", "Örnek ana yemek"],
  "totalCalories": null,
  "sourceName": "Ankara Üniversitesi SKS",
  "sourceUrl": "https://sks.ankara.edu.tr/yemek-hizmetleri-2/"
}
```

Tarih zorunlu, 2000–2100 aralığındadır. `dishes` 1–8 adet boş olmayan, en fazla 300 karakterlik yemek adı içerir. `totalCalories` isteğe bağlıdır; verilirse 1–20000 arasıdır, yaklaşık enerji bilgisidir. Kaynak adı/linki duyuru ile aynı kuralları taşır. POST 201 ve öğe, PUT 204; aynı tarihte menü varsa 409. Elle düzenlenen menü `isManual=true` olur ve kaynak yenilemesi tarafından üzerine yazılmaz. `DELETE /api/meal-menus/{id}`: yönetici, 204 veya 404. Resmî kaynaktan silinen bir menü sonraki yenilemede yeniden gelebilir.

### Kaynak yenileme ve durumu

- `POST /api/announcements/refresh`: RSS kaynağını hemen kontrol eder.
- `POST /api/meal-menus/refresh`: resmî aylık menüyü hemen kontrol eder.
- İkisi de yalnız Yönetici rolüne açıktır; istek gövdesi gerekmez. Kaynak adresi kullanıcı isteğinden alınmaz.
- Başarı 200: `{ "success": true, "imported": 10, "changed": 0, "error": null, "skipped": false, "busy": false }`. `imported` kaynaktan okunan kayıt sayısıdır; `changed` yeni duyuru veya eklenen/güncellenen menü sayısıdır. Menü değişmemiş olsa da yeniden yazılıp sayılabilir; bu değer yeni menü sayısı olarak yorumlanmamalıdır.
- Kaynak hatası 503: `{ "message": "Resmî kaynak okunamadı veya biçimi değişti. Mevcut veriler korundu; elle giriş yapabilir veya tekrar yenileyebilirsiniz." }`. Mevcut liste/detay çağrıları çalışmaya devam eder. Aynı kaynak için devam eden başka yenileme varsa 409 ve açıklayıcı mesaj.
- `GET /api/content-sync`: yalnız Yönetici; `id`, `lastAttemptAt`, `lastSuccessAt`, `lastError` alanlı dizi. Henüz denenmemiş kaynak için kayıt olmayabilir. Zamanlar UTC, başarılı yenilemede hata null olur. Sonraki başarısız deneme son başarı zamanını silmez.

MVC portalı yenileme çağrılarını CSRF korumalı POST formlarıyla yapar. Öğrenci mobil ekranları yalnızca okuma uç noktalarını kullanır; kaynak bağlantısını haricî tarayıcıda açabilir ve boş/hata durumlarını ayrı gösterebilir.
