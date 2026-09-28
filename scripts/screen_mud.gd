class_name ScreenMud
extends CanvasLayer

## Mud over the eyes: brown splats over the screen of the hero a puglin's mud
## hit — one big slap and a spray round it, ragged, thick and wet in the middle,
## runs dripping from them, drops thrown off — that hold a moment and then thin
## away. Only on the screen of the one it hit (the host tells that peer,
## [method Puglin.net_mudded]).
##
## **Cheap to show.** Every splat is a picture made once (`_bake`, a handful of
## shapes) and laid on the screen as a plain textured rectangle, faded by its
## colour. It used to be one full-screen shader working out every splat's rim,
## runs and grain for every pixel, and blurring the view under it, every frame
## — which at a Retina screen's size cost frames for as long as the mud was on.

## Over the world and under everything drawn on top of it: the bars (4), the
## bag (6), the pause menu and its settings (10).
const LAYER := 3
const MOST := 16
const HOLD := 2.6
const FADE := 4.0
const SHAPES := 8
const SIZE := Vector2i(160, 224)

static var _shapes: Array[ImageTexture] = []
static var _film_tex: ImageTexture
static var _pending: ScreenMud

## Each: [TextureRect, centre (0–1 of the screen), radius (of its height), age].
var _splats: Array = []
var _film: TextureRect
var _root: Control


static func splat(tree: SceneTree, amount: float = 1.0) -> void:
	_here(tree)._add(amount)


static func _here(tree: SceneTree) -> ScreenMud:
	var here := tree.root.get_node_or_null("ScreenMud") as ScreenMud
	if here == null and _pending != null and is_instance_valid(_pending):
		return _pending
	if here == null:
		here = ScreenMud.new()
		here.name = "ScreenMud"
		# Called from inside a level's setting up (the warm-up) the root will not
		# take a child yet; it is put there a moment later, whole.
		_pending = here
		tree.root.add_child.call_deferred(here)
	return here


## Makes the pictures now (the level's warm-up calls it, behind its black).
static func prepare(tree: SceneTree) -> void:
	_bake()
	_here(tree)


## Clears it at once (the warm-up's splat, or a new level).
static func clear(tree: SceneTree) -> void:
	var here := tree.root.get_node_or_null("ScreenMud") as ScreenMud
	if here == null and _pending != null and is_instance_valid(_pending):
		here = _pending
	if here != null:
		for s: Array in here._splats:
			(s[0] as Node).queue_free()
		here._splats.clear()


## How much of the screen is under mud now, roughly (0–1): for tests.
static func cover(tree: SceneTree) -> float:
	var here := tree.root.get_node_or_null("ScreenMud") as ScreenMud
	if here == null:
		return 0.0
	var total := 0.0
	for s: Array in here._splats:
		total += PI * pow(float(s[2]), 2.0) * here._strength(float(s[3])) * 0.8
	return clampf(total, 0.0, 1.0)


func _init() -> void:
	layer = LAYER
	_bake()
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_film = TextureRect.new()
	_film.texture = _film_tex
	_film.set_anchors_preset(Control.PRESET_FULL_RECT)
	_film.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_film.stretch_mode = TextureRect.STRETCH_SCALE
	_film.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_film.modulate.a = 0.0
	_root.add_child(_film)


func _add(amount: float) -> void:
	# One big slap where it hit, the rest thrown round it, some off the edges.
	var middle := Vector2(randf_range(0.38, 0.62), randf_range(0.32, 0.58))
	_put(middle, randf_range(0.26, 0.34) * amount)
	for i in int(round(6.0 + 3.0 * amount)):
		_put(middle + Vector2(randf_range(-0.45, 0.45), randf_range(-0.35, 0.35)), randf_range(0.09, 0.22) * amount)
	while _splats.size() > MOST:
		((_splats.pop_front() as Array)[0] as Node).queue_free()


func _put(at: Vector2, radius: float) -> void:
	var rect := TextureRect.new()
	rect.texture = _shapes[randi() % _shapes.size()]
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.flip_h = randf() < 0.5
	_root.add_child(rect)
	_splats.append([rect, at, radius, 0.0])


func _strength(age: float) -> float:
	return 1.0 if age < HOLD else clampf(1.0 - (age - HOLD) / FADE, 0.0, 1.0)


func _ready() -> void:
	if _pending == self:
		_pending = null


