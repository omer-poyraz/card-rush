extends TestCase
## Ads, purchases, coins, cosmetics and missions. Ads/store are exercised ONLY
## through clearly labelled mock backends — mock results are never evidence
## that real ads or real purchases work.

const MockAds = preload("res://scripts/ads/mock_ads_backend.gd")
const MockStore = preload("res://scripts/purchases/mock_store_backend.gd")

var _ads_backend: AdsBackend
var _store_backend: StoreBackend
var _ads_init := false


func before_each() -> void:
	_ads_backend = Ads.backend
	_ads_init = Ads.initialized
	_store_backend = Store.backend
	Save.data = Save.defaults()


func after_each() -> void:
	Ads.use_backend(_ads_backend)
	Ads.initialized = _ads_init
	Store.use_backend(_store_backend)
	Store._owned = []
	Save.data = Save.defaults()


func _mock_ads() -> MockAds:
	var m := MockAds.new()
	Ads.use_backend(m)
	var done := [false]
	Ads.start(func(): done[0] = true)
	check(done[0], "mock start completes")
	return m


func _mock_store() -> MockStore:
	var m := MockStore.new()
	Store._owned = []
	Store.use_backend(m)
	return m


# --- ads -------------------------------------------------------------------------------

func test_no_sdk_platform_is_safe() -> void:
	Ads.use_backend(AdsBackend.new())
	var done := [false, false]
	Ads.start(func(): done[0] = true)
	Ads.show_banner()
	Ads.maybe_show_interstitial(func(): done[1] = true)
	check(done[0] and done[1], "callbacks still run without an SDK")
	check(not Ads.can_offer_rewarded(), "no rewarded offers without SDK")
	eq(Ads.banner_reserve(), 0)
	var got := [null]
	Ads.show_rewarded("x", 30, func(g): got[0] = g)
	eq(got[0], false)


func test_reward_only_from_callback_and_only_once() -> void:
	var m := _mock_ads()
	check(Ads.can_offer_rewarded(), "rewarded loaded")
	var before := Economy.coins()
	var res := [null]
	Ads.show_rewarded("test", 30, func(g): res[0] = g)
	eq(res[0], true)
	eq(Economy.coins(), before + 30, "granted exactly once despite a duplicated SDK callback")
	# user closes before the reward: nothing granted
	m.user_skips_reward = true
	m.rewarded_load()
	Ads._r_state = Ads.LoadState.READY
	var res2 := [null]
	Ads.show_rewarded("test", 30, func(g): res2[0] = g)
	eq(res2[0], false)
	eq(Economy.coins(), before + 30, "closing the ad is not a reward")


func test_interstitial_pacing() -> void:
	var m := _mock_ads()
	var done := [0]
	Ads.maybe_show_interstitial(func(): done[0] += 1)
	eq(m.shows["interstitial"], 0, "never before any finished match")
	for i in AdConfig.MIN_MATCHES_BEFORE_FIRST:
		Ads.on_match_completed()
	Save.section("ads")["last_interstitial_unix"] = 0
	Ads.maybe_show_interstitial(func(): done[0] += 1)
	eq(m.shows["interstitial"], 1, "shown at a natural break once due")
	m.interstitial_load()
	Ads.on_match_completed()
	Ads.maybe_show_interstitial(func(): done[0] += 1)
	eq(m.shows["interstitial"], 1, "spacing: not after every match")
	eq(done[0], 3, "flow always continues")


func test_failed_loads_never_block() -> void:
	var m := MockAds.new()
	m.fail_loads = true
	Ads.use_backend(m)
	Ads.start(func(): pass)
	for i in 5:
		Ads.on_match_completed()
	var done := [false]
	Ads.maybe_show_interstitial(func(): done[0] = true)
	check(done[0], "no ad loaded -> continue immediately")
	check(not Ads.can_offer_rewarded())


func test_premium_blocks_ad_requests() -> void:
	var store := _mock_store()
	store.next_result = "purchased"
	Store.purchase("cardrush_premium")
	check(Store.is_premium(), "premium owned")
	var m := MockAds.new()
	Ads.use_backend(m)
	Ads.start(func(): pass)
	Ads.show_banner()
	for i in 5:
		Ads.on_match_completed()
	Ads.maybe_show_interstitial(func(): pass)
	eq(m.loads["banner"] + m.loads["interstitial"] + m.loads["rewarded"], 0, "premium: no ad requests at all")
	eq(m.shows["interstitial"], 0)
	check(not Ads.can_offer_rewarded())


