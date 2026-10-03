class_name PackCreature
extends Node3D

## One of Polysplit's Biped Creatures (CREATURES_PACK.md) as the pack made
## it: its own figure on its own 99-bone skeleton, every part of it shown
## (armour, clothes, and the weapons it came with, skinned to its hand and
## equip bones), coloured by the pack's own RGB-mask shader
## (`shaders/creature_rgb.gdshader`) in the pack's colours for it, and held
## in the pose the pack's demo stands it in (`BipedCreaturePoses.fbx`, one
## frame each). The pack has no clips: it stands, and does not fight.
## Sized against the heroes (CREATURES_PACK.md §6).
##
## The FBX files are the pack's own, read by Godot's FBX importer
## (`assets/creatures/`). The mask is the pack's own
## (`assets/creatures/creature_mask.png`, RGBA: its alpha cuts out the eyes,
## brows and mouth; the Advanced Weapons' copy has no alpha).
##
## The pack's figures face +Z; the game's creatures face -Z, so the figure
## is turned round under the node. Set down on whatever is under it.

const DIR := "res://assets/creatures/"
const POSES := "res://assets/creatures/BipedCreaturePoses.fbx"
## The poses' take runs from frame -51, at 24 frames a second (the Unity
## clips name the frame each pose is held on).
const POSE_FIRST := -51.0
const POSE_FPS := 24.0
const MASK := preload("res://assets/creatures/creature_mask.png")
const SHADER := preload("res://shaders/creature_rgb.gdshader")

## kind -> [label, fbx, scale, pose frame (the Unity clip's), body colours,
## objects colours]. A creature with no pose of its own (the bare skeleton)
## takes the man zombie's shamble.
const KINDS := {
	&"orc": ["Orc", "Orc", 1.1, -46, "Body_Orc", "Objects_Orc"],
	&"goblin": ["Goblin", "Goblin", 0.65, -42, "Body_Goblin", "Objects_Goblin"],
	&"ogre": ["Ogre", "Ogre", 1.6, -50, "Body_Ogre", "Objects_Ogre"],
	&"troll": ["Troll", "Troll", 1.6, -48, "Body_Troll", "Objects"],
	&"ghoul": ["Ghoul", "Ghoul", 0.95, -34, "Body_Ghoul", "Objects"],
	&"golem": ["Golem", "Golem", 1.8, -52, "Body_Golem", "Objects"],
	&"zombie_m": ["Zombie (man)", "Zombie_M", 0.95, -36, "Body_Zombie", "Objects_Zombie"],
	&"zombie_f": ["Zombie (woman)", "Zombie_F", 0.95, -38, "Body_Zombie", "Objects_Zombie"],
	&"skeleton": ["Skeleton", "Skeleton_Base", 0.95, -36, "Body_Skeleton", "Objects"],
	&"skeleton_warrior": ["Skeleton warrior", "Skeleton_Warrior", 0.95, 14, "Body_Skeleton", "Objects_SkelWarrior"],
	&"skeleton_archer": ["Skeleton archer", "Skeleton_Archer", 0.95, 24, "Body_Skeleton", "Objects_SkelArcher"],
	&"skeleton_mage": ["Skeleton mage", "Skeleton_Mage", 0.95, 26, "Body_Skeleton", "Objects_SkelMage"],
	&"skeleton_all": ["Skeleton, all in one", "Skeleton_AllinOne", 0.95, 6, "Body_Skeleton", "Objects_SkelUniform"],
}

