class_name ScreenMud
extends CanvasLayer

## Mud over the eyes: brown splats over the screen of the hero a puglin's mud
## hit, each with a ragged edge and a run or two dripping from it, that hold a
## moment and then thin away over a few seconds. Only on the screen of the one it
## hit — the host tells that peer ([method Puglin.net_mudded]).

const MOST := 16
const SHADER := preload("res://shaders/screen_mud.gdshader")
const HOLD := 2.6
const FADE := 4.0

## Each: [centre (0–1 of the screen), radius (of its height), age, seed].
var _splats: Array = []
var _rect: ColorRect
var _mat: ShaderMaterial


static func splat(tree: SceneTree, amount: float = 1.0) -> void:
	var here := tree.root.get_node_or_null("ScreenMud") as ScreenMud
	if here == null:
		here = ScreenMud.new()
		here.name = "ScreenMud"
		tree.root.add_child(here)
	here._add(amount)


## How much of the screen is under mud now, roughly (0–1): for tests.
static func cover(tree: SceneTree) -> float:
	var here := tree.root.get_node_or_null("ScreenMud") as ScreenMud
	if here == null:
		return 0.0
	var total := 0.0
	for s: Array in here._splats:
		total += PI * pow(float(s[1]), 2.0) * here._strength(float(s[2]))
	return clampf(total, 0.0, 1.0)


## Over the world and under everything drawn on top of it: the bars (4), the
## bag (6), the pause menu and its settings (10).
const LAYER := 3


## Clears it at once (the warm-up's splat, or a new level).
static func clear(tree: SceneTree) -> void:
	var here := tree.root.get_node_or_null("ScreenMud") as ScreenMud
	if here != null:
		here._splats.clear()


func _ready() -> void:
	layer = LAYER
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_rect.material = _mat
	add_child(_rect)


func _add(amount: float) -> void:
	# One big slap where it hit, the rest thrown round it, some off the edges.
	var middle := Vector2(randf_range(0.38, 0.62), randf_range(0.32, 0.58))
	_splats.append([middle, randf_range(0.26, 0.34) * amount, 0.0, randf() * 100.0])
	var n := int(round(6.0 + 3.0 * amount))
	for i in n:
		var at := middle + Vector2(randf_range(-0.45, 0.45), randf_range(-0.35, 0.35))
		_splats.append([at, randf_range(0.09, 0.22) * amount, 0.0, randf() * 100.0])
	while _splats.size() > MOST:
		_splats.pop_front()


func _strength(age: float) -> float:
	return 1.0 if age < HOLD else clampf(1.0 - (age - HOLD) / FADE, 0.0, 1.0)


func _process(delta: float) -> void:
	var blobs := PackedVector4Array()
	var seeds := PackedFloat32Array()
	var alive: Array = []
	for s: Array in _splats:
		s[2] = float(s[2]) + delta
		# It slides a little as it runs.
		s[0] = (s[0] as Vector2) + Vector2(0.0, 0.004 * delta)
		if float(s[2]) < HOLD + FADE:
			alive.append(s)
	_splats = alive
	for s: Array in _splats:
		var c: Vector2 = s[0]
		blobs.append(Vector4(c.x, c.y, float(s[1]), _strength(float(s[2]))))
		seeds.append(float(s[3]))
	while blobs.size() < MOST:
		blobs.append(Vector4.ZERO)
		seeds.append(0.0)
	_mat.set_shader_parameter(&"blobs", blobs)
	_mat.set_shader_parameter(&"seeds", seeds)
	_mat.set_shader_parameter(&"count", _splats.size())
	# A brown film over everything while there is much of it.
	var film := 0.0
	for sp: Array in _splats:
		film = maxf(film, _strength(float(sp[2])))
	_mat.set_shader_parameter(&"film", film)
	var size := get_viewport().get_visible_rect().size
	_mat.set_shader_parameter(&"aspect", size.x / maxf(size.y, 1.0))
	_rect.visible = not _splats.is_empty()
