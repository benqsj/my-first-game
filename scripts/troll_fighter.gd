class_name TrollFighter
extends PackBrute

## The troll (Polysplit's Biped Creatures, CREATURES_PACK.md): big and hard to
## keep down (the user's picks, 2026-10-07).
##
## **A great club, every blow heavy** (the user's word, 2026-10-25: it was so
## quick it could not be fought; heavy blows and Elden Ring's way, the club
## seen coming back after each blow, its balance lost, and its body breaking
## little by little until the last blow breaks it). What was a feral pouncer
## on all fours (2026-10-15) now carries a gnarled oak club in both hands
## (`vepxis-art/creatures/troll_club.py`, laid along its grip as the golem's
## maul is) and fights the way its weight lets it:
##
## * **Slow up, fast down**: every swing's wind-up drawn out to at least its
##   `_slow_to` (no glow: it is wood), and the club brought down quicker from
##   the top (`_snap`); now and then held at the top (`_holds`, the delayed
##   swing). It stops following him a beat before the blow (ClipFighter's
##   lock), and in a move it turns no quicker than `act_turn_most`.
## * **The club comes back**: each move plays out to the end of its clip, the
##   club carried back up to its shoulder before anything else (`hand_tail`
##   long, `attack_cooldown` long): that is the opening.
## * **Off balance when it misses**: its great swings (`MISS_REELS`) that find
##   nothing carry it round after the club, and it stands staggered a moment.
## * **Its balance, little by little** (Elden Ring's stance): blows fill it;
##   at `TOTTER_AT` it rocks back a step, at `STAGGER_AT` it is knocked off
##   its stance and reels, and full it goes down on a knee, open to a critical.
## * **Its body breaking**: at every `WOUND_AT` of its health a wound opens
##   where it was struck (seen by all), it gets slower, and its balance breaks
##   sooner; the last blow fells it, the club dropping out of its hands.
## * **Its own swings** (2026-10-25, the user's word: not the ogre's): a
##   batter's swings, a scoop up from between its legs, a butt-end jab, a
##   swing and three knees; strung two, three and four together, each move's
##   end running into the next's start ([method _set_moves]). It walks the
##   brute's walk, the club on its shoulder, and roars as a brute does.
## * **The leap**: from off it springs at him and brings the club down; the
##   ground splits along a line (no rings) where it lands, as for its chop.
## * **Its wounds close** a little while nothing burns or freezes it.

@export_group("Boulder")
## Off since it holds the club (2026-10-25); the old throw kept for a kind
## that wants it.
@export var hurl_on: bool = false
@export var pick_clip: StringName = &"CR_Harvest"
@export var pick_part: Vector3 = Vector3(1.5, 0.12, 0.5)
@export var hurl_clip: StringName = &"CR_Throw"
@export var hurl_part: Vector3 = Vector3(1.1, 0.0, 0.85)
@export var hurl_from: float = 6.0
@export var hurl_to: float = 20.0
@export var hurl_cooldown: Vector2 = Vector2(6.0, 10.0)
@export var boulder_share: float = 1.1

@export_group("Regeneration")
## Share of its health won back a second.
@export var regen: float = 0.004
@export var regen_stopped: float = 6.0
@export var regen_tint: Color = Color(0.45, 1.0, 0.35)

@export_group("Club")
const CLUB_FILE := "res://assets/creatures/troll_club.glb"
## The club's size in its hand's frame (the model is ~1.64 m at 1; the hand's
## frame is a man's, the troll drawn 1.6 times that).
@export var club_scale: float = 0.75
## How far out along its grip the club's head is (its blows reach to there).
@export var club_reach: float = 0.86
@export var club_radius: float = 0.24
## Dust where the club's head comes down into the ground: within this of it
## (m), coming down at least this fast (m/s).
@export var dust_touch: float = 0.18
@export var dust_fall: float = 3.0

@export_group("Crack")
@export var crack_reach: float = 7.5
@export var crack_speed: float = 11.0
@export var crack_width: float = 0.85
@export var crack_share: float = 0.8

@export_group("Body")
## Its health's shares at which a wound opens and it slows.
const WOUND_AT := [0.8, 0.6, 0.4, 0.2]
## Each wound: its pace this much less, its stance this much less.
@export var wound_slow: float = 0.06
@export var wound_stance: float = 0.1
## Its stance's shares at which it rocks back a step, and is staggered.
const TOTTER_AT := 0.4
const STAGGER_AT := 0.72

const PICK := 116
const HURL := 117
## Its club's moves (2026-10-25; its own, not the ogre's: the user's word,
## the same day — swings of a man with a heavy bat, a scoop up from between
## its legs, a butt-end jab, a swing and three knees; Mixamo's, baked as
## CR_TR_*). The chop (UAL's Heavy1) and the leap stay.
const T_CHOP := 200
## the great swing round at him, the batter's homerun (fells; missed, it reels)
const T_SWING := 203
## a quicker swing across (the batter's single)
const T_BAT := 220
## the batter's double: the second swing of a string
const T_BAT2 := 221
## the club swung up from between its legs (it throws him up)
const T_SCOOP := 222
## the butt of the club jabbed at him, close
const T_BUTT := 223
## a swing across and three knees into him: four blows
const T_KNEES := 224
const T_REEL := 210
const T_TOTTER := 211
const T_STAGGER := 212
## Its swings that carry it round off its balance when they find nothing.
const MISS_REELS := [T_SWING]
## Its blows that split the ground where the club comes down (its chop: the
## one whose club goes into the ground, measured).
const CRACKS := [T_CHOP]
## Its club, from its right hand out along the grip (laid right once it has
## felt both hands on it, [method _lay_club]).
const CLUB := "R_wrist_joint>R_wrist_joint@0,0.86,0:0.24"
const KNEES := "L_thigh_joint>L_knee_joint:0.24|R_thigh_joint>R_knee_joint:0.24"
const SOUNDS := "res://sounds/ogre/"

