# Card Rush — Yapılacaklar

## Aşama 5 — Yerel ağ (sıradaki)
- [ ] NetworkManager + adaptörler (Offline / ENet LAN / doğrudan IP), LAN oda keşfi (UDP yayını)
- [ ] RoomManager: oda kodu, bekleme odası, hazır durumu, bot ekleme, kural profili gösterimi, host başlatır
- [ ] NetworkMatchClient: eylem isteği (seq + sürüm), redakte görünüm/olay alımı
- [ ] Kopma: koltuk koruma, yeniden bağlanma tokenı, bot devralma, yinelenen mesaj reddi
- [ ] Host ayrılması: yeniden bağlanma süresi; güvenli devir ya da maçı bitirme
- [ ] Testler: iki/çok süreçli yerel ENet testi, gizli kart sızıntısı, sahte koltuk

## Aşama 6 — İnternet ve sesli sohbet
- [ ] Bağlantı yöntemlerini araştır ve belgele (WebRTC GDExtension, signaling, TURN maliyeti)
- [ ] Sesli sohbet modülleri (VoiceChatManager, VoiceConnection, VoiceParticipant, VoiceSettings, VoicePermissionManager)

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
