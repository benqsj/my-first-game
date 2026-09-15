extends SceneTree

## Prints, for one clip, where the mannequin puts each limb and where the
## retarget ends up putting Tariel's. Both are model-space directions, so a
## mapping that is out by a turn shows up as a sign or an axis swap rather than
## as something to squint at in a screenshot.
##   godot --headless --script res://tests/debug_retarget.gd -- [clip]

const WORLD := "res://scenes/world/greybox_world.tscn"

## [label, mannequin bone pair, Tariel joint pair]
const LIMBS := [
	["upper arm (sword)", ["upperarm_r", "lowerarm_r"], ["shoulder_l", "upperarm_l_end"]],
	["forearm (sword)", ["lowerarm_r", "hand_r"], ["upperarm_l_end", "forearm_l_end"]],
	["upper arm (shield)", ["upperarm_l", "lowerarm_l"], ["shoulder_r", "upperarm_r_end"]],
	["forearm (shield)", ["lowerarm_l", "hand_l"], ["upperarm_r_end", "forearm_r_end"]],
	["thigh", ["thigh_r", "calf_r"], ["hip_l", "thigh_l_end"]],
	["shin", ["calf_r", "foot_r"], ["thigh_l_end", "shin_l_end"]],
	["spine", ["spine_01", "spine_03"], ["spine", "chest"]],
	["neck", ["neck_01", "Head"], ["neck", "head"]],
]


func _initialize() -> void:
	var argv := OS.get_cmdline_user_args()
	var clip := StringName(argv[0]) if argv.size() > 0 else &"A_TPose"

	var world: Node3D = load(WORLD).instantiate()
	root.add_child(world)
	var player: Player = (world as World).player()

	await process_frame
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	player.global_position = Vector3(6.0, 0.2, 0.0)
	for i in 30:
		await physics_frame

	var rig: Node3D = player.rig
	var retarget := rig.find_child("Actions", true, false) as AnimRetarget
	if retarget == null:
		printerr("no retarget")
		quit(1)
		return

	const THROUGH := 0.85
	rig.hold_clip(clip, THROUGH)
	for i in 4:
		await process_frame

	var skel := retarget.find_child("Skeleton3D", true, false) as Skeleton3D
	print("\nclip '%s' held %d%% through, blend weight %.2f\n" % [
		clip, roundi(THROUGH * 100.0), retarget.weight()])
	print("%-20s %-26s %-26s" % ["limb", "mannequin", "tariel"])
	for entry in LIMBS:
		var bones: Array = entry[1]
		var joints: Array = entry[2]
		var source := _bone_dir(skel, bones[0], bones[1])
		var dest := _joint_dir(rig, joints[0], joints[1])
		var gap := rad_to_deg(source.angle_to(dest))
		print("%-20s %-26s %-26s  off by %5.1f deg" % [entry[0], _v(source), _v(dest), gap])

	# What the library's walk is worth at this game's speeds. The cycle is
	# seeked from the stride phase rather than played, so the rates below are not
	# what happens — they are the reason it is not what happens.
	var gait := rig.find_child("Gait", true, false) as AnimRetarget
	if gait != null:
		var length := gait.clip_length(rig.walk_clip)
		var stride := gait.measure_stride(rig.walk_clip)
		print("\nwalk cycle '%s': %.2fs, %.2f m per cycle (%.2f m/s as authored)" % [
			rig.walk_clip, length, stride, stride / maxf(length, 0.01)])
		print("  played straight it would want %.1fx at a walk, %.1fx at a run" % [
			4.5 * length / maxf(stride, 0.01), 9.0 * length / maxf(stride, 0.01)])

	# World-space landmarks, which is what a screenshot actually shows.
	print("\nworld space, player at %s facing %s" % [
		_v(player.global_position), _v(-player.global_transform.basis.z)])
	for node_name in ["hand_l", "hand_r", "nose", "head", "boot_l", "boot_r"]:
		var node := rig.find_child(node_name, true, false) as Node3D
		if node != null:
			print("  %-10s %s" % [node_name, _v(node.global_position)])

	quit()


## Direction from one bone to the next, in the skeleton's frame.
func _bone_dir(skel: Skeleton3D, from_bone: String, to_bone: String) -> Vector3:
	var a := skel.get_bone_global_pose(skel.find_bone(from_bone)).origin
	var b := skel.get_bone_global_pose(skel.find_bone(to_bone)).origin
	return (b - a).normalized()


## Direction from one joint to the next, in the model's frame.
func _joint_dir(rig: Node3D, from_joint: String, to_joint: String) -> Vector3:
	var to_model := rig.global_transform.affine_inverse()
	var a := to_model * (rig.find_child(from_joint, true, false) as Node3D).global_position
	var b := to_model * (rig.find_child(to_joint, true, false) as Node3D).global_position
	return (b - a).normalized()


func _v(v: Vector3) -> String:
	return "(%+.2f,%+.2f,%+.2f)" % [v.x, v.y, v.z]
