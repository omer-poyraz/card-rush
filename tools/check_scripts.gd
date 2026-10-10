extends Node
## Compiles every GDScript under scripts/, tests/ and tools/ and reports failures.
##   godot --headless --path . res://tools/check_scripts.tscn

func _ready() -> void:
	var bad := 0
	var n := 0
	for root in ["res://scripts", "res://tests", "res://tools"]:
		for path in _walk(root):
			if not path.ends_with(".gd"):
				continue
			n += 1
			var s := load(path) as GDScript
			if s == null or not s.can_instantiate():
				print("FAIL ", path)
				bad += 1
	print("checked %d scripts, %d failed" % [n, bad])
	get_tree().quit(1 if bad else 0)


func _walk(dir: String) -> Array:
	var out := []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for f in d.get_files():
		out.append(dir.path_join(f))
	for sub in d.get_directories():
		out.append_array(_walk(dir.path_join(sub)))
	return out
