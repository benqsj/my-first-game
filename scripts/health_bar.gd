class_name HealthBar
extends Node3D

## A health bar that floats over a creature's head.
##
## Two flat quads — a dark backing and a coloured fill. The fill is scaled from
## its left edge rather than its centre, which is why it is parented to an offset
## pivot: scaling a quad about its middle would shrink it inwards from both ends
## instead of draining it.
##
## **The whole bar is turned to the camera, not each quad.** Both used to be
## `BILLBOARD_ENABLED`, which is a per-mesh trick: every quad independently
## swings to face the viewer *about its own origin*. The backing's origin is the
## middle of the bar and the fill's is off to the left, so the two of them turned
## about different points and the fill slid off its backing as the viewing angle
## changed — visible as a bar that comes apart while a wolf is running at you and
## settles back when it stops. Turning the parent instead keeps the offset in a
## frame that is already square to the camera, so there is nothing to slide.

## Width of the bar in metres.
@export var width: float = 0.9
@export var height: float = 0.1
## Colour at full health, and at none.
@export var healthy: Color = Color(0.72, 0.13, 0.13)
@export var hurt: Color = Color(0.85, 0.55, 0.1)
## Hidden again once the creature has been at full health this long.
@export var hide_delay: float = 4.0

var _fill: MeshInstance3D
var _pivot: Node3D
var _fraction: float = 1.0
var _idle: float = 0.0


func _ready() -> void:
	var backing := _make_quad(Vector2(width + 0.04, height + 0.03), Color(0.05, 0.04, 0.04, 0.75))
	add_child(backing)

	_pivot = Node3D.new()
	_pivot.position = Vector3(-width * 0.5, 0.0, 0.005)
	add_child(_pivot)

	_fill = _make_quad(Vector2(width, height), healthy)
	# Offset by half its width so the pivot sits on the bar's left edge.
	_fill.position = Vector3(width * 0.5, 0.0, 0.0)
	_pivot.add_child(_fill)

	visible = false


## Shows `fraction` of the bar, 0 to 1.
func set_fraction(fraction: float) -> void:
	_fraction = clampf(fraction, 0.0, 1.0)
	_pivot.scale.x = maxf(_fraction, 0.001)
	var material := _fill.material_override as StandardMaterial3D
	material.albedo_color = hurt.lerp(healthy, _fraction)
	if _fraction < 1.0:
		visible = true
		_idle = 0.0


func _process(delta: float) -> void:
	if not visible:
		return
	_face_the_camera()
	# Fades out of the way once the creature is untouched and whole again.
	if _fraction >= 1.0:
		_idle += delta
		if _idle > hide_delay:
			visible = false


## Squares the whole bar up to whoever is looking, in one piece.
##
## A quad's front is its own +Z, and a camera's +Z points back towards the
## viewer — so taking the camera's orientation whole is what puts the bar's face
## where the eye is.
func _face_the_camera() -> void:
	var port := get_viewport()
	if port == null:
		return
	var eye := port.get_camera_3d()
	if eye != null:
		global_basis = eye.global_basis


func _make_quad(size: Vector2, colour: Color) -> MeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = size
	var node := MeshInstance3D.new()
	node.mesh = quad
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = colour
	material.no_depth_test = true
	material.render_priority = 1
	node.material_override = material
	return node