var _hurl_wait: float = 3.0
var _hurled: bool = false
var _hurl_at: float = 0.5
var _hand: int = -1
## Every peer: the boulder in its hands, from the pick until it is thrown.
var _held: MeshInstance3D
var _held_serial: int = -1
var _held_clock: float = 0.0
## Host: seconds its wounds are still kept from closing.
var _stopped_for: float = 0.0
## Replicated (net_regen): its wounds closing now.
var healing: bool = false
var _mote_clock: float = 0.0
var _heal_glow: StandardMaterial3D
var _heal_shown: bool = false
## Kept for the old tests: bites that closed its wounds (none now).
var bites_healed: int = 0

## Every peer: its club, and the grip it is laid along.
var _club_hold: BoneAttachment3D
var _club: Node3D
var _grip_local: Vector3 = Vector3.UP
var _grip_learnt: bool = false
var _club_dropped: bool = false
## Its club's stretch as `attack_limbs` reads one (set by [method _learn_grip]).
var _club_spec: String = CLUB
## Every peer: the move it shows and its clock (its sounds and dust).
var _seen_serial: int = -1
var _seen_clock: float = 0.0
var _whooshed: int = -1
var _tip_last: Vector3 = Vector3.INF
var _dust_wait: float = 0.0
## Host: the serial of the move whose blow last reached him; cracks let go.
var _landed_serial: int = -1
var _cracked_serial: int = -1
var _cracks: Array[GroundCrack] = []
## Host: how far through its stance it has rocked (0 none, 1 tottered, 2
## staggered); its wounds; its pace and stance at the start.
var _rocked: int = 0
var wounds: int = 0
var _rage_eased: bool = false
## Every peer: where its wounds are (each bleeds now and then).
var _wound_marks: Array[Marker3D] = []
var _drip_in: float = 0.5
var _stance0: float = 0.0
## For the tests and probes.
var reels: int = 0
var totters: int = 0
var staggers: int = 0
var cracks_made: int = 0
var ground_dusts: int = 0


func _ready() -> void:
	# a heavy thing on two feet with a club in both hands: never on all fours,
	# no hop aside, slow to come round
	# at rest it breathes, the club in one hand, and walks the brute's walk
	# with it on its shoulder (Mixamo's mutant's); in the fight, both hands on it
	idle_clip = &"CR_TR_MutantIdle"
	guard_idle_clip = &"CR_HeavyIdle"
	fidget_clip = &"CR_TR_MutantIdle"
	walk_clip = &"CR_TR_MutantWalk"
	back_clip = &"CR_HeavyBack"
	strafe_l_clip = &"CR_HeavyL"
	strafe_r_clip = &"CR_HeavyR"
	run_clip = &"CR_HeavyRun"
	hit_clip = &"CR_GS_Impact"
	block_clip = &"CR_GS_Impact"
	break_clip = &"CR_GS_Impact"
	death_clip = &"CR_MG_Death"
	var loops := Array(loop_clips)
	for c in ["CR_HeavyIdle", "CR_HeavyWalk", "CR_HeavyBack", "CR_HeavyL", "CR_HeavyR", "CR_HeavyRun",
			"CR_TR_MutantIdle", "CR_TR_MutantWalk"]:
		if not loops.has(c):
			loops.append(c)
	loop_clips = PackedStringArray(loops)
	speed = minf(speed, 1.6)
	chase_speed = 3.3
	close_speed = 1.8
	run_above = 2.6
	dash_chance = 0.0
	stand_turn_max = 1.6
	turn_speed = minf(turn_speed, 3.2)
	act_turn_most = 75.0
	glide_most = 0.9
	glide_gap = 0.8
	chain_snap = 0.0
	max_health = maxf(max_health, 720.0)
	hit_damage = maxf(hit_damage, 58.0)
	reach = 3.4
	strike_off = 2.7
	attack_cooldown = Vector2(1.5, 2.5)
	attack_cost = 18.0
	stamina_regen = minf(stamina_regen, 18.0)
	# its plain blows are the club too: a swing across, and the butt jabbed
	# when he is close
	attacks = [&"CR_TR_BatSingle", &"CR_TR_ButtSmash"] as Array[StringName]
	attack_parts = [Vector3(1.0, 0.15, 0.68), Vector3(1.0, 0.2, 0.62)] as Array[Vector3]
	attack_limbs = PackedStringArray([CLUB, CLUB])
	attack_blows = PackedInt32Array([1, 1])
	attack_clip = &"CR_TR_BatSingle"
	# the leap: the club brought down out of a spring at him
	leap_clip = &"CR_Heavy4"
	leap_part = Vector3(0.9, 0.0, 0.94)
	leap_land = 0.32
	leap_from = 5.0
	leap_to = 9.5
	leap_cooldown = 11.0
	leap_quake = 0.0
	leap_limbs = CLUB
	leap_share = 1.4
	# its balance (Elden Ring's): light cuts hardly shake it, heavy blows do
	stance = 520.0
	stance_light_share = 0.4
	stance_rest = 9.0
	stance_down = 3.0
	stance_crit_share = 0.12
	bite_hold = 0.0
	shove_share = 0.15
	flinch_share = 0.55
	# enraged late, not at once: the brute's roar, harder, a little quicker
	rage_at = 0.3
	rage_clip = &"CR_TR_Roar"
	rage_part = Vector3(1.15, 0.1, 0.62)
	rage_pace = 1.12
	rage_harder = 1.3
	hand_pace = 1.0
	hand_tail = 0.62
	hand_combo_chance = Vector2(0.55, 0.7)
	combo_slack = 0.7
	repeat_damp = 0.3
	_stance0 = stance
	super()
	# its grip read off its two-handed stance before the moves are measured,
	# so where each blow lands from is the club's reach, not its fingers'
	_learn_grip()
	_set_moves()
	if _grip_learnt:
		# its plain blows and the leap out to the club's head too, measured again
		_reach_club()
		for i in attacks.size():
			_moment_at_reach(ATTACK_BASE + i)
	# it closes in until the furthest of its blows would land, not short of it
	var furthest := 0.0
	for what: int in _strike_from:
		furthest = maxf(furthest, float(_strike_from[what]))
	if furthest > 0.0:
		reach = furthest + 0.3
	_special(PICK, pick_clip, pick_part)
	_special(HURL, hurl_clip, hurl_part)
	if _skeleton != null:
		_hand = _skeleton.find_bone("R_wrist_joint")
	if _anim != null and hurl_on:
		var m: Array = _moves_table[HURL]
		var length := _anim.clip_length(m[0])
		var best := -1.0
		for p in _anim.measure_peaks(m[0], PackedStringArray(["R_wrist_joint"]), 0.5, 0.08):
			if p >= float(m[2]) and p <= float(m[3]):
				best = p
		if best < 0.0:
			best = lerpf(float(m[2]), float(m[3]), 0.5)
		_hurl_at = (best - float(m[2])) * length / maxf(float(m[1]), 0.01)
	_hurl_wait = _rng.randf_range(2.0, hurl_cooldown.x)
	_make_club()


