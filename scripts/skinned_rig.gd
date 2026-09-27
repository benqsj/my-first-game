class_name SkinnedRig
extends CharacterRig

## Tariel as a real skinned character: one Skeleton3D, and the Mixamo sword and
## shield library played on it through an AnimationPlayer.
##
## It stands in for [CharacterRig] everywhere the controller talks to a rig —
## same calls, same answers — so `player.gd` does not know which of the two it
## was handed. The procedural rig is untouched and still drives Avtandil;
## putting Tariel back on it is one line in `tariel.tres`.
##
## The model and every clip come from `assets/tariel_rigged/tariel_rigged.glb`,
## exported from `~/Desktop/vepxis-art/tariel/tariel.blend` (see NOTES.md
## there): the old joint hierarchy turned into a 36-bone skeleton with UE
## mannequin names, every armour plate bound rigidly to one bone so nothing
## stretches, and the Mixamo clips retargeted onto it in Blender.
##
## What the library does not cover — climbing, the slide, sheathing — falls back
## to the nearest pose it does have. Those are marked below.

## Which clip plays for what. Everything the rig decides is looked up here, so a
## second character is a second table (see `SkinnedArcherRig`), not a second rig.
## Set by `_configure()`; these are Tariel's.
var clips := {
	&"idle": &"SS_Idle", &"walk": &"SS_Walk", &"run": &"SS_Run",
	&"walk_back": &"SS_Backward_Walk", &"run_back": &"SS_Backward_Run",
	&"walk_left": &"SS_Left_Strafe_Walk", &"walk_right": &"SS_Right_Strafe_Walk",
	&"run_left": &"SS_Left_Run_Strafe", &"run_right": &"SS_Right_Run_Strafe",
	&"block_idle": &"SS_Block_Idle", &"block_walk": &"SS_Block_Walk",
	&"block_walk_back": &"SS_Block_Walk_Back", &"block_walk_left": &"SS_Block_Walk_Left",
	&"block_walk_right": &"SS_Block_Walk_Right",
	&"crouch": &"SS_Crouch_Block_Idle", &"air": &"SS_Running_Jump",
	&"crouch_walk": &"SS_Crouch_Walk", &"crouch_walk_back": &"SS_Crouch_Walk_Back",
	&"crouch_walk_left": &"SS_Crouch_Walk_Left", &"crouch_walk_right": &"SS_Crouch_Walk_Right",
	&"roll": &"Roll_Quick_To_Run", &"down": &"SS_Falling_Back_Death",
	&"hit": &"SS_Head_Impact", &"hit_blocked": &"SS_Blocked_Impact",
	&"mantle": &"SS_Mantle", &"plunge": &"SS_Jump_Attack",
	&"overhead": &"SS_Downward_Slash",
	# Keyed in Blender off the guard: the shield swept out across the blow and
	# the body opened behind it, the sword drawn back for the answer.
	&"parry": &"SS_Parry",
	# The same guard behind the tower shield: lower, knees bent, leaning in.
	&"tower_block": &"SS_Tower_Block",
}
## Ground speed each in-place cycle was authored at, measured in Blender off the
## planted foot (m/s). The play rate is the body's speed over this, so the feet
## keep up with the ground instead of skating.
var ground_speed := {
	&"SS_Walk": 1.42, &"SS_Run": 3.2,
	&"SS_Backward_Walk": 1.12, &"SS_Backward_Run": 3.22,
	&"SS_Left_Strafe_Walk": 1.08, &"SS_Right_Strafe_Walk": 1.21,
	&"SS_Left_Run_Strafe": 2.56, &"SS_Right_Run_Strafe": 2.45,
	&"SS_Block_Walk": 1.42, &"SS_Block_Walk_Back": 1.12,
	&"SS_Block_Walk_Left": 1.08, &"SS_Block_Walk_Right": 1.21,
	&"SS_Crouch_Walk": 1.5, &"SS_Crouch_Walk_Back": 1.14,
	&"SS_Crouch_Walk_Left": 1.3, &"SS_Crouch_Walk_Right": 1.32,
}
var looping: Array[StringName] = [
	&"SS_Idle", &"SS_Walk", &"SS_Run", &"SS_Backward_Walk", &"SS_Backward_Run",
	&"SS_Left_Strafe_Walk", &"SS_Right_Strafe_Walk", &"SS_Left_Run_Strafe",
	&"SS_Right_Run_Strafe", &"SS_Block_Idle", &"SS_Crouch_Block_Idle",
	&"SS_Left_Crouch_Idle_Loop", &"SS_Sword_Play_Idle", &"SS_Look_Around_Idle",
	&"SS_Block_Walk", &"SS_Block_Walk_Back", &"SS_Block_Walk_Left", &"SS_Block_Walk_Right",
	&"SS_Crouch_Walk", &"SS_Crouch_Walk_Back", &"SS_Crouch_Walk_Left", &"SS_Crouch_Walk_Right",
	&"SS_Tower_Block",
]
## The cuts a flurry cycles through, in order.
var flurry: Array[StringName] = [&"SS_High_Attack", &"SS_Cross_Slash", &"SS_Downward_Slash"]
## Where each swing's blade is actually travelling, as a fraction of the clip —
## measured in Blender as the span the tip moves faster than 55% of its peak.
var cut_window := {
	&"SS_High_Attack": Vector2(0.41, 0.487), &"SS_Cross_Slash": Vector2(0.44, 0.52),
	&"SS_Downward_Slash": Vector2(0.378, 0.467), &"SS_Low_Attack": Vector2(0.404, 0.462),
	&"SS_Power_Slash": Vector2(0.548, 0.575), &"SS_Jump_Attack": Vector2(0.471, 0.543),
	&"SS_Crouch_Slash": Vector2(0.366, 0.488),
}
## How far into the roll clip the body is back on its feet (pelvis lowest at 0.64).
var roll_share := 0.8
## The jump attack, re-baked in Blender with the clip's own jump taken out (the
## controller does the jumping): the sword goes up from 0.40, the chop reaches
## the ground at 0.56, the blade stays in it to 0.77 and he stands after that.
## Thrown in the air it plays `air_cut_from`..`plunge_from` and holds the chop
## until the feet land; the landing (`plunge()`) carries on from there, so the
## two are one movement rather than a cut into another clip.
var air_cut_from := 0.40
var plunge_from := 0.56

