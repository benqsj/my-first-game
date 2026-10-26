class_name MageFighter
extends Brawler

## A caster that keeps the fight at arm's length of a spell: the skeleton
## mage of Polysplit's Biped Creatures (CREATURES_PACK.md), its own staff in
## its right fist, on the mage hero's casts carried onto the pack's skeleton
## (tools/creature_clips.gd, CR_MG_*).
##
## * **It keeps its distance** (`keep_from` to `keep_to`): further off it
##   walks in, closer it steps back, staff and face to him — it does not run.
## * **A bolt** (`CR_MG_Throw`): a ball of violet light from the crystal
##   ([SpellBolt], the mage hero's, turned on the heroes), slow and then
##   faster, bending after him; a roll takes him out of its way.
## * **The ground under him** (`CR_MG_Ground`): a rune circle flashes where
##   he stands ([BoneThorns]); `hex_delay` later bone spears burst up out of
##   it. It favours this when he has stood still.
## * **Bones thrown from afar** (`CR_SK_HandUp`, then `CR_SK_HandForward`; the
##   user's word 2026-10-26, as the elf's Frost Spears): ten pieces of its own
##   skeleton grow out of the air round its head ([BoneCrown]), and once all
##   are there they go at him one by one in the elf's beat ([BoneShard]).
## * **A great sword of light** over its head (`CR_SK_GreatSwordSpell`,
##   [SpiritSword]) moves with its staff, back and then over and down onto
##   the ground in front: a long reach, from `SpiritSword.strike_span`.
## * **A blade grown out of its staff** (the same swing, [StaffBlade]) when he
##   has come in nearer than it keeps him.
## * **Up close** (`blast_under`): it drives him off with a blast of the staff
##   (`CR_MG_Blast`, thrown back hard), and between blasts strikes with the
##   staff (its [Brawler] attacks) — only when he has come to it: it does not
##   walk in to strike.
## * **The dead rise** (`CR_SK_UpwardPull`): it calls bare skeletons up out
##   of the ground beside it (`raise_count` at a time, `raise_max` standing
##   at most).
## * **A bolt** (`CR_MG_Throw`) between the others, while they come round.

@export_group("Spells")
@export var bolt_scene: PackedScene = preload("res://scenes/fx/spell_bolt.tscn")
@export var bolt_speed: float = 20.0
@export var bolt_colour: Color = Color(0.7, 0.45, 1.0)
@export var keep_from: float = 7.0
@export var keep_to: float = 15.0
@export var hex_radius: float = 1.9
@export var hex_delay: float = 0.55
@export var hex_cooldown: float = 4.0
@export var blast_under: float = 3.2
@export var blast_radius: float = 3.6
@export var blast_push: float = 11.0
@export var blast_cooldown: float = 5.0
@export var raise_scene: PackedScene = preload("res://scenes/enemies/pack/skeleton.tscn")
@export var raise_count: int = 2
@export var raise_max: int = 2
@export var raise_cooldown: float = 14.0
@export var raise_clip: StringName = &"CR_Rise"
@export var sword_cooldown: float = 9.0
@export var blade_cooldown: float = 6.0
@export var volley_cooldown: float = 11.0
## Each thrown bone's worth, as a share of `hit_damage`, and its top speed.
@export var volley_share: float = 0.45
@export var volley_speed: float = 30.0

const BOLT := 71
const HEX := 72
const BLAST := 73
const RAISE := 74
const SWORD := 75
const BLADE := 76
const VOLLEY := 77
const FLING := 78
const SWING_CLIP := &"CR_SK_GreatSwordSpell"
## [clip, rate, the moment (clip s) the spell goes, faced on him till (clip s)
## (missing: the moment)]; the moment of a swing is where it lands.
const SPELLS := {
	BOLT: [&"CR_MG_Throw", 1.3, 0.0],
	HEX: [&"CR_MG_Ground", 1.25, 0.0],
	BLAST: [&"CR_MG_Blast", 1.35, 0.0],
	RAISE: [&"CR_SK_UpwardPull", 1.2, 0.0],
	SWORD: [SWING_CLIP, 1.0, 2.53, 1.3],
	BLADE: [SWING_CLIP, 1.05, 2.53, 1.6],
	VOLLEY: [&"CR_SK_HandUp", 1.0, 0.05],
	FLING: [&"CR_SK_HandForward", 1.6, 0.0],
}
## The moment of the old casts, as a share of the clip.
const SHARES := {BOLT: 0.40, HEX: 0.43, BLAST: 0.55, RAISE: 0.35}
## When each bone goes, from the first (s): the elf's beat — three, a
## breath, three, a breath, three and a fourth on its heels.
const BEAT: Array[float] = [0.0, 0.22, 0.44, 0.95, 1.17, 1.39, 1.9, 2.12, 2.34, 2.46]
## From the hand coming forward to the first going.
const GO_LEAD := 0.25
## The pieces of itself it throws: [mesh, bone, length m].
const BONE_PIECES := [["Skeleton_Bottom", "L_thigh_joint", 0.95], ["Skeleton_Bottom", "L_knee_joint", 0.85],
		["Skeleton_Top", "L_shoulder_joint", 0.7], ["Skeleton_Head", "head_joint", 0.42],
		["Skeleton_Top", "L_elbow_joint", 0.65]]