## Its club's moves and strings. Every clip is a two-handed one (both hands
## on the haft through all of it, measured: `_shots_tmp/troll_clips.gd`),
## each played to its end so the club is seen to come back.
func _set_moves() -> void:
	# (parts cut to the swing and its follow-through: the batter's set-up and
	# his bat dropped and the run after it, the knee string's settling, left
	# out; blow moments measured, `_shots_tmp/troll_clips2.gd`)
	_hand_move(T_CHOP, &"CR_Heavy1", Vector3(0.9, 0.0, 0.97), 1.35, _club_spec)
	_hand_move(T_SWING, &"CR_TR_Homerun", Vector3(1.0, 0.12, 0.5), 1.4, _club_spec)
	_hand_move(T_BAT, &"CR_TR_BatSingle", Vector3(1.0, 0.15, 0.68), 0.9, _club_spec)
	_hand_move(T_BAT2, &"CR_TR_BatDouble", Vector3(1.0, 0.2, 0.72), 1.0, _club_spec)
	_hand_move(T_SCOOP, &"CR_TR_KettleSwing", Vector3(0.9, 0.0, 0.45), 1.1, _club_spec)
	_hand_move(T_BUTT, &"CR_TR_ButtSmash", Vector3(1.0, 0.2, 0.62), 0.7, _club_spec)
	_hand_move(T_KNEES, &"CR_TR_KneeJab", Vector3(1.05, 0.12, 0.76), 0.6, _club_spec + "|" + KNEES,
			[0.22, 0.41, 0.54, 0.67])
	_special(T_REEL, &"CR_Stun", Vector3(1.25, 0.02, 0.48))
	_special(T_TOTTER, &"CR_Parry2HHit", Vector3(0.85, 0.0, 0.95))
	_special(T_STAGGER, &"CR_GS_Impact", Vector3(0.8, 0.0, 0.96))
	# heavy up, then all of it at once (no glow: it is wood)
	_slow_to[T_CHOP] = 1.05
	_snap[T_CHOP] = 1.6
	_slow_to[T_SWING] = 1.15
	_snap[T_SWING] = 1.4
	_slow_to[T_BAT] = 0.7
	_slow_to[T_BAT2] = 0.75
	_slow_to[T_SCOOP] = 0.8
	_slow_to[T_BUTT] = 0.55
	_slow_to[T_KNEES] = 0.7
	_slow_to[LEAP] = 0.75
	# held at the top now and then (Elden Ring's delayed swings)
	_holds[T_CHOP] = [0.45, 0.4, 0.95, 0.25]
	_holds[T_SWING] = [0.4, 0.35, 0.8, 0.25]
	_holds[T_BAT2] = [0.25, 0.3, 0.6, 0.25]
	_kinds[T_CHOP] = &"crush"
	_kinds[T_SWING] = &"crush"
	_kinds[LEAP] = &"crush"
	# its strings, each move's end running into the next's start: a swing's
	# follow-through into the next swing's back-swing, the scoop's club high
	# over its head into the chop down
	_hand_combos = [
		# two: a swing across, then the chop into the ground
		{"name": &"swing_chop", "moves": [T_BAT, T_CHOP], "fells": [1], "weight": 1.0},
		# two: up from between its legs, then straight down
		{"name": &"scoop_chop", "moves": [T_SCOOP, T_CHOP], "fells": [1], "weight": 1.0},
		# three: the batter's swings, the last the great one
		{"name": &"batter", "moves": [T_BAT, T_BAT2, T_SWING], "fells": [2], "weight": 1.0},
		# three: the butt jabbed, the scoop, the chop
		{"name": &"butt_scoop_chop", "moves": [T_BUTT, T_SCOOP, T_CHOP], "fells": [2], "weight": 0.9},
		# four: a swing and three knees
		{"name": &"knees", "moves": [T_KNEES], "fells": [0], "weight": 0.8},
		# four, enraged only: two swings, the scoop, the chop
		{"name": &"storm", "moves": [T_BAT, T_BAT2, T_SCOOP, T_CHOP], "fells": [3], "weight": 1.2, "rage_only": true},
	]


