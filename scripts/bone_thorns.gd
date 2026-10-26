class_name BoneThorns
extends Node3D

## The skeleton mage's ground spell ([MageFighter], the user's word
## 2026-10-26, shown in films first): a rune circle flashes on the ground
## where the hero stands — `warn` seconds, time to get out — then bone spears
## burst up out of it, curving outward round a tall one, with chips of bone,
## dust and a violet pulse, and whoever is still inside takes the blow
## (`receive_blow`, a spell: through m.def; host only). They hold, then sink
## back into the ground.

var radius: float = 1.9
var warn: float = 0.5
var damage: float = 30.0
var shooter: Node3D

const COLOUR := Color(0.8, 0.5, 1.0)
const HOLD := 1.4
const SINK := 0.6

var _age: float = 0.0
var _erupted: bool = false
var _circle: MeshInstance3D
var _circle_mat: StandardMaterial3D
var _light: OmniLight3D
var _spikes: Array[Dictionary] = []
var _chips: Array[Dictionary] = []
var _dust: CPUParticles3D

static var _rune_tex: ImageTexture


static func cast(into: Node, at: Vector3, from: Node3D, hurt: float, size: float = 1.9,
		wait: float = 0.5) -> BoneThorns:
	if into == null:
		return null
	var thorns := BoneThorns.new()
	thorns.radius = size
	thorns.warn = wait
	thorns.damage = hurt
	thorns.shooter = from
	into.add_child(thorns)
	thorns.global_position = at
	return thorns


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(global_position.snapped(Vector3.ONE * 0.1))
	_circle = MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(1, 1)
	_circle.mesh = pm
	_circle_mat = StandardMaterial3D.new()
	_circle_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_circle_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_circle_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_circle_mat.albedo_texture = rune_texture()
	_circle_mat.albedo_color = Color(COLOUR, 0.0)
	_circle_mat.render_priority = 2
	_circle.material_override = _circle_mat
	_circle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_circle.position = Vector3(0, 0.04, 0)
	add_child(_circle)
	_light = OmniLight3D.new()
	_light.light_color = Color(0.7, 0.45, 1.0)
	_light.omni_range = 5.0
	_light.light_energy = 0.0
	_light.position = Vector3(0, 0.6, 0)
	add_child(_light)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.7
	# the ring of spears: one tall in the middle, the rest round it leaning out
	var count := 15
	var spread := radius / 1.9
	for i in count:
		var big := i == 0
		var h := 3.0 if big else rng.randf_range(1.1, 2.3)
		var r := 0.2 if big else rng.randf_range(0.07, 0.14)
		var mi := MeshInstance3D.new()
		mi.mesh = spear_mesh(h, r, 0.0 if big else rng.randf_range(0.25, 0.6))
		mi.material_override = mat
		mi.visible = false
		add_child(mi)
		var ang := TAU * i / (count - 1) + rng.randf_range(-0.25, 0.25)
		var rad := 0.0 if big else rng.randf_range(0.8, 1.85) * spread
		var out := Vector3(cos(ang), 0, sin(ang))
		var lean := Basis(out.cross(Vector3.UP).normalized(), 0.0 if big else -deg_to_rad(rng.randf_range(5, 18)))
		_spikes.append({"mi": mi, "base": out * rad, "b": lean * Basis(Vector3.UP, -ang), "h": h,
				"delay": 0.0 if big else 0.04 + rng.randf_range(0.0, 0.16)})
	for i in 16:
		var mi := MeshInstance3D.new()
		mi.mesh = spear_mesh(rng.randf_range(0.12, 0.25), 0.03, 0.03)
		mi.material_override = mat
		mi.visible = false
		add_child(mi)
		var a := rng.randf() * TAU
		_chips.append({"mi": mi, "p": Vector3(cos(a), 0.1, sin(a)) * rng.randf_range(0.2, 1.6) * spread,
				"v": Vector3(cos(a) * rng.randf_range(1.5, 4.0), rng.randf_range(3.5, 7.0), sin(a) * rng.randf_range(1.5, 4.0)),
				"spin": Vector3(rng.randf_range(-12, 12), rng.randf_range(-12, 12), rng.randf_range(-12, 12))})
	_dust = CPUParticles3D.new()
	_dust.emitting = false
	_dust.one_shot = true
	_dust.amount = 90
	_dust.lifetime = 1.4
	_dust.explosiveness = 0.9
	_dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_dust.emission_sphere_radius = 1.5 * spread
	_dust.direction = Vector3.UP
	_dust.spread = 70
	_dust.initial_velocity_min = 1.0
	_dust.initial_velocity_max = 3.0
	_dust.gravity = Vector3(0, -1.5, 0)
	_dust.damping_min = 2.0
	_dust.damping_max = 3.0
	_dust.scale_amount_min = 1.0
	_dust.scale_amount_max = 2.6
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.4))
	curve.add_point(Vector2(1, 1.0))
	_dust.scale_amount_curve = curve
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.62, 0.57, 0.5, 0.55))
	ramp.set_color(1, Color(0.62, 0.57, 0.5, 0.0))
	_dust.color_ramp = ramp
	var dsm := SphereMesh.new()
	dsm.radius = 0.12
	dsm.height = 0.24
	dsm.radial_segments = 12
	dsm.rings = 6
	var dm := StandardMaterial3D.new()
	dm.albedo_color = Color(1, 1, 1, 1)
	dm.vertex_color_use_as_albedo = true
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dsm.material = dm
	_dust.mesh = dsm
	_dust.position = Vector3(0, 0.2, 0)
	_dust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_dust)