func _process(delta: float) -> void:
	var screen := get_viewport().get_visible_rect().size
	var film := 0.0
	var alive: Array = []
	for s: Array in _splats:
		s[3] = float(s[3]) + delta
		# It slides a little as it runs.
		s[1] = (s[1] as Vector2) + Vector2(0.0, 0.004 * delta)
		var rect := s[0] as TextureRect
		if float(s[3]) >= HOLD + FADE:
			rect.queue_free()
			continue
		alive.append(s)
		var strength := _strength(float(s[3]))
		film = maxf(film, strength)
		# The picture is a splat of radius 1/4 of its width, its runs below.
		var r := float(s[2]) * screen.y
		var w := r * 4.0
		var h := w * float(SIZE.y) / float(SIZE.x)
		var c: Vector2 = (s[1] as Vector2) * screen
		rect.position = Vector2(c.x - w * 0.5, c.y - w * 0.5)
		rect.size = Vector2(w, h)
		rect.modulate.a = strength
	_splats = alive
	_film.modulate.a = film * 0.3
	visible = not _splats.is_empty()


## The splat pictures and the film, made once: a ragged, lobed blot from a
## noise round its rim, darker and thicker in the middle with a wet sheen, two
## or three runs hanging from its lower edge, and a ring of round drops.
static func _bake() -> void:
	if not _shapes.is_empty():
		return
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.03
	noise.fractal_octaves = 3
	var grain := FastNoiseLite.new()
	grain.frequency = 0.12
	for k in SHAPES:
		noise.seed = 17 + k * 31
		grain.seed = 5 + k * 13
		var img := Image.create(SIZE.x, SIZE.y, false, Image.FORMAT_RGBA8)
		var c := Vector2(SIZE.x * 0.5, SIZE.x * 0.5)
		var r := SIZE.x * 0.25
		var runs: Array = []
		for j in 1 + k % 2:
			runs.append([randf_range(-0.6, 0.6) * r, randf_range(0.9, 1.9) * r, randf_range(0.09, 0.15) * r])
		var drops: Array = []
		for j in 6:
			var ang := randf() * TAU
			drops.append([c + Vector2(cos(ang), sin(ang)) * r * randf_range(1.2, 1.9), randf_range(0.06, 0.13) * r])
		for y in SIZE.y:
			for x in SIZE.x:
				var p := Vector2(x, y)
				var d := p - c
				var ang := atan2(d.y, d.x)
				# Broad lobes round it, and a little ragged grain on the edge.
				var rim := r * (0.95 + 0.28 * noise.get_noise_2d(cos(ang) * 9.0, sin(ang) * 9.0)
						+ 0.05 * grain.get_noise_2d(x * 1.5, y * 1.5))
				var dist := d.length()
				var body := 1.0 - smoothstep(rim * 0.9, rim, dist)
				var run := 0.0
				for rn: Array in runs:
					var dx := absf(d.x - float(rn[0]))
					var down := d.y
					if down > 0.0 and down < float(rn[1]):
						var width := float(rn[2]) * (1.0 - down / float(rn[1]) * 0.6)
						run = maxf(run, 1.0 - smoothstep(width * 0.6, width, dx))
				var drop := 0.0
				for dp: Array in drops:
					drop = maxf(drop, 1.0 - smoothstep(float(dp[1]) * 0.7, float(dp[1]), p.distance_to(dp[0])))
				var a := maxf(body, maxf(run * 0.9, drop * 0.85))
				if a <= 0.0:
					continue
				var thick := clampf(1.0 - dist / maxf(rim, 1.0), 0.0, 1.0)
				var g := grain.get_noise_2d(x, y) * 0.5 + 0.5
				var col := Color(0.09, 0.06, 0.03).lerp(Color(0.28, 0.18, 0.09), g * 0.8 + 0.1)
				# A wet sheen where it lies thick.
				var sheen := smoothstep(0.55, 0.9, thick) * smoothstep(0.55, 0.8, g)
				col = col.lerp(Color(0.5, 0.4, 0.3), sheen * 0.45)
				img.set_pixel(x, y, Color(col.r, col.g, col.b, a * 0.97))
		_shapes.append(ImageTexture.create_from_image(img))
	# The film: a dim brown grime, streaked.
	var film := Image.create(128, 72, false, Image.FORMAT_RGBA8)
	noise.seed = 99
	for y in 72:
		for x in 128:
			var n := noise.get_noise_2d(x * 2.0, y * 8.0) * 0.5 + 0.5
			film.set_pixel(x, y, Color(0.22, 0.15, 0.08, 0.35 + 0.65 * n))
	_film_tex = ImageTexture.create_from_image(film)
