class_name MenuBackdrop
extends Control

## What the menus stand on: dusk over the Caucasus.
##
## A sky going from deep blue at the top to the embers of a sunset at the
## horizon, the moon rising, three ranges of mountains one behind the other —
## the far ones pale with haze, the near ones black — drifting at their own
## pace, sparks rising off an unseen fire, and the edges of the screen sunk
## into shadow. All drawn: nothing to load, nothing to go out of date.
##
## Under the menu it is dimmed on the left, where the buttons are.

var _t: float = 0.0
var _ranges: Array[PackedVector2Array] = []
var _sparks: GPUParticles2D

const SKY_TOP := Color("0b1020")
const SKY_MID := Color("1c1a33")
const HORIZON := Color("6e2a22")
const GLOW := Color("d98a3a")


func _ready() -> void:
	# Offsets too: anchors alone, set once already in the tree, leave it 0 × 0.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rng := RandomNumberGenerator.new()
	rng.seed = 1934
	for layer in 3:
		var pts := PackedVector2Array()
		var x := 0.0
		var base := 0.62 + 0.09 * layer
		var h := 0.22 - 0.05 * layer
		while x <= 2.05:
			pts.append(Vector2(x, base - h * (0.35 + 0.65 * absf(sin(x * (3.1 + layer) + layer)))
					- rng.randf_range(0.0, h * 0.35)))
			x += rng.randf_range(0.03, 0.09)
		_ranges.append(pts)
	_sparks = GPUParticles2D.new()
	_sparks.amount = 70
	_sparks.lifetime = 7.0
	_sparks.preprocess = 7.0
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	m.emission_box_extents = Vector3(900, 10, 0)
	m.direction = Vector3(0.15, -1, 0)
	m.spread = 18.0
	m.initial_velocity_min = 25.0
	m.initial_velocity_max = 70.0
	m.gravity = Vector3(8, -6, 0)
	m.scale_min = 1.0
	m.scale_max = 2.6
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.75, 0.35, 0.0))
	ramp.add_point(0.1, Color(1.0, 0.7, 0.3, 0.9))
	ramp.set_color(ramp.get_point_count() - 1, Color(1.0, 0.35, 0.1, 0.0))
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	m.color_ramp = ramp_tex
	_sparks.process_material = m
	var dot := GradientTexture2D.new()
	dot.fill = GradientTexture2D.FILL_RADIAL
	dot.fill_from = Vector2(0.5, 0.5)
	dot.fill_to = Vector2(1.0, 0.5)
	var fall := Gradient.new()
	fall.set_color(0, Color(1, 1, 1, 1))
	fall.set_color(1, Color(1, 1, 1, 0))
	dot.gradient = fall
	dot.width = 16
	dot.height = 16
	_sparks.texture = dot
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_sparks.material = add
	add_child(_sparks)
	resized.connect(_place_sparks)
	_place_sparks()


func _place_sparks() -> void:
	if _sparks != null:
		_sparks.position = Vector2(size.x * 0.5, size.y + 20.0)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	if w <= 0.0 or h <= 0.0:
		return
	# The sky, top to horizon, in bands.
	var steps := 48
	for i in steps:
		var a := float(i) / steps
		var c := SKY_TOP.lerp(SKY_MID, smoothstep(0.0, 0.55, a)).lerp(HORIZON, smoothstep(0.45, 0.8, a))
		draw_rect(Rect2(0, h * a * 0.8, w, h * 0.8 / steps + 1.0), c)
	# The glow on the horizon, behind the mountains.
	var sun := Vector2(w * 0.68, h * 0.62)
	for r in range(10, 0, -1):
		draw_circle(sun, h * 0.06 * r, Color(GLOW, 0.035))
	# Stars, in the top of the sky.
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for i in 90:
		var p := Vector2(rng.randf() * w, rng.randf() * h * 0.42)
		var tw := 0.5 + 0.5 * sin(_t * rng.randf_range(0.8, 2.2) + i)
		draw_circle(p, rng.randf_range(0.6, 1.5), Color(1, 1, 1, 0.2 + 0.5 * tw * (1.0 - p.y / (h * 0.42))))
	# The moon.
	var moon := Vector2(w * 0.8, h * 0.2)
	draw_circle(moon, 44.0, Color(1.0, 0.95, 0.85, 0.08))
	draw_circle(moon, 30.0, Color(1.0, 0.96, 0.88, 0.92))
	draw_circle(moon + Vector2(11, -6), 27.0, SKY_TOP.lerp(SKY_MID, 0.25))
	# Three ranges, far to near, each drifting a little.
	var tints := [Color("3b3450"), Color("221d31"), Color("0d0b14")]
	for layer in _ranges.size():
		var drift := fmod(_t * (4.0 + 5.0 * layer), w)
		var poly := PackedVector2Array()
		for p in _ranges[layer]:
			poly.append(Vector2(p.x * w - drift * 0.6, p.y * h))
		poly.append(Vector2(poly[poly.size() - 1].x, h))
		poly.append(Vector2(poly[0].x, h))
		draw_colored_polygon(poly, tints[layer])
		# Haze sitting in front of each range.
		draw_rect(Rect2(0, h * (0.66 + 0.09 * layer), w, h * 0.04), Color(GLOW, 0.05 - 0.015 * layer))
	# Darkness round the edges, and heaviest down the left, where the menu is.
	for i in 12:
		var a := float(i) / 12.0
		draw_rect(Rect2(0, 0, w * 0.45 * (1.0 - a), h), Color(0, 0, 0, 0.05))
	for i in 8:
		var inset := 8.0 * i
		draw_rect(Rect2(inset, inset, w - inset * 2.0, h - inset * 2.0), Color(0, 0, 0, 0.05), false, 16.0)