#region The club (every peer)
## The club in its right hand, laid along its grip each frame.
func _make_club() -> void:
	if _skeleton == null or _hand < 0:
		return
	var scene := load(CLUB_FILE) as PackedScene
	if scene == null:
		return
	# (held off its body's tree, on its skeleton from outside: what is laid
	# over all of the body — the rage's red, the green of its healing — is not
	# laid on the wood)
	_club_hold = BoneAttachment3D.new()
	_club_hold.name = "TrollClubHold"
	add_child(_club_hold)
	_club_hold.use_external_skeleton = true
	_club_hold.external_skeleton = _club_hold.get_path_to(_skeleton)
	_club_hold.bone_name = "R_wrist_joint"
	_club = Node3D.new()
	_club.name = "TrollClub"
	_club_hold.add_child(_club)
	var model := scene.instantiate() as Node3D
	model.scale = Vector3.ONE * club_scale
	_club.add_child(model)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/dungeon/forest_glade/lp_solid.gdshader")
	mat.set_shader_parameter("foot_dark", 0.0)
	mat.set_shader_parameter("bright", 1.0)
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		mi.material_override = mat
	_club.visible = _grip_learnt


## Every peer: the line of its grip read off `CR_HeavyIdle`'s first pose
## (both hands on the haft), in its right hand's frame; its club's blows
## set out along it.
func _learn_grip() -> void:
	if _anim == null or _skeleton == null:
		return
	var player := _anim.get(&"_player") as AnimationPlayer
	var r := _skeleton.find_bone("R_wrist_joint")
	var l := _skeleton.find_bone("L_wrist_joint")
	if player == null or r < 0 or l < 0 or not player.has_animation(&"CR_HeavyIdle"):
		return
	var was := player.current_animation
	player.play(&"CR_HeavyIdle")
	player.seek(0.0, true)
	var rp: Transform3D = _anim.call(&"_posed", r)
	var lp: Transform3D = _anim.call(&"_posed", l)
	player.stop()
	if not was.is_empty():
		player.play(was)
	var span := rp.origin - lp.origin
	if span.length() < 0.05:
		return
	_grip_local = (rp.basis.inverse() * span).normalized()
	_grip_learnt = true
	var tip := _grip_local * club_reach
	_club_spec = "R_wrist_joint>R_wrist_joint@%.4f,%.4f,%.4f:%.2f" % [tip.x, tip.y, tip.z, club_radius]
	weapon_bone = &"R_wrist_joint"
	weapon_tip = tip


## Every peer: the club laid along the line from its left hand to its right
## while both hold it (learnt in its right hand's own frame), the head out past
## its right hand; its blows reach to the head.
func _lay_club() -> void:
	if _club == null or _skeleton == null or _club_dropped:
		return
	var r := _skeleton.find_bone("R_wrist_joint")
	var l := _skeleton.find_bone("L_wrist_joint")
	if r < 0 or l < 0:
		return
	var rp := _skeleton.get_bone_global_pose(r)
	var lp := _skeleton.get_bone_global_pose(l)
	var span := rp.origin - lp.origin
	if span.length() < 0.42 and span.length() > 0.05:
		var local := (rp.basis.inverse() * span).normalized()
		_grip_local = local if not _grip_learnt else _grip_local.slerp(local, 0.08).normalized()
		if not _grip_learnt:
			_grip_learnt = true
			_club.visible = true
			_reach_club()
	if not _grip_learnt:
		return
	var up := _grip_local
	var side := up.cross(Vector3.FORWARD if absf(up.z) < 0.9 else Vector3.RIGHT).normalized()
	_club.transform = Transform3D(Basis(side, up, side.cross(up)).orthonormalized(), Vector3.ZERO)


## Its blows out to the club's head, the way its grip runs.
func _reach_club() -> void:
	weapon_bone = &"R_wrist_joint"
	weapon_tip = _grip_local * club_reach
	for what: int in _limbs_of.keys():
		for st: Array in _limbs_of[what]:
			if String(st[0]) == "R_wrist_joint" and String(st[1]) == "R_wrist_joint" and bool(st[4]):
				st[2] = _grip_local * club_reach


