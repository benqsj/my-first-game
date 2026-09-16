extends SceneTree

## Stands each Bestiary creature on a plate and photographs it walking, so the
## retarget can be eyeballed: which way it faces, whether its feet reach the
## ground, and whether the library's shamble reads on its proportions.
##
##     godot --script res://tests/monster_shots.gd -- /abs/output/dir

const MONSTERS := {
	"imp": "res://scenes/enemies/imp.tscn",
	"puglin": "res://scenes/enemies/puglin.tscn",
}

var _dir := "res://"
var _camera: Camera3D
var _world: Node3D


func _initialize() -> void:
	var argv := OS.get_cmdline_user_args()
	if argv.size() > 0:
		_dir = argv[0]
	DirAccess.make_dir_recursive_absolute(_dir)

	_world = Node3D.new()
	root.add_child(_world)

	var env := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color(0.32, 0.36, 0.40)
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color(0.7, 0.72, 0.78)
	settings.ambient_light_energy = 0.9
	env.environment = settings
	_world.add_child(env)

	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.9, -0.7, 0.0)
	_world.add_child(sun)

	# Something for the feet to stand on, so a creature that has been settled
	# wrong sinks visibly instead of floating in the void.
	var ground := StaticBody3D.new()
	var plate := MeshInstance3D.new()
	var plane := BoxMesh.new()
	plane.size = Vector3(40, 1, 40)
	plate.mesh = plane
	plate.position.y = -0.5
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = plane.size
	shape.shape = box
	shape.position.y = -0.5
	ground.add_child(plate)
	ground.add_child(shape)
	_world.add_child(ground)

	_camera = Camera3D.new()
	_camera.fov = 45.0
	_world.add_child(_camera)

	for id: String in MONSTERS:
		await _photograph(id, MONSTERS[id])

	quit()


func _photograph(id: String, path: String) -> void:
	var monster: Monster = load(path).instantiate()
	monster.position = Vector3.ZERO
	# A long straight beat, so it is walking rather than turning in the shots.
	monster.roam_radius = 30.0
	monster.rest_time = 0.0
	_world.add_child(monster)
	await process_frame
	await process_frame

	var height := _height(monster)

	# Held still and square to the axes for the stills: the wander starts the
	# moment the creature is in the tree, and a photograph taken mid-turn says
	# nothing about which way the model is built to face.
	monster.set_physics_process(false)
	monster.rotation = Vector3.ZERO
	await process_frame

	print("%s: height=%.2f m, %s" % [id, height, _facing(monster)])

	# Front, side and three-quarter, framed to whatever size the creature is.
	var shots := {
		"front": Vector3(0.0, height * 0.6, height * 2.4),
		"side": Vector3(height * 2.4, height * 0.6, 0.0),
		"quarter": Vector3(height * 1.7, height * 0.9, height * 1.7),
	}
	for label: String in shots:
		_camera.position = monster.global_position + (shots[label] as Vector3)
		_camera.look_at(monster.global_position + Vector3.UP * height * 0.5)
		await _wait(4)
		await _save("%s_%s_idle" % [id, label])

	# Let it get going, then catch the cycle at two points.
	monster.set_physics_process(true)
	await _wait(70)
	for i in 2:
		_camera.position = monster.global_position + Vector3(height * 2.2, height * 0.7, height * 1.4)
		_camera.look_at(monster.global_position + Vector3.UP * height * 0.5)
		await _wait(10)
		await _save("%s_walk_%d" % [id, i])

	print("  after %d frames: at %s, speed %.2f m/s" % [
			90, monster.global_position, Vector3(monster.velocity.x, 0.0, monster.velocity.z).length()])
	monster.queue_free()
	await process_frame


## Which way the model is actually built to face, read off its own toes.
##
## Eyeballing a render does not answer this and it is easy to get backwards: a
## camera standing in front of a creature and a creature standing in front of a
## camera look identical in a still. The toes do answer it — on any biped the ball
## of the foot is in front of the ankle — and a creature in Godot travels down its
## own -Z, so the two have to agree.
func _facing(monster: Node3D) -> String:
	var skeleton := monster.find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton == null:
		return "no skeleton to read a facing off"
	var toe := skeleton.find_bone("ball_l")
	var ankle := skeleton.find_bone("foot_l")
	if toe < 0 or ankle < 0:
		return "no toe bone to read a facing off"

	var to_body := monster.global_transform.affine_inverse() * skeleton.global_transform
	var step := (to_body * skeleton.get_bone_global_rest(toe).origin
			- to_body * skeleton.get_bone_global_rest(ankle).origin)
	var forward := -step.z
	return "toes lead by %+.3f m along its own forward — %s" % [forward,
			"walks face-first" if forward > 0.0 else "WALKS BACKWARDS"]


## Top of the creature's drawn mesh above its feet.
func _height(monster: Node3D) -> float:
	var top := 0.0
	for m in monster.find_children("*", "MeshInstance3D", true, false):
		var mesh := m as MeshInstance3D
		if not mesh.visible:
			continue
		var here := monster.global_transform.affine_inverse() * mesh.global_transform
		top = maxf(top, (here * mesh.get_aabb()).end.y)
	return maxf(top, 0.5)


func _wait(frames: int) -> void:
	for i in frames:
		await process_frame


func _save(label: String) -> void:
	await process_frame
	var image := root.get_texture().get_image()
	var path := "%s/%s.png" % [_dir, label]
	image.save_png(path)
	print("  wrote ", path)