## Blade, measured from the fist along the blade (m).
const BLADE_BASE := 0.18
const BLADE_TIP := 1.03
## The same, per character (a dagger is a third of a sword), and which way the
## blade points in the socket at rest, in the skeleton's frame: the knight's
## sword lies forward in the T, the rogue's daggers stand up.
var blade_base := BLADE_BASE
var blade_tip := BLADE_TIP
var blade_rest_dir := Vector3(0, 0, 1)
## A blade in the other hand too, which cuts the air as the right one does.
var off_hand_blade := false
## What a swing sounds like: one of these, at random, at `swing_pitch`. The
## knight's sword; the rogue sets his own knife's (`SkinnedRogueRig`).
var swing_sounds: Array[String] = [
	"res://unverified/sounds/tariel/slash_1.wav", "res://unverified/sounds/tariel/slash_2.wav",
	"res://unverified/sounds/tariel/slash_3.wav", "res://unverified/sounds/tariel/slash_4.wav",
]
## The older, lighter whooshes: the staff and the hunter's knife keep these.
const LIGHT_SWINGS: Array[String] = [
	"res://unverified/sounds/tariel/swing_1.wav", "res://unverified/sounds/tariel/swing_2.wav",
	"res://unverified/sounds/tariel/swing_3.wav", "res://unverified/sounds/tariel/swing_4.wav",
	"res://unverified/sounds/tariel/swing_5.wav", "res://unverified/sounds/tariel/swing_6.wav",
	"res://unverified/sounds/tariel/swing_7.wav",
]
## How loud the swing plays, dB. (The user's slashes are ~8 dB hotter than
## the old air cuts; the rigs that keep those set their own.)
var swing_volume := -18.0
## The blade going into a creature: one of these at random.
var hit_sounds: Array[String] = ["res://unverified/sounds/tariel/hit_1.wav"]
var hit_volume := -19.0
## Being hurt.
var hurt_sounds: Array[String] = ["res://unverified/sounds/all/hurt_1.wav"]
var hurt_volume := -19.0
var swing_pitch := 1.0

@export_group("Skinned")
## Under this speed the body stands; over `run_threshold` it runs.
@export var idle_threshold: float = 0.25
@export var run_threshold: float = 3.2
## Clamp on how far a cycle is sped up or slowed down to match the ground. Past
## the top of it the feet slide a little rather than blur.
@export var min_play_rate: float = 0.6
@export var max_play_rate: float = 2.1
## Seconds without a click after which the flurry starts again from its first
## swing; 0 keeps it going round wherever it was.
@export var flurry_reset_after: float = 0.0
var _last_attack_at: float = -100.0
@export var loco_blend: float = 0.2
@export var action_blend: float = 0.1
## Widens the measured cutting window a little each side, as a fraction of the clip.
@export var cut_margin: float = 0.03
## Swings play at this rate. Mixamo's are unhurried; the game is not.
@export var swing_rate: float = 1.6
## A swing thrown on the move keeps running legs under it (see
## [StrideModifier]) instead of skating on the clip's planted feet.
@export var swing_strides: bool = true
## How quickly the legs go over to the stride and back, in seconds.
@export var stride_blend: float = 0.12

@export_group("Cloth")
## The cape and the ponytail hang off spring bones: they lag behind the body and
## swing back, and the cape is kept off the legs by capsules on them.
@export var cloth_enabled: bool = true
## Pull back towards the way the cloth hangs at rest. Lower is floppier.
@export var cape_stiffness: float = 1.3
@export var cape_drag: float = 0.55
@export var cape_gravity: float = 2.2
## How thick the cape is treated as being when it meets the legs.
@export var cape_radius: float = 0.04
@export var hair_stiffness: float = 0.8
@export var hair_drag: float = 0.4
@export var hair_gravity: float = 0.4
## Capes of cloth ([ClothCape]), one spec each, set by `_configure()`. When
## there are any the cape's spring bones are left alone: the cloth is the cape.
var capes: Array[Dictionary] = []
## The capes hung, for the tests.
var cloth_capes: Array[ClothCape] = []

enum Role { NONE, SWING, ROLL, HIT, DOWN, GET_UP, PLUNGE, CLIMB, FREE }

var _anim: AnimationPlayer
var _skel: Skeleton3D
var _body: Node3D
var _sword_mesh: MeshInstance3D
var _role: Role = Role.NONE
var _act_clip: StringName = &""
var _action_left: float = 0.0
var _action_len: float = 0.0
var _action_rate: float = 1.0
var _base_clip: StringName = &""
var _flurry_slot: int = -1
var _airborne_now: bool = false
var _blocking_now: bool = false
var _plunge_left: float = 0.0
var _swing_commit: float = 0.0
var _air_cut: bool = false
var _sliding: bool = false
var _stride: StrideModifier
var _stride_clip: StringName = &""
var _stride_time: float = 0.0
## The cut the blade leaves in the air ([BladeArc]); it stands in for the
## ribbon [CharacterRig] hangs off the procedural rig.
var _arc: BladeArc
var _arc_l: BladeArc
## Which shield is on the arm (see [enum Shields] in `inventory.gd`): 0 the
## round one, 1 the tower shield. The model carries both; one is shown.
var shield_kind: int = 0
var _shield_meshes: Array[MeshInstance3D] = []
## Outfits the model carries, each its own mesh on the one skeleton (their
## names in the model); one is shown. Empty for a hero with only the one
## (set by `_configure()`).
var garbs: Array[StringName] = []
## Which of `garbs` is on.
var garb: int = 0


