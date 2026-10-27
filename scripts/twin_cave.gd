class_name TwinCave
extends RefCounted

## The ghouls' cave, two halls one after the other (the user's pick,
## 2026-10-27: concepts gamoq2 and gamoq4, "one to one"; the ghouls its own).
## High-end low poly as the forest: the pieces in `ghoul_cave_lowpoly.glb`
## (Blender, `vepxis-art/world/ghoul_cave_lowpoly.py`), built in the kit's
## frame (the temple hall at +z, the den at -z) under one node turned round:
## in the room the den is at +z, where he comes in.
##
## He comes in out of a dark tunnel into the ghouls' den: a high round hall
## under a great sinkhole, the moon's shaft down through it onto a wide
## flagged floor; a ledge all round at half its height, the dark mouths of
## the ghouls' tunnels under it, bones and their nests of rags up on it. The
## first wave is met there. Behind it the short tunnel with the timber gate:
## it creaks open with the second wave ([method open_way], on every peer).
## Then the temple hall: pale greige rock, a forgotten temple carved into
## its far wall (a great shut door in a niche between columns, a stair up
## to it), pale crystals at the walls, a stream along each side; the portals
## stand before the temple, its great door shut.
##
## (The cave before, a beast's den and a crystal hall with a turquoise pool,
## 2026-10-26: `twin_cave_lowpoly.py`, in git before this.)

const DIR := "res://assets/dungeon/ghoul_cave/"
const KIT := DIR + "ghoul_cave_lowpoly.glb"
## The same numbers as the Blender script's: centre z, half-width,
## half-length, height.
const HALL_A := Vector4(34.0, 25.0, 24.5, 21.0)
const HALL_D := Vector4(-26.0, 24.0, 21.5, 18.0)
const TUN_W := 4.6
const TUN_H := 6.6
const HOLE_D := 8.5
const LEDGE_K := 0.80
## The ghouls' tunnel mouths under the den's ledge: angle round it (degrees,
## x = cos, z = sin), half-width (degrees), height. The first two are the
## tunnel on and the way in.
const MOUTHS := [[90.0, 19.0, 7.1], [270.0, 17.0, 6.4],
		[14.0, 7.0, 3.3], [46.0, 6.5, 3.6], [134.0, 6.5, 3.5], [166.0, 7.0, 3.2],
		[203.0, 6.5, 3.6], [236.0, 6.0, 3.3], [304.0, 6.0, 3.4], [337.0, 7.0, 3.5]]
## The temple's plinth (front z, back z, half-width, top), the stair's
## half-width and foot, as built (the Blender script's sizes grown 1.3 and
## set back to z 50).
const PLINTH := Vector4(50.0, 58.32, 17.55, 1.95)
const STAIR := Vector2(3.9, 46.36)
## The streams: the line each follows (x, z) and its half-width.
const STREAMS := [
	[[Vector2(15.6, 13.0), Vector2(13.6, 19.0), Vector2(14.2, 26.0), Vector2(17.4, 33.0), Vector2(21.4, 40.5), Vector2(23.6, 45.0)], 1.4],
	[[Vector2(-22.4, 26.0), Vector2(-20.8, 32.5), Vector2(-19.6, 38.5), Vector2(-19.5, 44.0), Vector2(-23.0, 48.0)], 1.2],
]
## Where the gate stands across the tunnel (z), its leaves' hinges (x) and
## how far they swing open (degrees).
const GATE_Z := 2.5
const LEAF_HINGE := 3.78
const OPEN_DEG := 100.0
## Where the first wave stands (the room's z): the middle of the den.
const WAVE_ONE_Z := 22.0

static var _kit: Node3D
static var _crystal_mat: StandardMaterial3D
static var _void_mat: StandardMaterial3D
static var _sky_mat: StandardMaterial3D
static var _vine_mat: StandardMaterial3D


