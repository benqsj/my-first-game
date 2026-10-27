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
## The aim and loose after the nock (none: the one shot clip, as before).
@export var aim_clip: StringName = &""
@export var aim_rate: float = 0.9
@export var aim_loose: float = 0.33
## The share of `shot_clip` its nock and draw end at.
@export var nock_until: float = 0.58

@export_group("Fire arrow")
@export var fire_clip: StringName = &""
@export var fire_rate: float = 1.6
@export_range(0.0, 1.0) var fire_chance: float = 0.25
@export var fire_burn: float = 3.0
@export var fire_dps: float = 6.0

@export_group("Close in")
@export var kick_clip: StringName = &""
@export var kick_range: float = 2.2
@export var kick_cooldown: float = 4.0
@export var kick_limbs: String = "R_knee_joint>R_toe_joint:0.15|L_knee_joint>L_toe_joint:0.15"
@export var dodge_clips: PackedStringArray = PackedStringArray()
@export_range(0.0, 1.0) var dodge_chance: float = 0.0
@export var dodge_speed: float = 3.6

@export_group("The line")
@export var behind_line: bool = false
@export var behind_gap: float = 5.0

const SHOT := 70
const NOCK := 71
const AIM := 72
const POWER := 73
const KICK := 74
const DODGE_B := 75
const DODGE_L := 76
const DODGE_R := 77
const DODGES := [DODGE_B, DODGE_L, DODGE_R]

var _string: int = -1
var _hand: int = -1
var _string_rest: Vector3 = Vector3.ZERO
var _nocked: MeshInstance3D
var _loosed: bool = false
var _flee_left: float = 0.0
## Run, then shoot: it runs again only once it has turned and shot.
##
## The skeleton archer's own (2026-10-27, the user's picks from its films,
## project doc claude/archer_imp_puglin_plan.md; Mixamo's, CR_AR_*):
## * **The shot** is two moves when `aim_clip` is set: the nock and draw of
##   `shot_clip` (`NOCK`, up to `nock_until` of it), then the aim and loose
##   (`AIM`, `aim_clip`, loosed at `aim_loose` clip s).
## * **The fire arrow** (`fire_chance` of the shots): after the nock it draws
##   long (`POWER`, `fire_clip`, the arrow's head alight on every peer) and
##   looses a burning arrow; it sets him alight ([HeroBurn], `fire_burn` s).
## * **Come close** (within `kick_range`) it kicks him back off his feet
##   (`KICK`, `kick_clip`), hops back (`DODGE_B`) and shoots; it runs as
##   before only when the kick is not ready.
## * **Now and then** (`dodge_chance`) it hops aside from his swing, left,
##   right or back (`DODGE_L/R/B`); a cut makes it flinch (`hit_clip`).
## * **Behind the line** (`behind_line`): with others of its band (not
##   archers) between it and him, it keeps behind them, `behind_gap` further
##   off him than they are, and shoots from there.
var _shot_since_run: bool = true
## Host: this shot burns.
var _fire_next: bool = false
var _kick_wait: float = 0.0
var _shoot_after_hop: bool = false
var _dodge_side: Vector3 = Vector3.ZERO
var _head_fire: Node3D


func _ready() -> void:
	super()
	_moves_table[SHOT] = [shot_clip, shot_rate, 0.0, 1.0]
	if not aim_clip.is_empty():
		_moves_table[NOCK] = [shot_clip, shot_rate, 0.0, nock_until]
		_moves_table[AIM] = [aim_clip, aim_rate, 0.0, 1.0]
	if not fire_clip.is_empty():
		_moves_table[POWER] = [fire_clip, fire_rate, 0.0, 1.0]
	if not kick_clip.is_empty():
		_moves_table[KICK] = [kick_clip, 1.25, 0.0, 0.9]
		_own_limb(KICK, kick_limbs)
		_moment_at_reach(KICK)
		# it throws him off his feet
		var st: Array = _strikes_table[KICK]
		st[3] = 1
	for i in mini(dodge_clips.size(), 3):
		_moves_table[DODGES[i]] = [StringName(dodge_clips[i]), 1.25, 0.0, 0.85]
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
	_kick_wait = maxf(_kick_wait - delta, 0.0)
	if act != Act.NONE:
		return
	var gap := _distance_to(_quarry)
	var away := global_position - _quarry.global_position
	away.y = 0.0
	if _shoot_after_hop:
		_shoot_after_hop = false
		_face(-away, 1.0, 50.0)
		_draw_bow()
		return
	# Come too close: the kick, then a hop back and a shot.
	if _moves_table.has(KICK) and _kick_wait <= 0.0 and gap < kick_range \
			and not _quarry_down() and _flee_left <= 0.0:
		_kick_wait = kick_cooldown
		_face(-away, 1.0, 50.0)
		_begin(KICK)
		return
	if _to_shoot_slot(delta):
		return
	if behind_line and not shoot_slot and _keep_behind(gap, delta):
		return
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
	# (its turn among all that throw at him: one at a time, the user's word,
	# 2026-10-27, so each can be seen coming and stepped out of)
	if _cooldown <= 0.0 and ahead.dot(-away.normalized()) > 0.9 and Fighter.claim_throw(_quarry):
		_draw_bow()


