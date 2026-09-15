class_name TargetMarker
extends MeshInstance3D

## The dot on whatever is being fought.
##
## A lock that does not show you what it took is a lock you have to guess at,
## and with two wolves in front of you the guess is wrong half the time. So:
## a plain disc over the target, unshaded and always facing the camera, in a
## colour nothing else in the world uses.
##
## It is a billboard rather than a ring drawn on the screen, because it has to
## sit *in* the world — over that wolf, at that height — and a screen-space
## reticle has to be told where that is every frame anyway.

## How far up the target the dot sits. Its middle, not over its head: the mark
## should be on the thing being fought.
@export var height: float = 0.85
## How big it is, in metres, and how much bigger it gets with distance so that
## it stays readable across a field. Small: it says *which*, and anything past
## the size it takes to say that is sitting on top of the thing being fought.
@export var size: float = 0.091
@export var grow_with_range: float = 0.007
## Brighter than white on purpose. Past 1 the colour runs into the glow pass, so
## the mark reads as lit rather than as a sticker.
@export var tint: Color = Color(1.35, 1.35, 1.35)
## How fast it slides onto a new target when the lock changes.
@export var settle_speed: float = 18.0
## How fast it spins, in turns per second. A plain dot has nothing to show for
## spinning, so this is off unless the mark is given a shape again.
@export var spin: float = 0.0

var _target: Node3D
var _camera: Camera3D
var _material: StandardMaterial3D


func _ready() -> void:
	top_level = true
	visible = false
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var disc := QuadMesh.new()
	disc.size = Vector2.ONE
	mesh = disc

	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	# Drawn over whatever it is marking: a dot hidden behind the wolf it is on
	# would be worse than no dot at all.
	_material.no_depth_test = true
	_material.albedo_color = tint
	_material.albedo_texture = _pip()
	_material.render_priority = 1
	material_override = _material


## The mark itself: one dot, drawn here rather than imported.
##
## A hard core with a halo fading out around it, so it reads as something giving
## off light rather than as a circle stuck to the screen. The falloff is most of
## that — an edge that simply stops looks like a sticker.
static func _pip() -> ImageTexture:
	const SIDE := 64
	var image := Image.create(SIDE, SIDE, false, Image.FORMAT_RGBA8)
	image.fill(Color(1.0, 1.0, 1.0, 0.0))
	var middle := (SIDE - 1) * 0.5
	for y in SIDE:
		for x in SIDE:
			var out := Vector2(x - middle, y - middle).length() / middle
			var core := 1.0 - smoothstep(0.22, 0.30, out)
			# Faint, and not far: a halo that reaches the edge of the quad puts a
			# white wash over the very thing the mark is meant to point at.
			var halo := (1.0 - smoothstep(0.26, 0.62, out)) * 0.18
			var ink := clampf(core + halo, 0.0, 1.0)
			if ink > 0.0:
				image.set_pixel(x, y, Color(1.0, 1.0, 1.0, ink))
	return ImageTexture.create_from_image(image)


## Marks `who`, or nothing at all. The camera is needed for the sizing, which is
## the one thing that cannot be worked out from the target alone.
func mark(who: Node3D, camera: Camera3D) -> void:
	_camera = camera
	if who == _target:
		return
	_target = who
	if _target != null and _camera != null:
		# Straight onto a new target rather than sliding across the field from
		# the old one: the point of it is saying *which*, immediately.
		global_position = _over(_target)


func _process(delta: float) -> void:
	if _target == null or not is_instance_valid(_target) or _camera == null:
		visible = false
		return

	visible = true
	var wanted := _over(_target)
	global_position = global_position.lerp(wanted, 1.0 - exp(-settle_speed * delta))
	if spin != 0.0:
		rotate_object_local(Vector3.FORWARD, TAU * spin * delta)

	var range_to := _camera.global_position.distance_to(global_position)
	var across := size + grow_with_range * range_to
	scale = Vector3(across, across, across)


func _over(who: Node3D) -> Vector3:
	return who.global_position + Vector3.UP * height
