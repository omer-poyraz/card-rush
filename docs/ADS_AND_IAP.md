# Card Rush — Reklam ve Uygulama İçi Satın Alma

## Reklam (AdMob)
- Eklenti: Poing Studios Godot AdMob 5.1.0 (MIT, `addons/admob`). Android'de gerçek SDK; iOS'ta ikili var ama yayın öncesi iOS AdMob uygulaması gerekir.
- Kimlikler `scripts/ads/ad_config.gd` (`AdConfig`): uygulama `ca-app-pub-8602764456287198~3978960722` (ayrıca `project.godot [admob]`), banner `/1754278757`, geçiş `/6357712051`, ödüllü `/9441197085`. Bunlar herkese açık kimliklerdir, gizli değil.
- **Release derlemeler gerçek birimleri kullanır** (telefon testi: `Android APK (phone test)` preset'i release + debug anahtarıyla imzalı → `export/android/CardRush-phone.apk`, günlükte `test_units=false` doğrulandı). **Debug derlemeler her zaman Google test birimlerini kullanır** (`card_rush/ads/use_production_in_debug` bilerek açılmadıkça). Gerçek reklamlara tıklamayın.
- iOS: `PROD_IOS` boş → iOS sürümünde de test birimleri. AdMob konsolunda iOS uygulaması + birimleri oluşturup `PROD_IOS` ve `project.godot` `admob/general/ios/app_id` doldurulmalı.
- Arka uçlar: `admob` (Android/iOS + eklenti), `none` (Windows/masaüstü: reklam yok, hata yok), `mock` (yalnızca debug `--mock-ads` / `CARDRUSH_MOCK_ADS=1` ve testler; gerçek reklam değildir).
- İzin: Google UMP onay formu açılışta (gerekli bölgelerde); Ayarlar'da "Reklam gizlilik seçenekleri" (gerekliyse).
- **Banner kullanılmıyor** (sahip kararı, 2026-10-10: alttaki butonları kapatıyordu). Yalnızca geçiş ve ödüllü reklam. Banner birimi `/1754278757` AdConfig'de yorum olarak duruyor.
- Geçiş: yalnızca maç sonucu ekranından çıkarken; ilk 2 maçtan önce yok, en az 2 maçta bir ve 150 sn aralıkla; yüklü değilse beklemeden devam.
- Ödüllü: isteğe bağlı, yalnızca reklam gerçekten yüklüyse teklif edilir, günlük 10 sınırı; ödül **yalnızca SDK ödül geri çağrısında**, benzersiz anahtarla bir kez (kapama ödül değildir). Ödül kozmetik jetondur.
- Premium: tüm reklam istekleri durur (yalnızca gizleme değil; `destroy_all`).
- Ortak reklam etkinliği: oda sahibi lobide önerir; her oyuncu kendi cihazında kabul/ret; oyuncu başına durum takibi; katılmayan cezalandırılmaz; aktif el sırasında başlatılamaz.

## Satın alma
- Android: GodotGooglePlayBilling 3.3.0 (MIT, Play Billing Library 9.1). iOS: resmi `InAppStore` eklentisi **macOS'ta derlenip** `ios/plugins` altına eklenmeli (bu depoda yok → iOS'ta mağaza "kullanılamıyor" gösterir).
- Ürünler `data/store/products.json`: `cardrush_premium` (tek seferlik), `cardrush_premium_monthly` / `_yearly` (abonelik, **yalnızca Android**), `cardrush_pack_neon` (kozmetik paket). Aynı kimliklerle Play Console / App Store Connect'te oluşturulmalı; oluşturulana kadar arayüz "fiyat yok" gösterir ve satın alma butonu kapalıdır (sahte fiyat yok).
- Haklar mağazadan doğrulanır; yerel kayıt yalnızca mağaza erişilemezken 30 güne kadar önbellek; masaüstünde kayıt dosyasına asla güvenilmez. Mağazanın tam anlık görüntüsü iadeleri/biten abonelikleri kaldırır. Yinelenen satın alma olayları idempotent. Geri yükleme butonu ve abonelik yönetimi bağlantısı var.
- Sunucusuz sınır: makbuzlar sunucuda doğrulanmıyor (Play Developer API / App Store Server API sunucu gerektirir). Bu, istemci tarafında hileye karşı tam koruma değildir; kozmetik/reklamsızlık ürünleri için kabul edilen risk. iOS aboneliği bu yüzden kapalı.

## Doğrulama
- Otomatik: `tests/unit/test_monetization.gd` (19 test, mock arka uçlar).
- **Android 15 emülatöründe gerçek SDK ile**: test banner'ı yüklendi; ödüllü test reklamı izlendi, SDK "Reward granted" → jeton 0→30 tek sefer; Play Billing arka ucu bağlandı (`backend=google_play`). Gerçek satın alma test edilmedi (Play Console'da ürün ve lisans test kullanıcısı gerekir).