func test_buying_premium_stops_running_ads() -> void:
	var m := _mock_ads()
	Ads.show_banner()
	check(m.banner_visible, "banner shown before premium")
	var store := _mock_store()
	Store.purchase("cardrush_premium")
	check(not m.banner_visible, "banner destroyed after purchase")
	check(not Ads.can_offer_rewarded())


# --- purchases ------------------------------------------------------------------------------

func test_purchase_is_idempotent() -> void:
	var store := _mock_store()
	var events := [0]
	Store.entitlements_changed.connect(func(): events[0] += 1)
	Store.purchase("cardrush_pack_neon")
	check(Store.owns("cardrush_pack_neon"))
	Store._on_purchase_result("cardrush_pack_neon", "purchased", "dup")
	eq(events[0], 1, "duplicate purchase event changes nothing")
	eq(Store.pack_items().size(), 3)


func test_canceled_and_pending_and_failed() -> void:
	var store := _mock_store()
	store.next_result = "canceled"
	Store.purchase("cardrush_premium")
	check(not Store.is_premium(), "canceled grants nothing")
	store.next_result = "pending"
	Store.purchase("cardrush_premium")
	check(not Store.is_premium(), "pending is not owned yet")
	store.complete_pending("cardrush_premium")
	check(Store.is_premium(), "unlocked when the store confirms")
	store.offline = true
	Store.connected = false
	var st := [""]
	Store.purchase_state_changed.connect(func(_p, s, _m): st[0] = s)
	Store.purchase("cardrush_pack_neon")
	eq(st[0], "failed", "offline purchase fails clearly")


func test_restore_and_refund_snapshot() -> void:
	var store := _mock_store()
	store.owned = ["cardrush_premium"]
	Store.restore()
	check(Store.is_premium(), "restored from store")
	store.owned = []
	Store.restore()
	check(not Store.is_premium(), "store snapshot without the item revokes (refund)")
	store.offline = true
	store.owned = ["cardrush_premium"]
	Store._on_owned(false, [])
	check(not Store.is_premium(), "an unreachable store never grants")


func test_desktop_never_trusts_a_copied_save() -> void:
	Save.section("store")["owned"] = ["cardrush_premium"]
	Save.section("store")["verified_unix"] = int(Time.get_unix_time_from_system())
	Store._load_cache()
	if OS.get_name() in ["Android", "iOS"]:
		return
	check(not Store.is_premium(), "is_premium = true from a save file is ignored on desktop")


func test_subscriptions_only_where_verifiable() -> void:
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/store/products.json"))
	for p in d["products"]:
		if p["type"] == "subs":
			check(not p["platforms"].has("ios"), "no iOS subscriptions without receipt validation")


# --- coins, cosmetics, missions ------------------------------------------------------------

func test_economy_unique_keys() -> void:
	check(Economy.grant(50, "t", "k1"))
	check(not Economy.grant(50, "t", "k1"), "same key never paid twice")
	eq(Economy.coins(), 50)
	check(not Economy.spend(60, "x"), "cannot overspend")
	check(Economy.spend(20, "x"))
	eq(Economy.coins(), 30)


func test_cosmetics_buy_and_equip() -> void:
	eq(Cosmetics.equipped("back"), "back_classic")
	eq(Cosmetics.buy("back_sunset"), "ERR_NOT_ENOUGH_COINS")
	Economy.grant(500, "t", "seed")
	eq(Cosmetics.buy("back_sunset"), "")
	eq(Economy.coins(), 350)
	eq(Cosmetics.buy("back_sunset"), "ERR_COSMETIC_OWNED")
	check(Cosmetics.equip("back_sunset"))
	eq(Cosmetics.equipped("back"), "back_sunset")
	check(not Cosmetics.equip("back_neon"), "cannot equip locked premium item")
	eq(Cosmetics.buy("back_neon"), "ERR_COSMETIC_NOT_BUYABLE")


