class_name SpellBolt
extends Arrow

## The mage's bolt: a ball of light with lightning crackling off the back of it
## (`assets/magic-person/magic-attack/skill1.glb`).
##
## An [Arrow] in what matters — the same sweep from one tick to the next so
## nothing fast tunnels through it, the same `take_hit()` on whatever it meets,
## the same launch from the controller — and its own thing in how it flies:
##
## * **It gathers pace over the whole flight.** It leaves the staff's crystal
##   at a walk, a small light swelling to full size, and speeds up all the way
##   to what it was thrown at, reaching full speed only near the end — over
##   `ramp_share` of the distance to its quarry, or `ramp_distance` when it has
##   none. Slowly at first and harder towards the end, so the throw reads as a
##   spell let go of and building rather than a shot fired.
## * **A tail of light** ([GlowTail]) runs behind it — hot white at the head
##   cooling to gold, as long as it is fast — with two fine strands winding
##   round it and embers shed along the way.
## * **It hunts what it was thrown at.** A bolt thrown with something locked
##   bends towards it as it flies, as hard as `steer` lets it — a thing walking
##   or running on across the line is followed and hit.
## * **It can be dodged.** A quarry that rolls, dashes or sidesteps — anything
##   that says `is_evading()`, or breaks sideways off the way it was going
##   faster than `dodge_kick` — shakes it off. From then on the bolt flies
##   straight, and it goes through a body that is rolling out of its way.
## * **It does not come round again.** The moment it is past what it was thrown
##   at, hit or not, it fades out where it is. Without a quarry it fades at
##   the end of its `reach`.
##
## Where it strikes it bursts in a flash and is gone instead of sticking.

const MODEL := "res://assets/magic-person/magic-attack/skill1.glb"
## The model's orb is 1.24 across its radius; this makes it a hand's width.
const MODEL_SCALE := 0.14

## How long the burst lasts.
@export var burst_time: float = 0.3
@export var glow_colour: Color = Color(1.0, 0.82, 0.38)
## It leaves the staff at this share of its full speed...
@export var start_share: float = 0.3
## ...and reaches full speed this far into the way to its quarry...
@export_range(0.3, 1.0) var ramp_share: float = 0.9
## ...or this many metres out, thrown at nothing — never less than
## `ramp_min` nor more than `ramp_max`.
@export var ramp_distance: float = 16.0
@export var ramp_min: float = 8.0
@export var ramp_max: float = 40.0
## Above 1 the pace comes on late: most of it in the last part of the ramp.
@export var ramp_curve: float = 1.3
## The strands that wind round the tail: how far out, and how fast they turn.
@export var strand_radius: float = 0.16
@export var strand_turns: float = 2.2
## How hard it can bend towards its quarry: the most it may be pushed sideways,
## in m/s². Slow, just off the staff, that is a tight curve; at full speed it
## is a gentle one, which is what leaves a dodge room to work.
@export var steer: float = 36.0
## A quarry whose velocity jumps sideways off the bolt's line by more than this
## (m/s) against what it was doing a moment ago has got out of the way.
@export var dodge_kick: float = 4.0
## How far it goes before it has spent itself, in metres.
@export var reach: float = 70.0
## How long the fading out takes.
@export var fade_out: float = 0.22

var _model: Node3D
var _light: OmniLight3D
var _flicker: float = 0.0
## Full speed, and which way it is going.
var _top_speed: float = 0.0
var _heading: Vector3 = Vector3.FORWARD
var _travelled: float = 0.0
## What it was thrown at, whether it is still after it, and whether it has
## been ahead of it yet (a bolt thrown from beside its quarry has not).
var _quarry: Node3D
var _hunting: bool = false
var _was_ahead: bool = false
## The quarry's recent velocity, smoothed: a dodge is a break from it.
var _quarry_pace: Vector3 = Vector3.ZERO
var _fading: bool = false
## The distance over which it gathers pace, worked out on its first tick —
## the quarry is handed over after the launch.
var _ramp: float = 0.0
var _tails: Array[GlowTail] = []
## Where it was at the last physics tick, so what is drawn can be placed
## between ticks rather than jumping from one to the next.
var _prev_at: Vector3 = Vector3.ZERO
var _placed: bool = false
var _embers: GPUParticles3D


