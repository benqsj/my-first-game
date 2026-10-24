extends SceneTree
## Every place a portal can lead to, built as F1's "Rooms" builds it, and
## looked over (the user's word, 2026-10-24: once a place is made, check it
## by itself, every time):
## - the hero stands on the floor and stays there: the walking collision is
##   where the drawn floor is (feet sank once), at the door, the middle, the
##   portals' spots and the way out;
## - nothing solid where the portals stand (±9, −l/2+10), at the way in and
##   at the way out (−l/2+15);
## - creatures called up from F1 come on the floor (not under it, not in the
##   air: the island in the sky is 160 m up), and come at him and land blows.
##   Godot --headless --path . --script res://tests/places_test.gd [-- place ...]

const WORLD_MASK := 1
## How far the drawn floor and the walked one may be apart (m).
const FEET_SINK := 0.07
const FEET_FLOAT := 0.18
## The room kept clear round a portal's spot, the door and the way out.
const CLEAR_R := 1.1
const CLEAR_H := 2.4
## How long the creatures have to land a blow (physics seconds).
const BLOW_WAIT := 22.0
const ABOVE := 0.6
## The places no portal leads to any more (the user's word, 2026-10-23: the
## court, the cave and the broken hall gone from the run): looked over only
## when named.
const UNUSED := ["court", "great_hall", "cave"]

var _failures := 0
var _tri: Dictionary = {}
var _struck := 0
var _drawn_name := ""


func _check(what: String, ok: bool, detail: String = "") -> void:
	print("  %s - %s %s" % ["ok  " if ok else "FAIL", what, detail])
	if not ok:
		_failures += 1


