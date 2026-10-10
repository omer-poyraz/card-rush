# Card Rush — Karar Kaydı

Her karar: bağlam → karar → sonuç. Yeni kararlar sona eklenir.

**D-01 Motor ve dil.** Kurulu Godot 4.7.2 kullanıldı (yükseltme yok). Yalnızca GDScript; C# mobil dışa aktarımı zorlaştıracağı için yok.

**D-02 Renderer: Compatibility (GLES3).** 2D kart oyunu; en geniş Android/iOS cihaz desteği ve düşük güç. Forward+'tan geçildi, Windows'taki d3d12 satırı kaldırıldı.

**D-03 Ekran yönü: her yerde yatay.** Masa yatay gerekiyordu; menüleri de yatay tutmak döndürme geçişlerini ve iki düzen bakımını önler. `window/handheld/orientation=4` (sensor landscape).

**D-04 Arayüz kodla kurulur, sahneler ince.** Her ekran `.tscn` kökü + betik; içerik `UiKit` ile kodda üretilir. Metinlerin tamamı `tr()` üzerinden geçer, sahnelere gömülü metin yok. Tema `CanvasLayer` altında miras alınmadığı için modallere açıkça atanır.

**D-05 Kart kimliği = tam sayı.** `CardInstance` sınıfı yerine deste dizisindeki indeks. Ağ paketleri küçük kalır, kopyalanamaz; `check_integrity()` her kartın tam bir kez bulunduğunu doğrular.

**D-06 Kural profili ve ev kuralları ayrı.** `RuleProfile` varsayılanları resmi kurallardır; `HOUSE_RULE_KEYS` listesi arayüzde ayrı bölümde ve masada "Ev kuralları açık" etiketiyle gösterilir. Uzaktan gelen profil `from_dict` ile tip/aralık denetiminden geçer.

**D-07 İki oyunculu Reverse = Skip.** İncelenen iki Mattel sayfası iki oyunculu durumu tanımlamıyor; sonraki resmi baskılarda kullanılan davranış seçildi.

**D-08 +4 itirazında el gösterilmez.** Kaynakta oynayan eli itiraz edene gösterir; çok oyunculu dijital oyunda gizliliği korumak için otorite yalnızca hükmü (haklı/haksız) yayınlar. Haklı itirazdan sonra itiraz eden normal turunu oynar (kaynak: "draw the 4 cards instead of you").

**D-09 Oynanabilir kart varken çekmek serbest** (kaynak: "You may also choose NOT to play a playable card"). İstem "oynanabilir kartı yoksa çekebilsin" diyor; bu bir izin, yasak değil. `draw_when_playable=false` ile kapatılabilir.

**D-10 +4 blöfü resmi modda serbest.** Resmi kurala göre +4 kural dışı da oynanabilir ve itirazla denetlenir. "Motor geçersiz kartı engellesin" şartı için `STRICT` modu var. Botlar asla blöf yapmaz.

**D-11 UNO yakalama penceresi.** "Sonraki oyuncunun turu başlayana kadar" = sıradakinin ilk kabul edilen tur hamlesi; ek olarak otorite saatinde 4 sn (ayarlanabilir 2/4/6) sınırı. İnsan varken botlar en az 1,6 sn bekler ki insanların yakalama şansı olsun.

**D-12 "UNO" kelimesi marka riski.** İstek gereği buton "UNO!" yazıyor; ancak "UNO" Mattel'in tescilli markasıdır ve mağazalar taklit içerikleri reddedebilir. Kelime tek anahtardadır (`CALL_WORD`, `CALL_WORD_SHORT` — `tools/localization/strings.py`). **Öneri:** mağaza yayını öncesi "RUSH!" / "SON KART!" yapılması ve mağaza metinlerinde "UNO" geçmemesi. Kart görselleri, logo ve sesler tamamen özgündür (merkez madalyon tasarımı UNO'nun eğik ovalinden bilinçli olarak farklıdır).

**D-13 Botlar adil.** `BotController` yalnızca `view_for(seat)` ve redakte olayları görür. Zor bot çıkarım yapar (çekme olaylarından "bu renk yok" hafızası, görülen renk sayıları), softmax ile çeşitlilik gösterir.

**D-14 Sesler sentetik.** numpy olmadan standart kütüphaneyle sentezlenir (`tools/assets/make_audio.py`); lisans sorunu yok, yeniden üretilebilir.

**D-15 Fontlar.** Baloo 2 ve Nunito (SIL OFL 1.1, Google Fonts) — Türkçe karakter desteği var; lisans dosyaları `assets/fonts/`.

**D-16 Yerelleştirme kaynağı Python'da.** Uzun kural metinlerini CSV'de elle tırnaklamak hataya açık; `strings.py` → CSV üretilir, ikisi de depoda. Test eksik anahtarı yakalar.

**D-17 Yerel profil ve istatistik.** Sunucu olmadan güvenilir hesap/sıralama yok; profil yalnızca cihazda, istatistikler "resmi sıralamada kullanılmaz" notuyla gösterilir.

**D-18 Hazır olmayan özellikler.** Menüde "YAKINDA" rozetiyle devre dışı (`Features.AVAILABLE`); sahte ekran yok. Sesli sohbet kaydırıcısı da sesli sohbet gelene kadar gizli.

**D-19 Resmi "Alternative Scoring".** Kaynaktaki alternatif puanlama `LOW_TALLY` modu olarak eklendi (herkes kendi kalanını biriktirir, hedefe biri ulaşınca en düşük kazanır).

**D-20 Ağ: taşıma bağımsız oda protokolü.** `RoomHost`/`RoomClient` yalnızca `NetTransport` arayüzünü bilir; ENet (LAN/IP), WebRTC (internet) ve test için bellek içi loopback aynı kodu çalıştırır. RPC/düğüm yolu kullanılmadı (MultiplayerPeer'ın ham paket API'si).

**D-21 Host otoritesi, yıldız topoloji.** Sunucu bütçesi yok; oda sahibi otoritedir. Konuklar yalnızca host'a bağlanır (WebRTC'de de). Güvenlik sınırı NETWORKING.md'de açıkça yazılı.

**D-22 Maç ortası otorite devri yok.** Gizli elleri bir oyuncuya aktarmadan güvenli devir mümkün değil; host 30 sn içinde dönmezse maç güvenli biçimde biter.

**D-23 Kopma politikası.** 20 sn koltuk koruma, sonra geçici bot (oda ayarı: bot / otomatik hamle). Bilerek ayrılma beklemeden uygulanır.

**D-24 İnternet: WebRTC + kendi signaling.** Ücretsiz ve gerçekçi seçenek: Cloudflare Workers + Durable Objects (ücretsiz plan, aşımda hata — fatura yok). TURN ayrı maliyettir (1 TB/ay ücretsiz, sonra ücretli); anahtar yalnızca Worker'da. STUN Google (ücretsiz, SLA yok). URL boşsa özellik kapalı.

**D-25 Ses codec'i IMA-ADPCM.** Tüm platformlarda yerel eklenti gerektirmeyen saf GDScript; 64 kbit/sn konuşurken + VAD. Opus (TwoVoIP) ileride. AEC yok → kulaklık önerisi arayüzde.

**D-26 webrtc-native kırpıldı.** Yalnızca Windows x86_64, Linux x86_64 (geliştirme/test), macOS, Android arm64/x86_64, iOS ikilileri tutuldu (~49 MB). Android armv7 için eklentide ikili yok.
