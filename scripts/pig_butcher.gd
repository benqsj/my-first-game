class_name PigButcher
extends OrcFighter

## The butcher, the boss halfway through the orcs' palace (the user's pick,
## 2026-10-22: Synty's pig butcher, about 2.6 m). He fights as an orc does
## with a great axe — its moves, its stance, its rage — and is seen as the
## Synty figure: the orc's own body is there and posed, unseen, and the
## butcher's skeleton follows it bone by bone ([FigureFollower]), his cleaver
## in his own right hand.
##
## His own (the user's word, 2026-10-22, monster_polish_plan.md session 2):
## * **His cleaver**, Synty's own for him, bloodied, in place of the great axe;
##   its blows are where the cleaver is seen ([method _weapon_part]), not
##   where the orc's unseen axe would be.
## * **The hook** on its chain: from off he hurls it at him; caught, he is
##   hauled in to the butcher's feet and met with the headbutt and the chop.
##   A roll slips it.
## * **The ground split**: the cleaver brought down so the ground cracks out
##   at him along a line; enraged, three of them running.
## * **Combos**: Mixamo's two-handed club string; UAL 2's sword string
##   ending in his head; the chop held at the top, then the ground.
## * **His coming in**: woken, he roars, and his name comes up on the screen.

const FIGURE := "res://assets/monsters/synty_rivals/pig_butcher.glb"
## The figure's size against the rig's (the rig is drawn at `visual_scale`):
## at 1 he stands ~2.6 m.
@export var figure_scale: float = 1.0
## The butcher's bones -> the orc's (Synty's names, Polysplit's).
const MAP := {
	&"Hips": &"pelvis_joint", &"Spine_01": &"waist_joint", &"Spine_03": &"chest_joint",
	&"Neck": &"neck_joint", &"Head": &"head_joint",
	&"Clavicle_L": &"L_clavicle_joint", &"Shoulder_L": &"L_shoulder_joint", &"Elbow_L": &"L_elbow_joint",
	&"Hand_L": &"L_wrist_joint",
	&"Clavicle_R": &"R_clavicle_joint", &"Shoulder_R": &"R_shoulder_joint", &"Elbow_R": &"R_elbow_joint",
	&"Hand_R": &"R_wrist_joint",
	&"UpperLeg_L": &"L_thigh_joint", &"LowerLeg_L": &"L_knee_joint", &"Ankle_L": &"L_ankle_joint",
	&"Ball_L": &"L_ball_joint", &"Toes_L": &"L_toe_joint",
	&"UpperLeg_R": &"R_thigh_joint", &"LowerLeg_R": &"R_knee_joint", &"Ankle_R": &"R_ankle_joint",
	&"Ball_R": &"R_ball_joint", &"Toes_R": &"R_toe_joint",
}

var figure: Node3D
var follower: FigureFollower


const CLEAVER := "res://assets/monsters/synty_rivals/butcher_cleaver.glb"
const HOOK_MESH := "res://assets/monsters/synty_rivals/meat_hook.glb"
const TITLE := "ყასაბი — სასახლის ჯალათი"
const CHAIN_SOUND := "res://sounds/whoosh_heavy.wav"

const B_CLEAVE3 := 240
const B_REG := 241
const B_BUTT := 242
const B_DOWN := 243
const B_POUND := 244
const B_HOOK := 245
const B_INTRO := 246
const HOOK_COMBO := &"hooked"

enum Hook { NONE, OUT, PULL, BACK }

## The cleaver's size (1: Synty's, 1.5 m) and a turn about its haft (degrees)
## to set its edge.
@export var cleaver_scale: float = 1.15
@export var cleaver_roll: float = 0.0
@export var cleaver_radius: float = 0.3

@export_group("Hook")
@export var hook_from: float = 6.0
@export var hook_to: float = 15.0
@export var hook_cooldown: Vector2 = Vector2(8.0, 13.0)
@export var hook_speed: float = 24.0
@export var hook_range: float = 17.0
@export var hook_pull: float = 11.0
@export var hook_back: float = 20.0
@export var hook_share: float = 0.25

