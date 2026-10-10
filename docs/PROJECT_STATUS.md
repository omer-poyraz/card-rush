# Card Rush — Proje Durumu

_Son güncelleme: 2026-10-10 · Godot 4.7.2 · Testler: 97/97 geçti (`tools/run_tests.sh`)_

## Aşama özeti
| Aşama | Durum | Not |
|---|---|---|
| 1 Analiz ve altyapı | ✅ Tamam | Klasörler, autoload'lar, tema, açılış, ana menü, belgeler |
| 2 Oynanabilir kart oyunu | ✅ Tamam | 108 kart, tüm klasik kurallar + resmi alternatif puanlama, ev kuralları; çevrim dışı tam maç |
| 3 Yapay zekâ | ✅ Tamam | Kolay/Normal/Zor, karışık masa, 2–10 oyuncu; bot testleri |
| 4 Premium arayüz ve animasyonlar | ✅ Büyük ölçüde | Dağıtma/çekme/oynama/ceza/yön/renk/UNO/itiraz animasyonları, sesler, sonuç ekranları, konfeti. Cila maddeleri TODO'da |
| 5 Yerel ağ | ⏳ Sıradaki | |
| 6 İnternet + sesli sohbet | ⬜ | |
| 7 Reklam + IAP | ⬜ | Kardeş projede doğrulanmış eklentiler mevcut (AdMob 5.1.0, Play Billing 3.3.0) |
| 8 İlerleme, kozmetik | 🟡 Kısmi | XP/seviye/istatistik/geçmiş + profil çalışıyor; görevler, koleksiyon, mağaza yok |
| 9 Test ve yayın | ⬜ | |

## Gerçekten çalışan (doğrulandı)
- Çevrim dışı maç: Hızlı Oyna (3 bot, tek el) ve Botlara Karşı (2–10 oyuncu, zorluk, tüm kural seçenekleri).
- Kural motoru: 97 otomatik testin çoğu kurallar; 350 rastgele maç + bot maçları + arayüz üzerinden tam maç (headless) hatasız.
- Görsel doğrulama: `tools/capture.tscn` ile menü, masa, kart sayfası, ayarlar, kurallar, sonuç ekranı ekran görüntüleriyle kontrol edildi (Linux, Compatibility renderer).
- TR/EN, ayarlar (ses seviyeleri, dil, kalite, azaltılmış animasyon, renk körlüğü, titreşim, tek dokunuş, bot hızı), yerel profil + istatistik + XP.
- Klavye kısayolları (Windows), Android geri tuşu, uygulama arka plana geçince çevrim dışı maçın duraklaması.

## Henüz yok / doğrulanmadı
- Multiplayer, sesli sohbet, reklam, IAP, görevler, koleksiyon, mağaza, arkadaşlar (menüde "YAKINDA").
- Android/iOS/Windows dışa aktarımı henüz denenmedi (export_presets yok). Dokunmatik giriş gerçek cihazda test edilmedi (fare emülasyonu ile tasarlandı).
- "UNO" kelimesi marka riski taşıyor — D-12.

## Önemli dosyalar
Kurallar `scripts/rules/`, durum `scripts/game/`, botlar `scripts/ai/`, masa `scripts/ui/table/`, metinler `tools/localization/strings.py`, kurallar belgesi `docs/GAME_RULES.md`.
