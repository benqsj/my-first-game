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
## * **The hook** on its chain: from off he hurls it at him with his free
##   left hand; caught, he is hauled in to the butcher's feet and met with the
##   chop.
##   A roll slips it.
## * **The ground split**: the cleaver brought down so the ground cracks out
##   at him along a line; enraged, three of them running.
## * **Combos**: Mixamo's two-handed club string; UAL 2's sword string
##   ending in the chop; the chop held at the top, then the ground.
## * **His coming in**: woken, he roars, and his name comes up on the screen.

## (his apron made white and bloodied: vepxis-art/tools/butcher_apron.py)
const FIGURE := "res://assets/monsters/synty_rivals/pig_butcher_white.glb"
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
const B_DOWN := 243
const B_POUND := 244
const B_HOOK := 245
const B_INTRO := 246
const B_C1 := 247
const B_C2 := 248
const B_C3 := 249
const B_HORIZ := 250
const B_BACK := 251
const B_SPIN := 252
const B_CLUB1 := 253
const B_BASH := 254
## Mixamo's, his own (2026-10-23, the user's pick): the one-handed sword
## string, the thrust and cut, the leap at him from a run, the low spin.
const B_SWORD3 := 255
const B_THRUST := 256
const B_LEAP := 257
const B_LOWSPIN := 258
const HOOK_COMBO := &"hooked"
const SIDE_SPIN := &"side_spin"
const SIDE_LOW := &"side_low"
## His foot (a stamp on him lying).
const FEET := "R_knee_joint>R_ankle_joint:0.3|L_knee_joint>L_ankle_joint:0.3"

enum Hook { NONE, OUT, PULL, BACK }

## The cleaver's size (1: Synty's, 1.5 m) and a turn about its haft (degrees)
## to set its edge.
@export var cleaver_scale: float = 1.15
@export var cleaver_roll: float = 260.0
@export var cleaver_radius: float = 0.3
## The haft's grip on the cleaver (its height up the haft, the cleaver's own
## units), where the palm is between wrist and knuckles, which way its edge
## faces (1: the knuckles' way), which way the fingers close (1 or -1).
@export var haft_grip: float = 0.12
@export var palm_share: float = 0.55
@export var edge_sign: float = 1.0
@export var fist_sign: float = 1.0

@export_group("Hook")
## The cut in the air his cleaver leaves, as the heroes' blades do (Tariel's
## look); drawn while its edge goes faster than this (m/s) in a blow.
const ARC_STYLE := {"life": 0.26, "intensity": 1.0, "sheet": 0.5, "taper": 0.35, "smear": 1.0,
		"tip_overshoot": 0.04}
## Where (bearing off his front, degrees, + to his left) each blow of a move
## really crosses a man's height, and when (act seconds, at his pace) where
## the wrist's fastest moment was off the cut — measured with
## `_shots_tmp/move_probe.gd` (2026-10-23, the user's word: standing still,
## his strings still missed). Spins land all round and need none.
const CUT_AIM := {
	240: [-42.0, 0.0, -32.0], 241: [16.0, 23.0, -35.0], 247: [-3.0, 40.0], 248: [6.0, 4.0, -8.0],
	249: [-18.0, -18.0], 250: [-6.0], 251: [-12.0], 253: [-15.0, -39.0, -16.0], 254: [13.0],
	255: [23.0, -46.0, -5.0], 256: [-12.0, -5.0], 257: [-15.0], 62: [-9.0],
}
const CUT_AT := {
	240: [1.08, 2.08, 2.93], 247: [1.47, 2.18], 255: [0.80, 1.55, 2.35],
}
## The cleaver's edge, in its own frame: its blade runs from the haft (z ~0)
## out to z 0.365 (measured, `_shots_tmp/cleaver_aabb.gd`).
const ARC_EDGE_Z := 0.3
@export var arc_speed: float = 6.0
## (His string left off with him far: [OrcFighter]'s `string_leave`. His
## glide and his turn in a move are held by [PackBrute]'s `glide_most` and
## `act_turn_most`, set in `_ready`.)
## Him gone round to his side close by (further than `side_angle` off his
## front, or going round him faster than `side_orbit` degrees a second),
## he spins on him, the cleaver round the whole of him (the user's word,
## 2026-10-23: running round him, nothing he swung found him).
@export var side_angle: float = 60.0
@export var side_orbit: float = 70.0
@export var side_near: float = 4.2
@export var side_cooldown: Vector2 = Vector2(3.5, 6.0)
## Dust where his cleaver comes down into the ground: its edge within this of
## the ground (m), coming down at least this fast (m/s).
@export var dust_touch: float = 0.12
@export var dust_fall: float = 2.5
## The hook thrown at him from afar (off: the user's word, 2026-10-23).
@export var hook_on: bool = false
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
var _fig_skel: Skeleton3D
var _fig_hand: int = -1
var _hand_twist: Quaternion = Quaternion.IDENTITY
## [bone, its rest turn, the bend laid on it]
var _curls: Array = []
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
## Every peer: the cut in the air his cleaver leaves (the heroes' own), and
## where its edge was last frame (its speed; the dust where it meets the ground).
var _arc: BladeArc
var _arc_base: Node3D
var _arc_tip: Node3D
var _air_frame: int = -1
var _arc_base_local: Vector3
var _arc_tip_local: Vector3
var _arc_last: Vector3 = Vector3.INF
var _low_last: Vector3 = Vector3.INF
var _dust_wait: float = 0.0
## dust thrown up where his cleaver meets the ground, counted (tests)
var ground_dusts: int = 0
## Every peer: his pace his rage's from the first; his cleaver's rot (enraged).
var _fierce: bool = false
var _rot: Node3D
var _rot_lamp: OmniLight3D
## Host: him going round to his side — how fast (degrees a second about him,
## smoothed), where he was last, and the wait before the next spin at it.
var _orbit_rate: float = 0.0
var _orbit_last: float = INF
var _orbit_frame: int = -10
var _side_wait: float = 0.0
## spins made at him gone round to his side (tests)
var side_spins: int = 0
## his blows that reached him, all and his spins' (tests, probes)
var blows_landed: int = 0
var spin_blows_landed: int = 0
## Host: each move's blows swung and landed ({act: [swung, landed]}; probes)
var blow_tally: Dictionary = {}
## For the tests.
var hooks_thrown: int = 0
var hooks_caught: int = 0
var cracks_made: int = 0
var cracks_hurt: int = 0


