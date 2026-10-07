class_name DarkComet
extends Node3D

## One of the dark elf's comets ([DarkSkills], the Black Comets): a rock of
## black stone split with violet veins, wrapped in black fire, dragging a tail
## of it and of smoke across the sky from the rift it came out of
## ([DarkRift]) to the ground. Where it will strike a ring burns on the ground
## and tightens as it comes. It strikes: a flash, the ground cracked and burnt
## black round it, a ring of violet thrown out over the ground, stone flying,
## smoke, and black fire left burning there a while. Whatever is within
## `REACH` takes a spell's blow, less at the edge; what it falls right on is
## thrown down ([method Brute.react] `knock`).
##
## Drawn on every peer from the same numbers; only the host's hurts.

const REACH := 2.5
const SQUARE := 1.3
## A comet sent at someone follows him for this share of its fall, then
## comes on to where he was.
const HOME := 0.7
## How long the streak of fire behind it.
const STREAK := 6.0
## Its worth at the edge of `REACH`, of what it is where it falls.
const EDGE := 0.55

var caster: Player
var damage: float = 0.0
var critical: bool = false
var flight: float = 0.6
var size: float = 1.0
## Only drawn ([method DarkSkills.warm]): it hurts nothing and shakes nothing.
var dummy := false

var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _age: float = 0.0
var _rock: MeshInstance3D
var _rock_mat: ShaderMaterial
var _spin := Vector3.ZERO
var _warn: Decal
var _trail: Array[GPUParticles3D] = []
var _light: OmniLight3D
var _streak: MeshInstance3D
var _struck := false
var _quarry: Node3D


## A comet from `from` down to `to`, striking `seconds` later.
static func fall(into: Node, from: Vector3, to: Vector3, seconds: float, by: Player, hurt: float,
		crit: bool, which: int, scale_k: float = 1.0) -> DarkComet:
	if into == null:
		return null
	var c := DarkComet.new()
	c._from = from
	c._to = to
	c.flight = seconds
	c.caster = by
	c.damage = hurt
	c.critical = crit
	c.size = scale_k
	c.set_meta(&"which", which)
	into.add_child(c)
	c.global_position = from
	return c


func _ready() -> void:
	var into := get_parent()
	_rock = MeshInstance3D.new()
	_rock.mesh = DarkFx.rock_mesh(int(get_meta(&"which", 0)))
	_rock_mat = DarkFx.rock_material()
	_rock.material_override = _rock_mat
	_rock.scale = Vector3.ONE * 1.5 * size
	add_child(_rock)
	_spin = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized() * randf_range(5.0, 9.0)
	_light = OmniLight3D.new()
	_light.light_color = DarkFx.VOID
	_light.light_energy = 2.0
	_light.omni_range = 7.0
	add_child(_light)
	_light.position = Vector3.UP * 1.5 * size
	# its tail: black fire, violet fire and smoke, left behind in the air
	var way := (_to - _from).normalized()
	var back := -way
	_trail.append(SkillFx.particles(self, global_position, {"amount": 90, "life": 0.7,
			"speed": Vector2(0.3, 1.2), "dir": back, "spread": 25.0, "sphere": 0.55 * size,
			"size": Vector2(1.1, 1.8) * size, "grow": 0.5, "add": true, "tex": DarkFx.FLAME, "spin": true,
			"colors": [Color(DarkFx.VOID, 0.0), Color(DarkFx.VOID, 0.55), Color(DarkFx.VOID, 0.3), Color(DarkFx.VOID, 0.0)]}))
	_trail.append(SkillFx.particles(self, global_position, {"amount": 90, "life": 1.0,
			"speed": Vector2(0.4, 1.4), "dir": back, "spread": 30.0, "sphere": 0.6 * size,
			"size": Vector2(1.3, 2.2) * size, "grow": 0.7, "add": false, "tex": DarkFx.FLAME, "spin": true,
			"colors": [Color(DarkFx.INK, 0.0), Color(DarkFx.INK, 0.95), Color(0.08, 0.03, 0.1, 0.6), Color(0.1, 0.05, 0.12, 0.0)]}))
	_trail.append(SkillFx.particles(self, global_position, {"amount": 60, "life": 2.2,
			"speed": Vector2(0.2, 0.8), "dir": back, "spread": 40.0, "sphere": 0.7 * size,
			"size": Vector2(1.5, 2.6) * size, "grow": 1.0, "add": false, "tex": DarkFx.PUFF, "spin": true,
			"colors": [Color(0.05, 0.02, 0.07, 0.0), Color(0.06, 0.03, 0.08, 0.55), Color(0.1, 0.07, 0.12, 0.0)]}))
	_trail.append(SkillFx.particles(self, global_position, {"amount": 50, "life": 0.7,
			"speed": Vector2(1.0, 3.0), "dir": back, "spread": 50.0, "sphere": 0.3 * size,
			"size": Vector2(0.03, 0.06), "grow": 0.2, "gravity": Vector3(0, -2, 0),
			"colors": [Color(1, 1, 1, 1), Color(DarkFx.HOT, 1.0), Color(DarkFx.VOID, 0.0)]}))
	# the black drawn over the violet
	_trail[1].sorting_offset = 1.0
	# a streak of violet fire behind it, along the way it goes
	_streak = MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.55 * size
	cone.height = STREAK * size
	cone.radial_segments = 10
	cone.rings = 1
	cone.cap_bottom = false
	_streak.mesh = cone
	var m := SkillFx.glow(DarkFx.VOID, 2.5, true, 0.5)
	var fade := GradientTexture2D.new()
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0.0))
	g.set_color(1, Color(1, 1, 1, 1.0))
	fade.gradient = g
	fade.fill_from = Vector2(0.0, 0.0)
	fade.fill_to = Vector2(0.0, 1.0)
	fade.width = 4
	fade.height = 64
	m.albedo_texture = fade
	_streak.material_override = m
	_streak.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_streak)
	# its point back along the way it came, its base at the rock
	var side := way.cross(Vector3.UP)
	if side.length_squared() < 0.0001:
		side = Vector3.RIGHT
	side = side.normalized()
	_streak.basis = Basis(side, -way, side.cross(-way)).orthonormalized()
	_streak.position = -way * STREAK * size * 0.5
	# where it will strike: a ring of violet burning on the ground, tightening
	_warn = DarkFx.decal(into, _to, DarkFx.SHOCK, REACH * 2.6, Color(DarkFx.VOID, 0.0), 1.4, 0.0)
	_place()