func test_premium_and_pack_unlocks() -> void:
	var store := _mock_store()
	check(not Cosmetics.is_owned("back_mint"))
	Store.purchase("cardrush_pack_neon")
	check(Cosmetics.is_owned("back_mint"), "pack item")
	check(Cosmetics.is_owned("back_neon"), "premium item also in the pack")
	check(not Cosmetics.is_owned("table_royal"))
	Store.purchase("cardrush_premium")
	check(Cosmetics.is_owned("table_royal"), "premium item")


func test_equipped_falls_back_when_no_longer_owned() -> void:
	Save.section("cosmetics")["equipped"] = {"table": "table_royal"}
	eq(Cosmetics.equipped("table"), "table_night")


func test_missions_progress_and_single_claim() -> void:
	var s := Missions.state()
	eq(s["daily"].size(), Missions.DAILY_COUNT)
	eq(s["weekly"].size(), Missions.WEEKLY_COUNT)
	for i in 20:
		Missions.on_match({"won": true, "cards_played": 30, "actions": 8, "uno_calls": 2, "catches": 1, "online": true, "bot_level": 2, "points_mode": true})
	var paid := 0
	for m in s["daily"]:
		paid += Missions.claim(m["id"])
	check(paid > 0, "daily missions claimable")
	var before := Economy.coins()
	for m in s["daily"]:
		eq(Missions.claim(m["id"]), 0, "claimed once")
	eq(Economy.coins(), before)


func test_daily_login_once_per_day() -> void:
	var st := Missions.login_status()
	check(st["can_claim"])
	check(Missions.claim_login() > 0)
	eq(Missions.claim_login(), 0, "second claim the same day pays nothing")


func test_dynamic_translation_keys() -> void:
	var keys := {}
	var f := FileAccess.open("res://data/localization/strings.csv", FileAccess.READ)
	f.get_csv_line()
	while not f.eof_reached():
		var row := f.get_csv_line()
		if row.size() > 0:
			keys[row[0]] = true
	for it in Cosmetics.items():
		check(keys.has("COS_" + str(it["id"]).to_upper()), "name for " + str(it["id"]))
	for m in Missions.DAILY_POOL + Missions.WEEKLY_POOL:
		check(keys.has("MISSION_" + str(m["stat"]).to_upper()), "mission text " + str(m["stat"]))
	for st in NetProtocol.AD_STATUSES:
		check(keys.has("ADEVENT_ST_" + st.to_upper()), "status " + st)
	for p in ["cardrush_premium", "cardrush_premium_monthly", "cardrush_premium_yearly"]:
		check(keys.has("STORE_" + p.to_upper()), p)


# --- shared ad event -----------------------------------------------------------------------

func test_shared_ad_event_flow() -> void:
	var server := LoopbackTransport.make_server()
	var h := RoomHost.new()
	runner.add_child(h)
	h.start(server, {"name": "A", "max_players": 4, "rules": {}}, "Host", 0)
	var c := RoomClient.new()
	c.transport_factory = func(_a, _p): return LoopbackTransport.make_client(server)
	runner.add_child(c)
	c.join("loop", 0, h.code, "Guest", 1)
	var t0 := Time.get_ticks_msec()
	while c.state != RoomClient.State.LOBBY and Time.get_ticks_msec() - t0 < 3000:
		await frames(1)
	var proposed := [""]
	c.ad_event_proposed.connect(func(id, _coins, _from): proposed[0] = id)
	eq(h.propose_ad_event(30), "")
	await frames(3)
	eq(proposed[0], h.ad_event["id"], "client got the proposal")
	c.send_ad_result(proposed[0], "declined")
	await frames(3)
	eq(h.ad_event["statuses"][c.pid], "declined", "per-player status tracked")
	c.send_ad_result("bogus", "completed")
	c.send_ad_result(proposed[0], "hacked")
	await frames(3)
	eq(h.ad_event["statuses"][c.pid], "declined", "invalid reports ignored")
	# never during an active hand
	c.set_ready(true)
	while h.can_start() != "" and Time.get_ticks_msec() - t0 < 5000:
		await frames(1)
	h.start_match()
	await frames(30)
	if h.authority and h.authority.state.phase < GameState.Phase.MATCH_OVER:
		eq(h.propose_ad_event(30), "ERR_AD_EVENT_MID_MATCH")
	c.queue_free()
	h.queue_free()
	await frames(2)