func _ready() -> void:
	act_turn_most = 200.0
	glide_most = 1.2
	glide_gap = 1.0
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
	_fig_skel = fig_skel
	_fig_hand = fig_skel.find_bone("Hand_R")
	# the great axe's line: what its blows were measured along
	var box := axe.get_aabb()
	var hand := grip.global_position
	var far := hand
	for k in 8:
		var p := axe.global_transform * box.get_endpoint(k)
		if p.distance_to(hand) > far.distance_to(hand):
			far = p
	var up := (far - hand).normalized()
	# his hand turned so a fist would hold that line: the line across his
	# palm (from his little finger's side to his first finger's) laid on it
	var across := (_bone_at("IndexFinger_01.001") - _bone_at("Finger_01.001")).normalized()
	var g0 := (fig_skel.global_transform * fig_skel.get_bone_global_pose(_fig_hand)).basis.orthonormalized()
	var turn := Basis(Quaternion(across, up))
	_hand_twist = (g0.inverse() * turn * g0).get_rotation_quaternion()
	# and closed: the right hand round the haft, the left loosely
	_curls.clear()
	_fist(["Finger_01.001", "Finger_02.001", "Finger_03.001"], [75.0, 85.0, 60.0], across, fist_sign)
	_fist(["IndexFinger_01.001", "IndexFinger_02.001", "IndexFinger_03.001"], [70.0, 85.0, 60.0], across, fist_sign)
	_fist(["Thumb_02.001", "Thumb_03.001"], [25.0, 35.0], across, fist_sign)
	var across_l := (_bone_at("IndexFinger_01") - _bone_at("Finger_01")).normalized()
	_fist(["Finger_01", "Finger_02", "Finger_03"], [40.0, 45.0, 30.0], across_l, -fist_sign)
	_fist(["IndexFinger_01", "IndexFinger_02", "IndexFinger_03"], [35.0, 45.0, 30.0], across_l, -fist_sign)
	if follower != null and not follower.followed.is_connected(_after_follow):
		follower.followed.connect(_after_follow)
	_after_follow()
	fig_skel.force_update_all_bone_transforms()
	# the cleaver in that fist: its haft through the palm, along the line,
	# its edge the way the knuckles face
	var hand_now := fig_skel.global_transform * fig_skel.get_bone_global_pose(_fig_hand)
	var base := _bone_at("Finger_01.001")
	var tip := _bone_at("Finger_02.001")
	var knuckles := (tip - base)
	knuckles -= up * knuckles.dot(up)
	var edge := knuckles.normalized() * edge_sign if knuckles.length() > 0.001 else up.cross(Vector3.UP).normalized()
	edge = edge.rotated(up, deg_to_rad(cleaver_roll))
	var x := up.cross(edge).normalized()
	var palm := hand_now.origin.lerp(base, palm_share)
	var want := Transform3D(Basis(x, up, edge).orthonormalized().scaled(Vector3.ONE * cleaver_scale),
			palm + up * haft_grip * cleaver_scale)
	_cleaver = (load(CLEAVER) as PackedScene).instantiate() as Node3D
	_cleaver.name = "Cleaver"
	grip.add_child(_cleaver)
	# the attachment's frame as the turned hand has it now (it follows from here)
	_cleaver.transform = hand_now.affine_inverse() * want
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
	_make_arc(top, side)
	# the left hand is his own (the hook is thrown from it): not drawn onto
	# the haft as the orc's is onto its great axe's
	if _skeleton != null:
		for c in _skeleton.get_children():
			if c is TwoHandGrip:
				(c as TwoHandGrip).active = false


