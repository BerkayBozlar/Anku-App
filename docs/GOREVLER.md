# AnküApp — Görev Panosu

İki dersin plan belgesi ([BLM4587 Flutter](plan/BLM4587-flutter-plan.md), [BLM4581 Web](plan/BLM4581-web-plan.md)) **aynı ürünü** anlatıyor: tek PostgreSQL veritabanı, tek ASP.NET Core Web API, bunun üzerinde bir MVC yönetim portalı ve bir Flutter mobil uygulaması. Bu pano iki belgenin haftalık işlerini birleştirip kişi bazında görevlere böler.

- **B** = Berkay Bozlar (`BerkayBozlar`), **Y** = Yiğithan Başağa (`yigithan-basaga`)
- Bir görev bitince `[ ]` → `[x]` yapıp aynı commit'e ekleyin.
- Her hafta: ikiniz de **kendi hesabınızdan** commit/push; o haftanın lideri ilgili ders için **en az 5 dk video**yu Drive'a yükler.

## Takvim ve video sorumluları

Belgelerde kesin olan tarihler: başlangıç **21 Ekim**, ilk video ve iskelet **25 Ekim**, ilk gösterim **18 Kasım**, teslim **23 Aralık**. Ara tarihler bunlardan çıkarılmıştır (hafta Pazartesi–Pazar, video Pazar'a kadar); vize haftası 9–15 Kasım varsayılmıştır, gerçek tarihle düzeltin.

| Hafta | Tarih (tahmini) | Flutter dersi lideri / videosu | Web dersi lideri / videosu |
|---|---|---|---|
| 1 | 21–25 Eki | B | B |
| 2 | 26 Eki–1 Kas | B | Y |
| 3 | 2–8 Kas | B | B |
| — | 9–15 Kas | Vize, video yok | Vize, video yok |
| 4 | 16–22 Kas (**18 Kas gösterim**) | B | Y |
| 5 | 23–29 Kas | Y | B |
| 6 | 30 Kas–6 Ara | Y | Y |
| 7 | 7–13 Ara | Y | B |
| 8 | 14–20 Ara | Y | Y |
| 9 | 21–27 Ara (**23 Ara teslim**) | Y | Y |

> **Not:** İki belgenin liderlik dağılımı farklı (Flutter: B 1–4, Y 5–9; Web: B 1-3-5-7, Y 2-4-6-8-9). Bu yüzden 2, 4, 5 ve 7. haftalarda iki dersin videosunu farklı kişiler çeker. Kasıtlı değilse belgeleri teslimden önce eşitleyin.

## Mimari kararlar (iki belgeden çıkanlar)

- Klasörler: `backend/AnkuApp.Api` (Web API), `backend/AnkuApp.Web` (MVC portal), `mobile/` (Flutter — henüz yok).
- Flutter veritabanına **hiç** bağlanmaz; her şey Web API üzerinden. Mobilde kimlik doğrulama **JWT**, MVC'de Identity cookie.
- Roller: **Yönetici**, **Kulüp Yetkilisi**, **Öğrenci**. Kulüp Yetkilisi yalnız kendi kulübünün içeriğini yönetir.
- Events CRUD **iki yerde** olmalı: MVC portalında yönetim formları (Web dersi) ve Flutter'da yöneticiye özel GET/POST/PUT/DELETE ekranları (Flutter dersi).
- Harici hazır API yok: harita OpenStreetMap + MapLibre; duyuru/menü/takvim resmî RSS/HTML'den günlük görevle çekilir, tekrar önleme anahtarı + yönetici elle giriş/yenileme yedeği.
- Sıra: önce uygulama içi akışlar ve yerel hatırlatıcılar; FCM push ve ayrıntılı rota temel işlevler kararlı olunca.
- Flutter paketleri: dio, go_router, flutter_secure_storage, flutter_riverpod, maplibre_gl, geolocator, image_picker, flutter_local_notifications, timezone, intl; FCM sonra.

## Hafta 1 — İskelet (21–25 Eki)

- [x] **B** ASP.NET Core MVC + Web API projeleri, `AnkuApp.slnx`, `/api/health` ([PR #1](https://github.com/BerkayBozlar/Anku-App/pull/1))
- [x] **B** İlk veri modeli taslağı — [veritabani-taslagi.md](veritabani-taslagi.md) ([PR #2](https://github.com/BerkayBozlar/Anku-App/pull/2))
- [ ] **B** API sözleşmesi: Flutter'ın çağıracağı ilk uç noktalar (auth, events) — istek/yanıt örnekleriyle `docs/api-sozlesmesi.md`
- [ ] **B** İlk video (her iki ders için, B lider)
- [x] **Y** `mobile/` altında Flutter projesi (`tr.edu.ankara.anku_app`), Android emülatörde çalışan ilk ekranlar: ana sayfa, 7 modül kartı, alt gezinme
- [x] **Y** Web API bağlantı ayarı: `API_BASE_URL` (emülatörde `http://10.0.2.2:5098`), dio ile `/api/health` sonucu ana sayfadaki kartta
- [x] **Y** Harita denemesi: maplibre_gl + OSM ile Tandoğan merkezli harita ekranı
- [x] **B+Y** Görev panosu (bu belge)
- [ ] **B+Y** Kabul ölçütleri: yedi modülün her biri için "bitti" tanımı (aşağıdaki modül listesine birer satır)
- [ ] **Y** Kendi hesabından ilk commit/push

## Hafta 2 — Kimlik doğrulama ve veri katmanı

- [ ] **B** Npgsql + EF Core, `AppDbContext`, Users/Clubs/Events/EventParticipants/Announcements/CampusLocations varlıkları, ilk migration
- [ ] **B** ASP.NET Core Identity (`ApplicationUser`), 3 rolün seed'i, örnek yönetici/kulüp yetkilisi/öğrenci hesapları
- [ ] **B** API'de JWT üretimi: `POST /api/auth/login` (+ gerekiyorsa `register`), rol claim'leri
- [ ] **Y** MVC'de Identity ile giriş/çıkış, Yönetici ve Kulüp Yetkilisi için rol bazlı menü, responsive ana düzen (`_Layout`)
- [ ] **Y** Flutter giriş ekranı, token'ı flutter_secure_storage'da saklama, dio interceptor ile `Authorization` başlığı
- [ ] **Y** go_router ile rol bazlı gezinme (Öğrenci / Kulüp Yetkilisi / Yönetici), riverpod ile oturum durumu
- [ ] **B+Y** Karşılıklı kod inceleme (her PR'ı diğeri onaylasın)

> İki belge bu haftayı farklı bölüyor (Flutter belgesi Identity'yi B'ye, Web belgesi "giriş, roller"i Y'ye veriyor). Yukarıdaki bölüşüm bir öneri: Identity/JWT altyapısı B, MVC ve Flutter giriş arayüzleri Y. Kendi aranızda netleştirin.

## Hafta 3 — Events CRUD

- [ ] **B** `EventsController`: GET (liste + detay), POST, PUT, DELETE; DTO + validation; Club-Events 1:N
- [ ] **B** Swagger UI (şu an yalnız `AddOpenApi` var), JWT ile Swagger'dan test; yetki: Yönetici her şey, Kulüp Yetkilisi kendi kulübü
- [ ] **B** Örnek veri (kulüpler, etkinlikler, Tandoğan konumları) ve temel API testleri
- [ ] **Y** MVC portalında kulüp ve etkinlik yönetim formları (liste, ekle, düzenle, sil, doğrulama mesajları)
- [ ] **Y** Flutter API istemcisi (events repository) ve yöneticiye özel etkinlik liste/ekle/düzenle/sil ekranları; hata ve boş durumlar

## Vize haftası (9–15 Kas, tahmini) — plan dışı, video yok

## Hafta 4 — 18 Kasım ilk gösterim

- [ ] **B** Backend kararlılığı ve demo verisi
- [ ] **Y** Flutter'da öğrenci için kulüp-etkinlik akışı (liste → detay)
- [ ] **Y** Tandoğan haritasının temel sürümü
- [ ] **Y** Flutter/MVC entegrasyonu
- [ ] **B+Y** Demo provası: giriş + roller, responsive MVC portalı, Events CRUD (portal + Flutter + Swagger), etkinlik akışı, harita

## Hafta 5 — Duyurular ve yemekhane menüsü

- [ ] **B** Resmî duyuru kaynağı için günde bir çalışan zamanlanmış görev (HttpClient + BackgroundService), kaynak bağlantısı, `UniqueKey` ile tekrar önleme
- [ ] **B** Kaynak bozulursa: yöneticinin elle duyuru girişi ve "şimdi yenile" uç noktası/portal butonu
- [ ] **B** Yemekhane menüsü verisi ve API'si
- [ ] **Y** Flutter duyuru akışı ve yemekhane menüsü ekranları

## Hafta 6 — Ders programı görseli, akademik takvim, hatırlatıcılar

- [ ] **B** Akademik takvim verisi ve API desteği
- [ ] **Y** Ders/sınav programı görseli: image_picker ile galeriden seçme, cihazda saklama, yakınlaştırma, değiştirme, silme
- [ ] **Y** Akademik takvim ekranı; kişisel hatırlatıcılar ve flutter_local_notifications + timezone ile yerel bildirim

## Hafta 7 — Harita ve not hesaplayıcı

- [ ] **B** CampusLocations verisi (bina/tesis, koordinat, erişilebilirlik) ve API; test
- [ ] **Y** MapLibre + OSM ile Tandoğan işaretleri, arama, geolocator ile GPS konumu, temel yönlendirme
- [ ] **Y** Not hesaplayıcı: sınırsız kalem, ağırlık, hedef final, ulaşılamayan hedef uyarısı, baraj kontrolü

## Hafta 8 — Kulüp takibi, katılım, güvenlik, bildirim

- [ ] **B** Katılım API'si: başvuru, kontenjan, başvuru durumu, belge yükleme
- [ ] **B** Güvenlik kontrolü: rol/sahiplik kontrolleri, gizli bilgilerin (bağlantı dizesi, JWT anahtarı) depoda olmaması
- [ ] **Y** Flutter kulüp takip akışı, etkinliğe başvuru ve durum ekranları
- [ ] **Y** Önce uygulama içi bildirim; kararlıysa takip edilen kulüpler ve yeni duyurular için FCM
- [ ] **B+Y** Entegrasyon testi

## Hafta 9 — 23 Aralık teslim

- [ ] **B+Y** Yedi modülün uçtan uca testi, farklı telefon/tablet boyutları, responsive portal kontrolü
- [ ] **B** Backend, migration, Swagger son hali; README'de kurulum ve migration adımları
- [ ] **Y** Mobil paket (APK), son entegrasyon, sunum
- [ ] **B+Y** Örnek veri, final video/demo, son push

## Yedi modül kontrol listesi (teslimde hepsi temel sürümüyle çalışmalı)

- [ ] Tandoğan kampüs haritası
- [ ] Ders ve sınav programı görseli
- [ ] Duyurular ve bildirimler
- [ ] Kulüpler ve etkinlikler
- [ ] Yemekhane menüsü
- [ ] Akademik takvim ve hatırlatıcılar
- [ ] Not hesaplama
