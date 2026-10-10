class_name Palette
extends RefCounted
## Card Rush visual identity: deep navy / night purple with controlled neon accents.

const BG_DEEP := Color("0a0b1c")
const BG_NIGHT := Color("13143a")
const BG_PURPLE := Color("2a1554")
const PANEL := Color(0.09, 0.09, 0.22, 0.92)
const PANEL_LIGHT := Color(0.16, 0.16, 0.36, 0.95)
const PANEL_EDGE := Color(0.45, 0.5, 1.0, 0.35)

const ELECTRIC := Color("2fa8ff")
const CORAL := Color("ff5a5f")
const SUN := Color("ffd23f")
const TEAL := Color("19d3c5")
const VIOLET := Color("9b6bff")

const TEXT := Color("eef1ff")
const TEXT_DIM := Color("9aa3c7")
const TEXT_MUTED := Color("5f6791")
const SUCCESS := Color("3ee08f")
const DANGER := Color("ff4d6d")

## Card colours (index = CardDefinition.CardColor). Tuned for contrast on navy.
const CARD := [Color("e8384f"), Color("f5bd1f"), Color("21b36a"), Color("2d74ff"), Color("1b1b3a")]
## High-contrast alternative used in colour-blind mode (Okabe–Ito inspired).
const CARD_CB := [Color("d55e00"), Color("f0e442"), Color("009e73"), Color("0072b2"), Color("1b1b3a")]


static func card_color(c: int) -> Color:
	var pal: Array = CARD_CB if _colorblind() else CARD
	return pal[clampi(c, 0, 4)]


static func _colorblind() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or not tree.root.has_node("Settings"):
		return false
	return bool(tree.root.get_node("Settings").get_value("colorblind"))
