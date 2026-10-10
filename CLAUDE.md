# CLAUDE.md — Card Rush

Godot 4.7.2 / GDScript, 2D kart oyunu (Android, iOS, Windows). Önce oku: `docs/PROJECT_STATUS.md`, `docs/TODO.md`; gerektiğinde `docs/ARCHITECTURE.md`, `docs/DECISIONS.md`, `docs/GAME_RULES.md`.

## Kurallar
- Kural mantığı yalnızca `scripts/rules/rule_engine.gd` içinde (saf, düğümsüz). Kural değişikliği = motor + `docs/GAME_RULES.md` + test.
- Tüm hamleler `MatchAuthority.submit` üzerinden; UI ve botlar yalnızca `view_for(seat)` görür.
- Kullanıcı metinleri `tools/localization/strings.py` içinde (TR+EN), sonra `python3 tools/localization/strings.py`. Sahnelere metin gömme.
- Yeni özellik menüde `Features.AVAILABLE` ile açılır; hazır değilse "YAKINDA" kalır. Sahte ekran/sahte başarı yok.
- Her aşamada: `tools/run_tests.sh` geçmeli, `check_scripts.tscn` 0 hata; ardından PROJECT_STATUS/TODO/DECISIONS güncellenir.
- Kod yazarken: `set_anchors_and_offsets_preset` kullan (kodla oluşturulan Control'lerde `set_anchors_preset` boyutu güncellemez). Variant'tan `:=` ile tip çıkarımı derleme hatasıdır; açık tip yaz.

## Komutlar
```bash
tools/run_tests.sh [--only x]
$(tools/godot_path.sh) --headless --path . res://tools/check_scripts.tscn
$(tools/godot_path.sh) --path . --resolution 1280x720 res://tools/capture.tscn -- --scene table --players 5 --wait 6 --out /tmp/t.png
```
