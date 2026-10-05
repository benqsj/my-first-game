class_name AmiraniChains
extends Node3D
## Amirani's chains (2026-10-05, the user's word): an iron manacle on each
## wrist, the right one's chain hanging to the rock of the mountain he was
## chained to, the left one's broken short. Seen only — the chain is not yet a
## weapon.
##
## Worn on the maker's figure the rig shows (`SkinnedRig._figure_skel`): each
## manacle sits on the forearm, 78% of the way from the elbow to the wrist,
## and each chain is a rope of points (Verlet) hung from it, pulled down and
## held to its length, kept above the ground he stands on. The links are laid
## between its points, every other one turned a quarter about the chain, as
## vepxis-art _amirani/amirani_lp3.py drew them in Blender.

## How far along the forearm the manacle sits, elbow to wrist.
const ON_FOREARM := 0.78
## The chain's links: how many, and how far apart (metres, before the rig's
## scale).
const LONG_LINKS := 14
const SHORT_LINKS := 4
const PITCH := 0.065
const GRAVITY := 9.8
## How much of its speed a point keeps from one step to the next.
const KEEP := 0.985
const ITERATIONS := 8
const ROCK_RADIUS := 0.16

var _iron: StandardMaterial3D
var _bronze: StandardMaterial3D
var _stone: StandardMaterial3D
var _link: TorusMesh
var _manacles: Dictionary = {}
## Per chain: {"side", "points", "last", "links": [MeshInstance3D], "rock"}.
var _chains: Array[Dictionary] = []
var _built := false


func _ready() -> void:
	_iron = StandardMaterial3D.new()
	_iron.albedo_color = Color(0.07, 0.07, 0.075)
	_iron.metallic = 0.85
	_iron.roughness = 0.5
	_bronze = StandardMaterial3D.new()
	_bronze.albedo_color = Color(0.55, 0.33, 0.12)
	_bronze.metallic = 1.0
	_bronze.roughness = 0.4
	_stone = StandardMaterial3D.new()
	_stone.albedo_color = Color(0.3, 0.28, 0.26)
	_stone.roughness = 0.95
	_link = TorusMesh.new()
	_link.inner_radius = 0.023
	_link.outer_radius = 0.045
	_link.rings = 10
	_link.ring_segments = 5
	_link.material = _iron


func _skel() -> Skeleton3D:
	var rig := get_parent()
	if rig == null:
		return null
	var skel: Variant = rig.get(&"_figure_skel")
	return skel as Skeleton3D if skel is Skeleton3D and is_instance_valid(skel) else null


func _build(scale_by: float) -> void:
	_built = true
	for side in ["L", "R"]:
		var ring := MeshInstance3D.new()
		var band := TorusMesh.new()
		band.inner_radius = 0.058
		band.outer_radius = 0.092
		band.rings = 14
		band.ring_segments = 6
		band.material = _iron
		ring.mesh = band
		ring.top_level = true
		add_child(ring)
		var rims: Array[MeshInstance3D] = []
		for k in 2:
			var rim := MeshInstance3D.new()
			var thin := TorusMesh.new()
			thin.inner_radius = 0.084
			thin.outer_radius = 0.097
			thin.rings = 14
			thin.ring_segments = 4
			thin.material = _bronze
			rim.mesh = thin
			rim.top_level = true
			add_child(rim)
			rims.append(rim)
		_manacles[side] = {"ring": ring, "rims": rims}
	for spec: Array in [["R", LONG_LINKS, true], ["L", SHORT_LINKS, false]]:
		var links: Array[MeshInstance3D] = []
		for i in int(spec[1]):
			var link := MeshInstance3D.new()
			link.mesh = _link
			link.top_level = true
			add_child(link)
			links.append(link)
		var rock: MeshInstance3D = null
		if spec[2]:
			rock = MeshInstance3D.new()
			var ball := SphereMesh.new()
			ball.radius = ROCK_RADIUS
			ball.height = ROCK_RADIUS * 1.7
			ball.radial_segments = 7
			ball.rings = 4
			ball.material = _stone
			rock.mesh = ball
			rock.top_level = true
			add_child(rock)
		_chains.append({"side": spec[0], "points": PackedVector3Array(), "last": PackedVector3Array(),
				"links": links, "rock": rock, "pitch": PITCH * scale_by})


