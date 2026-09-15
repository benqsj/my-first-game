class_name DustRing
extends MeshInstance3D

## The dirt a sword throws up when it goes into the ground.
##
## A ring lying *on* the ground rather than a billboard facing the camera: what
## a plunge displaces spreads outwards along the floor, and a disc that turns to
## face you reads as a flash instead. It grows and thins, which is what dust
## does — the far edge keeps going while the middle gives out.
##
## Deliberately dull. Nothing here goes past white or blends additively: this is
## displaced earth, and earth does not shine. The same rule the arrow's
## slipstream follows, for the same reason — a glow makes a swing read as a
## spell, and there are no spells in this.
##
## It frees itself. Nothing has to remember it exists.

## How long it lasts, in seconds.
@export var life: float = 0.55
## How wide the ring starts and ends, in metres.
@export var from_size: float = 0.5
@export var to_size: float = 2.6
## Dirt colour, and how solid it ever gets.
@export var tint: Color = Color(0.58, 0.51, 0.42)
@export_range(0.0, 1.0) var opacity: float = 0.6
## How the fade is shaped. Above one it holds and then gives out, which is dust
## hanging for a beat before it settles.
@export var falloff: float = 1.7

var _age: float = 0.0
var _material: StandardMaterial3D

## The same texture for every ring ever thrown, so it is built once.
static var _shared: ImageTexture = null


## Throws one at `where`, in `into`'s world, scaled by `size`. Hands it back in
## case the caller wants to colour it; it runs and frees itself either way.
static func burst(into: Node, where: Vector3, size: float = 1.0) -> DustRing:
	if into == null or size <= 0.0:
		return null
	var ring := DustRing.new()
	ring.from_size *= size
	ring.to_size *= size
	into.add_child(ring)
	ring.global_position = where + Vector3.UP * 0.03
	return ring


func _ready() -> void:
	top_level = true
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var disc := QuadMesh.new()
	disc.size = Vector2.ONE
	# Laid flat. A QuadMesh faces +Z, so it is tipped onto its back to lie on the
	# floor rather than standing up out of it.
	disc.orientation = PlaneMesh.FACE_Y
	mesh = disc

	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material.disable_receive_shadows = true
	_material.albedo_color = Color(tint.r, tint.g, tint.b, opacity)
	_material.albedo_texture = _cloud()
	material_override = _material
	scale = Vector3(from_size, 1.0, from_size)


func _process(delta: float) -> void:
	_age += delta
	var through := clampf(_age / maxf(life, 0.001), 0.0, 1.0)
	if through >= 1.0:
		queue_free()
		return
	var left := pow(1.0 - through, falloff)
	_material.albedo_color = Color(tint.r, tint.g, tint.b, opacity * left)
	var across := lerpf(from_size, to_size, sqrt(through))
	scale = Vector3(across, 1.0, across)


## A soft ring: nothing in the middle, thickest a little way out, fading to
## nothing at the rim. Drawn here rather than imported — it is a handful of
## maths and one less file to ship.
static func _cloud() -> ImageTexture:
	if _shared != null:
		return _shared
	const SIDE := 64
	var image := Image.create(SIDE, SIDE, false, Image.FORMAT_RGBA8)
	image.fill(Color(1.0, 1.0, 1.0, 0.0))
	var middle := (SIDE - 1) * 0.5
	for y in SIDE:
		for x in SIDE:
			var out := Vector2(x - middle, y - middle).length() / middle
			if out >= 1.0:
				continue
			# Hollow in the middle — the sword is in that hole — and gone by the
			# rim so the ring has no edge to it.
			var band := smoothstep(0.18, 0.58, out) * (1.0 - smoothstep(0.62, 1.0, out))
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, clampf(band, 0.0, 1.0)))
	_shared = ImageTexture.create_from_image(image)
	return _shared
