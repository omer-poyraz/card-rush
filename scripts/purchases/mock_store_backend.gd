extends StoreBackend
## TEST-ONLY store. Enabled exclusively in debug builds with --mock-store (or CARDRUSH_MOCK_STORE=1) and in tests.
## Prices are labelled "TEST" and nothing is charged. Used by automated tests
## to exercise pending / canceled / failed / restore flows.

var next_result := "purchased"   # tests set: purchased | pending | canceled | failed
var owned: Array = []
var offline := false


func kind() -> String:
	return "mock"


func is_available() -> bool:
	return not offline


func connect_store() -> void:
	connected_changed.emit(not offline)


func query_products(products: Array) -> void:
	if offline:
		products_received.emit([])
		return
	products_received.emit(products.map(func(p): return {"id": p.id, "title": "[TEST] " + p.id, "price": "TEST", "available": true}))


func query_owned(_products: Array) -> void:
	owned_received.emit(not offline, [] if offline else owned.duplicate())


func purchase(product: Dictionary) -> void:
	if offline:
		purchase_result.emit(product.id, "failed", "offline")
		return
	if owned.has(product.id):
		purchase_result.emit(product.id, "already_owned", "")
		return
	if next_result == "purchased":
		owned.append(product.id)
	purchase_result.emit(product.id, next_result, "mock")


## Tests: complete a previously pending purchase.
func complete_pending(pid: String) -> void:
	owned.append(pid)
	purchase_result.emit(pid, "purchased", "mock")