func _ready() -> void:
	_attack_rng.randomize()
	_anim = find_children("*", "AnimationPlayer", true, false).front() as AnimationPlayer
	_skel = find_children("*", "Skeleton3D", true, false).front() as Skeleton3D
	if _anim == null or _skel == null:
		push_error("SkinnedRig: the model has no AnimationPlayer or Skeleton3D.")
		return
	_body = get_parent() as Node3D
	_configure()
	for n in looping:
		if _anim.has_animation(n):
			_anim.get_animation(n).loop_mode = Animation.LOOP_LINEAR
	# The clips carry their travel on the `root` bone. The controller moves the
	# body itself, so that travel is taken out of the pose rather than played.
	var holder := _anim.get_node(_anim.root_node)
	_anim.root_motion_track = NodePath(String(holder.get_path_to(_skel)) + ":root")
	_setup_blade()
	# Before the cloth, so the cape's spring bones hang over the legs as they
	# end up, stride and all.
	_stride = StrideModifier.new()
	_stride.name = "Stride"
	_skel.add_child(_stride)
	if cloth_enabled:
		_setup_cloth()
	# The capes are the rig's own cloth, not spring bones: hung on every rig.
	_setup_capes()
	_put_on_dress()
	_sword_mesh = find_child("tariel_sword", true, false) as MeshInstance3D
	for mesh_name in ["tariel_shield", "tariel_tower_shield"]:
		_shield_meshes.append(find_child(mesh_name, true, false) as MeshInstance3D)
	set_shield(shield_kind)
	set_garb(garb)
	_set_base(clips[&"idle"], 0.0, 1.0)
	# Read off the disk now, not on the first swing.
	Sfx.warm(swing_sounds + hit_sounds + hurt_sounds)


## Override to swap in another character's clip table (see `clips`). The
## knight's own: his tiger's skin, hung from the fur across his shoulders.
func _configure() -> void:
	wardrobe = TARIEL_WARDROBE
	capes = [{
		"bone": "spine_02", "left": [0.21, 0.15, 1.6], "right": [-0.21, 0.15, 1.6],
		"length": 1.15, "spread": 1.35, "flare": 0.12, "wrap": 0.13, "cols": 7, "rows": 11,
		"base": Color.html("d98a2b"), "hem": Color.html("f2c27a"), "trim": Color.html("1b1310"),
		"pattern": "tiger", "hold": 0.5, "wind": 1.0, "drag": 0.6,
		"colliders": [["pelvis", "neck_01", 0.17], ["thigh_l", "calf_l", 0.11], ["thigh_r", "calf_r", 0.11],
				["calf_l", "foot_l", 0.09], ["calf_r", "foot_r", 0.09]],
	}]


#region Tariel's colours
## What Tariel can wear: each a set of colours for the model's materials (by
## their names in the model, in Blender's linear values) and for his cape (as
## seen). Kept here rather than baked into the model so they can be tried in
## the game — F9 steps through them — and cost nothing: the same meshes, the
## same number of materials. The first is the model as it was made.
const TARIEL_WARDROBE := {
	&"crimson": {"name": "crimson and gold (as made)", "mats": {},
		"cape": {"base": Color("d98a2b"), "hem": Color("f2c27a"), "trim": Color("1b1310")}},
	&"panther": {"name": "panther: oxblood, tawny skin, old bronze",
		"mats": {"t6_crimson": Color(0.2, 0.035, 0.03), "t6_tiger": Color(0.30, 0.18, 0.07),
			"t6_tiger2": Color(0.38, 0.26, 0.12), "t6_stripe": Color(0.05, 0.035, 0.025),
			"t6_gold": Color(0.34, 0.22, 0.09), "brass_gold": Color(0.34, 0.22, 0.09),
			"t6_steel": Color(0.36, 0.37, 0.38), "t6_steel2": Color(0.18, 0.19, 0.2),
			"steel": Color(0.33, 0.34, 0.35), "t6_ruby": Color(0.25, 0.03, 0.03),
			"t6_tigereye": Color(0.45, 0.32, 0.05), "tower_crimson": Color(0.2, 0.035, 0.03)},
		"cape": {"base": Color("a8793f"), "hem": Color("d2b37c"), "trim": Color("2a1d14")}},
	&"black": {"name": "black and steel, dark amber skin",
		"mats": {"t6_crimson": Color(0.045, 0.045, 0.05), "t6_tiger": Color(0.24, 0.14, 0.05),
			"t6_tiger2": Color(0.3, 0.21, 0.1), "t6_stripe": Color(0.02, 0.015, 0.01),
			"t6_gold": Color(0.3, 0.25, 0.15), "brass_gold": Color(0.3, 0.25, 0.15),
			"t6_steel": Color(0.5, 0.52, 0.55), "t6_steel2": Color(0.22, 0.23, 0.25),
			"t6_ruby": Color(0.3, 0.02, 0.02), "t6_leather": Color(0.07, 0.035, 0.02),
			"tower_crimson": Color(0.05, 0.05, 0.055)},
		"cape": {"base": Color("7d5a2e"), "hem": Color("a88c5c"), "trim": Color("141110")}},
	&"indigo": {"name": "indigo, tawny skin, muted gold",
		"mats": {"t6_crimson": Color(0.04, 0.06, 0.14), "t6_tiger": Color(0.30, 0.18, 0.07),
			"t6_tiger2": Color(0.38, 0.26, 0.12), "t6_stripe": Color(0.05, 0.035, 0.025),
			"t6_gold": Color(0.4, 0.3, 0.12), "brass_gold": Color(0.4, 0.3, 0.12),
			"t6_steel": Color(0.42, 0.44, 0.47), "t6_steel2": Color(0.2, 0.21, 0.24),
			"t6_ruby": Color(0.1, 0.15, 0.35), "tower_crimson": Color(0.05, 0.07, 0.15)},
		"cape": {"base": Color("ad8246"), "hem": Color("d8bd86"), "trim": Color("22170f")}},
	&"hunter": {"name": "hunter: olive and leather, like Avtandil",
		"mats": {"t6_crimson": Color(0.09, 0.12, 0.05), "t6_tiger": Color(0.30, 0.18, 0.07),
			"t6_tiger2": Color(0.38, 0.26, 0.12), "t6_stripe": Color(0.05, 0.035, 0.025),
			"t6_gold": Color(0.33, 0.22, 0.1), "brass_gold": Color(0.33, 0.22, 0.1),
			"t6_steel": Color(0.34, 0.35, 0.35), "t6_steel2": Color(0.16, 0.17, 0.17),
			"steel": Color(0.33, 0.34, 0.35), "t6_ruby": Color(0.2, 0.3, 0.1),
			"t6_leather": Color(0.12, 0.055, 0.022), "tower_crimson": Color(0.12, 0.08, 0.04)},
		"cape": {"base": Color("a67a44"), "hem": Color("cfb07a"), "trim": Color("241a12")}},
}
## Which of the wardrobe Tariel wears, for every Tariel in this game.
static var dress: StringName = &"black"
## This rig's wardrobe; empty for a hero that has none (set by `_configure()`).
var wardrobe: Dictionary = {}
var _dress_on: StringName = &""
var _dress_label: Label


