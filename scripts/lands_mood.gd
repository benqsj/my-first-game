class_name LandsMood
extends Node

## Each land's own light and air (the map's `mood`), eased in round the hero.
##
## The west is a warm late afternoon, the north a cold clear morning, Mamberi's
## spruce wood grey and thick with mist, Ochopintre's beeches in a golden
## evening, the devs' mountains cold and windy. What the land asks for is mixed
## by how much of each land lies round the hero (sampled over a few dozen
## metres, so a border is crossed over a stretch, not at a line) and eased in
## over a couple of seconds: the fog's colour and thickness, the sun's height,
## bearing and colour, and what drifts in the air.
##
## It changes the level's own [WorldEnvironment] and sun, on top of whatever
## [Looks] and the graphics setting put there: anything they write is taken as
## the new base, and the core is always the base itself.

## How far round the hero the lands are weighed, metres.
@export var reach: float = 26.0
## How fast the air follows the hero, per second (0..1 of the way).
@export var ease_rate: float = 0.9
## How much of a land's mood is put on (1 = all of it).
@export var strength: float = 0.85
@export var particles: bool = true

const REGIONS: PackedStringArray = ["core", "west", "north", "mamberi", "ochopintre", "devi"]
## What drifts in each land's air: [amount, colour, size, fall speed, spread up, sway].
const AIR := {
	"west": [50, Color(1.0, 0.9, 0.6, 0.55), 0.06, -0.05, 0.3, 0.6],
	"north": [30, Color(0.95, 0.97, 1.0, 0.4), 0.05, -0.1, 0.1, 1.2],
	"mamberi": [26, Color(0.85, 0.9, 0.88, 0.07), 3.2, 0.02, 0.05, 0.2],
	"ochopintre": [90, Color(0.95, 0.5, 0.18, 0.95), 0.14, -0.7, 0.0, 0.9],
	"devi": [160, Color(1.0, 1.0, 1.0, 0.85), 0.07, -1.4, 0.0, 0.5],
}

var _env: Environment
var _sun: DirectionalLight3D
var _region := PackedByteArray()
var _moods: Array = []
var _weights := PackedFloat32Array()
var _base: Dictionary = {}
var _written: Dictionary = {}
var _air: CPUParticles3D
var _air_kind := ""
var _tick := 0


func _ready() -> void:
	var lands := Lands.current
	if lands == null or not is_instance_valid(lands):
		set_process(false)
		return
	_region = Lands._read("region.u8.gz", lands.nx * lands.nz)
	var regions: Dictionary = lands.info.get("regions", {})
	for key in REGIONS:
		_moods.append(regions[key].get("mood", {}) if regions.has(key) else {})
	_weights.resize(REGIONS.size())
	_weights.fill(0.0)
	_weights[0] = 1.0
	var world := get_parent()
	var envs := world.find_children("*", "WorldEnvironment", true, false)
	if not envs.is_empty():
		_env = (envs[0] as WorldEnvironment).environment
	var suns := world.find_children("*", "DirectionalLight3D", true, false)
	if not suns.is_empty():
		_sun = suns[0] as DirectionalLight3D
	if particles:
		_build_air()


## The land at (x, z): an index into [constant REGIONS].
func region_at(x: float, z: float) -> int:
	var lands := Lands.current
	if lands == null or _region.is_empty() or not lands.inside(x, z):
		return 0
	var ix := clampi(int(round(x - lands.x0)), 0, lands.nx - 1)
	var iz := clampi(int(round(z - lands.z0)), 0, lands.nz - 1)
	return clampi(_region[iz * lands.nx + ix], 0, REGIONS.size() - 1)


## How much of each land lies round (x, z), summing to one.
func weights_at(x: float, z: float) -> PackedFloat32Array:
	var w := PackedFloat32Array()
	w.resize(REGIONS.size())
	w.fill(0.0)
	var n := 0
	for dz in range(-2, 3):
		for dx in range(-2, 3):
			w[region_at(x + dx * reach * 0.5, z + dz * reach * 0.5)] += 1.0
			n += 1
	for i in w.size():
		w[i] /= float(n)
	return w


func _viewer() -> Node3D:
	var cam := get_viewport().get_camera_3d()
	if cam != null:
		return cam
	for node in get_tree().get_nodes_in_group(&"player"):
		if node is Node3D:
			return node
	return null


func _process(delta: float) -> void:
	var who := _viewer()
	if who == null:
		return
	var at := who.global_position
	_tick += 1
	if _tick % 6 == 0:
		var want := weights_at(at.x, at.z)
		var k := clampf(ease_rate * delta * 6.0, 0.0, 1.0)
		for i in _weights.size():
			_weights[i] = lerpf(_weights[i], want[i], k)
		_apply()
	if _air != null:
		_air.global_position = at + Vector3(0.0, 4.0, 0.0)
		_update_air()


func _hex(value: Variant, fallback: Color) -> Color:
	var text := String(value) if value != null else ""
	return Color.html(text) if Color.html_is_valid(text) else fallback


