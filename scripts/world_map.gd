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

## The old level's walls, in metres, for a level with no lands round it.
const CORE_MIN := Vector2(-120.0, -455.5)
const CORE_MAX := Vector2(120.0, 179.5)
## What the map covers: the lands' rim where there are lands ([Lands]),
## 600 × 890 m, or the old level.
var WORLD_MIN := CORE_MIN
var WORLD_MAX := CORE_MAX
## Pixels a metre in the photograph (fewer over the lands: it is big).
var PIXELS_PER_METRE := 4.0
## How far in the big map zooms, over the whole map fitted to the screen.
const MOST_ZOOM := 14.0
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
	var lands := Lands.current
	if lands != null and is_instance_valid(lands) and not lands.info.is_empty():
		var r := lands.rim()
		WORLD_MIN = Vector2(r.x, r.y)
		WORLD_MAX = Vector2(r.z, r.w)
		PIXELS_PER_METRE = 3.0
		_names_from(lands)
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
				_zoom_about(b.position, 1.15 if b.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.15)
		elif b.button_index == MOUSE_BUTTON_LEFT:
			_dragging = b.pressed
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _dragging:
		_centre -= (event as InputEventMouseMotion).relative / maxf(_zoom, 0.0001)
		get_viewport().set_input_as_handled()
	elif event is InputEventMagnifyGesture:
		# a laptop's trackpad: two fingers pinched apart or together
		var g := event as InputEventMagnifyGesture
		_zoom_about(g.position, g.factor)
		get_viewport().set_input_as_handled()
	elif event is InputEventPanGesture:
		# and two fingers slid: the map moves under them
		_centre += (event as InputEventPanGesture).delta * 12.0 / maxf(_zoom, 0.0001)
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed:
		var key := (event as InputEventKey).physical_keycode
		match key:
			KEY_C:
				_centre = _to_map(player.global_position)
			KEY_EQUAL, KEY_KP_ADD, KEY_E:
				_zoom_about(_big.size * 0.5, 1.3)
			KEY_MINUS, KEY_KP_SUBTRACT, KEY_Q:
				_zoom_about(_big.size * 0.5, 1.0 / 1.3)
			KEY_0, KEY_KP_0, KEY_F:
				# the whole map on the screen
				_zoom = 0.0001
				_centre = (WORLD_MAX - WORLD_MIN) * PIXELS_PER_METRE * 0.5
			KEY_W, KEY_UP:
				_centre.y -= 60.0 / maxf(_zoom, 0.0001)
			KEY_S, KEY_DOWN:
				_centre.y += 60.0 / maxf(_zoom, 0.0001)
			KEY_A, KEY_LEFT:
				_centre.x -= 60.0 / maxf(_zoom, 0.0001)
			KEY_D, KEY_RIGHT:
				_centre.x += 60.0 / maxf(_zoom, 0.0001)
			_:
				return
		_big.queue_redraw()
		get_viewport().set_input_as_handled()


func _open(on: bool) -> void:
	_big_root.visible = on
	_dragging = false
	player.menu_open = on
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if on else Input.MOUSE_MODE_CAPTURED
	if on:
		# Opens on where you are.
		_centre = _to_map(player.global_position)


## Zooms by `factor` about a point of the screen, which stays under it.
func _zoom_about(at: Vector2, factor: float) -> void:
	var before := _centre + (at - _big.size * 0.5) / maxf(_zoom, 0.0001)
	_zoom = clampf(_zoom * factor, _fit(), _fit() * MOST_ZOOM)
	_centre = before - (at - _big.size * 0.5) / maxf(_zoom, 0.0001)
	_big.queue_redraw()


