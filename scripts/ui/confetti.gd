class_name Confetti
extends RefCounted
## One-shot CPU particle effects (Compatibility-renderer friendly). Each
## emitter frees itself when done, so nothing keeps running in the background.

static var _tex: Texture2D


static func _texture() -> Texture2D:
	if _tex == null:
		var img := Image.create(6, 10, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		_tex = ImageTexture.create_from_image(img)
	return _tex


static func _ramp() -> Gradient:
	var g := Gradient.new()
	var cols := [Palette.CORAL, Palette.SUN, Palette.TEAL, Palette.ELECTRIC, Palette.VIOLET, Color.WHITE]
	g.offsets = PackedFloat32Array([0.0, 0.2, 0.4, 0.6, 0.8, 1.0])
	g.colors = PackedColorArray(cols)
	g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	return g


static func _base(amount: int, lifetime: float) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.amount = amount
	p.lifetime = lifetime
	p.one_shot = true
	p.explosiveness = 0.9
	p.texture = _texture()
	p.color_initial_ramp = _ramp()
	p.angular_velocity_min = -540
	p.angular_velocity_max = 540
	p.angle_min = 0
	p.angle_max = 360
	p.scale_amount_min = 0.8
	p.scale_amount_max = 1.6
	p.gravity = Vector2(0, 520)
	p.finished.connect(p.queue_free)
	return p


static func burst(parent: Node, pos: Vector2, amount := 40, lifetime := 1.0) -> CPUParticles2D:
	var p := _base(amount, lifetime)
	p.direction = Vector2(0, -1)
	p.spread = 70
	p.initial_velocity_min = 220
	p.initial_velocity_max = 420
	parent.add_child(p)
	p.global_position = pos
	p.emitting = true
	return p


static func rain(parent: Node, area: Vector2, amount := 100) -> CPUParticles2D:
	var p := _base(amount, 3.2)
	p.explosiveness = 0.15
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(area.x / 2.0, 10)
	p.direction = Vector2(0, 1)
	p.spread = 25
	p.initial_velocity_min = 60
	p.initial_velocity_max = 160
	p.gravity = Vector2(0, 160)
	p.z_index = 50
	parent.add_child(p)
	p.position = Vector2(area.x / 2.0, -20)
	p.emitting = true
	return p
