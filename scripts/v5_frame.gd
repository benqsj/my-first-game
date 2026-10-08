class_name V5Frame
extends Node3D

## The v5 world's frame (stage 1 of the project's world_v5_plan): what the
## ground ([Lands] reading `assets/world/v5/`) does not draw itself.
##
## * **The Black Sea.** One plane at the sea's level from a little east of the
##   coast out to the horizon, wearing the bay's water a shade bluer. The
##   ground under it is the map's sea floor, so the shallows show sand and
##   the deep goes dark; the floor holds a body back where it is deeper than a
##   wade (`block` 2 in the map).
## * **The wolves' hill**, moved as it was from behind the old village to the
##   north-east (the map's `wolves_hill`, worked out by build_v5.py from the
##   old Terrain features, Forest.GROVE and the wolves in greybox_world.tscn):
##   its giant firs and young pines, a trunk to bump into each, and its
##   sixteen wolves.
##
## Everything comes from the map's json, so building it is the same on every
## peer; the wolves get the same names everywhere.

const SEA := "res://assets/world/sea.tres"
const WOLF := "res://scenes/enemies/wolf.tscn"
const TREES := "res://assets/forest/"

## How far out the sea runs past the grid (m).
@export var sea_reach: float = 6000.0
## The Black Sea's water: bluer and clearer than the old bay's.
@export var sea_shallow := Color(0.13, 0.36, 0.42)
@export var sea_deep := Color(0.02, 0.10, 0.17)
## Whether the wolves are put on their hill (tests can leave them off).
@export var wolves: bool = true

var counts: Dictionary = {}


func _ready() -> void:
	var lands := Lands.current
	if lands == null or not is_instance_valid(lands) or lands.info.is_empty():
		push_warning("V5Frame: no lands to frame.")
		return
	var started := Time.get_ticks_usec()
	_build_sea(lands)
	var hill: Dictionary = lands.info.get("wolves_hill", {})
	_plant(hill.get("trees", []))
	if wolves:
		_raise_wolves(hill.get("wolves", []))
	print("V5Frame: %s in %.1f ms" % [counts, (Time.get_ticks_usec() - started) / 1000.0])


#region The sea
func _build_sea(lands: Lands) -> void:
	# from the coast's easternmost point (less a margin) out west to the horizon
	var east := INF
	for p: Array in lands.info.get("coast", []):
		east = minf(east, float(p[0]))
	if east == INF:
		return
	east -= 40.0
	var plane := PlaneMesh.new()
	plane.size = Vector2(sea_reach, sea_reach * 2.0)
	var mi := MeshInstance3D.new()
	mi.name = "Sea"
	mi.mesh = plane
	mi.position = Vector3(east + sea_reach * 0.5, lands.sea_level, 0.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := (load(SEA) as ShaderMaterial).duplicate() as ShaderMaterial
	mat.set_shader_parameter("shallow_color", sea_shallow)
	mat.set_shader_parameter("deep_color", sea_deep)
	mat.set_shader_parameter("murk", 3.2)
	mi.material_override = mat
	add_child(mi)
	counts["sea_from_x"] = snappedf(east, 0.1)
#endregion


#region The wolves' hill
func _plant(trees: Array) -> void:
	if trees.is_empty():
		return
	var by_kind: Dictionary = {}
	for t: Array in trees:
		var kind := String(t[0])
		if not by_kind.has(kind):
			by_kind[kind] = []
		(by_kind[kind] as Array).append(t)
	var body := StaticBody3D.new()
	body.name = "Trunks"
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	var n := 0
	for kind: String in by_kind:
		var mesh := load(TREES + kind + ".obj") as Mesh
		if mesh == null:
			push_warning("V5Frame: no %s.obj" % kind)
			continue
		var list: Array = by_kind[kind]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = list.size()
		var giant := kind.begins_with("GiantFir")
		for i in list.size():
			var t: Array = list[i]
			var x := float(t[1])
			var z := float(t[2])
			var s := float(t[3])
			var y := Terrain.height_under(x, z, 0.8) - 0.2
			var basis := Basis(Vector3.UP, deg_to_rad(float(t[4]))).scaled(Vector3.ONE * s)
			mm.set_instance_transform(i, Transform3D(basis, Vector3(x, y, z)))
			var shape := CylinderShape3D.new()
			shape.radius = (0.75 if giant else 0.3) * s
			shape.height = 6.0
			var cs := CollisionShape3D.new()
			cs.shape = shape
			cs.position = Vector3(x, y + 3.0, z)
			body.add_child(cs)
			n += 1
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Hill_" + kind
		mmi.multimesh = mm
		mmi.visibility_range_end = 520.0
		add_child(mmi)
	counts["hill_trees"] = n


func _raise_wolves(list: Array) -> void:
	var holder := get_parent().get_node_or_null(^"Enemies") as Node3D
	if holder == null:
		return
	var scene := load(WOLF) as PackedScene
	var n := 0
	for w: Array in list:
		var wolf := scene.instantiate() as Node3D
		n += 1
		wolf.name = "HillWolf%d" % n
		var x := float(w[0])
		var z := float(w[1])
		wolf.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(float(w[2]))),
				Vector3(x, Terrain.height(x, z) + 0.2, z))
		holder.add_child(wolf)
	counts["wolves"] = n
#endregion
