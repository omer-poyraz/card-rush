# Card Rush — Oyun Kuralları (motorun uyguladığı haliyle)

Tek kural otoritesi: `scripts/rules/rule_engine.gd`. Bu belge ile motor çelişirse **motor + testler** doğrudur; belge düzeltilir.

## Kaynaklar
- Mattel, *UNO Basic Instruction Sheet* (41940-0923, © 2008) — https://service.mattel.com/instruction_sheets/UNO%20Basic%20IS.pdf
- Mattel, *DHT61* talimatı (temalı baskı; kurallar Basic ile birebir aynı) — https://service.mattel.com/instruction_sheets/DHT61-Eng.pdf
- Her iki PDF 2026-10-10'da indirildi ve metni `pdftotext` ile okundu.

## Deste: `classic_108`
4 renk × (bir 0 + ikişer 1–9 + ikişer Skip/Reverse/+2) = 100, + 4 Wild + 4 Wild Draw Four = **108**. Test: `test_deck.gd`.
Kart kimliği = deste dizisindeki indeks (0–107). Ağ üzerinden yalnızca tam sayı gider.

## Kurulum
- Dağıtıcı rastgele seçilir (kaynak: en yüksek kartı çeken dağıtır — dijitalde eşdeğer rastgelelik). Her elde dağıtıcı bir sola kayar.
- Herkese 7 kart, kalanlar çekme destesi, üst kart açılır. Dağıtıcının solundaki (sıradaki) oyuncu başlar.
- Karıştırma: işletim sisteminin kriptografik RNG'siyle tohumlanır (`GameState.reseed_secure`).

## İlk açılan kart (kaynakla birebir)
| Kart | Davranış |
|---|---|
| Sayı | Normal başlangıç |
| Skip | Dağıtıcının solundaki atlanır, ondan sonraki başlar |
| Reverse | Dağıtıcı başlar, yön ters döner |
| +2 | İlk oyuncu 2 çeker ve sırasını kaybeder ("the same rule applies") |
| Wild | İlk oyuncu rengi seçer (`CHOOSE_COLOR` evresi) ve sonra normal oynar |
| Wild +4 | Desteye geri konur, karıştırılır, yeni kart açılır |
Ev kuralı `first_card_mode = NUMBER_ONLY`: sayı kartı gelene kadar yeniden açılır.

## Oynama
- Eşleşme: aynı **renk**, aynı **sayı** ya da aynı **sembol**; Wild her zaman.
- Oynamamayı seçip çekmek serbesttir (kaynak: "You may also choose NOT to play a playable card"). `draw_when_playable=true`.
- Çekilen kart oynanabiliyorsa **yalnızca o kart** aynı turda oynanabilir; aksi halde/tutulursa sıra geçer.
- Çekme destesi biterse en üst atılan kart kalır, kalanı karıştırılır. İki deste de boşsa çekme hamlesi kartsız pas olur (sonsuz döngü yok).

## Aksiyon kartları
- Skip: sıradaki atlanır. Reverse: yön döner. +2: sıradaki 2 çeker ve atlanır. Wild: renk seçilir.
- **İki oyunculu**: Reverse = Skip (sıra tekrar oynayanda), Skip/+2 sonrası da aynı oyuncu tekrar oynar. *Kaynak sayfalarda iki oyunculu kural yok; daha yeni Mattel baskılarındaki yaygın resmi davranış seçildi — DECISIONS D-07.*

## Wild Draw Four ve itiraz
- Yasal oynama: elde **aktif renkte** kart yokken. Aynı sayı/sembol ya da Wild tutmak yasal kılmaz/engellemez.
- `wd4_mode = CHALLENGE` (resmi): kural dışı oynanabilir (blöf); kurban itiraz edebilir.
  - Haklı itiraz (oynayanda aktif renk vardı): oynayan **4** çeker; itiraz eden ceza almaz ve **normal turunu oynar**; seçilen renk kalır.
  - Haksız itiraz: itiraz eden **6** çeker ve turunu kaybeder.
  - Kabul: 4 çeker, turunu kaybeder.
  - Karar otoritede verilir; oynayanın eli kimseye gösterilmez (kaynakta "show you their hand" — dijitalde gizlilik için yalnızca hüküm açıklanır, D-08).
- `wd4_mode = STRICT`: kural dışı +4 motor tarafından reddedilir, itiraz yoktur.

## Son kart bildirimi ("UNO")
- Sondan bir önceki kartı oynamadan önce (sırası gelmiş ve 2 kartı varken) bildirmek gerekir.
- Bildirmeden 1 karta inen oyuncu **yakalanabilir**: diğer oyuncular `catch` ile 2 kart (ayarlanabilir 1–6) cezası verir.
- Pencere: sıradaki oyuncunun herhangi bir tur hamlesiyle **veya** otorite saatinde `uno_catch_window_ms` (varsayılan 4000) dolunca kapanır. İstemci saati kullanılmaz.
- Oyuncu yakalanmadan bildirirse güvendedir. Aynı ihlal yalnızca bir kez cezalandırılır.
- Arayüzdeki çağrı kelimesi tek bir çeviri anahtarıdır (`CALL_WORD`) — bkz. D-12 (marka riski).

## El / maç sonu ve puan
- 0 kart = el biter. Son kart +2/+4 ise sıradaki oyuncu yine çeker ve bu kartlar puana dahildir.
- Puanlar: sayı = yüzey değeri; Skip/Reverse/+2 = 20; Wild/+4 = 50.
- `SINGLE_ROUND`: ilk biten kazanır. `POINTS`: eli kazanan rakiplerin puanını alır, hedefe (500) ilk ulaşan kazanır. `LOW_TALLY` (kaynaktaki "Alternative Scoring"): herkes kendi kalan puanını biriktirir; biri hedefe ulaşınca **en düşük** toplam kazanır (eşitlikte o eli bitiren).
- Maç bitince hiçbir hamle kabul edilmez (`ERR_NOT_IN_PLAY`).

## Ev kuralları (resmi değil, `RuleProfile.HOUSE_RULE_KEYS`)
`stack_draw_two`, `stack_draw_four`, `stack_mixed`, `seven_zero`, `auto_play_drawn`, `first_card_mode`. Kaynaktaki "Progressive UNO" (+2/+4 zincirleme) ve "Seven-O" ev kurallarına karşılık gelir. Jump-In uygulanmadı. Zincir sürerken itiraz yoktur (yalnızca tek +4 itiraz edilebilir). Ayrıntı ve testler: `test_house_rules.gd`.

## Doğrulama
Ayrıntılı kural testleri `tests/unit/test_rules.gd`, `test_house_rules.gd`; her hamleden sonra kart bütünlüğünü denetleyen 350 rastgele tam maç `test_fuzz_games.gd`.
