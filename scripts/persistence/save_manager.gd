extends Node
## Autoload "Save". Versioned JSON save with atomic writes, a rolling backup
## and corruption recovery. Only local, non-authoritative data lives here —
## purchase entitlements are re-verified with the store (see PurchaseManager).

signal saved

const PATH := "user://save.json"
const BACKUP := "user://save.bak.json"
const SCHEMA := 1

var path := PATH
var backup_path := BACKUP
var data := {}
var recovered_from := ""   # "", "backup" or "defaults" (shown once in the UI)
var _dirty := false
var _save_timer := 0.0


func _ready() -> void:
	load_data()


static func defaults() -> Dictionary:
	return {
		"schema": SCHEMA,
		"profile": {"name": "", "avatar": 0, "xp": 0, "coins": 0, "created": int(Time.get_unix_time_from_system())},
		"stats": {
			"played": 0, "won": 0, "streak": 0, "best_streak": 0, "cards_played": 0,
			"uno_calls": 0, "catches": 0, "by_level": {"0": [0, 0], "1": [0, 0], "2": [0, 0]},
			"online_played": 0, "online_won": 0, "history": [],
		},
		"settings": {},
		"cosmetics": {"owned": [], "equipped": {}},
		"missions": {},
		"social": {"blocked": [], "recent": [], "muted": []},
		"bot_setup": {},
		"room_setup": {},
		"ads": {},
		"store": {},
		"flags": {},
	}


func load_data() -> void:
	recovered_from = ""
	var d := _read(path)
	if d.is_empty() and FileAccess.file_exists(path):
		# primary corrupted: keep a copy for diagnostics, try the backup
		DirAccess.copy_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(path + ".corrupt"))
		d = _read(backup_path)
		recovered_from = "backup" if not d.is_empty() else "defaults"
	data = _migrate(d) if not d.is_empty() else defaults()
	if recovered_from != "":
		push_warning("Save recovered from " + recovered_from)
		save_now()


func _read(p: String) -> Dictionary:
	if not FileAccess.file_exists(p):
		return {}
	var f := FileAccess.open(p, FileAccess.READ)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if not parsed is Dictionary or not parsed.has("schema"):
		return {}
	return parsed


## Fills missing keys from defaults and upgrades older schemas.
func _migrate(d: Dictionary) -> Dictionary:
	var base := defaults()
	_merge_missing(d, base)
	d["schema"] = SCHEMA
	return d


func _merge_missing(target: Dictionary, base: Dictionary) -> void:
	for k in base:
		if not target.has(k) or typeof(target[k]) != typeof(base[k]):
			target[k] = base[k]
		elif base[k] is Dictionary and not (base[k] as Dictionary).is_empty():
			_merge_missing(target[k], base[k])


func mark_dirty() -> void:
	_dirty = true
	_save_timer = 0.5


func _process(dt: float) -> void:
	if _dirty:
		_save_timer -= dt
		if _save_timer <= 0.0:
			save_now()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		if _dirty:
			save_now()


## Atomic: write temp file, keep the previous good file as backup, then rename.
func save_now() -> void:
	_dirty = false
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("Save: cannot write " + tmp)
		return
	f.store_string(JSON.stringify(data))
	f.close()
	var abs_path := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(path):
		DirAccess.copy_absolute(abs_path, ProjectSettings.globalize_path(backup_path))
	DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), abs_path)
	saved.emit()


func section(name: String) -> Dictionary:
	if not data.has(name) or not data[name] is Dictionary:
		data[name] = {}
	return data[name]
