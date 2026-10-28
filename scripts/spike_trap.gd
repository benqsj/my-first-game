class_name SpikeTrap
extends Node3D

## The traps in the floor of the fighting places (the user's word, 2026-10-22,
## made anew 2026-10-26 after the picture of four he liked: all of them, laid
## sensibly). High-end low poly: the pieces in `traps_lowpoly.glb` (Blender,
## `vepxis-art/world/traps_lowpoly.py`). Three kinds:
##  - "spikes": a stone-framed iron grate; now and then its pit glows and it
##    rattles (`WARN` s), then steel spikes come up through it for `UP` s.
##  - "darts": a round rune plate; step on it and its runes flash, a click,
##    and darts fly out of its six slots all round, low, for a few metres
##    (the user's favourite).
##  - "fire": an iron plate with a skull; now and then its vents and the
##    skull's eyes glow, then fire roars up out of it.
## Whoever is caught is hurt, a hero or a creature alike: a thing to stay
## off, and a thing to lead them onto. No shield takes it; a jump over the
## spikes or the fire does, not over the darts. Laid by [method lay] when a
## place wakes, from the third step on; still once the place is cleared. The
## host deals the hurt; every peer draws it.

const KIT := "res://assets/dungeon/traps/traps_lowpoly.glb"
const WARN := 0.9
const UP := 0.75
const RISE := 0.07
const GRID := 4
## The opening's half-width (the Blender script's IN), and the whole piece's.
const IN := 1.0
const OUT := 1.4
## Kept for the old tests: the dangerous square's side.
const SIZE := 2.0
## What each does to a hero (a share of his life), and to a creature.
const HERO_SHARE := 0.14
const FOE_DAMAGE := 70.0
const DART_SHARE := 0.08
const DART_FOE := 45.0
const FIRE_SHARE := 0.16
const FIRE_FOE := 80.0
const HOT := Color(1.0, 0.35, 0.08)
const RUNE_GLOW := Color(0.35, 0.85, 1.0)
const DART_SPEED := 15.0
const DART_REACH := 7.5
const DART_REST := 2.6

var kind := "spikes"
var _d: Dungeon
var _room: int = -1
var _period: float = 4.5
var _offset: float = 0.0
var _spikes: MultiMeshInstance3D
var _glow: StandardMaterial3D
var _cycle: int = -1
var _warned: int = -1
var _struck: Dictionary = {}
var _lift: float = -1.0
var _armed_at: float = 0.0
var _fire_at: float = -1.0
var _darts: Array[Dictionary] = []
var _flame: GPUParticles3D
var _flash: OmniLight3D
var _shown := false
## Raises (spikes), volleys (darts) or bursts (fire) so far (tests).
var raised: int = 0

static var _kit: Node3D


## A few in place `i` of `d`, on open floor, not at the doors nor the middle;
## of which kinds, by how far into the run and what kind of place it is.
static func lay(d: Dungeon, i: int, rng: RandomNumberGenerator) -> Array[SpikeTrap]:
	var out: Array[SpikeTrap] = []
	if i >= d._room_nodes.size() or not is_instance_valid(d._room_nodes[i]):
		return out
	var room := d._room_nodes[i]
	var r := d._room(i)
	var w: float = r["w"]
	var l: float = r["l"]
	var c := d.centre(i)
	var kinds := _kinds_for(d.stage_of(i), String(r.get("kind", "")), rng)
	var tries := 0
	while out.size() < kinds.size() and tries < 50:
		tries += 1
		var at := c + Vector3(rng.randf_range(-w * 0.32, w * 0.32), 0.0, rng.randf_range(-l * 0.3, l * 0.22))
		# not in the middle (a boss's spot, the lights), nor near another
		if Vector2(at.x - c.x, at.z - c.z).length() < 6.0:
			continue
		var apart := true
		for t in out:
			if Vector2(t.global_position.x - at.x, t.global_position.z - at.z).length() < OUT * 4.0:
				apart = false
		if not apart:
			continue
		var floor_y := _floor_at(room, at, c.y)
		if is_nan(floor_y):
			continue
		var trap := SpikeTrap.new()
		trap.name = "Spikes%d" % out.size()
		trap.kind = kinds[out.size()]
		trap._d = d
		trap._room = i
		trap._period = rng.randf_range(3.6, 5.6)
		trap._offset = rng.randf() * trap._period
		room.add_child(trap)
		trap.global_position = Vector3(at.x, floor_y, at.z)
		trap.rotation.y = float(rng.randi_range(0, 3)) * PI * 0.5
		out.append(trap)
	return out


