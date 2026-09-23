class_name QuestGiver
extends Node3D

## Somebody who stands in the level with a job for the player: Datvi the
## woodcutter in the settlement, Ali of the Embers on the mere's shore, old
## Baqaq fishing off the harbour's dock. The talking and the counting are the
## [QuestBook]'s; this is the person.
##
## The models are single meshes with no skeleton, so they are brought to life
## the cheap way: a slow breath (a stretch and settle up the body), a small sway,
## and they turn to face whoever talks to them. Over their head is a mark — a
## gold `!` while they have something to say, a green `?` when the job is done
## and they are waiting to hear it — that is what you look for across a field.
##
## They stand on whatever is under them: on the first physics frame they drop
## on to the ground with a ray, so one can be placed on a dock or an island
## without its height being worked out by hand.

@export var npc_name: String = ""
@export var quest: StringName = &""
@export var model: PackedScene
## How tall the model should stand, in metres. Its own size is measured.
@export var height: float = 1.9
## Turn of the model inside the node, so its face looks along the node's -Z.
@export var model_yaw_degrees: float = 0.0
@export var snap_to_ground: bool = true
## Something to stand beside them (a campfire), in the node's frame.
@export var prop: PackedScene
@export var prop_offset: Vector3 = Vector3(1.4, 0.0, 0.6)
@export var prop_height: float = 0.0

var _look: Node3D
var _mark: Label3D
var _t: float = 0.0
var _snapped: bool = false
var _facing_target := NAN
var _book: QuestBook


func _ready() -> void:
	_t = randf() * 10.0
	_look = Node3D.new()
	_look.name = "Look"
	add_child(_look)
	if model != null:
		var body := model.instantiate() as Node3D
		_look.add_child(body)
		body.rotation.y = deg_to_rad(model_yaw_degrees)
		_fit(body, height)
	if prop != null:
		var thing := prop.instantiate() as Node3D
		add_child(thing)
		if prop_height > 0.0:
			_fit(thing, prop_height)
		thing.position += prop_offset
	# Solid, so nobody walks through them.
	var solid := StaticBody3D.new()
	solid.collision_layer = 1
	solid.collision_mask = 0
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = clampf(height * 0.22, 0.35, 0.9)
	capsule.height = maxf(height, capsule.radius * 2.0)
	shape.shape = capsule
	shape.position.y = capsule.height * 0.5
	solid.add_child(shape)
	add_child(solid)

	_mark = Label3D.new()
	_mark.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_mark.font_size = 96
	_mark.outline_size = 18
	_mark.pixel_size = 0.006
	_mark.no_depth_test = false
	_mark.position.y = height + 0.55
	add_child(_mark)

	for node in get_tree().get_nodes_in_group(&"quest_book"):
		_book = node as QuestBook
	if _book == null:
		call_deferred(&"_find_book")
	else:
		_book.register(self)


func _find_book() -> void:
	for node in get_tree().get_nodes_in_group(&"quest_book"):
		_book = node as QuestBook
	if _book != null:
		_book.register(self)


## Scales a model so it stands `tall` metres, feet on its parent's origin and
## centred over it. Measured in the parent's frame, so a turn already given to
## the model is allowed for.
static func _fit(body: Node3D, tall: float) -> void:
	var parent := body.get_parent() as Node3D
	if parent == null:
		return
	var box := AABB()
	var first := true
	var to_parent := parent.global_transform.affine_inverse()
	for node in body.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.mesh == null:
			continue
		var piece := (to_parent * mesh.global_transform) * mesh.mesh.get_aabb()
		box = piece if first else box.merge(piece)
		first = false
	if first or box.size.y <= 0.0001:
		return
	var s := tall / box.size.y
	var centre := box.get_center()
	body.scale *= s
	body.position = Vector3(-centre.x * s, -box.position.y * s, -centre.z * s)


func _physics_process(_delta: float) -> void:
	if _snapped or not snap_to_ground:
		set_physics_process(false)
		return
	_snapped = true
	var from := global_position + Vector3.UP * 4.0
	var ray := PhysicsRayQueryParameters3D.create(from, global_position + Vector3.DOWN * 6.0, 1)
	var solids: Array[RID] = []
	for node in find_children("*", "StaticBody3D", true, false):
		solids.append((node as StaticBody3D).get_rid())
	ray.exclude = solids
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	if not hit.is_empty():
		global_position.y = (hit["position"] as Vector3).y


func turn_to(who: Node3D) -> void:
	if who == null:
		return
	var to := who.global_position - global_position
	to.y = 0.0
	if to.length_squared() > 0.01:
		_facing_target = atan2(-to.x, -to.z)


func _process(delta: float) -> void:
	_t += delta
	# Breath and sway.
	var breath := sin(_t * 1.7) * 0.012
	_look.scale = Vector3(1.0 - breath * 0.5, 1.0 + breath, 1.0 - breath * 0.5)
	_look.rotation.z = sin(_t * 0.6) * 0.02
	if not is_nan(_facing_target):
		rotation.y = lerp_angle(rotation.y, _facing_target, 1.0 - exp(-4.0 * delta))
	# The mark over their head.
	var shown := ""
	var colour := Color.WHITE
	if _book != null:
		match int(_book.state.get(quest, QuestBook.State.OFFERED)):
			QuestBook.State.OFFERED:
				shown = "!"
				colour = Color(1.0, 0.8, 0.25)
			QuestBook.State.DONE:
				shown = "?"
				colour = Color(0.5, 1.0, 0.4)
	_mark.text = shown
	_mark.modulate = colour
	_mark.position.y = height + 0.55 + sin(_t * 2.2) * 0.07
