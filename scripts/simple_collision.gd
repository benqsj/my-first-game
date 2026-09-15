class_name SimpleCollision
extends Node3D

## Swaps an imported model's trimesh colliders for something a physics engine
## can afford to have a character walk past.
##
## Godot's GLB importer gives every mesh in a model its own `StaticBody3D` with
## a `ConcavePolygonShape3D` cut from the mesh itself. For scenery that is a
## trap: the cart in this level arrived as **two shapes holding 13,416
## triangles**, and the house as forty-three holding 31,032. Measured with the
## player walking past the house wall, the physics step cost:
##
## | | |
## | --- | --- |
## | as imported | **7.7 ms** a tick |
## | cart simplified | 3.1 ms |
## | both simplified | **0.7 ms** |
##
## Seven point seven milliseconds is half of a 60 Hz frame spent deciding
## whether a capsule has touched a cart. That is the stutter near the house, and
## it is nothing to do with the rendering: a cart does not need to be
## collided against to the nearest plank.
##
## Two ways out, per model:
##
## * `HULL` — one convex hull per mesh. Keeps the shape of a thing that has a
##   shape worth keeping (a roof slopes, and a box over it is a block the player
##   stands on top of in mid-air). Hulls are slow to *build* — a second for the
##   house — so they are baked by `tools/bake_colliders.gd` and read back from a
##   [ColliderBake].
## * `BOX` — the mesh's own bounding box. Free, instant, and right for anything
##   that is a solid lump anyway. A cart is a solid lump.
##
## The box is also the fallback whenever a bake is missing or stale, so a
## re-exported model loses accuracy rather than losing its walls.
##
## Deliberately **not** a `@tool` script. The editor would then be showing
## shapes the importer did not produce, and an editor that edits the colliders
## of an instanced sub-scene is one save away from writing them into the level.
## What the editor shows is what came in; what the game runs is this.

enum Mode {
	BOX, ## The mesh's bounding box. Free, and right for a solid obstacle.
	HULL, ## One convex hull per mesh, read from `bake`.
}

@export var mode: Mode = Mode.BOX
## The hulls, for `HULL`. Without one, boxes are used instead.
@export var bake: ColliderBake
## Turn off to measure against what the importer produced.
@export var enabled: bool = true

## How many shapes were replaced, for anything that wants to check the work.
var swapped: int = 0


func _ready() -> void:
	_simplify()


## Replaces every collision shape under this node. Safe to call twice: the
## shapes are rebuilt from the meshes each time rather than from each other.
func _simplify() -> void:
	swapped = 0
	if not enabled:
		return
	var hulls := bake if mode == Mode.HULL else null
	for body in find_children("*", "StaticBody3D", true, false):
		var mesh := _mesh_beside(body)
		if mesh == null:
			continue
		for node in body.find_children("*", "CollisionShape3D", true, false):
			var shape := node as CollisionShape3D
			var points := hulls.hull_for(String(get_path_to(shape))) \
					if hulls != null else PackedVector3Array()
			if points.size() >= 4:
				var hull := ConvexPolygonShape3D.new()
				hull.points = points
				shape.shape = hull
			else:
				# No bake, or one that no longer matches the model. A box is
				# wrong in detail and right in kind, which is the better way to
				# be wrong about a wall.
				var box := BoxShape3D.new()
				var bounds := mesh.get_aabb()
				box.size = bounds.size.maxf(0.01)
				shape.shape = box
				shape.position = bounds.get_center()
			swapped += 1


## The mesh a generated collider was cut from. The importer hangs the body off
## the `MeshInstance3D` itself, but a model that has been re-parented in Blender
## can put the two side by side instead.
static func _mesh_beside(body: Node) -> Mesh:
	var parent := body.get_parent()
	if parent == null:
		return null
	if parent is MeshInstance3D:
		return (parent as MeshInstance3D).mesh
	for sibling in parent.get_children():
		if sibling is MeshInstance3D:
			return (sibling as MeshInstance3D).mesh
	return null