## Which traps a place gets (the user's word, 2026-10-26: divided sensibly):
## early steps the spikes, a rune plate among them; then the darts more; late
## the fire too. Crypts lean to darts, caves and prisons to spikes, the orcs'
## camp and court and the fortress to fire.
static func _kinds_for(stage: int, place_kind: String, rng: RandomNumberGenerator) -> Array[String]:
	var weights := {"spikes": 3.0, "darts": 1.0, "fire": 0.0}
	if stage >= 5:
		weights = {"spikes": 2.0, "darts": 2.0, "fire": 1.0}
	if stage >= 8:
		weights = {"spikes": 1.5, "darts": 2.0, "fire": 2.0}
	match place_kind:
		"flood_crypt", "crypt", "gold_hall":
			weights["darts"] = float(weights["darts"]) * 2.0
		"twin_cave", "cave", "cell_cave", "swamp":
			weights["spikes"] = float(weights["spikes"]) * 2.0
		"war_camp", "lord_court", "fort", "rampart":
			weights["fire"] = float(weights["fire"]) * 2.0 + 0.5
	var n := rng.randi_range(3, 5)
	var out: Array[String] = []
	for k in n:
		var total := 0.0
		for key: String in weights:
			total += float(weights[key])
		var roll := rng.randf() * total
		var pick := "spikes"
		for key: String in weights:
			roll -= float(weights[key])
			if roll <= 0.0:
				pick = key
				break
		out.append(pick)
		# fewer of the same: each picked one a little less likely again
		weights[pick] = float(weights[pick]) * 0.6
	return out


## The floor's height under `at`, if it is open floor about the place's own
## (nothing standing on it, no hole); NAN if not.
static func _floor_at(room: Node3D, at: Vector3, near_y: float) -> float:
	var space := room.get_world_3d().direct_space_state
	var top := -INF
	for dx: float in [-1.0, 0.0, 1.0]:
		for dz: float in [-1.0, 0.0, 1.0]:
			var p := at + Vector3(dx * OUT, 0.0, dz * OUT)
			var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 4.0, p + Vector3.DOWN * 3.0, 1)
			var hit := space.intersect_ray(q)
			if hit.is_empty():
				return NAN
			var y := (hit["position"] as Vector3).y
			if absf(y - near_y) > 0.4:
				return NAN
			top = maxf(top, y)
	return top


# ---------------------------------------------------------------- building
static func _ready_kit() -> void:
	if _kit != null and is_instance_valid(_kit):
		return
	_kit = (load(KIT) as PackedScene).instantiate() as Node3D
	for mi: MeshInstance3D in _kit.find_children("*", "MeshInstance3D", true, false):
		var mesh := mi.mesh
		for s in mesh.get_surface_count():
			var mat := mesh.surface_get_material(s)
			match String(mat.resource_name) if mat != null else "":
				"Iron":
					mi.set_surface_override_material(s, TerracePlaces._solid(0.0, 1.0, 0.5))
				"Steel":
					mi.set_surface_override_material(s, TerracePlaces._solid(0.0, 1.2, 0.3))
				"Rune", "Pit":
					pass
				_:
					mi.set_surface_override_material(s, TerracePlaces._solid(0.0, 1.1, 0.9))


func _piece(piece: String) -> MeshInstance3D:
	var src := _kit.get_node_or_null(piece) as MeshInstance3D
	if src == null:
		push_warning("SpikeTrap: no piece " + piece)
		return null
	var n := src.duplicate() as MeshInstance3D
	add_child(n)
	# its glowing parts (the pit, the runes, the vents) this trap's own
	for s in n.mesh.get_surface_count():
		var mat := n.mesh.surface_get_material(s)
		var name := String(mat.resource_name) if mat != null else ""
		if name == "Rune" or name == "Pit":
			n.set_surface_override_material(s, _glow)
	return n


