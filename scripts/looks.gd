class_name Looks
extends Node

## The world's looks, side by side: **F8** steps through them in play, to see
## what each one looks like and what it costs on this machine.
##
## A look is a ground and a grass:
##
## 0. **new** (the default) — the forest-floor ground ([code]terrain_forest.gdshader[/code]):
##    fallen leaves and moss under the trees, grassy earth under the meadows,
##    bare earth with sprigs and leaves in the open, blended by height; the
##    light grass clump (364 triangles, opaque); and a low sward filling the
##    meadows ([member Meadows.sward]): short clumps of 180 triangles in mixed
##    greens, yellow-green, straw and the odd dead blade, six round every
##    meadow clump, drawn to 30% of the grass's distance.
## 1. **old** — the house ground and the full grass clump (8 256 triangles).
##    What the game looked like before any of this.
## 2. **old ground, light grass** — only the grass changed, to see that alone.
## 3. **photo** — the photographed ground (`Terrain.styles[1]`) with the light
##    grass.
## 4. **new ground, gras2** — the forest floor with the user's own clump from
##    `assets/grass2/gras2.glb` (6 672 triangles, alpha-dithered): to judge it
##    against the light one.
##
## Since 2026-10-06 (the user's word) only two are stepped through: the new
## one above (0) and **elden dark** (1, below). **elden** (its gold
## grade, kept in `GRADES`) is off F8: too colourful — the same ground and grass in Elden Ring's
## Limgrave colours: gold and ochre grass, olive-gold leaves, dry grey-brown
## earth, a warm golden haze, a low amber sun and a pale gold horizon. The
## old looks (1–4 above) are no longer on F8.
##
## `-- look_1` (or any number) starts in that look.
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
## The dark grade ([method _grade]): an overcast, heavier light — lower sun and
## sky, a thicker grey haze, contrast up and colour drained, the wood's greens
## taken down — for a brutal fight rather than a fairy tale (the user's words:
## Lineage 2 with Elden Ring). Property -> value, on the environment, the sky,
## the sun. This is the grade on Medium and High (the user's pick, seen on
## those: the later, lighter one below had been judged on Low). Its shadows
## and blacks lifted a touch after (more ambient, softer shadows, a little less
## contrast): "a little lighter, the shadows and the black most of all".
## The fog thickened (0.0042 -> 0.0052, Low's 0.0032 -> 0.0058) when the
## world stopped being drawn past [constant Graphics.REACH]: it is what hides
## where the drawing stops.
const DARK_ENV := {
	"tonemap_mode": Environment.TONE_MAPPER_ACES,
	"tonemap_exposure": 1.0,
	"ambient_light_color": Color(0.45, 0.5, 0.52),
	"ambient_light_energy": 2.25,
	"fog_light_color": Color(0.4, 0.42, 0.43),
	"fog_density": 0.0052,
	"fog_aerial_perspective": 0.6,
	"fog_sun_scatter": 0.08,
	"adjustment_enabled": true,
	"adjustment_brightness": 1.04,
	"adjustment_contrast": 1.06,
	"adjustment_saturation": 0.74,
}
const DARK_SKY := {
	"sky_top_color": Color(0.21, 0.26, 0.33),
	"sky_horizon_color": Color(0.46, 0.47, 0.47),
	"ground_bottom_color": Color(0.11, 0.11, 0.1),
	"ground_horizon_color": Color(0.46, 0.47, 0.47),
}
const DARK_SUN := {
	"light_energy": 1.05,
	"light_color": Color(1.0, 0.9, 0.78),
	"shadow_opacity": 0.64,
}
## How much of their colour the wood's leaves and bark keep in the dark grade.
const DARK_WOOD := Color(0.82, 0.86, 0.78)