## Where the club's head is now.
func _club_head() -> Vector3:
	if _club == null or not _grip_learnt:
		return _weapon_tip_at()
	return _club.global_transform * (Vector3.UP * club_reach)


## Every peer: the club let go as it falls, down onto the ground beside it.
func _drop_club() -> void:
	if _club == null or _club_dropped or not is_inside_tree():
		return
	_club_dropped = true
	# out of its hand where it is, then down flat on the ground before it
	var t := _club.global_transform
	_club.top_level = true
	_club.global_transform = t
	var size := t.basis.get_scale().x
	var floor_y := global_position.y
	var side := _forward().cross(Vector3.UP).normalized()
	var flat := Basis(side, -PI * 0.5) * Basis(Vector3.UP, randf_range(-0.6, 0.6))
	var land := Transform3D(flat.scaled(Vector3.ONE * size),
			Vector3(t.origin.x, floor_y + 0.1 * size, t.origin.z) + _forward() * 0.3 * size)
	var tw := _club.create_tween()
	tw.tween_property(_club, "global_transform", land, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		Sfx.play_any(self, [SOUNDS + "club_ground_1.wav", SOUNDS + "club_ground_3.wav"], self, 0.8, -4.0)
		_ground_dust(land.origin, 0.9))
	tw.tween_interval(14.0)
	tw.tween_callback(_club.queue_free)
#endregion


#region Every peer: what is heard and seen of its weight
func _process(delta: float) -> void:
	super(delta)
	_lay_club()
	if act_serial != _seen_serial:
		_seen_serial = act_serial
		_seen_clock = 0.0
		_on_move_shown()
	else:
		_seen_clock += delta
	_whoosh()
	_club_ground(delta)
	if act_serial != _held_serial:
		_held_serial = act_serial
		_held_clock = 0.0
		if act == PICK:
			var at := global_position + _forward() * 0.9 * visual_scale
			GroundFx.eruption(Blood.world_of(self), at, 0.5)
		elif act != HURL:
			_show_held(false)
	else:
		_held_clock += delta
	if act == PICK and _held_clock >= 0.35 and not is_dead:
		_show_held(true)
	if _held != null and _held.visible:
		_held.global_position = _hand_at() + Vector3.UP * 0.18 * visual_scale
	if is_dead:
		_show_held(false)
		_drop_club_later()
	_show_healing(delta)
	_bleed(delta)


## Every peer: a drop of blood off one of its wounds now and then.
func _bleed(delta: float) -> void:
	if _wound_marks.is_empty() or is_dead:
		return
	_drip_in -= delta
	if _drip_in > 0.0:
		return
	_drip_in = randf_range(0.25, 0.7) / float(_wound_marks.size())
	var mark := _wound_marks[randi() % _wound_marks.size()]
	if not is_instance_valid(mark) or not mark.is_inside_tree():
		return
	SkillFx.burst(Blood.world_of(self), mark.global_position, Color(0.45, 0.02, 0.015), 3, Vector2(0.2, 0.6),
			Vector3.DOWN, 30.0, Vector2(0.03, 0.05), Vector3(0, -9.0, 0), 0.6)


var _drop_in: float = -1.0


## Every peer: the club slips from its hands partway down.
func _drop_club_later() -> void:
	if _club_dropped:
		return
	if _drop_in < 0.0:
		_drop_in = 0.55
	_drop_in -= get_process_delta_time()
	if _drop_in <= 0.0:
		_drop_club()


## Every peer, as a move begins: its breath and its strain.
func _on_move_shown() -> void:
	if is_dead:
		return
	if act == T_CHOP or act == T_SWING or act == LEAP or act == T_SCOOP:
		Sfx.play_any(self, [SOUNDS + "strain_rise.wav", SOUNDS + "grunt_2.wav"], self, randf_range(0.85, 0.95), -6.0)
	elif act == T_REEL or act == T_STAGGER:
		Sfx.play_any(self, [SOUNDS + "grunt_1.wav", SOUNDS + "grunt_3.wav"], self, randf_range(0.8, 0.9), -4.0)


## Every peer: the club heard through the air just before each of its blows.
func _whoosh() -> void:
	if is_dead or not _strikes().has(act):
		return
	var ms := _blow_moments(act)
	for i in ms.size():
		var key := act_serial * 16 + i
		if key <= _whooshed:
			continue
		if _seen_clock >= ms[i] - 0.14:
			_whooshed = key
			var heavy := act == T_CHOP or act == T_SWING or act == LEAP or act == T_SCOOP or act == T_BAT2
			Sfx.play(self, SOUNDS + ("whoosh_heavy.wav" if heavy else "whoosh_light.wav"), self,
					Vector3.UP * 1.6 * visual_scale, randf_range(0.82, 0.92) if heavy else randf_range(0.9, 1.0), -3.0)
		break