@export_group("Ground split")
@export var crack_reach: float = 8.0
@export var crack_speed: float = 13.0
@export var crack_width: float = 0.9
@export var crack_share: float = 0.8

## Every peer: the cleaver as it is held, and where on it its blow is.
var _cleaver: Node3D
var _edge_from: Vector3
var _edge_to: Vector3
## Host: the hook's flight, where it is, which way, who it has.
var hook_state: int = Hook.NONE
var _hook_pos: Vector3
var _hook_dir: Vector3 = Vector3.FORWARD
var _hook_went: float = 0.0
var _hook_held: Node3D
var _hook_wait: float = 0.0
var _hook_at: float = 0.4
var _hook_thrown: bool = false
## Every peer: its hook and chain drawn.
var _hook_node: Node3D
var _chain: MeshInstance3D
var _cracks: Array[GroundCrack] = []
var _pound_cracked: int = -1
var _introduced: bool = false
var _drip_in: float = 0.0
## For the tests.
var hooks_thrown: int = 0
var hooks_caught: int = 0
var cracks_made: int = 0
var cracks_hurt: int = 0


func _ready() -> void:
	super()
	_wear_figure()
	_butcher_moves()


## The orc's own meshes hidden (its weapons kept, moved to his hand), the
## butcher put on, following the orc's skeleton.
func _wear_figure() -> void:
	if body == null or _skeleton == null or not ResourceLoader.exists(FIGURE):
		return
	figure = (load(FIGURE) as PackedScene).instantiate() as Node3D
	figure.name = "Butcher"
	body.add_child(figure)
	figure.scale = Vector3.ONE * figure_scale
	var fig_skel := figure.find_child("Skeleton3D", true, false) as Skeleton3D
	if fig_skel == null:
		return
	follower = FigureFollower.new()
	follower.name = "Follower"
	# the Synty skeleton stands centimetres, Z up, under a turned node
	follower.space = fig_skel.global_basis.orthonormalized().inverse() * _skeleton.global_basis.orthonormalized()
	follower.mids = {&"Spine_02": [&"waist_joint", &"chest_joint", 0.5]}
	add_child(follower)
	if not follower.setup(_skeleton, fig_skel, MAP, &"Hips"):
		push_warning("PigButcher: the figure's bones do not match the map.")
		return
	_hide_rig()
	_take_weapons(fig_skel)


func _hide_rig() -> void:
	for node in body.find_children("*", "GeometryInstance3D", true, false):
		var g := node as GeometryInstance3D
		if figure.is_ancestor_of(g):
			continue
		g.visible = false


## His weapons off the orc's hands and into his own: each the orc held (a
## mesh skinned rigidly to one hand bone, [method OrcFighter._put_in_hand])
## made again, unskinned, on his hand, turned as it is turned now and moved
## from the orc's hand onto his.
func _take_weapons(fig_skel: Skeleton3D) -> void:
	for node in body.find_children("Arm_*", "MeshInstance3D", true, false):
		var w := node as MeshInstance3D
		if figure.is_ancestor_of(w) or w.skin == null or w.skin.get_bind_count() == 0:
			continue
		var bone_name := String(w.skin.get_bind_name(0))
		var bone := _skeleton.find_bone(bone_name)
		var hand := fig_skel.find_bone("Hand_L" if bone_name.begins_with("L_") else "Hand_R")
		if bone < 0 or hand < 0:
			continue
		var held := _skeleton.global_transform * _skeleton.get_bone_global_pose(bone)
		var now := held * w.skin.get_bind_pose(0)
		var grip := BoneAttachment3D.new()
		grip.name = "Grip_%s" % fig_skel.get_bone_name(hand)
		grip.bone_name = fig_skel.get_bone_name(hand)
		fig_skel.add_child(grip)
		var at := fig_skel.global_transform * fig_skel.get_bone_global_pose(hand)
		var copy := MeshInstance3D.new()
		copy.name = "Held_" + String(w.name)
		copy.mesh = w.mesh
		copy.material_override = w.material_override
		grip.add_child(copy)
		copy.global_transform = Transform3D(now.basis, at.origin + (now.origin - held.origin))
	_arm_cleaver(fig_skel)