func _ready() -> void:
	super()
	streak_tint = Color(1.0, 0.86, 0.45, 0.8)
	wake_tint = Color(1.0, 0.75, 0.3, 0.22)
	crit_tint = Color(1.0, 0.95, 0.75, 0.9)
	# The arrow's flat bands are not used: the bolt lays its own tail.
	trail_width = 0.0
	# It does not roll. A spinning orb with a crackling tail read as a thing
	# tumbling, not a thing thrown.
	spin = 0.0
	bite = 0.0
	if ResourceLoader.exists(MODEL):
		_model = (load(MODEL) as PackedScene).instantiate() as Node3D
		# The orb leads: its tail runs off down the model's +Z, the flight is
		# this node's +Y.
		_model.rotation = Vector3(PI * 0.5, 0.0, 0.0)
		_model.scale = Vector3.ONE * MODEL_SCALE * 0.3
		add_child(_model)
		var glow := StandardMaterial3D.new()
		glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		glow.albedo_color = glow_colour
		glow.emission_enabled = true
		glow.emission = glow_colour
		glow.emission_energy_multiplier = 2.5
		for node in _model.find_children("*", "MeshInstance3D", true, false):
			(node as MeshInstance3D).material_override = glow
			(node as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_light = OmniLight3D.new()
	_light.light_color = glow_colour
	_light.light_energy = 3.5
	_light.omni_range = 4.5
	add_child(_light)


## As an arrow's, and then held back to the walk it leaves the staff at.
func launch(velocity: Vector3, damage: float, critical: bool, gravity: float,
		shooter: Node3D) -> void:
	_top_speed = velocity.length()
	_heading = velocity.normalized() if _top_speed > 0.001 else Vector3.FORWARD
	super(_heading * _top_speed * start_share, damage, critical, gravity, shooter)


## Sets it after `who`. Null, or never called, and it flies straight.
func hunt(who: Node3D) -> void:
	_quarry = who
	_hunting = who != null
	_was_ahead = false
	var pace: Variant = who.get("velocity") if who != null else null
	_quarry_pace = pace if pace is Vector3 else Vector3.ZERO


## Whether it is still bending towards its quarry.
func is_hunting() -> bool:
	return _hunting


## The pace it is at now, in m/s.
func speed() -> float:
	return _velocity.length()


func _process(delta: float) -> void:
	if _spent or _fading:
		return
	# Swells from a spark at the crystal to its full size as it gathers pace,
	# and breathes a little once it is there.
	_flicker += delta * 30.0
	# Drawn where it is between two ticks, not where the last one left it: at
	# forty metres a second a tick is most of a metre, and a thing that jumps
	# that far each tick is seen to judder.
	if _placed and _model != null:
		var between := _prev_at.lerp(global_position, Engine.get_physics_interpolation_fraction())
		_model.global_position = between
		if _light != null:
			_light.global_position = between
	var grown := clampf(_ramp_through() / 0.45, 0.0, 1.0)
	grown = 1.0 - (1.0 - grown) * (1.0 - grown)
	var breath := 1.0 + 0.07 * sin(_flicker * 0.45)
	if _model != null:
		_model.scale = Vector3.ONE * MODEL_SCALE * lerpf(0.3, 1.0, grown) * breath
	if _light != null:
		# A crackle rather than a steady lamp, bright as it leaves.
		_light.light_energy = lerpf(3.5, 2.0, grown) + 0.6 * sin(_flicker) * sin(_flicker * 0.37)


func _physics_process(delta: float) -> void:
	if _spent or _fading:
		return
	_age += delta
	if _age > lifetime or _travelled > reach:
		_fade()
		return

	if _ramp <= 0.0:
		_ramp = ramp_distance
		if _quarry != null and is_instance_valid(_quarry):
			_ramp = global_position.distance_to(_mark(_quarry)) * ramp_share
		_ramp = clampf(_ramp, ramp_min, ramp_max)
	_prev_at = global_position
	_placed = true
	# Slowly and then harder: the pace follows the way through the ramp raised
	# to `ramp_curve`, so full speed comes towards the end.
	var pace := _top_speed * lerpf(start_share, 1.0, pow(_ramp_through(), ramp_curve))

	if _quarry != null:
		if not is_instance_valid(_quarry) or not _quarry.is_inside_tree():
			_quarry = null
			_hunting = false
		else:
			var to_it := _mark(_quarry) - global_position
			if to_it.dot(_heading) < 0.0:
				# Gone by. It does not turn round for another go.
				if _was_ahead:
					_fade()
					return
			else:
				_was_ahead = true
			if _hunting and _got_away(_quarry, delta):
				_hunting = false
			if _hunting and _was_ahead and to_it.length_squared() > 0.0001:
				var most := minf(steer / maxf(pace, 1.0), 8.0) * delta
				_heading = _turn(_heading, to_it.normalized(), most)

	if _gravity > 0.0:
		_heading = (_heading * pace + Vector3.DOWN * _gravity * delta).normalized()
	_velocity = _heading * pace
	_roll += TAU * spin * delta
	var step := _velocity * delta
	var from := global_position
	var hit := _sweep(from, from + step)
	# A body rolling out of the way is not there to be hit: the bolt goes on
	# through where it was.
	var through_them: Array[RID] = []
	while not hit.is_empty() and _is_evading(hit["collider"] as Node3D) and through_them.size() < 3:
		through_them.append((hit["collider"] as CollisionObject3D).get_rid())
		hit = _sweep_past(from, from + step, through_them)
	if hit.is_empty():
		global_position += step
		_travelled += step.length()
		_point_along(_heading)
		_feed_tails()
		return
	global_position = hit["position"] as Vector3
	_strike(hit["collider"] as Node3D, hit["position"] as Vector3)


## How far through its ramp to full speed it is, 0 to 1.
func _ramp_through() -> float:
	if _ramp <= 0.0:
		return 0.0
	return clampf(_travelled / _ramp, 0.0, 1.0)


## The tail: a hot core, a wider soft glow round it, and two fine strands that
## wind round both. All of them are fed the head's position each frame.
func _lay_trail() -> void:
	var into := get_parent()
	if into == null:
		return
	_tails.append(_tail(into, 0.55, 0.26, 1.3, Color(1.0, 0.78, 0.35, 0.5), Color(1.0, 0.4, 0.06, 0.0)))
	_tails.append(_tail(into, 0.14, 0.36, 1.6, Color(1.0, 0.96, 0.8, 1.0), Color(1.0, 0.55, 0.12, 0.0)))
	for i in 2:
		_tails.append(_tail(into, 0.035, 0.3, 0.7, Color(1.0, 0.92, 0.7, 0.95), Color(1.0, 0.6, 0.2, 0.0)))
	# The glow and the core are joined to the orb itself between ticks; the
	# strands wind round the line and are left to their own samples.
	for i in 2:
		_tails[i].head = _model if _model != null else self
	_embers = _make_embers()
	add_child(_embers)


func _tail(into: Node, across: float, seconds: float, shape: float, head: Color,
		tail: Color) -> GlowTail:
	var t := GlowTail.new()
	t.width = across
	t.life = seconds
	t.taper = shape
	t.head_colour = head
	t.tail_colour = tail
	into.add_child(t)
	t.global_position = Vector3.ZERO
	return t


## Sparks shed along the way: they fall back off the bolt and cool as they go.
func _make_embers() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = "Embers"
	p.amount = 70
	p.lifetime = 0.55
	p.local_coords = false
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = 0.06
	m.direction = Vector3.UP
	m.spread = 180.0
	m.initial_velocity_min = 0.3
	m.initial_velocity_max = 1.4
	m.gravity = Vector3(0.0, -2.5, 0.0)
	m.damping_min = 1.0
	m.damping_max = 3.0
	m.scale_min = 0.5
	m.scale_max = 1.2
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.97, 0.85, 1.0))
	ramp.set_color(1, Color(1.0, 0.4, 0.05, 0.0))
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	m.color_ramp = ramp_tex
	p.process_material = m
	var dot := QuadMesh.new()
	dot.size = Vector2(0.07, 0.07)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	var disc := GradientTexture2D.new()
	disc.fill = GradientTexture2D.FILL_RADIAL
	disc.fill_from = Vector2(0.5, 0.5)
	disc.fill_to = Vector2(1.0, 0.5)
	var fall := Gradient.new()
	fall.set_color(0, Color(1, 1, 1, 1))
	fall.set_color(1, Color(1, 1, 1, 0))
	disc.gradient = fall
	disc.width = 32
	disc.height = 32
	mat.albedo_texture = disc
	dot.material = mat
	p.draw_pass_1 = dot
	p.emitting = true
	return p