## Every peer: where the club's head comes down into the ground, the thud,
## dust and grit thrown up, the view shaken (no ring, no stop).
func _club_ground(delta: float) -> void:
	_dust_wait = maxf(_dust_wait - delta, 0.0)
	if _club == null or not _grip_learnt or _club_dropped or delta <= 0.0:
		_tip_last = Vector3.INF
		return
	var tip := _club_head()
	var was := _tip_last
	_tip_last = tip
	if was == Vector3.INF or _dust_wait > 0.0 or not _strikes().has(act):
		return
	var ground := global_position.y
	var falling := (was.y - tip.y) / delta
	if tip.y <= ground + dust_touch and was.y > ground + dust_touch and falling > dust_fall:
		_dust_wait = 0.4
		ground_dusts += 1
		var power := clampf(falling / 9.0, 0.8, 1.6)
		var at := Vector3(tip.x, ground + 0.05, tip.z)
		_ground_dust(at, power)
		Sfx.play_any(self, [SOUNDS + "club_ground_1.wav", SOUNDS + "club_ground_2.wav",
				SOUNDS + "club_ground_3.wav", SOUNDS + "club_ground_4.wav"], self, randf_range(0.85, 0.95), 0.0)
		WindBlast.shake(self, 0.07 * power, 0.3, 14.0)


func _ground_dust(at: Vector3, power: float) -> void:
	GroundFx.weapon_dust(Blood.world_of(self), at, power)
#endregion


#region Host: the moves' weight
func _blow_reached(who: Node3D, what: int) -> void:
	super(who, what)
	_landed_serial = act_serial


func _own_move(delta: float) -> bool:
	_hurl_wait = maxf(_hurl_wait - delta, 0.0)
	var gap := _distance_to(_quarry)
	if hurl_on and _hurl_wait <= 0.0 and gap >= hurl_from and gap <= hurl_to and not _quarry_down() \
			and stamina >= attack_cost:
		mode = Mode.FIGHT
		_face(_quarry.global_position - global_position, 1.0, 50.0)
		_begin(PICK)
		return true
	return super(delta)


func _after(what: int) -> void:
	if what == PICK:
		if _quarry != null:
			_face(_quarry.global_position - global_position, 1.0, 50.0)
		_hurled = false
		_begin(HURL)
		return
	if what == HURL:
		_hurl_wait = _rng.randf_range(hurl_cooldown.x, hurl_cooldown.y)
	# a great swing that found nothing: carried round after the club, it
	# stands a moment off its balance, open
	var missed := MISS_REELS.has(what) and _landed_serial != act_serial and not is_dead and _decides()
	if missed:
		_hand_combo = -1
	super(what)
	if missed and act == Act.NONE and not is_dead:
		reels += 1
		velocity.x = 0.0
		velocity.z = 0.0
		_begin(T_REEL)
		return
	if what == T_REEL or what == T_STAGGER:
		_cooldown = maxf(_cooldown, 0.6)


func _run_act(delta: float) -> void:
	super(delta)
	if is_dead or not _decides():
		_run_cracks(delta)
		return
	if act == HURL:
		if _quarry != null and _act_time < _hurl_at:
			_face(_quarry.global_position - global_position, delta, turn_speed * 2.0)
		if not _hurled and _act_time >= _hurl_at:
			_hurled = true
			_release()
	if act == T_REEL or act == T_TOTTER or act == T_STAGGER:
		velocity.x = move_toward(velocity.x, 0.0, acceleration * delta)
		velocity.z = move_toward(velocity.z, 0.0, acceleration * delta)
	# the club down on the ground: it splits along a line out from it
	if (CRACKS.has(act) or act == LEAP) and _cracked_serial != act_serial:
		var ms := _blow_moments(act)
		if not ms.is_empty() and _act_time >= ms[ms.size() - 1]:
			_cracked_serial = act_serial
			_crack()
	_run_cracks(delta)


## Host: a crack let go from the club's head along the way it faces (at him,
## if he is near enough in front).
func _crack() -> void:
	var head := _club_head()
	var from := Vector3(head.x, global_position.y, head.z)
	var way := _forward()
	if _quarry != null:
		var to := _quarry.global_position - from
		to.y = 0.0
		if to.length_squared() > 0.25 and to.normalized().dot(_forward()) > 0.5:
			way = to.normalized()
	cracks_made += 1
	_cracks.append(GroundCrack.new(from, way, crack_reach, crack_speed, crack_width, 7000000 + act_serial))
	if is_inside_tree() and multiplayer.has_multiplayer_peer():
		net_crack.rpc(from, way)
	else:
		net_crack(from, way)


func _run_cracks(delta: float) -> void:
	if not _decides():
		return
	for i in range(_cracks.size() - 1, -1, -1):
		var c: GroundCrack = _cracks[i]
		for who: Node3D in c.reached(delta, get_tree()):
			who.call(&"receive_blow", hit_damage * crack_share * _blow_worth(0), self, 0, 1, c.id, false, &"ground")
		if c.done():
			_cracks.remove_at(i)


@rpc("authority", "call_local", "reliable")
func net_crack(from: Vector3, way: Vector3) -> void:
	GroundCrack.show(self, from, way, crack_reach, crack_speed)
#endregion