## Puts on `dress` (if this rig has a wardrobe and it is not already on): each
## surface whose material is named in it gets a copy in the new colour; the
## rest, and anything the last dress changed that this one does not, go back
## to the model's own.
func _put_on_dress() -> void:
	if wardrobe.is_empty() or not wardrobe.has(dress) or _dress_on == dress:
		return
	_dress_on = dress
	var outfit: Dictionary = wardrobe[dress]
	var mats: Dictionary = outfit.get("mats", {})
	for node in find_children("*", "MeshInstance3D", true, false):
		var mesh_node := node as MeshInstance3D
		if mesh_node.mesh == null:
			continue
		for i in mesh_node.mesh.get_surface_count():
			var own := mesh_node.mesh.surface_get_material(i)
			if own == null:
				continue
			if not mats.has(own.resource_name):
				mesh_node.set_surface_override_material(i, null)
				continue
			var copy := own.duplicate() as BaseMaterial3D
			if copy == null:
				continue
			# The model's colours are Blender's, linear; the material's are as seen.
			copy.albedo_color = (mats[own.resource_name] as Color).linear_to_srgb()
			mesh_node.set_surface_override_material(i, copy)
	for cape in cloth_capes:
		cape.recolour(outfit.get("cape", {}))


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or key.keycode != KEY_F9 or wardrobe.is_empty():
		return
	if _body != null and not _body.is_multiplayer_authority():
		return
	var names := wardrobe.keys()
	dress = names[(names.find(dress) + 1) % names.size()]
	_put_on_dress()
	_say_dress()


## Says which dress is on, for a moment, at the top of the screen.
func _say_dress() -> void:
	if _dress_label == null:
		var layer := CanvasLayer.new()
		layer.layer = 50
		add_child(layer)
		_dress_label = Label.new()
		_dress_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
		_dress_label.position.y = 92.0
		_dress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_dress_label.add_theme_font_size_override("font_size", 22)
		_dress_label.add_theme_color_override("font_outline_color", Color.BLACK)
		_dress_label.add_theme_constant_override("outline_size", 6)
		layer.add_child(_dress_label)
	var names := wardrobe.keys()
	_dress_label.text = "Tariel %d/%d: %s" % [names.find(dress) + 1, names.size(), wardrobe[dress]["name"]]
	_dress_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_dress_label.visible = true
	var shown := _dress_label.text
	get_tree().create_timer(2.5).timeout.connect(func() -> void:
		if is_instance_valid(_dress_label) and _dress_label.text == shown:
			_dress_label.visible = false)
#endregion


## The cloth capes, each on its own node that draws itself in world space.
func _setup_capes() -> void:
	for spec in capes:
		var cape := ClothCape.new()
		cape.name = "Cape%d" % cloth_capes.size()
		add_child(cape)
		if cape.setup(_skel, spec):
			cloth_capes.append(cape)
		else:
			cape.queue_free()