var _staff: int = -1
var _cast_done: bool = false
var _hex_wait: float = 0.0
var _blast_wait: float = 0.0
var _raise_wait: float = 4.0
var _sword_wait: float = 3.0
var _blade_wait: float = 0.0
var _volley_wait: float = 2.0
## The bones hung round its head (every peer), and on the host when they go
## and how many have gone.
var _crown: BoneCrown
var _crown_since: float = -1.0
var _volley_clock: float = 0.0
var _volley_going: bool = false
var _volley_thrown: int = 0
var _volley_quarry: Node3D
var _bone_parts: Array = []
var _raised: Array[Node] = []
## Where he was over the last moments, to tell whether he is standing still.
var _seen_at: Array[Vector3] = []
var _seen_clock: float = 0.0


func _ready() -> void:
	super()
	for what: int in SPELLS:
		var spell: Array = SPELLS[what]
		var to := 1.0
		if what == SWORD or what == BLADE:
			# the swing's long settle after the blow is cut
			to = clampf((float(spell[2]) + 0.9) / maxf(_clip_length(spell[0]), 0.1), 0.2, 1.0)
		_moves_table[what] = [spell[0], spell[1], 0.0, to]
	if _skeleton != null:
		_staff = _skeleton.find_bone(String(weapon_bone))
	BoneThorns.rune_texture()


func _clip_length(clip: StringName) -> float:
	return _anim.clip_length(clip) if _anim != null else 1.0


## The moment a spell goes, in clip seconds.
func _spell_at(what: int) -> float:
	var spell: Array = SPELLS[what]
	if SHARES.has(what):
		return float(SHARES[what]) * _clip_length(spell[0])
	return float(spell[2])


func _think(delta: float) -> void:
	_hex_wait = maxf(_hex_wait - delta, 0.0)
	_blast_wait = maxf(_blast_wait - delta, 0.0)
	_raise_wait = maxf(_raise_wait - delta, 0.0)
	_sword_wait = maxf(_sword_wait - delta, 0.0)
	_blade_wait = maxf(_blade_wait - delta, 0.0)
	_volley_wait = maxf(_volley_wait - delta, 0.0)
	_run_volley(delta)
	if mode == Mode.GUARD or mode == Mode.RETURN or is_dead:
		super(delta)
		return
	_quarry = _pick_quarry()
	if _quarry == null:
		_go_home()
		return
	_watch(delta)
	if act != Act.NONE:
		return
	var gap := _distance_to(_quarry)
	var to := _quarry.global_position - global_position
	to.y = 0.0
	# Up close: a blast if it has one, else the staff.
	if gap <= blast_under:
		mode = Mode.FIGHT
		_face(to, delta, turn_speed * 2.0)
		if _blast_wait <= 0.0:
			_cast(BLAST)
			return
		super(delta)
		return
	if gap > keep_to:
		mode = Mode.CHASE
		_move_towards(_quarry.global_position, speed, delta)
		return
	mode = Mode.FIGHT
	_face(to, delta, turn_speed * 2.0)
	if gap < keep_from:
		# Steps back, still facing him: it does not turn and run.
		var back := -to.normalized() * speed
		velocity.x = move_toward(velocity.x, back.x, acceleration * 3.0 * delta)
		velocity.z = move_toward(velocity.z, back.z, acceleration * 3.0 * delta)
	else:
		_slow(delta, 4.0)
	if _cooldown > 0.0 or _forward().dot(to.normalized()) < 0.85:
		return
	var span := SpiritSword.strike_span()
	if _raise_wait <= 0.0 and _standing_raised() < raise_max:
		_cast(RAISE)
	elif _blade_wait <= 0.0 and gap < keep_from - 1.5 and gap > 1.6:
		_cast(BLADE)
	elif _sword_wait <= 0.0 and gap > span.x + 0.3 and gap < span.y - 0.4 and _rng.randf() < 0.6:
		_cast(SWORD)
	elif _volley_wait <= 0.0 and _crown == null and _rng.randf() < 0.6:
		_cast(VOLLEY)
	elif _hex_wait <= 0.0 and (_standing_still() or _rng.randf() < 0.35):
		_cast(HEX)
	else:
		_cast(BOLT)


