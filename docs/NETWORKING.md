# Card Rush — Çok Oyunculu ve Sesli Sohbet

## Bağlantı yöntemleri (adaptörler)
| Yöntem | Teknoloji | Sunucu | Durum |
|---|---|---|---|
| Çevrim dışı | Yerel `MatchAuthority` | Yok | ✅ |
| Yerel ağ (aynı Wi-Fi) | ENet (UDP 47810) + UDP yayın keşfi (47811) | Yok | ✅ testli (aynı süreç + iki süreç) |
| Doğrudan IP | ENet | Yok (host erişilebilir olmalı) | ✅ testli (localhost). İnternette yalnızca port yönlendirme/ortak VPN ile |
| İnternet | WebRTC veri kanalları (`addons/webrtc_native` 1.2.2, MIT) + signaling | Signaling gerekli, TURN isteğe bağlı | ✅ dev signaling ile testli (3 süreç). **Cloudflare Worker yazıldı ama dağıtılmadı/test edilmedi** |
| Merkezi sunucu | — | — | Gelecek: `NetTransport` arayüzü bunu destekleyecek şekilde ayrık |

Tüm yöntemler aynı oda protokolünü (`RoomHost`/`RoomClient`, `scripts/networking/protocol.gd`) kullanır; yalnızca `NetTransport` değişir.

## Otorite modeli
- Oda sahibi (host) = otorite. Desteyi kriptografik RNG ile karıştırır, dağıtır, her hamleyi `RuleEngine` ile doğrular.
- İstemciler yalnızca **istek** gönderir: `{k:"act", seq, a:{type, card?, color?, target?}}`. Host: bilinmeyen alanları atar (`clean_action`), oyuncunun koltuğunu kendisi belirler (sahte `player` yok sayılır), sıra numarasıyla yinelenen/eski mesajları reddeder, hız sınırı uygular (20 msg/sn, sınır aşımında açık `ERR_NET_RATE_LIMIT`).
- Her koltuğa yalnızca kendi görünümü gider (`view_for` + `redact_events`); rakip kartlarının kimliği hiçbir pakette yoktur (test: `test_remote_never_receives_hidden_cards`).
- Paket kodlaması `var_to_bytes`/`bytes_to_var` (nesne yok), boyut sınırı istemci→host 4 KB, host→istemci 64 KB.

### Güvenlik sınırı (açıkça)
Host cihazı tüm elleri bellekte tutar. Değiştirilmiş bir host uygulaması hile yapabilir; bu, güvenilir bir **dedicated server** ile aynı güvenlik seviyesinde değildir. Çevrim içi istatistikler bu yüzden yalnızca yereldir ve hiçbir sıralamada kullanılmaz.

## Oda kodu ve keşif
- 6 karakter, 30 harfli belirsizliksiz alfabe (≈729 milyon), işletim sistemi kripto RNG'si, reddetme örneklemesiyle sapmasız.
- Özel odalar LAN'da kodun yalnızca tuzlanmış SHA-256 özetini yayınlar; kod ağda açık dolaşmaz. Kod karşılaştırması sabit zamanlıdır.
- İnternette signaling sunucusu yalnızca `SHA256("cardrush-signal-v1:" + kod)` ilk 16 hex'ini görür.
- Android'de bazı cihazlar Wi-Fi multicast kilidi olmadan yayın paketlerini filtreleyebilir → kodla/IP ile katılım her zaman var.
- Davet bağlantısı (`cardrush://join?code=...`) **tasarım aşamasında**; uygulanmadı ve arayüzde öyle belirtiliyor.

## Kopma, yeniden bağlanma, host ayrılması
- Her oyuncuya 128-bit oturum belirteci verilir. Bağlantı koparsa istemci 30 sn boyunca 2 sn'de bir aynı belirteçle yeniden bağlanır; host aynı koltuğu verir ve yalnızca o oyuncunun kartlarını içeren taze görünüm yollar. Uygulama yeniden başlarsa "Son odaya yeniden bağlan" (Save.net.last).
- Aynı belirteçle ikinci bağlantı gelirse eskisi düşürülür (aynı oyuncu iki koltukta oynayamaz).
- Maç sırasında kopan koltuk **20 sn** korunur; sonra politika: geçici bot (varsayılan) ya da otomatik zaman aşımı hamleleri. Oyuncu bilerek ayrılırsa beklemeden uygulanır.
- **Host ayrılırsa:** istemciler 30 sn yeniden bağlanmayı dener (ağ kesintisi/uygulama arka plana geçti). Host dönmezse maç güvenli biçimde biter ve oyuncuya açıkça bildirilir. **Maç ortası otorite devri yapılmaz**: gizli elleri başka bir oyuncuya vermeden güvenli devir mümkün değil. Lobide (gizli durum yokken) devir TODO'da.
- Mobilde uygulama arka plana geçince Godot ana döngüsü durur; host ise maç o sürede bekler.