func _bone_at(name: String) -> Vector3:
	var b := _fig_skel.find_bone(name)
	if b < 0:
		return _fig_skel.global_position
	return _fig_skel.global_transform * _fig_skel.get_bone_global_pose(b).origin


## Each of `names` (one finger, root first) bent `angles` degrees about the
## line across the palm (`across`, the world as the hand stands now).
func _fist(names: Array, angles: Array, across: Vector3, sign: float) -> void:
	for i in names.size():
		var b := _fig_skel.find_bone(String(names[i]))
		if b < 0:
			continue
		var g := (_fig_skel.global_transform * _fig_skel.get_bone_global_pose(b)).basis.orthonormalized()
		var axis := (g.inverse() * across).normalized()
		var rest := _fig_skel.get_bone_rest(b).basis.get_rotation_quaternion()
		_curls.append([b, rest, Quaternion(axis, deg_to_rad(float(angles[i])) * sign)])


## Every peer, each time the figure is posed off the rig: his right hand
## turned onto the haft, his fingers closed.
func _after_follow() -> void:
	if _fig_skel == null or _fig_hand < 0:
		return
	_fig_skel.set_bone_pose_rotation(_fig_hand, _fig_skel.get_bone_pose_rotation(_fig_hand) * _hand_twist)
	for c: Array in _curls:
		_fig_skel.set_bone_pose_rotation(int(c[0]), (c[1] as Quaternion) * (c[2] as Quaternion))
	_place_arc()
	# the cut and the dust off the blade as it is now posed (not a frame late)
	if is_inside_tree() and Engine.get_process_frames() != _air_frame:
		_air_frame = Engine.get_process_frames()
		_cleaver_air(get_process_delta_time())
		if _arc != null:
			_arc.tick(get_process_delta_time())


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


## Every peer: the heroes' cut in the air (Tariel's look), along his blade.
func _make_arc(top: float, side: float) -> void:
	# along his blade's edge (its far side from the haft), where it is blade,
	# not haft; placed each time his figure is posed ([method _place_arc]),
	# not as children of the cleaver: those are where it was a frame ago (the
	# user's word, 2026-10-23: the line was off the blade)
	_arc_base_local = Vector3(0.0, top * 0.38, ARC_EDGE_Z)
	_arc_tip_local = Vector3(0.0, top * 0.97, ARC_EDGE_Z)
	var base := Marker3D.new()
	base.top_level = true
	add_child(base)
	var tip := Marker3D.new()
	tip.top_level = true
	add_child(tip)
	_arc_base = base
	_arc_tip = tip
	_place_arc()
	_arc = BladeArc.new()
	_arc.name = "CleaverArc"
	# the bent air the heroes' cuts leave, not the plain streak
	_arc.air = true
	_arc.manual = true
	add_child(_arc)
	_arc.setup(base, tip)
	for key: String in ARC_STYLE:
		_arc.set(key, ARC_STYLE[key])
	_arc.restyle()


## Every peer: the cleaver as it is this frame, from the pose just set (its
## node's own transform is still last frame's until the skeleton updates).
func _cleaver_now() -> Transform3D:
	if _cleaver == null or not is_instance_valid(_cleaver):
		return Transform3D.IDENTITY
	var grip := _cleaver.get_parent() as BoneAttachment3D
	if grip == null or _fig_skel == null or grip.bone_idx < 0:
		return _cleaver.global_transform
	return _fig_skel.global_transform * _fig_skel.get_bone_global_pose(grip.bone_idx) * _cleaver.transform


func _place_arc() -> void:
	if _arc_base == null or _arc_tip == null:
		return
	var t := _cleaver_now()
	_arc_base.global_position = t * _arc_base_local
	_arc_tip.global_position = t * _arc_tip_local


