extends Node
## Renders the app icon set from the procedural brand art.
##   godot --path . --resolution 1024x1024 res://tools/make_icons.tscn
## Writes assets/branding/: icon_1024.png, adaptive_fg_432.png,
## adaptive_bg_432.png, adaptive_mono_432.png, icon_192.png.

func _ready() -> void:
	get_tree().current_scene = null
	await _render(1024, "full", "res://assets/branding/icon_1024.png")
	await _render(432, "fg", "res://assets/branding/adaptive_fg_432.png")
	await _render(432, "bg", "res://assets/branding/adaptive_bg_432.png")
	await _render(432, "mono", "res://assets/branding/adaptive_mono_432.png")
	var img := Image.load_from_file(ProjectSettings.globalize_path("res://assets/branding/icon_1024.png"))
	img.resize(192, 192, Image.INTERPOLATE_LANCZOS)
	img.save_png(ProjectSettings.globalize_path("res://assets/branding/icon_192.png"))
	img.resize(256, 256, Image.INTERPOLATE_LANCZOS)
	print("icons written")
	get_tree().quit()


func _render(px: int, mode: String, path: String) -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(px, px)
	vp.transparent_bg = mode != "full" and mode != "bg"
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var art := IconArt.new()
	art.mode = mode
	art.size = Vector2(px, px)
	vp.add_child(art)
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	vp.queue_free()


class IconArt:
	extends Control
	var mode := "full"

	func _draw() -> void:
		var s := size.x
		var c := size / 2.0
		if mode == "full" or mode == "bg":
			var r := Rect2(Vector2.ZERO, size)
			var pts := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
			var cols := PackedColorArray()
			for p in pts:
				cols.append(Color("2a1554").lerp(Color("0a0b1c"), p.y / s))
			draw_polygon(pts, cols)
			for i in 6:
				draw_circle(c + Vector2(-s * 0.25, -s * 0.25), s * (0.55 - i * 0.07), Color(Palette.ELECTRIC, 0.035))
			if mode == "bg":
				return
		# three fanned cards (adaptive fg keeps the art inside the 66% safe zone)
		var k := 0.62 if mode == "full" else 0.5
		var cw := s * 0.3 * k / 0.62
		var ch := cw * 1.5
		var cols3 := [Palette.CORAL, Palette.SUN, Palette.ELECTRIC]
		for i in 3:
			draw_set_transform(c + Vector2(0, s * 0.06), (i - 1) * 0.38, Vector2.ONE)
			var rr := Rect2(Vector2(-cw / 2.0, -ch * 0.62), Vector2(cw, ch))
			var white := Color.WHITE if mode != "mono" else Color.WHITE
			draw_colored_polygon(CardArt.rounded_rect_points(rr, cw * 0.14), white)
			if mode != "mono":
				draw_colored_polygon(CardArt.rounded_rect_points(rr.grow(-cw * 0.07), cw * 0.1), cols3[i])
				draw_circle(Vector2(0, -ch * 0.12), cw * 0.3, Color("f8f9ff"))
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
		# lightning "rush" mark on the front card
		var z := s * 0.1 * k / 0.62
		var o := c + Vector2(0, -s * 0.0)
		var bolt := PackedVector2Array([o + Vector2(0.15, -1.1) * z, o + Vector2(-0.55, 0.1) * z, o + Vector2(-0.05, 0.1) * z,
			o + Vector2(-0.25, 1.1) * z, o + Vector2(0.55, -0.15) * z, o + Vector2(0.05, -0.15) * z])
		draw_colored_polygon(bolt, Color("2a1554") if mode != "mono" else Color(0, 0, 0, 0))
