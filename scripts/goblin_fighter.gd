class_name GoblinFighter
extends Brawler

## The goblin (Polysplit's Biped Creatures, CREATURES_PACK.md): small, quick,
## a thief and a coward (the user's picks, 2026-10-07).
##
## * **Round to his back.** With another goblin by it, it does not come at his
##   front: it runs round him (`flank_angle` off his back) and strikes from
##   behind, or from where it got to once `flank_patience` is up. It hops
##   aside from his swings (the [Fighter]'s dash, `dash_chance`).
## * **A hand in his purse.** A blow of its that reaches him (and is not on
##   his guard) now and then (`steal_chance`) takes a share of his gold
##   ([Purse], `steal_share`) — a bag at its hip shows it — and it runs off
##   with it (`thief_flee`). Cut down, it drops what it took with its own
##   ([CoinBank.worth_of], `carried_gold`).
## * **A coward alone.** With no other goblin within `ally_range`, it keeps
##   off him (`keep_off`) and throws; only cornered (within `cornered`) does
##   it fight. Wounded under `fear_at` of its health it runs (`fear_flee`)
##   and shrieks for the others (`call_clip`, every goblin within
##   `call_range` comes), and comes back once they are with it.
## * **Stones and bombs.** From `throw_from` to `throw_to` off, now and then
##   (`throw_every`), it throws ([GoblinShot]): mostly a stone, a blow on him;
##   now and then (`bomb_chance`) a black pot with a fuse that bursts where it
##   lands. A goblin alone throws far oftener.

@export_group("Flank")
@export var flank_from: float = 6.0
## How far round from his back it makes for (degrees), and how close in.
@export var flank_angle: float = 30.0
@export var flank_patience: float = 2.6

@export_group("Theft")
@export_range(0.0, 1.0) var steal_chance: float = 0.55
@export_range(0.0, 1.0) var steal_share: float = 0.3
@export var steal_least: int = 3
@export var steal_most: int = 60
@export var thief_flee: float = 5.0

@export_group("Cowardice")
## Fights as though the others were by it, alone or not (a test's goblin).
@export var bold: bool = false
@export var ally_range: float = 12.0
@export var keep_off: float = 7.0
@export var cornered: float = 2.4
@export_range(0.0, 1.0) var fear_at: float = 0.35
@export var fear_flee: float = 4.0
@export var flee_speed: float = 5.6
@export var call_clip: StringName = &"CR_Call"
@export var call_part: Vector3 = Vector3(1.2, 0.0, 0.85)
@export var call_range: float = 28.0

@export_group("Throwing")
@export var throw_clip: StringName = &"CR_Throw"
@export var throw_part: Vector3 = Vector3(1.3, 0.0, 0.85)
@export var throw_from: float = 4.0
@export var throw_to: float = 15.0
@export var throw_every: Vector2 = Vector2(3.5, 6.0)
@export var throw_every_alone: Vector2 = Vector2(1.8, 3.0)
@export_range(0.0, 1.0) var bomb_chance: float = 0.3
## Shares of `hit_damage`.
@export var stone_share: float = 0.7
@export var bomb_share: float = 2.0

const THROW := 101
const CALL := 102

## What it has taken off the heroes (host), dropped when it dies.
var carried_gold: int = 0

var _flank_side: float = 1.0
var _flank_for: float = 0.0
var _flee_left: float = 0.0
var _feared: bool = false
var _throw_wait: float = 2.0
var _thrown: bool = false
var _throw_at: float = 0.5
var _throw_hand: StringName = &"R_wrist_joint"
var _called: bool = false
var _called_out: bool = false
var _call_at: float = 0.5
var _shots: int = 0
var _bag: Node3D


func _ready() -> void:
	super()
	_moves_table[THROW] = [throw_clip, throw_part.x, throw_part.y, throw_part.z]
	_moves_table[CALL] = [call_clip, call_part.x, call_part.y, call_part.z]
	if _anim != null:
		_throw_at = _moment_of(THROW, PackedStringArray(["R_wrist_joint", "L_wrist_joint"]), 0.5)
		_call_at = _moment_of(CALL, PackedStringArray(["R_wrist_joint", "L_wrist_joint"]), 0.5)
		_throw_hand = _fastest_hand(throw_clip)
	_flank_side = 1.0 if _rng.randf() < 0.5 else -1.0
	_throw_wait = _rng.randf_range(1.0, 3.0)