#region His cleaver
## Its weapon the orc's copied onto his hand ([method _take_weapons]): the
## great axe's copy hidden and Synty's cleaver held there in its place, along
## the axe's haft, bloodied; the left hand's blade hidden (the hook is
## thrown from it).
func _arm_cleaver(fig_skel: Skeleton3D) -> void:
	var axe: MeshInstance3D = null
	for n in fig_skel.find_children("Held_*", "MeshInstance3D", true, false):
		var m := n as MeshInstance3D
		if m.get_parent().name == &"Grip_Hand_R" and axe == null:
			axe = m
		m.visible = false
	if axe == null or not ResourceLoader.exists(CLEAVER):
		return
	var grip := axe.get_parent() as Node3D
	var box := axe.get_aabb()
	var hand := grip.global_position
	var far := hand
	var mid := Vector3.ZERO
	for k in 8:
		var p := axe.global_transform * box.get_endpoint(k)
		mid += p / 8.0
		if p.distance_to(hand) > far.distance_to(hand):
			far = p
	var up := (far - hand).normalized()
	# the blade side: where the axe's bulk lies off its haft
	var off := mid - hand
	off -= up * off.dot(up)
	var edge := off.normalized() if off.length() > 0.01 else up.cross(Vector3.UP).normalized()
	edge = edge.rotated(up, deg_to_rad(cleaver_roll))
	var x := up.cross(edge).normalized()
	var basis := Basis(x, up, x.cross(up).normalized()).scaled(Vector3.ONE * cleaver_scale)
	_cleaver = (load(CLEAVER) as PackedScene).instantiate() as Node3D
	_cleaver.name = "Cleaver"
	grip.add_child(_cleaver)
	_cleaver.global_transform = Transform3D(basis, hand)
	var top := 1.27
	var side := 0.15
	for n in _cleaver.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		mi.layers |= Blood.WOUND_LAYER
		var b := mi.get_aabb()
		top = b.end.y
		side = (b.position.z + b.end.z) * 0.5
	_edge_from = Vector3(0.0, top * 0.35, side)
	_edge_to = Vector3(0.0, top * 0.95, side)
	_bloody_cleaver(top, side)


## Blood on both faces of the blade and its edge, more than an orc's blade
## carries (the user's word: more of it, more brutal).
func _bloody_cleaver(top: float, side: float) -> void:
	for k in 4:
		var decal := Decal.new()
		decal.texture_albedo = Blood.wound_texture()
		decal.modulate = Color(0.3, 0.0, 0.0) if k < 2 else Color(0.2, 0.0, 0.0)
		decal.albedo_mix = 1.0
		decal.normal_fade = 0.0
		decal.cull_mask = Blood.WOUND_LAYER
		decal.upper_fade = 0.05
		decal.lower_fade = 0.05
		_cleaver.add_child(decal)
		var face := Vector3.RIGHT * (1.0 if k % 2 == 0 else -1.0)
		# the decal's -Y projects: laid on a face of the blade, its runs down it
		var y := face
		var z := Vector3.DOWN
		decal.transform = Transform3D(Basis(y.cross(z), y, z), Vector3(0.0, top * (0.72 if k < 2 else 0.45), side * 1.1))
		decal.size = Vector3(0.7 if k < 2 else 0.55, 0.3, top * (0.55 if k < 2 else 0.4))


## Every peer: now and then a drop off the cleaver's edge.
func _drip(delta: float) -> void:
	if _cleaver == null or not _cleaver.is_visible_in_tree() or is_dead:
		return
	_drip_in -= delta
	if _drip_in > 0.0:
		return
	_drip_in = randf_range(0.35, 0.9)
	var world := Blood.world_of(self)
	if world != null:
		var at := _cleaver.global_transform * Vector3(0.0, 0.0, 0.0).lerp(_edge_to, randf_range(0.6, 1.0))
		SkillFx.burst(world, at, Color(0.32, 0.0, 0.0), 2, Vector2(0.1, 0.4), Vector3.DOWN, 20.0,
				Vector2(0.025, 0.04), Vector3(0, -9.0, 0), 0.6)


