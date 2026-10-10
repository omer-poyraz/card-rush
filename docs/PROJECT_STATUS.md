# Card Rush — Proje Durumu

_Son güncelleme: 2026-10-10 · Godot 4.7.2 · Testler: 146/146 geçti (`tools/run_tests.sh`)_

## Aşama özeti
| Aşama | Durum | Not |
|---|---|---|
| 1 Analiz ve altyapı | ✅ Tamam | Klasörler, autoload'lar, tema, açılış, ana menü, belgeler |
| 2 Oynanabilir kart oyunu | ✅ Tamam | 108 kart, tüm klasik kurallar + resmi alternatif puanlama, ev kuralları; çevrim dışı tam maç |
| 3 Yapay zekâ | ✅ Tamam | Kolay/Normal/Zor, karışık masa, 2–10 oyuncu; bot testleri |
| 4 Premium arayüz ve animasyonlar | ✅ Büyük ölçüde | Dağıtma/çekme/oynama/ceza/yön/renk/UNO/itiraz animasyonları, sesler, sonuç ekranları, konfeti. Cila maddeleri TODO'da |
| 5 Yerel ağ | ✅ Tamam | ENet LAN + doğrudan IP, keşif, oda kodu, lobi, yeniden bağlanma, bot devralma. 17 ağ testi + iki süreçli gerçek maç |
| 6 İnternet + sesli sohbet | ✅ Kod tamam / 🟡 dağıtım | WebRTC + signaling (dev sunucu ile 3 süreçli maç testli); Cloudflare Worker yazıldı, **dağıtılmadı**. Sesli sohbet LAN/İnternet üzerinden çalışıyor (Linux'ta doğrulandı, mobilde test edilmedi) |
| 7 Reklam + IAP | ✅ Kod / 🟡 mağaza | AdMob (Android emülatöründe gerçek test banner + ödüllü reklam doğrulandı), Play Billing bağlanıyor; ürünler mağazada oluşturulmadı, iOS eklentisi yok. Ortak reklam etkinliği |
| 8 İlerleme, kozmetik | ✅ Tamam | XP/seviye, istatistik, günlük/haftalık görev, günlük giriş, jeton, koleksiyon (arka/masa/çerçeve), yerel arkadaş/engelleme |
| 9 Test ve yayın | 🟡 Kısmi | Windows + Linux + Android APK üretildi; APK Android 15 emülatöründe oynandı. AAB anahtar, iOS macOS bekliyor (RELEASE_CHECKLIST) |

## Gerçekten çalışan (doğrulandı)
- Çevrim dışı maç: Hızlı Oyna (3 bot, tek el) ve Botlara Karşı (2–10 oyuncu, zorluk, tüm kural seçenekleri).
- Kural motoru: 97 otomatik testin çoğu kurallar; 350 rastgele maç + bot maçları + arayüz üzerinden tam maç (headless) hatasız.
- Görsel doğrulama: `tools/capture.tscn` ile menü, masa, kart sayfası, ayarlar, kurallar, sonuç ekranı ekran görüntüleriyle kontrol edildi (Linux, Compatibility renderer).
- TR/EN, ayarlar (ses seviyeleri, dil, kalite, azaltılmış animasyon, renk körlüğü, titreşim, tek dokunuş, bot hızı), yerel profil + istatistik + XP.
- Klavye kısayolları (Windows), Android geri tuşu, uygulama arka plana geçince çevrim dışı maçın duraklaması.

## Henüz yok / doğrulanmadı
- Mağaza ürünleri Play Console/App Store'da yok → fiyatlar "fiyat yok", gerçek satın alma test edilmedi. iOS satın alma eklentisi (macOS'ta derlenmeli) yok.
- Küresel arkadaş listesi/davet/raporlama sunucusuz yapılamaz; yalnızca yerel son oyuncular + engelleme.
- İnternet odaları için üretim signaling sunucusu dağıtılmadı (`server/signaling-worker/README.md`); `card_rush/online/signaling_url` boş → İnternet seçeneği gerekçesiyle kapalı.
- Sesli sohbet ve ağ oyunu yalnızca Linux masaüstünde doğrulandı; Android/iOS/Windows cihaz testi yok.
- Gerçek Android telefon, iOS ve Windows'ta çalıştırılmadı (Android yalnızca emülatörde; emülatörün eski yazılım GL'i shader limitini aşıyor, ANGLE modunda sorunsuz).
- "UNO" kelimesi marka riski taşıyor — D-12.

## Önemli dosyalar
Ağ `scripts/networking/` (bkz. `docs/NETWORKING.md`), ses `scripts/voice/`, kurallar `scripts/rules/`, durum `scripts/game/`, botlar `scripts/ai/`, masa `scripts/ui/table/`, metinler `tools/localization/strings.py`, kurallar belgesi `docs/GAME_RULES.md`.