func _wait(n: int) -> void:
	for i in n:
		await physics_frame


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var game := root.get_node_or_null("Game")
	game.set(&"dungeon_id", 0)
	var world: World = load("res://scenes/world/dungeon.tscn").instantiate()
	root.add_child(world)
	await _wait(40)
	var d := world.get_node("Level/Rooms") as Dungeon
	var panel := world.get_node_or_null("ArenaPanel") as ArenaPanel
	var hero := world.player()
	_check("a dungeon, a hero and F1's board", d != null and hero != null and panel != null)
	if d == null or hero == null or panel == null:
		quit(1)
		return
	hero.immortal = true
	hero.struck.connect(func(_damage: float, _blocked: bool) -> void: _struck += 1)
	var wanted := OS.get_cmdline_user_args()
	for place: String in Dungeon.PLACES:
		if not wanted.is_empty() and not wanted.has(place):
			continue
		if wanted.is_empty() and UNUSED.has(place):
			print("\n== %s: in no portal's run, not looked over" % place)
			continue
		await _place(d, panel, hero, place)
	print("places_test: %s" % ("All checks passed." if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)


func _place(d: Dungeon, panel: ArenaPanel, hero: Player, place: String) -> void:
	print("\n== %s (%s)" % [place, String(Dungeon.PLACES[place]["name"])])
	panel._clear()
	await _wait(2)
	d.view_place(place, false)
	var step := int(Dungeon.VIEW.get(place, [1])[0])
	await _wait(90)
	var c := d.centre(step)
	var p: Dictionary = Dungeon.PLACES[place]
	var l := float(p["l"])
	var room: Node3D = d._room_nodes[step] if step < d._room_nodes.size() else null
	_check("built", room != null and is_instance_valid(room) and d.current == step)
	if room == null or not is_instance_valid(room):
		return
	_tri.clear()
	var spots := {
		"door": d.entry_point(0, step),
		"middle": c,
		"left portal": c + Vector3(-9.0, 0.0, -l * 0.5 + 10.0),
		"right portal": c + Vector3(9.0, 0.0, -l * 0.5 + 10.0),
		"way out": c + Vector3(0.0, 0.0, -l * 0.5 + 15.0),
	}
	# He came in at the door: on the floor, and still on it a while after.
	var y0 := hero.global_position.y
	await _wait(90)
	var y1 := hero.global_position.y
	_check("stands at the door, does not sink", hero.is_on_floor() and absf(y1 - y0) < 0.05,
			"y %.2f -> %.2f floor=%s" % [y0, y1, hero.is_on_floor()])
	for spot: String in spots:
		var at: Vector3 = spots[spot]
		var walked := _walked_floor(at, c.y)
		var drawn := _drawn_floor(room, at, c.y, walked if not is_nan(walked) else c.y)
		var walked_ok := not is_nan(walked)
		_check("%s: a floor to walk on" % spot, walked_ok, "at %s" % str(at))
		if not walked_ok:
			continue
		if not is_nan(drawn):
			_check("%s: the walked floor is the drawn one" % spot,
					walked - drawn <= FEET_FLOAT and drawn - walked <= FEET_SINK,
					"walked %.2f drawn %.2f (%s)" % [walked, drawn, _drawn_name])
		else:
			_check("%s: a drawn floor under it" % spot, false, "nothing drawn under %s" % str(at))
		var blocking := _solid_at(Vector3(at.x, minf(walked, c.y), at.z))
		if walked - c.y > 0.8:
			blocking.append("something %.1f m tall under the ray" % (walked - c.y))
		if spot != "middle":
			_check("%s: nothing solid there" % spot, blocking.is_empty(), str(blocking))
		# him there: on his feet on the drawn floor, not in it
		hero.global_position = Vector3(at.x, walked + 0.3, at.z)
		hero.velocity = Vector3.ZERO
		await _wait(45)
		var feet := hero.global_position.y
		var under := drawn if not is_nan(drawn) else walked
		_check("%s: his feet on the floor" % spot, hero.is_on_floor() and under - feet <= FEET_SINK
				and feet - under <= FEET_FLOAT, "feet %.2f floor %.2f" % [feet, under])
	await _creatures(d, panel, hero, c, l)


func _creatures(_d: Dungeon, panel: ArenaPanel, hero: Player, c: Vector3, l: float) -> void:
	# By the door, facing in (the front of every place is kept clear).
	var stand := c + Vector3(0.0, 0.0, l * 0.5 - 6.0)
	var floor_y := _walked_floor(stand, c.y)
	hero.global_position = Vector3(stand.x, (floor_y if not is_nan(floor_y) else c.y) + 0.2, stand.z)
	hero.velocity = Vector3.ZERO
	hero.rotation.y = 0.0
	await _wait(30)
	panel._wait_for_blow = false
	panel._frozen = false
	var bodies: Array[Node3D] = []
	var kinds := [Dungeon.GOBLIN, Dungeon.PUGLIN]
	for k in kinds.size():
		var at := hero.global_position + Vector3(-2.5 + 5.0 * float(k), 0.0, -5.0)
		var body := panel.call_up(String(kinds[k]), false, at)
		if body != null:
			bodies.append(body)
	_check("F1 calls them up", bodies.size() == kinds.size(), str(bodies.size()))
	await _wait(40)
	for body in bodies:
		if not is_instance_valid(body):
			continue
		var at := body.global_position
		var ground := _walked_floor(at, c.y)
		var camp: Vector3 = body.get("camp_centre")
		var tag := String(body.name)
		_check("%s on the floor" % tag, not is_nan(ground) and absf(at.y - ground) < 0.3,
				"y %.2f floor %.2f" % [at.y, ground])
		_check("%s: its camp at the room's height" % tag, not is_nan(ground) and absf(camp.y - ground) < 0.6,
				"camp %.2f floor %.2f" % [camp.y, ground])
	_struck = 0
	var t := 0.0
	while t < BLOW_WAIT and _struck < 2:
		await physics_frame
		t += 1.0 / float(Engine.physics_ticks_per_second)
	var near: Array[String] = []
	for body in bodies:
		if is_instance_valid(body):
			near.append("%s %.1fm y%.2f" % [body.name, body.global_position.distance_to(hero.global_position),
					body.global_position.y])
	_check("they come at him and land blows", _struck >= 2, "%d blows in %.0f s; %s" % [_struck, t, str(near)])
	panel._clear()
	await _wait(5)


## The top of the walking collision under `at` (between the place's floor
## height + 4 m and 12 m under it), NAN if none.
func _walked_floor(at: Vector3, base: float) -> float:
	var space := root.get_world_3d().direct_space_state
	var top := maxf(at.y, base) + 4.0
	var q := PhysicsRayQueryParameters3D.create(Vector3(at.x, top, at.z), Vector3(at.x, base - 12.0, at.z), WORLD_MASK)
	var hit := space.intersect_ray(q)
	return float((hit["position"] as Vector3).y) if not hit.is_empty() else NAN


## The top of what is drawn under `at` (the place's meshes), NAN if nothing.
## (Only what is at most `ABOVE` over the walked floor counts: higher up it
## is a roof, an arch, a branch, not the floor.)
func _drawn_floor(room: Node3D, at: Vector3, base: float, walked: float) -> float:
	var ceiling := walked + ABOVE
	_drawn_name = ""
	var top := maxf(at.y, base) + 4.0
	var from := Vector3(at.x, top, at.z)
	var best := NAN
	for node in room.find_children("*", "MeshInstance3D", true, false):
		var m := node as MeshInstance3D
		if m.mesh == null or not m.is_visible_in_tree() or m.transparency > 0.5 or _see_through(m):
			continue
		var box := m.global_transform * m.get_aabb()
		if at.x < box.position.x or at.x > box.end.x or at.z < box.position.z or at.z > box.end.z:
			continue
		if box.position.y > top or box.end.y < base - 12.0:
			continue
		var tri: TriangleMesh = _tri.get(m.mesh)
		if tri == null:
			tri = m.mesh.generate_triangle_mesh()
			_tri[m.mesh] = tri
		if tri == null:
			continue
		var inv := m.global_transform.affine_inverse()
		var hit := tri.intersect_ray(inv * from, (inv.basis * Vector3.DOWN).normalized())
		if hit.is_empty():
			continue
		var y := (m.global_transform * (hit["position"] as Vector3)).y
		if y < base - 12.0:
			continue
		if y > ceiling:
			continue
		if is_nan(best) or y > best:
			best = y
			_drawn_name = String(m.name)
	return best


## Mist, haze, water and glow: drawn see-through, not stood on.
func _see_through(m: MeshInstance3D) -> bool:
	var mats: Array[Material] = [m.material_override]
	for k in m.mesh.get_surface_count():
		mats.append(m.get_active_material(k))
	for mat in mats:
		if mat is BaseMaterial3D and (mat as BaseMaterial3D).transparency != BaseMaterial3D.TRANSPARENCY_DISABLED \
				and (mat as BaseMaterial3D).transparency != BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR:
			return true
		if mat is ShaderMaterial and (mat as ShaderMaterial).shader != null:
			var code := (mat as ShaderMaterial).shader.code
			if code.contains("blend_add") or code.contains("unshaded") \
					or (code.contains("ALPHA =") and not code.contains("ALPHA_SCISSOR")):
				return true
	return false


## What is solid within reach of standing at `at` (on the floor): names.
func _solid_at(at: Vector3) -> Array[String]:
	var space := root.get_world_3d().direct_space_state
	var shape := CapsuleShape3D.new()
	shape.radius = CLEAR_R
	shape.height = CLEAR_H
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.collision_mask = WORLD_MASK
	q.transform = Transform3D(Basis.IDENTITY, at + Vector3.UP * (0.35 + CLEAR_H * 0.5))
	var out: Array[String] = []
	for hit: Dictionary in space.intersect_shape(q, 8):
		var n := hit["collider"] as Node
		out.append(String(n.get_path()).get_slice("/Rooms/", 1) if n != null else "?")
	return out
