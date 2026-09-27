class_name Looks
extends Node

## The world's looks, side by side: **F8** steps through them in play, to see
## what each one looks like and what it costs on this machine.
##
## A look is a ground and a grass:
##
## 0. **old** — the house ground and the full grass clump (8 256 triangles).
##    The default: what the game looked like before any of this.
## 1. **new** — the forest-floor ground ([code]terrain_forest.gdshader[/code]):
##    fallen leaves and moss under the trees, grassy earth under the meadows,
##    bare earth with sprigs and leaves in the open, blended by height; the
##    light grass clump (364 triangles, opaque); and a low sward filling the
##    meadows ([member Meadows.sward]): short clumps of 180 triangles in mixed
##    greens, yellow-green, straw and the odd dead blade, six round every
##    meadow clump, drawn to 30% of the grass's distance.
## 2. **old ground, light grass** — only the grass changed, to see that alone.
## 3. **photo** — the photographed ground (`Terrain.styles[1]`) with the light
##    grass.
## 4. **new ground, gras2** — the forest floor with the user's own clump from
##    `assets/grass2/gras2.glb` (6 672 triangles, alpha-dithered): to judge it
##    against the light one.
##
## `-- look_1` (or any number) starts in that look. The ground's own
## `ground_a` / `ground_b` still pick the ground alone.
##
## The forest floor needs to know where the trees and the grass are. That is a
## small picture of the map ([method ground_mask]), red where trunks stand and
## green where the meadows planted grass, two metres a pixel, worked out from
## the wood and the field the first time the look is worn. It is the same
## picture a painted mask would be, when the ground comes to be painted by hand.

const OLD_GRASS := "res://assets/grass/grass2.glb"
const LIGHT_GRASS := "res://assets/grass/grass_light.glb"
const GRASS2 := "res://assets/grass2/gras2.glb"
const SHORT_GRASS := "res://assets/grass/grass_short.glb"
## The sward's share of the grass's draw distance.
const SWARD_REACH := 0.3
## Terrain.styles: 0 house, 1 photographed, 2 forest floor.
const LOOKS: Array[Dictionary] = [
	{"name": "old", "ground": 0, "grass": OLD_GRASS},
	{"name": "new: forest floor, low sward, light grass", "ground": 2, "grass": LIGHT_GRASS, "sward": true},
	{"name": "old ground, light grass", "ground": 0, "grass": LIGHT_GRASS},
	{"name": "photo ground, light grass", "ground": 1, "grass": LIGHT_GRASS},
	{"name": "new ground, gras2", "ground": 2, "grass": GRASS2},
]
## Metres a pixel of the ground mask.
const MASK_CELL := 2.0
## How far round a trunk the ground is forest floor.
const TRUNK_REACH := 5.5

@export var look: int = 0

var _terrain: Terrain
var _sward: GrassField = null
var _mask: ImageTexture = null
var _mask_rect := Rect2()
var _label: Label = null
var _label_left := 0.0


func _ready() -> void:
	_terrain = get_parent() as Terrain
	var meadows := _world().get_node_or_null("Meadows")
	if meadows != null and meadows.has_signal("grown"):
		meadows.connect("grown", _on_grown)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("look_") and arg.substr(5).is_valid_int():
			look = int(arg.substr(5))
	# Only a look other than the old one changes anything at load: the old one
	# is what the level is already wearing.
	if look != 0:
		apply(look)


## Wears look `which` (wrapped round the list).
func apply(which: int) -> void:
	look = posmod(which, LOOKS.size())
	var spec: Dictionary = LOOKS[look]
	var ground: int = spec["ground"]
	if _terrain != null:
		if ground == 2:
			_dress_forest_floor()
		if ground < _terrain.styles.size():
			_terrain.set_style(ground)
	var field := _field()
	if field != null:
		field.set_clump_scene(spec["grass"])
	_show_sward(bool(spec.get("sward", false)))


## The low sward: a second field of short clumps, grown the first time a look
## wants it and hidden (and still) when one does not.
func sward() -> GrassField:
	return _sward


func _show_sward(on: bool) -> void:
	if on and _sward == null:
		_grow_sward()
	if _sward == null:
		return
	_sward.visible = on
	_sward.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED


func _grow_sward() -> void:
	var field := _field()
	var meadows := _world().get_node_or_null("Meadows") as Meadows
	if field == null or meadows == null or meadows.sward_tints.is_empty():
		return
	_sward = GrassField.new()
	_sward.name = "Sward"
	_sward.clump_scene = SHORT_GRASS
	_sward.draw_chunk = 16.0
	_sward.draw_distance = field.draw_distance
	_sward.draw_distance_scale = SWARD_REACH
	_sward.lod_bias = field.lod_bias
	_sward.wind_radius = 14.0
	field.get_parent().add_child(_sward)
	_sward.transform = field.transform
	_sward.replace(meadows.sward, meadows.sward_tints)


## Where the trees and the grass are, for the forest floor: red, how much a
## point is under trees; green, how much grass was planted round it. Built the
## first time it is asked for, and again when the meadows grow anew.
func ground_mask() -> ImageTexture:
	if _mask == null:
		_build_mask()
	return _mask


func mask_rect() -> Rect2:
	if _mask == null:
		_build_mask()
	return _mask_rect