## Its blow where the cleaver is seen.
func _weapon_part() -> Array:
	if _cleaver == null or not is_instance_valid(_cleaver):
		return super()
	var t := _cleaver.global_transform
	return [[t * _edge_from, t * _edge_to, cleaver_radius * cleaver_scale]]


## Where the cleaver's end is (the wind-up's glow there, a jump over a low
## blow judged by it).
func _weapon_tip_at() -> Vector3:
	if _cleaver == null or not is_instance_valid(_cleaver):
		return super()
	return _cleaver.global_transform * _edge_to


## A move's striking ends ([Brawler]), its weapon's end the cleaver.
func _own_part(what: int) -> Array:
	var out := []
	if _skeleton == null:
		return out
	if _cleaver == null or not is_instance_valid(_cleaver):
		return super(what)
	var s := maxf(visual_scale, 0.01)
	var rest := []
	for st: Array in _limbs_of.get(what, []):
		if String(st[0]) == String(weapon_bone) or String(st[1]) == String(weapon_bone):
			out.append_array(_weapon_part())
			continue
		var a := _skeleton.find_bone(String(st[0]))
		var b := _skeleton.find_bone(String(st[1]))
		if a < 0 or b < 0:
			continue
		if bool(st[4]):
			rest.append(WeaponSweep.bones(_skeleton, a, b, float(st[3]) * s, st[2]))
		else:
			rest.append(WeaponSweep.bones(_skeleton, a, b, float(st[3]) * s))
	out.append_array(_stooped(rest))
	return out


## Host: his cleaver gone into him: more of his blood than another's blow lets.
func _blow_reached(who: Node3D, what: int) -> void:
	super(who, what)
	if who == null or not _decides() or bool(who.get("net_blocking")) or bool(who.get("is_blocking")):
		return
	var at := who.global_position + Vector3.UP * 1.2
	var way := who.global_position - global_position
	way.y = 0.0
	if is_inside_tree() and multiplayer.has_multiplayer_peer():
		net_gore.rpc(at, way)
	else:
		net_gore(at, way)


@rpc("authority", "call_local", "reliable")
func net_gore(at: Vector3, way: Vector3) -> void:
	var world := Blood.world_of(self)
	if world != null:
		Blood.splatter(world, at, way.normalized() + Vector3.UP * 0.3, null, 1.8)
#endregion


#region His moves
func _butcher_moves() -> void:
	var hp := maxf(hand_pace, 0.01)
	_throw_wait = 99999.0
	_hook_wait = _rng.randf_range(3.0, hook_cooldown.x)
	# Mixamo's two-handed club string: three blows, the last fells
	_hand_move(B_CLEAVE3, &"CR_OG_Club_Combo2H", Vector3(1.05 / hp, 0.03, 0.85), 0.75, "", [0.25, 0.517, 0.728])
	_slow_to[B_CLEAVE3] = 0.5
	# UAL 2's sword string, then his head into him
	_hand_move(B_REG, &"CR_SwordCombo", Vector3(0.85 / hp, 0.0, 0.75), 0.7, "", [0.083, 0.239, 0.517])
	_slow_to[B_REG] = 0.55
	_hand_move(B_BUTT, &"CR_OG_Headbutt", Vector3(1.1 / hp, 0.1, 0.75), 0.6, "neck_joint>head_joint:0.34")
	_hand_move(B_DOWN, &"CR_OG_Attack_Downward", Vector3(1.0 / hp, 0.05, 0.8), 1.1, "")
	_holds[B_DOWN] = [0.45, 0.35, 0.8, 0.25]
	_hand_move(B_POUND, &"CR_GroundPound", Vector3(0.8 / hp, 0.0, 0.95), 1.0, "")
	_windups[B_POUND] = [1.35, 0.2]
	_snap[B_POUND] = 1.4
	_kinds[B_POUND] = &"crush"
	_special(B_HOOK, &"CR_Throw", Vector3(1.0, 0.0, 0.75))
	_special(B_INTRO, &"CR_OG_Battlecry", Vector3(1.0, 0.0, 0.9))
	if _anim != null and _anim.clip_length(&"CR_Throw") > 0.0:
		var peaks := _anim.measure_peaks(&"CR_Throw", PackedStringArray(["R_wrist_joint"]), 0.6, 0.12)
		var best := float(peaks[0]) if not peaks.is_empty() else 0.4
		_hook_at = best * _anim.clip_length(&"CR_Throw")
	_hand_combos.append_array([
		{"name": &"cleaver_three", "moves": [B_CLEAVE3], "fells": [0], "weight": 1.2},
		{"name": &"butcher_string", "moves": [B_REG, B_BUTT], "fells": [1], "weight": 1.1},
		{"name": &"chop_and_split", "moves": [B_DOWN, B_POUND], "fells": [1], "weight": 0.9},
		{"name": &"slaughter", "moves": [B_POUND, B_POUND, B_POUND], "fells": [2], "weight": 1.4, "rage_only": true},
		{"name": HOOK_COMBO, "moves": [B_BUTT, B_DOWN], "fells": [1], "weight": 0.0, "far": true},
	])


