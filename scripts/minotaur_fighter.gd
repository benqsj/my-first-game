class_name MinotaurFighter
extends PackBrute

## The minotaur, a boss on its own skeleton (the user's word, 2026-10-22,
## monster_polish_plan.md session 1): a [PackBrute] now, so it has a stance
## it goes down on its knee from (a critical then), a rage at half its
## health, delayed swings and combos made by hand. Its own:
##
## * **The charge** (`charge_from`..`charge_to` off): it roars, the axe up,
##   its eyes reddening, and comes at him head down, gathering pace, along the
##   line it took when the roar ended (it steers only in its first steps), so
##   a roll to the side beats it. Caught, he is thrown down. Missed, it runs
##   on past him and stands dazed a moment, open; enraged, the first miss it
##   turns about at once and comes again.
## * **The axe into the ground** (`M_POUND`): a crack runs out from it along
##   the ground at him (a line, not a ring); on the ground where it passes he
##   is thrown down. A jump or a roll clears it, no shield takes it.
## * **Combos**: Mixamo's three cuts with the axe and the pound at the end;
##   UAL 2's heavy string; its own cuts with the last one held (a delayed
##   swing); a kick into the overhead; the spin into the chop.

const M_ROAR := 170
const M_GORE := 171
const M_DAZE := 172
const M_POUND := 173
const M_MX3 := 174
const M_UHEAVY := 175
const M_CHOP := 176
const M_SPIN := 177
const M_A1 := 178
const M_A2 := 179
const M_A3 := 180
const M_KICK := 181
const M_BUTT := 182
const M_UHEAVYD := 183

enum Charge { NONE, RUN, TURN }

## Its axe, from the bone it is bound to (`mino_weapon_axe`), out to its head.
const AXE := "mino_weapon_axe>mino_weapon_axe@0.1,0.17,1.2:0.42"
const KICK := "calf_r>foot_r:0.24|calf_l>foot_l:0.24"
const HORNS := "neck_01>head:0.55"

@export_group("Charge")
@export var charge_from: float = 7.0
@export var charge_to: float = 17.0
@export var charge_speed: float = 9.0
## The furthest it runs before it gives up on him (m).
@export var charge_most: float = 16.0
@export var charge_cooldown: Vector2 = Vector2(10.0, 15.0)
## Share of `hit_damage` the horns are worth.
@export var charge_share: float = 1.3
## How long it steers at him after it sets off (s); then straight on.
@export var charge_steer: float = 0.3
@export var charge_glow: Color = Color(1.0, 0.12, 0.04)

@export_group("Crack")
@export var crack_reach: float = 9.0
@export var crack_speed: float = 13.0
@export var crack_width: float = 0.9
@export var crack_share: float = 0.9

## Host: the charge it is on, which way, how far it has come, its clock.
var charge_state: int = Charge.NONE
var _charge_dir: Vector3 = Vector3.FORWARD
var _charge_went: float = 0.0
var _charge_t: float = 0.0
var _charge_wait: float = 0.0
var _charge_again: bool = false
var _charge_was_ahead: bool = false
var _turn_left: float = 0.0
## Host: the cracks running out from its pounds.
var _cracks: Array[GroundCrack] = []
var _pound_cracked: int = -1
## Every peer: its eyes, lit while it means to charge.
var _eyes: OmniLight3D
var _charging_shown: bool = false
var _dust_in: float = 0.0
## For the tests.
var charges_made: int = 0
var charges_landed: int = 0
var charges_missed: int = 0
var cracks_made: int = 0
var cracks_hurt: int = 0


func _ready() -> void:
	super()
	_charge_wait = _rng.randf_range(2.0, 5.0)
	_set_moves()
	_light_eyes()


