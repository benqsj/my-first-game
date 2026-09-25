class_name WorldMap
extends CanvasLayer

## The map: a small round one in the top-right corner, a little see-through,
## that turns with the camera,
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
const PIXELS_PER_METRE := 4.0
## The corner map: its size on screen, and how many metres across it shows.
const MINI_SIZE := 210.0
const MINI_SPAN := 90.0
const MINI_MARGIN := 22.0
## How much of the corner map shows through to the world behind it.
const MINI_OPACITY := 0.78

const GOLD := Color("d0a044")
const EDGE := Color(0.83, 0.72, 0.5, 0.7)
const ALLY := Color(0.6, 0.8, 1.0)
const FOE := Color(0.9, 0.18, 0.14)
const GIVER := Color(1.0, 0.82, 0.3)

var player: Player

var _texture: Texture2D
var _mini: Control
## The round frame the corner map is cut to, and its gilt rim.
var _mini_frame: Panel
var _big_root: Control
var _big: Control
var _givers: Array[Node3D] = []
## The big map's zoom (screen pixels per map pixel; 0 until first drawn) and
## the map point at the middle of the screen.
var _zoom: float = 0.0
var _centre: Vector2 = Vector2.INF
var _dragging: bool = false


func _ready() -> void:
	layer = 4
	# A round panel in the top-right corner that the map is cut to: whatever
	# the map draws outside the circle is not shown.
	_mini_frame = Panel.new()
	_mini_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mini_frame.anchor_left = 1.0
	_mini_frame.anchor_right = 1.0
	_mini_frame.offset_left = -MINI_SIZE - MINI_MARGIN
	_mini_frame.offset_right = -MINI_MARGIN
	_mini_frame.offset_top = MINI_MARGIN
	_mini_frame.offset_bottom = MINI_MARGIN + MINI_SIZE
	var round_bg := StyleBoxFlat.new()
	round_bg.bg_color = Color(0.05, 0.06, 0.05, 0.85)
	round_bg.set_corner_radius_all(int(MINI_SIZE * 0.5))
	round_bg.anti_aliasing = true
	_mini_frame.add_theme_stylebox_override("panel", round_bg)
	_mini_frame.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	_mini_frame.modulate = Color(1, 1, 1, MINI_OPACITY)
	add_child(_mini_frame)
	_mini = Control.new()
	_mini.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mini.set_anchors_preset(Control.PRESET_FULL_RECT)
	_mini.draw.connect(_draw_mini)
	_mini_frame.add_child(_mini)
	var rim := Panel.new()
	rim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rim.set_anchors_preset(Control.PRESET_FULL_RECT)
	var rim_style := StyleBoxFlat.new()
	rim_style.draw_center = false
	rim_style.set_border_width_all(2)
	rim_style.border_color = EDGE
	rim_style.set_corner_radius_all(int(MINI_SIZE * 0.5))
	rim_style.anti_aliasing = true
	rim.add_theme_stylebox_override("panel", rim_style)
	_mini_frame.add_child(rim)

	_big_root = Control.new()
	_big_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_big_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_big_root.visible = false
	add_child(_big_root)
	_big = Control.new()
	_big.set_anchors_preset(Control.PRESET_FULL_RECT)
	_big.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_big.draw.connect(_draw_big)
	_big_root.add_child(_big)

	_photograph.call_deferred()


