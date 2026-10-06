class_name SkeletonLord
extends ShieldFighter

## The skeletons' lord: Polysplit's "Skeleton, all in one" (the pack's kit of
## all three skeletons' parts) made a boss, bigger than they are, that fights
## as each of them in turn (the user's pick, 2026-10-06).
##
## * **Sword and shield** (`Stance.SWORD`), the warrior's way ([ShieldFighter]):
##   up close it walks in behind the shield, catches what comes at its front,
##   and answers with the bash and the sword.
## * **The bow** (`Stance.BOW`): further off than `bow_over`, it stops, turns
##   to him and after `bow_after` seconds puts sword and shield away, takes
##   the bow and shoots, the archer's shot (`CR_BowShot`, the string in its
##   fingers); come within `sword_under`, it takes sword and shield again. No
##   shield up with the bow.
## * **The staff** (`Stance.STAFF`, at `staff_at` of its health, for good): it
##   calls the dead up round it and takes the mage's staff, the shield kept:
##   bolts that bend after him, the ground erupting under him when he stands
##   still, a blast that throws him off when he is close, and the bash alone
##   between. Every `raise_cooldown` more of the dead.
##
## Which it holds is `stance`, sent to every peer; each shows the arms of it.

enum Stance { SWORD, BOW, STAFF }

@export_group("Stances")
@export var bow_over: float = 10.0
@export var bow_after: float = 0.5
@export var sword_under: float = 6.0
@export_range(0.0, 1.0) var staff_at: float = 0.5
## Shown whatever it holds, and what each stance holds besides.
@export var worn: PackedStringArray = PackedStringArray(["Skeleton_Head", "Skeleton_Top", "Skeleton_Bottom",
		"Skeleton_Warrior_Helm", "Skeleton_Warrior_Top", "Skeleton_Mage_Bottom", "Skeleton_Archer_Strap",
		"Skeleton_Archer_ArrowQuiver"])
@export var sword_arms: PackedStringArray = PackedStringArray(["Skeleton_Warrior_Sword", "Skeleton_Warrior_Shield"])
@export var bow_arms: PackedStringArray = PackedStringArray(["Skeleton_Archer_Bow"])
@export var staff_arms: PackedStringArray = PackedStringArray(["Skeleton_Mage_Staff", "Skeleton_Warrior_Shield"])

@export_group("Bow")
@export var shot_clip: StringName = &"CR_BowShot"
@export var shot_rate: float = 1.3
@export var nock_at: float = 0.63
@export var loose_at: float = 1.45
@export var arrow_speed: float = 36.0
@export var arrow_gravity: float = 6.0
@export var arrow_share: float = 0.8
@export var shot_gap: Vector2 = Vector2(0.4, 0.9)
@export var shoot_range: float = 26.0
@export var arrow_scene: PackedScene = preload("res://scenes/props/arrow.tscn")

@export_group("Staff")
@export var bolt_scene: PackedScene = preload("res://scenes/fx/spell_bolt.tscn")
@export var bolt_speed: float = 20.0
@export var bolt_colour: Color = Color(0.7, 0.45, 1.0)
@export var staff_tip: Vector3 = Vector3(-0.96, 0.0, 0.0)
@export var cast_gap: Vector2 = Vector2(0.8, 1.6)
@export var hex_radius: float = 2.0
@export var hex_delay: float = 1.0
@export var hex_cooldown: float = 4.0
@export var blast_under: float = 3.6
@export var blast_radius: float = 4.0
@export var blast_push: float = 12.0
@export var blast_cooldown: float = 5.0
@export var raise_scene: PackedScene = preload("res://scenes/enemies/pack/skeleton.tscn")
@export var raise_count: int = 2
@export var raise_max: int = 3
@export var raise_cooldown: float = 16.0
@export var raise_clip: StringName = &"CR_Rise"

## Its own moves, numbered clear of the warrior's and the Brawler's.
const SWAP := 90
const SHOT := 91
const BOLT := 92
const HEX := 93
const BLAST := 94
const RAISE := 95
## [clip, rate, the moment (share of the clip) the spell goes]
const SPELLS := {
	BOLT: [&"CR_MG_Throw", 1.3, 0.40],
	HEX: [&"CR_MG_Ground", 1.25, 0.43],
	BLAST: [&"CR_MG_Blast", 1.35, 0.55],
	RAISE: [&"CR_MG_Raise", 1.1, 0.42],
}