func _set_moves() -> void:
	hand_pace = 1.0
	_special(M_ROAR, &"MN_Battlecry", Vector3(1.25, 0.05, 0.6))
	_special(M_GORE, &"MN_Headbutt", Vector3(1.2, 0.25, 0.8))
	_special(M_DAZE, &"MN_Dizzy", Vector3(1.0, 0.0, 0.34))
	_hand_move(M_POUND, &"MN_UPound", Vector3(0.75, 0.0, 0.95), 1.3, AXE)
	_hand_move(M_MX3, &"MN_Combo2", Vector3(1.0, 0.05, 0.72), 0.8, AXE, [0.228, 0.417, 0.561])
	_hand_move(M_UHEAVY, &"MN_UHeavyCombo", Vector3(0.8, 0.0, 0.8), 0.75, AXE, [0.094, 0.272, 0.417, 0.594])
	_hand_move(M_UHEAVYD, &"MN_UHeavyD", Vector3(0.85, 0.05, 0.8), 1.2, AXE)
	_hand_move(M_CHOP, &"MN_Downward", Vector3(1.0, 0.05, 0.7), 1.1, AXE)
	_hand_move(M_SPIN, &"MN_Spin", Vector3(1.05, 0.05, 0.6), 0.9, AXE)
	_hand_move(M_A1, &"MN_attack1", Vector3(1.0, 0.0, 0.8), 0.85, AXE)
	_hand_move(M_A2, &"MN_attack2", Vector3(1.0, 0.0, 0.8), 0.9, AXE)
	_hand_move(M_A3, &"MN_attack3", Vector3(1.0, 0.0, 0.85), 1.2, AXE)
	_hand_move(M_KICK, &"MN_attack5_kick", Vector3(1.1, 0.0, 0.75), 0.6, KICK)
	_hand_move(M_BUTT, &"MN_Headbutt", Vector3(1.2, 0.1, 0.75), 0.7, HORNS)
	# heavy up, glowing, then all of it at once
	_windups[M_POUND] = [1.5, 0.2]
	_snap[M_POUND] = 1.5
	_windups[M_UHEAVYD] = [1.3, 0.2]
	_snap[M_UHEAVYD] = 1.3
	# quick clips: their wind-ups never shorter than this
	_slow_to[M_UHEAVY] = 0.6
	_slow_to[M_MX3] = 0.55
	_slow_to[M_A1] = 0.45
	_slow_to[M_A2] = 0.5
	# held at the top now and then (Elden Ring's delayed swings)
	_holds[M_A3] = [0.5, 0.35, 0.85, 0.25]
	_holds[M_CHOP] = [0.4, 0.3, 0.7, 0.25]
	_holds[M_UHEAVYD] = [0.3, 0.3, 0.6, 0.25]
	_kinds[M_POUND] = &"crush"
	_kinds[M_UHEAVYD] = &"crush"
	_kinds[M_KICK] = &"guard"
	_hand_combos = [
		# Mixamo's three cuts, the axe into the ground after
		{"name": &"three_and_pound", "moves": [M_MX3, M_POUND], "fells": [1], "weight": 1.0},
		# UAL 2's heavy string
		{"name": &"heavy_string", "moves": [M_UHEAVY], "fells": [0], "weight": 1.0},
		# its own cuts, the overhead last (held now and then)
		{"name": &"bull", "moves": [M_A1, M_A2, M_A3], "fells": [2], "weight": 1.0},
		{"name": &"trample", "moves": [M_KICK, M_BUTT, M_CHOP], "fells": [2], "weight": 0.8},
		{"name": &"reaper", "moves": [M_SPIN, M_UHEAVYD], "fells": [1], "weight": 0.8},
		# enraged only: the long one, ended in the ground
		{"name": &"fury", "moves": [M_A1, M_A2, M_MX3, M_POUND], "fells": [3], "weight": 1.2, "rage_only": true},
	]


func _light_eyes() -> void:
	if _skeleton == null or _skeleton.find_bone("head") < 0:
		return
	var at := BoneAttachment3D.new()
	at.bone_name = "head"
	_skeleton.add_child(at)
	_eyes = OmniLight3D.new()
	_eyes.light_color = charge_glow
	_eyes.light_energy = 0.0
	_eyes.omni_range = 2.2
	_eyes.position = Vector3(0.0, 0.12, 0.18)
	at.add_child(_eyes)


