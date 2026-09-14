extends SceneTree

## Builds Avtandil, the archer, and writes him out as a scene.
##
##     godot --path . --headless --script res://tools/build_avtandil.gd
##
## He is made the same way Tariel is — a hierarchy of named joint nodes with
## primitive meshes hung off them, no skeleton and no skinning — because that is
## what `CharacterRig` drives. The joint *names* are what matter: get those
## right and every bit of movement already written, from the stride to the wall
## climb, works on him without a line of new animation code.
##
## Where he differs is the silhouette. Tariel is armoured, broad and crimson;
## Avtandil is the hunter of the poem, so he is leaner through the shoulders,
## longer in the leg, hooded rather than helmeted, and dressed in greens and
## leather. Same height, so the same capsule fits.
##
## The output is a .tscn rather than a .glb on purpose: it is text, so it can be
## read in a diff, and nothing has to be imported before it can be used.

const OUT := "res://assets/avtandil/avtandil.tscn"

## The hunter's palette. Tariel's gold and crimson stay out of it except for a
## little trim, which is what keeps the two of them looking like they come from
## the same world without looking like each other.
const PALETTE := {
	"skin": Color("c08a60"),
	"hair": Color("241a14"),
	"hood": Color("2f3d26"),
	"tunic": Color("4a5d3a"),
	"leather": Color("6b4a2f"),
	"strap": Color("3d2a1a"),
	"steel": Color("a8b0b8"),
	"gold": Color("d0a044"),
	"wood": Color("5a3f28"),
	"linen": Color("cfc3a8"),
}

var _materials: Dictionary = {}
var _root: Node3D


func _initialize() -> void:
	_root = Node3D.new()
	_root.name = "avtandil"

	var hips := _joint(_root, "hips", Vector3(0.0, 0.95, 0.0), Vector3(0.05, 0.0, 0.0))
	_build_pelvis(hips)
	_build_torso(hips)
	_build_leg(hips, "l", -1.0)
	_build_leg(hips, "r", 1.0)

	_own(_root, _root)
	var packed := PackedScene.new()
	if packed.pack(_root) != OK:
		push_error("could not pack the model")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(OUT.get_base_dir())
	var err := ResourceSaver.save(packed, OUT)
	if err != OK:
		push_error("could not write %s (%d)" % [OUT, err])
		quit(1)
		return

	var meshes := _root.find_children("*", "MeshInstance3D", true, false).size()
	var joints := _root.find_children("*", "Node3D", true, false).size() - meshes
	print("wrote %s — %d meshes on %d joints" % [OUT, meshes, joints])
	quit()


#region Body
func _build_pelvis(hips: Node3D) -> void:
	_box(hips, "pelvis", Vector3(0.28, 0.19, 0.20), Vector3(0.0, -0.02, 0.0), "leather")
	# A hunter's belt, with a knife on the hip.
	_box(hips, "belt", Vector3(0.30, 0.06, 0.22), Vector3(0.0, 0.04, 0.0), "strap")
	_box(hips, "belt_buckle", Vector3(0.07, 0.06, 0.02), Vector3(0.0, 0.04, 0.11), "gold")
	_box(hips, "knife", Vector3(0.04, 0.20, 0.03), Vector3(0.13, -0.08, 0.02), "strap")
	# A short skirt of leather strips. Fewer and lighter than Tariel's mail.
	for i in 6:
		var across := lerpf(-0.13, 0.13, float(i) / 5.0)
		_box(hips, "kilt_%d" % i, Vector3(0.045, 0.22, 0.02),
				Vector3(across, -0.14, 0.11), "tunic")
		_box(hips, "kilt_back_%d" % i, Vector3(0.045, 0.19, 0.02),
				Vector3(across, -0.13, -0.11), "tunic")


