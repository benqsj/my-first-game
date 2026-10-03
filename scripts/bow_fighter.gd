class_name BowFighter
extends Brawler

## An archer that keeps its distance: the skeleton archer of Polysplit's
## Biped Creatures (CREATURES_PACK.md), on the pack's own bow and string.
##
## * **Far off** (beyond `flee_under`) it stands and shoots, again and again,
##   and never runs. Beyond `shoot_range` it walks in until he is in range.
## * **Come close**, and it turns and runs (`flee_time`, or until it has
##   `keep_away` between them), turns back, shoots once, and if he is still
##   close runs again: run, turn, shoot, run.
## * **A shot** is one clip (`CR_BowShot`, tools/creature_clips.gd): the nock
##   and draw, a breath on the aim, the loose. From `nock_at` to `loose_at`
##   (clip seconds) the string (`stringJoint`) is held in the drawing hand and
##   the arrow on it shows; at `loose_at` a real [Arrow] leaves the string,
##   aimed where he will be when it gets there (his pace led, its drop
##   allowed for), and hits what it meets: a hero takes it as a blow, through
##   his guard and evades as any blow is ([member Arrow.against_heroes]).
##   It keeps turning onto him while it draws.

@export_group("Bow")
@export var shot_clip: StringName = &"CR_BowShot"
@export var shot_rate: float = 1.3
@export var nock_at: float = 0.63
@export var loose_at: float = 1.45
@export var arrow_speed: float = 34.0
@export var arrow_gravity: float = 6.0
@export var shoot_range: float = 24.0
@export var flee_under: float = 6.0
@export var keep_away: float = 11.0
@export var flee_time: float = 1.7
@export var arrow_scene: PackedScene = preload("res://scenes/props/arrow.tscn")
@export var string_bone: StringName = &"stringJoint"
@export var draw_bone: StringName = &"R_midFinger_joint1"
@export var arrow_mesh: StringName = &"Skeleton_Archer_Arrow"

const SHOT := 70

var _string: int = -1
var _hand: int = -1
var _string_rest: Vector3 = Vector3.ZERO
var _nocked: MeshInstance3D
var _loosed: bool = false
var _flee_left: float = 0.0
## Run, then shoot: it runs again only once it has turned and shot.
var _shot_since_run: bool = true


func _ready() -> void:
	super()
	_moves_table[SHOT] = [shot_clip, shot_rate, 0.0, 1.0]
	leash_radius = maxf(leash_radius, shoot_range * 2.5)
	if _skeleton != null:
		_string = _skeleton.find_bone(String(string_bone))
		_hand = _skeleton.find_bone(String(draw_bone))
		if _string >= 0:
			_string_rest = _skeleton.get_bone_rest(_string).origin
	if body != null:
		_nocked = body.find_child(String(arrow_mesh), true, false) as MeshInstance3D


func _think(delta: float) -> void:
	if mode == Mode.GUARD or mode == Mode.RETURN or is_dead:
		super(delta)
		return
	_quarry = _pick_quarry()
	if _quarry == null:
		_go_home()
		return
	if act != Act.NONE:
		return
	var gap := _distance_to(_quarry)
	var away := global_position - _quarry.global_position
	away.y = 0.0
	if _flee_left > 0.0:
		_flee_left -= delta
		if gap < keep_away and _flee_left > 0.0:
			mode = Mode.CHASE
			_move_towards(global_position + away.normalized() * 4.0, chase_speed, delta)
			return
		_flee_left = 0.0
	if gap < flee_under and _shot_since_run:
		_shot_since_run = false
		_flee_left = flee_time
		return
	if gap > shoot_range:
		mode = Mode.CHASE
		_move_towards(_quarry.global_position, speed * 1.6, delta)
		return
	mode = Mode.FIGHT
	_face(-away, delta, turn_speed * 2.0)
	_slow(delta, 4.0)
	var ahead := _forward()
	if _cooldown <= 0.0 and ahead.dot(-away.normalized()) > 0.9:
		_loosed = false
		_begin(SHOT)


func _run_act(delta: float) -> void:
	super(delta)
	if act != SHOT or _quarry == null:
		return
	velocity.x = 0.0
	velocity.z = 0.0
	var clip_t := _clip_time(act, _act_time)
	if clip_t < loose_at:
		_face(_quarry.global_position - global_position, delta, turn_speed * 2.0)
	elif not _loosed:
		_loosed = true
		_loose()


func _after(what: int) -> void:
	if what == SHOT:
		_shot_since_run = true
	super(what)


## The arrow off the string, aimed where he will be when it gets there.
func _loose() -> void:
	if not _decides() or _quarry == null:
		return
	var from := _string_point()
	var target := _quarry.global_position + Vector3.UP * 1.25
	var flight := from.distance_to(target) / arrow_speed
	var pace: Variant = _quarry.get("velocity")
	if pace is Vector3:
		var v := pace as Vector3
		target += Vector3(v.x, 0.0, v.z) * flight
	flight = from.distance_to(target) / arrow_speed
	var shot := (target - from) / maxf(flight, 0.01) + Vector3.UP * 0.5 * arrow_gravity * flight
	net_loose.rpc(from, shot)


@rpc("authority", "call_local", "reliable")
func net_loose(from: Vector3, shot: Vector3) -> void:
	var into := Blood.world_of(self)
	if into == null or arrow_scene == null:
		return
	var arrow := arrow_scene.instantiate() as Node3D
	arrow.set(&"against_heroes", true)
	into.add_child(arrow)
	arrow.global_position = from
	arrow.call(&"launch", shot, hit_damage, false, arrow_gravity, self)


## Where the string is now (the drawing hand while it is drawn), in the world.
func _string_point() -> Vector3:
	if _skeleton == null:
		return global_position + Vector3.UP * 1.4
	var bone := _hand if _hand >= 0 else _string
	return _skeleton.global_transform * _posed(bone).origin


func _process(delta: float) -> void:
	super(delta)
	if _skeleton == null or _string < 0:
		return
	var drawn := false
	if act == SHOT and _anim != null:
		var clip_t := _anim.clip_position()
		drawn = clip_t >= nock_at and clip_t < loose_at
	if drawn and _hand >= 0:
		var parent := _skeleton.get_bone_parent(_string)
		var parent_g := _posed(parent) if parent >= 0 else Transform3D.IDENTITY
		_skeleton.set_bone_pose_position(_string, parent_g.affine_inverse() * _posed(_hand).origin)
	else:
		_skeleton.set_bone_pose_position(_string, _string_rest)
	if _nocked != null:
		_nocked.visible = drawn


## A bone of this figure where its pose puts it, in the skeleton's space,
## worked up its chain from the local poses.
func _posed(idx: int) -> Transform3D:
	var t := Transform3D.IDENTITY
	var i := idx
	while i >= 0:
		var local := Transform3D(Basis(_skeleton.get_bone_pose_rotation(i)).scaled(_skeleton.get_bone_pose_scale(i)),
				_skeleton.get_bone_pose_position(i))
		t = local * t
		i = _skeleton.get_bone_parent(i)
	return t
