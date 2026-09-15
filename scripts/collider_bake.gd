class_name ColliderBake
extends Resource

## Convex hulls for one imported model, worked out once and kept.
##
## Building a hull from a six-thousand-triangle mesh takes QuickHull the better
## part of a second, and there are forty-five of them between the house and the
## cart. That is a second of load time to compute something that cannot change
## unless the model does — so it is computed by [code]tools/bake_colliders.gd[/code]
## and read back from here, which costs nothing.
##
## Points rather than shapes, because a `ConvexPolygonShape3D` is exactly its
## points and a `.tres` full of them stays readable and diffable.

## Node paths, relative to the [SimpleCollision] the bake is attached to, and the
## hull for each. Two arrays rather than a dictionary so the resource saves as
## something a person can look at.
@export var paths: PackedStringArray = PackedStringArray()
@export var hulls: Array[PackedVector3Array] = []
## What the bake was made from. If the model is re-exported with a different
## number of colliders, the bake is stale and the fallback takes over rather
## than half the house losing its walls.
@export var source: String = ""


func hull_for(path: String) -> PackedVector3Array:
	var at := paths.find(path)
	return hulls[at] if at >= 0 and at < hulls.size() else PackedVector3Array()