## The act time (s) of the fastest moment of `bones` in move `what`.
func _moment_of(what: int, bones: PackedStringArray, fallback: float) -> float:
	var m: Array = _moves_table[what]
	var length := _anim.clip_length(m[0])
	var best := -1.0
	for p in _anim.measure_peaks(m[0], bones, 0.5, 0.08):
		if p >= float(m[2]) and p <= float(m[3]):
			best = p
			break
	if best < 0.0:
		best = lerpf(float(m[2]), float(m[3]), fallback)
	return (best - float(m[2])) * length / maxf(float(m[1]), 0.01)


## Which hand moves the most in a clip (the one that throws).
func _fastest_hand(clip: StringName) -> StringName:
	var right := _anim.measure_peaks(clip, PackedStringArray(["R_wrist_joint"]), 0.5, 0.08)
	var left := _anim.measure_peaks(clip, PackedStringArray(["L_wrist_joint"]), 0.5, 0.08)
	return &"L_wrist_joint" if left.size() > right.size() else &"R_wrist_joint"


#region Thinking
func _think(delta: float) -> void:
	_throw_wait = maxf(_throw_wait - delta, 0.0)
	_flee_left = maxf(_flee_left - delta, 0.0)
	if mode == Mode.GUARD or mode == Mode.RETURN or is_dead or act != Act.NONE:
		super(delta)
		return
	_quarry = _pick_quarry()
	if _quarry == null:
		super(delta)
		return
	var to := _quarry.global_position - global_position
	to.y = 0.0
	var gap := to.length()
	var allies := _allies()
	# Hurt badly: off, and a shriek for the others.
	if not _feared and health <= max_health * fear_at:
		_feared = true
		_flee_left = fear_flee
		_called = false
	if _flee_left > 0.0:
		if _feared and not _called and gap > 6.0:
			_called = true
			_face(to, 1.0, 50.0)
			_begin(CALL)
			return
		_run_from(to, delta)
		return
	# Its fear spent once the others are with it.
	if _feared and allies > 0:
		_feared = false
	var alone := allies == 0 and not bold
	# A stone or a bomb, from off.
	if _throw_wait <= 0.0 and gap >= throw_from and gap <= throw_to and not _quarry_down() \
			and stamina >= attack_cost:
		mode = Mode.FIGHT
		_face(to, delta, turn_speed * 2.0)
		if _forward().dot(to.normalized()) > 0.85:
			_thrown = false
			_slow(delta, 6.0)
			_begin(THROW)
		else:
			_slow(delta, 4.0)
		return
	if alone or _feared:
		if gap > cornered:
			_keep_away(to, gap, delta)
			return
		super(delta)
		return
	if gap < flank_from and not _behind_him() and allies > 0:
		_flank_for += delta
		if _flank_for < flank_patience:
			_flank(delta)
			return
	else:
		_flank_for = 0.0
	super(delta)


## Other goblins up and about near it.
func _allies() -> int:
	var n := 0
	for node in get_tree().get_nodes_in_group(&"enemy"):
		var g := node as GoblinFighter
		if g == null or g == self or g.is_dead:
			continue
		if g.global_position.distance_to(global_position) <= ally_range:
			n += 1
	return n


## Whether it stands at his back (round from where he faces).
func _behind_him() -> bool:
	var his := -_quarry.global_transform.basis.z
	his.y = 0.0
	var to_me := global_position - _quarry.global_position
	to_me.y = 0.0
	return his.normalized().dot(to_me.normalized()) < -0.35


