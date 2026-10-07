class_name FrostTrail
extends Node3D

## What the elf's Frost Step leaves on the ground (the user's word,
## 2026-10-07): the ground freezing under her as she glides, from where she
## pushed off to where she stopped, a strip of frost with ice crystals
## standing up out of it and a cold mist low over it, for `seconds` after. Whatever crosses it is chilled ([Afflictions] "chill") for
## `CHILL` after it leaves: slowed to [constant Afflictions.CHILL_SPEED].
## A creature always; a hero only one she is hostile to (PvP).
##
## Made on every peer from the same numbers ([method MageSkills.show_frost_step]),
## each chilling what crosses it there; only the body's own peer slows it
## ([method Afflictions._physics_process]). Afterwards the crystals sink and
## the frost fades.

const ICE := Color(0.62, 0.9, 1.0)
const ICE_HOT := Color(0.9, 0.98, 1.0)
## How long anything that crossed stays slow, after it is off the frost.
const CHILL := 5.0
## Half the strip's width.
const HALF := 0.85
## Crystals a metre of the strip.
const CRYSTALS := 2.6
## How fast the frost runs along it when no glide is given (m/s).
const RUN := 60.0
## How often the frost sprays off her feet as she glides.
const SPRAY_EVERY := 0.035
const FADE := 1.5

var seconds: float = 6.0

var _caster: Node3D
var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _way := Vector3.FORWARD
## Her glide: its first pace, how long, and the share of the pace it ends at.
var _v0: float = 0.0
var _glide: float = 0.0
var _ease: float = 1.0
## How far along she stopped, if short ([method cut]).
var _cut: float = INF
var _spray: float = 0.0
var _arrived := false
var _age: float = 0.0
var _tick: float = 0.0
var _caught: Dictionary = {}
var _crystals: Array[Node3D] = []
var _sizes: Array[float] = []
var _mist: GPUParticles3D
var _motes: GPUParticles3D
var _decal: Decal

static var _frost_tex: Texture2D = null


func start(caster: Node3D, from: Vector3, to: Vector3, last: float, v0: float = 0.0,
		glide: float = 0.0, ease: float = 1.0) -> void:
	_caster = caster
	_from = from
	_to = to
	seconds = last
	_v0 = v0
	_glide = glide
	_ease = ease
	global_position = (from + to) * 0.5
	_build()


## Every peer: she stopped at `at` (her glide ended there): the frost goes no
## further.
func cut(at: Vector3) -> void:
	var along := Vector2(at.x - _from.x, at.z - _from.z).dot(Vector2(_way.x, _way.z))
	_cut = clampf(along, 0.3, _length())
	for i in _crystals.size():
		var c := _crystals[i]
		if is_instance_valid(c) and float(c.get_meta(&"at")) > _cut + 0.2:
			c.queue_free()


## How far along the frost has run: where she is in her glide.
func _front() -> float:
	var run := _age * RUN
	if _glide > 0.0:
		var t := minf(_age, _glide)
		run = _v0 * (t - (1.0 - _ease) * t * t / (2.0 * _glide))
		if _age >= _glide:
			run = INF
	return minf(run, minf(_length(), _cut))


## How long the frost lasts: its seconds after she is done gliding.
func _lasts() -> float:
	return seconds + _glide


func _length() -> float:
	return Vector2(_to.x - _from.x, _to.z - _from.z).length()


