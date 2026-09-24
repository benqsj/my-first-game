class_name Villager
extends Node3D

## Someone who lives in the village: walks the street from one spot to the
## next, stops, looks about, fidgets, and turns to watch a player who comes
## close.
##
## They are the mage's own model in everyday dress — a chokha of their own
## colour, the papakha black or white, no staff — out of
## `assets/villager/villager.glb`, which carries his idle, walk and fidget
## (`VL_*`, exported from `heroes.blend`).
##
## Not a physics body: they walk a handful of set spots along the street and
## round the square, which are clear of houses, and stand on whatever is under
## them. Nothing about them is simulated on more than one peer — each peer walks
## its own villagers from the same seed, and nobody fights them.

const MODEL := "res://assets/villager/villager.glb"
const WALK_SPEED := 1.19
const CHOKHA := [Color(0.36, 0.22, 0.12), Color(0.1, 0.14, 0.3), Color(0.33, 0.33, 0.34),
		Color(0.08, 0.08, 0.08), Color(0.78, 0.75, 0.66), Color(0.2, 0.26, 0.14)]

## Where they may walk, in the world; set by whoever places them.
var spots: Array[Vector3] = []
var variant: int = 0
var pace: float = 1.2

var _anim: AnimationPlayer
var _model: Node3D
var _rng := RandomNumberGenerator.new()
var _target: Vector3
var _wait: float = 0.0
var _walking: bool = false


func _ready() -> void:
	_rng.seed = 7919 * (variant + 1)
	var scene := load(MODEL) as PackedScene
	if scene == null:
		return
	_model = scene.instantiate() as Node3D
	add_child(_model)
	_anim = _model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _anim != null:
		for clip in [&"VL_Idle", &"VL_Walk", &"VL_Idle_Play"]:
			if _anim.has_animation(clip):
				_anim.get_animation(clip).loop_mode = Animation.LOOP_LINEAR if clip != &"VL_Idle_Play" \
						else Animation.LOOP_NONE
		# The clips carry their travel on the root bone: the body moves them.
		var skel := _model.find_child("Skeleton3D", true, false) as Skeleton3D
		if skel != null:
			_anim.root_motion_track = NodePath(String(_anim.get_node(_anim.root_node).get_path_to(skel)) + ":root")
		_anim.play(&"VL_Idle")
		_anim.seek(_rng.randf() * 2.0, true)
	_dress()
	_wait = _rng.randf_range(0.5, 4.0)
	_target = global_position
	pace = _rng.randf_range(1.0, 1.35)


## Their own colours: the chokha, and a white papakha on some.
func _dress() -> void:
	var coat: Color = CHOKHA[variant % CHOKHA.size()]
	var white_hat := variant % 3 == 1
	for node in _model.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		for i in mesh.get_surface_override_material_count():
			var mat := mesh.mesh.surface_get_material(i) as BaseMaterial3D
			if mat == null:
				continue
			var n := mat.resource_name
			var change: Color = Color(-1, 0, 0)
			if n == "mg_560b10":
				change = coat
			elif n == "mg_300508":
				change = coat.darkened(0.45)
			elif n == "mg_080707" and white_hat:
				change = Color(0.88, 0.85, 0.78)
			if change.r >= 0.0:
				var copy := mat.duplicate() as BaseMaterial3D
				copy.albedo_color = change
				mesh.set_surface_override_material(i, copy)


func _process(delta: float) -> void:
	if _anim == null:
		return
	var watcher := _nearest_player()
	if _walking:
		var to := _target - global_position
		to.y = 0.0
		if to.length() < 0.3:
			_walking = false
			_wait = _rng.randf_range(2.0, 7.0)
			if _anim.has_animation(&"VL_Idle_Play") and _rng.randf() < 0.4:
				_anim.play(&"VL_Idle_Play", 0.3)
			else:
				_anim.play(&"VL_Idle", 0.3)
		else:
			var step := to.normalized() * pace * delta
			global_position += step
			_turn_to(to, delta, 5.0)
			_anim.speed_scale = pace / WALK_SPEED
	else:
		_anim.speed_scale = 1.0
		if _anim.current_animation != "VL_Idle" and not _anim.is_playing():
			_anim.play(&"VL_Idle", 0.3)
		if watcher != null:
			_turn_to(watcher.global_position - global_position, delta, 3.0)
		_wait -= delta
		if _wait <= 0.0 and not spots.is_empty() and watcher == null:
			_target = spots[_rng.randi() % spots.size()]
			_walking = true
			_anim.play(&"VL_Walk", 0.3)
	_stand_on_ground()


## A player close enough to be watched, or null.
func _nearest_player() -> Node3D:
	for node in get_tree().get_nodes_in_group("player"):
		var who := node as Node3D
		if who != null and who.global_position.distance_to(global_position) < 5.0:
			return who
	return null


func _turn_to(direction: Vector3, delta: float, rate: float) -> void:
	direction.y = 0.0
	if direction.length_squared() < 0.0001:
		return
	# The model faces -Y in Blender, which is +Z here.
	var yaw := atan2(direction.x, direction.z)
	rotation.y = lerp_angle(rotation.y, yaw, 1.0 - exp(-rate * delta))


func _stand_on_ground() -> void:
	var space := get_world_3d().direct_space_state
	var from := global_position + Vector3.UP * 2.0
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 5.0, 1))
	if not hit.is_empty():
		global_position.y = (hit["position"] as Vector3).y