## Round him to his back, at a run, facing where it runs until it is near,
## then him.
func _flank(delta: float) -> void:
	mode = Mode.CHASE
	var his := -_quarry.global_transform.basis.z
	his.y = 0.0
	his = his.normalized() if his.length_squared() > 0.0001 else Vector3.FORWARD
	var back := (-his).rotated(Vector3.UP, deg_to_rad(flank_angle) * _flank_side)
	var off := maxf(float(_strike_from.get(ATTACK_BASE, strike_off)), reach * 0.8)
	var point := _quarry.global_position + back * off
	# Round, not through him: a point to the side first while it is in front.
	var to_me := global_position - _quarry.global_position
	to_me.y = 0.0
	if his.dot(to_me.normalized()) > -0.1:
		var side := his.cross(Vector3.UP) * _flank_side
		point = _quarry.global_position + (side - his * 0.6).normalized() * (off + 1.0)
	var way := point - global_position
	way.y = 0.0
	if way.length() < 0.4:
		_face(_quarry.global_position - global_position, delta, turn_speed * 2.0)
		_slow(delta, 4.0)
		return
	var pace := chase_speed if way.length() > 1.5 else speed * 1.4
	_move_towards(point, pace, delta)


## Alone: off out of his reach, facing him, while he comes on; on the run
## when he is close.
func _keep_away(to: Vector3, gap: float, delta: float) -> void:
	mode = Mode.FIGHT
	if gap >= keep_off:
		_face(to, delta, turn_speed)
		_slow(delta, 3.0)
		return
	if gap < keep_off * 0.6:
		_run_from(to, delta)
		return
	# Backing off, facing him.
	_face(to, delta, turn_speed)
	var back := -to.normalized() * speed * 1.2
	velocity.x = move_toward(velocity.x, back.x, acceleration * 3.0 * delta)
	velocity.z = move_toward(velocity.z, back.z, acceleration * 3.0 * delta)


func _run_from(to: Vector3, delta: float) -> void:
	mode = Mode.CHASE
	var away := -to.normalized()
	# Not straight out of the camp's ground: back round towards it.
	var home := _home - global_position
	home.y = 0.0
	if home.length() > leash_radius * 0.6:
		away = (away + home.normalized() * 0.8).normalized()
	_move_towards(global_position + away * 4.0, flee_speed, delta)
#endregion


#region Its moves
func _run_act(delta: float) -> void:
	super(delta)
	if is_dead or not _decides():
		return
	if act == THROW and not _thrown and _act_time >= _throw_at:
		_thrown = true
		_release()
	elif act == CALL and not _called_out and _act_time >= _call_at:
		_called_out = true
		_call_them()


func _begin(what: int) -> void:
	if what == CALL:
		_called_out = false
	super(what)


func _after(what: int) -> void:
	if what == THROW:
		var every := throw_every_alone if _allies() == 0 else throw_every
		_throw_wait = _rng.randf_range(every.x, every.y)
	super(what)


## Host: the stone or the bomb out of its hand, on an arc onto where he will be.
func _release() -> void:
	if _quarry == null:
		return
	var from := global_position + Vector3.UP * 1.0 * visual_scale
	if _skeleton != null:
		var hand := _skeleton.find_bone(String(_throw_hand))
		if hand >= 0:
			from = _skeleton.global_transform * _skeleton.get_bone_global_pose(hand).origin
	var bomb := _rng.randf() < bomb_chance
	var target := _quarry.global_position + Vector3.UP * (0.15 if bomb else 1.05)
	var gap := Vector3(target.x - from.x, 0.0, target.z - from.z).length()
	var flight := clampf(gap / (11.0 if bomb else 15.0), 0.45, 1.2)
	if _quarry is CharacterBody3D:
		var v := (_quarry as CharacterBody3D).velocity
		target += Vector3(v.x, 0.0, v.z) * flight * 0.6
	var throw_v := (target - from) / flight + Vector3.UP * 0.5 * GoblinShot.GRAVITY * flight
	_shots += 1
	var kind := GoblinShot.Kind.BOMB if bomb else GoblinShot.Kind.STONE
	var worth := hit_damage * (bomb_share if bomb else stone_share)
	_send_throw(from, throw_v, kind, worth, act_serial * 100 + _shots)


