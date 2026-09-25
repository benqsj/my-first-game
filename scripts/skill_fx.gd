class_name SkillFx
extends RefCounted

## The small pieces the heroes' skills are drawn with — glows, bursts, rings,
## flashes, a soft round sprite — so each skill's own script is only the
## choreography. Everything here frees itself.
##
## Glow here is meant: these are the skills, the one place in the fight where
## light is allowed to be a spell. Colours are kept below white so the tint
## survives the tonemapper.

## One soft round dot for every billboard particle, built once.
static var _dot: Texture2D = null
## A tongue of flame for fire particles: a round hot foot, a pointed top.
static var _flame: Texture2D = null


## A glowing, unshaded material. `add` blends it additively (sparks, motes);
## without it it covers what is behind (sigils, the venom on a blade).
static func glow(color: Color, energy: float = 2.0, add: bool = true, alpha: float = 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(color.r, color.g, color.b, alpha)
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if add:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.no_depth_test = false
	return m


## The soft dot: white in the middle, gone at the rim.
static func dot() -> Texture2D:
	if _dot == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.35, Color(1, 1, 1, 0.8))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(0.5, 0.0)
		t.width = 64
		t.height = 64
		_dot = t
	return _dot


## A flame: drawn once into an image, a round foot narrowing to a point.
static func flame() -> Texture2D:
	if _flame == null:
		var w := 64
		var h := 128
		var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
		for y in h:
			var t := 1.0 - float(y) / float(h - 1)            # 0 at the foot, 1 at the tip
			var half := 0.46 * pow(1.0 - t, 0.6) * minf(1.0, t * 4.0 + 0.35)
			for x in w:
				var u := absf(float(x) / float(w - 1) - 0.5)
				var edge := 1.0 - clampf((u - half * 0.6) / maxf(half * 0.4, 0.001), 0.0, 1.0)
				var a := edge * clampf(1.0 - t * t, 0.0, 1.0) * clampf(t * 8.0 + 0.2, 0.0, 1.0)
				img.set_pixel(x, y, Color(1, 1, 1, a))
		_flame = ImageTexture.create_from_image(img)
	return _flame


## A material for billboard particles drawn with `tex`, coloured by the
## particle's colour (the process material's ramp).
static func sprite_material(tex: Texture2D, add: bool = true) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if add:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = tex
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true
	return m


## A colour ramp for particles, a list of colours spread evenly over their life.
static func ramp(colors: Array[Color]) -> GradientTexture1D:
	var g := Gradient.new()
	g.remove_point(1)
	g.set_color(0, colors[0])
	for i in range(1, colors.size()):
		g.add_point(float(i) / float(colors.size() - 1), colors[i])
	var t := GradientTexture1D.new()
	t.gradient = g
	return t


## A size curve: grows to full in `grow` of its life and shrinks to nothing.
static func swell(grow: float = 0.15) -> CurveTexture:
	var c := Curve.new()
	c.add_point(Vector2(0.0, 0.0))
	c.add_point(Vector2(grow, 1.0))
	c.add_point(Vector2(1.0, 0.0))
	var t := CurveTexture.new()
	t.curve = c
	return t


## A particle system in `into` at `at`. `spec` keys (all optional):
## amount, life, one_shot, explosiveness, speed (Vector2 min/max), dir, spread,
## gravity (Vector3), damping, size (Vector2), colors (Array[Color]), tex,
## add (bool), sphere (emission radius), box (Vector3 extents), ring
## (Vector2 inner/outer radius, lying flat), orbit (radial accel, negative pulls
## in), local (bool: particles move with the node), free_after (seconds; 0
## keeps it).
static func particles(into: Node, at: Vector3, spec: Dictionary) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = int(spec.get("amount", 24))
	p.lifetime = float(spec.get("life", 0.8))
	p.one_shot = bool(spec.get("one_shot", false))
	p.explosiveness = float(spec.get("explosiveness", 0.0))
	p.local_coords = bool(spec.get("local", false))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm := ParticleProcessMaterial.new()
	var sp: Vector2 = spec.get("speed", Vector2(0.5, 1.5))
	pm.initial_velocity_min = sp.x
	pm.initial_velocity_max = sp.y
	pm.direction = spec.get("dir", Vector3.UP)
	pm.spread = float(spec.get("spread", 30.0))
	pm.gravity = spec.get("gravity", Vector3.ZERO)
	pm.damping_min = float(spec.get("damping", 0.0))
	pm.damping_max = float(spec.get("damping", 0.0))
	var sz: Vector2 = spec.get("size", Vector2(0.04, 0.08))
	pm.scale_min = sz.x
	pm.scale_max = sz.y
	pm.scale_curve = swell(float(spec.get("grow", 0.15)))
	var colors: Array[Color] = []
	colors.assign(spec.get("colors", [Color(1, 1, 1, 1), Color(1, 1, 1, 0)]))
	pm.color_ramp = ramp(colors)
	if spec.has("sphere"):
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		pm.emission_sphere_radius = float(spec["sphere"])
	elif spec.has("box"):
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		pm.emission_box_extents = spec["box"]
	elif spec.has("ring"):
		var r: Vector2 = spec["ring"]
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
		pm.emission_ring_axis = Vector3.UP
		pm.emission_ring_inner_radius = r.x
		pm.emission_ring_radius = r.y
		pm.emission_ring_height = 0.05
	if spec.has("orbit"):
		pm.radial_accel_min = float(spec["orbit"])
		pm.radial_accel_max = float(spec["orbit"])
	if spec.has("tangent"):
		pm.tangential_accel_min = float(spec["tangent"])
		pm.tangential_accel_max = float(spec["tangent"])
	if spec.has("spin"):
		pm.angle_min = -180.0
		pm.angle_max = 180.0
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = spec.get("quad", Vector2(1.0, 1.0))
	quad.material = sprite_material(spec.get("tex", dot()) as Texture2D, bool(spec.get("add", true)))
	p.draw_pass_1 = quad
	into.add_child(p)
	p.global_position = at
	p.emitting = true
	var free_after := float(spec.get("free_after", (p.lifetime + 0.2) if p.one_shot else 0.0))
	if free_after > 0.0:
		p.get_tree().create_timer(free_after, false).timeout.connect(p.queue_free)
	return p


