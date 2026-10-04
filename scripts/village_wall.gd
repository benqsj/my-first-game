class_name VillageWall
extends Node3D

## The low stone wall round the village, in place of the wooden fence: a man's
## chest high, dry stone with a timber cap, the same stone as the houses'
## ground floors (a length of the Medieval Village kit's wall, two back to back
## and cut down, from `village_houses.glb`).
##
## It does not run round a rectangle. It follows the lot loosely — out a little
## to the east, in at the corners — and it is broken where the ways go through:
## the west gate (the track from the spawn), the east gate (the road into the
## lands), a gap in the south for the lane down to the vineyard and the
## windmill, and one in the north for the lane up to the wood. Each run of it
## ends on a stouter pier.
##
## Every length stands on the ground under its middle and follows it, so the
## wall rides the village's gentle roll. Drawn as one [MultiMeshInstance3D];
## collides as one thin box per length, thin enough that a hero who jumps at it
## goes over rather than standing on its top (see `fence_vault_test`).

const SCENE := "res://assets/village/houses/village_houses.glb"
const PIECE := &"WallPiece"

## The runs, (x, z) in metres; the ways in are the gaps between them.
const RUNS: Array[Array] = [
	# From the west gate south and along the south side to the vineyard lane.
	[Vector2(20, 36), Vector2(20, 10), Vector2(40, 8), Vector2(54, 7)],
	# From the vineyard lane east and up to the east gate.
	[Vector2(64, 7), Vector2(70, 7), Vector2(100, 8), Vector2(118, 14), Vector2(120, 44)],
	# From the east gate north and along the north side to the lane to the wood.
	[Vector2(120, 57), Vector2(122, 78), Vector2(100, 80), Vector2(60, 82), Vector2(47, 81.5)],
	# From the lane to the wood round to the west gate.
	[Vector2(36, 81), Vector2(30, 80), Vector2(20, 70), Vector2(20, 50)],
]

## A length of the model, and how high and thick it stands.
const LENGTH := 2.0
const HEIGHT := 1.31
const THICK := 0.58
## The collider is thinner than the stone: a hero vaults a thin top.
const BODY_THICK := 0.2
## The piers at the ends of the runs: a short length turned across, bigger.
const PIER := Vector3(0.5, 1.2, 1.7)


static func dress(parent: Node3D) -> VillageWall:
	var wall := VillageWall.new()
	wall.name = "Wall"
	parent.add_child(wall)
	wall.build()
	return wall


## Where the north side of the wall crosses a line of x, for whoever needs to
## stand someone at it.
static func north_z(x: float) -> float:
	var run: Array = RUNS[2]
	for i in run.size() - 1:
		var a: Vector2 = run[i]
		var b: Vector2 = run[i + 1]
		if (x - a.x) * (x - b.x) <= 0.0 and a.x != b.x:
			return lerpf(a.y, b.y, (x - a.x) / (b.x - a.x))
	return World.VILLAGE.end.y


## Every length of wall as a Transform3D (scaled along x to fit its segment),
## and the piers.
static func placements() -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	for run: Array in RUNS:
		for i in run.size() - 1:
			var a: Vector2 = run[i]
			var b: Vector2 = run[i + 1]
			var span := a.distance_to(b)
			var dir := (b - a) / span
			var n := maxi(1, ceili(span / LENGTH))
			var step := span / n
			var yaw := atan2(-dir.y, dir.x)
			for k in n:
				var c := a + dir * (step * (k + 0.5))
				# A hair longer than its share, so the joints close.
				var turn := Basis(Vector3.UP, yaw).scaled(Vector3(step / LENGTH * 1.02, 1.0, 1.0))
				out.append(Transform3D(turn, Vector3(c.x, Terrain.height(c.x, c.y) - 0.12, c.y)))
			# A corner where the run turns: a short length on the bisector.
			if i > 0:
				var prev: Vector2 = run[i - 1]
				var across := ((a - prev).normalized() + dir).normalized()
				var cyaw := atan2(-across.y, across.x)
				out.append(Transform3D(Basis(Vector3.UP, cyaw).scaled(Vector3(0.45, 1.0, 1.0)),
						Vector3(a.x, Terrain.height(a.x, a.y) - 0.12, a.y)))
		for end: Vector2 in [run[0], run[run.size() - 1]]:
			var other: Vector2 = run[1] if end == run[0] else run[run.size() - 2]
			var d := (other - end).normalized()
			var pyaw := atan2(-d.y, d.x)
			out.append(Transform3D(Basis(Vector3.UP, pyaw).scaled(PIER),
					Vector3(end.x, Terrain.height(end.x, end.y) - 0.12, end.y)))
	return out


func build() -> void:
	var scene := load(SCENE) as PackedScene
	if scene == null:
		return
	var models := scene.instantiate()
	var mesh: Mesh = null
	for node in models.find_children("*", "MeshInstance3D", true, false):
		if StringName(String(node.name)) == PIECE:
			mesh = (node as MeshInstance3D).mesh
	models.free()
	if mesh == null:
		push_warning("VillageWall: no %s in %s" % [PIECE, SCENE])
		return
	var where := placements()
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = where.size()
	for i in where.size():
		multi.set_instance_transform(i, where[i])
	var drawn := MultiMeshInstance3D.new()
	drawn.name = "Stones"
	drawn.multimesh = multi
	add_child(drawn)

	var body := StaticBody3D.new()
	body.name = "WallBody"
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	for xf: Transform3D in where:
		var size := xf.basis.get_scale()
		var shape := CollisionShape3D.new()
		var slab := BoxShape3D.new()
		var thick := BODY_THICK if size.z < 1.1 else THICK * size.z
		slab.size = Vector3(LENGTH * size.x, HEIGHT * size.y, thick)
		shape.shape = slab
		shape.transform = Transform3D(xf.basis.orthonormalized(), xf.origin + Vector3.UP * HEIGHT * size.y * 0.5)
		body.add_child(shape)