func _process(delta: float) -> void:
	_age += delta
	var now := _age
	# the circle: opens fast, burns, fades as the bones come
	var o := clampf(now / 0.18, 0.0, 1.0)
	var fade := clampf((now - warn - 0.15) / 0.5, 0.0, 1.0)
	var size := radius * 2.3 * (0.35 + 0.65 * (1.0 - pow(1.0 - o, 3.0)))
	_circle.scale = Vector3(size, 1, size)
	_circle.rotation.y = now * 1.6
	var pulse := 0.75 + 0.25 * sin(now * 40.0)
	_circle_mat.albedo_color = Color(COLOUR, o * (1.0 - fade) * pulse)
	_circle.visible = fade < 1.0
	var since := now - warn
	_light.light_energy = clampf(o * 1.5, 0.0, 1.5) * (1.0 - fade) \
			+ (4.0 * clampf(1.0 - since / 0.5, 0.0, 1.0) if since > 0.0 else 0.0)
	if since > 0.0 and not _erupted:
		_erupt()
	for sp: Dictionary in _spikes:
		var u := clampf((since - float(sp["delay"])) / 0.12, 0.0, 1.0)
		var down := clampf((since - HOLD) / SINK, 0.0, 1.0)
		var k := (1.0 - pow(1.0 - u, 3.0)) * (1.0 - down * down)
		var h: float = sp["h"]
		var mi := sp["mi"] as MeshInstance3D
		mi.visible = u > 0.0 and down < 1.0
		mi.transform = Transform3D(sp["b"], (sp["base"] as Vector3) + Vector3(0, -h * (1.0 - k) - 0.05, 0))
	if _erupted:
		for ch: Dictionary in _chips:
			var mi := ch["mi"] as MeshInstance3D
			ch["v"] = (ch["v"] as Vector3) + Vector3(0, -14.0 * delta, 0)
			var p: Vector3 = (ch["p"] as Vector3) + (ch["v"] as Vector3) * delta
			if p.y < 0.03:
				p.y = 0.03
				ch["v"] = Vector3.ZERO
				ch["spin"] = Vector3.ZERO
			ch["p"] = p
			mi.position = p
			mi.rotation += (ch["spin"] as Vector3) * delta
			mi.visible = since < 2.2
	if since > HOLD + SINK + 0.8:
		queue_free()


func _erupt() -> void:
	_erupted = true
	_dust.emitting = true
	for ch: Dictionary in _chips:
		(ch["mi"] as MeshInstance3D).visible = true
	if not multiplayer.is_server():
		return
	for node in get_tree().get_nodes_in_group("player"):
		var who := node as Node3D
		if who == null or not who.has_method(&"receive_blow") or who.get("net_dead") == true:
			continue
		var off := who.global_position - global_position
		off.y = 0.0
		if off.length() <= radius + 0.25:
			who.call(&"receive_blow", damage, shooter if is_instance_valid(shooter) else self,
					0, 2, get_instance_id() % 100000, true)


## A curved, tapered bone spear along +Y: five sides, bending out (+X) as it
## rises, a knuckle at its foot; ivory going grey at the root (vertex colours).
static func spear_mesh(h: float, r: float, bend: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sides := 5
	var segs := 7
	var rings: Array = []
	for k in segs + 1:
		var u := float(k) / segs
		var c := Vector3(bend * u * u, h * u, 0)
		var rad := r * (1.0 - u) * (1.0 - u * 0.15) + 0.004
		if k == 0:
			rad = r * 1.45
		elif k == 1:
			rad = r * 1.05
		var ring: Array = []
		for sd in sides:
			var a := TAU * sd / sides + u * 0.6
			ring.append(c + Vector3(cos(a) * rad, 0, sin(a) * rad))
		rings.append(ring)
	var root_col := Color(0.42, 0.38, 0.33)
	var tip_col := Color(0.95, 0.92, 0.84)
	for k in segs:
		var c0 := root_col.lerp(tip_col, minf(float(k) / 2.5, 1.0))
		var c1 := root_col.lerp(tip_col, minf(float(k + 1) / 2.5, 1.0))
		for sd in sides:
			var a0: Vector3 = rings[k][sd]
			var a1: Vector3 = rings[k][(sd + 1) % sides]
			var b0: Vector3 = rings[k + 1][sd]
			var b1: Vector3 = rings[k + 1][(sd + 1) % sides]
			for v: Array in [[a0, c0], [b0, c1], [a1, c0], [a1, c0], [b0, c1], [b1, c1]]:
				st.set_color(v[1])
				st.add_vertex(v[0])
	st.generate_normals()
	return st.commit()


## The rune circle, drawn once: two rings, ticks and a star.
static func rune_texture() -> ImageTexture:
	if _rune_tex != null:
		return _rune_tex
	var n := 256
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var dx := (x - n * 0.5) / (n * 0.5)
			var dy := (y - n * 0.5) / (n * 0.5)
			var r := sqrt(dx * dx + dy * dy)
			var ang := atan2(dy, dx)
			var a := 0.0
			a = maxf(a, 1.0 - absf(r - 0.9) / 0.035)
			a = maxf(a, 0.8 * (1.0 - absf(r - 0.62) / 0.025))
			var tick := absf(fmod(ang * 12.0 / TAU + 100.0, 1.0) - 0.5)
			if r > 0.66 and r < 0.86 and tick > 0.44:
				a = maxf(a, 0.9)
			var star := absf(sin(ang * 3.0)) * 0.55
			if absf(r - star) < 0.02 and r < 0.6:
				a = maxf(a, 0.7)
			a = maxf(a, 0.25 * clampf(1.0 - r, 0.0, 1.0) * (1.0 if r < 0.9 else 0.0))
			img.set_pixel(x, y, Color(1, 1, 1, clampf(a, 0.0, 1.0)))
	_rune_tex = ImageTexture.create_from_image(img)
	return _rune_tex
