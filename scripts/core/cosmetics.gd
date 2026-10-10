class_name Cosmetics
extends RefCounted
## Cosmetic catalog (data/cosmetics/catalog.json). Purely visual: nothing here
## changes the rules or gives an advantage. Unlock sources: default, coins,
## level, premium, store pack. A "premium" item listing a pack is also
## unlocked by owning that pack.

const TYPES := ["back", "table", "frame"]
const DEFAULTS := {"back": "back_classic", "table": "table_night", "frame": "frame_none"}

## Table themes: felt colours + rim accent.
const TABLES := {
	"table_night": {"felt": Color("18144a"), "felt2": Color("2a2378"), "rim": Color("2fa8ff")},
	"table_ocean": {"felt": Color("0b2a4a"), "felt2": Color("135c7a"), "rim": Color("19d3c5")},
	"table_ember": {"felt": Color("3a1220"), "felt2": Color("6e1f2c"), "rim": Color("ff8a3d")},
	"table_forest": {"felt": Color("0f2e22"), "felt2": Color("1d5a3c"), "rim": Color("3ee08f")},
	"table_royal": {"felt": Color("2a1450"), "felt2": Color("4b2290"), "rim": Color("ffd23f")},
}
const FRAMES := {
	"frame_none": Color.TRANSPARENT,
	"frame_ruby": Color("ff4d6d"),
	"frame_teal": Color("19d3c5"),
	"frame_gold": Color("ffd23f"),
	"frame_neon": Color("ff3df2"),
}

static var _items: Array = []


static func items() -> Array:
	if _items.is_empty():
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/cosmetics/catalog.json"))
		_items = d.get("items", []) if d is Dictionary else []
	return _items


static func item(id: String) -> Dictionary:
	for it in items():
		if it["id"] == id:
			return it
	return {}


static func of_type(t: String) -> Array:
	return items().filter(func(it): return it["type"] == t)


static func is_owned(id: String) -> bool:
	var it := item(id)
	if it.is_empty():
		return false
	match str(it.get("unlock", "")):
		"default":
			return true
		"coins":
			return Save.section("cosmetics").get("owned", []).has(id)
		"level":
			return Progression.level_info(int(Save.section("profile").get("xp", 0)))["level"] >= int(it.get("level", 999))
		"premium":
			return Store.is_premium() or (it.has("pack") and Store.owns(str(it["pack"])))
		"pack":
			return Store.owns(str(it.get("pack", "")))
	return false


## Buys a coin item. Returns "" or an error key.
static func buy(id: String) -> String:
	var it := item(id)
	if it.is_empty() or str(it.get("unlock", "")) != "coins":
		return "ERR_COSMETIC_NOT_BUYABLE"
	if is_owned(id):
		return "ERR_COSMETIC_OWNED"
	if not Economy.spend(int(it.get("price", 0)), "cosmetic:" + id):
		return "ERR_NOT_ENOUGH_COINS"
	var c := Save.section("cosmetics")
	var owned: Array = c.get("owned", [])
	owned.append(id)
	c["owned"] = owned
	Save.mark_dirty()
	return ""


static func equipped(t: String) -> String:
	var id := str(Save.section("cosmetics").get("equipped", {}).get(t, DEFAULTS.get(t, "")))
	# fall back if it is no longer owned (e.g. refunded pack, expired premium)
	return id if is_owned(id) else str(DEFAULTS.get(t, ""))


static func equip(id: String) -> bool:
	var it := item(id)
	if it.is_empty() or not is_owned(id):
		return false
	var c := Save.section("cosmetics")
	var eq: Dictionary = c.get("equipped", {})
	eq[it["type"]] = id
	c["equipped"] = eq
	Save.mark_dirty()
	return true


static func frame_color(id := "") -> Color:
	return FRAMES.get(id if id != "" else equipped("frame"), Color.TRANSPARENT)


static func table_theme(id := "") -> Dictionary:
	return TABLES.get(id if id != "" else equipped("table"), TABLES["table_night"])