func _process(_delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	_mini_frame.visible = not _big_root.visible
	if _mini_frame.visible:
		_mini.queue_redraw()
	else:
		_big.queue_redraw()


func _input(event: InputEvent) -> void:
	if player == null or not is_instance_valid(player):
		return
	if event.is_action_pressed("map"):
		_open(not _big_root.visible)
		get_viewport().set_input_as_handled()
		return
	if not _big_root.visible:
		return
	if event.is_action_pressed("ui_cancel"):
		_open(false)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		var b := event as InputEventMouseButton
		if b.button_index == MOUSE_BUTTON_WHEEL_UP or b.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if b.pressed:
				# Zoomed about the point under the mouse, which stays under it.
				var before := _centre + (b.position - _big.size * 0.5) / maxf(_zoom, 0.0001)
				_zoom *= 1.15 if b.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.15
				_big.queue_redraw()
				var z := _zoom
				_centre = before - (b.position - _big.size * 0.5) / maxf(z, 0.0001)
		elif b.button_index == MOUSE_BUTTON_LEFT:
			_dragging = b.pressed
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _dragging:
		_centre -= (event as InputEventMouseMotion).relative / maxf(_zoom, 0.0001)
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and (event as InputEventKey).physical_keycode == KEY_C:
		_centre = _to_map(player.global_position)
		get_viewport().set_input_as_handled()


func _open(on: bool) -> void:
	_big_root.visible = on
	_dragging = false
	player.menu_open = on
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if on else Input.MOUSE_MODE_CAPTURED
	if on:
		# Opens on where you are.
		_centre = _to_map(player.global_position)


func is_open() -> bool:
	return _big_root.visible


#region The photograph
## Takes the picture, once the renderer can draw the ground as well as the sky.
func _photograph() -> void:
	for node in get_tree().root.find_children("*", "Node3D", true, false):
		if node is QuestGiver:
			_givers.append(node)
	if DisplayServer.get_name() == "headless":
		return
	# Not on the first frame: on a machine meeting the level for the first time
	# the renderer is still compiling its shaders, and anything whose shader is
	# not ready yet is simply not drawn — the photograph comes out as nothing
	# but sky. So it waits, and takes it again until the ground is in it.
	for attempt in 8:
		await get_tree().create_timer(2.0 if attempt == 0 else 3.0).timeout
		if not is_inside_tree():
			return
		var image := await _take_photograph()
		if image == null or image.is_empty():
			continue
		_texture = ImageTexture.create_from_image(image)
		if not _only_sky(image):
			return


## True when the picture is (nearly) all sky: blue over green.
static func _only_sky(image: Image) -> bool:
	var small := image.duplicate() as Image
	small.resize(24, 48, Image.INTERPOLATE_BILINEAR)
	var skyish := 0
	for y in small.get_height():
		for x in small.get_width():
			var c := small.get_pixel(x, y)
			if c.b > c.g + 0.04 and c.b > c.r + 0.1:
				skyish += 1
	return skyish > small.get_width() * small.get_height() * 0.6


## One frame from straight above, then the viewport goes.
func _take_photograph() -> Image:
	var pixels := (WORLD_MAX - WORLD_MIN) * PIXELS_PER_METRE
	var view := SubViewport.new()
	view.size = Vector2i(int(pixels.x), int(pixels.y))
	view.world_3d = get_viewport().find_world_3d()
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
	view.queue_free()
	return image


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
	_mini.draw_string(ThemeDB.fallback_font, Vector2(box.size.x * 0.5 - 5.0, box.size.y - 12.0), "M",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(GOLD, 0.8))


func _draw_big() -> void:
	var screen := _big.size
	var whole := (WORLD_MAX - WORLD_MIN) * PIXELS_PER_METRE
	# The whole screen is the map's window: the map under it, moved by
	# dragging and zoomed by the wheel, never so far out that it floats in it.
	var fit := maxf(screen.x / whole.x, screen.y / whole.y) * 0.62
	_zoom = clampf(_zoom if _zoom > 0.0 else fit * 1.6, fit, fit * 6.0)
	if _centre == Vector2.INF:
		_centre = _to_map(player.global_position)
	var half := screen * 0.5 / _zoom
	_centre.x = clampf(_centre.x, minf(half.x, whole.x * 0.5), maxf(whole.x - half.x, whole.x * 0.5))
	_centre.y = clampf(_centre.y, minf(half.y, whole.y * 0.5), maxf(whole.y - half.y, whole.y * 0.5))
	var corner := screen * 0.5 - _centre * _zoom
	var frame := Rect2(corner, whole * _zoom)
	_big.draw_rect(Rect2(Vector2.ZERO, screen), Color(0.06, 0.07, 0.06, 1.0))
	if _texture != null:
		_big.draw_texture_rect(_texture, frame, false, Color(1.25, 1.25, 1.2))
	else:
		_big.draw_rect(frame, Color(0.2, 0.26, 0.16))
	var place := func(at: Vector3) -> Vector2:
		return corner + _to_map(at) * _zoom
	var view := Rect2(Vector2.ZERO, screen)
	_marks_on(_big, place, view, 6.0, false)
	_arrow(_big, place.call(player.global_position), _heading_on_map(-player.global_transform.basis.z), 15.0)
	# A band across the top with the title and the keys.
	_big.draw_rect(Rect2(0, 0, screen.x, 46), Color(0.03, 0.03, 0.03, 0.78))
	_big.draw_rect(Rect2(0, 46, screen.x, 1), EDGE)
	var font := ThemeDB.fallback_font
	_big.draw_string(font, Vector2(24, 31), "MAP", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, GOLD)
	_big.draw_string(font, Vector2(110, 30),
			"wheel  zoom      drag  move      C  back to you      M  close",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(GOLD, 0.75))
	var legend := [["you", GOLD], ["players", ALLY], ["creatures", FOE], ["people with work", GIVER]]
	var x := screen.x - 470.0
	for item: Array in legend:
		_big.draw_circle(Vector2(x, 25), 6.0, item[1])
		_big.draw_string(font, Vector2(x + 12, 30), String(item[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 15,
				Color(1, 1, 1, 0.8))
		x += 26.0 + font.get_string_size(String(item[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 16.0
	# North, top right under the band.
	var n_at := Vector2(screen.x - 40, 90)
	_big.draw_circle(n_at, 18.0, Color(0, 0, 0, 0.55))
	_big.draw_colored_polygon(PackedVector2Array([n_at + Vector2(0, -14), n_at + Vector2(6, 2),
			n_at + Vector2(-6, 2)]), GOLD)
	_big.draw_string(font, n_at + Vector2(-5, 16), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, GOLD)


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