## Every peer: the cut drawn while the cleaver swings hard in a blow; and
## where it comes down into the ground, dust thrown up there, that moment.
func _cleaver_air(delta: float) -> void:
	_dust_wait = maxf(_dust_wait - delta, 0.0)
	if _cleaver == null or not is_instance_valid(_cleaver) or delta <= 0.0:
		return
	var t := _cleaver_now()
	var tip := t * _edge_to
	var swinging := act != Act.NONE and _strikes().has(act) and not is_dead
	var fast := _arc_last != Vector3.INF and tip.distance_to(_arc_last) / delta > arc_speed
	_arc_last = tip
	if _arc != null:
		_arc.emitting = swinging and fast and _cleaver.is_visible_in_tree()
	# the lowest of its edge
	var low := tip
	for k in 4:
		var p := t * _edge_from.lerp(_edge_to, float(k) / 3.0)
		if p.y < low.y:
			low = p
	var ground := global_position.y
	var was := _low_last
	_low_last = low
	if not swinging or was == Vector3.INF or _dust_wait > 0.0:
		return
	var falling := (was.y - low.y) / delta
	if low.y <= ground + dust_touch and was.y > ground + dust_touch and falling > dust_fall:
		_dust_wait = 0.35
		ground_dusts += 1
		_ground_dust(Vector3(low.x, ground + 0.05, low.z), clampf(falling / 10.0, 0.7, 1.4))


