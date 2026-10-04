class_name VillageHouses
extends Node3D

## The village's buildings: nine houses in the Kakheti way (a stone ground
## floor, plaster and timber above, a wooden balcony on the street side, red
## round-tile roofs), the marani-tavern on the square, the smithy by the east
## gate, a stone tower by the west gate, and three ruins just outside the fence.
##
## They are assembled in Blender from Quaternius' Medieval Village MegaKit
## (CC0) by `vepxis-art/village/houses/village.py`, which writes them to one
## glb — a node per building, standing on its own origin with its street side
## to -X — and, beside it, a json of what the game needs to know about each:
## its size, the boxes it collides with, where its door is, and where its
## outside stair comes down.
##
## [LAYOUT] says where each stands: the houses face the street from both
## sides, each turned a few degrees off the next so the rows do not read as
## ruled; the plan is `claude/village_reconstruction_plan.md` in the project.
##
## Colliders are boxes: one round the whole of a house (its balcony overhangs
## the ground and is not walked on; its stair is scenery), one per standing
## piece of wall in a ruin. A trimesh of the buildings themselves would cost
## the physics several milliseconds a tick ([Building] measured it).

const SCENE := "res://assets/village/houses/village_houses.glb"
const INFO := "res://assets/village/houses/village_houses.json"

## [building, x, z, yaw in degrees] — at yaw 0 the street side looks to -x;
## -90 looks south (-z), 90 north (+z).
const LAYOUT := [
	# The north row, facing south onto the street and the square.
	[&"Tower", 23.0, 62.0, -90.0],
	[&"House1", 31.0, 53.0, -84.0],
	[&"House2", 48.0, 62.0, -96.0],
	[&"Marani", 68.0, 64.0, -90.0],
	[&"House3", 87.0, 59.0, -80.0],
	[&"House4", 101.0, 62.0, -76.0],
	# The south row, facing north.
	[&"House5", 29.0, 31.0, 82.0],
	[&"House6", 45.0, 25.0, 94.0],
	[&"House7", 73.0, 25.0, 84.0],
	[&"House8", 88.0, 34.0, 98.0],
	[&"Smithy", 100.0, 40.0, 90.0],
	[&"House9", 108.0, 28.0, 102.0],
	# Ruins out past the fence.
	[&"Ruin1", 10.0, 70.0, 30.0],
	[&"Ruin2", 100.0, -1.0, -20.0],
	[&"Ruin3", 94.0, 87.0, 75.0],
]

## Beyond this a building is not drawn; the props go long before.
const REACH := 320.0

static var _info: Dictionary = {}


static func info() -> Dictionary:
	if _info.is_empty():
		var text := FileAccess.get_file_as_string(INFO)
		var parsed: Variant = JSON.parse_string(text)
		if parsed is Dictionary:
			_info = parsed
	return _info


static func dress(parent: Node3D) -> VillageHouses:
	var houses := VillageHouses.new()
	houses.name = "Houses"
	parent.add_child(houses)
	houses.build()
	return houses


## Where a building in [LAYOUT] stands: on the ground under its middle, or for a
## ruin out on the slopes, on the lowest of its corners so no wall floats.
static func placed(entry: Array) -> Transform3D:
	var at := Vector2(entry[1], entry[2])
	var turn := Basis(Vector3.UP, deg_to_rad(entry[3]))
	var y := Terrain.height(at.x, at.y)
	var data: Dictionary = info().get(String(entry[0]), {})
	if data.get("ruin", false):
		var hw: float = float(data.get("W", 6)) * 0.5
		var hd: float = float(data.get("D", 6)) * 0.5
		for c: Vector3 in [Vector3(-hw, 0, -hd), Vector3(hw, 0, -hd), Vector3(hw, 0, hd), Vector3(-hw, 0, hd)]:
			var p := turn * c
			y = minf(y, Terrain.height(at.x + p.x, at.y + p.z))
		y -= 0.08
	return Transform3D(turn, Vector3(at.x, y, at.y))


func build() -> void:
	var scene := load(SCENE) as PackedScene
	if scene == null:
		push_warning("VillageHouses: no %s" % SCENE)
		return
	var models := scene.instantiate()
	var meshes := {}
	for node in models.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		meshes[StringName(String(mi.name))] = mi.mesh
	models.free()
	var body := StaticBody3D.new()
	body.name = "HousesBody"
	body.collision_layer = 1
	body.collision_mask = 0
	body.set_meta(&"matter", &"stone")
	add_child(body)
	for entry: Array in LAYOUT:
		var kind: StringName = entry[0]
		var mesh := meshes.get(kind) as Mesh
		if mesh == null:
			push_warning("VillageHouses: no model %s" % kind)
			continue
		var xf := placed(entry)
		var node := MeshInstance3D.new()
		node.name = String(kind)
		node.mesh = mesh
		node.transform = xf
		node.visibility_range_end = REACH
		node.visibility_range_end_margin = 20.0
		add_child(node)
		var data: Dictionary = info().get(String(kind), {})
		for b: Dictionary in data.get("boxes", []):
			var size: Array = b["size"]
			var c: Array = b["c"]
			var shape := CollisionShape3D.new()
			var slab := BoxShape3D.new()
			slab.size = Vector3(size[0], size[1], size[2])
			shape.shape = slab
			shape.transform = xf * Transform3D(Basis(Vector3.UP, deg_to_rad(float(b.get("yaw", 0.0)))),
					Vector3(c[0], b["y"], c[1]))
			body.add_child(shape)


## Each house's door out on the street, [position (x, z), outward (x, z)] in the
## world: what the props at the doors are laid round.
static func doors(houses_only: bool = true) -> Array:
	var out: Array = []
	for entry: Array in LAYOUT:
		var kind := String(entry[0])
		if houses_only and not kind.begins_with("House"):
			continue
		var data: Dictionary = info().get(kind, {})
		var list: Array = data.get("doors", [])
		if list.is_empty():
			continue
		var xf := placed(entry)
		var d: Dictionary = list[0]
		var p := xf * Vector3(d["at"][0], 0.0, d["at"][1])
		var o := xf.basis * Vector3(d["out"][0], 0.0, d["out"][1])
		out.append([Vector2(p.x, p.z), Vector2(o.x, o.z).normalized()])
	return out


## Whether a point (x, z) is taken by a building — inside its walls or under
## its outside stair — with `margin` metres round it. The ground under a
## balcony is free: a bench or a barrel stands there well.
static func blocked(at: Vector2, margin: float = 0.0) -> bool:
	for entry: Array in LAYOUT:
		var data: Dictionary = info().get(String(entry[0]), {})
		if data.is_empty():
			continue
		var xf := placed(entry)
		var local := xf.affine_inverse() * Vector3(at.x, xf.origin.y, at.y)
		var hw: float = float(data["W"]) * 0.5
		var hd: float = float(data["D"]) * 0.5
		if Rect2(-hw, -hd, hw * 2.0, hd * 2.0).grow(margin).has_point(Vector2(local.x, local.z)):
			return true
		var stairs: Variant = data.get("stairs")
		if stairs is Dictionary:
			var c: Array = stairs["c"]
			var s: Array = stairs["size"]
			var r := Rect2(Vector2(c[0], c[1]) - Vector2(s[0], s[1]) * 0.5, Vector2(s[0], s[1]))
			if r.grow(margin).has_point(Vector2(local.x, local.z)):
				return true
	return false