func _dress_forest_floor() -> void:
	if _terrain == null or _terrain.styles.size() < 3:
		return
	var mat := _terrain.styles[2] as ShaderMaterial
	if mat == null:
		return
	var rect := mask_rect()
	mat.set_shader_parameter("ground_mask", ground_mask())
	mat.set_shader_parameter("mask_rect", Vector4(rect.position.x, rect.position.y, rect.size.x, rect.size.y))


func _on_grown() -> void:
	# The grass is new: the mask has to follow it, and a light look has to
	# keep its own clump (the field was rebuilt with whatever it was given).
	_mask = null
	if _sward != null:
		var meadows := _world().get_node_or_null("Meadows") as Meadows
		if meadows != null:
			_sward.replace(meadows.sward, meadows.sward_tints)
	if look != 0:
		apply(look)


func _build_mask() -> void:
	var started := Time.get_ticks_usec()
	var half := 120.0
	var north := 180.0
	var south := -456.0
	if _terrain != null:
		half = _terrain.half_size
		north = _terrain.north_edge()
	_mask_rect = Rect2(-half, south, half * 2.0, north - south)
	var w := int(ceil(_mask_rect.size.x / MASK_CELL))
	var h := int(ceil(_mask_rect.size.y / MASK_CELL))
	var wood := PackedFloat32Array()
	wood.resize(w * h)
	var grass := PackedFloat32Array()
	grass.resize(w * h)

	var forest := _world().get_node_or_null("Forest")
	if forest != null and forest.has_method("trunk_positions"):
		var reach := int(ceil(TRUNK_REACH / MASK_CELL))
		for at: Vector2 in forest.call("trunk_positions"):
			var c := _cell(at, w, h)
			for dz in range(-reach, reach + 1):
				for dx in range(-reach, reach + 1):
					var x := c.x + dx
					var z := c.y + dz
					if x < 0 or z < 0 or x >= w or z >= h:
						continue
					var d := Vector2(dx, dz).length() * MASK_CELL / TRUNK_REACH
					if d >= 1.0:
						continue
					var k := z * w + x
					wood[k] = minf(wood[k] + (1.0 - d * d) * 0.55, 1.0)

	var field := _field()
	if field != null:
		for i in field.clump_count():
			var at := field.to_global(field.clump_home(i))
			var c := _cell(Vector2(at.x, at.z), w, h)
			for dz in range(-1, 2):
				for dx in range(-1, 2):
					var x := c.x + dx
					var z := c.y + dz
					if x < 0 or z < 0 or x >= w or z >= h:
						continue
					var k := z * w + x
					var add := 0.34 if dx == 0 and dz == 0 else 0.1
					grass[k] = minf(grass[k] + add, 1.0)

	# Softened, so a lone tree stands in a smudge of leaves rather than on a
	# disc of them, and the thick of the wood is one floor.
	for pass_ in 2:
		wood = _blur(wood, w, h)

	var data := PackedByteArray()
	data.resize(w * h * 2)
	for k in w * h:
		data[k * 2] = int(wood[k] * 255.0)
		data[k * 2 + 1] = int(grass[k] * 255.0)
	var image := Image.create_from_data(w, h, false, Image.FORMAT_RG8, data)
	_mask = ImageTexture.create_from_image(image)
	print("Looks: ground mask %dx%d in %.0f ms" % [w, h, (Time.get_ticks_usec() - started) / 1000.0])


static func _blur(src: PackedFloat32Array, w: int, h: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(w * h)
	for z in h:
		for x in w:
			var total := 0.0
			var n := 0
			for dz in range(-1, 2):
				for dx in range(-1, 2):
					var xx := x + dx
					var zz := z + dz
					if xx >= 0 and zz >= 0 and xx < w and zz < h:
						total += src[zz * w + xx]
						n += 1
			out[z * w + x] = total / n
	return out


func _cell(at: Vector2, w: int, h: int) -> Vector2i:
	return Vector2i(clampi(int((at.x - _mask_rect.position.x) / MASK_CELL), 0, w - 1),
			clampi(int((at.y - _mask_rect.position.y) / MASK_CELL), 0, h - 1))


## The meadows' own field (not the sward).
func _field() -> GrassField:
	for node in _world().find_children("*", "GrassField", true, false):
		if node != _sward:
			return node as GrassField
	return null


func _world() -> Node:
	var node: Node = self
	while node != null and not (node is World):
		node = node.get_parent()
	if node != null:
		return node
	return get_tree().current_scene if get_tree().current_scene != null else get_parent()


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_F8:
		apply(look + 1)
		_show()


## Says which look is on, for a moment, at the top of the screen.
func _show() -> void:
	if _label == null:
		var layer := CanvasLayer.new()
		layer.layer = 50
		add_child(layer)
		_label = Label.new()
		_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
		_label.position.y = 60.0
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_label.add_theme_font_size_override("font_size", 22)
		_label.add_theme_color_override("font_outline_color", Color.BLACK)
		_label.add_theme_constant_override("outline_size", 6)
		layer.add_child(_label)
	_label.text = "Look %d/%d: %s" % [look + 1, LOOKS.size(), LOOKS[look]["name"]]
	_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_label.visible = true
	_label_left = 2.5
	set_process(true)


func _process(delta: float) -> void:
	if _label == null or not _label.visible:
		set_process(false)
		return
	_label_left -= delta
	if _label_left <= 0.0:
		_label.visible = false
		set_process(false)