## Host: a shot begun: the old single clip, or the nock (then the aim, or the
## long fiery draw).
func _draw_bow() -> void:
	_loosed = false
	if not _moves_table.has(NOCK):
		_begin(SHOT)
		return
	_fire_next = _moves_table.has(POWER) and _rng.randf() < fire_chance
	_begin(NOCK)


## Host: with its band's fighters between it and him, it goes round behind
## them, `behind_gap` further off him than they are. True while it walks.
func _keep_behind(gap: float, delta: float) -> bool:
	var sum := Vector3.ZERO
	var n := 0
	for node in get_tree().get_nodes_in_group(&"enemy"):
		var f := node as Fighter
		if f == null or f == self or f is BowFighter or f.is_dead:
			continue
		if f.global_position.distance_to(global_position) > 18.0:
			continue
		if f.global_position.distance_to(_quarry.global_position) > 7.0:
			continue
		sum += f.global_position
		n += 1
	if n == 0:
		return false
	var line := sum / float(n) - _quarry.global_position
	line.y = 0.0
	if line.length_squared() < 0.01:
		return false
	var spot := _quarry.global_position + line.normalized() * (line.length() + behind_gap)
	var to := spot - global_position
	to.y = 0.0
	if to.length() < 1.5 or gap > shoot_range:
		return false
	mode = Mode.CHASE
	_move_towards(spot, chase_speed, delta)
	return true

func _run_act(delta: float) -> void:
	super(delta)
	if act in DODGES or act == KICK:
		return
	if (act == NOCK or act == POWER) and _quarry != null:
		velocity.x = 0.0
		velocity.z = 0.0
		_face(_quarry.global_position - global_position, delta, turn_speed * 2.0)
		return
	if act == AIM and _quarry != null:
		velocity.x = 0.0
		velocity.z = 0.0
		if _clip_time(act, _act_time) < aim_loose:
			_face(_quarry.global_position - global_position, delta, turn_speed * 2.0)
		elif not _loosed:
			_loosed = true
			_loose()
		return
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
	match what:
		NOCK:
			_begin(POWER if _fire_next else AIM)
			return
		POWER:
			# the long draw held: the burning arrow goes now
			if not _loosed:
				_loosed = true
				_loose()
			_fire_next = false
			_shot_since_run = true
		AIM:
			_shot_since_run = true
		KICK:
			# off him: a hop back, then a shot
			if _moves_table.has(DODGE_B) and not is_dead:
				_begin(DODGE_B)
				_shoot_after_hop = true
				return
	if what == SHOT:
		_shot_since_run = true
	super(what)


func _extra_velocity(delta: float) -> Vector3:
	match act:
		DODGE_L, DODGE_R:
			return _dodge_side * dodge_speed
		NOCK, AIM, POWER, KICK:
			return Vector3.ZERO
	return super(delta)


## Host: now and then a hop aside out of his swing (left, right or back).
func _answer_swing(knight: Node3D) -> void:
	if act != Act.NONE or dodge_chance <= 0.0 or _rng.randf() >= dodge_chance:
		super(knight)
		return
	var to_me := global_position - knight.global_position
	to_me.y = 0.0
	if to_me.length() > 4.0:
		return
	var which: int = DODGES[_rng.randi() % DODGES.size()]
	if not _moves_table.has(which):
		return
	_rouse(knight)
	_face(-to_me, 1.0, 50.0)
	var right := _forward().cross(Vector3.UP)
	_dodge_side = -right if which == DODGE_L else right
	_begin(which)


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
	net_loose.rpc(from, shot, act == POWER)


