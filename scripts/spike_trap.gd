class_name SpikeTrap
extends Node3D

## A trap in the floor of a fighting place (the user's word, 2026-10-22: the
## portal's surroundings in the fight): a square iron grate. Now and then its
## seams glow and it rattles, with a click (`WARN` s), and then iron spikes
## come up through it for `UP` s — whoever stands on it then is hurt, a hero
## or a creature alike. So it is a thing to stay off, and a thing to lead
## them onto. No shield takes it; a jump over it does.
##
## Laid by [method lay] when a place is come to, from the third step on; still
## once the place is cleared. The host deals the hurt.

const WARN := 0.9
const UP := 0.75
const RISE := 0.07
const GRID := 4
const SIZE := 2.4
## What it does to a hero (a share of his life), and to a creature.
const HERO_SHARE := 0.14
const FOE_DAMAGE := 70.0
const HOT := Color(1.0, 0.35, 0.08)

var _d: Dungeon
var _room: int = -1
var _period: float = 4.5
var _offset: float = 0.0
var _spikes: MultiMeshInstance3D
var _seams: StandardMaterial3D
var _cycle: int = -1
var _warned: int = -1
var _struck: Dictionary = {}
var _lift: float = -1.0
## Raises so far (tests).
var raised: int = 0


## A few in place `i` of `d`, on open floor, not at the doors nor the middle.
static func lay(d: Dungeon, i: int, rng: RandomNumberGenerator) -> Array[SpikeTrap]:
	var out: Array[SpikeTrap] = []
	if i >= d._room_nodes.size() or not is_instance_valid(d._room_nodes[i]):
		return out
	var room := d._room_nodes[i]
	var r := d._room(i)
	var w: float = r["w"]
	var l: float = r["l"]
	var c := d.centre(i)
	var want := rng.randi_range(3, 5)
	var tries := 0
	while out.size() < want and tries < 40:
		tries += 1
		var at := c + Vector3(rng.randf_range(-w * 0.32, w * 0.32), 0.0, rng.randf_range(-l * 0.3, l * 0.22))
		# not in the middle (a boss's spot, the lights), nor near another
		if Vector2(at.x - c.x, at.z - c.z).length() < 6.0:
			continue
		var apart := true
		for t in out:
			if Vector2(t.global_position.x - at.x, t.global_position.z - at.z).length() < SIZE * 2.5:
				apart = false
		if not apart:
			continue
		var floor_y := _floor_at(room, at, c.y)
		if is_nan(floor_y):
			continue
		var trap := SpikeTrap.new()
		trap.name = "Spikes%d" % out.size()
		trap._d = d
		trap._room = i
		trap._period = rng.randf_range(3.6, 5.6)
		trap._offset = rng.randf() * trap._period
		room.add_child(trap)
		trap.global_position = Vector3(at.x, floor_y + 0.02, at.z)
		out.append(trap)
	return out


## The floor's height under `at`, if it is open floor about the place's own
## (nothing standing on it, no hole); NAN if not.
static func _floor_at(room: Node3D, at: Vector3, near_y: float) -> float:
	var space := room.get_world_3d().direct_space_state
	var top := -INF
	for dx: float in [-1.0, 0.0, 1.0]:
		for dz: float in [-1.0, 0.0, 1.0]:
			var p := at + Vector3(dx * SIZE * 0.5, 0.0, dz * SIZE * 0.5)
			var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 4.0, p + Vector3.DOWN * 3.0, 1)
			var hit := space.intersect_ray(q)
			if hit.is_empty():
				return NAN
			var y := (hit["position"] as Vector3).y
			if absf(y - near_y) > 0.4:
				return NAN
			top = maxf(top, y)
	return top


func _ready() -> void:
	# the grate: a dark iron frame, the seams between its bars glowing when it wakes
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.16, 0.15, 0.14)
	iron.metallic = 0.7
	iron.roughness = 0.45
	_seams = StandardMaterial3D.new()
	_seams.albedo_color = Color(0.05, 0.03, 0.02)
	_seams.emission_enabled = true
	_seams.emission = HOT
	_seams.emission_energy_multiplier = 0.0
	var under := _mesh(BoxMesh.new(), _seams, Vector3(SIZE, 0.02, SIZE), Vector3(0.0, 0.0, 0.0))
	under.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var bar := SIZE / float(GRID)
	for k in GRID + 1:
		var off := -SIZE * 0.5 + bar * float(k)
		_mesh(BoxMesh.new(), iron, Vector3(SIZE + 0.12, 0.06, 0.12), Vector3(0.0, 0.03, off))
		_mesh(BoxMesh.new(), iron, Vector3(0.12, 0.06, SIZE + 0.12), Vector3(off, 0.03, 0.0))
	# the spikes, one up each square, down under it till they come
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.09
	cone.height = 0.8
	cone.radial_segments = 6
	cone.rings = 1
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.55, 0.53, 0.5)
	steel.metallic = 0.85
	steel.roughness = 0.3
	cone.material = steel
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = cone
	mm.instance_count = GRID * GRID
	for x in GRID:
		for z in GRID:
			var p := Vector3(-SIZE * 0.5 + bar * (float(x) + 0.5), 0.4, -SIZE * 0.5 + bar * (float(z) + 0.5))
			mm.set_instance_transform(x * GRID + z, Transform3D(Basis.IDENTITY, p))
	_spikes = MultiMeshInstance3D.new()
	_spikes.multimesh = mm
	_spikes.position = Vector3(0.0, -0.9, 0.0)
	_spikes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_spikes)