## Every peer: dust off the ground where the cleaver went in (no ring).
func _ground_dust(at: Vector3, power: float) -> void:
	GroundFx.weapon_dust(Blood.world_of(self), at, power)


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
	blows_landed += 1
	if blow_tally.has(what):
		(blow_tally[what] as Array)[1] += 1
	if what == B_SPIN or what == B_LOWSPIN:
		spin_blows_landed += 1
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
	_hand_move(B_DOWN, &"CR_OG_Attack_Downward", Vector3(1.0 / hp, 0.05, 0.8), 1.1, "")
	_holds[B_DOWN] = [0.45, 0.35, 0.8, 0.25]
	_hand_move(B_POUND, &"CR_GroundPound", Vector3(0.8 / hp, 0.0, 0.95), 1.0, "")
	_windups[B_POUND] = [1.35, 0.2]
	_snap[B_POUND] = 1.4
	_kinds[B_POUND] = &"crush"
	_special(B_HOOK, &"CR_Throw", Vector3(1.0, 0.0, 0.75))
	_special(B_INTRO, &"CR_OG_Battlecry", Vector3(1.0, 0.0, 0.9))
	# (UAL 2's overhand throw is thrown with the left hand on this skeleton;
	# the hook leaves that hand at the wrist's fastest)
	if _anim != null and _anim.clip_length(&"CR_Throw") > 0.0:
		var peaks := _anim.measure_peaks(&"CR_Throw", PackedStringArray(["L_wrist_joint"]), 0.6, 0.12)
		var best := float(peaks[0]) if not peaks.is_empty() else 0.4
		_hook_at = best * _anim.clip_length(&"CR_Throw")
	# his own blows, not the orc's (the user's word, 2026-10-23: he played the
	# orc's combos one for one): Mixamo's one-handed axe set — its strings
	# and its single cuts — the one-handed club string, the overhead bash
	_hand_move(B_C1, &"CR_OG_Combo_1", Vector3(1.0 / hp, 0.03, 0.85), 0.7, "", _blows_in(&"CR_OG_Combo_1", 2))
	_hand_move(B_C2, &"CR_OG_Combo_2", Vector3(1.0 / hp, 0.03, 0.85), 0.7, "", _blows_in(&"CR_OG_Combo_2", 3))
	_hand_move(B_C3, &"CR_OG_Combo_3", Vector3(1.0 / hp, 0.03, 0.85), 0.75, "", _blows_in(&"CR_OG_Combo_3", 2))
	_hand_move(B_HORIZ, &"CR_OG_Attack_Horizontal", Vector3(1.0 / hp, 0.05, 0.8), 0.9, "")
	_hand_move(B_BACK, &"CR_OG_Attack_Backhand", Vector3(1.0 / hp, 0.05, 0.75), 0.85, "")
	_hand_move(B_SPIN, &"CR_OG_Attack_360", Vector3(1.05 / hp, 0.05, 0.75), 1.0, "")
	_hand_move(B_CLUB1, &"CR_OG_Club_Combo1H", Vector3(1.0 / hp, 0.03, 0.85), 0.7, "", _blows_in(&"CR_OG_Club_Combo1H", 3))
	_hand_move(B_BASH, &"CR_OG_Bash", Vector3(1.0 / hp, 0.05, 0.8), 1.15, "")
	for what: int in [B_C1, B_C2, B_C3, B_CLUB1, B_HORIZ, B_BACK]:
		_slow_to[what] = 0.5
	_windups[B_BASH] = [1.35, 0.2]
	_snap[B_BASH] = 1.35
	_kinds[B_BASH] = &"crush"
	_holds[B_SPIN] = [0.35, 0.3, 0.7, 0.25]
	_holds[B_C3] = [0.3, 0.3, 0.6, 0.25]
	# his plain blows the axe set's too
	var plain: Array[StringName] = [&"CR_OG_Attack_Downward", &"CR_OG_Attack_Horizontal", &"CR_OG_Attack_Backhand"]
	for i in plain.size():
		_hand_move(ATTACK_BASE + i, plain[i], Vector3(1.0 / hp, 0.05, 0.8), 1.0, "")
	attacks = plain
	# his boot, and his foot down on him where he lies
	_special(KICK, &"CR_SpartaKick", Vector3(1.1, 0.0, 0.8))
	_hand_move(O_STAB, &"CR_OG_Stomp", Vector3(1.0 / hp, 0.05, 0.8), 0.9, FEET)
	_kinds[O_STAB] = &"stomp"
	# Mixamo's, fresh for him (2026-10-23, the user's pick of twelve)
	_hand_move(B_SWORD3, &"CR_BU_OneHand_Sword_Combo", Vector3(1.0 / hp, 0.03, 0.85), 0.75, "", _blows_in(&"CR_BU_OneHand_Sword_Combo", 3))
	_hand_move(B_THRUST, &"CR_BU_Thrust_Slash", Vector3(1.0 / hp, 0.03, 0.85), 0.75, "", _blows_in(&"CR_BU_Thrust_Slash", 2))
	_hand_move(B_LEAP, &"CR_BU_Run_Jump_Attack", Vector3(1.0 / hp, 0.03, 0.85), 1.1, "")
	_kinds[B_LEAP] = &"crush"
	_hand_move(B_LOWSPIN, &"CR_BU_Attack_360_Low", Vector3(1.0 / hp, 0.03, 0.85), 0.9, "")
	for what: int in [B_SWORD3, B_THRUST, B_LOWSPIN]:
		_slow_to[what] = 0.5
	hand_combo_chance = Vector2(0.9, 0.9)
	# any of them any time, the same again now and then (the user's word:
	# mixed up, not one after another in turn)
	repeat_damp = 1.0
	# in to him on his feet before a string, not glided the last of the way
	# (the user's word, 2026-10-23: he slid)
	combo_slack = 0.45
	# into the next of a string turned through its wind-up, not at once
	chain_snap = 0.0
	_hand_combos = [
		# Mixamo: three chops on end
		{"name": &"three_chops", "moves": [B_C2], "fells": [0], "weight": 1.2},
		{"name": &"chop_chop", "moves": [B_C1, B_DOWN], "fells": [1], "weight": 1.0},
		{"name": &"spin_cleave", "moves": [B_SPIN, B_C3], "fells": [1], "weight": 0.9},
		{"name": &"sword_string", "moves": [B_SWORD3], "fells": [0], "weight": 1.2},
		{"name": &"thrust_cut", "moves": [B_THRUST], "fells": [0], "weight": 1.1},
		{"name": &"leap_in", "moves": [B_LEAP], "fells": [0], "weight": 1.0},
		{"name": &"low_spin", "moves": [B_LOWSPIN], "fells": [0], "weight": 1.0},
		{"name": &"string_and_spin", "moves": [B_SWORD3, B_LOWSPIN], "fells": [1], "weight": 0.9},
		{"name": &"thrust_and_string", "moves": [B_THRUST, B_SWORD3], "fells": [1], "weight": 0.8},
		{"name": &"leap_and_thrust", "moves": [B_LEAP, B_THRUST], "fells": [1], "weight": 0.8},
		{"name": &"club_string", "moves": [B_CLUB1], "fells": [0], "weight": 0.9},
		{"name": &"cleaver_three", "moves": [B_CLEAVE3], "fells": [0], "weight": 0.8},
		{"name": &"bash_split", "moves": [B_BASH, B_POUND], "fells": [1], "weight": 0.8},
		{"name": &"chop_and_split", "moves": [B_DOWN, B_POUND], "fells": [1], "weight": 0.8},
		# UAL 2's sword string, then the chop
		{"name": &"butcher_string", "moves": [B_REG, B_DOWN], "fells": [1], "weight": 1.0},
		{"name": &"slaughter", "moves": [B_POUND, B_POUND, B_POUND], "fells": [2], "weight": 0.7, "always": true},
		{"name": &"frenzy", "moves": [B_C1, B_HORIZ, B_C2], "fells": [2], "weight": 0.9, "always": true},
		{"name": &"butchery", "moves": [B_SWORD3, B_THRUST, B_LOWSPIN], "fells": [2], "weight": 1.0, "always": true},
		{"name": HOOK_COMBO, "moves": [B_DOWN], "fells": [0], "weight": 0.0, "far": true},
		# (the orc's own kinds of answer, in his blows)
		{"name": COUNTER_COMBO, "moves": [B_BACK], "fells": [0], "weight": 0.0, "far": true},
		{"name": TRAP_COMBO, "moves": [B_HORIZ], "fells": [0], "weight": 0.0, "far": true},
		{"name": FETCH_COMBO, "moves": [B_SPIN], "fells": [0], "weight": 0.0, "far": true},
		# him gone round to his side: a spin, high or low ([method _try_side])
		{"name": SIDE_SPIN, "moves": [B_SPIN], "fells": [0], "weight": 0.0, "far": true},
		{"name": SIDE_LOW, "moves": [B_LOWSPIN], "fells": [0], "weight": 0.0, "far": true},
	]

	_always_fierce()