## Markers for the blade's base and tip on the weapon socket, so the swing trail
## and `get_cutting_edge()` have a segment to read. The blade's direction in the
## socket is read off the rest pose (it points forward, +Z, in the T-pose) rather
## than assumed, so it does not matter which axis the exporter left the bone on.
func _setup_blade() -> void:
	var bone := _skel.find_bone("weapon_r")
	if bone < 0:
		return
	var mount := BoneAttachment3D.new()
	mount.name = "WeaponMount"
	_skel.add_child(mount)
	mount.bone_name = "weapon_r"
	var along := (_skel.get_bone_global_rest(bone).basis.inverse() * blade_rest_dir).normalized()
	_blade_base = Marker3D.new()
	_blade_base.name = "blade_base"
	_blade_base.position = along * blade_base
	mount.add_child(_blade_base)
	_blade_tip = Marker3D.new()
	_blade_tip.name = "blade_tip"
	_blade_tip.position = along * blade_tip
	mount.add_child(_blade_tip)
	_sword_mount = mount
	_arc = BladeArc.new()
	_arc.name = "BladeArc"
	add_child(_arc)
	_arc.setup(_blade_base, _blade_tip)
	var left := _skel.find_bone("weapon_l")
	if off_hand_blade and left >= 0:
		var mount_l := BoneAttachment3D.new()
		mount_l.name = "WeaponMountL"
		_skel.add_child(mount_l)
		mount_l.bone_name = "weapon_l"
		var along_l := (_skel.get_bone_global_rest(left).basis.inverse() * blade_rest_dir).normalized()
		var base_l := Marker3D.new()
		base_l.position = along_l * blade_base
		mount_l.add_child(base_l)
		var tip_l := Marker3D.new()
		tip_l.position = along_l * blade_tip
		mount_l.add_child(tip_l)
		_arc_l = BladeArc.new()
		_arc_l.name = "BladeArcL"
		add_child(_arc_l)
		_arc_l.setup(base_l, tip_l)


## Spring bones for the cape (`cape_00`..`cape_06`) and the ponytail
## (`hair_00`..`hair_04`), and the capsules that keep the cape out of the legs
## and the body. The clips leave both chains at rest; this runs after them.
func _setup_cloth() -> void:
	var sim := SpringBoneSimulator3D.new()
	sim.name = "Cloth"
	var chains := [
		[&"cape_00", &"cape_06", cape_stiffness, cape_drag, cape_gravity, cape_radius],
		[&"hair_00", &"hair_04", hair_stiffness, hair_drag, hair_gravity, 0.03],
	]
	var usable: Array = []
	for c in chains:
		if c[0] == &"cape_00" and not capes.is_empty():
			continue
		if _skel.find_bone(c[0]) >= 0 and _skel.find_bone(c[1]) >= 0:
			usable.append(c)
	if usable.is_empty():
		return
	_skel.add_child(sim)
	sim.set_setting_count(usable.size())
	for i in usable.size():
		var c: Array = usable[i]
		sim.set_root_bone_name(i, c[0])
		sim.set_end_bone_name(i, c[1])
		sim.set_extend_end_bone(i, true)
		sim.set_end_bone_length(i, 0.12)
		sim.set_stiffness(i, c[2])
		sim.set_drag(i, c[3])
		sim.set_gravity(i, c[4])
		sim.set_radius(i, c[5])
	# Capsules along the legs, the hips and the back: bone, radius, length.
	for spec in [[&"thigh_l", 0.1, 0.44], [&"thigh_r", 0.1, 0.44], [&"calf_l", 0.08, 0.42],
			[&"calf_r", 0.08, 0.42], [&"pelvis", 0.17, 0.3], [&"spine_01", 0.17, 0.25],
			[&"spine_02", 0.17, 0.28], [&"head", 0.13, 0.22]]:
		if _skel.find_bone(spec[0]) < 0:
			continue
		var cap := SpringBoneCollisionCapsule3D.new()
		cap.name = "Col_%s" % spec[0]
		sim.add_child(cap)
		cap.set_bone_name(spec[0])
		cap.set_radius(spec[1])
		cap.set_height(spec[2] + spec[1] * 2.0)
		# Capsules run along their own Y, as bones do; centred halfway down it.
		cap.set_position_offset(Vector3(0.0, spec[2] * 0.5, 0.0))
	sim.set_enable_all_child_collisions(0, true)
	if usable.size() > 1:
		sim.set_enable_all_child_collisions(1, true)


func animate(delta: float, planar_speed: float, _speed_ratio: float, airborne: bool,
		dashing: bool, vertical_speed: float, blocking: bool = false) -> void:
	if _anim == null:
		return
	_airborne_now = airborne
	_blocking_now = blocking
	_hold_stop(delta)
	_plunge_left = maxf(_plunge_left - delta, 0.0)
	_swing_commit = maxf(_swing_commit - delta, 0.0)

	if _role != Role.NONE:
		_action_left -= delta
		var through := _progress()
		_attack_cutting = _role == Role.SWING and _in_window(through)
		# A swing that has done its work gives the body back as soon as the
		# player moves off; standing still, it plays out its follow-through.
		var released := _role == Role.SWING and not _air_cut and _swing_commit <= 0.0 and planar_speed > idle_threshold
		if _role == Role.DOWN:
			pass  # held until get_up() or leave_ground()
		elif _air_cut and _action_left <= 0.0 and airborne:
			_anim.speed_scale = 0.0  # the chop, held until the ground arrives
		elif _action_left <= 0.0 or released:
			_end_action()
	else:
		_attack_cutting = false
	if _arc != null:
		_arc.emitting = _attack_cutting
	if _arc_l != null:
		_arc_l.emitting = _attack_cutting

	if _role == Role.NONE:
		_pick_base(planar_speed, airborne, dashing, vertical_speed, blocking)
	_update_stride(delta, planar_speed, airborne)


## Running legs under a swing thrown on the move: the cycle that fits the way
## the body is going, carried on from the phase the run was at, faded in over
## `stride_blend` and back out when the swing ends or the body stops.
func _update_stride(delta: float, planar: float, airborne: bool) -> void:
	if _stride == null:
		return
	var want := swing_strides and _role == Role.SWING and not _air_cut and not airborne \
			and planar > idle_threshold
	if want:
		var clip := _direction_clip(planar)
		if _anim.has_animation(clip):
			if clip != _stride_clip:
				# Same foot forward in the new cycle: keep the phase as a share.
				var from_len := _stride.cycle.length if _stride.cycle != null else 1.0
				var share := fposmod(_stride_time, maxf(from_len, 0.01)) / maxf(from_len, 0.01)
				_stride_clip = clip
				_stride.cycle = _anim.get_animation(clip)
				_stride_time = share * _stride.cycle.length
			_stride_time += delta * _rate(clip, planar)
			_stride.time = _stride_time
		else:
			want = false
	_stride.weight = move_toward(_stride.weight, 1.0 if want else 0.0,
			delta / maxf(stride_blend, 0.01))


