extends Node
## PurchaseManager (autoload "Store"). Premium (no ads + premium cosmetics)
## and cosmetic packs. Ownership comes from the platform store; the local save
## is only a cache used while the store is unreachable, for at most GRACE_DAYS
## after the last successful verification, and never on desktop (a copied
## save file must not unlock paid features). Prices are the store's localized
## strings — never invented. Purchase events are applied idempotently.
##   google_play — GodotGooglePlayBilling 3.3.0 (Android)
##   app_store   — official InAppStore iOS plugin (must be built on macOS)
##   unavailable — Windows/desktop or no plugin: no purchase UI pretends otherwise
##   mock        — debug builds with --mock-store, and tests

signal products_updated
signal purchase_state_changed(product_id: String, state: String, message: String)
signal entitlements_changed
signal availability_changed(available: bool)

const GRACE_DAYS := 30

var products: Array = []                # data/store/products.json (filtered by platform)
var product_info: Dictionary = {}       # id -> {title, price, available}
var backend: StoreBackend
var connected := false
var _last_purchase_id := ""
var _owned: Array = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/store/products.json"))
	var all: Array = d.get("products", []) if d is Dictionary else []
	var plat := "ios" if OS.get_name() == "iOS" else "android"
	products = all.filter(func(p): return p.get("platforms", [plat]).has(plat))
	_load_cache()
	use_backend(_choose_backend())


static func mock_requested() -> bool:
	return OS.is_debug_build() and (OS.get_cmdline_user_args().has("--mock-store") or OS.get_environment("CARDRUSH_MOCK_STORE") == "1")


func _choose_backend() -> StoreBackend:
	if mock_requested():
		return load("res://scripts/purchases/mock_store_backend.gd").new()
	if OS.get_name() == "Android":
		var g: GDScript = load("res://scripts/purchases/google_play_backend.gd")
		if g.call("available"):
			var b: StoreBackend = g.new()
			b.call("setup", self)
			return b
	elif OS.get_name() == "iOS":
		var a: GDScript = load("res://scripts/purchases/app_store_backend.gd")
		if a.call("available"):
			return a.new()
	return StoreBackend.new()


## Swaps the backend (tests inject the mock).
func use_backend(b: StoreBackend) -> void:
	backend = b
	connected = false
	b.connected_changed.connect(_on_connected)
	b.products_received.connect(_on_products)
	b.owned_received.connect(_on_owned)
	b.purchase_result.connect(_on_purchase_result)
	print("[Store] backend=%s" % b.kind())
	b.connect_store()


func _process(_d: float) -> void:
	backend.poll()


func is_available() -> bool:
	return backend.is_available() and connected


func backend_kind() -> String:
	return backend.kind()


func product(id: String) -> Dictionary:
	for p in products:
		if p["id"] == id:
			return p
	return {}


func price_of(id: String) -> String:
	return str(product_info.get(id, {}).get("price", ""))


# --- entitlements --------------------------------------------------------------------

func _trust_cache() -> bool:
	return OS.get_name() in ["Android", "iOS"] or mock_requested() or backend_kind() == "mock"


func _load_cache() -> void:
	var e := Save.section("store")
	var age_days := (Time.get_unix_time_from_system() - float(e.get("verified_unix", 0))) / 86400.0
	_owned = []
	if (OS.get_name() in ["Android", "iOS"] or mock_requested()) and age_days <= GRACE_DAYS:
		for pid in e.get("owned", []):
			if not product(str(pid)).is_empty():
				_owned.append(str(pid))


func is_premium() -> bool:
	for pid in _owned:
		if product(pid).get("grants", "") == "premium":
			return true
	return false


func owns(product_id: String) -> bool:
	return _owned.has(product_id)


## Cosmetic ids unlocked by owned packs (premium cosmetics handled by Cosmetics).
func pack_items() -> Array:
	var out := []
	for pid in _owned:
		var p := product(pid)
		if p.get("grants", "") == "pack":
			out.append_array(p.get("items", []))
	return out


func _save_cache() -> void:
	var e := Save.section("store")
	e["owned"] = _owned.duplicate()
	e["verified_unix"] = int(Time.get_unix_time_from_system())
	Save.mark_dirty()


# --- store flow ------------------------------------------------------------------------

func _on_connected(ok: bool) -> void:
	connected = ok
	availability_changed.emit(ok)
	if ok:
		backend.query_products(products)
		if backend.kind() != "app_store":
			backend.query_owned(products)


func _on_products(list: Array) -> void:
	for p in list:
		product_info[p["id"]] = p
	products_updated.emit()


## ok=false means the store could not answer: keep the cache, never revoke.
## ok=true is a full snapshot from the store: it replaces the cache (refunds
## and expired subscriptions disappear here).
func _on_owned(ok: bool, owned_ids: Array) -> void:
	if not ok:
		return
	var known := []
	for pid in owned_ids:
		if not product(str(pid)).is_empty() and not known.has(str(pid)):
			known.append(str(pid))
	var changed := known != _owned
	_owned = known
	_save_cache()
	if changed:
		entitlements_changed.emit()


func purchase(id: String) -> void:
	var p := product(id)
	if p.is_empty():
		purchase_state_changed.emit(id, "failed", "ERR_STORE_UNKNOWN_PRODUCT")
		return
	if not is_available():
		purchase_state_changed.emit(id, "failed", "ERR_STORE_UNAVAILABLE")
		return
	if owns(id):
		purchase_state_changed.emit(id, "already_owned", "")
		return
	_last_purchase_id = id
	purchase_state_changed.emit(id, "started", "")
	backend.purchase(p)


## Idempotent: a duplicated "purchased" event never grants twice.
func _on_purchase_result(pid: String, state: String, msg: String) -> void:
	if pid.is_empty():
		pid = _last_purchase_id
	match state:
		"purchased", "already_owned":
			if not _owned.has(pid) and not product(pid).is_empty():
				_owned.append(pid)
				_save_cache()
				entitlements_changed.emit()
				Audio.play("reward")
	purchase_state_changed.emit(pid, state, msg)


func restore() -> void:
	if not is_available():
		purchase_state_changed.emit("", "failed", "ERR_STORE_UNAVAILABLE")
		return
	backend.restore(products)


## Where players manage/cancel subscriptions (store-owned UI).
func manage_subscriptions_url() -> String:
	if OS.get_name() == "Android":
		return "https://play.google.com/store/account/subscriptions?package=%s" % str(ProjectSettings.get_setting("card_rush/store/android_package", ""))
	if OS.get_name() == "iOS":
		return "https://apps.apple.com/account/subscriptions"
	return ""