@rpc("authority", "call_local", "reliable")
func net_loose(from: Vector3, shot: Vector3, burning: bool = false) -> void:
	var into := Blood.world_of(self)
	if into == null or arrow_scene == null:
		return
	var arrow := arrow_scene.instantiate() as Node3D
	arrow.set(&"against_heroes", true)
	# At him: a line he can read and step out of (the user's word, 2026-10-27:
	# the arrows' trail was not to be seen), wide, warm and long.
	arrow.set(&"trail_width", 0.17)
	arrow.set(&"trail_fade", 0.75)
	arrow.set(&"streak_tint", Color(1.0, 0.55, 0.25, 0.9))
	arrow.set(&"wake_tint", Color(1.0, 0.75, 0.5, 0.22))
	into.add_child(arrow)
	arrow.global_position = from
	arrow.call(&"launch", shot, hit_damage, false, arrow_gravity, self)
	if burning:
		_set_alight(arrow, 1.0)
		if _decides() and arrow.has_signal(&"struck"):
			arrow.connect(&"struck", _fire_struck)


## Host: the burning arrow found a hero (not on his guard, not rolling): he
## catches fire, on every peer.
func _fire_struck(what: Node3D, _where: Vector3, _critical: bool) -> void:
	var hero := what as Player
	if hero == null or hero.is_dead or hero.untouchable_now(self) or hero.guarding():
		return
	net_burn.rpc(hero.get_path())


@rpc("authority", "call_local", "reliable")
func net_burn(hero: NodePath) -> void:
	var who := get_node_or_null(hero) as Node3D
	if who != null:
		HeroBurn.ignite(who, fire_burn, fire_dps)


## Flames on `on` (a burning arrow, or the head of the one it draws), and a
## warm light; `size` 1 the arrow's.
static func _set_alight(on: Node3D, size: float) -> Node3D:
	var holder := Node3D.new()
	holder.name = "Alight"
	on.add_child(holder)
	SkillFx.particles(holder, on.global_position, {
		"amount": 36, "life": 0.35, "speed": Vector2(0.2, 0.6), "spread": 40.0, "local": false,
		"gravity": Vector3(0, 2.0, 0), "size": Vector2(0.12, 0.22) * size, "sphere": 0.04,
		"tex": SkillFx.flame(), "quad": Vector2(0.5, 1.0), "add": false, "grow": 0.2,
		"colors": [Color(1.0, 0.62, 0.18, 0.0), Color(1.0, 0.5, 0.08, 0.95), Color(0.92, 0.2, 0.02, 0.85),
				Color(0.25, 0.03, 0.0, 0.0)],
	})
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.45, 0.08)
	glow.light_energy = 1.8
	glow.omni_range = 3.5
	glow.shadow_enabled = false
	holder.add_child(glow)
	return holder


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
	elif act == NOCK and _anim != null:
		drawn = _anim.clip_position() >= nock_at
	elif act == POWER:
		drawn = true
	elif act == AIM and _anim != null:
		drawn = _anim.clip_position() < aim_loose
	_show_head_fire(act == POWER and not is_dead)
	if drawn and _hand >= 0:
		var parent := _skeleton.get_bone_parent(_string)
		var parent_g := _posed(parent) if parent >= 0 else Transform3D.IDENTITY
		_skeleton.set_bone_pose_position(_string, parent_g.affine_inverse() * _posed(_hand).origin)
	else:
		_skeleton.set_bone_pose_position(_string, _string_rest)
	if _nocked != null:
		_nocked.visible = drawn


## Every peer: the nocked arrow's head alight through the long draw.
func _show_head_fire(on: bool) -> void:
	if on and _head_fire == null and _nocked != null and _skeleton != null and _hand >= 0:
		var at := BoneAttachment3D.new()
		at.bone_idx = _hand
		_skeleton.add_child(at)
		_head_fire = at
		var lit := _set_alight(at, 0.8)
		# out along the arrow, at its head (the arrow lies forward of the hand)
		lit.position = Vector3(0.0, 0.0, 0.0)
		_head_fire.set_meta(&"lit", lit)
	if _head_fire != null:
		_head_fire.visible = on
		var lit := _head_fire.get_meta(&"lit") as Node3D
		if on and lit != null and _skeleton != null and _string >= 0:
			# placed at the bow, where the head of a drawn arrow rests
			var bow := _skeleton.global_transform * _posed(_skeleton.get_bone_parent(_string)).origin
			lit.global_position = bow


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
