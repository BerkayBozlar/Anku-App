
# AnküApp - Veritabanı Taslağı

## Veritabanı Teknolojisi
- PostgreSQL
- Entity Framework Core
- ASP.NET Core Identity
- Code First / Migrations

## 1. ApplicationUsers
Kullanıcı hesapları ve kimlik doğrulama.

Örnek alanlar:
- Id (PK)
- FullName
- Email

Kullanıcı rolleri ASP.NET Core Identity ile yönetilecektir.

## 2. Clubs
Üniversite öğrenci kulüpleri.

- Id (PK)
- Name
- Description
- SocialMediaUrl
- AuthorizedUserId (FK)

İlişki:
Bir kullanıcı birden fazla kulübün yetkilisi olabilir.

## 3. Events
Kulüplerin oluşturduğu etkinlikler.

- Id (PK)
- ClubId (FK)
- CampusLocationId (FK, opsiyonel)
- Title
- Description
- EventDate
- Capacity
- Status

İlişki:
Bir kulübün birden fazla etkinliği olabilir.

## 4. EventParticipants
Etkinlik başvuruları ve katılımcılar.

- Id (PK)
- EventId (FK)
- ParticipantInfo
- ApplicationStatus
- DocumentPath (opsiyonel)

İlişki:
Bir etkinliğe birden fazla başvuru yapılabilir.

Katılımcının kullanıcı hesabıyla ilişkisi
kimlik doğrulama tasarımında netleştirilecektir.

## 5. Announcements
Üniversite duyuruları.

- Id (PK)
- Title
- SourceUrl
- PublishedAt
- UniqueKey

UniqueKey tekrar eden duyuruları tespit etmek
için kullanılacaktır.

## 6. CampusLocations
Kampüsteki binalar ve önemli noktalar.

- Id (PK)
- CampusName
- Name
- Type
- Latitude
- Longitude
- AccessibilityInfo

İlişki:
Bir konum birden fazla etkinlikle ilişkilendirilebilir.

## Notlar
Bu belge ilk hafta hazırlanan taslak veri modelidir.
Tabloların alanları geliştirme sırasında
ihtiyaca göre genişletilebilir.

ASP.NET Core Identity kendi kullanıcı ve rol
tablolarını oluşturabilir.

Gerçek veritabanı ve EF Core Migration
çalışmaları ikinci haftada yapılacaktır.