## Feeds the tails where the head is now. The strands are offset round the
## line of flight, turning as it goes, so what they leave behind is a helix.
func _feed_tails() -> void:
	if _tails.is_empty():
		return
	var head := global_position
	var ahead := _heading.normalized()
	var side := ahead.cross(Vector3.UP)
	if side.length_squared() < 1e-6:
		side = ahead.cross(Vector3.RIGHT)
	side = side.normalized()
	var up := side.cross(ahead).normalized()
	# The strands open out as it speeds up.
	var r := strand_radius * lerpf(0.4, 1.0, _ramp_through())
	var turn := _travelled * strand_turns
	for i in _tails.size():
		var tail := _tails[i]
		if not is_instance_valid(tail):
			continue
		if i < 2:
			tail.push(head)
		else:
			var a := turn + PI * float(i - 2)
			tail.push(head + (side * cos(a) + up * sin(a)) * r)


func _let_go_of_tails() -> void:
	for tail in _tails:
		if is_instance_valid(tail):
			tail.emitting = false
	_tails.clear()
	if _embers != null:
		_embers.emitting = false


## Where on `who` it goes for: the middle of the body, as the lock sees it.
func _mark(who: Node3D) -> Vector3:
	var points := TargetPoints.of(who)
	if points.is_empty():
		return who.global_position + Vector3.UP
	return points[clampi(TargetPoints.default_index(who), 0, points.size() - 1)]