func _build_torso(hips: Node3D) -> void:
	var spine := _joint(hips, "spine", Vector3(0.0, 0.13, 0.0), Vector3(0.09, 0.0, 0.0))
	_box(spine, "waist", Vector3(0.27, 0.18, 0.19), Vector3(0.0, 0.08, 0.0), "tunic")

	var chest := _joint(spine, "chest", Vector3(0.0, 0.19, 0.0), Vector3(0.02, 0.0, 0.0))
	_box(chest, "ribs", Vector3(0.33, 0.24, 0.21), Vector3(0.0, 0.10, 0.0), "tunic")
	# Leather over the chest rather than a breastplate: he is built to run.
	_box(chest, "jerkin", Vector3(0.30, 0.20, 0.04), Vector3(0.0, 0.10, 0.10), "leather")
	_box(chest, "baldric", Vector3(0.06, 0.30, 0.04), Vector3(-0.06, 0.10, 0.10), "strap")
	_box(chest, "baldric_back", Vector3(0.06, 0.30, 0.04), Vector3(0.06, 0.10, -0.10), "strap")
	_build_quiver(chest)

	var neck := _joint(chest, "neck", Vector3(0.0, 0.27, 0.0), Vector3.ZERO)
	_box(neck, "throat", Vector3(0.10, 0.09, 0.10), Vector3(0.0, 0.04, 0.0), "skin")

	var head := _joint(neck, "head", Vector3(0.0, 0.13, 0.0), Vector3(0.05, 0.0, 0.0))
	_build_head(head)

	_build_arm(chest, "l", -1.0)
	_build_arm(chest, "r", 1.0)


## The hood is what tells the two of them apart at a glance, so it has to sit on
## the head rather than over it: a shell across the crown and down the back, and
## a brim high enough to leave the face showing. A box pulled down over the eyes
## reads as a helmet, which is the one thing he is not wearing.
func _build_head(head: Node3D) -> void:
	_box(head, "skull", Vector3(0.20, 0.22, 0.21), Vector3(0.0, 0.06, 0.005), "skin")
	_box(head, "hood_crown", Vector3(0.215, 0.055, 0.215), Vector3(0.0, 0.155, -0.005), "hood")
	_box(head, "hood_side_l", Vector3(0.022, 0.19, 0.215), Vector3(-0.098, 0.055, -0.005), "hood")
	_box(head, "hood_side_r", Vector3(0.022, 0.19, 0.215), Vector3(0.098, 0.055, -0.005), "hood")
	_box(head, "hood_back", Vector3(0.215, 0.24, 0.035), Vector3(0.0, 0.04, -0.10), "hood")
	_box(head, "hood_brim", Vector3(0.225, 0.03, 0.06), Vector3(0.0, 0.165, 0.075), "hood")
	# The cowl gathered at the neck, which is what a thrown-back hood leaves.
	_box(head, "cowl", Vector3(0.20, 0.07, 0.16), Vector3(0.0, -0.06, -0.05), "tunic")
	_box(head, "hair", Vector3(0.17, 0.07, 0.05), Vector3(0.0, -0.01, -0.09), "hair")
	_box(head, "eye_l", Vector3(0.035, 0.028, 0.02), Vector3(-0.048, 0.075, 0.10), "linen")
	_box(head, "eye_r", Vector3(0.035, 0.028, 0.02), Vector3(0.048, 0.075, 0.10), "linen")
	_box(head, "beard", Vector3(0.13, 0.06, 0.09), Vector3(0.0, -0.025, 0.055), "hair")


## The quiver rides high on the back, angled so the arrows clear the drawing
## arm. The arrows are separate meshes so that shooting can take them away.
func _build_quiver(chest: Node3D) -> void:
	var quiver := _joint(chest, "quiver", Vector3(0.09, 0.14, -0.13),
			Vector3(-0.25, 0.0, -0.30))
	_box(quiver, "quiver_body", Vector3(0.10, 0.34, 0.10), Vector3(0.0, 0.0, 0.0), "leather")
	_box(quiver, "quiver_rim", Vector3(0.12, 0.04, 0.12), Vector3(0.0, 0.17, 0.0), "strap")
	for i in 5:
		var across := lerpf(-0.03, 0.03, float(i) / 4.0)
		var deep := 0.02 if i % 2 == 0 else -0.02
		_box(quiver, "arrow_%d" % i, Vector3(0.012, 0.16, 0.012),
				Vector3(across, 0.24, deep), "wood")
		_box(quiver, "fletch_%d" % i, Vector3(0.035, 0.06, 0.01),
				Vector3(across, 0.29, deep), "linen")
#endregion