## The moments of a clip's blows (its weapon hand at its fastest), if there
## are `n` of them; else none (each move's blow put where it reaches).
func _blows_in(clip: StringName, n: int) -> Array:
	if _anim == null or _anim.clip_length(clip) <= 0.0:
		return []
	var peaks := _anim.measure_peaks(clip, PackedStringArray(["R_wrist_joint"]), 0.6, 0.12)
	if peaks.size() < n:
		return []
	var out := []
	for i in n:
		out.append(float(peaks[i]))
	return out


## Host: his bearing on him, and how fast he goes round (smoothed), kept
## every frame; him at his side close by, now and then, a spin at him.
func _try_side(delta: float) -> bool:
	_side_wait = maxf(_side_wait - delta, 0.0)
	if _quarry == null or delta <= 0.0:
		return false
	var to := _quarry.global_position - global_position
	to.y = 0.0
	var bearing := atan2(to.x, to.z)
	var frame := Engine.get_physics_frames()
	if frame - _orbit_frame > 2:
		_orbit_last = INF
	_orbit_frame = frame
	if _orbit_last != INF:
		var rate := absf(rad_to_deg(wrapf(bearing - _orbit_last, -PI, PI))) / delta
		_orbit_rate = lerpf(_orbit_rate, rate, clampf(delta * 4.0, 0.0, 1.0))
	_orbit_last = bearing
	if drill_combo >= 0 or _side_wait > 0.0 or act != Act.NONE or _hand_combo >= 0 or _quarry_down() \
			or stamina < attack_cost * 0.5 or to.length() > side_near or to.length() < 0.3:
		return false
	var off := rad_to_deg(_forward().angle_to(to.normalized()))
	if off < side_angle and not (_orbit_rate > side_orbit and off > 30.0):
		return false
	var which := _combo_named(SIDE_SPIN if _rng.randf() < 0.55 else SIDE_LOW)
	if which < 0:
		return false
	_side_wait = _rng.randf_range(side_cooldown.x, side_cooldown.y) * (0.6 if raging else 1.0)
	side_spins += 1
	start_hand_combo(which)
	return true


## Its spins land the whole way round (the cleaver goes round him from a
## little before the blow to a little after: measured, `_shots_tmp/spin_probe.gd`),
## not only where he faces.
func _blow_window_for(what: int) -> Vector2:
	if what == B_SPIN:
		return Vector2(0.22, 0.22)
	if what == B_LOWSPIN:
		return Vector2(0.35, 0.22)
	return super(what)


## Every peer: from the first he fights at the pace the others keep for their
## rage — quick on his feet, in his swings, hardly a breath between strings,
## all his strings his (the user's word, 2026-10-23: as fast as enraged, and
## always so); his rage is only his cleaver's rot ([method net_rage]).
func _always_fierce() -> void:
	if _fierce:
		return
	_fierce = true
	_moves_table.erase(RAGE)
	speed *= rage_pace
	chase_speed *= rage_pace
	close_speed *= rage_pace
	attack_cooldown *= 0.4
	stamina_regen *= 1.6
	for what: int in _moves_table:
		var m: Array = (_moves_table[what] as Array).duplicate()
		m[1] = float(m[1]) * rage_pace
		_moves_table[what] = m


