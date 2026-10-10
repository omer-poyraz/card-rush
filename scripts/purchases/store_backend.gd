class_name StoreBackend
extends RefCounted
## Interface for platform stores. PurchaseManager owns entitlements; a backend
## only reports what the platform says.
##
## Signals carry plain dictionaries:
##   products_received([{id, title, price, available}])
##   owned_received(ok: bool, owned_ids: Array)        # full ownership snapshot
##   purchase_result(id, state, message)               # state: purchased|pending|canceled|failed|already_owned

signal connected_changed(ok: bool)
signal products_received(products: Array)
signal owned_received(ok: bool, owned_ids: Array)
signal purchase_result(product_id: String, state: String, message: String)


func kind() -> String:
	return "unavailable"


func is_available() -> bool:
	return false


func connect_store() -> void:
	connected_changed.emit(false)


func query_products(_products: Array) -> void:
	products_received.emit([])


func query_owned(_products: Array) -> void:
	owned_received.emit(false, [])


func purchase(product: Dictionary) -> void:
	purchase_result.emit(str(product.get("id", "")), "failed", "store unavailable")


func restore(products: Array) -> void:
	query_owned(products)


func poll() -> void:
	pass
