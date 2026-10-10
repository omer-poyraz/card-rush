extends StoreBackend
## Google Play Billing through the official GodotGooglePlayBilling plugin 3.3.0
## (addons/GodotGooglePlayBilling, MIT, Play Billing Library 9.1).
## Purchases are acknowledged after being granted; nothing is consumed (all
## products are non-consumable or subscriptions).

var client: BillingClient
var _details: Dictionary = {}     # product id -> product details dictionary
var _pending_inapp: Array = []
var _pending_subs: Array = []
var _owned_inapp: Array = []
var _owned_subs: Array = []
var _owned_ok := [true, true]
var _owned_waiting := 0


static func available() -> bool:
	return Engine.has_singleton("GodotGooglePlayBilling")


func kind() -> String:
	return "google_play"


func is_available() -> bool:
	return client != null and client.is_ready()


func setup(host: Node) -> void:
	client = BillingClient.new()
	host.add_child(client)
	client.connected.connect(func(): connected_changed.emit(true))
	client.disconnected.connect(func(): connected_changed.emit(false))
	client.connect_error.connect(func(_code: int, _msg: String): connected_changed.emit(false))
	client.query_product_details_response.connect(_on_details)
	client.query_purchases_response.connect(_on_purchases)
	client.on_purchase_updated.connect(_on_purchase_updated)


func connect_store() -> void:
	client.start_connection()


func query_products(products: Array) -> void:
	_pending_inapp = products.filter(func(p): return p.type == "inapp").map(func(p): return p.id)
	_pending_subs = products.filter(func(p): return p.type == "subs").map(func(p): return p.id)
	if not _pending_inapp.is_empty():
		client.query_product_details(PackedStringArray(_pending_inapp), BillingClient.ProductType.INAPP)
	if not _pending_subs.is_empty():
		client.query_product_details(PackedStringArray(_pending_subs), BillingClient.ProductType.SUBS)


static func _price_of(d: Dictionary) -> String:
	for o in d.get("one_time_purchase_offer_details_list", []):
		if o.get("offer_id") == null or str(o.get("offer_id", "")).is_empty():
			return str(o.get("formatted_price", ""))
	var one: Variant = d.get("one_time_purchase_offer_details", null)
	if typeof(one) == TYPE_DICTIONARY:
		return str(one.get("formatted_price", ""))
	for s in d.get("subscription_offer_details", []):
		# base plan (no offer) -> last pricing phase is the recurring price
		if s.get("offer_id") == null or str(s.get("offer_id", "")).is_empty():
			var phases: Array = s.get("pricing_phases", [])
			if not phases.is_empty():
				return str(phases[phases.size() - 1].get("formatted_price", ""))
	return ""


func _on_details(result: Dictionary) -> void:
	if int(result.get("response_code", -1)) != BillingClient.BillingResponseCode.OK:
		products_received.emit([])
		return
	var out := []
	for d in result.get("product_details", []):
		var pid := str(d.get("product_id", ""))
		_details[pid] = d
		out.append({"id": pid, "title": str(d.get("name", d.get("title", pid))), "price": _price_of(d), "available": true})
	products_received.emit(out)


func query_owned(_products: Array) -> void:
	_owned_inapp.clear()
	_owned_subs.clear()
	_owned_ok = [true, true]
	_owned_waiting = 2
	client.query_purchases(BillingClient.ProductType.INAPP)
	client.query_purchases(BillingClient.ProductType.SUBS)


func _on_purchases(result: Dictionary) -> void:
	# responses arrive for INAPP and SUBS separately; merge them into one snapshot
	var ok := int(result.get("response_code", -1)) == BillingClient.BillingResponseCode.OK
	var idx := 2 - _owned_waiting
	if idx >= 0 and idx < 2:
		_owned_ok[idx] = ok
	for p in result.get("purchases", []):
		if int(p.get("purchase_state", 1)) != BillingClient.PurchaseState.PURCHASED:
			continue
		_acknowledge(p)
		for pid in p.get("product_ids", []):
			_owned_inapp.append(str(pid))
	_owned_waiting -= 1
	if _owned_waiting <= 0:
		owned_received.emit(_owned_ok[0] and _owned_ok[1], _owned_inapp + _owned_subs)


func _acknowledge(p: Dictionary) -> void:
	if not bool(p.get("is_acknowledged", true)):
		client.acknowledge_purchase(str(p.get("purchase_token", "")))


func purchase(product: Dictionary) -> void:
	var pid := str(product.id)
	var res: Dictionary
	if product.type == "subs":
		var base_plan := ""
		var d: Dictionary = _details.get(pid, {})
		for s in d.get("subscription_offer_details", []):
			if s.get("offer_id") == null or str(s.get("offer_id", "")).is_empty():
				base_plan = str(s.get("base_plan_id", ""))
				break
		if base_plan.is_empty():
			purchase_result.emit(pid, "failed", "subscription base plan not found")
			return
		res = client.purchase_subscription(pid, base_plan)
	else:
		res = client.purchase(pid)
	var code := int(res.get("response_code", BillingClient.BillingResponseCode.ERROR))
	if code == BillingClient.BillingResponseCode.ITEM_ALREADY_OWNED:
		purchase_result.emit(pid, "already_owned", "")
	elif code != BillingClient.BillingResponseCode.OK:
		purchase_result.emit(pid, "failed", str(res.get("debug_message", "")))


func _on_purchase_updated(result: Dictionary) -> void:
	var code := int(result.get("response_code", -1))
	if code == BillingClient.BillingResponseCode.USER_CANCELED:
		purchase_result.emit("", "canceled", "")
		return
	if code == BillingClient.BillingResponseCode.ITEM_ALREADY_OWNED:
		purchase_result.emit("", "already_owned", "")
		return
	if code != BillingClient.BillingResponseCode.OK:
		purchase_result.emit("", "failed", str(result.get("debug_message", "")))
		return
	for p in result.get("purchases", []):
		var state := int(p.get("purchase_state", 0))
		for pid in p.get("product_ids", []):
			if state == BillingClient.PurchaseState.PURCHASED:
				_acknowledge(p)
				purchase_result.emit(str(pid), "purchased", "")
			elif state == BillingClient.PurchaseState.PENDING:
				purchase_result.emit(str(pid), "pending", "")


func restore(products: Array) -> void:
	query_owned(products)