## The pack's materials (RGBRecolor_<name>.mat): colour 1, 2, 3, eye white,
## cornea, lip (sRGB, as the .mat holds them), metallic and smoothness of the
## mask's R, G, B.
const MATERIALS := {
	"Body_Ghoul": [Color(0.6118, 0.6157, 0.6392), Color(0.3674, 0.1207, 0.0672), Color(0.8616, 0.7554, 0.7072), Color(0.7955, 0.6820, 0.6172), Color(0.6281, 0.9635, 0.9937), Color(0.8078, 0.0235, 0.1608),
			Vector3(0, 0, 0), Vector3(0, 0.5, 0)],
	"Body_Goblin": [Color(0.5216, 0.6078, 0.3294), Color(0.3674, 0.1207, 0.0672), Color(1.0000, 0.8128, 0.6194), Color(0.7955, 0.6820, 0.6172), Color(1.0000, 0.9477, 0.2314), Color(0.8078, 0.0235, 0.1608),
			Vector3(0, 0, 0), Vector3(0, 0.5, 0)],
	"Body_Golem": [Color(0.5765, 0.6196, 0.6980), Color(0.5765, 0.6196, 0.6980), Color(0.5765, 0.6196, 0.6980), Color(0.5765, 0.6196, 0.6980), Color(0.5765, 0.6196, 0.6980), Color(0.5765, 0.6196, 0.6980),
			Vector3(0, 0, 0), Vector3(0, 0.5, 0)],
	"Body_Ogre": [Color(0.7799, 0.6072, 0.3507), Color(0.3674, 0.1207, 0.0672), Color(1.0000, 0.8128, 0.6194), Color(0.7955, 0.6820, 0.6172), Color(1.0000, 0.9477, 0.2314), Color(0.8078, 0.0235, 0.1608),
			Vector3(0, 0, 0), Vector3(0, 0.5, 0)],
	"Body_Orc": [Color(0.4392, 0.6549, 0.2941), Color(0.3674, 0.1207, 0.0672), Color(1.0000, 0.8128, 0.6194), Color(0.7955, 0.6820, 0.6172), Color(1.0000, 0.9477, 0.2314), Color(0.8078, 0.0235, 0.1608),
			Vector3(0, 0, 0), Vector3(0, 0.5, 0)],
	"Body_Skeleton": [Color(0.8868, 0.8191, 0.7334), Color(0.3674, 0.1207, 0.0672), Color(1.0000, 0.8128, 0.6194), Color(0.7955, 0.6820, 0.6172), Color(1.0000, 0.9477, 0.2314), Color(0.8078, 0.0235, 0.1608),
			Vector3(0, 0, 0), Vector3(0, 0.5, 0)],
	"Body_Troll": [Color(0.6981, 0.6891, 0.4369), Color(0.5660, 0.4648, 0.3720), Color(1.0000, 0.8128, 0.6194), Color(0.7955, 0.6820, 0.6172), Color(1.0000, 0.9477, 0.2314), Color(0.8078, 0.0235, 0.1608),
			Vector3(0, 0, 0), Vector3(0, 0.5, 0)],
	"Body_Zombie": [Color(0.5255, 0.6471, 0.6314), Color(0.5346, 0.0936, 0.0588), Color(1.0000, 0.8128, 0.6194), Color(0.7955, 0.6820, 0.6172), Color(1.0000, 0.9477, 0.2314), Color(0.8078, 0.0235, 0.1608),
			Vector3(0, 0, 0), Vector3(0, 0.5, 0)],
	"Objects_Goblin": [Color(0.5333, 0.1294, 0.1451), Color(0.2745, 0.2078, 0.2000), Color(0.6180, 0.6180, 0.6180), Color(0.8000, 0.8000, 0.8000), Color(0.2039, 0.8706, 0.9490), Color(0.8078, 0.0235, 0.1608),
			Vector3(0, 0, 0.25), Vector3(0, 0.4, 0.25)],
	"Objects_Ogre": [Color(0.5216, 0.3529, 0.1961), Color(0.5346, 0.3375, 0.2034), Color(0.6180, 0.6180, 0.6180), Color(0.8000, 0.8000, 0.8000), Color(0.2039, 0.8706, 0.9490), Color(0.8078, 0.0235, 0.1608),
			Vector3(0, 0, 0.25), Vector3(0, 0.4, 0.25)],
	"Objects_Orc": [Color(0.4784, 0.0941, 0.1137), Color(0.4745, 0.2941, 0.2157), Color(0.5294, 0.6157, 0.6588), Color(0.8000, 0.8000, 0.8000), Color(0.2039, 0.8706, 0.9490), Color(0.8078, 0.0235, 0.1608),
			Vector3(0, 0, 0.25), Vector3(0, 0.4, 0.25)],
	"Objects_SkelArcher": [Color(0.8805, 0.6159, 0.3461), Color(0.2510, 0.2471, 0.1529), Color(0.6180, 0.6180, 0.6180), Color(0.8000, 0.8000, 0.8000), Color(0.2039, 0.8706, 0.9490), Color(0.8078, 0.0235, 0.1608),
			Vector3(0, 0, 0.25), Vector3(0, 0.4, 0.25)],
	"Objects_SkelMage": [Color(0.3836, 0.2980, 0.3637), Color(0.3719, 0.4906, 0.3162), Color(0.6180, 0.6180, 0.6180), Color(0.8000, 0.8000, 0.8000), Color(0.2996, 0.2002, 0.5535), Color(0.8078, 0.0235, 0.1608),
			Vector3(0, 0, 0.25), Vector3(0, 0.4, 0.25)],
	"Objects_SkelUniform": [Color(0.3333, 0.2941, 0.3647), Color(0.3765, 0.2549, 0.1961), Color(0.3255, 0.3843, 0.4784), Color(0.8000, 0.8000, 0.8000), Color(0.2039, 0.8706, 0.9490), Color(0.8078, 0.0235, 0.1608),
			Vector3(0, 0, 0.25), Vector3(0, 0.4, 0.25)],
	"Objects_SkelWarrior": [Color(0.2314, 0.2706, 0.1882), Color(0.5723, 0.3458, 0.2574), Color(0.6180, 0.6180, 0.6180), Color(0.8000, 0.8000, 0.8000), Color(0.2039, 0.8706, 0.9490), Color(0.8078, 0.0235, 0.1608),
			Vector3(0, 0, 0.25), Vector3(0, 0.4, 0.25)],
	"Objects_Zombie": [Color(0.2431, 0.2000, 0.2471), Color(0.3451, 0.2471, 0.2275), Color(0.5451, 0.5020, 0.4392), Color(0.8000, 0.8000, 0.8000), Color(0.2039, 0.8706, 0.9490), Color(0.8078, 0.0235, 0.1608),
			Vector3(0, 0, 0.25), Vector3(0, 0.4, 0.25)],
	"Objects": [Color(0.3804, 0.5608, 0.8039), Color(0.6000, 0.2382, 0.1557), Color(0.6180, 0.6180, 0.6180), Color(0.8000, 0.8000, 0.8000), Color(0.2039, 0.8706, 0.9490), Color(0.8078, 0.0235, 0.1608),
			Vector3(0, 0, 0.25), Vector3(0, 0.4, 0.25)],
}

