class_name DragonFlyby
extends Node3D

## The Soul Eater on the wing, for a film: no mind, no body to hit, only the
## model flown along a line through the air at a speed the story sets, banking
## into its turns, and the fire it spits.
##
## The line is a list of points; the curve through them is smooth (each
## point's handles lie along the line from the point before to the one
## after). [member speed] can be changed in flight; [signal arrived] is sent at
## the last point, and [method fireball] throws a ball of fire from its jaws
## at a point and calls back when it lands.

signal arrived

const MODEL := "res://assets/monsters/dragon_souleater/dragon_souleater.glb"
const FLAP := &"DS_FlyForward"
const GLIDE := &"DS_FlyGlide"
const SPIT := &"DS_FlyFireballShoot"
const FIRE := Color(1.0, 0.45, 0.08)

## Times the size of the boss in the bestiary (which stands ~3 m at the
## shoulder): the one that burns a village is a great deal bigger.
@export var size: float = 4.0
## Metres a second along the line.
var speed: float = 22.0

var _turn: Node3D
var _model: Node3D
var _anim: AnimationPlayer
var _skel: Skeleton3D
var _curve: Curve3D
var _along: float = 0.0
var _flying: bool = false
var _bank: float = 0.0
var _last_yaw: float = NAN


func _ready() -> void:
	_turn = Node3D.new()
	_turn.name = "Turn"
	add_child(_turn)
	# The model looks along its +z; the flier along its -z.
	_turn.rotation.y = PI
	var scene := load(MODEL) as PackedScene
	if scene == null:
		return
	_model = scene.instantiate() as Node3D
	_turn.add_child(_model)
	_model.scale = Vector3.ONE * size
	for mesh: GeometryInstance3D in _model.find_children("*", "GeometryInstance3D", true, false):
		mesh.extra_cull_margin = 4.0
		mesh.visibility_range_end = 0.0
	var players := _model.find_children("*", "AnimationPlayer", true, false)
	if not players.is_empty():
		_anim = players[0] as AnimationPlayer
		for clip: StringName in [FLAP, GLIDE]:
			if _anim.has_animation(clip):
				_anim.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
		_anim.animation_finished.connect(_on_clip_done)
	var skels := _model.find_children("*", "Skeleton3D", true, false)
	if not skels.is_empty():
		_skel = skels[0] as Skeleton3D
	clip(GLIDE, 0.0)


## Flies the line through `points` from the first.
func fly(points: PackedVector3Array) -> void:
	_curve = Curve3D.new()
	_curve.bake_interval = 0.5
	for i in points.size():
		var before := points[maxi(i - 1, 0)]
		var after := points[mini(i + 1, points.size() - 1)]
		var handle := (after - before) * 0.22
		_curve.add_point(points[i], -handle, handle)
	_along = 0.0
	_flying = true
	_last_yaw = NAN
	_place(0.0)


## How far along the line it is, 0 to 1.
func progress() -> float:
	if _curve == null:
		return 0.0
	return clampf(_along / maxf(_curve.get_baked_length(), 0.01), 0.0, 1.0)


func clip(which: StringName, blend: float = 0.35, rate: float = 1.0) -> void:
	if _anim != null and _anim.has_animation(which):
		_anim.play(which, blend, rate)


## Where its jaws are.
func mouth() -> Vector3:
	if _skel != null:
		var head := _skel.find_bone("Head")
		if head >= 0:
			return _skel.global_transform * _skel.get_bone_global_pose(head).origin
	return global_position - global_transform.basis.z * 3.0 * size


## A ball of fire from the jaws to `at`, landing after `seconds`; `landed`
## is called with `at` when it does.
func fireball(at: Vector3, seconds: float = 0.7, landed: Callable = Callable()) -> void:
	clip(SPIT, 0.15)
	var parent := get_parent()
	var ball := Node3D.new()
	ball.name = "Fireball"
	parent.add_child(ball)
	var from := mouth()
	ball.global_position = from
	var core := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.4
	sphere.height = 0.8
	core.mesh = sphere
	core.material_override = SkillFx.glow(Color(1.0, 0.5, 0.12), 3.0)
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ball.add_child(core)
	SkillFx.particles(ball, from, {
		"amount": 110, "life": 0.5, "speed": Vector2(0.2, 1.2), "spread": 180.0,
		"size": Vector2(0.8, 1.7), "sphere": 0.5, "tex": SkillFx.flame(), "grow": 0.3,
		"colors": [Color(1.0, 0.8, 0.3, 1.0), Color(1.0, 0.45, 0.06, 0.9), Color(0.3, 0.05, 0.0, 0.0)],
	})
	var light := OmniLight3D.new()
	light.light_color = FIRE
	light.light_energy = 6.0
	light.omni_range = 14.0
	ball.add_child(light)
	var t := ball.create_tween()
	t.tween_method(func(k: float) -> void:
		# A little arc: spat out and falling on to it.
		var p := from.lerp(at, k) + Vector3.UP * sin(k * PI) * 2.0
		ball.global_position = p, 0.0, 1.0, seconds)
	t.tween_callback(func() -> void:
		SkillFx.flash(parent, at + Vector3.UP * 1.0, Color(1.0, 0.6, 0.25), 2.2, 0.35, 6.0)
		SkillFx.burst(parent, at + Vector3.UP * 0.5, FIRE, 120, Vector2(4.0, 14.0), Vector3.UP, 70.0,
				Vector2(0.06, 0.16), Vector3(0, -9, 0), 1.4)
		if landed.is_valid():
			landed.call(at)
		ball.queue_free())


func _on_clip_done(done: StringName) -> void:
	if done == SPIT:
		clip(FLAP, 0.3)


func _process(delta: float) -> void:
	if not _flying or _curve == null:
		return
	_along += speed * delta
	var length := _curve.get_baked_length()
	if _along >= length:
		_along = length
		_flying = false
		_place(delta)
		arrived.emit()
		return
	_place(delta)


func _place(delta: float) -> void:
	var length := _curve.get_baked_length()
	var at := _curve.sample_baked(_along, true)
	var ahead := _curve.sample_baked(minf(_along + 3.0, length), true)
	if _along + 3.0 > length:
		ahead = at + (at - _curve.sample_baked(maxf(_along - 3.0, 0.0), true))
	global_position = at
	var way := ahead - at
	if way.length() < 0.01:
		return
	var yaw := atan2(-way.x, -way.z)
	var pitch := atan2(way.y, Vector2(way.x, way.z).length())
	# Banked into the turn, by how fast it is turning.
	if not is_nan(_last_yaw) and delta > 0.0:
		var turning := wrapf(yaw - _last_yaw, -PI, PI) / delta
		_bank = lerpf(_bank, clampf(turning * 0.9, -0.7, 0.7), 1.0 - exp(-3.0 * delta))
	_last_yaw = yaw
	global_basis = Basis.from_euler(Vector3(pitch * 0.6, yaw, _bank), EULER_ORDER_YXZ)
