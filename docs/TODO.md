# Card Rush — Yapılacaklar

## Aşama 5–6 kalanlar
- [ ] Cloudflare Worker'ı dağıt, `card_rush/online/signaling_url` ayarla, gerçek mobil ağlar arasında dene; TURN anahtarı ekle
- [ ] Lobi host devri (maç dışında, gizli durum yokken)
- [ ] Android: Wi-Fi multicast kilidi (keşif güvenilirliği) — gerekirse küçük Android eklentisi
- [ ] Sesli sohbet: Opus (TwoVoIP, MIT) ile bant genişliği azaltma; bas-konuş seçeneği; mobil cihaz testleri
- [ ] Davet bağlantısı (`cardrush://`) deep link

## Aşama 7 — Reklam ve IAP
- [ ] AdConfig (test/üretim ayrımı), AdManager, banner/geçiş/ödüllü, Premium reklam engeli, UMP onayı
- [ ] PurchaseManager (Play Billing, StoreKit), geri yükleme, idempotent işleme
- [ ] Ortak reklam etkinliği

## Aşama 8 — İlerleme ve kozmetik
- [ ] Günlük/haftalık görevler, günlük giriş ödülü, koleksiyon (kart arkaları hazır: 6 stil), masa temaları
- [ ] Arkadaşlar: yerel son oyuncular + engelleme (sunucusuz sınırlar açıkça)

## Aşama 4 cila
- [ ] Rakip koltuklarda küçük yelpaze kart arkaları
- [ ] Maç içi banner için güvenli alan (Aşama 7 ile)
- [ ] Gerçek cihazda dokunmatik ve performans testi; düşük kalite modunda masa keçesi çizimini önbelleğe alma
- [ ] Zafer animasyonları kozmetiği

## Aşama 9
- [ ] export_presets (Android AAB, iOS, Windows), ikon/splash, `legal/*.txt` dosyalarının export filtresine eklenmesi
- [ ] Mağaza metinleri, veri güvenliği formu, gizlilik politikası yayını