@export var kind: StringName = &"orc"

var figure: Node3D
var skeleton: Skeleton3D

static var _pose_anim: Animation
static var _made := {}


func _ready() -> void:
	var k: Array = KINDS[kind]
	var scene := load(DIR + String(k[1]) + ".fbx") as PackedScene
	figure = scene.instantiate() as Node3D
	figure.name = "Figure"
	var size: float = k[2]
	figure.scale = Vector3.ONE * size
	figure.rotation.y = PI
	add_child(figure)
	var found := figure.find_children("*", "Skeleton3D", true, false)
	skeleton = found[0] as Skeleton3D if not found.is_empty() else null
	_dress(String(k[4]), String(k[5]))
	hold_pose(float(k[3]))
	_add_body(size)
	_set_down.call_deferred()


## Stands on the ground under it (the arena calls creatures up a little
## above the floor, for bodies that fall; this one does not).
func _set_down() -> void:
	if not is_inside_tree():
		return
	await get_tree().physics_frame
	if not is_inside_tree():
		return
	var from := global_position + Vector3.UP * 1.5
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 20.0)
	# Not onto another of these, called up on the same spot.
	var others: Array[RID] = []
	for body in get_tree().get_nodes_in_group(&"pack_creature_body"):
		others.append((body as CollisionObject3D).get_rid())
	query.exclude = others
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		global_position.y = (hit["position"] as Vector3).y


## Every surface in the pack's shader: the body's material or the objects'.
func _dress(body: String, objects: String) -> void:
	dress(figure, body, objects)


## The same for any of the pack's figures (a fighting one's, [PackDress]).
static func dress(figure_root: Node, body: String, objects: String) -> void:
	for node in figure_root.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		mesh.visible = true
		for i in mesh.mesh.get_surface_count():
			var was := mesh.mesh.surface_get_material(i)
			var made_as := was.resource_name if was != null else ""
			mesh.set_surface_override_material(i, material(objects if made_as.contains("Objects") else body))


static func material(which: String) -> ShaderMaterial:
	if _made.has(which):
		return _made[which]
	var c: Array = MATERIALS[which]
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("mask_tex", MASK)
	for i in 6:
		var colour: Color = c[i]
		m.set_shader_parameter(["color1", "color2", "color3", "eye_white", "cornea", "lip"][i],
				Vector3(colour.r, colour.g, colour.b))
	m.set_shader_parameter("metal_rgb", c[6])
	m.set_shader_parameter("smooth_rgb", c[7])
	_made[which] = m
	return m


## Holds the figure in the pose the pack's take has at `frame`. The take's
## tracks are whole local transforms of the same 99 bones, so they are set
## as they are.
func hold_pose(frame: float) -> void:
	var anim := _poses()
	if anim == null or skeleton == null:
		return
	var t := clampf((frame - POSE_FIRST) / POSE_FPS, 0.0, anim.length)
	for i in anim.get_track_count():
		var bone := skeleton.find_bone(String(anim.track_get_path(i).get_concatenated_subnames()))
		if bone < 0:
			continue
		match anim.track_get_type(i):
			Animation.TYPE_POSITION_3D:
				skeleton.set_bone_pose_position(bone, anim.position_track_interpolate(i, t))
			Animation.TYPE_ROTATION_3D:
				skeleton.set_bone_pose_rotation(bone, anim.rotation_track_interpolate(i, t))
			Animation.TYPE_SCALE_3D:
				skeleton.set_bone_pose_scale(bone, anim.scale_track_interpolate(i, t))


static func _poses() -> Animation:
	if _pose_anim == null:
		var scene := load(POSES) as PackedScene
		if scene == null:
			return null
		var root := scene.instantiate()
		var players := root.find_children("*", "AnimationPlayer", true, false)
		if not players.is_empty():
			var player := players[0] as AnimationPlayer
			_pose_anim = player.get_animation(player.get_animation_list()[0])
		root.free()
	return _pose_anim


## Something to bump into: a capsule the creature's size.
func _add_body(size: float) -> void:
	var body := StaticBody3D.new()
	body.name = "Body"
	body.add_to_group(&"pack_creature_body")
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.32 * size
	capsule.height = 1.85 * size
	shape.shape = capsule
	shape.position = Vector3(0.0, 0.925 * size, 0.0)
	body.add_child(shape)
	add_child(body)


static func label(of: StringName) -> String:
	return String(KINDS[of][0]) if KINDS.has(of) else String(of)