func _build() -> void:
	var length := maxf(_length(), 0.5)
	var way := _to - _from
	way.y = 0.0
	way = way.normalized() if way.length_squared() > 0.0001 else Vector3.FORWARD
	_way = way
	var yaw := atan2(way.x, way.z)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector3i(roundi(_from.x * 10.0), roundi(_from.z * 10.0), roundi(_to.x * 10.0)))

	# the frost itself, laid on whatever ground there is
	_decal = Decal.new()
	# shallow, so it frosts the ground and the feet, not whoever stands on it
	_decal.size = Vector3(HALF * 2.6, 0.9, length + HALF * 1.6)
	_decal.texture_albedo = _frost_texture()
	_decal.modulate = Color(0.85, 0.95, 1.0, 0.0)
	_decal.albedo_mix = 1.0
	_decal.upper_fade = 0.6
	_decal.lower_fade = 0.3
	add_child(_decal)
	_decal.global_position = (_from + _to) * 0.5 + Vector3.UP * 0.1
	_decal.global_rotation = Vector3(0.0, yaw, 0.0)

	# ice crystals standing up out of it, leaning every way, bigger in the
	# middle of the strip
	var count := int(ceil(length * CRYSTALS)) + 2
	for i in count:
		var t := (float(i) + rng.randf_range(0.0, 0.8)) / float(count)
		var across := rng.randf_range(-1.0, 1.0)
		across = signf(across) * pow(absf(across), 0.7) * HALF * 0.9
		var side := way.cross(Vector3.UP)
		var at := _from.lerp(_to, t) + side * across
		at.y = _ground_y(at)
		var tall := rng.randf_range(0.3, 0.75) * (1.0 - absf(across) / HALF * 0.45)
		var c := IceShard.spike(tall, tall * 0.2, 1.3)
		add_child(c)
		c.global_position = at
		c.global_rotation = Vector3(rng.randf_range(-0.55, 0.55), rng.randf_range(-PI, PI), rng.randf_range(-0.55, 0.55))
		c.scale = Vector3.ONE * 0.01
		c.visible = false
		c.set_meta(&"at", t * length)
		_crystals.append(c)
		_sizes.append(rng.randf_range(0.8, 1.15))

	# a cold mist low over the strip, and motes of frost glinting in it
	var box := Vector3(HALF, 0.12, length * 0.5)
	_mist = SkillFx.particles(self, global_position + Vector3.UP * 0.15, {
		"amount": int(clampf(length * 5.0, 8.0, 48.0)), "life": 1.8, "speed": Vector2(0.05, 0.25),
		"dir": Vector3.UP, "spread": 70.0, "gravity": Vector3(0, 0.04, 0), "damping": 0.3,
		"size": Vector2(0.5, 0.9), "box": box, "add": false, "grow": 0.5,
		"colors": [Color(0.9, 0.96, 1.0, 0.0), Color(0.88, 0.95, 1.0, 0.22), Color(0.85, 0.93, 1.0, 0.0)],
	})
	_mist.rotation.y = yaw
	_motes = SkillFx.particles(self, global_position + Vector3.UP * 0.3, {
		"amount": int(clampf(length * 4.0, 6.0, 32.0)), "life": 1.2, "speed": Vector2(0.05, 0.3),
		"spread": 180.0, "gravity": Vector3(0, -0.1, 0), "size": Vector2(0.02, 0.04),
		"box": Vector3(HALF, 0.3, length * 0.5),
		"colors": [Color(ICE_HOT, 0.0), Color(ICE_HOT, 1.0), Color(ICE, 0.0)],
	})
	_motes.rotation.y = yaw
	# gliding, the mist rises once she is over it all
	if _glide > 0.0:
		_mist.emitting = false
		_motes.emitting = false
	_shape_decal(0.3 if _glide > 0.0 else _length())


## The frost laid as far as `along`.
func _shape_decal(along: float) -> void:
	along = maxf(along, 0.3)
	_decal.size = Vector3(HALF * 2.6, 0.9, along + HALF * 1.6)
	var mid := _from + _way * (along * 0.5)
	mid.y = lerpf(_from.y, _to.y, along / maxf(_length(), 0.01))
	_decal.global_position = mid + Vector3.UP * 0.1


