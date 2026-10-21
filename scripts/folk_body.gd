class_name FolkBody
extends Node3D

## The body of one of the village's people (the user's word, 2026-10-22):
## a figure — the poly heroes' Blink man (the squire, the knight), a
## Polysplit man or woman of the hero select's maker, an elf among them —
## moved by an unseen mannequin that plays everyday clips, not a fighter's:
## standing at ease, arms folded, walking, crouched. Nothing of a hero's rig
## (no blade, no cloth, no stride): one AnimationPlayer and a
## [FigureFollower] per body.
##
## The figure faces +Z here, as [Villager] turns its node.

const MANNEQUIN := "res://assets/anim/lab/ual2_mannequin.glb"
## Where the everyday clips come from (all on the mannequin's skeleton).
const LIBS := ["res://assets/anim/lab/kevin_lib.res", "res://assets/anim/heroes/mage_mannequin.res"]
## What each mood plays: a clip of the mannequin's own (UAL2) or of `LIBS`.
const CLIPS := {
	&"idle": [&"KV_Idle01", &"KV_Idle01", &"Idle_FoldArms"],
	&"walk": &"KV_Walk01_Forward",
	&"crouch": &"MG_Crouch",
	&"fidget": [&"Yes", &"Idle_FoldArms", &"Idle_No"],
}
## The walk covers about this many metres a second at speed 1.
const WALK_SPEED := 1.25

const BLINK := "res://assets/tariel_blink/tariel_blink.glb"
const BLINK_LOOKS := {
	&"squire": {"show": ["body_", "starter_"], "hide": ["body_underwear"]},
	&"knight": {"show": ["body_", "plate_"], "hide": ["body_underwear", "body_hair"]},
}
## Blink's man onto the mannequin (his rest was turned onto Tariel's rig,
## which is the mannequin's but for its spine of two and "head").
const BLINK_MAP := {
	&"Root_M": &"pelvis", &"Spine1_M": &"spine_01", &"Chest_M": &"spine_03",
	&"Neck_M": &"neck_01", &"Head_M": &"Head",
	&"Scapula_R": &"clavicle_r", &"Shoulder_R": &"upperarm_r", &"Elbow_R": &"lowerarm_r", &"Wrist_R": &"hand_r",
	&"Scapula_L": &"clavicle_l", &"Shoulder_L": &"upperarm_l", &"Elbow_L": &"lowerarm_l", &"Wrist_L": &"hand_l",
	&"Hip_R": &"thigh_r", &"Knee_R": &"calf_r", &"Ankle_R": &"foot_r", &"Toes_R": &"ball_r",
	&"Hip_L": &"thigh_l", &"Knee_L": &"calf_l", &"Ankle_L": &"foot_l", &"Toes_L": &"ball_l",
}
const POLYSPLIT := "res://assets/polysplit/mannequin_%s.glb"

## &"squire" / &"knight" (Blink's man), or &"ps" (a Polysplit figure dressed
## by `look`, a [PolysplitLook] look: "g", "race", clothes, colours).
var kind: StringName = &"ps"
var look: Dictionary = {}

var _anim: AnimationPlayer
var _rig: Node3D
var _figure: Node3D
var _mood: StringName = &""
var _rng := RandomNumberGenerator.new()
var _since: float = 0.0
var _fidgeting: bool = false
static var _lib: AnimationLibrary


func _ready() -> void:
	_rng.seed = hash(name) ^ hash(kind)
	_rig = (load(MANNEQUIN) as PackedScene).instantiate() as Node3D
	_rig.name = "Mannequin"
	add_child(_rig)
	for mesh: MeshInstance3D in _rig.find_children("*", "MeshInstance3D", true, false):
		mesh.visible = false
	var skel := _rig.find_children("*", "Skeleton3D", true, false).front() as Skeleton3D
	_anim = _rig.find_children("*", "AnimationPlayer", true, false).front() as AnimationPlayer
	_anim.add_animation_library(&"folk", _library(_anim))
	# the clips carry their travel on the root bone: the villager moves himself
	_anim.root_motion_track = NodePath(String(_anim.get_node(_anim.root_node).get_path_to(skel)) + ":root")
	if kind == &"ps":
		_wear_polysplit(skel)
	else:
		_wear_blink(skel)
	idle()
	_anim.seek(_rng.randf() * 3.0, true)


