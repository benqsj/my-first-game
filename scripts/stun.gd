class_name Stun
extends Node3D

## A creature stunned (the Stunning Arrow, [method Player.arrow_stun]): it
## reels where it stands by its own reel (`react(&"stun")`, host side), and on
## every peer a ring of small stars goes round over its head for as long as
## that lasts — the old sign of a head that is spinning.

## How long a stun holds a creature (the user's word, 2026-10-05: 2 s).
const TIME := 2.0
## The stunning shot's colour: its charge, its streak, its stars.
const GOLD := Color(1.0, 0.84, 0.3)
const STARS := 4
const RING := 0.32
const TURN := 2.2
const STAR_SIZE := 0.12

var _creature: Node3D
var _left: float = 0.0
var _age: float = 0.0
var _stars: Array[MeshInstance3D] = []
var _material: StandardMaterial3D
static var _star_tex: ImageTexture


## Puts the stars over `creature` for `seconds` (again over the old ones: the
## time is only ever lengthened).
static func show_over(creature: Node3D, seconds: float) -> void:
	if creature == null or not creature.is_inside_tree():
		return
	var held := creature.get_node_or_null(^"StunStars") as Stun
	if held != null:
		held._left = maxf(held._left, seconds)
		return
	var ring := Stun.new()
	ring.name = "StunStars"
	ring._creature = creature
	ring._left = seconds
	creature.add_child(ring)


func _ready() -> void:
	top_level = true
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_material.billboard_keep_scale = true
	_material.albedo_texture = _star()
	_material.albedo_color = Color(1.0, 0.86, 0.3)
	_material.no_depth_test = true
	_material.render_priority = 2
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * STAR_SIZE
	for k in STARS:
		var star := MeshInstance3D.new()
		star.mesh = quad
		star.material_override = _material
		star.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(star)
		_stars.append(star)
	_place(0.0)


func _process(delta: float) -> void:
	_age += delta
	_left -= delta
	if _left <= 0.0 or _creature == null or not is_instance_valid(_creature) \
			or _creature.get(&"is_dead") == true:
		queue_free()
		return
	_place(delta)


func _place(_delta: float) -> void:
	if _creature == null or not is_instance_valid(_creature):
		return
	var over := _head_top()
	global_position = over
	var fade := clampf(_left / 0.25, 0.0, 1.0) * clampf(_age / 0.12, 0.0, 1.0)
	_material.albedo_color.a = fade
	for k in _stars.size():
		var a := _age * TAU / TURN + TAU * k / _stars.size()
		var star := _stars[k]
		star.position = Vector3(cos(a) * RING, sin(a * 2.0 + k) * 0.03, sin(a) * RING)
		var s := 0.8 + 0.25 * sin(_age * 9.0 + k * 1.7)
		star.scale = Vector3.ONE * s


## A little over the head: the lock's head point ([TargetPoints]) lifted a
## hand, or over the middle of something small.
func _head_top() -> Vector3:
	var points := TargetPoints.of(_creature)
	var top: Vector3 = points[points.size() - 1]
	var lift := 0.35 if points.size() == 3 else 0.9
	return top + Vector3.UP * lift


## A five-pointed star, drawn here: a soft-edged bright shape.
static func _star() -> ImageTexture:
	if _star_tex != null:
		return _star_tex
	const SIDE := 64
	var image := Image.create(SIDE, SIDE, false, Image.FORMAT_RGBA8)
	image.fill(Color(1, 1, 1, 0))
	var mid := (SIDE - 1) * 0.5
	for y in SIDE:
		for x in SIDE:
			var v := Vector2(x - mid, mid - y) / mid
			var r := v.length()
			var a := atan2(v.x, v.y)
			# the star's edge: between 0.42 and 0.95 of the way out, five times round
			var edge := lerpf(0.42, 0.95, pow(absf(cos(a * 2.5)), 3.0))
			var ink := 1.0 - smoothstep(edge - 0.06, edge + 0.02, r)
			if ink > 0.0:
				image.set_pixel(x, y, Color(1, 1, 1, ink))
	_star_tex = ImageTexture.create_from_image(image)
	return _star_tex