#region The charge
func _own_move(delta: float) -> bool:
	_charge_wait = maxf(_charge_wait - delta, 0.0)
	if charge_state == Charge.RUN:
		_run_charge(delta)
		return true
	if charge_state == Charge.TURN:
		_turn_about(delta)
		return true
	var gap := _distance_to(_quarry)
	if drill_combo < 0 and _charge_wait <= 0.0 and gap >= charge_from and gap <= charge_to \
			and not _quarry_down() and stamina >= attack_cost:
		begin_charge()
		return true
	return super(delta)


## Host: the roar that tells of it (then [method _after] sets it running).
func begin_charge() -> void:
	mode = Mode.FIGHT
	velocity.x = 0.0
	velocity.z = 0.0
	charges_made += 1
	_charge_again = false
	if _quarry != null:
		_face(_quarry.global_position - global_position, 1.0, 50.0)
	_show_charge(true)
	_begin(M_ROAR)


func _start_run() -> void:
	charge_state = Charge.RUN
	_charge_went = 0.0
	_charge_t = 0.0
	_charge_was_ahead = false
	_charge_dir = _forward()
	if _quarry != null:
		var to := _quarry.global_position - global_position
		to.y = 0.0
		if to.length_squared() > 0.01:
			_charge_dir = to.normalized()
	_show_charge(true)


func _run_charge(delta: float) -> void:
	_charge_t += delta
	mode = Mode.FIGHT
	if _quarry != null and _charge_t < charge_steer:
		var to := _quarry.global_position - global_position
		to.y = 0.0
		if to.length_squared() > 0.01:
			var want := to.normalized()
			var most := deg_to_rad(70.0) * delta
			var ang := _charge_dir.signed_angle_to(want, Vector3.UP)
			_charge_dir = _charge_dir.rotated(Vector3.UP, clampf(ang, -most, most))
	var pace := charge_speed * minf(1.0, 0.45 + _charge_t * 2.2) * (1.1 if raging else 1.0)
	velocity.x = _charge_dir.x * pace
	velocity.z = _charge_dir.z * pace
	_face(_charge_dir, delta, 24.0)
	_charge_went += pace * delta
	for node in get_tree().get_nodes_in_group(&"player"):
		var who := node as Node3D
		if who == null or bool(who.get("is_dead")) or not who.has_method(&"receive_blow"):
			continue
		var rel := who.global_position - global_position
		if absf(rel.y) > 1.6:
			continue
		rel.y = 0.0
		var along := rel.dot(_charge_dir)
		var side := (rel - _charge_dir * along).length()
		if who == _quarry and along > 1.0:
			_charge_was_ahead = true
		if along < -0.2 or along > body_radius + 0.9 or side > body_radius + 0.45:
			continue
		if who.has_method(&"is_evading") and bool(who.call(&"is_evading")):
			continue
		_gore(who)
		return
	var passed := false
	if _quarry != null and _charge_was_ahead:
		var rq := _quarry.global_position - global_position
		rq.y = 0.0
		passed = rq.dot(_charge_dir) < -2.5
	if (is_on_wall() and _charge_t > 0.3) or _charge_went >= charge_most or passed:
		_missed()


func _gore(who: Node3D) -> void:
	charges_landed += 1
	charge_state = Charge.NONE
	_show_charge(false)
	who.call(&"receive_blow", hit_damage * charge_share * (rage_harder if raging else 1.0), self,
			0, 1, 5000000 + act_serial, false, &"crush")
	velocity.x = _charge_dir.x * 2.0
	velocity.z = _charge_dir.z * 2.0
	_charge_wait = _rng.randf_range(charge_cooldown.x, charge_cooldown.y)
	_begin(M_GORE)


func _missed() -> void:
	charges_missed += 1
	if raging and not _charge_again:
		_charge_again = true
		charge_state = Charge.TURN
		_turn_left = 0.55
		return
	charge_state = Charge.NONE
	_show_charge(false)
	velocity.x = 0.0
	velocity.z = 0.0
	_charge_wait = _rng.randf_range(charge_cooldown.x, charge_cooldown.y) * (0.7 if raging else 1.0)
	_begin(M_DAZE)