## The same grade on Low. Low has no ambient occlusion or glow and blurs
## its textures, and the grade above went murky there: lighter (AgX, which
## keeps the shadows open; more exposure and ambient; softer shadows) and less
## green instead of darker — the leaves (not the bark, which is lifted), the
## grass and the grassy ground taken to a deep olive.
const LOW_ENV := {
	"tonemap_mode": Environment.TONE_MAPPER_AGX,
	"tonemap_exposure": 1.2,
	"ambient_light_color": Color(0.45, 0.5, 0.52),
	"ambient_light_energy": 2.7,
	"fog_light_color": Color(0.4, 0.42, 0.43),
	"fog_density": 0.0058,
	"fog_aerial_perspective": 0.6,
	"fog_sun_scatter": 0.08,
	"ssao_intensity": 0.55,
	"adjustment_enabled": true,
	"adjustment_brightness": 1.17,
	"adjustment_contrast": 1.07,
	"adjustment_saturation": 0.86,
}
const LOW_SUN := {
	"light_energy": 1.2,
	"light_color": Color(1.0, 0.9, 0.78),
	"shadow_opacity": 0.5,
}
const LOW_WOOD := Color(0.8, 0.68, 0.62)
const LOW_GRASS := Color(0.86, 0.72, 0.64)
const LOW_BARK := Color(1.45, 1.4, 1.35)
const LOW_GROUND_GRASS := Color(0.7, 0.66, 0.5)
## Elden Ring's Limgrave: a warm golden haze and an amber sun, a pale gold
## horizon under a grey-blue sky, colour a little drained and contrast up.
const ELDEN_ENV := {
	"tonemap_mode": Environment.TONE_MAPPER_ACES,
	"tonemap_exposure": 1.06,
	"ambient_light_color": Color(0.62, 0.57, 0.46),
	"ambient_light_energy": 2.0,
	"fog_light_color": Color(0.76, 0.67, 0.48),
	"fog_density": 0.0062,
	"fog_aerial_perspective": 0.72,
	"fog_sun_scatter": 0.28,
	"adjustment_enabled": true,
	"adjustment_brightness": 1.02,
	"adjustment_contrast": 1.1,
	"adjustment_saturation": 0.8,
}
const ELDEN_SKY := {
	"sky_top_color": Color(0.4, 0.45, 0.5),
	"sky_horizon_color": Color(0.86, 0.76, 0.55),
	"ground_bottom_color": Color(0.14, 0.12, 0.09),
	"ground_horizon_color": Color(0.8, 0.7, 0.5),
}
const ELDEN_SUN := {
	"light_energy": 1.35,
	"light_color": Color(1.0, 0.8, 0.52),
	"shadow_opacity": 0.72,
}
## What the leaves (olive-gold), the grass clumps (gold and ochre) are
## multiplied by.
const ELDEN_WOOD := Color(0.94, 0.8, 0.48)
const ELDEN_GRASS := Color(1.15, 0.9, 0.48)
## The forest floor's tones ([code]terrain_forest.gdshader[/code]).
const ELDEN_GROUND := {
	"tone_grass": Color(0.9, 0.78, 0.46),
	"tone_floor": Color(0.6, 0.56, 0.42),
	"tone_bare": Color(0.82, 0.74, 0.56),
	"tone_earth": Color(0.84, 0.79, 0.68),
}
## The lands' ground round the core ([code]lands_ground.gdshader[/code]).
const ELDEN_LANDS := {
	"grass_a": Color(0.34, 0.31, 0.13),
	"grass_b": Color(0.5, 0.44, 0.19),
	"grass_dry": Color(0.66, 0.55, 0.27),
	"needles": Color(0.2, 0.19, 0.11),
	"litter": Color(0.46, 0.33, 0.16),
	"heather_green": Color(0.42, 0.39, 0.2),
	"dirt": Color(0.46, 0.38, 0.26),
}
## **elden dark** (the user's word, 2026-10-06: the gold one liked, but too
## colourful): the same Limgrave, darker and more drained — an overcast gold,
## a grey-gold haze, a lower sun, olive-brown grass, darker earth.
const EDARK_ENV := {
	"tonemap_mode": Environment.TONE_MAPPER_ACES,
	"tonemap_exposure": 0.98,
	"ambient_light_color": Color(0.5, 0.49, 0.43),
	"ambient_light_energy": 1.8,
	"fog_light_color": Color(0.52, 0.49, 0.4),
	"fog_density": 0.0066,
	"fog_aerial_perspective": 0.7,
	"fog_sun_scatter": 0.14,
	"adjustment_enabled": true,
	"adjustment_brightness": 0.98,
	"adjustment_contrast": 1.12,
	"adjustment_saturation": 0.66,
}
const EDARK_SKY := {
	"sky_top_color": Color(0.27, 0.3, 0.34),
	"sky_horizon_color": Color(0.6, 0.56, 0.45),
	"ground_bottom_color": Color(0.1, 0.09, 0.07),
	"ground_horizon_color": Color(0.56, 0.52, 0.42),
}
const EDARK_SUN := {
	"light_energy": 1.05,
	"light_color": Color(0.96, 0.82, 0.6),
	"shadow_opacity": 0.7,
}
const EDARK_WOOD := Color(0.74, 0.7, 0.5)
const EDARK_GRASS := Color(0.86, 0.74, 0.46)
const EDARK_GROUND := {
	"tone_grass": Color(0.68, 0.61, 0.4),
	"tone_floor": Color(0.48, 0.46, 0.36),
	"tone_bare": Color(0.64, 0.59, 0.46),
	"tone_earth": Color(0.68, 0.65, 0.58),
}
const EDARK_LANDS := {
	"grass_a": Color(0.25, 0.24, 0.12),
	"grass_b": Color(0.36, 0.33, 0.16),
	"grass_dry": Color(0.48, 0.42, 0.24),
	"needles": Color(0.15, 0.15, 0.1),
	"litter": Color(0.34, 0.26, 0.15),
	"heather_green": Color(0.31, 0.3, 0.17),
	"dirt": Color(0.36, 0.31, 0.23),
}
## The grades a look may wear, by name: light, sky, sun, the wood's and the
## grass's tone, and the grounds' colours.
const GRADES := {
	"elden": {"env": ELDEN_ENV, "sky": ELDEN_SKY, "sun": ELDEN_SUN, "wood": ELDEN_WOOD,
			"grass": ELDEN_GRASS, "ground": ELDEN_GROUND, "lands": ELDEN_LANDS},
	"elden_dark": {"env": EDARK_ENV, "sky": EDARK_SKY, "sun": EDARK_SUN, "wood": EDARK_WOOD,
			"grass": EDARK_GRASS, "ground": EDARK_GROUND, "lands": EDARK_LANDS},
}
## Terrain.styles: 0 house, 1 photographed, 2 forest floor. `grade`: the light
## and colour put on ("dark", or one of `GRADES`; none for the level's own).
const LOOKS: Array[Dictionary] = [
	{"name": "new: forest floor, low sward, light grass, dark", "ground": 2, "grass": LIGHT_GRASS, "sward": true, "grade": "dark"},
	{"name": "elden dark: Limgrave overcast", "ground": 2, "grass": LIGHT_GRASS, "sward": true, "grade": "elden_dark"},
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
	# The level is built wearing the old look; whichever this is, it is put on
	# now, and again once the meadows have grown (the mask and the sward need
	# them).
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
	_grade(String(spec.get("grade", "")))


## The light the world is seen in: the dark grade, Elden Ring's, or the
## level's own (`kind` ""). The level's values are kept the first time they
## are changed, to put back.
func _grade(kind: String) -> void:
	var on := kind != ""
	var g: Dictionary = GRADES.get(kind, {})
	var styled := not g.is_empty()
	# Which of the two dark grades: Low's own, or the one for Medium and High.
	var low := kind == "dark" and Graphics.current == Graphics.Level.LOW
	var world := _world()
	for node in world.find_children("*", "WorldEnvironment", true, false):
		var env := (node as WorldEnvironment).environment
		if env == null:
			continue
		_set_all(env, g["env"] if styled else (LOW_ENV if low else DARK_ENV), on,
				[DARK_ENV, LOW_ENV, ELDEN_ENV, EDARK_ENV])
		var sky := env.sky.sky_material if env.sky != null else null
		if sky is ProceduralSkyMaterial:
			_set_all(sky, g["sky"] if styled else DARK_SKY, on, [DARK_SKY, ELDEN_SKY, EDARK_SKY])
	for node in world.find_children("*", "DirectionalLight3D", true, false):
		_set_all(node, g["sun"] if styled else (LOW_SUN if low else DARK_SUN), on,
				[DARK_SUN, LOW_SUN, ELDEN_SUN, EDARK_SUN])
	var forest := world.get_node_or_null("Forest")
	if forest != null:
		if low:
			_tone_wood(forest, LOW_WOOD, LOW_BARK)
		else:
			# Everything back first (Low leaves some of it alone), then toned.
			_tone_wood(forest, Color.WHITE)
			_tone_wood(forest, g["wood"] if styled else (DARK_WOOD if on else Color.WHITE))
	for node in world.find_children("*", "GrassField", true, false):
		_tone_wood(node, g["grass"] if styled else (LOW_GRASS if low else Color.WHITE))
	if _terrain != null and _terrain.styles.size() > 2:
		var ground := _terrain.styles[2] as ShaderMaterial
		if ground != null:
			var tones: Dictionary = g["ground"] if styled else ({"tone_grass": LOW_GROUND_GRASS} if low else {})
			_set_params(ground, tones)
	var lands := world.get_node_or_null("Lands")
	if lands != null and lands.get(&"_ground") is ShaderMaterial:
		_set_params(lands.get(&"_ground") as ShaderMaterial, g["lands"] if styled else {})


## A ground's shader parameters: those in `values` put on, every other one
## this has ever set put back to its own. Kept in a dictionary: unset, a
## parameter reads null, and a null meta is no meta.
func _set_params(mat: ShaderMaterial, values: Dictionary) -> void:
	if not mat.has_meta(&"looks_own"):
		mat.set_meta(&"looks_own", {})
	var own: Dictionary = mat.get_meta(&"looks_own")
	var keys: Array = ELDEN_GROUND.keys() + ELDEN_LANDS.keys()
	for key: String in keys:
		if not own.has(key):
			own[key] = mat.get_shader_parameter(key)
	for key: String in own:
		# (null puts an unset parameter back to the shader's own default)
		mat.set_shader_parameter(key, values.get(key, own[key]))


## The graphics setting changed ([Graphics.apply]): the grade follows it.
func regrade() -> void:
	_grade(String(LOOKS[look].get("grade", "")))


## `values` put on `target` (or, not `dark`, its own put back). `sets` are all
## the sets it may be given, so a property one sets and another does not goes
## back to its own when the other is worn.
func _set_all(target: Object, values: Dictionary, dark: bool, sets: Array) -> void:
	if not target.has_meta(&"looks_own"):
		target.set_meta(&"looks_own", {})
	var own: Dictionary = target.get_meta(&"looks_own")
	for set_: Dictionary in sets:
		for key: String in set_:
			if not own.has(key):
				own[key] = target.get(key)
	for set_: Dictionary in sets:
		for key: String in set_:
			target.set(key, values[key] if dark and values.has(key) else own[key])


## Every material the wood is drawn with, its colour multiplied by `tone`
## (white puts it back). Shared by every tree of a kind, so this is a few
## dozen materials, not a walk over the trees. `bark`, if given, is what the
## bark is multiplied by instead (the rest that is not foliage is left alone).
func _tone_wood(forest: Node, tone: Color, bark: Color = Color(0, 0, 0, 0)) -> void:
	var seen := {}
	for node in forest.find_children("*", "GeometryInstance3D", true, false):
		var meshes: Array[Mesh] = []
		if node is MultiMeshInstance3D and (node as MultiMeshInstance3D).multimesh != null:
			meshes.append((node as MultiMeshInstance3D).multimesh.mesh)
		elif node is MeshInstance3D:
			meshes.append((node as MeshInstance3D).mesh)
		for mesh in meshes:
			if mesh == null:
				continue
			for s in mesh.get_surface_count():
				var mat := mesh.surface_get_material(s) as BaseMaterial3D
				if mat == null or seen.has(mat):
					continue
				seen[mat] = true
				if not mat.has_meta(&"looks_own"):
					mat.set_meta(&"looks_own", mat.albedo_color)
				var own: Color = mat.get_meta(&"looks_own")
				var k := tone
				if bark.a > 0.0 and not _is_leaf(mat):
					if not mat.resource_name.to_lower().contains("bark"):
						continue
					k = bark
				mat.albedo_color = Color(own.r * k.r, own.g * k.g, own.b * k.b, own.a)


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
	# No wind in it: a hand-high sward barely sways, and swaying thousands of
	# clumps a frame cost more than it showed. It still bends under a foot.
	_sward.wind_enabled = false
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
					wood[k] = minf(wood[k] + (1.0 - d * d) * 0.45, 1.0)

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

	# And the low sward out on the open ground ([member Meadows.sward]): the
	# grassy ground under it too, so a patch of it stands on grass, not earth.
	var meadows := _world().get_node_or_null("Meadows") as Meadows
	if field != null and meadows != null:
		var low := meadows.sward
		for i in range(0, low.size(), GrassField.STRIDE):
			var at := field.to_global(Vector3(low[i], 0.0, low[i + 1]))
			var c := _cell(Vector2(at.x, at.z), w, h)
			var k := c.y * w + c.x
			if k >= 0 and k < w * h:
				grass[k] = minf(grass[k] + 0.16, 1.0)

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


## Whether a material of the wood is foliage: by its name, or — for the kit's
## flat-coloured ones — by being green more than anything else.
static func _is_leaf(mat: BaseMaterial3D) -> bool:
	var name := mat.resource_name.to_lower()
	for word in ["leaf", "leav", "foliage", "needle", "bush", "canopy", "green", "grass", "moss"]:
		if name.contains(word):
			return true
	var c: Color = mat.get_meta(&"looks_own", mat.albedo_color)
	return c.g > c.r * 1.08 and c.g > c.b * 1.08