func _own_move(delta: float) -> bool:
	_hook_wait = maxf(_hook_wait - delta, 0.0)
	if hook_state != Hook.NONE:
		mode = Mode.FIGHT
		velocity.x = move_toward(velocity.x, 0.0, acceleration * delta)
		velocity.z = move_toward(velocity.z, 0.0, acceleration * delta)
		if _quarry != null:
			_face(_quarry.global_position - global_position, delta, turn_speed)
		return true
	var gap := _distance_to(_quarry)
	if drill_combo < 0 and _hook_wait <= 0.0 and gap >= hook_from and gap <= hook_to and not _quarry_down() \
			and stamina >= attack_cost and _quarry is Player:
		mode = Mode.FIGHT
		_face(_quarry.global_position - global_position, 1.0, 50.0)
		_hook_thrown = false
		_hook_wait = _rng.randf_range(hook_cooldown.x, hook_cooldown.y) * (0.65 if raging else 1.0)
		_begin(B_HOOK)
		return true
	return super(delta)


func _run_act(delta: float) -> void:
	super(delta)
	if is_dead or not _decides():
		return
	if act == B_HOOK:
		if _quarry != null and _act_time < _hook_at:
			_face(_quarry.global_position - global_position, delta, turn_speed * 1.5)
		if not _hook_thrown and _act_time >= _hook_at:
			_hook_thrown = true
			_throw_hook()
	if act == B_POUND and _pound_cracked != act_serial:
		var ms := _blow_moments(B_POUND)
		if not ms.is_empty() and _act_time >= ms[0]:
			_pound_cracked = act_serial
			_split_ground()
	if act == B_INTRO:
		velocity.x = 0.0
		velocity.z = 0.0


func _physics_process(delta: float) -> void:
	super(delta)
	if not _decides():
		return
	if hook_state != Hook.NONE:
		_fly_hook(delta)
	for i in range(_cracks.size() - 1, -1, -1):
		var c := _cracks[i]
		for who: Node3D in c.reached(delta, get_tree()):
			cracks_hurt += 1
			who.call(&"receive_blow", hit_damage * crack_share, self, 0, 1, c.id, false, &"ground")
		if c.done():
			_cracks.remove_at(i)


func _process(delta: float) -> void:
	super(delta)
	_drip(delta)
	_draw_hook()
#endregion


#region The ground split
func _split_ground() -> void:
	var from := global_position + _forward() * 0.5
	var way := _forward()
	if _quarry != null:
		var to := _quarry.global_position - from
		to.y = 0.0
		if to.length_squared() > 0.25 and to.normalized().dot(_forward()) > 0.4:
			way = to.normalized()
	cracks_made += 1
	_cracks.append(GroundCrack.new(from, way, crack_reach, crack_speed, crack_width, 7000000 + act_serial))
	if is_inside_tree() and multiplayer.has_multiplayer_peer():
		net_split.rpc(from, way)
	else:
		net_split(from, way)