## Every peer: at half his health his blows land harder (`rage_harder`) and
## his cleaver rots — a green flame up it, a reek off it, flies all round it;
## he himself does not redden. His pace was his rage's from the first.
@rpc("authority", "call_local", "reliable")
func net_rage() -> void:
	if raging:
		return
	raging = true
	_rot_on()


@rpc("authority", "call_local", "reliable")
func net_calm() -> void:
	if not raging:
		return
	raging = false
	_rot_off()


## (Not the red glow on his body the others take.)
func _glow_on() -> void:
	pass


func _glow_off() -> void:
	pass


func _rot_on() -> void:
	_rot_off()
	if _cleaver == null or not is_instance_valid(_cleaver):
		return
	var top := _edge_to.y / 0.95
	var mid := Vector3(0.0, top * 0.66, ARC_EDGE_Z * 0.55)
	var holder := Node3D.new()
	holder.name = "Rot"
	_cleaver.add_child(holder)
	holder.position = mid
	_rot = holder
	var blade_len := top * 0.32
	# no flame (the user's word, 2026-10-23): a green reek steaming up off the
	# blade — soft, slow, left in the air as it swings and rising there
	SkillFx.particles(holder, holder.global_position, {
		"amount": 70, "life": 1.5, "add": false,
		"speed": Vector2(0.1, 0.35), "dir": Vector3.UP, "spread": 30.0, "gravity": Vector3(0, 0.55, 0),
		"damping": 0.8, "size": Vector2(0.22, 0.42), "grow": 0.55, "box": Vector3(0.05, blade_len, 0.18),
		"colors": [Color(0.42, 0.62, 0.2, 0.0), Color(0.38, 0.6, 0.18, 0.42), Color(0.32, 0.48, 0.16, 0.22),
				Color(0.28, 0.4, 0.14, 0.0)],
	})
	# ...and close on the blade itself, a thin steam that stays with it
	SkillFx.particles(holder, holder.global_position, {
		"amount": 30, "life": 0.8, "add": false, "local": true,
		"speed": Vector2(0.05, 0.2), "dir": Vector3.UP, "spread": 40.0, "gravity": Vector3.ZERO,
		"damping": 0.5, "size": Vector2(0.15, 0.28), "grow": 0.5, "box": Vector3(0.05, blade_len, 0.16),
		"colors": [Color(0.45, 0.68, 0.22, 0.0), Color(0.42, 0.66, 0.2, 0.35), Color(0.35, 0.55, 0.18, 0.0)],
	})
	# flies, a swarm, about it every way, keeping to it as it swings: bigger
	# and black, to be seen
	var flies := SkillFx.particles(holder, holder.global_position, {
		"amount": 160, "life": 2.2, "add": false, "local": true,
		"speed": Vector2(0.8, 1.8), "dir": Vector3.UP, "spread": 180.0, "gravity": Vector3.ZERO,
		"damping": 0.0, "size": Vector2(0.05, 0.08), "grow": 0.05, "sphere": 0.6,
		"orbit": -2.8, "tangent": 3.4,
		"colors": [Color(0.02, 0.02, 0.015, 0.0), Color(0.02, 0.02, 0.015, 1.0), Color(0.02, 0.02, 0.015, 1.0),
				Color(0.02, 0.02, 0.015, 0.0)],
	})
	var pm := flies.process_material as ParticleProcessMaterial
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 3.5
	pm.turbulence_noise_scale = 1.4
	pm.turbulence_noise_speed = Vector3(0.8, 0.8, 0.8)
	pm.turbulence_influence_min = 0.4
	pm.turbulence_influence_max = 0.85
	# the moment it takes: a puff of the reek off it, no ring
	SkillFx.particles(Blood.world_of(self), holder.global_position, {
		"amount": 30, "life": 1.6, "one_shot": true, "explosiveness": 0.9, "add": false,
		"speed": Vector2(0.4, 1.2), "dir": Vector3.UP, "spread": 70.0, "gravity": Vector3(0, 0.5, 0),
		"damping": 1.2, "size": Vector2(0.35, 0.7), "grow": 0.5, "box": Vector3(0.05, blade_len, 0.2),
		"colors": [Color(0.42, 0.62, 0.2, 0.0), Color(0.38, 0.6, 0.18, 0.5), Color(0.28, 0.4, 0.14, 0.0)],
	})

func _rot_off() -> void:
	if _rot != null and is_instance_valid(_rot):
		_rot.queue_free()
	_rot = null
	_rot_lamp = null


## Host: its blows armed — counted (`blow_tally`).
func _arm(what: int) -> void:
	super(what)
	if not blow_tally.has(what):
		blow_tally[what] = [0, 0]
	(blow_tally[what] as Array)[0] += _blow_moments(what).size()


