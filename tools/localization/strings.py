#!/usr/bin/env python3
"""Source of every user-facing string (Turkish + English).

Run `python3 tools/localization/strings.py` to regenerate
data/localization/strings.csv (Godot translation CSV). Edit strings HERE.
Placeholders use GDScript % formatting (%s, %d) via Loc.t().
"""
import csv
import os

S = {
    # --- generic ---
    "BTN_OK": ("Tamam", "OK"),
    "BTN_CANCEL": ("Vazgeç", "Cancel"),
    "BTN_CLOSE": ("Kapat", "Close"),
    "BTN_BACK": ("Geri", "Back"),
    "BTN_SAVE": ("Kaydet", "Save"),
    "BTN_QUIT": ("Çık", "Quit"),
    "BTN_RETRY": ("Tekrar Dene", "Retry"),
    "BTN_COPY": ("Kopyala", "Copy"),
    "UNIT_SECONDS_N": ("%d sn", "%ds"),
    "DEFAULT_PLAYER_NAME": ("Oyuncu", "Player"),
    "SAVE_RECOVERED": ("Kayıt dosyası bozuktu; son sağlam yedek geri yüklendi.", "Your save file was damaged; the last good backup was restored."),
    "QUIT_TITLE": ("Oyundan çık?", "Quit the game?"),
    "QUIT_BODY": ("Card Rush kapatılsın mı?", "Close Card Rush?"),
    # The table call word is a single key so it can be renamed before store release.
    "CALL_WORD": ("UNO!", "UNO!"),
    "CALL_WORD_SHORT": ("UNO", "UNO"),

    # --- colours ---
    "COLOR_RED": ("Kırmızı", "Red"),
    "COLOR_YELLOW": ("Sarı", "Yellow"),
    "COLOR_GREEN": ("Yeşil", "Green"),
    "COLOR_BLUE": ("Mavi", "Blue"),
    "COLOR_WILD": ("Joker", "Wild"),

    # --- menu ---
    "MENU_QUICK_PLAY": ("Hızlı Oyna", "Quick Play"),
    "MENU_QUICK_PLAY_SUB": ("3 bota karşı tek el · çevrim dışı", "One hand vs 3 bots · offline"),
    "MENU_BOTS": ("Botlara Karşı", "Play vs Bots"),
    "MENU_BOTS_SUB": ("2–10 oyuncu, zorluk ve kurallar senin seçimin", "2–10 players, your difficulty and rules"),
    "MENU_CREATE_ROOM": ("Oda Kur", "Create Room"),
    "MENU_JOIN_ROOM": ("Odaya Katıl", "Join Room"),
    "MENU_FRIENDS": ("Arkadaşlar", "Friends"),
    "MENU_PROFILE": ("Profil", "Profile"),
    "MENU_COLLECTION": ("Koleksiyon", "Collection"),
    "MENU_MISSIONS": ("Görevler", "Missions"),
    "MENU_STORE": ("Mağaza", "Store"),
    "MENU_SETTINGS": ("Ayarlar", "Settings"),
    "MENU_HELP": ("Kurallar", "Rules"),
    "MENU_OFFLINE_READY": ("Botlarla oyun internet gerektirmez", "Bot games work without internet"),
    "BADGE_SOON": ("YAKINDA", "SOON"),
    "FEATURE_SOON_TIP": ("Bu özellik henüz hazır değil; sonraki sürümlerde gelecek.", "This feature is not ready yet; it is coming in a later version."),

    # --- settings ---
    "SETTINGS_TITLE": ("Ayarlar", "Settings"),
    "SETTINGS_SOUND": ("Ses", "Sound"),
    "SETTINGS_MUSIC": ("Müzik", "Music"),
    "SETTINGS_SFX": ("Efektler", "Effects"),
    "SETTINGS_VOICE": ("Sesli sohbet", "Voice chat"),
    "SETTINGS_LANGUAGE": ("Dil", "Language"),
    "SETTINGS_LANGUAGE_CHANGED": ("Dil değiştirildi", "Language changed"),
    "SETTINGS_GAMEPLAY": ("Oynanış", "Gameplay"),
    "SETTINGS_ONE_TAP": ("Tek dokunuşla kart oyna", "Play a card with one tap"),
    "SETTINGS_HINTS": ("İpuçlarını göster", "Show hints"),
    "SETTINGS_BOT_SPEED": ("Bot hızı", "Bot speed"),
    "BOT_SPEED_0": ("Sakin", "Relaxed"),
    "BOT_SPEED_1": ("Normal", "Normal"),
    "BOT_SPEED_2": ("Hızlı", "Fast"),
    "SETTINGS_DISPLAY": ("Görüntü ve erişilebilirlik", "Display & accessibility"),
    "SETTINGS_QUALITY": ("Görsel kalite", "Visual quality"),
    "QUALITY_LOW": ("Düşük", "Low"),
    "QUALITY_MEDIUM": ("Orta", "Medium"),
    "QUALITY_HIGH": ("Yüksek", "High"),
    "SETTINGS_ANIMATION": ("Animasyonlar", "Animations"),
    "ANIM_FULL": ("Tam", "Full"),
    "ANIM_REDUCED": ("Azaltılmış", "Reduced"),
    "SETTINGS_SHAKE": ("Ekran sarsıntısı", "Screen shake"),
    "SETTINGS_COLORBLIND": ("Renk körlüğü modu (şekil + yüksek kontrast)", "Colour-blind mode (shapes + high contrast)"),
    "SETTINGS_HAPTICS": ("Titreşim", "Haptics"),
    "SETTINGS_PRIVACY": ("Gizlilik", "Privacy"),
    "SETTINGS_NOTIFICATIONS": ("Bildirimler", "Notifications"),
    "SETTINGS_PRIVACY_NOTE": ("Card Rush hesap açtırmaz ve profilin yalnızca bu cihazda saklanır. Reklam ve izin seçenekleri reklam sistemi etkinleştirildiğinde burada görünecek.",
                              "Card Rush needs no account and your profile is stored only on this device. Ad and consent options will appear here once ads are enabled."),
    "SETTINGS_PRIVACY_POLICY": ("Gizlilik Politikası", "Privacy Policy"),
    "SETTINGS_TERMS": ("Kullanım Koşulları", "Terms of Use"),
    "SETTINGS_LICENSES": ("Lisanslar", "Licenses"),
    "SETTINGS_ABOUT": ("Hakkında", "About"),
    "SETTINGS_PREMIUM_STATUS_NONE": ("Premium: etkin değil", "Premium: not active"),

    # --- help ---
    "HELP_TITLE": ("Kurallar ve Yardım", "Rules & Help"),
    "HELP_TAB_BASICS": ("Temel", "Basics"),
    "HELP_TAB_ACTIONS": ("Aksiyon", "Actions"),
    "HELP_TAB_UNO": ("Son Kart", "Last Card"),
    "HELP_TAB_WD4": ("+4 İtirazı", "+4 Challenge"),
    "HELP_TAB_SCORING": ("Puan", "Scoring"),
    "HELP_TAB_HOUSE": ("Ev Kuralları", "House Rules"),
    "HELP_TAB_CONTROLS": ("Kontroller", "Controls"),
    "HELP_BASICS": (
        "[b]Amaç:[/b] Elindeki tüm kartlardan ilk kurtulan oyuncu olmak.\n\n"
        "[b]Deste:[/b] 108 kart — dört renk (kırmızı, sarı, yeşil, mavi); her renkte bir 0, ikişer 1–9, ikişer Pas Geç, Yön Değiştir ve +2; ayrıca 4 Renk Değiştir ve 4 Renk Değiştir +4.\n\n"
        "[b]Başlangıç:[/b] Herkese 7 kart dağıtılır, bir kart açılır. Dağıtıcının solundaki oyuncu başlar.\n\n"
        "[b]Sıran gelince:[/b] Ortadaki kartla aynı [b]renkte[/b], aynı [b]sayıda[/b] ya da aynı [b]sembolde[/b] bir kart oyna veya bir Joker oyna.\n\n"
        "[b]Kart çekme:[/b] Oynamak istemezsen ya da oynayamazsan desteden bir kart çek. Çektiğin kart oynanabiliyorsa hemen oynayabilir ya da tutabilirsin; tutarsan sıra geçer.\n\n"
        "[b]Deste biterse:[/b] Ortadaki en üst kart kalır, altındaki kartlar karıştırılıp yeni deste olur.",
        "[b]Goal:[/b] be the first player to get rid of all your cards.\n\n"
        "[b]Deck:[/b] 108 cards — four colours (red, yellow, green, blue); per colour one 0, two each of 1–9, two Skip, two Reverse and two Draw Two; plus 4 Wild and 4 Wild Draw Four.\n\n"
        "[b]Start:[/b] everyone gets 7 cards and one card is turned up. The player left of the dealer starts.\n\n"
        "[b]On your turn:[/b] play a card matching the top card's [b]colour[/b], [b]number[/b] or [b]symbol[/b], or play a Wild.\n\n"
        "[b]Drawing:[/b] if you can't or don't want to play, draw one card. If it can be played you may play it right away or keep it; keeping it ends your turn.\n\n"
        "[b]Empty deck:[/b] the top discard stays and the rest are shuffled into a new draw pile."),
    "HELP_ACTIONS": (
        "[b]Pas Geç:[/b] Sıradaki oyuncu turunu kaybeder.\n\n"
        "[b]Yön Değiştir:[/b] Oyun yönü tersine döner. İki kişilik oyunda Pas Geç gibi çalışır: sıra tekrar sana gelir.\n\n"
        "[b]+2:[/b] Sıradaki oyuncu 2 kart çeker ve turunu kaybeder.\n\n"
        "[b]Renk Değiştir (Joker):[/b] Her zaman oynanabilir; oyuna devam edilecek rengi sen seçersin.\n\n"
        "[b]Renk Değiştir +4:[/b] Rengi sen seçersin; sıradaki oyuncu 4 kart çeker ve turunu kaybeder — ancak itiraz edebilir (bkz. +4 İtirazı).\n\n"
        "[b]İlk açılan kart:[/b] Pas Geç → ilk oyuncu atlanır. Yön Değiştir → dağıtıcı başlar ve yön ters döner. +2 → ilk oyuncu 2 kart çeker ve atlanır. Renk Değiştir → ilk oyuncu rengi seçip oynar. Renk Değiştir +4 → desteye geri karıştırılır ve yeni kart açılır.",
        "[b]Skip:[/b] the next player loses their turn.\n\n"
        "[b]Reverse:[/b] the direction of play flips. With two players it works like Skip: it's your turn again.\n\n"
        "[b]Draw Two:[/b] the next player draws 2 cards and loses their turn.\n\n"
        "[b]Wild:[/b] can always be played; you choose the colour to continue with.\n\n"
        "[b]Wild Draw Four:[/b] you choose the colour; the next player draws 4 and loses their turn — but may challenge (see +4 Challenge).\n\n"
        "[b]First card turned up:[/b] Skip → the first player is skipped. Reverse → the dealer starts and play goes the other way. Draw Two → the first player draws 2 and is skipped. Wild → the first player picks the colour and plays. Wild Draw Four → it is shuffled back and a new card is turned up."),
    "HELP_UNO": (
        "[b]Son kart bildirimi:[/b] Sondan bir önceki kartını oynamadan önce sağ alttaki büyük butona bas.\n\n"
        "[b]Unutursan:[/b] Tek kartın kaldığında bildirmediysen rakiplerin seni yakalayabilir. Yakalanırsan 2 kart çekersin (oda ayarına göre 4).\n\n"
        "[b]Yakalama süresi:[/b] Sıradaki oyuncu hamlesini yapınca ya da ayarlanan süre (varsayılan 4 sn) dolunca yakalama hakkı biter. Süre, oyunu yöneten cihazın saatiyle ölçülür.\n\n"
        "[b]Kendini kurtar:[/b] Unuttuysan, biri seni yakalamadan butona basarsan güvendesin.\n\n"
        "Aynı ihlal için yalnızca bir kez ceza verilir.",
        "[b]Last-card call:[/b] press the big button at the bottom right before you play your second-to-last card.\n\n"
        "[b]If you forget:[/b] when you're down to one card without calling, opponents can catch you. If caught you draw 2 cards (4 if the room says so).\n\n"
        "[b]Catch window:[/b] it ends as soon as the next player acts or the configured time (default 4 s) runs out, measured on the device running the game.\n\n"
        "[b]Save yourself:[/b] if you forgot, pressing the button before anyone catches you makes you safe.\n\n"
        "A missed call is penalised only once."),
    "HELP_WD4": (
        "[b]Kural:[/b] Renk Değiştir +4'ü yalnızca elinde [b]aktif renkte[/b] kart yokken oynayabilirsin. Aynı sayıda ya da sembolde başka renkte kartların veya Jokerlerin olması sorun değildir.\n\n"
        "[b]Blöf:[/b] Resmi kurallarda bu kartı kural dışı da oynayabilirsin — ama +4 gelen oyuncu itiraz edebilir.\n\n"
        "[b]İtiraz haklıysa:[/b] (elinde aktif renkte kart vardı) +4'ü oynayan 4 kart çeker; itiraz eden ceza almaz ve normal şekilde oynar. Seçilen renk geçerli kalır.\n\n"
        "[b]İtiraz haksızsa:[/b] İtiraz eden 6 kart çeker ve turunu kaybeder.\n\n"
        "Kontrolü oyunu yöneten cihaz yapar; kimsenin eli diğer oyunculara gösterilmez.\n\n"
        "[b]Katı mod:[/b] Oda ayarından seçilirse kural dışı +4 hiç oynanamaz ve itiraz yoktur.",
        "[b]Rule:[/b] you may play Wild Draw Four only when you hold no card of the [b]active colour[/b]. Cards of other colours with the same number or symbol, or Wilds, don't matter.\n\n"
        "[b]Bluffing:[/b] under the official rules you can still play it illegally — but the player hit by it may challenge.\n\n"
        "[b]Challenge succeeds:[/b] (you did hold the active colour) the +4 player draws 4; the challenger takes no penalty and plays normally. The chosen colour stays.\n\n"
        "[b]Challenge fails:[/b] the challenger draws 6 and loses their turn.\n\n"
        "The device running the game checks this; nobody's hand is shown to other players.\n\n"
        "[b]Strict mode:[/b] if selected in the room rules an illegal +4 can't be played at all and there is no challenge."),
    "HELP_SCORING": (
        "[b]Tek el:[/b] İlk kartlarını bitiren kazanır.\n\n"
        "[b]Puan modu:[/b] Eli kazanan, rakiplerin elinde kalan kartların puanını alır. Hedef puana (varsayılan 500) ilk ulaşan maçı kazanır.\n\n"
        "[b]Kart puanları:[/b] Sayı kartları üzerindeki sayı kadar · Pas Geç, Yön Değiştir, +2: 20 · Renk Değiştir ve +4: 50.\n\n"
        "[b]Düşük puan (resmi alternatif):[/b] Her el sonunda herkes kendi elinde kalan kartların puanını toplar. Biri hedefe ulaşınca en düşük toplamlı oyuncu kazanır.\n\n"
        "Son kart +2 veya +4 ise sıradaki oyuncu yine kartları çeker ve bu kartlar puana eklenir.",
        "[b]Single hand:[/b] the first to empty their hand wins.\n\n"
        "[b]Points mode:[/b] the hand winner scores the value of the cards left in opponents' hands. First to the target (default 500) wins the match.\n\n"
        "[b]Card values:[/b] number cards = face value · Skip, Reverse, Draw Two: 20 · Wild and Wild Draw Four: 50.\n\n"
        "[b]Low tally (official alternative):[/b] after each hand everyone adds up the points of the cards left in their OWN hand. When someone reaches the target, the lowest total wins.\n\n"
        "If the last card is a Draw Two or Wild Draw Four the next player still draws and those cards are scored."),
    "HELP_HOUSE": (
        "Ev kuralları [b]resmi kurallar değildir[/b] ve yalnızca oda/maç ayarında açılırsa geçerlidir. Masada \"Ev kuralları açık\" yazısı görünür.\n\n"
        "[b]+2 üstüne +2:[/b] +2 gelen oyuncu kendi +2'siyle cezayı bir sonrakine aktarabilir.\n"
        "[b]+4 üstüne +4:[/b] Aynısı +4 için. Zincirde itiraz yapılamaz.\n"
        "[b]Karışık zincir:[/b] +2 üstüne +4 ve (seçilen renkteyse) +4 üstüne +2.\n"
        "[b]7-0:[/b] 7 oynayan, seçtiği oyuncuyla elini değiştirir; 0 oynanınca tüm eller oyun yönünde kayar.\n"
        "[b]Çekileni otomatik oyna:[/b] Çekilen kart oynanabiliyorsa (Joker hariç) kendiliğinden oynanır.\n"
        "[b]İlk kart yalnızca sayı:[/b] Açılış kartı sayı kartı olana kadar yeniden çekilir.",
        "House rules [b]are not official rules[/b] and only apply when enabled for the room/match. The table then shows \"House rules on\".\n\n"
        "[b]Stack +2:[/b] a player hit by +2 can pass the penalty on with their own +2.\n"
        "[b]Stack +4:[/b] the same for +4. Stacked chains can't be challenged.\n"
        "[b]Mixed stacking:[/b] +4 on +2, and +2 on +4 (if it matches the chosen colour).\n"
        "[b]7-0:[/b] playing a 7 swaps hands with a player you choose; playing a 0 passes all hands in the direction of play.\n"
        "[b]Auto-play drawn card:[/b] a playable drawn card (not a Wild) is played automatically.\n"
        "[b]Number-only first card:[/b] the opening card is redrawn until it is a number card."),
    "HELP_CONTROLS": (
        "[b]Dokunmatik / fare:[/b] Karta bir kez dokun → seçilir; tekrar dokun, çift tıkla ya da yukarı kaydır → oynanır. Ayarlardan tek dokunuşla oynamayı açabilirsin.\n"
        "Çok kart varsa elini yatay kaydırabilirsin. Desteye dokunarak kart çekersin.\n\n"
        "[b]Klavye (Windows):[/b] ← → kart seç · Enter/Boşluk oyna · D çek/tut · U son kart bildirimi · C itiraz · 1–4 renk seç · Esc menü.",
        "[b]Touch / mouse:[/b] tap a card once to select it; tap again, double-click or swipe up to play it. You can enable one-tap play in Settings.\n"
        "With many cards, drag your hand sideways. Tap the deck to draw.\n\n"
        "[b]Keyboard (Windows):[/b] ← → select · Enter/Space play · D draw/keep · U last-card call · C challenge · 1–4 pick colour · Esc menu."),

    # --- setup / rules form ---
    "SETUP_TABLE": ("Masa", "Table"),
    "SETUP_PLAYERS": ("Oyuncu sayısı (sen dahil)", "Players (including you)"),
    "SETUP_PLAYERS_NOTE": ("Klasik 108 kartlık deste 2–10 oyuncuyu destekler.", "The classic 108-card deck supports 2–10 players."),
    "SETUP_DIFFICULTY": ("Bot zorluğu", "Bot difficulty"),
    "SETUP_START": ("Oyunu Başlat", "Start Game"),
    "BOT_EASY": ("Kolay", "Easy"),
    "BOT_NORMAL": ("Normal", "Normal"),
    "BOT_HARD": ("Zor", "Hard"),
    "BOT_MIXED": ("Karışık", "Mixed"),
    "BOT_EASY_DESC": ("Geçerli kartlardan birini seçer, rengi basitçe belirler ve bazen son kart bildirimini unutur.", "Picks any valid card, chooses colours simply and sometimes forgets the last-card call."),
    "BOT_NORMAL_DESC": ("Renk dağılımına bakar, aksiyon kartlarını rakiplerin kart sayısına göre kullanır.", "Considers its colour spread and uses action cards based on opponents' card counts."),
    "BOT_HARD_DESC": ("Rakiplerin hangi renkleri tutmadığını çıkarır, son karta yaklaşanları hedefler ve asla blöf +4 oynamaz. Rakiplerin elini görmez.", "Infers which colours opponents lack, targets players close to winning and never bluffs a +4. It never sees hidden hands."),
    "BOT_MIXED_DESC": ("Botlar kolay, normal ve zor arasında dağıtılır.", "Bots are spread across easy, normal and hard."),
    "RULES_CLASSIC_SECTION": ("Klasik kurallar", "Classic rules"),
    "RULES_MODE": ("Bitiş", "Finish"),
    "RULES_MODE_SINGLE": ("Tek el", "Single hand"),
    "RULES_MODE_POINTS": ("Puan", "Points"),
    "RULES_MODE_LOW": ("Düşük puan", "Low tally"),
    "RULES_TARGET": ("Hedef puan", "Target score"),
    "RULES_WD4": ("+4 denetimi", "+4 policing"),
    "RULES_WD4_CHALLENGE": ("İtiraz (resmi)", "Challenge (official)"),
    "RULES_WD4_STRICT": ("Katı", "Strict"),
    "RULES_WD4_TIP": ("Resmi kural: +4 blöf olarak oynanabilir ve itiraz edilebilir. Katı mod: kural dışı +4 oynanamaz.", "Official: +4 may be bluffed and challenged. Strict: an illegal +4 can't be played."),
    "RULES_UNO_PENALTY": ("Yakalanma cezası (kart)", "Missed-call penalty (cards)"),
    "RULES_UNO_WINDOW": ("Yakalama süresi", "Catch window"),
    "RULES_TURN_TIMER": ("Tur süresi", "Turn timer"),
    "RULES_TIMER_OFF": ("Kapalı", "Off"),
    "RULES_HOUSE_SECTION": ("Ev kuralları (resmi değil)", "House rules (not official)"),
    "RULES_HOUSE_NOTE": ("Bunlar klasik kuralların parçası değildir. Açtığın her kural maç başında tüm oyunculara gösterilir.", "These are not part of the classic rules. Every rule you enable is shown to all players before the match."),
    "RULES_SUMMARY_CLASSIC": ("Kural profili: Klasik (resmi kurallar)", "Rule profile: Classic (official rules)"),
    "RULES_SUMMARY_HOUSE": ("Kural profili: Klasik + ev kuralları: %s", "Rule profile: Classic + house rules: %s"),
    "HOUSE_STACK_DRAW_TWO": ("+2 üstüne +2", "Stack +2 on +2"),
    "HOUSE_STACK_DRAW_TWO_TIP": ("+2 gelen oyuncu +2 atarak cezayı aktarabilir.", "A player hit by +2 may pass it on with a +2."),
    "HOUSE_STACK_DRAW_FOUR": ("+4 üstüne +4", "Stack +4 on +4"),
    "HOUSE_STACK_DRAW_FOUR_TIP": ("+4 gelen oyuncu +4 atarak cezayı aktarabilir.", "A player hit by +4 may pass it on with a +4."),
    "HOUSE_STACK_MIXED": ("Karışık zincir (+2/+4)", "Mixed stacking (+2/+4)"),
    "HOUSE_STACK_MIXED_TIP": ("+2 üstüne +4 ve seçilen renkte +4 üstüne +2.", "+4 on +2, and +2 on +4 in the chosen colour."),
    "HOUSE_SEVEN_ZERO": ("7-0 el değiştirme", "7-0 hand swapping"),
    "HOUSE_SEVEN_ZERO_TIP": ("7: seçtiğin oyuncuyla el değiştir. 0: tüm eller yön boyunca kayar.", "7: swap hands with a chosen player. 0: all hands pass along."),
    "HOUSE_AUTO_PLAY_DRAWN": ("Çekileni otomatik oyna", "Auto-play drawn card"),
    "HOUSE_AUTO_PLAY_DRAWN_TIP": ("Çekilen oynanabilir kart (Joker hariç) kendiliğinden oynanır.", "A playable drawn card (except Wilds) is played automatically."),
    "HOUSE_FIRST_CARD_MODE": ("İlk kart yalnızca sayı", "Number-only first card"),
    "HOUSE_FIRST_CARD_MODE_TIP": ("Açılış kartı sayı kartı olana kadar yeniden çekilir.", "The opening card is redrawn until it is a number."),

    # --- table ---
    "TABLE_YOU": ("Sen", "You"),
    "TABLE_DRAW": ("Kart Çek", "Draw"),
    "TABLE_KEEP": ("Tut ve Geç", "Keep"),
    "TABLE_TAKE_N": ("+%d Al", "Take +%d"),
    "TABLE_CATCH": ("Yakala!", "Catch!"),
    "TABLE_CHOOSE_COLOR": ("Renk Seç", "Choose a Colour"),
    "TABLE_COLOR_IS": ("Renk: %s", "Colour: %s"),
    "TABLE_HINT_PLAY": ("Eşleşen bir kart oyna ya da desteden çek", "Play a matching card or draw from the deck"),
    "TABLE_HINT_DRAWN": ("Çektiğin kartı oynayabilir ya da tutabilirsin", "Play the card you drew or keep it"),
    "TABLE_HINT_STACK": ("Cezayı aktar ya da %d kart al", "Pass the penalty on or take %d cards"),
    "TABLE_HINT_CHALLENGE": ("+4 geldi: kabul et ya da itiraz et", "Hit by +4: accept or challenge"),
    "TABLE_HINT_UNO": ("İki kartın var: oynamadan önce bildirmeyi unutma!", "Two cards left: call before you play!"),
    "TABLE_HINT_WAIT": ("%s oynuyor…", "%s is playing…"),
    "TABLE_FIRST_WILD": ("İlk kart Renk Değiştir: rengi sen seçiyorsun", "The first card is a Wild: you pick the colour"),
    "TABLE_CHALLENGE_TITLE": ("+4 geldi!", "Wild Draw Four!"),
    "TABLE_CHALLENGE_BODY": ("%s sana Renk Değiştir +4 oynadı. Kabul edersen kartları çekip turunu kaybedersin. İtiraz edersen: %s elinde önceki renkten kart varsa o 4 kart çeker; yoksa sen 6 kart çekersin.",
                             "%s played a Wild Draw Four on you. Accept to draw the cards and lose your turn. Challenge: if %s held a card of the previous colour they draw 4; otherwise you draw 6."),
    "TABLE_CHALLENGE_STACK_HINT": ("Ya da elindeki uygun kartla cezayı aktar.", "Or pass the penalty on with a suitable card."),
    "TABLE_ACCEPT_N": ("Kabul Et (+%d)", "Accept (+%d)"),
    "TABLE_CHALLENGE": ("İtiraz Et", "Challenge"),
    "TABLE_CHALLENGE_GUILTY": ("İtiraz haklı! %s 4 kart çekti", "Challenge upheld! %s draws 4"),
    "TABLE_CHALLENGE_INNOCENT": ("İtiraz haksız! %s 6 kart çekti", "Challenge failed! %s draws 6"),
    "TABLE_CAUGHT": ("%s yakalandı! +%d", "%s was caught! +%d"),
    "TABLE_RESHUFFLE": ("Atılan kartlar karıştırıldı", "Discards reshuffled"),
    "TABLE_DECK_EMPTY": ("Çekilecek kart kalmadı", "No cards left to draw"),
    "TABLE_SWAP": ("%s ve %s elleri değiştirdi", "%s and %s swapped hands"),
    "TABLE_ROTATE": ("Tüm eller kaydı!", "All hands passed along!"),
    "TABLE_PICK_TARGET": ("Elini değiştireceğin oyuncuya dokun", "Tap the player to swap hands with"),
    "TABLE_ROUND_N": ("El %d", "Hand %d"),
    "TABLE_TARGET_N": ("Hedef %d puan", "Target %d points"),
    "TABLE_POINTS_N": ("%d puan", "%d pts"),
    "TABLE_TAG_BOT": ("BOT", "BOT"),
    "TABLE_TAG_OFFLINE": ("KOPTU", "OFFLINE"),
    "TABLE_HOUSE_RULES_ON": ("Ev kuralları açık", "House rules on"),
    "TABLE_CARD_NOT_PLAYABLE": ("Bu kart oynanamaz: renk, sayı veya sembol eşleşmiyor.", "That card can't be played: colour, number or symbol don't match."),
    "TABLE_MUST_STACK_OR_TAKE": ("Ceza bekliyor: uygun bir kartla aktar ya da +%d al.", "A penalty is pending: pass it on with a suitable card or take +%d."),
    "TABLE_ONLY_DRAWN": ("Şimdi yalnızca çektiğin kartı oynayabilirsin.", "Now you may only play the card you just drew."),
    "TABLE_WD4_BLUFF_WARN": ("Dikkat: elinde aktif renkte kart var. Bu +4'e itiraz edilirse 4 kart çekersin.", "Careful: you hold the active colour. If this +4 is challenged you draw 4."),
    "TABLE_DISCONNECTED": ("%s bağlantısı koptu", "%s disconnected"),
    "TABLE_RECONNECTED": ("%s geri döndü", "%s is back"),
    "PAUSE_TITLE": ("Menü", "Menu"),
    "PAUSE_RESUME": ("Devam Et", "Resume"),
    "PAUSE_RULES": ("Kurallar", "Rules"),
    "PAUSE_LEAVE": ("Maçtan Çık", "Leave Match"),
    "PAUSE_ONLINE_NOTE": ("Çevrim içi maçlar duraklatılamaz; sıra sana gelirse süre işlemeye devam eder.", "Online matches can't be paused; your turn timer keeps running."),
    "LEAVE_CONFIRM_TITLE": ("Maçtan çıkılsın mı?", "Leave the match?"),
    "LEAVE_CONFIRM_BODY": ("Maçtan çıkarsan bu maç kayıp sayılır.", "If you leave, this match counts as a loss."),
    "RESULT_YOU_WIN": ("Kazandın!", "You win!"),
    "RESULT_WINNER": ("%s kazandı", "%s wins"),
    "RESULT_ROUND_WINNER": ("%s eli kazandı (+%d)", "%s wins the hand (+%d)"),
    "RESULT_REMATCH": ("Tekrar Oyna", "Play Again"),
    "RESULT_MENU": ("Ana Menü", "Main Menu"),
    "RESULT_NEXT_ROUND": ("Sonraki El", "Next Hand"),
    "RESULT_NEXT_IN": ("Sonraki el %d sn içinde", "Next hand in %ds"),
    "RESULT_XP": ("+%d XP", "+%d XP"),
    "RESULT_LEVEL_UP": ("Seviye atladın! Seviye %d", "Level up! Level %d"),
    "RESULT_CARDS_LEFT": ("%d kart · %d puan", "%d cards · %d pts"),

    # --- profile ---
    "PROFILE_LEVEL_N": ("Seviye %d", "Level %d"),
    "PROFILE_NAME": ("Oyuncu adı", "Player name"),
    "PROFILE_AVATAR": ("Avatar", "Avatar"),
    "PROFILE_STATS": ("İstatistikler", "Statistics"),
    "PROFILE_HISTORY": ("Son maçlar", "Recent matches"),
    "PROFILE_NO_HISTORY": ("Henüz maç oynamadın.", "No matches played yet."),
    "PROFILE_SAVED": ("Profil kaydedildi", "Profile saved"),
    "PROFILE_LOCAL_NOTE": ("Profil ve istatistikler yalnızca bu cihazda saklanır. Çevrim dışı istatistikler resmi bir sıralamada kullanılmaz.", "Profile and statistics are stored only on this device. Offline statistics are not used for any official ranking."),
    "STAT_PLAYED": ("Oynanan maç", "Matches played"),
    "STAT_WON": ("Kazanılan maç", "Matches won"),
    "STAT_WIN_RATE": ("Kazanma oranı", "Win rate"),
    "STAT_BEST_STREAK": ("En uzun seri", "Best streak"),
    "STAT_CARDS_PLAYED": ("Oynanan kart", "Cards played"),
    "STAT_UNO_CALLS": ("Son kart bildirimi", "Last-card calls"),
    "STAT_CATCHES": ("Yakalama", "Catches"),
    "STAT_VS_BOTS": ("Botlara karşı (%s): galibiyet / maç", "Vs bots (%s): wins / matches"),
    "STAT_ONLINE": ("Çevrim içi: galibiyet / maç", "Online: wins / matches"),
    "HIST_WIN": ("Galibiyet", "Win"),
    "HIST_LOSS": ("Mağlubiyet", "Loss"),
    "HIST_PLAYERS": ("%d oyuncu", "%d players"),

    # --- errors (engine + generic) ---
    "ERR_GENERIC": ("Bir şeyler ters gitti. Lütfen tekrar dene.", "Something went wrong. Please try again."),
    "ERR_NOT_YOUR_TURN": ("Sıra sende değil.", "It's not your turn."),
    "ERR_NOT_IN_PLAY": ("El bitti; yeni hamle kabul edilmiyor.", "The hand is over; no more moves."),
    "ERR_BAD_PLAYER": ("Geçersiz oyuncu.", "Invalid player."),
    "ERR_BAD_CARD": ("Geçersiz kart.", "Invalid card."),
    "ERR_CARD_NOT_IN_HAND": ("Bu kart elinde değil.", "That card isn't in your hand."),
    "ERR_CARD_NOT_PLAYABLE": ("Bu kart şu an oynanamaz.", "That card can't be played now."),
    "ERR_WD4_RESTRICTED": ("+4'ü yalnızca elinde aktif renkte kart yokken oynayabilirsin.", "You can play +4 only when you hold no card of the active colour."),
    "ERR_NEED_COLOR": ("Önce bir renk seç.", "Pick a colour first."),
    "ERR_NEED_TARGET": ("El değiştireceğin oyuncuyu seç.", "Choose a player to swap with."),
    "ERR_WRONG_PHASE": ("Bu hamle şu an yapılamaz.", "That move isn't possible right now."),
    "ERR_MUST_PLAY": ("Oynanabilir kartın varken çekemezsin.", "You can't draw while holding a playable card."),
    "ERR_NOTHING_TO_ACCEPT": ("Bekleyen bir ceza yok.", "There is no pending penalty."),
    "ERR_CANNOT_CHALLENGE": ("Şu an itiraz edilemez.", "You can't challenge now."),
    "ERR_UNO_ALREADY": ("Zaten bildirdin.", "You already called."),
    "ERR_UNO_INVALID": ("Bildirmek için sıranda ve iki kartın olmalı.", "You can call only on your turn with two cards."),
    "ERR_BAD_TARGET": ("Geçersiz oyuncu seçimi.", "Invalid player choice."),
    "ERR_NOT_CATCHABLE": ("Bu oyuncu yakalanamaz.", "That player can't be caught."),
    "ERR_CATCH_EXPIRED": ("Yakalama süresi doldu.", "The catch window has closed."),
    "ERR_STALE": ("Oyun durumu değişti, hamle yinelenmedi.", "The game moved on; the action was ignored."),
    "ERR_UNKNOWN_ACTION": ("Bilinmeyen hamle.", "Unknown action."),
    "ERR_NO_MATCH": ("Aktif maç yok.", "No active match."),
    "ERR_TOO_FEW_PLAYERS": ("En az 2 oyuncu gerekir.", "At least 2 players are required."),
    "ERR_TOO_MANY_PLAYERS": ("Bu deste en fazla 10 oyuncuyu destekler.", "This deck supports at most 10 players."),
    "ERR_DECK_TOO_SMALL": ("Bu oyuncu sayısı için deste yetersiz.", "The deck is too small for this many players."),
    "ERR_NAME_SHORT": ("İsim en az 3 karakter olmalı.", "Names need at least 3 characters."),
    "ERR_NAME_BLOCKED": ("Bu isim kullanılamaz.", "That name isn't allowed."),

    # --- lobby / network ---
    "MENU_LAN_READY": ("Aynı Wi-Fi'da arkadaşlarınla oda kurabilirsin", "Create rooms with friends on the same Wi-Fi"),
    "LOBBY_LAN_NOTE": ("Yerel ağ, IP veya internet (sunucu yapılandırıldıysa)", "Local network, IP or internet (when a server is configured)"),
    "LOBBY_ROOM_NAME": ("Oda adı", "Room name"),
    "LOBBY_DEFAULT_ROOM_NAME": ("Masa · %s", "%s's Table"),
    "LOBBY_MAX_PLAYERS": ("En fazla oyuncu (botlar dahil)", "Max players (bots included)"),
    "LOBBY_CONNECTION": ("Bağlantı", "Connection"),
    "LOBBY_CONN_LAN": ("Yerel ağ", "Local network"),
    "LOBBY_CONN_INTERNET": ("İnternet", "Internet"),
    "LOBBY_CONN_LAN_NOTE": ("Aynı Wi-Fi'daki oyuncular odayı bulup kodla katılır. Sunucu gerekmez.", "Players on the same Wi-Fi find the room and join with the code. No server needed."),
    "LOBBY_CONN_INTERNET_NOTE": ("Arkadaşların farklı ağlardan oda koduyla katılır. Bağlantı kurulduktan sonra veriler doğrudan cihazlar arasında akar.", "Friends join from other networks with the room code. Once connected, data flows directly between devices."),
    "LOBBY_INTERNET_ROOM": ("İnternet odası: arkadaşların “Odaya Katıl” ekranında bu kodu girmeli.", "Internet room: friends enter this code on the “Join Room” screen."),
    "NET_INTERNET_NOT_CONFIGURED": ("İnternet odaları için bir bağlantı sunucusu yapılandırılmamış. Şimdilik yerel ağ veya IP ile oynayabilirsin.", "No connection server is configured for internet rooms yet. You can play on the local network or by IP."),
    "NET_INTERNET_UNSUPPORTED": ("Bu cihazda internet bağlantısı (WebRTC) desteklenmiyor. Yerel ağ veya IP ile oynayabilirsin.", "Internet play (WebRTC) isn't supported on this device. You can play on the local network or by IP."),
    "ERR_NET_SIGNAL_UNREACHABLE": ("Bağlantı sunucusuna ulaşılamadı. İnternet bağlantını kontrol et.", "Couldn't reach the connection server. Check your internet connection."),
    "ERR_NET_SIGNAL_CLOSED": ("Bağlantı sunucusu bağlantıyı kapattı.", "The connection server closed the connection."),
    "ERR_NET_SIGNAL_NO_ROOM": ("Bu kodla açık bir oda bulunamadı.", "No open room with this code."),
    "ERR_NET_SIGNAL_ROOM_TAKEN": ("Oda kodu çakıştı, lütfen tekrar dene.", "Room code clash, please try again."),
    "ERR_NET_SIGNAL_FULL": ("Oda dolu.", "The room is full."),
    "ERR_NET_SIGNAL_BAD_REQUEST": ("Bağlantı sunucusu isteği reddetti.", "The connection server rejected the request."),
    "ERR_NET_WEBRTC_TIMEOUT": ("Cihazlar arasında doğrudan bağlantı kurulamadı (ağ engeli). Bir aktarıcı (TURN) sunucusu yapılandırılmamış olabilir; yerel ağ veya farklı bir ağ dene.", "A direct connection between the devices couldn't be made (network restrictions). A relay (TURN) server may not be configured; try the local network or another network."),
    "SETTINGS_ONLINE": ("Çevrim içi (gelişmiş)", "Online (advanced)"),
    "SETTINGS_SIGNALING_NOTE": ("İnternet odaları için bağlantı sunucusu adresi. Boş bırakırsan oyunun varsayılanı kullanılır. Kendi sunucunu kurduysan buraya yaz.", "Connection server address for internet rooms. Leave empty for the game's default. Enter your own server if you host one."),
    "LOBBY_VISIBILITY": ("Görünürlük", "Visibility"),
    "LOBBY_PRIVATE": ("Özel (kodla)", "Private (code)"),
    "LOBBY_PUBLIC": ("Herkese açık", "Public"),
    "LOBBY_PRIVATE_NOTE": ("Oda yakındaki listesinde kilitli görünür; katılmak için oda kodu gerekir. Kodun kendisi ağda yayınlanmaz.", "The room shows as locked in nearby rooms; the room code is required to join. The code itself is never broadcast."),
    "LOBBY_PUBLIC_NOTE": ("Aynı ağdaki herkes odayı görüp doğrudan katılabilir.", "Anyone on the same network can see the room and join directly."),
    "LOBBY_VOICE": ("Sesli sohbet", "Voice chat"),
    "LOBBY_VOICE_TIP": ("Oyuncular istedikleri zaman mikrofonlarını açabilir. Kapalıysa oyun aynen devam eder.", "Players can switch their mic on whenever they like. With voice off the game works the same."),
    "LOBBY_VOICE_ON": ("Sesli sohbet açık", "Voice chat on"),
    "LOBBY_VOICE_OFF": ("Sesli sohbet kapalı", "Voice chat off"),
    "VOICE_MIC": ("Mikrofon", "Microphone"),
    "VOICE_MIC_LIVE": ("● MİKROFON AÇIK", "● MIC ON"),
    "VOICE_DEAFEN": ("Herkesi benim için sustur", "Mute everyone for me"),
    "VOICE_PLAYERS": ("Sesli sohbet", "Voice chat"),
    "VOICE_LOCAL_NOTE": ("Susturma ve ses seviyesi yalnızca senin cihazında geçerlidir; diğer oyuncuların ayarları değişmez. Yankı olmaması için kulaklık önerilir.", "Mute and volume only apply on your device; other players' settings don't change. Headphones are recommended to avoid echo."),
    "VOICE_MUTE": ("Sustur", "Mute"),
    "VOICE_ALWAYS": ("Her zaman", "Always"),
    "VOICE_ALWAYS_TIP": ("Bu isimdeki oyuncuyu sonraki odalarda da sustur", "Also mute this player name in future rooms"),
    "VOICE_NOBODY": ("Odada başka oyuncu yok.", "No other players in the room."),
    "VOICE_PERMISSION_DENIED": ("Mikrofon izni verilmedi. Oyuna mikrofonsuz devam edebilir, izni cihaz ayarlarından açabilirsin.", "Microphone permission was denied. You can keep playing without it, or allow it in your device settings."),
    "VOICE_INPUT_DISABLED": ("Bu sürümde ses girişi kapalı.", "Audio input is disabled in this build."),
    "SETTINGS_VOICE_ENABLED": ("Sesli sohbeti kullan", "Use voice chat"),
    "LOBBY_CREATE": ("Odayı Kur", "Create Room"),
    "LOBBY_NEARBY": ("Yakındaki odalar", "Nearby rooms"),
    "LOBBY_SEARCHING": ("Aynı Wi-Fi ağındaki odalar aranıyor… Oda görünmüyorsa kodla ya da IP adresiyle katılmayı dene.", "Looking for rooms on this Wi-Fi… If a room doesn't show up, join by code or by IP address."),
    "LOBBY_DISCOVERY_UNAVAILABLE": ("Bu cihazda yakındaki odalar taranamıyor. IP adresiyle katılabilirsin.", "Nearby rooms can't be scanned on this device. You can join by IP address."),
    "LOBBY_ROOM_SUB": ("Kurucu: %s · %d/%d oyuncu", "Host: %s · %d/%d players"),
    "LOBBY_IN_MATCH": ("Maç sürüyor", "Match in progress"),
    "LOBBY_JOIN": ("Katıl", "Join"),
    "LOBBY_BY_CODE": ("Oda koduyla katıl", "Join with a room code"),
    "LOBBY_BY_IP": ("IP adresiyle bağlan", "Connect by IP address"),
    "LOBBY_BY_IP_NOTE": ("Oda sahibinin ekranında yazan adresi gir (kod da gerekir). İnternet üzerinden yalnızca port yönlendirme veya ortak bir VPN ile çalışır.", "Enter the address shown on the host's screen (the code is also required). Over the internet this only works with port forwarding or a shared VPN."),
    "LOBBY_CONNECT_IP": ("Bağlan", "Connect"),
    "LOBBY_REJOIN": ("Son odaya yeniden bağlan", "Rejoin last room"),
    "LOBBY_ENTER_CODE_PRIVATE": ("Bu oda özel: sağ taraftan oda kodunu gir.", "This room is private: enter the room code on the right."),
    "LOBBY_CODE_NOT_FOUND": ("Bu kodla yakında bir oda bulunamadı. Aynı Wi-Fi'da olduğundan emin ol ya da IP ile bağlan. (İnternet odaları için bağlantı sunucusu yapılandırılmamış.)", "No nearby room with this code. Make sure you're on the same Wi-Fi or connect by IP. (No connection server is configured for internet rooms.)"),
    "LOBBY_IP_NEEDS_CODE": ("IP ile bağlanmak için oda kodunu da gir.", "Enter the room code too when connecting by IP."),
    "LOBBY_CONNECTING": ("Bağlanılıyor…", "Connecting…"),
    "LOBBY_WAITING_ROOM": ("Bekleme Odası", "Waiting Room"),
    "LOBBY_PLAYERS": ("Oyuncular", "Players"),
    "LOBBY_ADD_BOT": ("Bot ekle:", "Add bot:"),
    "LOBBY_ROOM_CODE": ("Oda kodu", "Room code"),
    "LOBBY_CODE_COPIED": ("Oda kodu kopyalandı", "Room code copied"),
    "LOBBY_HOST_IP": ("Bu cihazın adresi: %s (port %d)", "This device's address: %s (port %d)"),
    "LOBBY_INVITE_NOTE": ("Kodu arkadaşına ilet. Davet bağlantısı (cardrush://) henüz desteklenmiyor.", "Share the code with your friend. Invite links (cardrush://) are not supported yet."),
    "LOBBY_RULES": ("Kurallar", "Rules"),
    "LOBBY_START": ("Maçı Başlat", "Start Match"),
    "LOBBY_READY": ("Hazırım", "I'm Ready"),
    "LOBBY_NOT_READY": ("Hazır değilim", "Not Ready"),
    "LOBBY_READY_STATE": ("HAZIR", "READY"),
    "LOBBY_WAITING_STATE": ("BEKLİYOR", "WAITING"),
    "LOBBY_EMPTY_SEAT": ("— boş koltuk —", "— empty seat —"),
    "LOBBY_BOT_N": ("Bot (%s)", "Bot (%s)"),
    "LOBBY_KICK": ("Odadan çıkar", "Kick"),
    "LOBBY_REMOVE_BOT": ("Botu kaldır", "Remove bot"),
    "LOBBY_JOINED": ("%s odaya katıldı", "%s joined"),
    "LOBBY_LEFT": ("%s odadan ayrıldı", "%s left"),
    "LOBBY_KICKED": ("Oda sahibi seni odadan çıkardı.", "The host removed you from the room."),
    "LOBBY_ROOM_CLOSED": ("Oda kapandı.", "The room was closed."),
    "LOBBY_LEAVE_TITLE": ("Odadan ayrıl?", "Leave the room?"),
    "LOBBY_LEAVE_BODY": ("Odadan ayrılırsan aynı kodla yeniden katılabilirsin.", "You can rejoin later with the same code."),
    "LOBBY_LEAVE_HOST_BODY": ("Oda sahibisin: ayrılırsan oda herkes için kapanır ve süren maç biter.", "You are the host: leaving closes the room for everyone and ends any match."),
    "LOBBY_LEAVE": ("Ayrıl", "Leave"),
    "LEAVE_CONFIRM_ONLINE_BODY": ("Maçtan çıkarsan koltuğunu bir bot devralır ve maç kayıp sayılır.", "If you leave, a bot takes your seat and the match counts as a loss."),
    "RESULT_LOBBY": ("Lobiye Dön", "Back to Lobby"),
    "NET_RECONNECTING": ("Bağlantı koptu, yeniden bağlanılıyor…", "Connection lost, reconnecting…"),
    "ERR_NET_PORT_BUSY": ("Oyun portu kullanımda. Başka bir uygulama portu kullanıyor olabilir.", "The game port is in use. Another app may be using it."),
    "ERR_NET_HOST_FAILED": ("Oda kurulamadı. Ağ bağlantını kontrol et.", "Couldn't create the room. Check your network connection."),
    "ERR_NET_JOIN_FAILED": ("Odaya bağlanılamadı. Aynı ağda olduğunuzdan ve adresin doğru olduğundan emin ol.", "Couldn't connect to the room. Make sure you're on the same network and the address is correct."),
    "ERR_NET_HOST_GONE": ("Oda sahibine ulaşılamıyor; oda kapanmış olabilir.", "The host can't be reached; the room may have closed."),
    "ERR_NET_BAD_CODE": ("Oda kodu yanlış.", "Wrong room code."),
    "ERR_NET_BAD_CODE_FORMAT": ("Oda kodu 6 karakter olmalı.", "Room codes have 6 characters."),
    "ERR_NET_BAD_IP": ("Geçerli bir IP adresi gir (ör. 192.168.1.20).", "Enter a valid IP address (e.g. 192.168.1.20)."),
    "ERR_NET_ROOM_FULL": ("Oda dolu.", "The room is full."),
    "ERR_NET_IN_MATCH": ("Odada maç sürüyor; bitince katılabilirsin.", "A match is in progress; you can join when it ends."),
    "ERR_NET_VERSION": ("Oyun sürümleri uyuşmuyor. Herkes Card Rush'ı güncellemeli.", "Game versions don't match. Everyone should update Card Rush."),
    "ERR_NET_NOT_READY": ("Tüm oyuncuların hazır olması bekleniyor.", "Waiting for all players to be ready."),
    "ERR_NET_NOT_CONNECTED": ("Bağlantı yok; hamle gönderilemedi.", "Not connected; the move wasn't sent."),
    "ERR_NET_RATE_LIMIT": ("Çok hızlı! Hamleni tekrar dene.", "Too fast! Try your move again."),
}


def main():
    out = os.path.join(os.path.dirname(__file__), "..", "..", "data", "localization", "strings.csv")
    with open(out, "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f, quoting=csv.QUOTE_MINIMAL, lineterminator="\n")
        w.writerow(["keys", "tr", "en"])
        for k in sorted(S):
            tr, en = S[k]
            w.writerow([k, tr, en])
    print("wrote %d keys -> %s" % (len(S), os.path.abspath(out)))


if __name__ == "__main__":
    main()