## Replicated: what it holds.
var stance: int = Stance.SWORD
var _shown: int = -1
var _to: int = Stance.SWORD
var _swapped: bool = false
var _far_for: float = 0.0
var _cast_done: bool = false
var _loosed: bool = false
var _hex_wait: float = 0.0
var _blast_wait: float = 0.0
var _raise_wait: float = 0.0
var _raised: Array[Node] = []
var _seen_at: Array[Vector3] = []
var _seen_clock: float = 0.0
var _string: int = -1
var _hand: int = -1
var _equip: int = -1
var _string_rest: Vector3 = Vector3.ZERO
var _nocked: MeshInstance3D


func _ready() -> void:
	super()
	_moves_table[SWAP] = [&"CR_Block", 1.0, 0.0, 0.45]
	_moves_table[SHOT] = [shot_clip, shot_rate, 0.0, 1.0]
	for what: int in SPELLS:
		var spell: Array = SPELLS[what]
		_moves_table[what] = [spell[0], spell[1], 0.0, 1.0]
	leash_radius = maxf(leash_radius, shoot_range * 2.0)
	if _skeleton != null:
		_string = _skeleton.find_bone("stringJoint")
		_hand = _skeleton.find_bone("R_midFinger_joint1")
		_equip = _skeleton.find_bone("R_equip_joint")
		if _string >= 0:
			_string_rest = _skeleton.get_bone_rest(_string).origin
	if body != null:
		_nocked = body.find_child("Skeleton_Archer_Arrow", true, false) as MeshInstance3D
	_show_stance()


#region What it holds
func _show_stance() -> void:
	_shown = stance
	bash_follows = stance != Stance.STAFF
	if body == null:
		return
	var on := {}
	for n in worn:
		on[n] = true
	for n in ([sword_arms, bow_arms, staff_arms][clampi(stance, 0, 2)] as PackedStringArray):
		on[n] = true
	for mi: MeshInstance3D in body.find_children("*", "MeshInstance3D", true, false):
		if mi == _nocked:
			mi.visible = false
			continue
		mi.visible = on.has(String(mi.name))


func shield_up() -> bool:
	return stance != Stance.BOW and super()


## Puts down what it holds and takes up `to` (the change shown halfway).
func _swap(to: int) -> void:
	_to = to
	_swapped = false
	velocity.x = 0.0
	velocity.z = 0.0
	if to == Stance.STAFF:
		# The staff taken up for good: the dead called up with it.
		_cast_done = false
		_begin(RAISE)
	else:
		_begin(SWAP)


@rpc("authority", "call_local", "unreliable")
func net_swap_puff(at: Vector3) -> void:
	var into := Blood.world_of(self)
	DustRing.burst(into, at, 0.6 * visual_scale)
	SkillFx.flash(into, at, bolt_colour, 0.3, 0.2)
#endregion


#region Thinking
func _think(delta: float) -> void:
	_hex_wait = maxf(_hex_wait - delta, 0.0)
	_blast_wait = maxf(_blast_wait - delta, 0.0)
	_raise_wait = maxf(_raise_wait - delta, 0.0)
	if mode == Mode.GUARD or mode == Mode.RETURN or is_dead:
		super(delta)
		return
	if act == SWAP or act == SHOT or SPELLS.has(act):
		return
	if act != Act.NONE:
		super(delta)
		return
	_quarry = _pick_quarry()
	if _quarry == null:
		_go_home()
		return
	_watch(delta)
	if stance != Stance.STAFF and health <= max_health * staff_at:
		_swap(Stance.STAFF)
		return
	var gap := _distance_to(_quarry)
	match stance:
		Stance.SWORD:
			if gap > bow_over:
				# Kept off: it stops, turns to him and takes the bow.
				_far_for += delta
				mode = Mode.FIGHT
				_face(_quarry.global_position - global_position, delta, turn_speed)
				_slow(delta, 4.0)
				if _far_for >= bow_after:
					_far_for = 0.0
					_swap(Stance.BOW)
				return
			_far_for = 0.0
			super(delta)
		Stance.BOW:
			if gap < sword_under:
				_swap(Stance.SWORD)
				return
			_bow_think(delta, gap)
		Stance.STAFF:
			_staff_think(delta, gap)


