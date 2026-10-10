# Card Rush — Mimari

Godot 4.7.2 · GDScript · Compatibility renderer · Control tabanlı 2D. Temel çözünürlük 1280×720, `canvas_items` + `expand`, mobilde yatay (sensor landscape).

## Katmanlar
```
UI (scripts/ui, scenes/)        TableView, menüler, diyaloglar — yalnızca istek gönderir, durum göstermez/üretmez
   │  MatchClient (updated(view, events) / send(action))
   ├─ LocalMatchClient ── MatchAuthority (offline, aynı süreç)
   └─ NetworkMatchClient ── ağ ── host'taki MatchAuthority     (Aşama 5)
MatchAuthority (scripts/game)   tek tam GameState sahibi; RuleEngine ile doğrular; bot/zamanlayıcı; koltuk başına redakte görünüm yayınlar
RuleEngine / TurnManager / ScoringManager (scripts/rules)   saf statik fonksiyonlar
GameState / PlayerState (scripts/game), CardDefinition / DeckProfile / DeckManager (scripts/cards)
BotController (scripts/ai)      yalnızca view_for(seat) + açık olay akışı görür
```

## Temel ilkeler
1. **Tek otorite**: Tüm hamleler `MatchAuthority.submit(seat, action)` → `RuleEngine.apply`. `action.player` gönderen koltukla değiştirilir (sahtecilik yok). Reddedilen hamle durumu değiştirmez (önce doğrula, sonra değiştir).
2. **Redaksiyon**: `GameState.view_for(seat)` yalnızca kendi elini içerir; `RuleEngine.redact_events` başkasının çektiği kartların kimliğini siler. Botlar da aynı görünümü alır.
3. **Önce durum, sonra animasyon**: TableView olayları sırayla canlandırır, ardından anlık görüntüye (`_sync`) oturur; animasyon gerçek durumdan sapamaz. Kuyruk birikirse animasyonlar hızlanır.
4. **Sürüm**: her kabul edilen hamle `state.version`'ı artırır; `v` alanı verilirse eski sürüm reddedilir (`ERR_STALE`) — ağda yinelenen/eskimiş mesajlara karşı.
5. **Zaman otoritede**: UNO yakalama penceresi ve tur süresi otorite saatiyle (`now_ms`) ölçülür.

## Eylem şeması
`{type, player, card?, color?, target?, v?, now_ms?}` — tipler: play, draw, pass, accept, challenge, choose_color, uno, catch. Ayrıntı: `rule_engine.gd` başlığı.

## Olaylar
`deal, first_card, rebury, play, draw, reshuffle, skip, reverse, color, uno, uno_missed, caught, challenge, swap, rotate, pass, turn, round_end, match_end, connection, uno_window_closed`.

## Autoload'lar
| Ad | Dosya | Görev |
|---|---|---|
| Save | persistence/save_manager.gd | Sürümlü JSON, atomik yazma, yedek, bozulma kurtarma |
| Settings | core/settings_manager.gd | Ayarlar (Save.settings), animasyon ölçeği, titreşim |
| Loc | localization/localization_manager.gd | TR/EN, cihaz dili, `t()` |
| Audio | core/audio_manager.gd | Music/SFX/Voice bus'ları, efekt havuzu |
| App | core/app.gd | Sahne geçişi, parametre, toast, modal, Android geri tuşu |

## Sahneler
`scenes/boot/boot.tscn` (açılış) → `scenes/menus/main_menu.tscn` → `bot_setup.tscn` / `profile.tscn` / `scenes/game/game_table.tscn`. Arayüz kodla `UiKit` parçalarından kurulur; tüm metinler `tr()`.

## Görsel sistem
- `Palette` (renkler, renk körlüğü paleti), `UiKit` (tema, fontlar: Baloo 2 + Nunito, OFL), `IconView` (vektör ikonlar), `CardArt` (prosedürel kart çizimi + 6 arka yüz), `CardView`, `Backdrop`, `LogoView`, `AvatarView`, `Confetti` (tek seferlik CPUParticles2D).
- Masa: `TableView` (orkestrasyon), `HandView` (yelpaze/kaydırma/dokunma), `SeatView`, `TableFelt` (masa, aktif renk halkası, yön okları), `ColorTile`, `RoundResultPanel`.

## Ses
`tools/assets/make_audio.py` tüm efektleri ve iki müzik döngüsünü sentezler (harici örnek yok). Müzik OGG (ffmpeg), efektler WAV.

## Yerelleştirme
Kaynak: `tools/localization/strings.py` → `data/localization/strings.csv` → Godot `.translation`. Test: `test_localization.gd` koddaki tüm anahtarların iki dilde var olduğunu doğrular.

## Testler ve araçlar
- `tools/run_tests.sh [--only x]` → `tests/reports/test_report.md` (birim + entegrasyon; gerçek kayıt izole edilir).
- `tools/check_scripts.tscn` tüm betikleri derler.
- `tools/capture.tscn` gerçek pencerede ekran görüntüsü (`--scene menu|table|cards|settings|help ... --autoplay 1`).
