class_name ShadowGrasp
extends Node3D

## The dark elf's Dark Hands ([DarkSkills]): a circle of violet runes opens on
## the ground where she points and turns, black smoke and motes drawn down into
## it — time to get out — then the ground cracks and long black hands burst up
## out of it. Two take hold of each foe still in it, close on it and hold it
## where it stands ([ShadowHold]) for `HOLD` (half that on a boss); more grab
## at the air round them. Whatever is caught takes a spell's blow (through
## m.def).
##
## The circle, the runes and the empty hands are drawn on every peer from the
## same message ([method Player.net_dark_grasp]); who is caught is the host's
## to say, and it tells everyone ([method Player.net_dark_held]), so the hands
## that hold are on everyone's screen on the same bodies.

const RADIUS := 4.5
const WARN := 0.75
const HOLD := 2.6
## Hands that grab at nothing, scattered round the circle.
const EMPTY := 6

var caster: Player
var damage: float = 0.0
var critical: bool = false
## Only drawn ([method DarkSkills.warm]): it catches no one.
var dummy := false

var _age: float = 0.0
var _done := false
var _runes: Decal
var _spikes: Decal
var _glow: OmniLight3D
var _swirl: GPUParticles3D
var _rng := RandomNumberGenerator.new()


static func open(into: Node, at: Vector3, by: Player, hurt: float, crit: bool, grasp_seed: int) -> ShadowGrasp:
	if into == null:
		return null
	var g := ShadowGrasp.new()
	g.caster = by
	g.damage = hurt
	g.critical = crit
	g._rng.seed = grasp_seed
	into.add_child(g)
	g.global_position = at
	return g


func _ready() -> void:
	var into := get_parent()
	var at := global_position
	_runes = DarkFx.decal(into, at, DarkFx.RUNES, RADIUS * 2.15, Color(DarkFx.VOID, 0.0), 3.0, 0.15)
	_spikes = DarkFx.decal(into, at, DarkFx.SPIKES, RADIUS * 1.5, Color(DarkFx.VOID, 0.0), 2.0, 0.5)
	_glow = OmniLight3D.new()
	_glow.light_color = DarkFx.VOID
	_glow.light_energy = 0.0
	_glow.omni_range = RADIUS * 2.2
	into.add_child(_glow)
	_glow.global_position = at + Vector3.UP * 0.6
	# motes and wisps drawn down and round into the circle
	_swirl = SkillFx.particles(into, at + Vector3.UP * 0.4, {"amount": 40, "life": 0.7,
			"ring": Vector2(RADIUS * 0.8, RADIUS), "speed": Vector2(0.0, 0.2), "orbit": -5.0,
			"tangent": 4.0, "gravity": Vector3(0, -1.2, 0), "size": Vector2(0.03, 0.07), "grow": 0.3,
			"colors": [Color(DarkFx.HOT, 0.0), Color(DarkFx.HOT, 1.0), Color(DarkFx.VOID, 0.0)]})
	SkillFx.particles(into, at + Vector3.UP * 0.2, {"amount": 14, "life": 0.9, "one_shot": true,
			"explosiveness": 0.3, "ring": Vector2(RADIUS * 0.6, RADIUS), "speed": Vector2(0.2, 0.6),
			"orbit": -2.0, "tangent": 1.5, "size": Vector2(0.6, 1.0), "grow": 0.6, "add": false,
			"tex": DarkFx.PUFF, "spin": true,
			"colors": [Color(DarkFx.INK, 0.0), Color(DarkFx.INK, 0.6), Color(0.1, 0.05, 0.12, 0.0)]})


func _process(delta: float) -> void:
	_age += delta
	if not _done:
		var t := clampf(_age / WARN, 0.0, 1.0)
		_runes.rotation.y += delta * 1.2
		_spikes.rotation.y -= delta * 2.4
		_runes.modulate.a = minf(t * 2.0, 1.0)
		_spikes.modulate.a = t * t
		_spikes.size = Vector3(RADIUS * lerpf(2.4, 1.5, t), 0.9, RADIUS * lerpf(2.4, 1.5, t))
		_glow.light_energy = 1.2 * t
		if _age >= WARN:
			_erupt()
		return
	var fade := clampf((_age - WARN - HOLD * 0.7) / 0.8, 0.0, 1.0)
	_runes.rotation.y += delta * 0.4
	_runes.modulate.a = 1.0 - fade
	_spikes.modulate.a = 0.0
	_glow.light_energy = 1.2 * (1.0 - fade)
	if fade >= 1.0:
		for n: Variant in [_runes, _spikes, _glow, _swirl]:
			if is_instance_valid(n):
				(n as Node).queue_free()
		queue_free()