## Takes what is in the environment now as the base, unless it is what this
## wrote itself last time.
func _base_of(obj: Object, prop: StringName) -> Variant:
	var key := "%d:%s" % [obj.get_instance_id(), prop]
	var now: Variant = obj.get(prop)
	if not _written.has(key) or _written[key] != now:
		_base[key] = now
	return _base[key]


func _write(obj: Object, prop: StringName, value: Variant) -> void:
	obj.set(prop, value)
	_written["%d:%s" % [obj.get_instance_id(), prop]] = obj.get(prop)


func _apply() -> void:
	if _env != null:
		var fog: Color = _base_of(_env, &"fog_light_color")
		var dense: float = _base_of(_env, &"fog_density")
		var col := Color(0, 0, 0)
		var den := 0.0
		for i in REGIONS.size():
			var w := _weights[i]
			if w <= 0.0001:
				continue
			var mood: Dictionary = _moods[i]
			if i == 0 or mood.is_empty():
				col += fog * w
				den += dense * w
				continue
			var tint := _hex(mood.get("fog"), fog)
			# the mood's hue at the base's brightness
			var lum := maxf(tint.get_luminance(), 0.01)
			tint = Color(tint.r, tint.g, tint.b) * (fog.get_luminance() / lum)
			col += fog.lerp(tint, strength) * w
			var ratio := clampf(float(mood.get("fog_density", 0.0045)) / 0.0045, 0.8, 3.2)
			den += lerpf(dense, dense * ratio, strength) * w
		_write(_env, &"fog_light_color", Color(col.r, col.g, col.b, 1.0))
		_write(_env, &"fog_density", den)
	if _sun != null:
		var basis: Basis = _base_of(_sun, &"basis")
		var colour: Color = _base_of(_sun, &"light_color")
		var q := basis.get_rotation_quaternion()
		var c := Color(0, 0, 0)
		var got := 0.0
		for i in REGIONS.size():
			var w := _weights[i]
			if w <= 0.0001 or i == 0 or (_moods[i] as Dictionary).is_empty():
				continue
			var mood: Dictionary = _moods[i]
			var elev := deg_to_rad(float(mood.get("sun_elev", 40.0)))
			var azim := deg_to_rad(float(mood.get("sun_azim", 200.0)))
			# bearing from north (+z), clockwise through east (-x)
			var to_sun := Vector3(-sin(azim) * cos(elev), sin(elev), cos(azim) * cos(elev))
			var target := Basis.looking_at(-to_sun, Vector3.UP).get_rotation_quaternion()
			q = q.slerp(target, clampf(w * strength / maxf(1.0 - got, w), 0.0, 1.0))
			got += w
			var sky := _hex(mood.get("sky"), colour)
			c += colour.lerp(Color(sky.r, sky.g, sky.b) * (1.0 / maxf(sky.get_luminance(), 0.01)) * colour.get_luminance(), 0.55 * strength) * w
		c += colour * (1.0 - got)
		_write(_sun, &"basis", Basis(q).scaled(basis.get_scale()))
		_write(_sun, &"light_color", Color(c.r, c.g, c.b, 1.0))


#region Air
func _build_air() -> void:
	_air = CPUParticles3D.new()
	_air.name = "Air"
	_air.emitting = false
	_air.local_coords = false
	_air.lifetime = 6.0
	_air.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_air.emission_box_extents = Vector3(18.0, 6.0, 18.0)
	_air.direction = Vector3(1.0, 0.0, 0.3)
	_air.spread = 60.0
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	quad.material = m
	_air.mesh = quad
	add_child(_air)


func _update_air() -> void:
	var best := 0
	for i in _weights.size():
		if _weights[i] > _weights[best]:
			best = i
	var kind := REGIONS[best] if _weights[best] > 0.55 else ""
	if kind == _air_kind:
		return
	_air_kind = kind
	if not AIR.has(kind):
		_air.emitting = false
		return
	var spec: Array = AIR[kind]
	_air.amount = int(spec[0])
	# the quad is drawn at the air's own size and colour (a mote, a leaf, a
	# flake, a wisp)
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * float(spec[2])
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = spec[1]
	m.albedo_texture = LandsMood.soft_dot()
	quad.material = m
	_air.mesh = quad
	_air.scale_amount_min = 0.7
	_air.scale_amount_max = 1.3
	_air.gravity = Vector3(0.0, float(spec[3]), 0.0)
	_air.initial_velocity_min = float(spec[5]) * 0.4
	_air.initial_velocity_max = float(spec[5])
	_air.angular_velocity_min = -90.0 if kind == "ochopintre" else 0.0
	_air.angular_velocity_max = 90.0 if kind == "ochopintre" else 0.0
	_air.emitting = true
#endregion


## A round, soft-edged dot: what a mote, a flake or a wisp of mist is drawn with
## (a bare quad shows its corners).
static func soft_dot() -> GradientTexture2D:
	if _dot != null:
		return _dot
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	_dot = GradientTexture2D.new()
	_dot.gradient = g
	_dot.fill = GradientTexture2D.FILL_RADIAL
	_dot.fill_from = Vector2(0.5, 0.5)
	_dot.fill_to = Vector2(1.0, 0.5)
	_dot.width = 64
	_dot.height = 64
	return _dot

static var _dot: GradientTexture2D = null