#region Host: its balance and its body
## Blows fill its stance; partway it rocks back a step, further it is knocked
## off it and reels (before it goes down on a knee, full).
func _add_stance(amount: float) -> void:
	super(amount)
	if is_dead or stance <= 0.0 or act == STANCE or act == PIECES or act == RAGE or act == LEAP:
		return
	var share := stance_taken / stance
	if _rocked < 2 and share >= STAGGER_AT:
		_rocked = 2
		staggers += 1
		_hand_combo = -1
		_sweeps.clear()
		velocity.x = 0.0
		velocity.z = 0.0
		_begin(T_STAGGER)
	elif _rocked < 1 and share >= TOTTER_AT and (act == Act.NONE or act == T_REEL):
		_rocked = 1
		totters += 1
		_begin(T_TOTTER)


func _receive(damage: float, at: Vector3, blow: Vector3, from: Node3D, magic: bool = false) -> bool:
	var bled := super(damage, at, blow, from, magic)
	if stance_taken <= 0.0 and act != STANCE:
		_rocked = 0
	if bled and not is_dead and wounds < WOUND_AT.size() and health <= max_health * float(WOUND_AT[wounds]):
		_wound(at, blow)
	return bled


## Host: a wound opens where it was struck; it is slower, its balance breaks
## sooner. Seen by all ([method net_wound]).
func _wound(at: Vector3, blow: Vector3) -> void:
	wounds += 1
	# slower by each (on top of whatever its rage has made of its pace)
	var keep := (1.0 - wound_slow * float(wounds)) / (1.0 - wound_slow * float(wounds - 1))
	speed *= keep
	chase_speed *= keep
	close_speed *= keep
	stance = _stance0 * (1.0 - wound_stance * float(wounds))
	if stance_taken >= stance and act != STANCE:
		# what it has already taken is more than its wounded balance holds
		_break_stance()
	var bone := _nearest_bone(at)
	if bone < 0:
		return
	var b := _skeleton.global_transform * _skeleton.get_bone_global_pose(bone)
	var local := b.affine_inverse() * at
	var way := b.basis.inverse() * (-blow if blow.length_squared() > 0.0001 else -_forward())
	if is_inside_tree() and multiplayer.has_multiplayer_peer():
		net_wound.rpc(String(_skeleton.get_bone_name(bone)), local, way, wounds)
	else:
		net_wound(String(_skeleton.get_bone_name(bone)), local, way, wounds)


## The body's bone nearest a point (a wound is laid on it).
func _nearest_bone(at: Vector3) -> int:
	if _skeleton == null:
		return -1
	var best := -1
	var near := INF
	for name_of: String in ["chest_joint", "waist_joint", "pelvis_joint", "L_shoulder_joint", "R_shoulder_joint",
			"L_elbow_joint", "R_elbow_joint", "L_thigh_joint", "R_thigh_joint", "L_knee_joint", "R_knee_joint",
			"neck_joint"]:
		var i := _skeleton.find_bone(name_of)
		if i < 0:
			continue
		var p := (_skeleton.global_transform * _skeleton.get_bone_global_pose(i)).origin
		var d := p.distance_squared_to(at)
		if d < near:
			near = d
			best = i
	return best


## Every peer: a wound opened on bone `bone_name`, at `local` in its frame,
## facing `way` (whence the blow came); the deeper the more it has.
@rpc("authority", "call_local", "reliable")
func net_wound(bone_name: String, local: Vector3, way: Vector3, count: int) -> void:
	if _skeleton == null or _skeleton.find_bone(bone_name) < 0:
		return
	if not has_meta(&"wound_layer"):
		set_meta(&"wound_layer", true)
		for m in find_children("*", "GeometryInstance3D", true, false):
			var g := m as GeometryInstance3D
			if not (g is GPUParticles3D) and not (g is Label3D) and not (_club != null and _club.is_ancestor_of(g)):
				g.layers |= Blood.WOUND_LAYER
	var hold := BoneAttachment3D.new()
	hold.bone_name = bone_name
	_skeleton.add_child(hold)
	var y := way.normalized() if way.length_squared() > 0.0001 else Vector3.FORWARD
	var z := Vector3.DOWN - y * y.dot(Vector3.DOWN)
	z = z.normalized() if z.length_squared() > 0.0001 else y.cross(Vector3.RIGHT).normalized()
	var x := y.cross(z).normalized()
	var s := 1.0 / maxf(visual_scale, 0.01)
	var deep := 1.0 + 0.25 * float(count - 1)
	var decal := Decal.new()
	decal.name = "Wound%d" % count
	decal.texture_albedo = Blood.wound_texture()
	decal.modulate = Color(0.5, 0.03, 0.02)
	decal.albedo_mix = 1.0
	decal.cull_mask = Blood.WOUND_LAYER
	# (in the bone's frame, which is the troll's size over: sized to a man's)
	# (deep through it: where a blow lands is taken on its body's axis, so the
	# box reaches out through the skin on the side it came from; the far
	# side's skin faces away and is faded out)
	decal.size = Vector3(0.6 * deep, 1.5, 0.9 * deep) * s * visual_scale / 1.6
	decal.normal_fade = 0.4
	hold.add_child(decal)
	decal.transform = Transform3D(Basis(x, y, z), local + y * 0.25)
	# it bleeds from there from now on, a drop now and then
	var mark := Marker3D.new()
	mark.name = "WoundAt%d" % count
	hold.add_child(mark)
	mark.position = local
	_wound_marks.append(mark)
	# blood out of it as it opens, and the grunt of it
	var world := Blood.world_of(self)
	var at := _skeleton.global_transform * _skeleton.get_bone_global_pose(_skeleton.find_bone(bone_name)) * local
	if world != null:
		SkillFx.burst(world, at, Color(0.5, 0.03, 0.02), 18, Vector2(1.0, 3.2), _skeleton.global_basis * y, 50.0,
				Vector2(0.03, 0.07), Vector3(0, -9.0, 0), 0.7)
	Sfx.play_any(self, [SOUNDS + "grunt_1.wav", SOUNDS + "grunt_3.wav"], self, randf_range(0.78, 0.86), -3.0)