#region Limbs
func _build_arm(chest: Node3D, side: String, sign: float) -> void:
	# Leaner than Tariel's, and the shoulders sit a little narrower.
	var shoulder := _joint(chest, "shoulder_%s" % side,
			Vector3(0.20 * sign, 0.18, 0.0), Vector3(0.06, 0.0, 0.12 * sign))
	_box(shoulder, "shoulder_cap_%s" % side, Vector3(0.12, 0.10, 0.13),
			Vector3(0.0, 0.0, 0.0), "leather")
	_box(shoulder, "upperarm_%s" % side, Vector3(0.10, 0.28, 0.10),
			Vector3(0.0, -0.14, 0.0), "skin")
	_box(shoulder, "sleeve_%s" % side, Vector3(0.12, 0.12, 0.12),
			Vector3(0.0, -0.05, 0.0), "tunic")

	var elbow := _joint(shoulder, "upperarm_%s_end" % side,
			Vector3(0.0, -0.28, 0.0), Vector3(-0.32, 0.0, 0.0))
	_box(elbow, "forearm_%s" % side, Vector3(0.09, 0.26, 0.09),
			Vector3(0.0, -0.13, 0.0), "skin")
	# A bracer on the bow arm, which is the one the string would otherwise flay.
	_box(elbow, "bracer_%s" % side, Vector3(0.11, 0.16, 0.11),
			Vector3(0.0, -0.10, 0.0), "leather" if sign > 0.0 else "strap")
	_box(elbow, "bracer_band_%s" % side, Vector3(0.115, 0.02, 0.115),
			Vector3(0.0, -0.05, 0.0), "gold")

	var wrist := _joint(elbow, "forearm_%s_end" % side,
			Vector3(0.0, -0.26, 0.0), Vector3(-0.08, 0.0, 0.0))
	var hand := _joint(wrist, "hand_%s" % side, Vector3.ZERO, Vector3.ZERO)
	_box(hand, "hand_%s_palm" % side, Vector3(0.07, 0.10, 0.05),
			Vector3(0.0, -0.05, 0.0), "skin")
	_box(hand, "hand_%s_thumb" % side, Vector3(0.03, 0.05, 0.03),
			Vector3(-0.04 * sign, -0.03, 0.01), "skin")

	# The bow hangs off the left hand — which, because the model's *_l nodes sit
	# on its -X side, is `hand_r`. The other hand draws the string.
	if sign > 0.0:
		_build_bow(_joint(hand, "bow", Vector3(0.0, -0.06, 0.0), Vector3.ZERO))
	else:
		_joint(hand, "draw", Vector3(0.0, -0.07, 0.02), Vector3.ZERO)


func _build_leg(hips: Node3D, side: String, sign: float) -> void:
	var hip := _joint(hips, "hip_%s" % side,
			Vector3(0.10 * sign, -0.06, 0.0), Vector3(0.26, 0.0, 0.05 * sign))
	_box(hip, "thigh_%s" % side, Vector3(0.15, 0.45, 0.15),
			Vector3(0.0, -0.225, 0.0), "tunic")

	var knee := _joint(hip, "thigh_%s_end" % side, Vector3(0.0, -0.45, 0.0),
			Vector3(0.34, 0.0, 0.0))
	_box(knee, "knee_%s" % side, Vector3(0.14, 0.08, 0.14), Vector3.ZERO, "leather")
	_box(knee, "shin_%s" % side, Vector3(0.12, 0.44, 0.12),
			Vector3(0.0, -0.22, 0.0), "skin")
	# Wrapped to the knee rather than plated: quieter, and quicker over ground.
	for i in 4:
		_box(knee, "wrap_%s_%d" % [side, i], Vector3(0.135, 0.05, 0.135),
				Vector3(0.0, -0.09 - 0.09 * i, 0.0), "linen")

	var ankle := _joint(knee, "shin_%s_end" % side, Vector3(0.0, -0.44, 0.0), Vector3.ZERO)
	var foot := _joint(ankle, "foot_%s" % side, Vector3.ZERO, Vector3(-0.04, 0.0, 0.0))
	_box(foot, "boot_%s" % side, Vector3(0.11, 0.08, 0.23),
			Vector3(0.0, -0.04, 0.045), "strap")
	_box(foot, "boot_%s_toe" % side, Vector3(0.10, 0.06, 0.07),
			Vector3(0.0, -0.05, 0.15), "strap")
	_box(foot, "boot_%s_cuff" % side, Vector3(0.125, 0.07, 0.13),
			Vector3(0.0, 0.02, -0.01), "leather")