func _ready() -> void:
	_ready_kit()
	_glow = StandardMaterial3D.new()
	_glow.albedo_color = Color(0.05, 0.04, 0.04) if kind != "darts" else Color(0.18, 0.17, 0.17)
	_glow.emission_enabled = true
	_glow.emission = RUNE_GLOW if kind == "darts" else HOT
	_glow.emission_energy_multiplier = 0.0
	match kind:
		"darts":
			_piece("TrRune")
		"fire":
			_piece("TrSkull")
			_make_fire()
		_:
			_piece("TrSpikeFrame")
			var g := _piece("TrGrate")
			if g != null:
				g.position.y = 0.0
			_make_spikes()
	for g in find_children("*", "GeometryInstance3D", true, false):
		(g as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _make_spikes() -> void:
	var src := _kit.get_node_or_null("TrSpike") as MeshInstance3D
	if src == null:
		return
	var mesh := src.mesh.duplicate() as ArrayMesh
	# plain steel (the low poly shader tinted them each a colour in a MultiMesh)
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.62, 0.62, 0.64)
	steel.metallic = 0.85
	steel.roughness = 0.3
	for s in mesh.get_surface_count():
		mesh.surface_set_material(s, steel)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = GRID * GRID
	var bar := IN * 2.0 / float(GRID)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(name)
	for x in GRID:
		for z in GRID:
			var p := Vector3(-IN + bar * (float(x) + 0.5), 0.0, -IN + bar * (float(z) + 0.5))
			var s := rng.randf_range(0.85, 1.1)
			var b := Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3(1.0, s, 1.0))
			mm.set_instance_transform(x * GRID + z, Transform3D(b, p))
	_spikes = MultiMeshInstance3D.new()
	_spikes.multimesh = mm
	_spikes.position = Vector3(0.0, -0.95, 0.0)
	add_child(_spikes)


func _make_fire() -> void:
	_flame = GPUParticles3D.new()
	_flame.amount = 90
	_flame.lifetime = 0.7
	_flame.emitting = false
	_flame.position = Vector3(0.0, 0.1, 0.0)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.75
	pm.direction = Vector3.UP
	pm.spread = 12.0
	pm.initial_velocity_min = 4.0
	pm.initial_velocity_max = 7.0
	pm.gravity = Vector3(0.0, 2.0, 0.0)
	pm.scale_min = 0.6
	pm.scale_max = 1.2
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.5))
	curve.add_point(Vector2(0.3, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	var ct := CurveTexture.new()
	ct.curve = curve
	pm.scale_curve = ct
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.95, 0.6, 1.0))
	grad.add_point(0.35, Color(1.0, 0.5, 0.1, 0.9))
	grad.set_color(grad.get_point_count() - 1, Color(0.3, 0.1, 0.05, 0.0))
	var gt := GradientTexture1D.new()
	gt.gradient = grad
	pm.color_ramp = gt
	_flame.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.7, 0.7)
	var qm := StandardMaterial3D.new()
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	qm.vertex_color_use_as_albedo = true
	qm.albedo_texture = SkillFx.dot()
	quad.material = qm
	_flame.draw_pass_1 = quad
	add_child(_flame)
	_flash = OmniLight3D.new()
	_flash.light_color = Color(1.0, 0.55, 0.2)
	_flash.light_energy = 0.0
	_flash.omni_range = 7.0
	_flash.position = Vector3(0.0, 1.2, 0.0)
	_flash.set_meta(&"designed_shadow", false)
	add_child(_flash)


# ---------------------------------------------------------------- working
## Whether it is working: its place fought in, not yet cleared.
func _awake() -> bool:
	return _d != null and _d.current == _room and _d.get(&"_woken") == true \
			and _room < _d.cleared.size() and not bool(_d.cleared[_room])


## For pictures: as it is at its worst, held so.
func show_active() -> void:
	_shown = true
	_glow.emission_energy_multiplier = 3.0
	if _spikes != null:
		_spikes.position.y = 0.0
	if _flame != null:
		_flame.emitting = true
		_flash.light_energy = 3.0
	if kind == "darts":
		_volley()


func _process(delta: float) -> void:
	if _shown:
		for dart in _darts:
			var node: Node3D = dart["node"] as Node3D if is_instance_valid(dart["node"]) else null
			if is_instance_valid(node) and float(dart["gone"]) < 2.2:
				node.global_position += (dart["dir"] as Vector3) * DART_SPEED * delta
				dart["gone"] = float(dart["gone"]) + DART_SPEED * delta
		return
	_fly_darts(delta)
	if not _awake():
		_glow.emission_energy_multiplier = move_toward(_glow.emission_energy_multiplier, 0.0, delta * 4.0)
		if _spikes != null:
			_spikes.position.y = move_toward(_spikes.position.y, -0.95, delta * 2.0)
		if _flash != null:
			_flash.light_energy = move_toward(_flash.light_energy, 0.0, delta * 8.0)
		return
	match kind:
		"darts":
			_darts_tick(delta)
		"fire":
			_fire_tick(delta)
		_:
			_spikes_tick(delta)


