class_name Horizon
extends Node3D

## Rings the map with mountains, so the world ends in a skyline instead of in a
## wall.
##
## The boundary of this level is four invisible boxes. Walk up to one in an open
## field and the illusion is over — there is nothing past it but sky. A ridge
## standing behind the wall costs almost nothing and answers the question the
## player was about to ask: the map does not end there, it just does not go any
## further.
##
## Cheap on purpose, because none of it is ever reached:
##
## * the kit's mountains are seventy-five triangles each, drawn through one
##   [MultiMeshInstance3D] per ring rather than one node per peak;
## * no collision at all — the wall is still the wall;
## * no shadows, since the sun's shadow map does not reach out this far and a
##   ridge two hundred metres off casting into it would be pure waste.
##
## Two rings, offset from one another, so the skyline has depth rather than
## reading as one cardboard cut-out with gaps in it.

const MODELS: PackedStringArray = [
	"res://assets/forest/Mountain_1.obj",
	"res://assets/forest/Mountain_2.obj",
	"res://assets/forest/Mountain_3.obj",
	"res://assets/forest/Mountain_4.obj",
]

@export var random_seed: int = 5512033
## Distance from the middle of the map to the near ring, in metres. Wants to be
## beyond the boundary wall by more than a mountain is wide, or the near faces
## poke through into the play area.
@export var inner_radius: float = 178.0
@export var outer_radius: float = 268.0
## Where the rings are centred, (x, z). The map is no longer square about the
## origin — it runs further south, into the marsh — so the ring is moved to the
## middle of what is there rather than left round the spawn.
@export var centre: Vector2 = Vector2.ZERO
## How much each ring is drawn out along x and z. An oblong map wants an
## oval of mountains, or the long sides run straight into them.
@export var stretch: Vector2 = Vector2.ONE
## How many peaks go round each ring. The kit's mountains are about eighty-five
## metres across, so a ring wants roughly its circumference divided by sixty.
@export var inner_count: int = 17
@export var outer_count: int = 22
@export var inner_scale: Vector2 = Vector2(0.85, 1.45)
@export var outer_scale: Vector2 = Vector2(1.6, 2.6)
## How far a peak is allowed to wander off its ring, in metres, so the skyline is
## not a circle of evenly spaced teeth.
@export var jitter: float = 26.0
## Sunk into the ground by this much, so no peak shows the flat underside its
## model was cut with.
@export var sink: float = 3.0

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = random_seed
	_ring("Near", inner_radius, inner_count, inner_scale)
	_ring("Far", outer_radius, outer_count, outer_scale)


func _ring(ring_name: String, radius: float, count: int, span: Vector2) -> void:
	# One multimesh per model, so a ring of twenty peaks is four draw calls.
	var placed: Dictionary = {}
	for i in count:
		# Spread evenly and then knocked off the mark, which reads as a range;
		# purely random angles clump and leave holes in the skyline.
		var angle := TAU * (float(i) + _rng.randf_range(-0.28, 0.28)) / float(count)
		var out := radius + _rng.randf_range(-jitter, jitter)
		var at := Vector3(centre.x + cos(angle) * out * stretch.x, -sink,
				centre.y + sin(angle) * out * stretch.y)
		var size := _rng.randf_range(span.x, span.y)
		var basis := Basis(Vector3.UP, _rng.randf() * TAU).scaled(
				Vector3(size, size * _rng.randf_range(0.75, 1.35), size))

		var pick := _rng.randi_range(0, MODELS.size() - 1)
		var list: Array = placed.get(pick, [])
		list.append(Transform3D(basis, at))
		placed[pick] = list

	var holder := Node3D.new()
	holder.name = ring_name
	add_child(holder)

	for pick: int in placed:
		var path := MODELS[pick]
		if not ResourceLoader.exists(path):
			push_warning("Horizon: '%s' is missing." % path)
			continue
		var mesh := load(path) as Mesh
		if mesh == null:
			continue
		var list: Array = placed[pick]

		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = mesh
		multi.instance_count = list.size()
		for i in list.size():
			multi.set_instance_transform(i, list[i])

		var node := MultiMeshInstance3D.new()
		node.name = path.get_file().get_basename()
		node.multimesh = multi
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# Nothing out here is ever close enough for the detail to matter, and a
		# ridge that drops to its coarsest mesh immediately is a ridge that costs
		# nothing to have.
		node.lod_bias = 0.25
		holder.add_child(node)