@rpc("authority", "call_local", "reliable")
func net_split(from: Vector3, way: Vector3) -> void:
	GroundCrack.show(self, from, way, crack_reach, crack_speed, Color(0.38, 0.3, 0.26))
#endregion


#region The hook
## Where the hook leaves his hand from: his left (the cleaver in his right).
func _hook_hand() -> Vector3:
	var fig_skel := figure.find_child("Skeleton3D", true, false) as Skeleton3D if figure != null else null
	if fig_skel != null:
		var b := fig_skel.find_bone("Hand_L")
		if b >= 0:
			return fig_skel.global_transform * fig_skel.get_bone_global_pose(b).origin
	return global_position + Vector3.UP * 1.8


## Host: the hook let go at him, aimed where he will be.
func _throw_hook() -> void:
	if _quarry == null:
		return
	hooks_thrown += 1
	var from := _hook_hand()
	var aim := _quarry.global_position + Vector3.UP * 1.1
	if _quarry is CharacterBody3D:
		var v := (_quarry as CharacterBody3D).velocity
		aim += Vector3(v.x, 0.0, v.z) * clampf(from.distance_to(aim) / hook_speed, 0.0, 0.5)
	_hook_pos = from
	_hook_dir = (aim - from).normalized()
	_hook_went = 0.0
	_send_hook(Hook.OUT)


func _fly_hook(delta: float) -> void:
	if hook_state == Hook.OUT:
		var step := hook_speed * delta
		_hook_pos += _hook_dir * step
		_hook_went += step
		for node in get_tree().get_nodes_in_group(&"player"):
			var who := node as Player
			if who == null or who.is_dead:
				continue
			if (who.global_position + Vector3.UP * 1.1).distance_to(_hook_pos) > 1.1:
				continue
			if who.is_evading():
				continue
			_hook_held = who
			hooks_caught += 1
			who.receive_blow(hit_damage * hook_share, self, 0, 3, 8000000 + act_serial)
			who.grab_by(self, 3.0)
			_send_hook(Hook.PULL)
			return
		if _hook_went >= hook_range or _hook_pos.y < global_position.y + 0.2:
			_send_hook(Hook.BACK)
		return
	var home := _hook_hand()
	var stop := 0.4
	var pace := hook_back
	if hook_state == Hook.PULL:
		home = global_position + _forward() * (body_radius * visual_scale + 1.3) + Vector3.UP * 1.2
		stop = 0.3
		pace = hook_pull
	var to := home - _hook_pos
	var d := to.length()
	var step := pace * delta
	if d <= maxf(stop, step):
		_hook_pos = home
		var held := _hook_held
		_hook_held = null
		_send_hook(Hook.NONE)
		if held != null and is_instance_valid(held):
			held.call(&"release_grab")
			var c := _combo_named(HOOK_COMBO)
			if c >= 0 and not is_dead:
				start_hand_combo(c)
		return
	_hook_pos += to / d * step


## Host: where he hangs while the hook has him ([method Player.grab_by]).
func grab_point() -> Vector3:
	return _hook_pos if hook_state != Hook.NONE else global_position + _forward() * 2.0 + Vector3.UP * 1.2


func _send_hook(state: int) -> void:
	if is_inside_tree() and multiplayer.has_multiplayer_peer():
		net_hook.rpc(state, _hook_pos, _hook_dir)
	else:
		net_hook(state, _hook_pos, _hook_dir)


@rpc("authority", "call_local", "reliable")
func net_hook(state: int, at: Vector3, dir: Vector3) -> void:
	var was := hook_state
	hook_state = state
	_hook_pos = at
	if state == Hook.OUT:
		_hook_dir = dir
		Sfx.play_any(self, [CHAIN_SOUND], self, 0.7, 2.0)
	elif state == Hook.PULL:
		ImpactFx.strike(self, at, &"flesh", 1.4)
		Blood.splatter(Blood.world_of(self), at, -dir, null, 1.4)
	elif state == Hook.NONE and was != Hook.NONE:
		ImpactFx.thud(self, at, false)