func _phase() -> Vector3:
	# (which cycle, the time into it, when the warning starts)
	var clock := Time.get_ticks_msec() / 1000.0 + _offset
	var n := int(floor(clock / _period))
	return Vector3(float(n), clock - float(n) * _period, _period - WARN - UP)


func _spikes_tick(delta: float) -> void:
	var ph := _phase()
	var n := int(ph.x)
	var t := ph.y
	if t < ph.z:
		_glow.emission_energy_multiplier = move_toward(_glow.emission_energy_multiplier, 0.0, delta * 4.0)
		_spikes.position.y = move_toward(_spikes.position.y, -0.95, delta * 3.0)
		_lift = -1.0
		return
	if t < ph.z + WARN:
		# waking: the pit glows hotter, the spikes rattle just under the grate
		var u := (t - ph.z) / WARN
		_glow.emission_energy_multiplier = 0.4 + 3.0 * u * (0.75 + 0.25 * sin(t * 40.0))
		_spikes.position.y = -0.7 + 0.03 * sin(t * 70.0)
		if _warned != n:
			_warned = n
			Sfx.play(_d, Dungeon.SND + "creak.wav", null, global_position + Vector3.UP * 0.3, 2.2, -4.0)
		return
	_glow.emission_energy_multiplier = 2.0
	if _cycle != n:
		_cycle = n
		_struck.clear()
		raised += 1
		_lift = 0.0
		Sfx.play(_d, "res://sounds/parry/clang.wav", null, global_position + Vector3.UP * 0.3, 0.55, -3.0)
		_dust(Color(0.55, 0.5, 0.45))
	_lift += delta
	_spikes.position.y = lerpf(-0.7, 0.0, clampf(_lift / RISE, 0.0, 1.0))
	if _d.decides() and _lift >= RISE * 0.5:
		_strike_square(IN + 0.15, HERO_SHARE, FOE_DAMAGE, &"spike")


func _fire_tick(delta: float) -> void:
	var ph := _phase()
	var n := int(ph.x)
	var t := ph.y
	if t < ph.z:
		_glow.emission_energy_multiplier = move_toward(_glow.emission_energy_multiplier, 0.0, delta * 3.0)
		_flash.light_energy = move_toward(_flash.light_energy, 0.0, delta * 10.0)
		_flame.emitting = false
		return
	if t < ph.z + WARN:
		# waking: the vents and the skull's eyes glow, a hiss
		var u := (t - ph.z) / WARN
		_glow.emission_energy_multiplier = 0.5 + 3.5 * u * (0.8 + 0.2 * sin(t * 30.0))
		_flash.light_energy = 0.6 * u
		if _warned != n:
			_warned = n
			Sfx.play(_d, Dungeon.SND + "portal_whoosh.wav", null, global_position + Vector3.UP * 0.3, 0.6, -6.0)
		return
	_glow.emission_energy_multiplier = 4.0
	_flash.light_energy = 3.0 + 0.6 * sin(t * 25.0)
	if _cycle != n:
		_cycle = n
		_struck.clear()
		raised += 1
		_flame.restart()
		_flame.emitting = true
		Sfx.play(_d, Dungeon.SND + "portal_open.wav", null, global_position + Vector3.UP * 0.5, 1.6, -2.0)
	if _d.decides():
		_strike_round(OUT - 0.15, 2.4, FIRE_SHARE, FIRE_FOE, &"fire")