func _cast(what: int) -> void:
	_cast_done = false
	velocity.x = 0.0
	velocity.z = 0.0
	_begin(what)
	match what:
		SWORD:
			_sword_wait = sword_cooldown
			net_sword.rpc()
		BLADE:
			_blade_wait = blade_cooldown
			net_blade.rpc()
		VOLLEY:
			_volley_wait = volley_cooldown


func _run_act(delta: float) -> void:
	super(delta)
	if not SPELLS.has(act) or _quarry == null:
		return
	velocity.x = 0.0
	velocity.z = 0.0
	var spell: Array = SPELLS[act]
	var at := _clip_time(act, _act_time)
	var go := _spell_at(act)
	var aim_till := float(spell[3]) if spell.size() > 3 else go
	if at < aim_till:
		_face(_quarry.global_position - global_position, delta, turn_speed * 2.0)
	if at >= go and not _cast_done:
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
					_raise()
				SWORD:
					_swing_lands(SpiritSword.strike_span(), 1.0, 1.8)
				BLADE:
					_swing_lands(Vector2(1.2, 4.6), 0.9, 1.5)
				VOLLEY:
					net_crown.rpc(_quarry.get_path())


func _after(what: int) -> void:
	match what:
		HEX:
			_hex_wait = hex_cooldown
		BLAST:
			_blast_wait = blast_cooldown
		RAISE:
			_raise_wait = raise_cooldown
	super(what)


#region The spells
func _crystal() -> Vector3:
	if _skeleton == null or _staff < 0:
		return global_position + Vector3.UP * 1.6
	return _skeleton.global_transform * (_posed(_staff) * weapon_tip)


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
	bolt.call(&"launch", flight, hit_damage, false, 0.0, self)
	var who := get_node_or_null(quarry) as Node3D
	if who != null and bolt.has_method(&"hunt"):
		bolt.call(&"hunt", who)


func _hex() -> void:
	net_hex.rpc(_quarry.global_position)


@rpc("authority", "call_local", "reliable")
func net_hex(at: Vector3) -> void:
	BoneThorns.cast(Blood.world_of(self), at, self, hit_damage * 1.4, hex_radius, hex_delay)


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
		# Thrown back hard, off its feet's reach.
		var v: Variant = who.get("velocity")
		if v is Vector3:
			who.set("velocity", (v as Vector3) + off.normalized() * blast_push + Vector3.UP * 3.0)


@rpc("authority", "call_local", "reliable")
func net_blast(at: Vector3) -> void:
	var into := Blood.world_of(self)
	DustRing.burst(into, at, 2.2)
	GroundFx.eruption(into, at, 0.8)


func _raise() -> void:
	var into := get_parent()
	if into == null or raise_scene == null:
		return
	var side := _forward().cross(Vector3.UP).normalized()
	for i in raise_count:
		if _standing_raised() >= raise_max:
			break
		var body := raise_scene.instantiate() as Node3D
		body.name = "%s_raised_%d_%d" % [name, act_serial, i]
		var at := global_position + _forward() * 1.6 + side * (1.4 if i % 2 == 0 else -1.4)
		body.set("band", band)
		body.set("camp_centre", Vector3(at.x, 0.0, at.z))
		into.add_child(body)
		body.global_position = at
		body.rotation.y = rotation.y
		_raised.append(body)
		if body.has_method(&"rise"):
			body.call_deferred(&"rise", raise_clip, _quarry)
		GroundFx.eruption(Blood.world_of(self), at, 0.6)


## A swing of light come down: whoever is on the stretch `span` (m ahead
## of it) within `wide` of its line is struck and felled.
func _swing_lands(span: Vector2, wide: float, worth: float) -> void:
	var fwd := _forward()
	var right := fwd.cross(Vector3.UP)
	for node in get_tree().get_nodes_in_group("player"):
		var who := node as Node3D
		if who == null or not who.has_method(&"receive_blow") or who.get("net_dead") == true:
			continue
		var off := who.global_position - global_position
		off.y = 0.0
		var ahead := off.dot(fwd)
		if ahead < span.x or ahead > span.y or absf(off.dot(right)) > wide:
			continue
		who.call(&"receive_blow", hit_damage * worth, self, 0, 1, act_serial * 3 + 2, true)


@rpc("authority", "call_local", "reliable")
func net_sword() -> void:
	SpiritSword.raise(Blood.world_of(self), self, SWING_CLIP)