static func build(d: Dungeon, room: Node3D, w: float, l: float, rng: RandomNumberGenerator) -> void:
	_ready_kit()
	# the floor walked on: a box at 0, the drawn rock over it
	var slab := d._solid(room, TerracePlaces._solid(0.0), Vector3(w + 2.0, 1.0, l + 2.0), Vector3(0.0, -0.5, 0.0))
	for mi in slab.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).visible = false
	d._bounds(room, w, l)
	var top := room
	room = Node3D.new()
	room.name = "Cave"
	room.rotation.y = PI
	top.add_child(room)
	_shadows(_piece(room, "GGround", Vector3.ZERO), GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	for name: String in ["GHallA", "GHallD", "GTunnel", "GWayIn", "GLedge"]:
		var shell := _piece(room, name, Vector3.ZERO)
		_shadows(shell, GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED)
		_solid_shell(shell)
	for name: String in ["GShaftD"]:
		_shadows(_piece(room, name, Vector3.ZERO), GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED)
	for name: String in ["GSkyD"]:
		var lid := _piece(room, name, Vector3.ZERO)
		_shadows(lid, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
		for mi in lid.find_children("*", "MeshInstance3D", true, false) + [lid]:
			if mi is MeshInstance3D:
				(mi as MeshInstance3D).material_override = _sky_mat
	_shadows(_piece(room, "GMouths", Vector3.ZERO), GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	_shadows(_piece(room, "GLedgeLife", Vector3.ZERO), GeometryInstance3D.SHADOW_CASTING_SETTING_ON)
	_backstop(room)
	_den(d, room, rng)
	_gate(d, room)
	_temple(d, room, rng)
	TerracePlaces._motes(room, 30.0, 40.0, Color(0.80, 0.86, 0.95), 60)


## Dark rock behind all of it, round the sides, the ends and over the roof
## but for the den's sinkhole: where a seam in the shell lets the eye through it
## finds rock, not sky; it also keeps the light out but down the shafts.
static func _backstop(room: Node3D) -> void:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.025, 0.022, 0.02)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var dz := HALL_D.x
	var dh := HOLE_D + 2.5
	var y := 31.0
	var parts := [
		[Vector3(1.0, 50.0, 132.0), Vector3(-34.0, 12.0, 0.0)],
		[Vector3(1.0, 50.0, 132.0), Vector3(34.0, 12.0, 0.0)],
		[Vector3(70.0, 50.0, 1.0), Vector3(0.0, 12.0, 66.0)],
		[Vector3(70.0, 50.0, 1.0), Vector3(0.0, 12.0, -63.0)],
		[Vector3(70.0, 1.0, (dz - dh) + 63.0), Vector3(0.0, y, (dz - dh - 63.0) * 0.5)],
		[Vector3(35.0 - dh, 1.0, 2.0 * dh), Vector3(-(35.0 + dh) * 0.5, y, dz)],
		[Vector3(35.0 - dh, 1.0, 2.0 * dh), Vector3((35.0 + dh) * 0.5, y, dz)],
		[Vector3(70.0, 1.0, 66.0 - (dz + dh)), Vector3(0.0, y, (66.0 + dz + dh) * 0.5)],
	]
	for part: Array in parts:
		var box := BoxMesh.new()
		box.size = part[0]
		var mi := MeshInstance3D.new()
		mi.mesh = box
		mi.material_override = m
		mi.position = part[1]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
		room.add_child(mi)


## The arch's height over the floor at an angle round the den (-0.3: the
## rock stands there).
static func _arch_h(deg: float) -> float:
	var best := -0.3
	for m: Array in MOUTHS:
		var dd := fposmod(deg - float(m[0]) + 180.0, 360.0) - 180.0
		var s := absf(dd) / float(m[1])
		if s < 1.0:
			best = maxf(best, 1.0)
	return best


## A spot on the ellipse of a hall (kit frame) at an angle and a share of
## its radii.
static func _round(h: Vector4, deg: float, k: float) -> Vector3:
	var a := deg_to_rad(deg)
	return Vector3(cos(a) * h.y * k, 0.0, h.x + sin(a) * h.z * k)


## The den: the moon's shaft down the hole, stalagmites at the pillars'
## feet, boulders, a cold mist low.
static func _den(d: Dungeon, room: Node3D, rng: RandomNumberGenerator) -> void:
	var cz := HALL_D.x
	# stalagmites before the ledge's pillars, never in a mouth
	var placed := 0
	for k in 60:
		if placed >= 12:
			break
		var deg := rng.randf_range(0.0, 360.0)
		if _arch_h(deg) > 0.0 or _arch_h(deg + 5.0) > 0.0 or _arch_h(deg - 5.0) > 0.0:
			continue
		var at := _round(HALL_D, deg, LEDGE_K * rng.randf_range(0.9, 0.97))
		var f := _piece(room, "GFang%d" % rng.randi_range(0, 3), at, rng.randf_range(0.0, TAU))
		f.scale = Vector3.ONE * rng.randf_range(0.8, 1.25)
		_solid_hull(f)
		placed += 1
	# heaps of bones at the pillars' feet, as in the picture
	var heaps := 0
	for k in 40:
		if heaps >= 6:
			break
		var deg := rng.randf_range(0.0, 360.0)
		if _arch_h(deg) > 0.0 or _arch_h(deg + 6.0) > 0.0 or _arch_h(deg - 6.0) > 0.0:
			continue
		var at := _round(HALL_D, deg, LEDGE_K * 0.95)
		_piece(room, "GBones%d" % (heaps % 3), at, rng.randf_range(0.0, TAU))
		heaps += 1
	for k in 5:
		var deg := 25.0 + float(k) * 72.0 + rng.randf_range(-8.0, 8.0)
		if _arch_h(deg) > 0.0:
			deg += 12.0
		var at := _round(HALL_D, deg, LEDGE_K * 0.9)
		var b := _piece(room, "GBoulder%d" % rng.randi_range(0, 2), at, rng.randf_range(0.0, TAU))
		_solid_hull(b)
	# the moon's shaft seen in the air (only the light down the hole lights it)
	var air := FogVolume.new()
	air.shape = RenderingServer.FOG_VOLUME_SHAPE_ELLIPSOID
	air.size = Vector3(16.0, 50.0, 16.0)
	air.position = Vector3(0.0, 12.0, cz)
	var am := FogMaterial.new()
	am.density = 0.006
	am.albedo = Color(0.95, 0.97, 0.92)
	am.edge_fade = 1.0
	air.material = am
	if Graphics.current != Graphics.Level.LOW:
		room.add_child(air)
	# a cold mist lying low round the walls, in the mouths
	TerracePlaces._haze(room, Vector3(0.0, 0.6, cz), Vector3(HALL_D.y * 2.1, 2.0, HALL_D.z * 2.1), 0.01)
	var motes := Node3D.new()
	motes.position = Vector3(0.0, 0.0, cz)
	room.add_child(motes)
	TerracePlaces._motes(motes, HOLE_D * 1.6, HOLE_D * 1.6, Color(0.92, 0.94, 0.88), 50)
	# the moonlight given back off the floor, softly, up the walls and the ledge
	var bounce := OmniLight3D.new()
	bounce.light_color = Color(0.88, 0.90, 0.84)
	bounce.light_energy = 1.5
	bounce.omni_range = 34.0
	bounce.omni_attenuation = 0.7
	bounce.position = Vector3(0.0, 2.5, cz)
	bounce.set_meta(&"designed_shadow", false)
	room.add_child(bounce)
	# the grey of the walls and the ledge seen round the dark (gamoq2)
	for k in 4:
		var fa := TAU * (float(k) + 0.5) / 4.0
		var fill := OmniLight3D.new()
		fill.light_color = Color(0.92, 0.93, 0.88)
		fill.light_energy = 1.8
		fill.omni_range = 24.0
		fill.omni_attenuation = 0.9
		fill.position = Vector3(cos(fa) * HALL_D.y * 0.45, 6.5, cz + sin(fa) * HALL_D.z * 0.45)
		fill.set_meta(&"designed_shadow", false)
		room.add_child(fill)
	# the moonlight caught round the hole's rim and on the roof's teeth
	for k in 3:
		var ra := TAU * float(k) / 3.0 + 0.4
		var rim := OmniLight3D.new()
		rim.light_color = Color(0.92, 0.94, 0.90)
		rim.light_energy = 1.6
		rim.omni_range = 15.0
		rim.position = Vector3(cos(ra) * (HOLE_D + 2.5), HALL_D.w - 3.0, cz + sin(ra) * (HOLE_D + 2.5))
		rim.set_meta(&"designed_shadow", false)
		room.add_child(rim)
	# a little of it reaching back into the way in, where he comes out
	var way := OmniLight3D.new()
	way.light_color = Color(0.84, 0.86, 0.80)
	way.light_energy = 0.7
	way.omni_range = 11.0
	way.position = Vector3(0.0, 4.0, cz - HALL_D.z - 2.5)
	way.set_meta(&"designed_shadow", false)
	room.add_child(way)


## The temple hall: the temple and its door, the columns, the crystals,
## the streams and what keeps him out of them; its light.
static func _temple(d: Dungeon, room: Node3D, rng: RandomNumberGenerator) -> void:
	var cz := HALL_A.x
	var temple := _piece(room, "GTemple", Vector3.ZERO)
	_shadows(temple, GeometryInstance3D.SHADOW_CASTING_SETTING_ON)
	_solid_shell(temple)
	# the stair as a slope to walk up
	var run := PLINTH.x - STAIR.y
	var slope := StaticBody3D.new()
	var ss := CollisionShape3D.new()
	var sb := BoxShape3D.new()
	sb.size = Vector3(STAIR.x * 2.0, 0.2, sqrt(run * run + PLINTH.w * PLINTH.w))
	ss.shape = sb
	slope.add_child(ss)
	slope.position = Vector3(0.0, PLINTH.w * 0.5 - 0.05, STAIR.y + run * 0.5)
	slope.rotation.x = -atan2(PLINTH.w, run)
	room.add_child(slope)
	# the great shut door in the niche (the user's word, 2026-10-27: no figure)
	var door := _piece(room, "GDoor", Vector3.ZERO)
	_shadows(door, GeometryInstance3D.SHADOW_CASTING_SETTING_ON)
	_solid_shell(door)
	for c: Array in [["GColumn", Vector3(-14.0, 0.0, 36.0), 0.3], ["GColumnBroken", Vector3(13.6, 0.0, 40.5), 1.1]]:
		var col := _piece(room, String(c[0]), c[1], float(c[2]))
		_solid_hull(col)
	var fallen := _piece(room, "GColumnFallen", Vector3(-15.5, 0.0, 26.0), 0.5)
	_solid_hull(fallen)
	# the streams: their faces, and low walls along them he cannot pass
	var water := _stream_water()
	var s := _piece(room, "GStream", Vector3.ZERO)
	_shadows(s, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	for mi in s.find_children("*", "MeshInstance3D", true, false) + [s]:
		if mi is MeshInstance3D:
			(mi as MeshInstance3D).material_override = water
	_shadows(_piece(room, "GBanks", Vector3.ZERO), GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	for st: Array in STREAMS:
		var pts: Array = st[0]
		var hw := float(st[1])
		for k in pts.size() - 1:
			var a: Vector2 = pts[k]
			var b: Vector2 = pts[k + 1]
			var body := StaticBody3D.new()
			var shape := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = Vector3(hw * 2.3, 3.0, a.distance_to(b) + 0.8)
			shape.shape = box
			body.add_child(shape)
			var mid := (a + b) * 0.5
			body.position = Vector3(mid.x, 1.5, mid.y)
			body.rotation.y = atan2(b.x - a.x, b.y - a.y)
			room.add_child(body)
	# pale crystals at the walls, out of the streams' way and the portals'
	var n := 26
	var made := 0
	for k in n:
		var deg := 360.0 * (float(k) + rng.randf_range(-0.3, 0.3)) / float(n)
		var at := _round(HALL_A, deg, rng.randf_range(0.82, 0.9))
		if absf(at.x) < 8.0 and at.z < cz:
			continue
		if at.z > PLINTH.x - 3.0 and absf(at.x) < PLINTH.z + 1.0:
			continue
		if _near_portal(at) or _in_stream(at, 1.8):
			continue
		var c := _piece(room, "GCrystal%d" % rng.randi_range(0, 3), at, rng.randf_range(0.0, TAU))
		c.scale = Vector3.ONE * rng.randf_range(1.7, 2.7)
		_shadows(c, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
		_solid_hull(c)
		made += 1
		if made % 3 == 0:
			var glow := OmniLight3D.new()
			glow.light_color = Color(0.62, 0.95, 0.95)
			glow.light_energy = 1.6
			glow.omni_range = 7.0
			glow.position = at + Vector3(0.0, 1.4, 0.0) + (Vector3(0.0, 0.0, cz) - at).normalized() * 1.2
			glow.set_meta(&"designed_shadow", false)
			room.add_child(glow)
	# big clusters at the plinth's front corners, as in the picture
	for side: float in [-1.0, 1.0]:
		var at := Vector3(side * 14.5, 0.0, PLINTH.x - 1.2)
		var c := _piece(room, "GCrystal%d" % (2 if side < 0.0 else 3), at, rng.randf_range(0.0, TAU))
		c.scale = Vector3.ONE * 2.4
		_shadows(c, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
		_solid_hull(c)
		var glow := OmniLight3D.new()
		glow.light_color = Color(0.62, 0.95, 0.95)
		glow.light_energy = 1.6
		glow.omni_range = 8.0
		glow.position = at + Vector3(-side * 1.5, 1.8, -1.5)
		glow.set_meta(&"designed_shadow", false)
		room.add_child(glow)
	# small ones by the banks
	for k in 12:
		var st: Array = STREAMS[k % 2]
		var pts: Array = st[0]
		var i := rng.randi_range(0, pts.size() - 2)
		var p: Vector2 = (pts[i] as Vector2).lerp(pts[i + 1], rng.randf())
		var off := (Vector2(0.0, cz) - p).normalized() * float(st[1]) * rng.randf_range(1.5, 1.9)
		var at := Vector3(p.x + off.x, 0.0, p.y + off.y)
		if _near_portal(at):
			continue
		var c := _piece(room, "GCrystal%d" % rng.randi_range(0, 3), at, rng.randf_range(0.0, TAU))
		c.scale = Vector3.ONE * rng.randf_range(0.4, 0.65)
		_shadows(c, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	# the lamp-posts' crystals at the stair's foot
	for side: float in [-1.0, 1.0]:
		var lamp := OmniLight3D.new()
		lamp.light_color = Color(0.6, 0.86, 1.0)
		lamp.light_energy = 1.4
		lamp.omni_range = 6.0
		lamp.position = Vector3(side * (STAIR.x + 0.5), 2.6, STAIR.y - 0.4)
		lamp.set_meta(&"designed_shadow", false)
		room.add_child(lamp)
	# the hall's soft daylight: the rock and the temple pale, as in the picture
	for at: Vector3 in [Vector3(0.0, 12.0, cz - 6.0), Vector3(-11.0, 9.0, cz + 8.0), Vector3(11.0, 9.0, cz + 8.0)]:
		var fill := OmniLight3D.new()
		fill.light_color = Color(1.0, 1.0, 0.98)
		fill.light_energy = 1.7
		fill.omni_range = 24.0
		fill.omni_attenuation = 0.8
		fill.position = at
		fill.set_meta(&"designed_shadow", false)
		room.add_child(fill)
	# the door lit from above and before
	var spot := SpotLight3D.new()
	spot.light_color = Color(1.0, 0.95, 0.86)
	spot.light_energy = 2.5
	spot.spot_range = 22.0
	spot.spot_angle = 22.0
	spot.position = Vector3(0.0, 14.0, PLINTH.x - 8.0)
	room.add_child(spot)
	spot.look_at(room.to_global(Vector3(0.0, 7.0, 56.5)), Vector3.UP)
	spot.set_meta(&"designed_shadow", false)
	TerracePlaces._haze(room, Vector3(0.0, 0.4, cz), Vector3(HALL_A.y * 2.0, 1.4, HALL_A.z * 2.0), 0.006)


## Whether a spot (kit frame) is within `pad` of a stream's line (beyond its
## half-width).
static func _in_stream(at: Vector3, pad: float) -> bool:
	var p := Vector2(at.x, at.z)
	for st: Array in STREAMS:
		var pts: Array = st[0]
		for k in pts.size() - 1:
			var a: Vector2 = pts[k]
			var b: Vector2 = pts[k + 1]
			var t := clampf((p - a).dot(b - a) / (b - a).length_squared(), 0.0, 1.0)
			if p.distance_to(a.lerp(b, t)) < float(st[1]) + pad:
				return true
	return false


## Whether a spot (kit frame) is near where the portals or the way out
## stand: in the room at (±9, -l/2+10) and (0, -l/2+15), at the temple
## hall's far end; in the kit's frame, turned, at +z.
static func _near_portal(at: Vector3) -> bool:
	for spot: Vector3 in [Vector3(9.0, 0.0, 45.0), Vector3(-9.0, 0.0, 45.0), Vector3(0.0, 0.0, 40.0)]:
		if Vector2(at.x - spot.x, at.z - spot.z).length() < 5.0:
			return true
	return false


## The streams' water: dark clear teal, the bed seen a little through it,
## ripples running down along it, a soft sheen of the crystals' light.
const STREAM_WATER := """
shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_disabled, specular_schlick_ggx;
uniform vec4 shallow : source_color = vec4(0.20, 0.42, 0.46, 1.0);
uniform vec4 deep : source_color = vec4(0.04, 0.12, 0.15, 1.0);
uniform float depth_reach = 0.35;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D depth_tex : hint_depth_texture, filter_linear_mipmap;
varying vec3 wp;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
float waves(vec2 p) {
	return vnoise(p * 1.6 + vec2(TIME * 0.35, TIME * 0.6)) * 0.6 + vnoise(p * 3.1 - vec2(TIME * 0.5, TIME * 0.2)) * 0.4;
}
void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	float e = 0.08;
	float h = waves(wp.xz);
	vec2 slope = vec2(waves(wp.xz + vec2(e, 0.0)) - h, waves(wp.xz + vec2(0.0, e)) - h) / e;
	vec3 nw = normalize(vec3(-slope.x * 0.12, 1.0, -slope.y * 0.12));
	NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);
	float d = texture(depth_tex, SCREEN_UV).r;
	vec4 behind = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, d, 1.0);
	behind.xyz /= behind.w;
	float depth = clamp(VERTEX.z - behind.z, 0.0, 20.0);
	float k = 1.0 - exp(-depth / depth_reach);
	vec3 bed = textureLod(screen_tex, SCREEN_UV + slope * 0.006 * k, 0.0).rgb;
	vec3 c = mix(bed * shallow.rgb * 1.4 + shallow.rgb * 0.12, deep.rgb, k * 0.85);
	c += vec3(0.7, 0.9, 1.0) * smoothstep(0.7, 0.95, h) * 0.05;
	ALBEDO = c;
	EMISSION = vec3(0.10, 0.22, 0.26) * 0.08;
	ROUGHNESS = 0.06;
	SPECULAR = 0.5;
	ALPHA = smoothstep(0.0, 0.03, depth);
}
"""
static var _stream_shader: Shader


static func _stream_water() -> ShaderMaterial:
	if _stream_shader == null:
		_stream_shader = Shader.new()
		_stream_shader.code = STREAM_WATER
	var m := ShaderMaterial.new()
	m.shader = _stream_shader
	m.render_priority = -100
	return m


## The gate across the tunnel (the user's word, 2026-10-25: a wooden gate
## that opens, not fallen rock): a timber frame, two barred leaves, and what
## holds him back while they are shut. Looking round (F2) it stands open.
static func _gate(d: Dungeon, room: Node3D) -> void:
	var gate := Node3D.new()
	gate.name = "Gate"
	gate.position = Vector3(0.0, 0.0, GATE_Z)
	room.add_child(gate)
	_shadows(_piece(gate, "GGateFrame", Vector3.ZERO), GeometryInstance3D.SHADOW_CASTING_SETTING_ON)
	for side: float in [-1.0, 1.0]:
		var leaf := _piece(gate, "GGateLeaf", Vector3(side * LEAF_HINGE, 0.0, 0.0), 0.0 if side < 0.0 else PI)
		leaf.name = "LeafL" if side < 0.0 else "LeafR"
	var wall := StaticBody3D.new()
	wall.name = "GateWall"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(TUN_W * 2.0 + 1.0, TUN_H + 2.0, 0.8)
	shape.shape = box
	shape.position = Vector3(0.0, (TUN_H + 2.0) * 0.5, 0.0)
	wall.add_child(shape)
	gate.add_child(wall)
	# the frame's posts stop him at the sides
	for side: float in [-1.0, 1.0]:
		var post := StaticBody3D.new()
		var ps := CollisionShape3D.new()
		var pb := BoxShape3D.new()
		pb.size = Vector3(0.6, 6.4, 0.7)
		ps.shape = pb
		ps.position = Vector3(side * 4.05, 3.2, 0.0)
		post.add_child(ps)
		gate.add_child(post)
	for side: float in [-1.0, 1.0]:
		_torch(room, Vector3(side * 3.3, 0.0, GATE_Z - 2.2), 0.0)
	if d._viewing:
		_swing(gate, false)


## A torch on its stake, its fire and warm light.
static func _torch(room: Node3D, at: Vector3, yaw: float) -> void:
	var t := _piece(room, "GTorch", at, yaw)
	TerracePlaces._post_col(t, 0.25, 2.0)
	var tip := at + Vector3(0.0, 2.1, 0.0)
	CryptTomb._flames(room, tip, [Vector3.ZERO], Color(1.0, 0.6, 0.28), false, 1.6)
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.64, 0.36)
	lamp.light_energy = 4.0
	lamp.omni_range = 13.0
	lamp.position = tip + Vector3(0.0, 0.4, 0.0)
	lamp.set_meta(&"designed_shadow", false)
	room.add_child(lamp)


## The gate thrown open (the second wave's coming, or the place cleared
## with one wave): on every peer, once.
static func open_way(d: Dungeon, room: Node3D) -> void:
	if room == null or not is_instance_valid(room):
		return
	var gate := room.get_node_or_null(^"Cave/Gate") as Node3D
	if gate == null or gate.has_meta(&"open"):
		return
	var at := gate.global_position + Vector3(0.0, 2.5, 0.0)
	Sfx.play(d, Dungeon.SND + "creak.wav", null, at, 0.55, 8.0)
	Sfx.play(d, Dungeon.SND + "creak.wav", null, at + Vector3(2.0, 0.0, 0.0), 0.7, 6.0)
	WindBlast.shake(gate, 0.1, 0.5, 90.0)
	_swing(gate, true)
	var world := Blood.world_of(d)
	if world != null:
		for j in 3:
			SkillFx.burst(world, at + Vector3(randf_range(-3.0, 3.0), randf_range(-2.0, 0.5), 0.0),
					Color(0.55, 0.50, 0.46), 24, Vector2(0.5, 2.0), Vector3.UP, 120.0, Vector2(0.1, 0.25),
					Vector3(0, -0.8, 0), 1.4)


## The leaves turned in to the den, back against the tunnel's sides; the bar
## gone. `slow`: swung over a couple of seconds, else at once.
static func _swing(gate: Node3D, slow: bool) -> void:
	gate.set_meta(&"open", true)
	var wall := gate.get_node_or_null(^"GateWall")
	if wall != null:
		wall.queue_free()
	for name: String in ["LeafL", "LeafR"]:
		var leaf := gate.get_node_or_null(NodePath(name)) as Node3D
		if leaf == null:
			continue
		# the left leaf reaches +x from its hinge, the right one -x: both
		# turned in to the crystal hall (+z in the kit's frame)
		var to := leaf.rotation.y + (-deg_to_rad(OPEN_DEG) if name == "LeafL" else deg_to_rad(OPEN_DEG))
		if slow:
			var tw := leaf.create_tween()
			tw.tween_interval(0.3 if name == "LeafL" else 0.5)
			tw.tween_property(leaf, "rotation:y", to, 2.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		else:
			leaf.rotation.y = to


# ---------------------------------------------------------------- the kit
static func _ready_kit() -> void:
	if _kit != null and is_instance_valid(_kit):
		return
	_crystal_mat = StandardMaterial3D.new()
	_crystal_mat.vertex_color_use_as_albedo = true
	_crystal_mat.vertex_color_is_srgb = true
	# pale ice with a soft light inside (gamoq4), not a lamp
	_crystal_mat.albedo_color = Color(0.85, 0.97, 1.0)
	_crystal_mat.roughness = 0.1
	_crystal_mat.emission_enabled = true
	_crystal_mat.emission = Color(0.55, 0.92, 0.95)
	_crystal_mat.emission_energy_multiplier = 1.1
	_void_mat = StandardMaterial3D.new()
	_void_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_void_mat.albedo_color = Color(0.012, 0.012, 0.014)
	_void_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	# the sky seen up the shafts: pale, as the picture's white light above
	_sky_mat = StandardMaterial3D.new()
	_sky_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_sky_mat.albedo_color = Color(0.74, 0.78, 0.72)
	_sky_mat.disable_fog = true
	_sky_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_vine_mat = StandardMaterial3D.new()
	_vine_mat.vertex_color_use_as_albedo = true
	_vine_mat.vertex_color_is_srgb = true
	_vine_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_vine_mat.roughness = 0.9
	_kit = (load(KIT) as PackedScene).instantiate() as Node3D
	for mi: MeshInstance3D in _kit.find_children("*", "MeshInstance3D", true, false):
		var mesh := mi.mesh
		for s in mesh.get_surface_count():
			var mat := mesh.surface_get_material(s)
			match String(mat.resource_name) if mat != null else "":
				"Crystal":
					mi.set_surface_override_material(s, _crystal_mat)
				"Void":
					mi.set_surface_override_material(s, _void_mat)
				"Vine", "Cloth":
					mi.set_surface_override_material(s, _vine_mat)
				"Iron", "Rust":
					mi.set_surface_override_material(s, TerracePlaces._solid(0.0, 1.0, 0.5))
				"Wood":
					mi.set_surface_override_material(s, TerracePlaces._solid(0.0, 1.0, 0.95))
				"Carved", "Statue", "Bone":
					mi.set_surface_override_material(s, TerracePlaces._solid(0.0, 1.05, 0.88))
				_:
					mi.set_surface_override_material(s, TerracePlaces._solid(0.0, 1.15, 0.92))


static func _piece(parent: Node3D, piece: String, at: Vector3, yaw: float = 0.0) -> Node3D:
	var src := _kit.get_node_or_null(piece) as Node3D
	if src == null:
		push_warning("TwinCave: no piece " + piece)
		return Node3D.new()
	var n := src.duplicate() as Node3D
	n.transform = Transform3D(Basis(Vector3.UP, yaw), at)
	parent.add_child(n)
	return n


## A prop's own hull to stop him (the user's word, 2026-10-25: he walked
## into the rocks and the crystals).
static func _solid_hull(n: Node3D) -> void:
	for mi in n.find_children("*", "MeshInstance3D", true, false) + [n]:
		if mi is MeshInstance3D and (mi as MeshInstance3D).mesh != null:
			var body := StaticBody3D.new()
			var shape := CollisionShape3D.new()
			shape.shape = (mi as MeshInstance3D).mesh.create_convex_shape(true, true)
			body.add_child(shape)
			(mi as Node3D).add_child(body)


## A shell's own faces to stop him (walls, the tunnel's sides).
static func _solid_shell(n: Node3D) -> void:
	for mi in n.find_children("*", "MeshInstance3D", true, false) + [n]:
		if mi is MeshInstance3D and (mi as MeshInstance3D).mesh != null:
			var body := StaticBody3D.new()
			var shape := CollisionShape3D.new()
			var tri := (mi as MeshInstance3D).mesh.create_trimesh_shape()
			tri.backface_collision = true
			shape.shape = tri
			body.add_child(shape)
			(mi as Node3D).add_child(body)


static func _shadows(n: Node3D, how: GeometryInstance3D.ShadowCastingSetting) -> void:
	for g in n.find_children("*", "GeometryInstance3D", true, false) + [n]:
		if g is GeometryInstance3D:
			(g as GeometryInstance3D).cast_shadow = how
