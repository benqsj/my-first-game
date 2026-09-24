class_name WorldMap
extends CanvasLayer

## The map: a small one in the bottom-right corner that turns with the camera,
## and the whole of it across the screen on **M** (M again, or Escape, closes
## it).
##
## The picture is the level itself, photographed once from straight above when
## the map is made: an orthographic camera over the whole 240 × 575 m, in a
## viewport that is rendered a single time and then thrown away. Nothing is
## drawn by hand, so a house moved or a wood grown is on the map the next time
## the game starts.
##
## On it: you (a gold arrow, pointing the way you face), the others playing
## (pale blue), creatures near enough to matter (red, the corner map only shows
## what is within its own reach), and the people with work to give (gold).
##
## North is up on the big map. On the small one the way the camera looks is up,
## so what is ahead on screen is ahead on the map.

## The level's walls, in metres: x from -120 to 120, z from -455.5 to 119.5.
const WORLD_MIN := Vector2(-120.0, -455.5)
const WORLD_MAX := Vector2(120.0, 119.5)
## Pixels a metre in the photograph.
const PIXELS_PER_METRE := 2.0
## The corner map: its size on screen, and how many metres across it shows.
const MINI_SIZE := 210.0
const MINI_SPAN := 90.0
const MINI_MARGIN := 22.0

const GOLD := Color("d0a044")
const EDGE := Color(0.83, 0.72, 0.5, 0.7)
const ALLY := Color(0.6, 0.8, 1.0)
const FOE := Color(0.9, 0.18, 0.14)
const GIVER := Color(1.0, 0.82, 0.3)

var player: Player

var _texture: Texture2D
var _mini: Control
var _big_root: Control
var _big: Control
var _givers: Array[Node3D] = []


