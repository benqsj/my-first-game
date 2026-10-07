class_name FrostNova
extends Node3D

## What the elf's Frost Nova looks like ([ElfSkills]): from where her staff
## strikes the ground, frost runs out over it in a disc to `radius` in `run`
## seconds, with rings of ice crystals bursting up out of it as it passes
## (one ring near her, one half way, one at the edge), a ring of white light
## and a low wave of snow and cold mist thrown out along the ground. After a
## moment the crystals sink and the frost fades.

const ICE := Color(0.62, 0.9, 1.0)
const ICE_HOT := Color(0.9, 0.98, 1.0)
## How long it all lasts before it has melted away.
const LASTS := 2.2
const FADE := 0.8

var _radius: float = 4.5
var _run: float = 0.28
var _age: float = 0.0
var _decal: Decal
var _crystals: Array[Node3D] = []
var _sizes: Array[float] = []

static var _frost_tex: Texture2D = null


## Every peer: the nova at `at`.
static func burst(into: Node, at: Vector3, radius: float, run: float) -> FrostNova:
	var n := FrostNova.new()
	n._radius = radius
	n._run = run
	into.add_child(n)
	n.global_position = at
	n._build()
	return n


func _build() -> void:
	var center := global_position + Vector3.UP * 0.15
	var into := get_parent()
	SkillFx.flash(into, center + Vector3.UP * 0.4, ICE_HOT, 0.9, 0.2, 3.0)
	SkillFx.light(into, center + Vector3.UP * 0.8, ICE, 4.0, _radius * 2.2, 0.6)
	SkillFx.ring(into, center, Vector3.UP, ICE_HOT, 0.3, _radius, _run * 1.4, 0.07, 3.0)
	SkillFx.ring(into, center + Vector3.UP * 0.05, Vector3.UP, ICE, 0.2, _radius * 0.75, _run * 1.8, 0.04, 2.0)
	# snow thrown out low along the ground, and cold mist rolling out after it
	for k in 2:
		var p := SkillFx.particles(into, center, {"amount": 70 if k == 0 else 26, "life": 0.7 if k == 0 else 1.4,
				"one_shot": true, "explosiveness": 1.0,
				"speed": Vector2(_radius / _run * 0.55, _radius / _run * 0.8) if k == 0 else Vector2(3.0, 6.0),
				"dir": Vector3.UP, "spread": 88.0, "gravity": Vector3(0, -2.0, 0), "damping": 6.0 if k == 0 else 4.0,
				"size": Vector2(0.03, 0.07) if k == 0 else Vector2(0.6, 1.1), "box": Vector3(0.3, 0.05, 0.3),
				"add": k == 0, "grow": 0.2 if k == 0 else 0.8,
				"colors": [Color(ICE_HOT, 1.0), Color(ICE, 0.0)] if k == 0 else
						[Color(0.92, 0.97, 1.0, 0.0), Color(0.9, 0.96, 1.0, 0.32), Color(0.9, 0.95, 1.0, 0.0)]})
		if p != null:
			# flattened: out along the ground, not up
			p.scale = Vector3(1.0, 0.25, 1.0)
	_decal = Decal.new()
	_decal.size = Vector3(_radius * 2.3, 1.2, _radius * 2.3)
	_decal.texture_albedo = _frost_texture()
	_decal.modulate = Color(0.85, 0.95, 1.0, 0.0)
	_decal.upper_fade = 0.5
	_decal.lower_fade = 0.3
	add_child(_decal)
	_decal.position = Vector3.UP * 0.2
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	_decal.rotation.y = rng.randf() * TAU
	for ring in 3:
		var r: float = _radius * (0.38 if ring == 0 else (0.7 if ring == 1 else 0.97))
		var count := int(r * 4.2) + 4
		for i in count:
			var a := TAU * (float(i) + rng.randf_range(-0.3, 0.3)) / float(count)
			var rr: float = r * rng.randf_range(0.88, 1.06)
			var out := Vector3(cos(a), 0.0, sin(a))
			var tall := rng.randf_range(0.35, 0.8) * (1.2 - 0.25 * ring)
			var c := IceShard.spike(tall, tall * 0.2, 1.2)
			add_child(c)
			var spot: Vector3 = global_position + out * rr
			spot.y = _ground_y(spot)
			c.global_position = spot
			c.basis = Basis(out.cross(Vector3.UP).normalized(), -rng.randf_range(0.25, 0.7)) \
					* Basis(Vector3.UP, rng.randf() * TAU)
			c.scale = Vector3.ONE * 0.01
			c.visible = false
			c.set_meta(&"at", rr / _radius * _run)
			_crystals.append(c)
			_sizes.append(rng.randf_range(0.8, 1.2))


func _ground_y(at: Vector3) -> float:
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 1.5, at + Vector3.DOWN * 2.5, 1)
	var hit := space.intersect_ray(q)
	return float((hit["position"] as Vector3).y) if not hit.is_empty() else at.y


func _process(delta: float) -> void:
	_age += delta
	var melt := clampf((_age - (LASTS - FADE)) / FADE, 0.0, 1.0)
	_decal.modulate.a = clampf(_age / _run, 0.0, 1.0) * (1.0 - melt) * 0.95
	for i in _crystals.size():
		var c := _crystals[i]
		var since := _age - float(c.get_meta(&"at"))
		if since < 0.0:
			continue
		c.visible = true
		var grow := clampf(since / 0.1, 0.0, 1.0)
		var k := grow * (1.0 + 0.3 * sin(clampf(since / 0.22, 0.0, 1.0) * PI))
		c.scale = Vector3.ONE * maxf(_sizes[i] * k * (1.0 - melt), 0.001)
	if _age > LASTS + 0.2:
		queue_free()


## The frost, a disc: ragged at its edge, with cracks running out from the middle.
static func _frost_texture() -> Texture2D:
	if _frost_tex != null:
		return _frost_tex
	var n := FastNoiseLite.new()
	n.frequency = 0.05
	n.fractal_octaves = 3
	var size := 192
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := (size - 1) * 0.5
	for y in size:
		for x in size:
			var dx := (x - c) / c
			var dy := (y - c) / c
			var r := sqrt(dx * dx + dy * dy)
			var ang := atan2(dy, dx)
			var ragged := n.get_noise_2d(cos(ang) * 60.0, sin(ang) * 60.0) * 0.18
			var edge := 1.0 - smoothstep(0.78 + ragged, 0.95 + ragged, r)
			var patch := n.get_noise_2d(x * 2.0, y * 2.0) * 0.5 + 0.5
			# cracks: thin spokes out from the middle, wandering a little
			var spokes := absf(sin(ang * 9.0 + n.get_noise_2d(r * 40.0, ang * 10.0) * 2.5))
			var crack := (1.0 - smoothstep(0.0, 0.08, spokes)) * smoothstep(0.1, 0.3, r)
			var a := edge * (0.3 + 0.45 * patch) + crack * edge * 0.45
			var col := Color(0.7, 0.86, 1.0).lerp(Color(0.95, 0.98, 1.0), patch).lerp(Color.WHITE, crack)
			img.set_pixel(x, y, Color(col.r, col.g, col.b, clampf(a, 0.0, 1.0)))
	img.generate_mipmaps()
	_frost_tex = ImageTexture.create_from_image(img)
	return _frost_tex