## Every peer: the hook and its chain from his hand, while it is out.
func _draw_hook() -> void:
	if hook_state == Hook.NONE or is_dead:
		if _hook_node != null:
			_hook_node.visible = false
			_chain.visible = false
		return
	if _hook_node == null:
		_hook_node = Node3D.new()
		_hook_node.name = "MeatHook"
		_hook_node.top_level = true
		add_child(_hook_node)
		if ResourceLoader.exists(HOOK_MESH):
			var m := (load(HOOK_MESH) as PackedScene).instantiate() as Node3D
			m.scale = Vector3.ONE * 2.6
			_hook_node.add_child(m)
		_chain = MeshInstance3D.new()
		_chain.name = "Chain"
		_chain.top_level = true
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.03
		cyl.bottom_radius = 0.03
		cyl.height = 1.0
		cyl.radial_segments = 6
		_chain.mesh = cyl
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.16, 0.15, 0.14)
		mat.metallic = 0.8
		mat.roughness = 0.45
		_chain.material_override = mat
		add_child(_chain)
	# on peers the hook flies on between what the host sends
	if not _decides():
		if hook_state == Hook.OUT:
			_hook_pos += _hook_dir * hook_speed * get_process_delta_time()
	_hook_node.visible = true
	_hook_node.global_position = _hook_pos
	if _hook_dir.length_squared() > 0.01:
		_hook_node.look_at(_hook_pos + _hook_dir, Vector3.UP)
	var hand := _hook_hand()
	var span := _hook_pos - hand
	var len := span.length()
	_chain.visible = len > 0.3
	if len > 0.3:
		var up := span / len
		var side := up.cross(Vector3.UP if absf(up.y) < 0.95 else Vector3.RIGHT).normalized()
		var basis := Basis(side, up, side.cross(up)).orthonormalized()
		_chain.global_transform = Transform3D(basis.scaled_local(Vector3(1.0, len, 1.0)), hand + span * 0.5)
#endregion


#region His coming in
## Woken the first time: he roars where he stands, and his name comes up.
func _rouse(who: Node3D) -> void:
	super(who)
	if _introduced or who == null or is_dead or not _decides():
		return
	_introduced = true
	velocity = Vector3.ZERO
	if who != null:
		_face(who.global_position - global_position, 1.0, 50.0)
	_begin(B_INTRO)
	if is_inside_tree() and multiplayer.has_multiplayer_peer():
		net_intro.rpc()
	else:
		net_intro()


## Every peer: his roar, and his name across the lower screen, Elden Ring's
## way: it comes up, holds, and goes.
@rpc("authority", "call_local", "reliable")
func net_intro() -> void:
	Sfx.play_any(self, [ROAR_SOUND], self, 0.8, 4.0)
	var layer := CanvasLayer.new()
	layer.layer = 40
	var label := Label.new()
	label.text = TITLE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.anchor_left = 0.0
	label.anchor_right = 1.0
	label.anchor_top = 0.68
	label.anchor_bottom = 0.68
	label.offset_top = -40
	label.offset_bottom = 40
	label.add_theme_font_size_override(&"font_size", 54)
	label.add_theme_color_override(&"font_color", Color(0.92, 0.82, 0.62))
	label.add_theme_color_override(&"font_outline_color", Color(0.05, 0.02, 0.02))
	label.add_theme_constant_override(&"outline_size", 10)
	label.modulate.a = 0.0
	layer.add_child(label)
	var world := Blood.world_of(self)
	(world if world != null else get_tree().root).add_child(layer)
	var tw := label.create_tween()
	tw.tween_property(label, "modulate:a", 1.0, 0.6)
	tw.tween_interval(2.4)
	tw.tween_property(label, "modulate:a", 0.0, 1.0)
	tw.tween_callback(layer.queue_free)
#endregion