func _pick_base(planar: float, airborne: bool, _dashing: bool, _vy: float, blocking: bool) -> void:
	if airborne:
		_set_base(clips[&"air"], loco_blend, 0.8)
		return
	if blocking:
		if planar < idle_threshold:
			var guard: StringName = clips[&"block_idle"]
			if shield_kind == 1 and clips.has(&"tower_block") and _anim.has_animation(clips[&"tower_block"]):
				guard = clips[&"tower_block"]
			_set_base(guard, 0.12, 1.0)
		else:
			# Legs from the walk, the guard held up over them (baked in Blender).
			var bclip := _block_walk_clip()
			var brate := clampf(planar / float(ground_speed.get(bclip, 1.4)), min_play_rate, max_play_rate)
			_set_base(bclip, 0.15, brate)
		return
	if _crouching or _wall_climbing:
		if _sliding or _wall_climbing or planar < idle_threshold or not clips.has(&"crouch_walk"):
			# A slide is carried, not walked: the crouched pose held while the
			# body goes along the ground.
			_set_base(clips[&"crouch"], loco_blend, 1.0)
		else:
			var cclip := _dir4(&"crouch_walk", &"crouch_walk_back", &"crouch_walk_left", &"crouch_walk_right")
			_set_base(cclip, loco_blend, _rate(cclip, planar))
		return
	if planar < idle_threshold:
		_set_base(clips[&"idle"], loco_blend, 1.0)
		return
	var clip := _direction_clip(planar)
	var rate := clampf(planar / float(ground_speed.get(clip, 1.4)), min_play_rate, max_play_rate)
	_set_base(clip, loco_blend, rate)


## Which cycle fits the way the body is actually travelling relative to where it
## faces — forwards, backwards, or sideways while locked on to something.
func _direction_clip(planar: float) -> StringName:
	var run := planar > run_threshold
	var body := _body as CharacterBody3D
	if body == null:
		return clips[&"run"] if run else clips[&"walk"]
	var local := body.global_transform.basis.inverse() * body.velocity
	var fwd := -local.z
	var side := local.x
	if absf(side) > absf(fwd) * 1.2:
		if side > 0.0:
			return clips[&"run_right"] if run else clips[&"walk_right"]
		return clips[&"run_left"] if run else clips[&"walk_left"]
	if fwd < 0.0:
		return clips[&"run_back"] if run else clips[&"walk_back"]
	return clips[&"run"] if run else clips[&"walk"]


func _block_walk_clip() -> StringName:
	var body := _body as CharacterBody3D
	if body == null:
		return clips[&"block_walk"]
	var local := body.global_transform.basis.inverse() * body.velocity
	if absf(local.x) > absf(local.z) * 1.2:
		return clips[&"block_walk_right"] if local.x > 0.0 else clips[&"block_walk_left"]
	return clips[&"block_walk_back"] if local.z > 0.0 else clips[&"block_walk"]


func _dir4(fwd: StringName, back: StringName, left: StringName, right: StringName) -> StringName:
	var body := _body as CharacterBody3D
	if body == null:
		return clips[fwd]
	var local := body.global_transform.basis.inverse() * body.velocity
	if absf(local.x) > absf(local.z) * 1.2:
		return clips[right] if local.x > 0.0 else clips[left]
	return clips[back] if local.z > 0.0 else clips[fwd]


func _rate(clip: StringName, planar: float) -> float:
	return clampf(planar / float(ground_speed.get(clip, 1.4)), min_play_rate, max_play_rate)


func _set_base(clip: StringName, blend: float, rate: float) -> void:
	if not _anim.has_animation(clip):
		return
	if clip != _base_clip or _anim.current_animation != clip:
		_base_clip = clip
		_anim.play(clip, blend)
	_anim.speed_scale = rate


func _play_action(clip: StringName, role: Role, rate: float = 1.0, blend: float = -1.0,
		from: float = 0.0, until: float = 1.0) -> bool:
	if not _anim.has_animation(clip):
		return false
	var length := _anim.get_animation(clip).length
	_role = role
	_act_clip = clip
	_action_len = length
	_action_rate = maxf(rate, 0.01)
	_action_left = length * (until - from) / _action_rate
	_base_clip = &""
	# Where the legs were in their cycle, for a stride carried on under the swing.
	var was := StringName(_anim.current_animation)
	if ground_speed.has(was) and _anim.has_animation(was):
		_stride_clip = was
		_stride_time = _anim.current_animation_position
		if _stride != null:
			_stride.cycle = _anim.get_animation(was)
	_anim.play(clip, action_blend if blend < 0.0 else blend)
	_anim.speed_scale = _action_rate
	if from > 0.0:
		_anim.seek(length * from, true)
	elif was == clip:
		# The same clip again — a roll straight after a roll: play() would carry
		# on from where it is, so start it over.
		_anim.seek(0.0, true)
	return true


func _end_action() -> void:
	_air_cut = false
	_role = Role.NONE
	_act_clip = &""
	_attack_cutting = false
	_base_clip = &""  # forces the next base pick to crossfade in


func _progress() -> float:
	if _action_len <= 0.0:
		return 1.0
	return clampf(_anim.current_animation_position / _action_len, 0.0, 1.0)


