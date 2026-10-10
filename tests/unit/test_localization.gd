extends TestCase
## Every translation key referenced in code exists in both languages.


func _csv_keys() -> Dictionary:
	var out := {}
	var f := FileAccess.open("res://data/localization/strings.csv", FileAccess.READ)
	f.get_csv_line()
	while not f.eof_reached():
		var row := f.get_csv_line()
		if row.size() >= 3 and row[0] != "":
			out[row[0]] = [row[1], row[2]]
	return out


func _walk(dir: String, out: Array) -> void:
	var d := DirAccess.open(dir)
	for f in d.get_files():
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for sub in d.get_directories():
		_walk(dir.path_join(sub), out)


func test_all_keys_translated() -> void:
	var keys := _csv_keys()
	check(keys.size() > 150, "csv parsed")
	var files := []
	_walk("res://scripts", files)
	var re := RegEx.new()
	re.compile('(?:tr|Loc\\.t|translate|_t|error_text)\\("([A-Z][A-Z0-9_]+)"')
	var missing := {}
	for path in files:
		var src := FileAccess.get_file_as_string(path)
		for m in re.search_all(src):
			var k := m.get_string(1)
			if k.ends_with("_"):
				continue  # dynamic prefix, covered by test_house_rule_labels_exist
			if not keys.has(k):
				missing[k] = path.get_file()
	eq(missing, {}, "missing keys")


func test_engine_errors_have_text() -> void:
	var keys := _csv_keys()
	var src := FileAccess.get_file_as_string("res://scripts/rules/rule_engine.gd") + FileAccess.get_file_as_string("res://scripts/rules/rule_profile.gd")
	var re := RegEx.new()
	re.compile('"(ERR_[A-Z_]+)"')
	for m in re.search_all(src):
		check(keys.has(m.get_string(1)), "no text for " + m.get_string(1))


func test_both_languages_filled_and_placeholders_match() -> void:
	var keys := _csv_keys()
	for k in keys:
		var tr_s: String = keys[k][0]
		var en_s: String = keys[k][1]
		check(tr_s != "" and en_s != "", "empty translation " + k)
		check(tr_s.count("%d") == en_s.count("%d") and tr_s.count("%s") == en_s.count("%s"), "placeholder mismatch " + k)


func test_house_rule_labels_exist() -> void:
	var keys := _csv_keys()
	for k in RuleProfile.HOUSE_RULE_KEYS:
		check(keys.has("HOUSE_" + k.to_upper()), "label for " + k)