func _bow_think(delta: float, gap: float) -> void:
	var to := _quarry.global_position - global_position
	to.y = 0.0
	if gap > shoot_range:
		mode = Mode.CHASE
		_move_towards(_quarry.global_position, speed * 1.4, delta)
		return
	mode = Mode.FIGHT
	_face(to, delta, turn_speed * 2.0)
	_slow(delta, 4.0)
	if _cooldown <= 0.0 and _forward().dot(to.normalized()) > 0.9:
		_loosed = false
		_begin(SHOT)


func _staff_think(delta: float, gap: float) -> void:
	var to := _quarry.global_position - global_position
	to.y = 0.0
	if gap <= blast_under:
		mode = Mode.FIGHT
		if _blast_wait <= 0.0 and not _quarry_down():
			_face(to, delta, 50.0)
			_cast(BLAST)
			return
		# Close and the blast not ready: the warrior's way, the bash alone.
		super._think(delta)
		return
	if gap > 14.0:
		mode = Mode.CHASE
		_move_towards(_quarry.global_position, shield_pace, delta)
		_face(to, delta, turn_speed)
		return
	mode = Mode.FIGHT
	_face(to, delta, turn_speed * 2.0)
	_slow(delta, 4.0)
	if _cooldown > 0.0 or _forward().dot(to.normalized()) < 0.85:
		return
	if _raise_wait <= 0.0 and _standing_raised() < raise_max:
		_cast(RAISE)
	elif _hex_wait <= 0.0 and (_standing_still() or _rng.randf() < 0.3):
		_cast(HEX)
	else:
		_cast(BOLT)


func _begin_attack() -> void:
	if stance == Stance.STAFF:
		_begin_bash()
		return
	super()


func _cast(what: int) -> void:
	_cast_done = false
	velocity.x = 0.0
	velocity.z = 0.0
	_begin(what)
#endregion


#region Acting
func _run_act(delta: float) -> void:
	super(delta)
	if _quarry == null or not (act == SWAP or act == SHOT or SPELLS.has(act)):
		return
	velocity.x = 0.0
	velocity.z = 0.0
	if act == SWAP:
		if not _swapped and _act_time >= _act_length * 0.5:
			_swapped = true
			_take_up(_to)
		return
	if act == SHOT:
		var clip_t := _clip_time(act, _act_time)
		if clip_t < loose_at:
			_face(_quarry.global_position - global_position, delta, turn_speed * 2.0)
		elif not _loosed:
			_loosed = true
			_loose()
		return
	var spell: Array = SPELLS[act]
	var share := _clip_time(act, _act_time) / maxf(_anim.clip_length(spell[0]), 0.001)
	if share < float(spell[2]):
		_face(_quarry.global_position - global_position, delta, turn_speed * 2.0)
	elif not _cast_done:
		_cast_done = true
		if _decides():
			match act:
				BOLT:
					_bolt()
				HEX:
					_hex()
				BLAST:
					_blast()
				RAISE:
					if stance != Stance.STAFF:
						_take_up(Stance.STAFF)
					_raise()


func _take_up(to: int) -> void:
	stance = to
	_show_stance()
	if _decides():
		net_swap_puff.rpc(_hand_point())


func _after(what: int) -> void:
	match what:
		SHOT:
			_cooldown = _rng.randf_range(shot_gap.x, shot_gap.y)
		BOLT, HEX:
			_cooldown = _rng.randf_range(cast_gap.x, cast_gap.y)
			if what == HEX:
				_hex_wait = hex_cooldown
		BLAST:
			_blast_wait = blast_cooldown
		RAISE:
			_raise_wait = raise_cooldown
	if what == SWAP or what == SHOT or SPELLS.has(what):
		_start(Act.NONE)
		return
	super(what)


func _process(delta: float) -> void:
	super(delta)
	if _shown != stance:
		_show_stance()
	if _skeleton == null or _string < 0:
		return
	var drawn := false
	if act == SHOT and _anim != null and stance == Stance.BOW:
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
#endregion


#region The bow
func _loose() -> void:
	if not _decides() or _quarry == null:
		return
	var from := _hand_point()
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
	arrow.call(&"launch", shot, hit_damage * arrow_share, false, arrow_gravity, self)


