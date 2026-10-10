extends Node
## Card Rush automated test suite:
##   godot --headless --path . res://tests/run_tests.tscn [-- --only <substring>]
## Runs every `test_*` method of every script in tests/unit and tests/integration,
## writes tests/reports/test_report.md and exits non-zero on any failure.

const DIRS := ["res://tests/unit", "res://tests/integration"]

var results: Array = []  # [file, name, ok, detail, ms]


func _ready() -> void:
	var only := ""
	var args := OS.get_cmdline_user_args()
	var i := args.find("--only")
	if i >= 0 and i + 1 < args.size():
		only = args[i + 1]
	# never touch the player's real save
	var saved_data := Save.data.duplicate(true)
	Save.path = "user://test_save.json"
	Save.backup_path = "user://test_save.bak.json"
	Save.data = Save.defaults()
	App.capture_mode = true
	for dir in DIRS:
		for f in _list(dir):
			await _run_file(f, only)
	Save._dirty = false
	Save.data = saved_data
	Save.path = Save.PATH
	Save.backup_path = Save.BACKUP
	_report()
	var failed := results.filter(func(r): return not r[2]).size()
	print("\n%d tests, %d failed" % [results.size(), failed])
	get_tree().quit(1 if failed > 0 else 0)


func _list(dir: String) -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for f in d.get_files():
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	out.sort()
	return out


func _run_file(path: String, only: String) -> void:
	var script := load(path) as GDScript
	if script == null:
		results.append([path, "<load>", false, "script failed to load", 0])
		return
	var names: Array[String] = []
	for m in script.get_script_method_list():
		var n: String = m["name"]
		if n.begins_with("test_") and not names.has(n):
			names.append(n)
	for n in names:
		var full := path.get_file().get_basename() + "." + n
		if only != "" and not full.contains(only):
			continue
		var tc: TestCase = script.new()
		tc.runner = self
		if tc.has_method("before_each"):
			await tc.call("before_each")
		var t0 := Time.get_ticks_msec()
		await tc.call(n)
		if tc.has_method("after_each"):
			await tc.call("after_each")
		var ms := Time.get_ticks_msec() - t0
		var passed := tc.failures.is_empty()
		var detail := "; ".join(tc.failures.slice(0, 5))
		results.append([path.get_file(), n, passed, detail, ms])
		print(("PASS " if passed else "FAIL ") + full + ("" if passed else "  -> " + detail))


func _report() -> void:
	var failed := results.filter(func(r): return not r[2])
	var lines := [
		"# Card Rush — Test Report",
		"",
		"- Date: %s" % Time.get_datetime_string_from_system(),
		"- Godot: %s" % Engine.get_version_info()["string"],
		"- Total: %d, passed: %d, failed: %d" % [results.size(), results.size() - failed.size(), failed.size()],
		"",
		"| File | Test | Result | ms | Detail |",
		"|---|---|---|---|---|",
	]
	for r in results:
		lines.append("| %s | %s | %s | %d | %s |" % [r[0], r[1], "PASS" if r[2] else "**FAIL**", r[4], str(r[3]).replace("|", "/")])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/reports"))
	var f := FileAccess.open("res://tests/reports/test_report.md", FileAccess.WRITE)
	if f:
		f.store_string("\n".join(lines) + "\n")