func _mesh(mesh: PrimitiveMesh, mat: Material, size: Vector3, at: Vector3) -> MeshInstance3D:
	(mesh as BoxMesh).size = size
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = mat
	m.position = at
	add_child(m)
	return m


## Whether it is working: its place fought in, not yet cleared.
func _awake() -> bool:
	return _d != null and _d.current == _room and _d.get(&"_woken") == true \
			and _room < _d.cleared.size() and not bool(_d.cleared[_room])


func _process(delta: float) -> void:
	if not _awake():
		_seams.emission_energy_multiplier = move_toward(_seams.emission_energy_multiplier, 0.0, delta * 4.0)
		_spikes.position.y = move_toward(_spikes.position.y, -0.9, delta * 2.0)
		return
	var clock := Time.get_ticks_msec() / 1000.0 + _offset
	var n := int(floor(clock / _period))
	var t := clock - float(n) * _period
	var warn_from := _period - WARN - UP
	if t < warn_from:
		_seams.emission_energy_multiplier = move_toward(_seams.emission_energy_multiplier, 0.0, delta * 4.0)
		_spikes.position.y = move_toward(_spikes.position.y, -0.9, delta * 3.0)
		_lift = -1.0
		return
	if t < warn_from + WARN:
		# waking: the seams glow hotter, the spikes rattle just under it
		var u := (t - warn_from) / WARN
		_seams.emission_energy_multiplier = 0.4 + 2.6 * u * (0.75 + 0.25 * sin(t * 40.0))
		_spikes.position.y = -0.62 + 0.03 * sin(t * 70.0)
		if _warned != n:
			_warned = n
			Sfx.play(_d, Dungeon.SND + "creak.wav", null, global_position + Vector3.UP * 0.3, 2.2, -4.0)
		return
	# up
	_seams.emission_energy_multiplier = 1.6
	if _cycle != n:
		_cycle = n
		_struck.clear()
		raised += 1
		_lift = 0.0
		Sfx.play(_d, "res://sounds/parry/clang.wav", null, global_position + Vector3.UP * 0.3, 0.55, -3.0)
		var world := Blood.world_of(self)
		if world != null:
			SkillFx.burst(world, global_position + Vector3.UP * 0.2, Color(0.55, 0.5, 0.45), 26,
					Vector2(1.0, 3.0), Vector3.UP, 70.0, Vector2(0.04, 0.1), Vector3(0, -6.0, 0), 0.6)
	_lift += delta
	_spikes.position.y = lerpf(-0.6, 0.0, clampf(_lift / RISE, 0.0, 1.0))
	if _d.decides() and _lift >= RISE * 0.5:
		_strike()


## Host: whoever stands on it now, once a raise.
func _strike() -> void:
	var half := SIZE * 0.5 + 0.15
	for hero in _d._heroes():
		if hero.is_dead or _struck.has(hero.get_instance_id()) or not _over(hero, half):
			continue
		_struck[hero.get_instance_id()] = true
		hero.receive_blow(hero.max_health * HERO_SHARE, self, 0, 1, _cycle, false, &"spike")
	var creatures := _d._creatures_node()
	if creatures == null:
		return
	for node in creatures.get_children():
		var body := node as Node3D
		if body == null or not body.visible or bool(body.get(&"is_dead")) or _struck.has(body.get_instance_id()):
			continue
		if body is Flyer or not _over(body, half) or not body.has_method(&"take_hit"):
			continue
		_struck[body.get_instance_id()] = true
		body.call(&"take_hit", FOE_DAMAGE, body.global_position + Vector3.UP * 0.4, Vector3.UP * 2.0,
				false, true, null, false)


func _over(body: Node3D, half: float) -> bool:
	var rel := body.global_position - global_position
	return absf(rel.x) < half and absf(rel.z) < half and rel.y > -0.5 and rel.y < 0.9