func _ground_y(at: Vector3) -> float:
	var space := get_world_3d().direct_space_state if is_inside_tree() else null
	if space == null:
		return at.y
	var mask := 1
	if _caster is CollisionObject3D:
		mask = (_caster as CollisionObject3D).collision_mask
	var skip: Array[RID] = []
	if _caster is CollisionObject3D:
		skip.append((_caster as CollisionObject3D).get_rid())
	var q := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 1.2, at + Vector3.DOWN * 2.0, mask, skip)
	var hit := space.intersect_ray(q)
	return float((hit["position"] as Vector3).y) if not hit.is_empty() else at.y


func _process(delta: float) -> void:
	_age += delta
	var on := _age < _lasts()
	var front := _front()
	var melt := clampf((_age - _lasts()) / FADE, 0.0, 1.0)
	if not _arrived:
		_shape_decal(front)
		_glide_spray(front, delta)
	for i in _crystals.size():
		var c := _crystals[i]
		if not is_instance_valid(c):
			continue
		var at := float(c.get_meta(&"at"))
		if front < at:
			continue
		if not c.has_meta(&"t0"):
			c.set_meta(&"t0", _age)
		var since := _age - float(c.get_meta(&"t0"))
		c.visible = true
		var grow := clampf(since / 0.12, 0.0, 1.0)
		# out quick, a little past, and settled
		var k := grow * (1.0 + 0.25 * sin(clampf(since / 0.25, 0.0, 1.0) * PI))
		c.scale = Vector3.ONE * maxf(_sizes[i] * k * (1.0 - melt), 0.001)
	var in_k := clampf(_age / 0.15, 0.0, 1.0)
	_decal.modulate.a = in_k * (1.0 - melt) * 0.95
	if on:
		_catch(delta)
	elif _mist.emitting:
		_mist.emitting = false
		_motes.emitting = false
	if melt >= 1.0 and _age > _lasts() + FADE + 1.9:
		queue_free()


## As she glides: ice spraying off her feet at the front of the frost, and,
## once she is done, the mist rising over the whole of it.
func _glide_spray(front: float, delta: float) -> void:
	var done := front >= minf(_length(), _cut) - 0.01 or (_glide > 0.0 and _age >= _glide)
	var into := get_parent()
	if into == null:
		return
	var at := _from + _way * front
	at.y = _ground_y(at) + 0.08
	if done:
		_arrived = true
		_shape_decal(front)
		if _glide > 0.0:
			_mist.emitting = true
			_motes.emitting = true
			SkillFx.ring(into, at, Vector3.UP, ICE_HOT, 0.25, 1.4, 0.35, 0.04, 2.0)
			SkillFx.burst(into, at + Vector3.UP * 0.1, ICE, 16, Vector2(0.8, 2.6), Vector3.UP, 80.0,
					Vector2(0.02, 0.05), Vector3(0, -5, 0), 0.5)
		return
	if _glide <= 0.0:
		return
	_spray -= delta
	if _spray > 0.0:
		return
	_spray = SPRAY_EVERY
	# chips of ice kicked up and back off her feet, and a breath of snow
	var back := -_way + Vector3.UP * 0.8
	SkillFx.burst(into, at, ICE_HOT, 6, Vector2(1.0, 3.2), back.normalized(), 40.0, Vector2(0.015, 0.04),
			Vector3(0, -6, 0), 0.4)
	SkillFx.particles(into, at + Vector3.UP * 0.1, {"amount": 3, "life": 0.7, "one_shot": true, "explosiveness": 1.0,
			"speed": Vector2(0.2, 0.7), "dir": back.normalized(), "spread": 60.0, "size": Vector2(0.3, 0.55),
			"add": false, "grow": 0.7, "box": Vector3(0.25, 0.05, 0.25),
			"colors": [Color(0.92, 0.97, 1.0, 0.0), Color(0.9, 0.96, 1.0, 0.3), Color(0.9, 0.95, 1.0, 0.0)]})


