extends StoreBackend
## Apple StoreKit through the official godot-ios-plugins "InAppStore" plugin.
## The plugin binary must be built on macOS for the exact Godot version and
## added to ios/plugins (see docs/ADS_AND_IAP.md). Events are polled.
## Limitation: without server-side receipt validation, restored auto-renewable
## subscriptions cannot be checked for expiry on-device; the PRO screen offers
## the lifetime product as the recommended iOS option.

var _store: Object
var _owned: Array = []
var _restoring := false


static func available() -> bool:
	return Engine.has_singleton("InAppStore")


func kind() -> String:
	return "app_store"


func is_available() -> bool:
	return _store != null


func connect_store() -> void:
	_store = Engine.get_singleton("InAppStore")
	if _store and _store.has_method("set_auto_finish_transaction"):
		_store.set_auto_finish_transaction(true)
	connected_changed.emit(_store != null)


func query_products(products: Array) -> void:
	if _store == null:
		products_received.emit([])
		return
	var ids := PackedStringArray(products.map(func(p): return p.id))
	_store.request_product_info({"product_ids": ids})


func query_owned(_products: Array) -> void:
	# StoreKit 1 has no silent ownership query; restore is the only path.
	restore(_products)


func purchase(product: Dictionary) -> void:
	if _store == null:
		purchase_result.emit(str(product.id), "failed", "store unavailable")
		return
	var err: int = _store.purchase({"product_id": product.id})
	if err != OK:
		purchase_result.emit(str(product.id), "failed", "purchase request error %d" % err)


func restore(_products: Array) -> void:
	if _store == null:
		owned_received.emit(false, [])
		return
	_owned.clear()
	_restoring = true
	_store.restore_purchases()


func poll() -> void:
	if _store == null:
		return
	while _store.get_pending_event_count() > 0:
		var e: Dictionary = _store.pop_pending_event()
		match str(e.get("type", "")):
			"product_info":
				var out := []
				var ids: Array = e.get("ids", [])
				var titles: Array = e.get("titles", [])
				var prices: Array = e.get("localized_prices", e.get("prices", []))
				for i in ids.size():
					out.append({"id": str(ids[i]), "title": str(titles[i]) if i < titles.size() else str(ids[i]),
						"price": str(prices[i]) if i < prices.size() else "", "available": true})
				products_received.emit(out)
			"purchase":
				var pid := str(e.get("product_id", ""))
				match str(e.get("result", "")):
					"ok": purchase_result.emit(pid, "purchased", "")
					"progress": purchase_result.emit(pid, "pending", "")
					"canceled", "cancelled": purchase_result.emit(pid, "canceled", "")
					_: purchase_result.emit(pid, "failed", str(e.get("error", "")))
			"restore":
				if str(e.get("result", "")) == "ok":
					_owned.append(str(e.get("product_id", "")))
			"completion":
				if _restoring:
					_restoring = false
					owned_received.emit(str(e.get("result", "ok")) == "ok", _owned.duplicate())