## A one-off spray of `count` sparks from `at`.
static func burst(into: Node, at: Vector3, color: Color, count: int = 30, speed: Vector2 = Vector2(2.0, 6.0),
		dir: Vector3 = Vector3.UP, spread: float = 180.0, size: Vector2 = Vector2(0.03, 0.07),
		gravity: Vector3 = Vector3(0, -6, 0), life: float = 0.5) -> GPUParticles3D:
	if into == null:
		return null
	return particles(into, at, {
		"amount": count, "life": life, "one_shot": true, "explosiveness": 0.95,
		"speed": speed, "dir": dir, "spread": spread, "gravity": gravity, "damping": 2.0,
		"size": size, "colors": [Color(1, 1, 1, 1), color, Color(color.r, color.g, color.b, 0.0)],
	})


## A ring that opens out and fades: `normal` is the way it faces.
static func ring(into: Node, at: Vector3, normal: Vector3, color: Color, from_r: float = 0.2,
		to_r: float = 1.6, time: float = 0.35, thickness: float = 0.03, energy: float = 2.0) -> MeshInstance3D:
	if into == null:
		return null
	var mi := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 1.0 - thickness
	t.outer_radius = 1.0 + thickness
	t.rings = 48
	t.ring_segments = 6
	mi.mesh = t
	var mat := glow(color, energy)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	into.add_child(mi)
	mi.global_position = at
	var n := normal.normalized() if normal.length_squared() > 0.0001 else Vector3.UP
	var side := n.cross(Vector3.RIGHT if absf(n.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD).normalized()
	mi.global_basis = Basis(side, n, side.cross(n)).orthonormalized()
	mi.scale = Vector3.ONE * from_r
	var tw := mi.create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * to_r, time).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(mat, "albedo_color:a", 0.0, time).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(mi.queue_free)
	return mi


## A bright ball that swells and is gone.
static func flash(into: Node, at: Vector3, color: Color, size: float = 0.5, time: float = 0.22,
		energy: float = 3.0) -> MeshInstance3D:
	if into == null:
		return null
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 1.0
	s.height = 2.0
	s.radial_segments = 16
	s.rings = 8
	mi.mesh = s
	var mat := glow(color, energy)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	into.add_child(mi)
	mi.global_position = at
	mi.scale = Vector3.ONE * size * 0.3
	var tw := mi.create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * size, time).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, time).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(mi.queue_free)
	return mi


## A short-lived light, flaring and gone.
static func light(into: Node, at: Vector3, color: Color, energy: float = 3.0, reach: float = 6.0,
		time: float = 0.35) -> OmniLight3D:
	if into == null:
		return null
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = energy
	l.omni_range = reach
	l.shadow_enabled = false
	into.add_child(l)
	l.global_position = at
	var tw := l.create_tween()
	tw.tween_property(l, "light_energy", 0.0, time).set_ease(Tween.EASE_IN)
	tw.tween_callback(l.queue_free)
	return l


## A thin glowing rod from `a` to `b`, for beams and streams.
static func rod(into: Node, a: Vector3, b: Vector3, color: Color, radius: float = 0.02,
		energy: float = 2.0) -> MeshInstance3D:
	if into == null:
		return null
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = radius
	c.bottom_radius = radius
	c.height = 1.0
	c.radial_segments = 8
	c.rings = 1
	mi.mesh = c
	mi.material_override = glow(color, energy)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	into.add_child(mi)
	place_rod(mi, a, b)
	return mi


## Lays a unit rod (Y up, 1 m) from `a` to `b`.
static func place_rod(mi: Node3D, a: Vector3, b: Vector3) -> void:
	var d := b - a
	var length := d.length()
	if length < 0.0001:
		mi.visible = false
		return
	mi.visible = true
	var y := d / length
	var x := y.cross(Vector3.UP if absf(y.y) < 0.95 else Vector3.RIGHT).normalized()
	var z := x.cross(y).normalized()
	mi.global_transform = Transform3D(Basis(x, y * length, z), (a + b) * 0.5)


## Fades a glow material's alpha to nothing and frees `node` after.
static func fade_out(node: Node, mat: StandardMaterial3D, time: float) -> void:
	if node == null or mat == null:
		return
	var tw := node.create_tween()
	tw.tween_property(mat, "albedo_color:a", 0.0, time)
	tw.tween_callback(node.queue_free)