func _erupt() -> void:
	_done = true
	_swirl.emitting = false
	var into := get_parent()
	var at := global_position
	# the ground split under the circle, the cracks burning violet
	var crack := DarkFx.decal(into, at, DarkFx.CRACK, RADIUS * 2.3, Color(DarkFx.VOID, 1.0), 4.0, 0.7)
	crack.rotation.y = _rng.randf() * TAU
	var tw := crack.create_tween()
	tw.tween_property(crack, "emission_energy", 0.0, HOLD + 1.0).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(crack, "modulate:a", 0.0, HOLD + 1.6).set_ease(Tween.EASE_IN)
	tw.tween_callback(crack.queue_free)
	SkillFx.ring(into, at + Vector3.UP * 0.1, Vector3.UP, DarkFx.VOID, 0.4, RADIUS * 1.15, 0.35, 0.03, 3.0)
	SkillFx.light(into, at + Vector3.UP * 1.0, DarkFx.HOT, 5.0, RADIUS * 3.0, 0.45)
	DarkFx.smoke(into, at + Vector3.UP * 0.3, 10, 1.6, 1.5, 1.4, RADIUS * 0.6)
	DarkFx.embers(into, at + Vector3.UP * 0.2, 30, Vector2(2.0, 5.0), 1.0, 60.0)
	if caster != null and is_instance_valid(caster) and caster.is_multiplayer_authority():
		WindBlast.shake(caster, 0.05, 0.22)
	# empty hands round the edge, clutching at nothing
	for k in EMPTY:
		var a := TAU * (k + _rng.randf() * 0.6) / EMPTY
		var r := RADIUS * _rng.randf_range(0.45, 0.9)
		var spot := at + Vector3(cos(a) * r, 0.0, sin(a) * r)
		spot.y = _ground_y(spot, at.y)
		ShadowHand.rise(into, spot, at, _rng.randf_range(0.8, 1.0), HOLD * _rng.randf_range(0.45, 0.7), 0.5)
	if multiplayer.is_server() and not dummy:
		_catch()


## The host: who is in it is caught, hurt, and held — and everyone is told.
func _catch() -> void:
	var paths: Array = []
	var times: Array = []
	for who in _foes():
		var off := who.global_position - global_position
		off.y = 0.0
		var br: Variant = who.get(&"body_radius")
		if off.length() > RADIUS + (float(br) if br != null else 0.4) * 0.6:
			continue
		if absf(who.global_position.y - global_position.y) > 2.5:
			continue
		var at := who.global_position + Vector3.UP * 0.8
		if who is Player:
			if who.get("net_dead") != true:
				who.call(&"receive_blow", damage, caster if is_instance_valid(caster) else self,
						0, 2, get_instance_id() % 100000, true)
		elif who.has_method(&"take_hit"):
			who.call(&"take_hit", damage, at, Vector3.UP * 0.5, critical, false, caster, true)
		var seconds := HOLD * (0.5 if is_boss(who) else 1.0)
		paths.append(who.get_path())
		times.append(seconds)
	if not paths.is_empty() and caster != null and is_instance_valid(caster):
		caster.net_dark_held.rpc(paths, times)


## The creatures, and the heroes she is hostile to (PvP).
func _foes() -> Array[Node3D]:
	var out: Array[Node3D] = []
	for node in get_tree().get_nodes_in_group(&"enemy"):
		var who := node as Node3D
		if who != null and who.get(&"is_dead") != true:
			out.append(who)
	if caster != null and is_instance_valid(caster) and Player.pvp_mode:
		for node in get_tree().get_nodes_in_group(&"player"):
			if caster.is_hostile_to(node):
				out.append(node as Node3D)
	return out


## A boss (a creature with stages of its fight, or a great deal of health) is
## held half as long.
static func is_boss(who: Node) -> bool:
	var phases: Variant = who.get(&"phases")
	if phases is Array and not (phases as Array).is_empty():
		return true
	var most: Variant = who.get(&"max_health")
	return most != null and float(most) >= 1200.0


## Every peer: `body` caught: two hands out of the ground either side of it,
## closing on its legs, held for `seconds`; and on its own peer it cannot move.
static func clutch(body: Node3D, seconds: float) -> void:
	if body == null or not body.is_inside_tree():
		return
	ShadowHold.hold(body, seconds)
	var into := body.get_parent()
	var br: Variant = body.get(&"body_radius")
	var r := clampf(float(br) if br != null else 0.4, 0.3, 1.6)
	var size := clampf(r / 0.4, 0.9, 2.2)
	var at := body.global_position
	var face := -body.global_basis.z
	face.y = 0.0
	face = face.normalized() if face.length_squared() > 0.0001 else Vector3.FORWARD
	var side := face.cross(Vector3.UP).normalized()
	for k in 2:
		var dir := (side * (1.0 if k == 0 else -1.0) + face * (0.45 if k == 0 else -0.45)).normalized()
		var spot := at + dir * (r + 0.35 * size)
		ShadowHand.rise(into, spot, at, size, seconds - 0.1, 0.55)
	DarkFx.black_fire(into, at + Vector3.UP * 0.05, seconds, 1.0, {"ring": Vector2(r * 0.6, r + 0.2), "rate": 1.2})
	# a band of violet round its feet while it is held
	SkillFx.ring(into, at + Vector3.UP * 0.12, Vector3.UP, DarkFx.HOT, r + 0.6, r * 0.9, 0.3, 0.05, 3.0)


func _ground_y(p: Vector3, fallback: float) -> float:
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 2.0, p + Vector3.DOWN * 4.0, 1)
	var hit := space.intersect_ray(q)
	return (hit["position"] as Vector3).y if not hit.is_empty() else fallback