func _in_window(through: float) -> bool:
	var w: Vector2 = cut_window.get(_act_clip, Vector2.ZERO)
	return w != Vector2.ZERO and through >= w.x - cut_margin and through <= w.y + cut_margin


#region The rig's interface, as the controller calls it
func attack(style: int = -1) -> void:
	attack_serial += 1
	var clip: StringName
	if _airborne_now and _anim.has_animation(clips[&"plunge"]):
		# Off a jump: the jump attack's own raise and chop, held at the bottom
		# until the landing takes it on (see `plunge()`).
		_attack_style = AttackStyle.OVERHEAD
		if _play_action(clips[&"plunge"], Role.SWING, swing_rate, 0.08, air_cut_from, plunge_from):
			_air_cut = true
			_swing_commit = swing_time()
			_whoosh()
		return
	if style == AttackStyle.OVERHEAD:
		clip = clips[&"overhead"]
		_attack_style = AttackStyle.OVERHEAD
	else:
		_attack_style = AttackStyle.SIDE
		# A combo left alone for a while starts again from its first cut.
		var now := Time.get_ticks_msec() / 1000.0
		if flurry_reset_after > 0.0 and now - _last_attack_at > flurry_reset_after:
			_flurry_slot = -1
		_last_attack_at = now
		_flurry_slot = (_flurry_slot + 1) % flurry.size()
		clip = flurry[_flurry_slot]
	if _play_action(clip, Role.SWING, swing_rate):
		_swing_commit = swing_time()
		_whoosh()


## The sword going through the air — every peer plays the swing, so every peer
## hears it.
##
## The sounds are short slashes now, so they are timed to the cut itself —
## where the clip's cut window opens — not to the start of the wind-up, where
## a short one was over before the blade moved and seemed not to play.
func _whoosh() -> void:
	var serial := attack_serial
	var clip := _act_clip
	var w: Vector2 = cut_window.get(_act_clip, Vector2.ZERO)
	var lead := 0.0
	if w != Vector2.ZERO and _action_len > 0.0 and _action_rate > 0.0:
		# A touch before the window opens: a slash is heard as the blade comes.
		lead = maxf(_action_len * w.x / _action_rate - 0.06, 0.0)
	if lead <= 0.01:
		_whoosh_now()
		return
	get_tree().create_timer(lead, false).timeout.connect(func() -> void:
		# Only if it is still that swing (not cut short by a hit or a roll).
		if is_inside_tree() and attack_serial == serial and _act_clip == clip:
			_whoosh_now())


func _whoosh_now() -> void:
	var at: Node3D = self
	if _sword_mount != null:
		at = _sword_mount
	Sfx.play_any(self, swing_sounds, at, swing_pitch, swing_volume)


func swing_time() -> float:
	if _role != Role.SWING or _action_len <= 0.0:
		return attack_duration
	var w: Vector2 = cut_window.get(_act_clip, Vector2(0.5, 0.5))
	return minf(_action_len * w.y / _action_rate + swing_recovery, _action_len / _action_rate)


func current_swing() -> StringName:
	return _act_clip if _role == Role.SWING else &""


func plunge(seconds: float) -> void:
	_plunge_left = maxf(seconds, 0.1)
	var length := _anim.get_animation(clips[&"plunge"]).length if _anim.has_animation(clips[&"plunge"]) else 1.0
	if _anim.current_animation == clips[&"plunge"]:
		# Already the jump attack, from the air: carry on from wherever the chop
		# has got to — no new clip, no blend, no jump in the pose.
		var at := clampf(_anim.current_animation_position / length, 0.0, 1.0)
		_air_cut = false
		_role = Role.PLUNGE
		_act_clip = clips[&"plunge"]
		_action_len = length
		_action_rate = maxf(length * (1.0 - at) / _plunge_left, 0.05)
		_action_left = _plunge_left
		_anim.speed_scale = _action_rate
		return
	# The landing of the jump attack — the blade going in and the body coming
	# back up over it — stretched over however long the recovery is.
	_play_action(clips[&"plunge"], Role.PLUNGE, length * (1.0 - plunge_from) / _plunge_left, 0.06, plunge_from, 1.0)


func is_planted() -> bool:
	return _plunge_left > 0.0


## The blade has gone into something: its sound, at the point it went in, the
## wet thump of it under the steel, and the swing caught a moment in the body.
func blade_landed() -> void:
	var at: Node3D = self
	if _sword_mount != null:
		at = _sword_mount
	Sfx.play_any(self, hit_sounds, at, randf_range(0.94, 1.06), hit_volume)
	ImpactFx.thud(self, at.global_position)
	hitstop(bite_stop)


## How long the swing is held as it bites (seconds): the blade felt going in.
var bite_stop: float = 0.075
var _stop_left: float = 0.0
var _stop_rate: float = 1.0
## The rate the clip is held at while stopped: all but still.
const STOP_RATE := 0.04


func hitstop(seconds: float) -> void:
	if _anim == null or seconds <= 0.0:
		return
	if _stop_left <= 0.0:
		_stop_rate = _anim.speed_scale
		_anim.speed_scale = _stop_rate * STOP_RATE
	_stop_left = maxf(_stop_left, seconds)
	# The swing's clock is held too, or it would end short of its clip.
	if _role != Role.NONE:
		_action_left += seconds


## The hold over: the clip goes on at the rate it had — unless something else
## has set a rate of its own in the meantime, which is left alone.
func _hold_stop(delta: float) -> void:
	if _stop_left <= 0.0:
		return
	_stop_left -= delta
	if _stop_left <= 0.0 and absf(_anim.speed_scale - _stop_rate * STOP_RATE) < 0.0001:
		_anim.speed_scale = _stop_rate


