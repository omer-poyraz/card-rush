# Card Rush

Renk ve sayı eşleştirme üzerine kurulu, çok oyunculu, ticari kalite hedefli kart oyunu. Godot 4.7.2 · GDScript · Android / iOS / Windows.
İstenen paket kimliği: `com.poyrazyazilim.card-rush`. **Uyarı:** Android applicationId ve iOS bundle id kurallarında `-` Android için geçersizdir (yalnızca harf, rakam, `_`); dışa aktarımda `com.poyrazyazilim.cardrush` veya `com.poyrazyazilim.card_rush` kullanılmalıdır (karar kullanıcıda).

## Çalıştırma
1. Godot 4.7.2'yi kurun (bu makinede: `~/Downloads/Godot_v4.7.2-stable_linux.x86_64`; başka yol için `GODOT=/yol`).
2. Projeyi Godot ile açın ve F5 — ya da: `$(tools/godot_path.sh) --path .`

## Testler
```bash
tools/run_tests.sh               # tüm testler → tests/reports/test_report.md
tools/run_tests.sh --only rules  # filtre
$(tools/godot_path.sh) --headless --path . res://tools/check_scripts.tscn   # tüm betikleri derle
```

## Araçlar
```bash
python3 tools/localization/strings.py      # metinleri değiştirdikten sonra CSV'yi üret
python3 tools/assets/make_audio.py         # sesleri yeniden sentezle (ffmpeg varsa müzik OGG)
$(tools/godot_path.sh) --path . --resolution 1280x720 res://tools/capture.tscn -- --scene table --players 5 --wait 6 --out /tmp/t.png
```

## Belgeler
`docs/PROJECT_STATUS.md` (durum) · `docs/ARCHITECTURE.md` · `docs/DECISIONS.md` · `docs/TODO.md` · `docs/GAME_RULES.md`.

## Lisanslar
Kod ve tüm görsel/ses varlıkları bu proje için üretilmiştir. Fontlar SIL OFL 1.1 (`assets/fonts/*-OFL.txt`). Ayrıntı: `THIRD_PARTY_LICENSES.md`.
