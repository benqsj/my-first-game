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
## * **The ground under him** (`CR_MG_Ground`): a ring of light opens where he
##   stands and tightens; `hex_delay` later the ground erupts there
##   ([HexCircle]). It favours this when he has stood still.
## * **Up close** (`blast_under`): it drives him off with a blast of the staff
##   (`CR_MG_Blast`, thrown back hard), and between blasts strikes with the
##   staff (its [Brawler] attacks).
## * **The dead rise** (`CR_MG_Raise`): it calls bare skeletons up out of the
##   ground beside it (`raise_count` at a time, `raise_max` standing at most).

@export_group("Spells")
@export var bolt_scene: PackedScene = preload("res://scenes/fx/spell_bolt.tscn")
@export var bolt_speed: float = 20.0
@export var bolt_colour: Color = Color(0.7, 0.45, 1.0)
@export var keep_from: float = 7.0
@export var keep_to: float = 15.0
@export var hex_radius: float = 1.8
@export var hex_delay: float = 1.1
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

const BOLT := 71
const HEX := 72
const BLAST := 73
const RAISE := 74
## [clip, rate, the moment (share of the clip) the spell goes]
const SPELLS := {
	BOLT: [&"CR_MG_Throw", 1.3, 0.40],
	HEX: [&"CR_MG_Ground", 1.25, 0.43],
	BLAST: [&"CR_MG_Blast", 1.35, 0.55],
	RAISE: [&"CR_MG_Raise", 1.2, 0.42],
}

var _staff: int = -1
var _cast_done: bool = false
var _hex_wait: float = 0.0
var _blast_wait: float = 0.0
var _raise_wait: float = 4.0
var _raised: Array[Node] = []
## Where he was over the last moments, to tell whether he is standing still.
var _seen_at: Array[Vector3] = []
var _seen_clock: float = 0.0


func _ready() -> void:
	super()
	for what: int in SPELLS:
		var spell: Array = SPELLS[what]
		_moves_table[what] = [spell[0], spell[1], 0.0, 1.0]
	if _skeleton != null:
		_staff = _skeleton.find_bone(String(weapon_bone))


func _think(delta: float) -> void:
	_hex_wait = maxf(_hex_wait - delta, 0.0)
	_blast_wait = maxf(_blast_wait - delta, 0.0)
	_raise_wait = maxf(_raise_wait - delta, 0.0)
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
	if _raise_wait <= 0.0 and _standing_raised() < raise_max:
		_cast(RAISE)
	elif _hex_wait <= 0.0 and (_standing_still() or _rng.randf() < 0.25):
		_cast(HEX)
	else:
		_cast(BOLT)


func _cast(what: int) -> void:
	_cast_done = false
	velocity.x = 0.0
	velocity.z = 0.0
	_begin(what)


func _run_act(delta: float) -> void:
	super(delta)
	if not SPELLS.has(act) or _quarry == null:
		return
	velocity.x = 0.0
	velocity.z = 0.0
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
					_raise()


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
