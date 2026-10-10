extends Node
## Autoload "Loc". Turkish and English via Godot's TranslationServer (CSV in
## data/localization). First run follows the device language.

signal locale_changed

const SUPPORTED := ["tr", "en"]


func _ready() -> void:
	var lang: String = Settings.get_value("language")
	if lang == "" or not SUPPORTED.has(lang):
		lang = "tr" if OS.get_locale_language() == "tr" else "en"
		Settings.set_value("language", lang)
	TranslationServer.set_locale(lang)


func set_language(lang: String) -> void:
	if not SUPPORTED.has(lang):
		return
	Settings.set_value("language", lang)
	TranslationServer.set_locale(lang)
	locale_changed.emit()


func language() -> String:
	return TranslationServer.get_locale().substr(0, 2)


## tr() with %-format arguments.
func t(key: String, args: Array = []) -> String:
	var s := tr(key)
	return s % args if not args.is_empty() else s


func color_name(c: int) -> String:
	return tr(["COLOR_RED", "COLOR_YELLOW", "COLOR_GREEN", "COLOR_BLUE", "COLOR_WILD"][clampi(c, 0, 4)])


## Human readable error message for an engine/network error key.
func error_text(key: String) -> String:
	var s := tr(key)
	return s if s != key else tr("ERR_GENERIC")
