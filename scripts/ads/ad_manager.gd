extends Node
## AdManager (autoload "Ads"). Pacing, banner visibility, rewarded grants and
## retry back-off over exactly one AdsBackend:
##   admob — real Google Mobile Ads SDK on Android/iOS (plugin present)
##   none  — desktop/Windows or no SDK: no ads, no rewarded offers, no errors
##   mock  — debug builds with --mock-ads, and tests (never a real ad)
## Premium players never trigger any ad request.
## Ads are never shown during a turn: interstitials only after a finished
## match when leaving the result screen; banners only on menu screens.

signal rewarded_availability_changed(available: bool)
signal banner_state_changed(visible: bool)

enum LoadState { IDLE, LOADING, READY, FAILED }

## Space reserved at the bottom of menu screens while a banner shows (px in
## the 720p canvas; adaptive banners are at most ~90 dp in landscape).
const BANNER_RESERVE := 64

var backend: AdsBackend
var initialized := false
var _want_banner := false
var _banner_state := LoadState.IDLE
var _i_state := LoadState.IDLE
var _r_state := LoadState.IDLE
var _retry := {"banner": 0, "interstitial": 0, "rewarded": 0}
var _session_matches := 0
var _showing_fullscreen := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	use_backend(_choose_backend())
	Store.entitlements_changed.connect(_on_entitlements_changed)
	print("[Ads] backend=%s test_units=%s" % [backend.kind(), AdConfig.use_test_ads()])


static func mock_requested() -> bool:
	return OS.is_debug_build() and (OS.get_cmdline_user_args().has("--mock-ads") or OS.get_environment("CARDRUSH_MOCK_ADS") == "1")


func _choose_backend() -> AdsBackend:
	if mock_requested():
		return load("res://scripts/ads/mock_ads_backend.gd").new()
	if OS.has_feature("mobile"):
		var script: GDScript = load("res://scripts/ads/admob_backend.gd")
		if script and script.call("available"):
			return script.new()
	return AdsBackend.new()


## Swaps the backend (tests inject the mock).
func use_backend(b: AdsBackend) -> void:
	backend = b
	initialized = false
	_banner_state = LoadState.IDLE
	_i_state = LoadState.IDLE
	_r_state = LoadState.IDLE
	b.banner_loaded.connect(func():
		_banner_state = LoadState.READY
		_retry["banner"] = 0
		b.banner_set_visible(_want_banner and _ads_allowed())
		banner_state_changed.emit(banner_visible()))
	b.banner_failed.connect(func(msg: String): _on_fail("banner", msg))
	b.interstitial_loaded.connect(func():
		_i_state = LoadState.READY
		_retry["interstitial"] = 0)
	b.interstitial_failed.connect(func(msg: String): _on_fail("interstitial", msg))
	b.rewarded_loaded.connect(func():
		_r_state = LoadState.READY
		_retry["rewarded"] = 0
		rewarded_availability_changed.emit(can_offer_rewarded()))
	b.rewarded_failed.connect(func(msg: String):
		_on_fail("rewarded", msg)
		rewarded_availability_changed.emit(false))


func has_ads() -> bool:
	return backend.kind() != "none"


func _ads_allowed() -> bool:
	return has_ads() and initialized and not Store.is_premium()


## Called once at boot: consent (Google UMP) first, then SDK initialisation.
func start(on_done: Callable) -> void:
	if not has_ads() or Store.is_premium():
		on_done.call()
		return
	if backend.kind() == "mock":
		initialized = true
		_preload()
		on_done.call()
		return
	backend.request_consent(func():
		Save.section("ads")["consent_done"] = true
		Save.mark_dirty()
		backend.initialize(func():
			initialized = true
			_preload()
			on_done.call()))


func _preload() -> void:
	if not _ads_allowed():
		return
	if _i_state in [LoadState.IDLE, LoadState.FAILED]:
		_i_state = LoadState.LOADING
		backend.interstitial_load()
	if _r_state in [LoadState.IDLE, LoadState.FAILED]:
		_r_state = LoadState.LOADING
		backend.rewarded_load()


func _on_fail(kind: String, msg: String) -> void:
	match kind:
		"banner":
			_banner_state = LoadState.FAILED
			banner_state_changed.emit(false)
		"interstitial":
			_i_state = LoadState.FAILED
		"rewarded":
			_r_state = LoadState.FAILED
	_retry[kind] = int(_retry[kind]) + 1
	var wait := minf(AdConfig.RETRY_MAX_SECONDS, AdConfig.RETRY_BASE_SECONDS * pow(2.0, _retry[kind] - 1))
	push_warning("[Ads] %s failed (%s), retry in %ds" % [kind, msg, int(wait)])
	if is_inside_tree():
		get_tree().create_timer(wait, true).timeout.connect(func(): _retry_load(kind))