## The everyday clips, gathered once for every body.
func _library(player: AnimationPlayer) -> AnimationLibrary:
	if _lib != null:
		return _lib
	_lib = AnimationLibrary.new()
	var sources: Array[AnimationLibrary] = [player.get_animation_library(&"")]
	for path: String in LIBS:
		if ResourceLoader.exists(path):
			sources.append(load(path) as AnimationLibrary)
	var wanted := {}
	for v: Variant in CLIPS.values():
		for c: StringName in (v if v is Array else [v]):
			wanted[c] = true
	for src in sources:
		for n: StringName in src.get_animation_list():
			if wanted.has(n) and not _lib.has_animation(n):
				var a := src.get_animation(n).duplicate() as Animation
				a.loop_mode = Animation.LOOP_NONE if n == &"Yes" or n == &"Idle_No" else Animation.LOOP_LINEAR
				_lib.add_animation(n, a)
	return _lib


func _wear_blink(skel: Skeleton3D) -> void:
	_figure = (load(BLINK) as PackedScene).instantiate() as Node3D
	_figure.name = "Figure"
	add_child(_figure)
	var spec: Dictionary = BLINK_LOOKS.get(kind, BLINK_LOOKS[&"squire"])
	for mesh: MeshInstance3D in _figure.find_children("*", "MeshInstance3D", true, false):
		var key := String(mesh.name).trim_prefix("blink_")
		var shown := false
		for pre: String in spec["show"]:
			shown = shown or key.begins_with(pre)
		for pre: String in spec["hide"]:
			shown = shown and not key.begins_with(pre)
		mesh.visible = shown
	_follow(skel, BLINK_MAP, &"Root_M")


func _wear_polysplit(skel: Skeleton3D) -> void:
	var g := String(look.get("g", "m"))
	_figure = (load(POLYSPLIT % g) as PackedScene).instantiate() as Node3D
	_figure.name = "Figure"
	add_child(_figure)
	var map := SkinnedRig.polysplit_map({})
	map[&"chest_joint"] = &"spine_03"
	map[&"head_joint"] = &"Head"
	PolysplitLook.apply(_figure, look)
	# the hero's own shields hang on every figure, for the rig to show
	for key: String in ["ps_shield", "ps_tower_shield"]:
		var shield := _figure.find_child(key, true, false) as MeshInstance3D
		if shield != null:
			shield.visible = false
	_follow(skel, map, &"pelvis_joint")


func _follow(skel: Skeleton3D, map: Dictionary, hips: StringName) -> void:
	var fig_skel := _figure.find_children("*", "Skeleton3D", true, false).front() as Skeleton3D
	var follower := FigureFollower.new()
	follower.name = "Follower"
	add_child(follower)
	if not follower.setup(skel, fig_skel, map, hips):
		push_warning("FolkBody: %s's skeleton does not match its map." % kind)


## Standing about; now and then a fidget of his own.
func idle() -> void:
	_mood_to(&"idle")


func walk(speed: float) -> void:
	_mood_to(&"walk")
	_anim.speed_scale = clampf(speed / WALK_SPEED, 0.6, 1.6)


## Down on his heels (the prisoner in his cage).
func crouch() -> void:
	_mood_to(&"crouch")


func _mood_to(mood: StringName) -> void:
	if mood == _mood:
		return
	_mood = mood
	_anim.speed_scale = 1.0
	_fidgeting = false
	_since = _rng.randf_range(5.0, 14.0)
	_anim.play(_pick(mood), 0.35)


## One of the mood's clips, as the player knows it ("folk/<clip>").
func _pick(mood: StringName) -> StringName:
	var v: Variant = CLIPS[mood]
	var name: StringName = (v as Array)[_rng.randi() % (v as Array).size()] if v is Array else v
	return StringName("folk/" + String(name))


func _process(delta: float) -> void:
	if _anim == null or _mood != &"idle":
		return
	_since -= delta
	if _since > 0.0:
		return
	# a fidget now and then, as long as the clip runs, then back to standing
	if _fidgeting:
		_fidgeting = false
		_anim.play(_pick(&"idle"), 0.5)
		_since = _rng.randf_range(7.0, 14.0)
	else:
		_fidgeting = true
		var clip := _pick(&"fidget")
		_anim.play(clip, 0.4)
		_since = minf(_anim.get_animation(clip).length, 6.0) - 0.3