func _hand_point() -> Vector3:
	if _skeleton == null or _hand < 0:
		return global_position + Vector3.UP * 1.6 * visual_scale
	return _skeleton.global_transform * _posed(_hand).origin
#endregion


#region The staff
func _crystal() -> Vector3:
	if _skeleton == null or _equip < 0:
		return global_position + Vector3.UP * 2.0 * visual_scale
	return _skeleton.global_transform * (_posed(_equip) * staff_tip)


func _bolt() -> void:
	var from := _crystal()
	var aim := (_quarry.global_position + Vector3.UP * 1.2 - from).normalized()
	net_bolt.rpc(from, aim * bolt_speed, _quarry.get_path())


@rpc("authority", "call_local", "reliable")
func net_bolt(from: Vector3, flight: Vector3, quarry: NodePath) -> void:
	var into := Blood.world_of(self)
	if into == null or bolt_scene == null:
		return
	var bolt := bolt_scene.instantiate() as Node3D
	bolt.set(&"against_heroes", true)
	bolt.set(&"glow_colour", bolt_colour)
	into.add_child(bolt)
	bolt.global_position = from
	bolt.call(&"launch", flight, hit_damage * 0.9, false, 0.0, self)
	var who := get_node_or_null(quarry) as Node3D
	if who != null and bolt.has_method(&"hunt"):
		bolt.call(&"hunt", who)


func _hex() -> void:
	net_hex.rpc(_quarry.global_position)


@rpc("authority", "call_local", "reliable")
func net_hex(at: Vector3) -> void:
	HexCircle.cast(Blood.world_of(self), at, self, hit_damage * 1.4, hex_radius, hex_delay)


func _blast() -> void:
	net_blast.rpc(global_position)
	for node in get_tree().get_nodes_in_group("player"):
		var who := node as Node3D
		if who == null or not who.has_method(&"receive_blow") or who.get("net_dead") == true:
			continue
		var off := who.global_position - global_position
		off.y = 0.0
		if off.length() > blast_radius:
			continue
		who.call(&"receive_blow", hit_damage * 1.2, self, 0, 2, act_serial * 3 + 1, true)
		var v: Variant = who.get("velocity")
		if v is Vector3:
			who.set("velocity", (v as Vector3) + off.normalized() * blast_push + Vector3.UP * 3.0)


@rpc("authority", "call_local", "reliable")
func net_blast(at: Vector3) -> void:
	var into := Blood.world_of(self)
	DustRing.burst(into, at, 2.6)
	GroundFx.eruption(into, at, 1.0)


func _raise() -> void:
	var into := get_parent()
	if into == null or raise_scene == null:
		return
	var side := _forward().cross(Vector3.UP).normalized()
	for i in raise_count:
		if _standing_raised() >= raise_max:
			break
		var risen := raise_scene.instantiate() as Node3D
		risen.name = "%s_raised_%d_%d" % [name, act_serial, i]
		var at := global_position + _forward() * 1.8 + side * (1.8 if i % 2 == 0 else -1.8)
		risen.set("band", band)
		risen.set("camp_centre", Vector3(at.x, 0.0, at.z))
		into.add_child(risen)
		risen.global_position = at
		risen.rotation.y = rotation.y
		_raised.append(risen)
		if risen.has_method(&"rise"):
			risen.call_deferred(&"rise", raise_clip, _quarry)
		GroundFx.eruption(Blood.world_of(self), at, 0.6)


func _standing_raised() -> int:
	var alive := 0
	for r in _raised:
		if is_instance_valid(r) and not bool(r.get("is_dead")):
			alive += 1
	return alive


func _watch(delta: float) -> void:
	_seen_clock += delta
	if _seen_clock < 0.25:
		return
	_seen_clock = 0.0
	_seen_at.append(_quarry.global_position)
	if _seen_at.size() > 6:
		_seen_at.pop_front()


func _standing_still() -> bool:
	return _seen_at.size() >= 6 and _seen_at[0].distance_to(_seen_at[-1]) < 1.0
#endregion


func _posed(idx: int) -> Transform3D:
	var t := Transform3D.IDENTITY
	var i := idx
	while i >= 0:
		var local := Transform3D(Basis(_skeleton.get_bone_pose_rotation(i)).scaled(_skeleton.get_bone_pose_scale(i)),
				_skeleton.get_bone_pose_position(i))
		t = local * t
		i = _skeleton.get_bone_parent(i)
	return t
