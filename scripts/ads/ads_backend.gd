class_name AdsBackend
extends RefCounted
## Interface for ad providers. AdsManager owns pacing/rewards; backends only
## talk to an SDK. Callbacks are always delivered at most once per request.

signal banner_loaded
signal banner_failed(msg: String)
signal interstitial_loaded
signal interstitial_failed(msg: String)
signal rewarded_loaded
signal rewarded_failed(msg: String)

## "admob" | "none" | "mock"
func kind() -> String:
	return "none"


## True only for the real SDK. Mock/none never claim to show real ads.
func is_real_sdk() -> bool:
	return false


func initialize(_on_done: Callable) -> void:
	_on_done.call()


func request_consent(on_done: Callable) -> void:
	on_done.call()


func privacy_options_required() -> bool:
	return false


func show_privacy_options(on_done: Callable) -> void:
	on_done.call()


func banner_load() -> void:
	pass


func banner_set_visible(_on: bool) -> void:
	pass


func banner_destroy() -> void:
	pass


## Real banner height in screen pixels (0 if unknown).
func banner_height_px() -> int:
	return 0


func interstitial_load() -> void:
	pass


func interstitial_ready() -> bool:
	return false


## on_closed(shown: bool)
func interstitial_show(on_closed: Callable) -> void:
	on_closed.call(false)


func rewarded_load() -> void:
	pass


func rewarded_ready() -> bool:
	return false


## on_earned() fires only from the SDK reward callback; on_closed(shown: bool) always fires once.
func rewarded_show(_on_earned: Callable, on_closed: Callable) -> void:
	on_closed.call(false)


func destroy_all() -> void:
	pass