@rpc("authority", "call_local", "reliable")
func net_blade() -> void:
	if _skeleton == null:
		return
	var staff := find_child("Skeleton_Mage_Staff", true, false) as MeshInstance3D
	StaffBlade.grow(Blood.world_of(self), self, _skeleton, staff, SWING_CLIP)


## The pieces of its own body it throws, cut once.
func _bone_pieces() -> Array:
	if not _bone_parts.is_empty():
		return _bone_parts
	for p: Array in BONE_PIECES:
		var body := find_child(String(p[0]), true, false) as MeshInstance3D
		var mesh := BoneShard.cut(body, String(p[1]), float(p[2]))
		if mesh != null:
			_bone_parts.append([mesh, BoneShard.material_of(body)])
	return _bone_parts


@rpc("authority", "call_local", "reliable")
func net_crown(quarry: NodePath) -> void:
	if is_instance_valid(_crown):
		_crown.break_all()
	_crown = BoneCrown.form(Blood.world_of(self), self, get_node_or_null(quarry) as Node3D, _bone_pieces())
	if _decides():
		_crown_since = 0.0
		_volley_going = false
		_volley_thrown = 0
		_volley_quarry = _quarry


## Host: the bones hung round its head go once all are there and it is free
## to bring its hand forward, one by one in the beat; with no one to throw
## at for long, or knocked down, they break.
func _run_volley(delta: float) -> void:
	if _crown_since < 0.0:
		return
	_crown_since += delta
	if is_dead or not is_instance_valid(_crown) or _crown_since > 9.0:
		_end_volley()
		return
	if not is_instance_valid(_volley_quarry) or _volley_quarry.get("net_dead") == true:
		_volley_quarry = _quarry
	if not _volley_going:
		if not _crown.all_formed() or act != Act.NONE or _volley_quarry == null:
			return
		_face(_volley_quarry.global_position - global_position, 1.0, 50.0)
		_begin(FLING)
		_volley_going = true
		_volley_clock = -GO_LEAD
		return
	_volley_clock += delta
	while _volley_thrown < BEAT.size() and _volley_clock >= BEAT[_volley_thrown]:
		if _volley_quarry != null:
			net_bone.rpc(_volley_thrown, _volley_quarry.get_path())
		_volley_thrown += 1
	if _volley_thrown >= BEAT.size():
		_crown_since = -1.0


func _end_volley() -> void:
	_crown_since = -1.0
	net_crown_end.rpc()


@rpc("authority", "call_local", "reliable")
func net_crown_end() -> void:
	if is_instance_valid(_crown):
		_crown.break_all()
	_crown = null


@rpc("authority", "call_local", "reliable")
func net_bone(i: int, quarry: NodePath) -> void:
	var into := Blood.world_of(self)
	if into == null or not is_instance_valid(_crown):
		return
	var who := get_node_or_null(quarry) as Node3D
	var from := _crown.place_of(i)
	_crown.take(i)
	var parts := _bone_pieces()
	if parts.is_empty():
		return
	var piece: Array = parts[i % parts.size()]
	var bone := BoneShard.new()
	bone.piece_mesh = piece[0]
	bone.piece_material = piece[1]
	bone.set(&"against_heroes", true)
	into.add_child(bone)
	bone.global_position = from.origin
	var aim := from.basis.y.normalized()
	if who != null:
		aim = (who.global_position + Vector3.UP * 1.1 - from.origin).normalized()
	bone.launch(aim * volley_speed, hit_damage * volley_share, false, 0.0, self)
	if who != null:
		bone.hunt(who)


func _standing_raised() -> int:
	var alive := 0
	for body in _raised:
		if is_instance_valid(body) and not bool(body.get("is_dead")):
			alive += 1
	return alive
#endregion


## Keeps where he has been over the last 1.5 s.
func _watch(delta: float) -> void:
	_seen_clock += delta
	if _seen_clock < 0.25:
		return
	_seen_clock = 0.0
	_seen_at.append(_quarry.global_position)
	if _seen_at.size() > 6:
		_seen_at.pop_front()


func _standing_still() -> bool:
	if _seen_at.size() < 6:
		return false
	return _seen_at[0].distance_to(_seen_at[-1]) < 1.0


func _posed(idx: int) -> Transform3D:
	var t := Transform3D.IDENTITY
	var i := idx
	while i >= 0:
		var local := Transform3D(Basis(_skeleton.get_bone_pose_rotation(i)).scaled(_skeleton.get_bone_pose_scale(i)),
				_skeleton.get_bone_pose_position(i))
		t = local * t
		i = _skeleton.get_bone_parent(i)
	return t
