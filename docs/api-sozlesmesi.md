# AnküApp İlk API Sözleşmesi

Bu belge, Flutter mobil uygulaması ile ASP.NET Core Web API arasındaki ilk uç nokta sözleşmesini tanımlar. Birinci hafta için kimlik doğrulama ve etkinlik akışlarının beklenen istek ve yanıt yapıları belirlenmiştir. Uç noktalar ikinci ve üçüncü haftalarda uygulanırken bu sözleşme esas alınacak, ihtiyaç hâlinde geriye dönük uyumluluk gözetilerek güncellenecektir.

## Temel adresler

- Bilgisayarda: `http://localhost:5098`
- Android emülatöründe: `http://10.0.2.2:5098`
- İçerik türü: `application/json`
- Tarih ve saatler: ISO 8601, UTC (`2026-11-18T10:30:00Z`)

Kimlik doğrulama gerektiren isteklerde JWT şu başlıkla gönderilir:

```http
Authorization: Bearer <token>
```

Roller `Yonetici`, `KulupYetkilisi` ve `Ogrenci` olarak taşınır. API yanıt alanları JSON içinde `camelCase` biçimindedir.

## Ortak hata yanıtı

Doğrulama ve iş kuralı hataları ASP.NET Core `ProblemDetails` biçiminde döner.

```json
{
  "type": "https://httpstatuses.com/400",
  "title": "Doğrulama hatası",
  "status": 400,
  "detail": "Gönderilen bilgiler geçerli değil.",
  "errors": {
    "title": ["Başlık zorunludur."]
  }
}
```

Temel durum kodları:

| Kod | Anlamı |
|---|---|
| `200 OK` | İstek başarıyla tamamlandı |
| `201 Created` | Yeni kayıt oluşturuldu |
| `204 No Content` | Güncelleme veya silme tamamlandı |
| `400 Bad Request` | Doğrulama ya da iş kuralı hatası |
| `401 Unauthorized` | Token yok, geçersiz veya süresi dolmuş |
| `403 Forbidden` | Kullanıcının işlem için rolü veya sahipliği uygun değil |
| `404 Not Found` | İstenen kayıt bulunamadı |
| `409 Conflict` | Aynı kayıt ya da çakışan işlem mevcut |

## Sağlık kontrolü

### `GET /api/health`

API'nin çalıştığını doğrular. Kimlik doğrulama gerektirmez.

Başarılı yanıt - `200 OK`:

```json
{
  "status": "ok",
  "application": "AnkuApp.Api"
}
```

## Kimlik doğrulama

### `POST /api/auth/login`

Kullanıcıyı e-posta ve parola ile doğrular, rol bilgisi içeren JWT üretir.

İstek:

```json
{
  "email": "ogrenci@ankara.edu.tr",
  "password": "OrnekParola123!"
}
```

Başarılı yanıt - `200 OK`:

```json
{
  "accessToken": "eyJhbGciOiJIUzI1NiIs...",
  "expiresAt": "2026-10-26T18:30:00Z",
  "user": {
    "id": "8c781f34-6a32-4ddb-b72d-62f68c17b964",
    "fullName": "Örnek Öğrenci",
    "email": "ogrenci@ankara.edu.tr",
    "role": "Ogrenci"
  }
}
```

Hatalar:

- `400 Bad Request`: E-posta veya parola alanı eksik.
- `401 Unauthorized`: E-posta ya da parola yanlış.

### `POST /api/auth/register`

Öğrenci hesabı oluşturur. İlk sürümde yalnızca `Ogrenci` rolüyle kayıt açılır; yönetici ve kulüp yetkilisi rolleri sistem tarafından atanır.

İstek:

```json
{
  "fullName": "Örnek Öğrenci",
  "email": "ogrenci@ankara.edu.tr",
  "password": "OrnekParola123!"
}
```

Başarılı yanıt - `201 Created`:

```json
{
  "id": "8c781f34-6a32-4ddb-b72d-62f68c17b964",
  "fullName": "Örnek Öğrenci",
  "email": "ogrenci@ankara.edu.tr",
  "role": "Ogrenci"
}
```

Hatalar:

- `400 Bad Request`: Alanlar geçersiz veya parola kurallarını karşılamıyor.
- `409 Conflict`: E-posta adresi daha önce kullanılmış.

## Etkinlikler

Etkinlik durumları `Draft`, `Published` ve `Cancelled` değerlerinden biridir.

Yetkilendirme kuralları:

- `Ogrenci`: Etkinlik listesini ve ayrıntısını görüntüler.
- `KulupYetkilisi`: Görüntüler; yalnızca yetkilisi olduğu kulübün etkinliklerini oluşturur, günceller ve siler.
- `Yonetici`: Tüm etkinliklerde görüntüleme ve yönetim işlemlerini yapar.
- Flutter'daki ilk yönetim arayüzü yalnızca `Yonetici` rolüne açılır. Kulüp yetkilisinin yönetim akışı MVC portalında sunulur.

### `GET /api/events`

Etkinlikleri filtreli ve sayfalı olarak listeler.

Örnek istek:

```http
GET /api/events?page=1&pageSize=20&search=konser&clubId=12&from=2026-11-01T00:00:00Z
```

Başarılı yanıt - `200 OK`:

```json
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
```

### `GET /api/events/{id}`

Tek etkinliğin ayrıntısını döndürür.

Başarılı yanıt - `200 OK`:

```json
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
```

Hata: Etkinlik yoksa `404 Not Found`.

### `POST /api/events`

Yeni etkinlik oluşturur. `Yonetici` veya ilgili kulübün `KulupYetkilisi` rolü gerekir.

İstek:

```json
{
  "clubId": 12,
  "campusLocationId": 3,
  "title": "Kampüs Konseri",
  "description": "Öğrenci toplulukları konseri.",
  "eventDate": "2026-11-18T15:00:00Z",
  "capacity": 250,
  "status": "Published"
}
```

Başarılı yanıt - `201 Created`:

```json
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
```

Doğrulamalar:

- `title` zorunludur ve en fazla 200 karakterdir.
- `eventDate` geçmişte olamaz.
- `capacity` sıfırdan büyük olmalıdır.
- `clubId` mevcut olmalıdır.
- `campusLocationId` verildiyse mevcut olmalıdır.

### `PUT /api/events/{id}`

Var olan etkinliği günceller. Yetkilendirme ve istek alanları `POST /api/events` ile aynıdır.

Başarılı yanıt: `204 No Content`.

Hatalar:

- `400 Bad Request`: Doğrulama hatası.
- `403 Forbidden`: Kulüp yetkilisi başka kulübün etkinliğini değiştirmeye çalıştı.
- `404 Not Found`: Etkinlik bulunamadı.

### `DELETE /api/events/{id}`

Etkinliği siler. `Yonetici` veya ilgili kulübün `KulupYetkilisi` rolü gerekir.

Başarılı yanıt: `204 No Content`.

Hatalar:

- `403 Forbidden`: Kullanıcının silme yetkisi yok.
- `404 Not Found`: Etkinlik bulunamadı.
- `409 Conflict`: Etkinlik ilişkili başvurular nedeniyle doğrudan silinemiyor.

## Uygulama sırası

1. İkinci hafta Identity kullanıcıları, roller, JWT ayarları ve `POST /api/auth/login` uygulanır.
2. Üçüncü hafta Events varlığı, DTO'lar, doğrulamalar ve tam CRUD uç noktaları uygulanır.
3. Swagger/OpenAPI üzerinde durum kodları ve örnek gövdeler doğrulanır.
4. Flutter istemcisi bu sözleşmeye göre giriş ve etkinlik akışlarına bağlanır.