func _ready() -> void:
	layer = 4
	_mini = Control.new()
	_mini.clip_contents = true
	_mini.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mini.anchor_left = 1.0
	_mini.anchor_right = 1.0
	_mini.anchor_top = 1.0
	_mini.anchor_bottom = 1.0
	_mini.offset_left = -MINI_SIZE - MINI_MARGIN
	_mini.offset_right = -MINI_MARGIN
	_mini.offset_top = -MINI_SIZE - MINI_MARGIN
	_mini.offset_bottom = -MINI_MARGIN
	_mini.draw.connect(_draw_mini)
	add_child(_mini)

	_big_root = Control.new()
	_big_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_big_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_big_root.visible = false
	add_child(_big_root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_big_root.add_child(dim)
	_big = Control.new()
	_big.set_anchors_preset(Control.PRESET_FULL_RECT)
	_big.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_big.draw.connect(_draw_big)
	_big_root.add_child(_big)

	_photograph.call_deferred()


func _process(_delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	_mini.visible = not _big_root.visible
	if _mini.visible:
		_mini.queue_redraw()
	else:
		_big.queue_redraw()


func _input(event: InputEvent) -> void:
	if player == null or not is_instance_valid(player):
		return
	if event.is_action_pressed("map"):
		_big_root.visible = not _big_root.visible
		get_viewport().set_input_as_handled()
	elif _big_root.visible and event.is_action_pressed("ui_cancel"):
		_big_root.visible = false
		get_viewport().set_input_as_handled()


func is_open() -> bool:
	return _big_root.visible


#region The photograph
## Takes the picture: one frame from straight above, then the viewport goes.
func _photograph() -> void:
	for node in get_tree().root.find_children("*", "Node3D", true, false):
		if node is QuestGiver:
			_givers.append(node)
	if DisplayServer.get_name() == "headless":
		return
	var pixels := (WORLD_MAX - WORLD_MIN) * PIXELS_PER_METRE
	var view := SubViewport.new()
	view.size = Vector2i(int(pixels.x), int(pixels.y))
	view.world_3d = get_viewport().world_3d
	view.render_target_update_mode = SubViewport.UPDATE_ONCE
	view.msaa_3d = Viewport.MSAA_2X
	add_child(view)
	var eye := Camera3D.new()
	eye.projection = Camera3D.PROJECTION_ORTHOGONAL
	eye.keep_aspect = Camera3D.KEEP_HEIGHT
	eye.size = WORLD_MAX.y - WORLD_MIN.y
	eye.near = 1.0
	eye.far = 600.0
	view.add_child(eye)
	var middle := (WORLD_MIN + WORLD_MAX) * 0.5
	eye.position = Vector3(middle.x, 300.0, middle.y)
	# Looking straight down with north (+z) at the top of the picture.
	eye.basis = Basis.looking_at(Vector3.DOWN, Vector3(0, 0, 1))
	eye.current = true
	# The world's own sky and haze, without the haze: seen from three hundred
	# metres up through the fog the whole map is one pale grey.
	for node in get_tree().root.find_children("*", "WorldEnvironment", true, false):
		var env := (node as WorldEnvironment).environment
		if env != null:
			var clear := env.duplicate() as Environment
			clear.fog_enabled = false
			clear.volumetric_fog_enabled = false
			clear.glow_enabled = false
			eye.environment = clear
			break
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image := view.get_texture().get_image()
	if image != null and not image.is_empty():
		_texture = ImageTexture.create_from_image(image)
	view.queue_free()


## Where a point of the world is on the photograph, in its pixels. Straight
## down with north at the top puts +z up and -x to the right.
func _to_map(at: Vector3) -> Vector2:
	var middle := (WORLD_MIN + WORLD_MAX) * 0.5
	return Vector2(-(at.x - middle.x), -(at.z - middle.y)) * PIXELS_PER_METRE \
			+ (WORLD_MAX - WORLD_MIN) * PIXELS_PER_METRE * 0.5


## The way the camera looks, as an angle on the photograph.
func _heading_on_map(ahead: Vector3) -> float:
	return atan2(-ahead.z, -ahead.x)
#endregion


#region Drawing
func _draw_mini() -> void:
	var box := Rect2(Vector2.ZERO, _mini.size)
	_mini.draw_rect(box, Color(0.05, 0.06, 0.05, 0.85))
	var centre := box.size * 0.5
	var zoom := MINI_SIZE / (MINI_SPAN * PIXELS_PER_METRE)
	var ahead := -player.camera_rig.global_transform.basis.z
	# Turned so the way the camera looks is up.
	var turn := -PI * 0.5 - _heading_on_map(ahead)
	var me := _to_map(player.global_position)
	if _texture != null:
		_mini.draw_set_transform(centre, turn, Vector2(zoom, zoom))
		_mini.draw_texture(_texture, -me, Color(1, 1, 1, 0.92))
		_mini.draw_set_transform_matrix(Transform2D.IDENTITY)
	var place := func(at: Vector3) -> Vector2:
		return centre + (_to_map(at) - me).rotated(turn) * zoom
	_marks(place, box.grow(-4.0), 3.0)
	var facing := -player.global_transform.basis.z
	_arrow(_mini, centre, turn + _heading_on_map(facing), 9.0)
	_mini.draw_rect(box, EDGE, false, 2.0)
	_mini.draw_string(ThemeDB.fallback_font, Vector2(box.size.x - 20.0, 16.0), "M",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(GOLD, 0.8))


func _draw_big() -> void:
	var screen := _big.size
	var whole := (WORLD_MAX - WORLD_MIN) * PIXELS_PER_METRE
	var zoom := minf(screen.y * 0.88 / whole.y, screen.x * 0.9 / whole.x)
	var shown := whole * zoom
	var corner := (screen - shown) * 0.5
	var frame := Rect2(corner, shown)
	_big.draw_rect(frame.grow(6.0), Color(0.05, 0.05, 0.05, 0.95))
	if _texture != null:
		_big.draw_texture_rect(_texture, frame, false)
	else:
		_big.draw_rect(frame, Color(0.2, 0.26, 0.16))
	var place := func(at: Vector3) -> Vector2:
		return corner + _to_map(at) * zoom
	_marks_on(_big, place, frame, 4.5, false)
	_arrow(_big, place.call(player.global_position), _heading_on_map(-player.global_transform.basis.z), 11.0)
	_big.draw_rect(frame.grow(6.0), EDGE, false, 2.0)
	var font := ThemeDB.fallback_font
	_big.draw_string(font, corner + Vector2(0, -16), "MAP", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, GOLD)
	_big.draw_string(font, corner + Vector2(shown.x - 90, -16), "M  close", HORIZONTAL_ALIGNMENT_LEFT, -1, 15,
			Color(GOLD, 0.7))
	_big.draw_string(font, corner + Vector2(shown.x * 0.5 - 5, 14), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, GOLD)


func _marks(place: Callable, inside: Rect2, dot: float) -> void:
	_marks_on(_mini, place, inside, dot, true)


## Everybody else, as dots: givers of work, creatures, the other players.
func _marks_on(on: Control, place: Callable, inside: Rect2, dot: float, near_only: bool) -> void:
	for giver in _givers:
		if is_instance_valid(giver):
			var at: Vector2 = place.call(giver.global_position)
			if inside.has_point(at):
				on.draw_circle(at, dot + 1.5, Color(0, 0, 0, 0.6))
				on.draw_circle(at, dot + 0.5, GIVER)
	for node in get_tree().get_nodes_in_group("enemy"):
		var foe := node as Node3D
		if foe == null or foe.get("is_dead") == true or not foe.visible:
			continue
		if near_only and foe.global_position.distance_to(player.global_position) > MINI_SPAN * 0.75:
			continue
		var at: Vector2 = place.call(foe.global_position)
		if inside.has_point(at):
			on.draw_circle(at, dot, FOE)
	for node in get_tree().get_nodes_in_group("player"):
		var other := node as Node3D
		if other == null or other == player:
			continue
		var at: Vector2 = place.call(other.global_position)
		if inside.has_point(at):
			on.draw_circle(at, dot + 1.0, Color(0, 0, 0, 0.6))
			on.draw_circle(at, dot, ALLY)


## You: a gold arrowhead pointing along `angle` (radians on the screen).
func _arrow(on: Control, at: Vector2, angle: float, size: float) -> void:
	var tip := Vector2(cos(angle), sin(angle))
	var side := Vector2(-tip.y, tip.x)
	var shape := PackedVector2Array([at + tip * size, at - tip * size * 0.6 + side * size * 0.7,
			at - tip * size * 0.25, at - tip * size * 0.6 - side * size * 0.7])
	var rim := PackedVector2Array()
	for p in shape:
		rim.append(at + (p - at) * 1.3)
	on.draw_colored_polygon(rim, Color(0, 0, 0, 0.7))
	on.draw_colored_polygon(shape, GOLD)
#endregion