## Enraged: brought up short, turned about, and at him again.
func _turn_about(delta: float) -> void:
	_turn_left -= delta
	velocity.x = move_toward(velocity.x, 0.0, 30.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 30.0 * delta)
	if _quarry != null:
		_face(_quarry.global_position - global_position, delta, turn_speed * 3.0)
	if _turn_left <= 0.0:
		_start_run()


func _begin(what: int) -> void:
	if what != M_ROAR and what != M_GORE and what != M_DAZE and charge_state != Charge.NONE:
		charge_state = Charge.NONE
		_show_charge(false)
	if what != M_ROAR and charge_state == Charge.NONE and _charging_shown:
		_show_charge(false)
	super(what)


func _after(what: int) -> void:
	super(what)
	if what == M_ROAR and not is_dead and _decides():
		_start_run()


func _run_act(delta: float) -> void:
	super(delta)
	if is_dead or not _decides():
		return
	if act == M_ROAR:
		velocity.x = 0.0
		velocity.z = 0.0
		if _quarry != null:
			_face(_quarry.global_position - global_position, delta, turn_speed * 2.0)
	if act == M_POUND and _pound_cracked != act_serial:
		var ms := _blow_moments(M_POUND)
		if not ms.is_empty() and _act_time >= ms[0]:
			_pound_cracked = act_serial
			_crack()


## Every peer: its eyes lit and the dust at its feet while it charges.
func _show_charge(on: bool) -> void:
	if not _decides():
		return
	if is_inside_tree() and multiplayer.has_multiplayer_peer():
		net_show_charge.rpc(on)
	else:
		net_show_charge(on)


@rpc("authority", "call_local", "reliable")
func net_show_charge(on: bool) -> void:
	var was := _charging_shown
	_charging_shown = on
	if on and not was:
		Sfx.play_any(self, ["res://sounds/ogre/roar_short.wav"], self, 0.85, 2.0)
#endregion


#region The crack
## Host: a crack let go from the axe's head along the way it faces (at him,
## if he is near enough in front).
func _crack() -> void:
	var from := global_position + _forward() * 0.5
	var way := _forward()
	if _quarry != null:
		var to := _quarry.global_position - from
		to.y = 0.0
		if to.length_squared() > 0.25 and to.normalized().dot(_forward()) > 0.5:
			way = to.normalized()
	cracks_made += 1
	_cracks.append(GroundCrack.new(from, way, crack_reach, crack_speed, crack_width, 6000000 + act_serial))
	if is_inside_tree() and multiplayer.has_multiplayer_peer():
		net_crack.rpc(from, way)
	else:
		net_crack(from, way)


func _run_cracks(delta: float) -> void:
	for i in range(_cracks.size() - 1, -1, -1):
		var c: GroundCrack = _cracks[i]
		for who: Node3D in c.reached(delta, get_tree()):
			cracks_hurt += 1
			who.call(&"receive_blow", hit_damage * crack_share, self, 0, 1, c.id, false, &"ground")
		if c.done():
			_cracks.remove_at(i)


@rpc("authority", "call_local", "reliable")
func net_crack(from: Vector3, way: Vector3) -> void:
	GroundCrack.show(self, from, way, crack_reach, crack_speed)
#endregion


func _physics_process(delta: float) -> void:
	super(delta)
	if _decides() and not _cracks.is_empty():
		_run_cracks(delta)


func _process(delta: float) -> void:
	super(delta)
	if _eyes != null:
		var want := 3.5 if _charging_shown and not is_dead else 0.0
		_eyes.light_energy = move_toward(_eyes.light_energy, want, delta * 12.0)
	if _charging_shown and not is_dead and Vector2(velocity.x, velocity.z).length() > 4.0:
		_dust_in -= delta
		if _dust_in <= 0.0:
			_dust_in = 0.12
			var world := Blood.world_of(self)
			if world != null:
				SkillFx.burst(world, global_position + Vector3.UP * 0.15, Color(0.5, 0.45, 0.38), 8,
						Vector2(0.6, 1.6), Vector3.UP, 70.0, Vector2(0.08, 0.16), Vector3(0, -1.0, 0), 0.6)


func _die() -> void:
	charge_state = Charge.NONE
	_charging_shown = false
	super()