## Hurt: a grunt.
func hurt() -> void:
	Sfx.play_any(self, hurt_sounds, self, randf_range(0.95, 1.05), hurt_volume)


func bloody() -> void:
	blade_blood = minf(blade_blood + 0.34, 1.0)
	if _sword_mesh == null:
		return
	var overlay := StandardMaterial3D.new()
	overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	overlay.albedo_color = Color(0.35, 0.02, 0.02, blade_blood * 0.7)
	overlay.roughness = 0.35
	_sword_mesh.material_overlay = overlay


func dodge(duration: float) -> void:
	# The roll part of the clip, fitted to the dash so the tumble and the
	# movement finish together; what is left of the clip is the run-out, which
	# the locomotion picks up instead.
	var length := _anim.get_animation(clips[&"roll"]).length if _anim.has_animation(clips[&"roll"]) else 1.0
	_play_action(clips[&"roll"], Role.ROLL, length * roll_share / maxf(duration, 0.05), 0.05, 0.0, roll_share)


func dodge_clip(duration: float) -> bool:
	var length := _anim.get_animation(clips[&"roll"]).length if _anim.has_animation(clips[&"roll"]) else 0.0
	if length <= 0.0:
		return false
	return _play_action(clips[&"roll"], Role.ROLL, length / maxf(duration, 0.05), 0.06)


func hit() -> void:
	flinch()


func flinch() -> void:
	if _role == Role.SWING or _role == Role.DOWN:
		return
	_play_action(clips[&"hit_blocked"] if _blocking_now else clips[&"hit"], Role.HIT, 1.3, 0.05)


## A blow thrown back off the shield: the guard's own jolt, played fast — the
## shield punched out into the blow and brought back.
func parry() -> void:
	if _role == Role.DOWN or _role == Role.GET_UP:
		return
	if clips.has(&"parry") and _anim.has_animation(clips[&"parry"]):
		_play_action(clips[&"parry"], Role.HIT, 1.5, 0.03)
	else:
		_play_action(clips[&"hit_blocked"], Role.HIT, 2.0, 0.04)


## Shows the shield that is carried and hides the other.
func set_shield(kind: int) -> void:
	shield_kind = kind
	for i in _shield_meshes.size():
		if _shield_meshes[i] != null:
			_shield_meshes[i].visible = i == kind
	_base_clip = &""


## Shows the outfit `index` of `garbs` and hides the others.
func set_garb(index: int) -> void:
	garb = clampi(index, 0, maxi(garbs.size() - 1, 0))
	for i in garbs.size():
		var mesh := find_child(String(garbs[i]), true, false) as MeshInstance3D
		if mesh != null:
			mesh.visible = i == garb


func knock_down() -> void:
	_play_action(clips[&"down"], Role.DOWN, 1.4, 0.06)


func get_up(duration: float) -> void:
	# No stand-up clip in the pack: the fall, played back to front.
	if not _anim.has_animation(clips[&"down"]):
		_end_action()
		return
	var length := _anim.get_animation(clips[&"down"]).length
	_role = Role.GET_UP
	_act_clip = clips[&"down"]
	_action_len = length
	_action_rate = length / maxf(duration, 0.05)
	_action_left = maxf(duration, 0.05)
	_anim.play_backwards(clips[&"down"], 0.1)
	_anim.speed_scale = _action_rate


func leave_ground() -> void:
	if _role == Role.DOWN or _role == Role.GET_UP:
		_end_action()


func is_down() -> bool:
	return _role == Role.DOWN or _role == Role.GET_UP


func slide(active: bool) -> void:
	# No slide in the library; the crouched guard, held, reads well enough at speed.
	_crouching = active
	_sliding = active


func wall_climb(active: bool) -> void:
	_wall_climbing = active
	if active and _role != Role.NONE:
		_end_action()


func climb(duration: float) -> void:
	_play_action(clips[&"mantle"], Role.CLIMB,
			_anim.get_animation(clips[&"mantle"]).length / maxf(duration, 0.05), 0.06)


func is_crouched() -> bool:
	return _crouching


func is_wall_climbing() -> bool:
	return _wall_climbing


func weapons_slung() -> float:
	return 0.0  # no sheathing yet — the sword stays in hand


## Plays `clip` from `from` to `until` (shares of its length) at `rate`, as a
## free action. Returns how long that takes (0 without the clip).
func play_part(clip: StringName, rate: float, from: float = 0.0, until: float = 1.0,
		blend: float = -1.0) -> float:
	if _anim == null or not _play_action(clip, Role.FREE, rate, blend, from, until):
		return 0.0
	return _anim.get_animation(clip).length * (until - from) / maxf(rate, 0.01)


## Where `bone` is in the world right now.
func bone_position(bone: StringName) -> Vector3:
	if _skel != null:
		var i := _skel.find_bone(bone)
		if i >= 0:
			return _skel.global_transform * _skel.get_bone_global_pose(i).origin
	return global_position + Vector3.UP * 1.2


func play_clip(clip: StringName, fade: float = -1.0, speed: float = 1.0) -> bool:
	return _play_action(clip, Role.FREE, speed, fade)


func hold_clip(clip: StringName, through: float) -> bool:
	if not _play_action(clip, Role.FREE, 1.0, 0.0, through):
		return false
	_anim.speed_scale = 0.0
	_action_left = INF
	return true


func current_clip() -> StringName:
	return _act_clip


func clip_weight() -> float:
	return 1.0 if _role != Role.NONE else 0.0


func clip_names() -> PackedStringArray:
	return _anim.get_animation_list() if _anim != null else PackedStringArray()


func has_clips() -> bool:
	return _anim != null
#endregion