func _retry_load(kind: String) -> void:
	if not _ads_allowed():
		return
	match kind:
		"banner":
			if _want_banner and _banner_state == LoadState.FAILED:
				_banner_state = LoadState.LOADING
				backend.banner_load()
		"interstitial":
			if _i_state == LoadState.FAILED:
				_i_state = LoadState.LOADING
				backend.interstitial_load()
		"rewarded":
			if _r_state == LoadState.FAILED:
				_r_state = LoadState.LOADING
				backend.rewarded_load()


# --- banner (menu screens only) ---------------------------------------------------------

## One banner object is reused across screens (no new request per screen).
func show_banner() -> void:
	_want_banner = true
	if not _ads_allowed():
		return
	match _banner_state:
		LoadState.IDLE:
			_banner_state = LoadState.LOADING
			backend.banner_load()
		LoadState.READY:
			backend.banner_set_visible(true)
			banner_state_changed.emit(true)


func hide_banner() -> void:
	_want_banner = false
	backend.banner_set_visible(false)
	banner_state_changed.emit(false)


func banner_visible() -> bool:
	return _want_banner and _banner_state == LoadState.READY and _ads_allowed()


func banner_reserve() -> int:
	return BANNER_RESERVE if banner_visible() else 0


# --- interstitial ------------------------------------------------------------------------

func on_match_completed() -> void:
	_session_matches += 1
	var a := Save.section("ads")
	a["total_matches"] = int(a.get("total_matches", 0)) + 1
	a["since_interstitial"] = int(a.get("since_interstitial", 0)) + 1
	Save.mark_dirty()


func interstitial_due() -> bool:
	if not _ads_allowed() or _showing_fullscreen:
		return false
	var a := Save.section("ads")
	if _session_matches < 1:
		return false
	if int(a.get("total_matches", 0)) < AdConfig.MIN_MATCHES_BEFORE_FIRST:
		return false
	if int(a.get("since_interstitial", 0)) < AdConfig.MIN_MATCHES_BETWEEN:
		return false
	if Time.get_unix_time_from_system() - float(a.get("last_interstitial_unix", 0)) < AdConfig.MIN_SECONDS_BETWEEN:
		return false
	return backend.interstitial_ready()


## At a natural break (leaving the result screen). Never waits for a load:
## if nothing is ready on_done runs immediately.
func maybe_show_interstitial(on_done: Callable) -> void:
	if not interstitial_due():
		on_done.call()
		return
	_showing_fullscreen = true
	_i_state = LoadState.IDLE
	Audio.stop_music()
	backend.interstitial_show(func(shown: bool):
		_showing_fullscreen = false
		if shown:
			var a := Save.section("ads")
			a["since_interstitial"] = 0
			a["last_interstitial_unix"] = int(Time.get_unix_time_from_system())
			Save.mark_dirty()
		_preload()
		on_done.call())


# --- rewarded ----------------------------------------------------------------------------

func _rewarded_today() -> int:
	var a := Save.section("ads")
	if str(a.get("rewarded_day", "")) != Time.get_date_string_from_system():
		return 0
	return int(a.get("rewarded_count", 0))


func can_offer_rewarded() -> bool:
	return _ads_allowed() and backend.rewarded_ready() and _rewarded_today() < AdConfig.REWARDED_DAILY_CAP and not _showing_fullscreen


## on_result(granted: bool). The reward is granted ONLY from the SDK's
## earned-reward callback, at most once per ad (unique ledger key) — closing
## the ad is not a reward.
func show_rewarded(reason: String, coins: int, on_result: Callable) -> void:
	if not can_offer_rewarded():
		on_result.call(false)
		return
	_showing_fullscreen = true
	_r_state = LoadState.IDLE
	var key := "ad_%d_%s" % [Time.get_ticks_usec(), Crypto.new().generate_random_bytes(4).hex_encode()]
	var granted := [false]
	backend.rewarded_show(func():
		if granted[0]:
			return
		if Economy.grant(coins, reason, key):
			granted[0] = true
			var a := Save.section("ads")
			var today := Time.get_date_string_from_system()
			if str(a.get("rewarded_day", "")) != today:
				a["rewarded_day"] = today
				a["rewarded_count"] = 0
			a["rewarded_count"] = int(a.get("rewarded_count", 0)) + 1
			Save.mark_dirty(),
		func(_shown: bool):
			_showing_fullscreen = false
			_preload()
			rewarded_availability_changed.emit(can_offer_rewarded())
			on_result.call(granted[0]))


# --- privacy -----------------------------------------------------------------------------

func privacy_options_required() -> bool:
	return has_ads() and backend.privacy_options_required()


func show_privacy_options(on_done: Callable) -> void:
	backend.show_privacy_options(on_done)


func _on_entitlements_changed() -> void:
	if Store.is_premium():
		# Premium: stop everything, not just hide it
		backend.destroy_all()
		_banner_state = LoadState.IDLE
		_i_state = LoadState.IDLE
		_r_state = LoadState.IDLE
		banner_state_changed.emit(false)
		rewarded_availability_changed.emit(false)