#endregion


#region The boulder (off unless `hurl_on`)
## Host: the boulder out of its hands, on an arc onto where he will be.
func _release() -> void:
	if _quarry == null:
		return
	var from := _hand_at() + Vector3.UP * 0.2
	var target := _quarry.global_position + Vector3.UP * 0.9
	var gap := Vector3(target.x - from.x, 0.0, target.z - from.z).length()
	var flight := clampf(gap / 16.0, 0.4, 1.2)
	if _quarry is CharacterBody3D:
		var v := (_quarry as CharacterBody3D).velocity
		target += Vector3(v.x, 0.0, v.z) * flight * 0.5
	var throw_v := (target - from) / flight + Vector3.UP * 0.5 * GoblinShot.GRAVITY * flight
	var worth := hit_damage * boulder_share * _blow_worth(HURL)
	if is_inside_tree() and multiplayer.has_multiplayer_peer():
		net_hurl.rpc(from, throw_v, worth, act_serial)
	else:
		net_hurl(from, throw_v, worth, act_serial)


@rpc("authority", "call_local", "reliable")
func net_hurl(from: Vector3, v: Vector3, worth: float, id: int) -> void:
	_show_held(false)
	GoblinShot.throw(Blood.world_of(self), from, v, GoblinShot.Kind.BOULDER, worth, self, _decides(), id * 100 + 7)


func _hand_at() -> Vector3:
	if _skeleton != null and _hand >= 0:
		return _skeleton.global_transform * _skeleton.get_bone_global_pose(_hand).origin
	return global_position + Vector3.UP * 2.0 * visual_scale


func _show_held(on: bool) -> void:
	if _held == null:
		if not on:
			return
		_held = MeshInstance3D.new()
		var m := SphereMesh.new()
		m.radius = 0.42
		m.height = 0.76
		m.radial_segments = 7
		m.rings = 4
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.4, 0.37, 0.33)
		mat.roughness = 1.0
		m.material = mat
		_held.mesh = m
		_held.top_level = true
		_held.scale = Vector3(1.1, 0.85, 1.0)
		add_child(_held)
	_held.visible = on
#endregion


#region Its wounds closing
func _show_healing(delta: float) -> void:
	var on := healing and not is_dead and body != null and act != PIECES
	if on != _heal_shown:
		_heal_shown = on
		if body != null:
			if _heal_glow == null:
				_heal_glow = StandardMaterial3D.new()
				_heal_glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				_heal_glow.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
				_heal_glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				_heal_glow.albedo_color = Color(regen_tint, 0.0)
			for mi: MeshInstance3D in body.find_children("*", "MeshInstance3D", true, false):
				if _club != null and _club.is_ancestor_of(mi):
					continue
				mi.material_overlay = _heal_glow if on else null
	if not on:
		return
	# A slow green pulse over it, and motes rising off its wounds.
	_heal_glow.albedo_color.a = 0.05 + 0.05 * (0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * 3.0))
	_mote_clock += delta
	if _mote_clock < 0.2:
		return
	_mote_clock = 0.0
	var at := global_position + Vector3.UP * randf_range(0.5, 1.7) * visual_scale \
			+ Vector3(randf_range(-0.35, 0.35), 0.0, randf_range(-0.35, 0.35)) * visual_scale
	SkillFx.burst(Blood.world_of(self), at, regen_tint, 6, Vector2(0.3, 0.9), Vector3.UP, 35.0,
			Vector2(0.045, 0.09), Vector3(0, 1.6, 0), 1.0)


func _physics_process(delta: float) -> void:
	super(delta)
	if is_dead or not _decides():
		return
	if raging and not _rage_eased:
		# its rage quicker, but still a heavy thing: a breath between strings
		_rage_eased = true
		attack_cooldown = Vector2(1.0, 1.7)
	var aff := Afflictions.of(self, false)
	if aff != null and (aff.is_burning() or aff.is_chilled()):
		_stopped_for = regen_stopped
	_stopped_for = maxf(_stopped_for - delta, 0.0)
	var heal := _stopped_for <= 0.0 and health < max_health and act != PIECES
	if heal:
		health = minf(health + max_health * regen * delta, max_health)
	if heal != healing:
		if is_inside_tree() and multiplayer.has_multiplayer_peer():
			net_regen.rpc(heal)
		else:
			net_regen(heal)


@rpc("authority", "call_local", "reliable")
func net_regen(on: bool) -> void:
	healing = on


## Burnt or frozen by a skill: its wounds stop closing.
func react(kind: StringName, from: Node3D = null, push: Vector3 = Vector3.ZERO) -> void:
	if kind == &"burn" or kind == &"chill" or kind == &"freeze":
		_stopped_for = regen_stopped
	super(kind, from, push)
#endregion