## Everything crossing it is chilled, and goes on being while it stays on it.
func _catch(delta: float) -> void:
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = 0.15
	for who in _crossers():
		var gap := _gap_to(who.global_position)
		var br: Variant = who.get(&"body_radius")
		if gap.y > 2.0 or gap.x > HALF + (float(br) if br != null else 0.4) * 0.5:
			continue
		var marks := Afflictions.of(who)
		if marks == null:
			continue
		var fresh := not marks.is_chilled()
		marks.apply(&"chill", CHILL, _caster)
		if fresh or not _caught.has(who):
			_caught[who] = true
			var into := get_parent()
			var feet := who.global_position + Vector3.UP * 0.2
			SkillFx.burst(into, feet, ICE, 14, Vector2(0.6, 2.0), Vector3.UP, 70.0, Vector2(0.02, 0.05),
					Vector3(0, -4, 0), 0.5)
			SkillFx.ring(into, feet - Vector3.UP * 0.15, Vector3.UP, ICE_HOT, 0.2, 1.1, 0.35, 0.04, 2.0)


## Who may be chilled: the creatures, and the heroes she is hostile to.
func _crossers() -> Array[Node3D]:
	var out: Array[Node3D] = []
	for node in get_tree().get_nodes_in_group(&"enemy"):
		var who := node as Node3D
		if who != null and who.get(&"is_dead") != true:
			out.append(who)
	if _caster is Player and Player.pvp_mode:
		for node in get_tree().get_nodes_in_group(&"player"):
			if (_caster as Player).is_hostile_to(node):
				out.append(node as Node3D)
	return out


## How far `p` is off the strip: across it (x), and up or down from it (y).
func _gap_to(p: Vector3) -> Vector2:
	var a := Vector2(_from.x, _from.z)
	var b := Vector2(_to.x, _to.z)
	var q := Vector2(p.x, p.z)
	var ab := b - a
	var reach := clampf(_front() / maxf(_length(), 0.01), 0.0, 1.0)
	var t := 0.0 if ab.length_squared() < 0.0001 else clampf((q - a).dot(ab) / ab.length_squared(), 0.0, reach)
	var near := a + ab * t
	var y := lerpf(_from.y, _to.y, t)
	return Vector2(q.distance_to(near), absf(p.y - y))


## The frost, made once: white-blue, ragged along both edges and both ends,
## with fine cracks through it.
static func _frost_texture() -> Texture2D:
	if _frost_tex == null:
		var n := FastNoiseLite.new()
		n.frequency = 0.06
		n.fractal_octaves = 3
		var cr := FastNoiseLite.new()
		cr.noise_type = FastNoiseLite.TYPE_CELLULAR
		cr.frequency = 0.05
		cr.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
		var w := 64
		var h := 256
		var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
		for y in h:
			for x in w:
				var u := absf(float(x) / float(w - 1) * 2.0 - 1.0)
				var v := absf(float(y) / float(h - 1) * 2.0 - 1.0)
				var ragged := n.get_noise_2d(x * 2.0, y * 0.7) * 0.9
				var edge := clampf((0.85 - u * 1.25 + ragged) * 1.8, 0.0, 1.0) \
						* clampf((1.0 - v + ragged * 0.5) * 3.0, 0.0, 1.0)
				var patch := n.get_noise_2d(x * 4.0 + 40.0, y * 3.0) * 0.5 + 0.5
				var crack := 1.0 - smoothstep(0.0, 0.1, absf(cr.get_noise_2d(x * 3.0, y * 1.5)))
				# and nothing at all at the border, whatever the noise did
				edge *= smoothstep(1.0, 0.82, u) * smoothstep(1.0, 0.9, v)
				var a := edge * (0.25 + 0.55 * patch) + crack * edge * 0.35
				var c := Color(0.7, 0.86, 1.0).lerp(Color(0.95, 0.98, 1.0), patch).lerp(Color(1, 1, 1), crack)
				img.set_pixel(x, y, Color(c.r, c.g, c.b, clampf(a, 0.0, 1.0)))
		img.generate_mipmaps()
		_frost_tex = ImageTexture.create_from_image(img)
	return _frost_tex