func _process(delta: float) -> void:
	var skel := _skel()
	var on := skel != null and skel.is_visible_in_tree()
	for child in get_children():
		(child as Node3D).visible = on
	if not on:
		return
	var scale_by := (get_parent() as Node3D).global_basis.get_scale().y
	if not _built:
		_build(scale_by)
	var floor_y := (get_parent() as Node3D).global_position.y + 0.02
	var anchors := {}
	for side in ["L", "R"]:
		var elbow := skel.find_bone(side + "_elbow_joint")
		var wrist := skel.find_bone(side + "_wrist_joint")
		if elbow < 0 or wrist < 0:
			continue
		var e := skel.global_transform * skel.get_bone_global_pose(elbow).origin
		var w := skel.global_transform * skel.get_bone_global_pose(wrist).origin
		var along := (w - e).normalized()
		var at := e.lerp(w, ON_FOREARM)
		var basis := _basis_about(along).scaled_local(Vector3(1.0, 2.4, 1.0)).scaled(Vector3.ONE * scale_by)
		var m: Dictionary = _manacles[side]
		(m["ring"] as Node3D).global_transform = Transform3D(basis, at)
		var rims: Array = m["rims"]
		for k in rims.size():
			var off := along * (0.055 if k == 0 else -0.055) * scale_by
			(rims[k] as Node3D).global_transform = Transform3D(_basis_about(along).scaled(Vector3.ONE * scale_by), at + off)
		# the chain hangs from the manacle's underside
		anchors[side] = at + Vector3.DOWN * 0.07 * scale_by
	var dt := clampf(delta, 0.0, 1.0 / 30.0)
	for chain in _chains:
		if not anchors.has(chain["side"]):
			continue
		_hang(chain, anchors[chain["side"]], dt, floor_y)
		_lay(chain, scale_by)


## A frame of the rope: each point carried on by its own last move and pulled
## down, then held to its neighbours' distance, the first to the manacle and
## every one above the ground.
func _hang(chain: Dictionary, anchor: Vector3, dt: float, floor_y: float) -> void:
	var links: Array = chain["links"]
	var n: int = links.size() + 1
	var pts: PackedVector3Array = chain["points"]
	var last: PackedVector3Array = chain["last"]
	var pitch: float = chain["pitch"]
	if pts.size() != n:
		pts.resize(n)
		last.resize(n)
		for i in n:
			pts[i] = anchor + Vector3.DOWN * pitch * i
			last[i] = pts[i]
	for i in range(1, n):
		var now := pts[i]
		pts[i] = now + (now - last[i]) * KEEP + Vector3.DOWN * GRAVITY * dt * dt
		last[i] = now
	for _k in ITERATIONS:
		pts[0] = anchor
		for i in n - 1:
			var d := pts[i + 1] - pts[i]
			var length := d.length()
			if length < 0.0001:
				continue
			var fix := d * (1.0 - pitch / length)
			if i == 0:
				pts[i + 1] -= fix
			else:
				pts[i] += fix * 0.5
				pts[i + 1] -= fix * 0.5
		for i in range(1, n):
			if pts[i].y < floor_y:
				pts[i].y = floor_y
	pts[0] = anchor
	chain["points"] = pts
	chain["last"] = last


func _lay(chain: Dictionary, scale_by: float) -> void:
	var pts: PackedVector3Array = chain["points"]
	var links: Array = chain["links"]
	for i in links.size():
		var a := pts[i]
		var b := pts[i + 1]
		var t := b - a
		if t.length() < 0.0001:
			t = Vector3.DOWN
		t = t.normalized()
		(links[i] as Node3D).global_transform = Transform3D(_link_basis(t, i).scaled(Vector3.ONE * scale_by), (a + b) * 0.5)
	var rock := chain["rock"] as MeshInstance3D
	if rock != null:
		var end := pts[pts.size() - 1]
		var down := (pts[pts.size() - 1] - pts[pts.size() - 2]).normalized()
		rock.global_transform = Transform3D(Basis.IDENTITY.scaled(Vector3(1.0, 1.0, 1.15) * scale_by),
				end + down * ROCK_RADIUS * 0.8 * scale_by)


## A basis whose Y is `axis` (a torus' hole along it).
func _basis_about(axis: Vector3) -> Basis:
	var y := axis.normalized()
	var ref := Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT
	var x := ref.cross(y).normalized()
	var z := x.cross(y).normalized()
	return Basis(x, y, z)


## A link along `t`: its ring's plane holds `t` (the hole across it), stretched
## along `t`, every other one a quarter turn about it.
func _link_basis(t: Vector3, i: int) -> Basis:
	var ref := Vector3.UP if absf(t.dot(Vector3.UP)) < 0.9 else Vector3.RIGHT
	var hole := t.cross(ref).normalized()
	if i % 2 == 1:
		hole = hole.rotated(t, PI * 0.5)
	var third := t.cross(hole).normalized()
	# X along the chain (stretched), Y the hole, Z the ring's other way
	return Basis(t * 1.45, hole, third)
