extends AdsBackend
## TEST-ONLY backend: debug builds with --mock-ads (or CARDRUSH_MOCK_ADS=1),
## and automated tests. It never shows a real ad; every "show" is logged and
## labelled MOCK. Mock results are not evidence that real ads work.

var fail_loads := false          # simulate "no fill / offline"
var user_skips_reward := false   # simulate closing before the reward
var duplicate_reward := true     # SDKs can call back twice: manager must grant once
var loads := {"banner": 0, "interstitial": 0, "rewarded": 0}
var shows := {"interstitial": 0, "rewarded": 0}
var banner_visible := false
var _i_ready := false
var _r_ready := false


func kind() -> String:
	return "mock"


func banner_load() -> void:
	loads["banner"] += 1
	if fail_loads:
		banner_failed.emit("mock: no fill")
	else:
		banner_loaded.emit()


func banner_set_visible(on: bool) -> void:
	banner_visible = on


func banner_destroy() -> void:
	banner_visible = false


func interstitial_load() -> void:
	loads["interstitial"] += 1
	if fail_loads:
		interstitial_failed.emit("mock: offline")
		return
	_i_ready = true
	interstitial_loaded.emit()


func interstitial_ready() -> bool:
	return _i_ready


func interstitial_show(on_closed: Callable) -> void:
	if not _i_ready:
		on_closed.call(false)
		return
	_i_ready = false
	shows["interstitial"] += 1
	print("[Ads][MOCK] interstitial (not a real ad)")
	on_closed.call(true)


func rewarded_load() -> void:
	loads["rewarded"] += 1
	if fail_loads:
		rewarded_failed.emit("mock: offline")
		return
	_r_ready = true
	rewarded_loaded.emit()


func rewarded_ready() -> bool:
	return _r_ready


func rewarded_show(on_earned: Callable, on_closed: Callable) -> void:
	if not _r_ready:
		on_closed.call(false)
		return
	_r_ready = false
	shows["rewarded"] += 1
	print("[Ads][MOCK] rewarded (not a real ad)")
	if not user_skips_reward:
		on_earned.call()
		if duplicate_reward:
			on_earned.call()
	on_closed.call(true)


func destroy_all() -> void:
	banner_visible = false
	_i_ready = false
	_r_ready = false