## Follows `who` as it falls ([constant HOME]).
func chase(who: Node3D) -> void:
	_quarry = who


func _process(delta: float) -> void:
	_age += delta
	if _struck:
		return
	var t := clampf(_age / flight, 0.0, 1.0)
	if _quarry != null and t < HOME:
		if not is_instance_valid(_quarry) or _quarry.get(&"is_dead") == true:
			_quarry = null
		else:
			var at := _quarry.global_position
			_to = Vector3(at.x, at.y, at.z)
			if is_instance_valid(_warn):
				_warn.global_position = _to + Vector3.UP * 0.15
	if is_instance_valid(_warn):
		_warn.modulate.a = minf(t * 2.5, 1.0) * 0.9
		var w := REACH * lerpf(2.6, 2.0, t)
		_warn.size = Vector3(w, 0.9, w)
		_warn.rotation.y += delta * 2.0
	_rock.rotate(_spin.normalized(), _spin.length() * delta)
	_place()
	if t >= 1.0:
		_strike()


## Where it is: along the way, gathering pace as it comes.
func _place() -> void:
	var t := clampf(_age / flight, 0.0, 1.0)
	global_position = _from.lerp(_to, pow(t, 1.25))


func _strike() -> void:
	_struck = true
	var into := get_parent()
	var at := _to
	# what it leaves in the air goes on fading where it is
	for p in _trail:
		if is_instance_valid(p):
			p.emitting = false
			p.reparent(into)
			p.get_tree().create_timer(p.lifetime + 0.3, false).timeout.connect(p.queue_free)
	if is_instance_valid(_warn):
		_warn.queue_free()
	if multiplayer.is_server() and not dummy:
		_hurt(at)
	# the flash and the light of it
	SkillFx.flash(into, at + Vector3.UP * 0.5, DarkFx.VOID, 0.9 * size, 0.16, 3.0)
	SkillFx.light(into, at + Vector3.UP * 1.2, DarkFx.VOID, 5.0, 12.0, 0.6)
	# the ground: cracked and burnt black, cracks glowing and cooling
	var crack := DarkFx.decal(into, at, DarkFx.CRACK, REACH * 1.6 * size, Color(DarkFx.VOID, 1.0), 1.3, 0.85)
	crack.rotation.y = randf() * TAU
	var tw := crack.create_tween()
	tw.tween_property(crack, "emission_energy", 0.0, 2.2).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(crack, "modulate:a", 0.0, 6.0).set_ease(Tween.EASE_IN)
	tw.tween_callback(crack.queue_free)
	var scorch := DarkFx.decal(into, at, DarkFx.PUFF, REACH * 1.9 * size, Color(0.03, 0.01, 0.04, 0.9), 0.0, 1.0)
	var tw2 := scorch.create_tween()
	tw2.tween_interval(3.0)
	tw2.tween_property(scorch, "modulate:a", 0.0, 3.0)
	tw2.tween_callback(scorch.queue_free)
	# a ring thrown out over the ground
	var shock := DarkFx.decal(into, at, DarkFx.SHOCK, 1.0, Color(DarkFx.VOID, 1.0), 2.5, 0.0)
	var tw3 := shock.create_tween().set_parallel(true)
	tw3.tween_property(shock, "size", Vector3(REACH * 3.2, 0.9, REACH * 3.2), 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw3.tween_property(shock, "modulate:a", 0.0, 0.45).set_ease(Tween.EASE_IN)
	tw3.chain().tween_callback(shock.queue_free)
	SkillFx.ring(into, at + Vector3.UP * 0.25, Vector3.UP, DarkFx.VOID, 0.5, REACH * 1.6, 0.4, 0.04, 3.0)
	# stone, smoke, sparks and the fire left burning
	_debris(into, at)
	DarkFx.smoke(into, at + Vector3.UP * 0.4, 12, 2.0 * size, 2.0, 2.2, 0.8)
	DarkFx.embers(into, at + Vector3.UP * 0.3, 40, Vector2(3.0, 8.0), 1.1, 70.0)
	DarkFx.black_fire(into, at + Vector3.UP * 0.05, 0.0, 1.6 * size, {"box": Vector3(0.6, 0.1, 0.6), "rate": 1.4})
	DarkFx.black_fire(into, at + Vector3.UP * 0.05, 2.4, 0.9 * size, {"ring": Vector2(0.2, 1.3 * size), "rate": 1.3})
	GroundFx.eruption(into, at, 0.6 * size)
	if not dummy:
		WindBlast.shake(self, 0.14, 0.35, 26.0)
	queue_free()


## Shards of its stone flung out, falling back.
func _debris(into: Node, at: Vector3) -> void:
	var p := GPUParticles3D.new()
	p.amount = 16
	p.lifetime = 1.2
	p.one_shot = true
	p.explosiveness = 1.0
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 55.0
	pm.initial_velocity_min = 4.0
	pm.initial_velocity_max = 9.0
	pm.gravity = Vector3(0, -16, 0)
	pm.scale_min = 0.12 * size
	pm.scale_max = 0.3 * size
	pm.angular_velocity_min = -400.0
	pm.angular_velocity_max = 400.0
	pm.angle_min = -180.0
	pm.angle_max = 180.0
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.4
	pm.particle_flag_rotate_y = true
	p.process_material = pm
	p.draw_pass_1 = DarkFx.chip_mesh()
	p.material_override = _rock_mat
	into.add_child(p)
	p.global_position = at + Vector3.UP * 0.3
	p.emitting = true
	p.get_tree().create_timer(p.lifetime + 0.3, false).timeout.connect(p.queue_free)


## The host: everyone within `REACH` takes it, less at the edge; what it falls
## right on is thrown down.
func _hurt(at: Vector3) -> void:
	for who in _foes():
		var off := who.global_position - at
		off.y = 0.0
		var br: Variant = who.get(&"body_radius")
		var r := float(br) if br != null else 0.4
		var d := maxf(off.length() - r * 0.6, 0.0)
		if d > REACH or absf(who.global_position.y - at.y) > 3.0:
			continue
		var worth := damage * lerpf(1.0, EDGE, clampf(d / REACH, 0.0, 1.0))
		var away := off.normalized() if off.length_squared() > 0.0001 else Vector3.FORWARD
		if who is Player:
			if who.get("net_dead") != true:
				who.call(&"receive_blow", worth, caster if is_instance_valid(caster) else self,
						0, 2, get_instance_id() % 100000, true)
			continue
		if who.has_method(&"take_hit"):
			who.call(&"take_hit", worth, who.global_position + Vector3.UP * 0.8, away + Vector3.UP * 0.6,
					critical, false, caster, true)
		if d <= SQUARE and who.has_method(&"react"):
			who.call(&"react", &"knock", caster, away * 3.0)


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
