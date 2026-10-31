class_name CreaturePreview
extends PanelContainer
## The arena board's second panel (2026-10-14, the user's word): the creature
## picked on the board, shown on the right before it is called up — in its
## arms and its gear, at rest, turning slowly — and called up from here.
##
## The creature is the scene itself, made as it would be, in a world of its
## own: its mind put away (not processing, out of every group, nothing to
## touch), only its skeleton kept moving, its idle played by hand.

signal call_up_pressed

const VIEW_SIZE := Vector2(340.0, 440.0)
## How far a pixel of the mouse dragged across it turns it (radians); it
## turns only so (the user's word, 2026-10-14: not by itself).
const DRAG_TURN := 0.012

var _view: SubViewport
var _stage: Node3D
var _cam: Camera3D
var _shown: Node3D
var _title: Label
var _note: Label
var _frame_wait: int = 0


func _ready() -> void:
	add_theme_stylebox_override("panel", MenuStyle.panel_style(Color(0.08, 0.09, 0.11, 0.88)))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	add_child(column)
	_title = MenuStyle.label("", MenuStyle.BODY_SIZE, MenuStyle.GOLD)
	column.add_child(_title)
	var box := SubViewportContainer.new()
	box.stretch = true
	box.custom_minimum_size = VIEW_SIZE
	box.mouse_default_cursor_shape = Control.CURSOR_DRAG
	box.gui_input.connect(_on_drag)
	column.add_child(box)
	_view = SubViewport.new()
	_view.own_world_3d = true
	_view.msaa_3d = Viewport.MSAA_4X
	_view.size = Vector2i(VIEW_SIZE)
	box.add_child(_view)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.11, 0.12, 0.14)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.75, 0.8)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	_view.add_child(world_env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40.0, 35.0, 0.0)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	_view.add_child(sun)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-20.0, 200.0, 0.0)
	rim.light_energy = 0.5
	_view.add_child(rim)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(12.0, 12.0)
	ground.mesh = plane
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.2, 0.2, 0.21)
	floor_mat.roughness = 1.0
	ground.material_override = floor_mat
	_view.add_child(ground)
	_stage = Node3D.new()
	_view.add_child(_stage)
	_cam = Camera3D.new()
	_cam.fov = 32.0
	_view.add_child(_cam)
	_cam.current = true
	_note = MenuStyle.label("", MenuStyle.BODY_SIZE - 4, MenuStyle.GOLD_DIM)
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.custom_minimum_size = Vector2(VIEW_SIZE.x, 0.0)
	column.add_child(_note)
	column.add_child(MenuStyle.button("Call up", func() -> void: call_up_pressed.emit()))


## Shows `path` with `props` set on it, named `title`; `note` under it.
func show_creature(path: String, props: Dictionary = {}, title: String = "", note: String = "") -> void:
	clear()
	_title.text = title
	_note.text = note
	var scene := load(path) as PackedScene
	if scene == null:
		return
	var body := scene.instantiate() as Node3D
	if body == null:
		return
	for key: String in props:
		body.set(StringName(key), props[key])
	if "sight_range" in body:
		body.set("sight_range", 0.0)
	# its mind put away before it wakes: only made, never moving on its own
	body.process_mode = Node.PROCESS_MODE_DISABLED
	_stage.rotation = Vector3.ZERO
	_stage.add_child(body)
	for g in body.get_groups():
		if not String(g).begins_with("_"):
			body.remove_from_group(g)
	for n in [body] + body.find_children("*", "", true, false):
		if n is CollisionObject3D:
			(n as CollisionObject3D).collision_layer = 0
			(n as CollisionObject3D).collision_mask = 0
		elif n is Label3D or n is Sprite3D or n is GPUParticles3D:
			(n as Node3D).visible = false
		if n is Skeleton3D or n is AnimationPlayer or n is AnimationTree:
			(n as Node).process_mode = Node.PROCESS_MODE_ALWAYS
	var anim: Variant = body.get(&"_anim")
	var idle: Variant = body.get(&"idle_clip")
	if anim is SkeletonAnim and idle is StringName and (anim as SkeletonAnim).has_clip(idle):
		(anim as SkeletonAnim).play(idle, 0.0)
	_shown = body
	_frame_wait = 3


func clear() -> void:
	if _shown != null and is_instance_valid(_shown):
		_shown.queue_free()
	_shown = null


func _process(delta: float) -> void:
	if _shown == null or not is_instance_valid(_shown) or not is_visible_in_tree():
		return
	var anim: Variant = _shown.get(&"_anim")
	if anim is SkeletonAnim:
		(anim as SkeletonAnim).advance(delta)
	if _frame_wait > 0:
		_frame_wait -= 1
		if _frame_wait == 0:
			_frame()


## Dragged across with the left button held: turned about.
func _on_drag(event: InputEvent) -> void:
	var drag := event as InputEventMouseMotion
	if drag != null and (drag.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		_stage.rotation.y += drag.relative.x * DRAG_TURN
		accept_event()


## The camera on all of it, whatever its size; its face toward the camera.
func _frame() -> void:
	if _shown.has_method(&"_forward"):
		var f: Vector3 = _shown.call(&"_forward")
		if Vector2(f.x, f.z).length() > 0.01:
			_stage.rotation.y -= atan2(f.x, f.z)
	var box := AABB()
	var first := true
	# (one that knows its own size: Monster Bundle 2's skinned meshes keep
	# their boxes in the pack's units, [Mb2Creature])
	if _shown.has_method(&"view_box"):
		box = _shown.call(&"view_box")
		first = false
	for n in ([] if not first else _shown.find_children("*", "VisualInstance3D", true, false)):
		var v := n as VisualInstance3D
		if not v.is_visible_in_tree() or v is Decal or v is Light3D:
			continue
		var b := v.global_transform * v.get_aabb()
		if b.size.length() > 30.0:
			continue
		box = b if first else box.merge(b)
		first = false
	if first:
		box = AABB(Vector3(-0.5, 0.0, -0.5), Vector3(1.0, 2.0, 1.0))
	var tall := maxf(box.size.y, 0.5)
	var wide := maxf(box.size.x, box.size.z)
	var span := maxf(tall, wide * 0.75) * 1.4
	var dist := span * 0.5 / tan(deg_to_rad(_cam.fov * 0.5))
	var centre := Vector3(0.0, box.position.y + tall * 0.5, 0.0)
	_cam.look_at_from_position(centre + Vector3(0.0, tall * 0.25, dist), centre, Vector3.UP)
