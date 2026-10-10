# Card Rush — Yayın Kontrol Listesi

## Kullanıcı kararı bekleyenler
- [ ] **Paket kimliği:** istenen `com.poyrazyazilim.card-rush` Android'de geçersiz (`-`). Preset'lerde yer tutucu `com.poyrazyazilim.cardrush` var (`export_presets.cfg`, `project.godot card_rush/store/android_package`).
- [ ] **"UNO" kelimesi** (Mattel markası): `CALL_WORD` anahtarı tek yerden değiştirilebilir (`tools/localization/strings.py`). Mağaza metinlerinde kullanılmamalı.

## Derleme (`tools/build_release.sh`)
| Hedef | Durum |
|---|---|
| Windows x86_64 | ✅ Bu makinede üretildi (exe + webrtc dll). Windows'ta çalıştırılmadı |
| Linux (duman testi) | ✅ Üretildi, açılıp kapandı |
| Android APK (debug) | ✅ Üretildi, Android 15 emülatöründe çalıştırıldı |
| Android AAB (release) | ⬜ Yükleme anahtarı gerekir: `export/keys/cardrush-upload.keystore` + şifre (depoya girmez) |
| iOS | ⬜ macOS + Xcode + Apple Team ID gerekir; preset yalnızca Xcode projesi üretir. InAppStore eklentisi macOS'ta derlenmeli |

## Android / Google Play
- [ ] Play Console uygulaması, ürünler (products.json kimlikleri), lisans test kullanıcıları
- [ ] Veri güvenliği formu: AdMob reklam kimliği (AD_ID) ve reklam etkileşim verisi (üçüncü taraf: Google); mikrofon sesi — yalnızca oyuncular arasında canlı aktarılır, toplanmaz/saklanmaz; konum yok; hesap yok; yerel profil cihazda
- [ ] İzinler gerekçesi: RECORD_AUDIO (isteğe bağlı sesli sohbet), INTERNET/ağ durumu/Wi-Fi/multicast (yerel ağ odaları)
- [ ] Hedef kitle: 13+ önerilir (sesli sohbet + reklam); "Families" programına girilmemeli
- [ ] Gizlilik politikası yayınlanıp URL'si girilmeli (`legal/privacy_*.txt` taslak)
- [ ] Gerçek cihazlarda test: Adreno/Mali GPU'lar, düşük RAM, dokunmatik, mikrofon izni, LAN keşfi

## iOS / App Store
- [ ] AdMob iOS uygulaması + birimleri (`AdConfig.PROD_IOS`), `SKAdNetworkItems` ve ATT gereksinimi incelenmeli
- [ ] `NSMicrophoneUsageDescription` (preset'te var), `NSLocalNetworkUsageDescription` (var); UDP yayın keşfi için `com.apple.developer.networking.multicast` yetkisi Apple onayı gerektirir — yoksa iOS'ta yalnızca kod/IP/internet ile katılım
- [ ] InAppStore eklentisi, App Store Connect ürünleri; abonelik iOS'ta kapalı

## Çevrim içi
- [ ] `server/signaling-worker` dağıt, `card_rush/online/signaling_url` ayarla; TURN anahtarı (isteğe bağlı, maliyet NETWORKING.md)

## Mağaza metni taslağı (TR)
Card Rush — renkleri ve sayıları eşleştir, kartlarını ilk sen bitir! Çevrim dışı botlara karşı (3 zorluk) ya da aynı Wi-Fi'daki arkadaşlarınla oda kurup sesli sohbetle oyna. Resmi klasik kurallar, isteğe bağlı ev kuralları, 2–10 oyuncu, renk körlüğü modu, Türkçe ve İngilizce. Görünümler yalnızca kozmetiktir; oyun avantajı satılmaz.