## The zoom that shows the whole map on the screen.
func _fit() -> float:
	var whole := (WORLD_MAX - WORLD_MIN) * PIXELS_PER_METRE
	var screen := _big.size if _big.size.x > 1.0 else Vector2(1280, 720)
	return minf(screen.x / whole.x, (screen.y - 50.0) / whole.y) * 0.96


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
	# Not the levels and numbers over the creatures ([CombatText]).
	eye.cull_mask &= ~CombatText.LAYER
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
	# The wood is drawn only so far from a camera, and from up here every tree
	# is further than that: for this one picture everything is drawn.
	var ranged: Dictionary = {}
	for node in get_tree().root.find_children("*", "GeometryInstance3D", true, false):
		var geo := node as GeometryInstance3D
		# (not the lands' ground: its near and far chunks share the distance)
		if Lands.current != null and Lands.current.is_ancestor_of(geo):
			continue
		if geo.visibility_range_end > 0.0 and geo.visibility_range_begin <= 0.0:
			ranged[geo] = geo.visibility_range_end
			geo.visibility_range_end = 0.0
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	for geo: GeometryInstance3D in ranged:
		if is_instance_valid(geo):
			geo.visibility_range_end = ranged[geo]
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
	var fit := _fit()
	_zoom = clampf(_zoom if _zoom > 0.0 else fit * 3.0, fit, fit * MOST_ZOOM)
	if _centre == Vector2.INF:
		_centre = _to_map(player.global_position)
	# kept on the map; where the map is narrower than the screen, in its middle
	var half := screen * 0.5 / _zoom
	_centre.x = clampf(_centre.x, minf(half.x, whole.x * 0.5), maxf(whole.x - half.x, whole.x * 0.5))
	_centre.y = clampf(_centre.y, minf(half.y - 50.0 / _zoom, whole.y * 0.5), maxf(whole.y - half.y, whole.y * 0.5))
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
	_names(place, view)
	_marks_on(_big, place, view, 6.0, false)
	_arrow(_big, place.call(player.global_position), _heading_on_map(-player.global_transform.basis.z), 15.0)
	# A band across the top with the title and the keys.
	_big.draw_rect(Rect2(0, 0, screen.x, 46), Color(0.03, 0.03, 0.03, 0.78))
	_big.draw_rect(Rect2(0, 46, screen.x, 1), EDGE)
	var font := ThemeDB.fallback_font
	_big.draw_string(font, Vector2(24, 31), "MAP", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, GOLD)
	_big.draw_string(font, Vector2(110, 30),
			"pinch / wheel / + −  zoom      drag / two fingers / WASD  move      0  whole map      C  you      M  close",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(GOLD, 0.75))
	var legend := [["you", GOLD], ["players", ALLY], ["creatures", FOE], ["people with work", GIVER]]
	var x := screen.x - 470.0 if screen.x > 1500.0 else screen.x + 100.0
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


## The names written on the big map: the lands, the villages and the city, the
## travelling fires (bright when lit).
var _labels: Array = []


func _names_from(lands: Lands) -> void:
	var regions: Dictionary = lands.info.get("regions", {})
	for key: String in regions:
		var poly: Array = regions[key].get("polygon", [])
		if poly.is_empty():
			continue
		var mid := Vector2.ZERO
		for p: Array in poly:
			mid += Vector2(float(p[0]), float(p[1]))
		mid /= poly.size()
		_labels.append({"at": Vector3(mid.x, 0, mid.y), "text": String(regions[key].get("name", key)), "size": 26, "kind": "land"})
	for st: Dictionary in lands.info.get("settlements", []):
		_labels.append({"at": Vector3(float(st["x"]), 0, float(st["z"])), "text": String(st.get("name", "")), "size": 16, "kind": "village"})
	var city: Dictionary = lands.info.get("city", {})
	if city.has("market"):
		_labels.append({"at": Vector3(float(city["market"]["x"]), 0, float(city["market"]["z"])), "text": String(city.get("name", "")), "size": 18, "kind": "village"})


func _names(place: Callable, view: Rect2) -> void:
	var font := ThemeDB.fallback_font
	var near := _zoom > _fit() * 1.8
	for label: Dictionary in _labels:
		if label["kind"] == "village" and not near and int(label["size"]) < 20:
			continue
		var at: Vector2 = place.call(label["at"])
		if not view.has_point(at):
			continue
		var text := String(label["text"])
		var size := int(label["size"])
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var p := at - Vector2(w * 0.5, 0)
		_big.draw_string_outline(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 5, Color(0, 0, 0, 0.75))
		_big.draw_string(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size,
				Color(1.0, 0.93, 0.75) if label["kind"] == "land" else Color(1, 1, 1, 0.92))
	var ways := get_tree().root.find_child("Waystones", true, false) as Waystones
	if ways == null:
		return
	for key: String in ways.fires:
		var at: Vector2 = place.call(ways.fires[key]["at"])
		if not view.has_point(at):
			continue
		var lit := key in ways.lit_keys
		_big.draw_circle(at, 6.0, Color(0, 0, 0, 0.6))
		_big.draw_circle(at, 4.5, Color(0.45, 0.7, 1.0) if lit else Color(0.45, 0.45, 0.5))
		if _zoom > _fit() * 4.0:
			var fire_name := String(ways.fires[key]["name"])
			_big.draw_string_outline(font, at + Vector2(8, 5), fire_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 4, Color(0, 0, 0, 0.7))
			_big.draw_string(font, at + Vector2(8, 5), fire_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 13,
					Color(0.7, 0.85, 1.0) if lit else Color(0.75, 0.75, 0.75))


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
