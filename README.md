# Ankü-App
Ankara University Campus Management Web Portal and Flutter Mobile Application

## Proje Belgeleri
- [Görev panosu (haftalık görevler, kim ne yapıyor)](docs/GOREVLER.md)
- [BLM4587 Flutter plan belgesi](docs/plan/BLM4587-flutter-plan.md)
- [BLM4581 Web plan belgesi](docs/plan/BLM4581-web-plan.md)
- [Veritabanı taslağı](docs/veritabani-taslagi.md)
- [4. hafta ilk gösterim ve entegrasyon rehberi](docs/demo-hafta4.md)
- [5. hafta duyuru/menü API'si, kurulum ve test rehberi](docs/hafta5-backend.md)

## Haftalık Proje Videoları
[Haftalık Proje Videoları – Google Drive](https://drive.google.com/drive/folders/1nl9wWlVjwhCP9dYb0tzGQ9k32NIIHGIA?usp=sharing)

Her hafta yapılan geliştirmeler, görev dağılımı ve çalışan uygulamanın gösterimi bu bağlantıdan ulaşabilirsiniz.

## Yerel çalıştırma

Backend ve portal .NET 10, veri katmanı PostgreSQL kullanır. Bağlantı dizesi, JWT ayarları ve demo parolalarını API projesinin yerel user-secrets ayarlarında tanımlayın; [kurulum ve demo rehberi](docs/demo-hafta4.md) adımları içerir.

```powershell
dotnet tool restore
dotnet ef database update --project backend/AnkuApp.Api -- --environment Development
dotnet run --project backend/AnkuApp.Api --launch-profile http -- --seed-demo
dotnet run --project backend/AnkuApp.Api --launch-profile http
```

`--seed-demo` yalnızca Development ortamında çalışır; eksik demo verisini ekleyip çıkar. İkinci terminalde `dotnet run --project backend/AnkuApp.Web --launch-profile http` ile portalı açın. API `http://localhost:5080`, Swagger `http://localhost:5080/swagger`, portal `http://localhost:5025` adresindedir. Flutter kurulumu için [mobil README](mobile/README.md).