func _darts_tick(delta: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	# the runes breathing faintly while it waits; bright as it goes
	if _fire_at > 0.0:
		_glow.emission_energy_multiplier = 3.5
		if now >= _fire_at:
			_fire_at = -1.0
			_volley()
		return
	# (dark while it waits: only a flash as it goes, no ring lit on the floor)
	_glow.emission_energy_multiplier = move_toward(_glow.emission_energy_multiplier, 0.0, delta * 3.0)
	if now < _armed_at:
		return
	# stepped on: by anyone, on any peer (each draws its own; the host hurts)
	if _anyone_on(OUT - 0.2):
		_fire_at = now + 0.35
		_armed_at = now + DART_REST
		Sfx.play(_d, Dungeon.SND + "creak.wav", null, global_position + Vector3.UP * 0.2, 2.8, -2.0)


## Six darts out of the slots, flying low and level all round.
func _volley() -> void:
	raised += 1
	_struck.clear()
	var src := _kit.get_node_or_null("TrDart") as MeshInstance3D
	for k in 6:
		var a := float(k) / 6.0 * TAU + PI / 6.0 + rotation.y
		var dir := Vector3(cos(a), 0.0, -sin(a))
		var dart := Node3D.new()
		if src != null:
			var m := src.duplicate() as MeshInstance3D
			m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			dart.add_child(m)
		_d.add_child(dart)
		dart.global_position = global_position + dir * 0.55 + Vector3.UP * 0.55
		# the piece flies along its own -z (Blender's +y)
		dart.look_at(dart.global_position + dir, Vector3.UP)
		_darts.append({"node": dart, "dir": dir, "gone": 0.0})
	Sfx.play(_d, Dungeon.SND + "portal_whoosh.wav", null, global_position + Vector3.UP * 0.5, 2.2, -2.0)
	_dust(Color(0.5, 0.75, 0.85))


func _fly_darts(delta: float) -> void:
	var k := 0
	while k < _darts.size():
		var dart: Dictionary = _darts[k]
		var node := dart["node"] as Node3D
		var step := DART_SPEED * delta
		dart["gone"] = float(dart["gone"]) + step
		if not is_instance_valid(node) or float(dart["gone"]) > DART_REACH:
			if is_instance_valid(node):
				node.queue_free()
			_darts.remove_at(k)
			continue
		node.global_position += (dart["dir"] as Vector3) * step
		if _d.decides():
			_strike_point(node.global_position, 0.55, DART_SHARE, DART_FOE, &"dart")
		k += 1


# ---------------------------------------------------------------- hurting
func _dust(col: Color) -> void:
	var world := Blood.world_of(self)
	if world != null:
		SkillFx.burst(world, global_position + Vector3.UP * 0.2, col, 26,
				Vector2(1.0, 3.0), Vector3.UP, 70.0, Vector2(0.04, 0.1), Vector3(0, -6.0, 0), 0.6)


func _bodies() -> Array[Node3D]:
	var out: Array[Node3D] = []
	for hero in _d._heroes():
		if not hero.is_dead:
			out.append(hero)
	var creatures := _d._creatures_node()
	if creatures != null:
		for node in creatures.get_children():
			var body := node as Node3D
			if body == null or not body.visible or bool(body.get(&"is_dead")) or body is Flyer:
				continue
			out.append(body)
	return out


func _hurt(body: Node3D, share: float, foe: float, how: StringName) -> void:
	if _struck.has(body.get_instance_id()):
		return
	_struck[body.get_instance_id()] = true
	if body is Player:
		var hero := body as Player
		hero.receive_blow(hero.max_health * share, self, 0, 1, _cycle, false, how)
	elif body.has_method(&"take_hit"):
		body.call(&"take_hit", foe, body.global_position + Vector3.UP * 0.4, Vector3.UP * 2.0,
				false, true, null, false)


## Host: whoever stands over the square now, once a raise.
func _strike_square(half: float, share: float, foe: float, how: StringName) -> void:
	for body in _bodies():
		var rel := body.global_position - global_position
		if absf(rel.x) < half and absf(rel.z) < half and rel.y > -0.5 and rel.y < 0.9:
			_hurt(body, share, foe, how)


## Host: whoever is in the round column of fire, once a burst.
func _strike_round(radius: float, tall: float, share: float, foe: float, how: StringName) -> void:
	for body in _bodies():
		var rel := body.global_position - global_position
		if Vector2(rel.x, rel.z).length() < radius and rel.y > -0.5 and rel.y < tall:
			_hurt(body, share, foe, how)


## Host: whoever a dart passes through, once a volley.
func _strike_point(at: Vector3, radius: float, share: float, foe: float, how: StringName) -> void:
	for body in _bodies():
		var rel := at - body.global_position
		if Vector2(rel.x, rel.z).length() < radius and rel.y > 0.0 and rel.y < 1.8:
			_hurt(body, share, foe, how)


func _anyone_on(radius: float) -> bool:
	for body in _bodies():
		var rel := body.global_position - global_position
		if Vector2(rel.x, rel.z).length() < radius and absf(rel.y) < 0.8:
			return true
	return false


func _exit_tree() -> void:
	for dart in _darts:
		if is_instance_valid(dart["node"]):
			(dart["node"] as Node).queue_free()
	_darts.clear()