func _send_throw(from: Vector3, v: Vector3, kind: int, worth: float, id: int) -> void:
	if is_inside_tree() and multiplayer.has_multiplayer_peer():
		net_throw.rpc(from, v, kind, worth, id)
	else:
		net_throw(from, v, kind, worth, id)


@rpc("authority", "call_local", "reliable")
func net_throw(from: Vector3, v: Vector3, kind: int, worth: float, id: int) -> void:
	GoblinShot.throw(Blood.world_of(self), from, v, kind, worth, self, _decides(), id)


## Host: the shriek heard: every goblin about comes for him.
func _call_them() -> void:
	SkillFx.ring(Blood.world_of(self), global_position + Vector3.UP * 1.0 * visual_scale, Vector3.UP,
			Color(1.0, 0.85, 0.5), 0.3, 3.0, 0.5, 0.02, 1.2)
	for node in get_tree().get_nodes_in_group(&"enemy"):
		var g := node as GoblinFighter
		if g == null or g == self or g.is_dead:
			continue
		if g.global_position.distance_to(global_position) <= call_range and _quarry != null:
			g._quarry = _quarry
			if g.mode == Mode.GUARD or g.mode == Mode.RETURN:
				g.mode = Mode.CHASE
#endregion


#region Theft
func _blow_reached(who: Node3D, _what: int) -> void:
	if is_dead or who == null or _flee_left > 0.0:
		return
	# Caught on his guard, it got nothing.
	if bool(who.get("net_blocking")) or bool(who.get("is_blocking")):
		return
	var purse := Purse.of(who)
	if purse == null or purse.gold <= 0 or _rng.randf() >= steal_chance:
		return
	var want := clampi(int(ceil(float(purse.gold) * steal_share)), steal_least, steal_most)
	var got := purse.take(want)
	if got <= 0:
		return
	carried_gold += got
	_flee_left = thief_flee
	if is_inside_tree() and multiplayer.has_multiplayer_peer():
		net_stole.rpc(who.global_position)
	else:
		net_stole(who.global_position)


## Every peer: a glint of gold off him into its hand, and the bag at its hip.
@rpc("authority", "call_local", "reliable")
func net_stole(at: Vector3) -> void:
	var into := Blood.world_of(self)
	SkillFx.burst(into, at + Vector3.UP * 1.0, Coins.GOLD, 18, Vector2(1.5, 3.5), Vector3.UP, 60.0,
			Vector2(0.02, 0.04), Vector3(0, -6, 0), 0.5)
	SkillFx.flash(into, global_position + Vector3.UP * 0.7 * visual_scale, Coins.GOLD, 0.35, 0.25, 2.0)
	_show_bag(true)


func _show_bag(on: bool) -> void:
	if _bag == null:
		if not on:
			return
		# At its hip, on the body (it turns with it).
		_bag = Node3D.new()
		_bag.name = "Takings"
		add_child(_bag)
		_bag.position = Vector3(0.2, 0.55, 0.05) * visual_scale
		_bag.scale = Vector3.ONE * visual_scale
		var sack := MeshInstance3D.new()
		var m := SphereMesh.new()
		m.radius = 0.11
		m.height = 0.2
		sack.mesh = m
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.36, 0.25, 0.14)
		mat.roughness = 0.9
		m.material = mat
		_bag.add_child(sack)
		var glint := MeshInstance3D.new()
		var c := CylinderMesh.new()
		c.top_radius = 0.05
		c.bottom_radius = 0.05
		c.height = 0.012
		glint.mesh = c
		var gm := StandardMaterial3D.new()
		gm.albedo_color = Coins.GOLD
		gm.metallic = 1.0
		gm.roughness = 0.25
		gm.emission_enabled = true
		gm.emission = Coins.GOLD
		gm.emission_energy_multiplier = 0.6
		c.material = gm
		glint.position = Vector3(0.0, 0.1, 0.0)
		glint.rotation = Vector3(0.4, 0.0, 0.2)
		_bag.add_child(glint)
	_bag.visible = on


func _lie_down() -> void:
	super()
	_show_bag(false)
#endregion