## İnternet: signaling, STUN, TURN ve maliyet
- STUN: `stun.l.google.com:19302` (ücretsiz, SLA yok). Cloudflare TURN yapılandırılırsa `stun.cloudflare.com` de gelir.
- **Signaling ≠ TURN.** Signaling yalnızca kurulum mesajlarını taşır (çok küçük). TURN, iki cihaz doğrudan bağlanamadığında (mobil operatör NAT'ı, simetrik NAT) tüm trafiği aktarır ve gerçek bant genişliği maliyetidir.
- `server/signaling-worker/` (Cloudflare Workers + Durable Objects, SQLite sınıfı → ücretsiz planla uyumlu): ücretsiz planda 100.000 istek/gün (DO WebSocket mesajları dahil); aşılırsa istekler hata verir, fatura çıkmaz. TURN: Cloudflare Realtime TURN 1.000 GB/ay ücretsiz, sonrası 0,05 $/GB (2026-10 itibarıyla; yayın öncesi yeniden kontrol edilmeli). TURN anahtarı yalnızca Worker gizli değişkeni; istemciye 4 saatlik geçici kimlik verilir.
- Yapılandırma: `project.godot` → `card_rush/online/signaling_url` (gizli değil). Boşsa İnternet seçeneği devre dışı ve gerekçesi gösterilir. Ayarlar → Çevrim içi (gelişmiş) alanı geliştirme/kendi sunucusu için geçersiz kılma sağlar.
- TURN yoksa bazı ağ çiftlerinde bağlantı 20 sn içinde `ERR_NET_WEBRTC_TIMEOUT` ile anlaşılır biçimde başarısız olur.
- WebRTC eklentisinde Android **armv7 (32-bit)** ikilisi yok → o cihazlarda yalnızca yerel ağ/IP.

## Sesli sohbet
- Modüller: `VoiceChatManager` (autoload `Voice`), `VoiceConnection`, `VoiceParticipant`, `VoiceSettings`, `VoicePermissionManager`, codec `ImaAdpcm`.
- Yakalama: `AudioStreamMicrophone` → sessiz `MicCapture` bus'ındaki `AudioEffectCapture` → mono → 16 kHz → ses etkinliği algılama (uyarlanır gürültü tabanı) → IMA-ADPCM (4:1, ~64 kbit/sn konuşurken) → 40 ms paketler, güvenilmez kanal. Host diğerlerine aktarır (yıldız). Kendi sesi geri gelmez.
- Oynatma: oyuncu başına `AudioStreamGenerator` ("Voice" bus'ı), ~120 ms titreşim tamponu, sıra numarasıyla sıralama, yinelenen/geç paket atma.
- Mikrofon kapalıyken mikrofon akışı durdurulur; hiçbir ses yakalanmaz ve gönderilmez. Açıkken kırmızı "● MİKROFON AÇIK" rozeti görünür.
- Susturma/ses seviyesi yalnızca kendi cihazında; "Her zaman" seçeneği ismi yerel listeye kaydeder. Engellenen isimler otomatik susturulur. "Sesli sohbeti kullan" kapalıysa host o oyuncuya ses göndermez (bant genişliği).
- İzin: Android `RECORD_AUDIO` yalnızca mikrofon ilk açıldığında istenir; reddedilirse oyun devam eder. iOS'ta export'a `NSMicrophoneUsageDescription` eklenmeli (Aşama 9).
- Sınırlar: yankı giderme (AEC) yok → kulaklık önerilir (arayüzde yazıyor). Opus (TwoVoIP, MIT) ileride bant genişliğini ~1/4'e indirebilir.
- Doğrulama: codec/VAD/titreşim/aktarım birim testleri; Linux'ta gerçek mikrofonla yakalama (`tools/mic_probe.tscn`); iki ve üç süreçli testlerde host sesi istemciye ulaştı (ENet ve WebRTC). Android/iOS/Windows'ta gerçek cihaz testi **yapılmadı**.

## Test araçları
- `tests/integration/test_network.gd` (loopback + gerçek ENet + keşif), `test_webrtc.gd` (gerçek veri kanalları), `tests/unit/test_voice.gd`.
- `tools/net_peer.tscn`: iki/üç süreçli gerçek arayüzlü maç (`--role host|client`, `--internet ws://...`, `--voice 1`).
- `tools/signaling_server.tscn`: yerel signaling sunucusu.
