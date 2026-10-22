class_name PigButcher
extends OrcFighter

## The butcher, the boss halfway through the orcs' palace (the user's pick,
## 2026-10-22: Synty's pig butcher, about 2.6 m). He fights as an orc does
## with a great axe — its moves, its stance, its rage — and is seen as the
## Synty figure: the orc's own body is there and posed, unseen, and the
## butcher's skeleton follows it bone by bone ([FigureFollower]), his cleaver
## in his own right hand.

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


func _ready() -> void:
	super()
	_wear_figure()


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