## A recurve, held with its limbs running up and down the hand and its string on
## the archer's side. The limbs lean away from him and the horns curl back, so
## the nocks come out level with the grip and the string is straight — which is
## what makes the shape read as a bow rather than a stick.
##
## The nock positions are *solved* rather than typed in, so changing the lean of
## a limb moves the string with it instead of leaving it hanging in the air.
##
## The string is two halves, each hanging from its own nock, because a drawn bow
## has a bend in it. Each is a full metre of cord scaled down to the length it
## needs; the rig aims them at the drawing hand and scales them to suit.
func _build_bow(mount: Node3D) -> void:
	const LIMB := 0.34
	const HORN := 0.14
	const GRIP := 0.08
	## How far the limbs lean away from the archer, and how far the horns curl
	## back the other way, in radians.
	const LEAN := 0.30
	const CURL := -1.0

	_box(mount, "bow_grip", Vector3(0.045, 0.17, 0.05), Vector3.ZERO, "leather")
	_box(mount, "bow_grip_bind", Vector3(0.05, 0.05, 0.055), Vector3.ZERO, "strap")

	var along := func(angle: float) -> Vector3:
		return Vector3(0.0, cos(angle), sin(angle))
	var nock := Vector3.ZERO
	for side: float in [1.0, -1.0]:
		var tag := "u" if side > 0.0 else "l"
		# Mirrored about the grip: upwards is +Y, and the lean is the same lean.
		var lean := LEAN * side
		var curl := (LEAN + CURL) * side
		var root := Vector3(0.0, GRIP * side, 0.0)
		var tip: Vector3 = root + along.call(lean) * LIMB * side
		nock = tip + along.call(curl) * HORN * side

		_box(mount, "bow_limb_%s" % tag, Vector3(0.038, LIMB, 0.030),
				root.lerp(tip, 0.5), "wood", Vector3(lean, 0.0, 0.0))
		_box(mount, "bow_horn_%s" % tag, Vector3(0.032, HORN, 0.026),
				tip.lerp(nock, 0.5), "wood", Vector3(curl, 0.0, 0.0))

		# The cord hangs from the nock down its own -Y, so the rig only has to
		# point the joint at the drawing hand and scale it to reach.
		var cord := _joint(mount, "bow_string_%s" % tag, nock, Vector3.ZERO)
		cord.scale = Vector3(1.0, nock.y * side, 1.0)
		_box(cord, "bow_cord_%s" % tag, Vector3(0.012, 1.0, 0.012),
				Vector3(0.0, -0.5 * side, 0.0), "linen")

	# The arrow on the string. It hangs off its own joint so the rig can slide it
	# back with the draw and take it away when it is loosed.
	var arrow := _joint(mount, "bow_arrow", Vector3(0.0, 0.0, nock.z), Vector3(PI * 0.5, 0.0, 0.0))
	_box(arrow, "shaft", Vector3(0.011, 0.62, 0.011), Vector3(0.0, 0.31, 0.0), "wood")
	_box(arrow, "head", Vector3(0.022, 0.07, 0.006), Vector3(0.0, 0.64, 0.0), "steel")
	_box(arrow, "fletch_a", Vector3(0.001, 0.09, 0.028), Vector3(0.0, 0.055, 0.0), "linen")
	_box(arrow, "fletch_b", Vector3(0.028, 0.09, 0.001), Vector3(0.0, 0.055, 0.0), "linen")
#endregion


#region Scaffolding
func _joint(parent: Node3D, node_name: String, at: Vector3, euler: Vector3) -> Node3D:
	var node := Node3D.new()
	node.name = node_name
	node.position = at
	node.rotation = euler
	parent.add_child(node)
	return node


func _box(parent: Node3D, node_name: String, size: Vector3, at: Vector3,
		colour: String, euler: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = _material(colour)
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.position = at
	node.rotation = euler
	parent.add_child(node)
	return node


## One material per colour, shared by every mesh that uses it, so the model
## draws in as few passes as there are colours.
func _material(colour: String) -> StandardMaterial3D:
	if _materials.has(colour):
		return _materials[colour]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = PALETTE[colour]
	mat.roughness = 0.85
	mat.metallic = 0.6 if colour in ["steel", "gold"] else 0.0
	mat.resource_name = colour
	_materials[colour] = mat
	return mat


## Everything packed into a scene has to be owned by its root, or the pack
## keeps the root alone and throws the body away.
func _own(node: Node, root: Node) -> void:
	if node != root:
		node.owner = root
	for child in node.get_children():
		_own(child, root)
#endregion