## Whether the quarry has just got out of the way: it says it is dodging, or its
## velocity has broken sideways off the bolt's line, hard, against what it was
## doing a moment ago. Steady running across the line is not that — it is
## followed.
func _got_away(who: Node3D, delta: float) -> bool:
	if _is_evading(who):
		return true
	var now: Variant = who.get("velocity")
	if not now is Vector3:
		return false
	var kick := (now as Vector3) - _quarry_pace
	_quarry_pace = _quarry_pace.lerp(now as Vector3, clampf(delta * 3.0, 0.0, 1.0))
	var across := kick - _heading * kick.dot(_heading)
	across.y = 0.0
	return across.length() > dodge_kick


static func _is_evading(who: Node3D) -> bool:
	return who != null and who.has_method(&"is_evading") and bool(who.call(&"is_evading"))


## `from` turned towards `to` by at most `most` radians.
static func _turn(from: Vector3, to: Vector3, most: float) -> Vector3:
	var angle := from.angle_to(to)
	if angle <= most:
		return to
	var axis := from.cross(to)
	if axis.length_squared() < 1e-8:
		return from
	return from.rotated(axis.normalized(), most).normalized()


func _sweep_past(from: Vector3, to: Vector3, past: Array[RID]) -> Dictionary:
	var exclude: Array[RID] = past.duplicate()
	if _shooter is CollisionObject3D:
		exclude.append((_shooter as CollisionObject3D).get_rid())
	var query := PhysicsRayQueryParameters3D.create(from, to, 5, exclude)
	return get_world_3d().direct_space_state.intersect_ray(query)


func _strike(what: Node3D, where: Vector3) -> void:
	_spent = true
	_velocity = Vector3.ZERO
	_let_go_of_trails()
	struck.emit(what, where, _critical)
	if what != null and what.has_method("take_hit"):
		what.call("take_hit", _damage, where, _heading, _critical, false, _shooter)
	_burst(where)


func _let_go_of_trails() -> void:
	_let_go_of_tails()
	for ribbon in [_trail, _wake]:
		if ribbon == null:
			continue
		ribbon.emitting = false
		ribbon.get_tree().create_timer(ribbon.fade_time + 0.1).timeout.connect(ribbon.queue_free)
	_trail = null
	_wake = null


## Missed, or spent: it goes out where it is — shrinks to a spark and its light
## with it.
func _fade() -> void:
	if _fading:
		return
	_fading = true
	_velocity = Vector3.ZERO
	_let_go_of_trails()
	var tween := create_tween().set_parallel(true)
	if _model != null:
		tween.tween_property(_model, "scale", Vector3.ONE * 0.001, fade_out) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	if _light != null:
		tween.tween_property(_light, "light_energy", 0.0, fade_out)
	tween.chain().tween_callback(queue_free)


## Whether it has gone out without hitting anything.
func is_fading() -> bool:
	return _fading


## The flash where it lands: a ball of light that swells and goes, and the lamp
## flaring with it. The bolt itself goes with the flash.
func _burst(where: Vector3) -> void:
	for child in get_children():
		if child is Node3D and child != _light and child != _steady:
			(child as Node3D).visible = false
	var flash := MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radius = 0.5
	ball.height = 1.0
	ball.radial_segments = 16
	ball.rings = 8
	flash.mesh = ball
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(glow_colour.r, glow_colour.g, glow_colour.b, 0.9)
	flash.material_override = mat
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(flash)
	flash.global_position = where
	flash.scale = Vector3.ONE * 0.2
	var tween := create_tween().set_parallel(true)
	tween.tween_property(flash, "scale", Vector3.ONE * (1.6 if _critical else 1.1), burst_time) \
			.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_property(mat, "albedo_color:a", 0.0, burst_time)
	if _light != null:
		_light.light_energy = 6.0
		tween.tween_property(_light, "light_energy", 0.0, burst_time)
	tween.chain().tween_callback(queue_free)


func _settle(_delta: float) -> void:
	pass