## Not the orc's fall from the sky (the user's word, 2026-10-23: another's).
func _try_leap() -> bool:
	return false


## Host: in a string, before each of its blows (not only the first) he turns
## after him, and what the clip carries goes the way he now faces: a dodged
## string does not run on the way it began (the user's word, 2026-10-23).
func _carry(delta: float) -> Vector3:
	if _quarry != null and _strikes().has(act) and _blow_moments(act).size() > 1:
		var ms := _blow_moments(act)
		var next := -1
		var prev := -1.0
		for i in ms.size():
			if ms[i] > _act_time:
				next = i
				break
			prev = ms[i]
		if prev >= 0.0 and next > 0 and _act_time > prev + 0.08 and _act_time < ms[next] - _track_lock(act):
			_face(_aimed(act, next), delta, _track_rate(act))
			_reframe()
	return super(delta)


## Host: before a move's first blow, turned so its cut crosses him.
func _track_before_blow(delta: float) -> void:
	if _quarry == null:
		return
	var first := _blow_moments(act)[0]
	if _act_time < first - _track_lock(act):
		_face(_aimed(act, 0), delta, _track_rate(act))
		_reframe()


## The way to face so blow `i` of move `what` crosses him: the cleaver does
## not cut along his nose in every swing — some come in from his side
## (measured, `_shots_tmp/move_probe.gd`: the bearing off his front where the
## blade passes at a man's height); turned that much off him, it meets him.
func _aimed(what: int, i: int) -> Vector3:
	var to := _quarry.global_position - global_position
	to.y = 0.0
	var aims: Array = CUT_AIM.get(what, [])
	if i < aims.size() and to.length_squared() > 0.0001:
		to = to.rotated(Vector3.UP, -deg_to_rad(float(aims[i])))
	return to


## His blows where the cleaver really cuts (act seconds at his pace), where
## the hand's fastest moment is not the cut (measured): else as measured.
func _blow_moments(what: int) -> PackedFloat32Array:
	if CUT_AT.has(what):
		return PackedFloat32Array(CUT_AT[what])
	return super(what)


## Host: in a string, his steps in under his blows never a glide faster than
## `glide_most` (the orc's string steps in at up to 6 m/s through each
## wind-up); his leap at him carries him by its own run. In a move he turns
## no quicker than `act_turn_most` ([PackBrute]).
func _extra_velocity(delta: float) -> Vector3:
	return _cap_glide(super(delta))


## Host: him run off well out of reach in a string, the rest of it is not
## swung at the air: he goes after him instead.
func _hand_next(what: int) -> int:
	# him gone round to his side mid-string: the rest of it is a spin
	if _quarry != null and _hand_combo >= 0 and _hand_step + 1 < _hand_moves.size() and _decides():
		var to := _quarry.global_position - global_position
		to.y = 0.0
		var next := int(_hand_moves[_hand_step + 1])
		if to.length() < side_near and to.length() > 0.3 and next != B_SPIN and next != B_LOWSPIN \
				and rad_to_deg(_forward().angle_to(to.normalized())) > side_angle + 10.0:
			_hand_moves = _hand_moves.slice(0, _hand_step + 1)
			_hand_moves.append(B_SPIN if _rng.randf() < 0.55 else B_LOWSPIN)
			side_spins += 1
	return super(what)


## Not the orc's battle cry nor its shield-first charge.
func _try_cry() -> bool:
	return false


func _try_charge() -> bool:
	return false


func _own_move(delta: float) -> bool:
	_hook_wait = maxf(_hook_wait - delta, 0.0)
	# at half his health, no stop to roar: his cleaver takes its rot
	if rage_at > 0.0 and not raging and health <= max_health * rage_at and not is_dead:
		_send_rage()
	if _try_side(delta):
		return true
	if hook_state != Hook.NONE:
		mode = Mode.FIGHT
		velocity.x = move_toward(velocity.x, 0.0, acceleration * delta)
		velocity.z = move_toward(velocity.z, 0.0, acceleration * delta)
		if _quarry != null:
			_face(_quarry.global_position - global_position, delta, turn_speed)
		return true
	var gap := _distance_to(_quarry)
	if hook_on and drill_combo < 0 and _hook_wait <= 0.0 and gap >= hook_from and gap <= hook_to and not _quarry_down() \
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
	if _rot_lamp != null and is_instance_valid(_rot_lamp):
		_rot_lamp.light_energy = 0.45 + 0.3 * absf(sin(Time.get_ticks_msec() * 0.011)) * randf_range(0.7, 1.0)
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
