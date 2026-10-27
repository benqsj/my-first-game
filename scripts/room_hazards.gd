class_name RoomHazards
extends Node

## A place's own dangers while its creatures are up (the user's word,
## 2026-10-28: the director's plan, liked):
##
## * **cave** — stalactites break from the roof: a ring on the floor where one
##   will land, a moment to step out, then it falls and shatters.
## * **crypt** — the old vault sheds its stones the same way.
## (The swamp's poison pools were tried and taken out, the user's word,
## 2026-10-28.)
##
## Made by [CombatDirector] for the place he has come to; the host chooses
## when and where a stone falls and every peer sees it ([method net_fall]).

## A stone: how often, how long its ring shows before it falls, how far it
## falls, its reach and its blow (a share of his whole life).
const FALL_EVERY := Vector2(4.5, 7.5)
const FALL_TELL := 1.3
const FALL_HEIGHT := 9.0
const FALL_TIME := 0.32
const FALL_R := 1.7
const FALL_HURT := 0.18
## Near him: within this of where he stands (now and then right on him).
const FALL_NEAR := 3.5

## On or off from F2 ([RoomsPanel]).
static var falls_on := true

var kind := ""
var _d: Dungeon
var _i := -1
var _next := 0.0
var _combo := 88000


static func make(d: Dungeon, i: int) -> RoomHazards:
	var place := d._place_of(i)
	var k := ""
	match place:
		"cave":
			k = "stalactites"
		"crypt":
			k = "stones"
	if k == "" or not falls_on:
		return null
	var h := RoomHazards.new()
	h.name = "RoomHazards"
	h.kind = k
	h._d = d
	h._i = i
	h._next = _now() + 3.0
	return h


## Puts the place's dangers up again as they now are (after F2 turned one on
## or off).
static func refresh(d: Dungeon) -> void:
	if d != null and d.director != null:
		d.director._hazard_step = -2


static func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func _fighting() -> bool:
	for body in _d._alive:
		if is_instance_valid(body) and not bool(body.get("is_dead")) and body.visible:
			return true
	return false


func _process(delta: float) -> void:
	if _d == null or _d.current != _i:
		return
	if not _d.decides() or _now() < _next or not _fighting():
		return
	_next = _now() + randf_range(FALL_EVERY.x, FALL_EVERY.y)
	var heroes := _d._heroes()
	var standing: Array = []
	for h in heroes:
		if not h.is_dead:
			standing.append(h)
	if standing.is_empty():
		return
	var hero: Node3D = standing[randi() % standing.size()]
	var off := Vector3.ZERO
	if randf() > 0.3:
		var a := randf() * TAU
		off = Vector3(cos(a), 0.0, sin(a)) * randf_range(0.8, FALL_NEAR)
	var at := _floor(hero.global_position + off)
	if is_inside_tree() and multiplayer.has_multiplayer_peer():
		net_fall.rpc(at)
	else:
		net_fall(at)


func _floor(at: Vector3) -> Vector3:
	var space := get_viewport().world_3d.direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.UP * 2.0, at + Vector3.DOWN * 10.0, 1))
	return hit["position"] if not hit.is_empty() else at


#region Falling
@rpc("authority", "call_local", "reliable")
func net_fall(at: Vector3) -> void:
	var world := Blood.world_of(_d)
	if world == null:
		return
	var spot := Node3D.new()
	spot.name = "Falling"
	world.add_child(spot)
	spot.global_position = at + Vector3.UP * 0.04
	# the ring where it will land, filling in
	var ring := _disc(FALL_R, Color(1.0, 0.35, 0.15, 0.16))
	spot.add_child(ring)
	var fill := _disc(FALL_R, Color(1.0, 0.45, 0.2, 0.32))
	fill.position.y = 0.01
	fill.scale = Vector3(0.05, 1.0, 0.05)
	spot.add_child(fill)
	# the stone, up out of sight
	var stone := MeshInstance3D.new()
	if kind == "stalactites":
		var cone := CylinderMesh.new()
		cone.top_radius = 0.5
		cone.bottom_radius = 0.02
		cone.height = 2.6
		cone.radial_segments = 6
		cone.rings = 1
		stone.mesh = cone
	else:
		var rock := SphereMesh.new()
		rock.radius = 0.6
		rock.height = 1.0
		rock.radial_segments = 6
		rock.rings = 3
		stone.mesh = rock
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.42, 0.41, 0.4) if kind == "stalactites" else Color(0.38, 0.36, 0.33)
	mat.roughness = 1.0
	stone.material_override = mat
	stone.position = Vector3.UP * FALL_HEIGHT
	stone.visible = false
	spot.add_child(stone)
	var tw := spot.create_tween()
	tw.tween_property(fill, "scale", Vector3.ONE, FALL_TELL - FALL_TIME)
	tw.tween_callback(func() -> void: stone.visible = true)
	tw.tween_property(stone, "position", Vector3.UP * (1.3 if kind == "stalactites" else 0.4), FALL_TIME) \
			.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(_landed.bind(spot, stone, ring, fill))
	tw.tween_interval(0.8)
	tw.tween_callback(spot.queue_free)


func _landed(spot: Node3D, stone: MeshInstance3D, ring: Node3D, fill: Node3D) -> void:
	var at := spot.global_position
	ring.visible = false
	fill.visible = false
	stone.visible = false
	SkillFx.burst(spot.get_parent(), at + Vector3.UP * 0.3, Color(0.55, 0.52, 0.48), 50,
			Vector2(3.0, 7.0), Vector3.UP, 120.0, Vector2(0.06, 0.18), Vector3(0, -9.0, 0), 0.7)
	ImpactFx.thud(spot, at, true)
	Sfx.play(spot, Dungeon.SND + "crumble.wav", null, at, randf_range(0.9, 1.15), 2.0)
	if not _d.decides():
		return
	_combo += 1
	for hero in _d._heroes():
		if hero.is_dead:
			continue
		var gap := Vector2(hero.global_position.x - at.x, hero.global_position.z - at.z).length()
		if gap <= FALL_R and absf(hero.global_position.y - at.y) < 2.5:
			hero.receive_blow(hero.max_health * FALL_HURT, spot, 0, 1, _combo, false)
#endregion




static func _disc(r: float, tint: Color) -> MeshInstance3D:
	var d := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = r
	cyl.bottom_radius = r
	cyl.height = 0.03
	cyl.radial_segments = 36
	d.mesh = cyl
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = tint
	d.material_override = m
	d.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return d
