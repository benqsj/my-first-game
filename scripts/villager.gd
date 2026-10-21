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
## The poly heroes' looks no hero wears any more (the user's word, 2026-10-22:
## the NPCs are those, and the prisoner too): Tariel's, kept on his rig
## ([member SkinnedRig.npc_look]) — Blink's low poly man in the leathers or the
## plate, Synty's Sidekicks.
const RIG := "res://scenes/player/tariel_rigged_visuals.tscn"
const LOOKS: Array[StringName] = [&"squire", &"hooded", &"paladin", &"sworn", &"knight", &"iron"]
## How they stand about (Tariel's clips, on his rig): looking round, or a
## guard's ready stance.
const EASE := &"SS_Look_Around_Idle"
const EASE_ARMED := &"TR_Ready_Idle"
## The men he frees, in the order freed: the first in the leathers.
const FREED: Array[StringName] = [&"squire", &"hooded", &"sworn", &"knight", &"iron"]


## The look of the `k`th man freed (the same in his cage and in the village).
static func freed_look(k: int) -> StringName:
	return FREED[posmod(k, FREED.size())]
const WALK_SPEED := 1.19
const CHOKHA := [Color(0.36, 0.22, 0.12), Color(0.1, 0.14, 0.3), Color(0.33, 0.33, 0.34),
		Color(0.08, 0.08, 0.08), Color(0.78, 0.75, 0.66), Color(0.2, 0.26, 0.14)]

## Where they may walk, in the world; set by whoever places them.
var spots: Array[Vector3] = []
var variant: int = 0
## One of `LOOKS`: worn on the hero's rig. Empty: the mage's model in a chokha.
var look: StringName = &""
## A guard's sword and shield; the rest go with their hands empty.
var armed: bool = false
var pace: float = 1.2

var _anim: AnimationPlayer
var _model: Node3D
var _rng := RandomNumberGenerator.new()
var _target: Vector3
var _wait: float = 0.0
var _walking: bool = false
var _rig: Node3D
## A pose of its own instead of walking about (`stand_clip`), such as the
## prisoner crouched in his cage.
var stand_clip: StringName = &""


func _ready() -> void:
	_rng.seed = 7919 * (variant + 1)
	_wait = _rng.randf_range(0.5, 4.0)
	_target = global_position
	pace = _rng.randf_range(1.0, 1.35)
	if look != &"":
		_wear_look()
		return
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


## The look on the hero's rig, turned to face as this node does (+Z; the
## rig's Visuals carry their own half turn to the body's -Z).
func _wear_look() -> void:
	var scene := load(RIG) as PackedScene
	if scene == null:
		return
	var holder := Node3D.new()
	holder.name = "Figure"
	holder.rotation.y = PI
	add_child(holder)
	_rig = scene.instantiate() as Node3D
	_rig.set(&"npc_look", look)
	holder.add_child(_rig)
	if not armed:
		_unarm()
	# at ease, not on guard: the hero's idle is a fighter's, fists up
	var table: Variant = _rig.get(&"clips")
	if table is Dictionary:
		var ease := EASE_ARMED if armed else EASE
		var player := _rig.find_children("*", "AnimationPlayer", true, false).front() as AnimationPlayer
		if player != null and player.has_animation(ease):
			player.get_animation(ease).loop_mode = Animation.LOOP_LINEAR
			(table as Dictionary)[&"idle"] = ease
	if stand_clip != &"":
		var player := _rig.find_children("*", "AnimationPlayer", true, false).front() as AnimationPlayer
		if player != null and player.has_animation(stand_clip):
			player.get_animation(stand_clip).loop_mode = Animation.LOOP_LINEAR
			_rig.set_process(false)
			_rig.set_physics_process(false)
			player.play(stand_clip)
			player.seek(_rng.randf() * 2.0, true)


## No sword nor shield in their hands.
func _unarm() -> void:
	for node in _rig.find_children("*", "MeshInstance3D", true, false):
		var n := String(node.name).to_lower()
		if n.contains("sword") or n.contains("shield") or n.contains("blade"):
			(node as MeshInstance3D).visible = false
			(node as MeshInstance3D).set_meta(&"unarmed", true)


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
	if _anim == null and _rig == null:
		return
	if _rig != null and stand_clip != &"":
		return
	var watcher := _nearest_player()
	var speed := 0.0
	if _walking:
		var to := _target - global_position
		to.y = 0.0
		if to.length() < 0.3:
			_walking = false
			_wait = _rng.randf_range(2.0, 7.0)
			if _anim != null:
				if _anim.has_animation(&"VL_Idle_Play") and _rng.randf() < 0.4:
					_anim.play(&"VL_Idle_Play", 0.3)
				else:
					_anim.play(&"VL_Idle", 0.3)
		else:
			var step := to.normalized() * pace * delta
			global_position += step
			speed = pace
			_turn_to(to, delta, 5.0)
			if _anim != null:
				_anim.speed_scale = pace / WALK_SPEED
	else:
		if _anim != null:
			_anim.speed_scale = 1.0
			if _anim.current_animation != "VL_Idle" and not _anim.is_playing():
				_anim.play(&"VL_Idle", 0.3)
		if watcher != null:
			_turn_to(watcher.global_position - global_position, delta, 3.0)
		_wait -= delta
		if _wait <= 0.0 and not spots.is_empty() and watcher == null:
			_target = spots[_rng.randi() % spots.size()]
			_walking = true
			if _anim != null:
				_anim.play(&"VL_Walk", 0.3)
	if _rig != null:
		_rig.call(&"animate", delta, speed, speed / WALK_SPEED, false, false, 0.0)
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
