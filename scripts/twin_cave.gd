class_name TwinCave
extends RefCounted

## The cave as two halls one after the other (the user's pick, 2026-10-25:
## concepts A and D joined, a wave in each). High-end low poly as the forest
## and the prisoners' cave: the pieces in `twin_cave_lowpoly.glb` (Blender,
## `vepxis-art/world/twin_cave_lowpoly.py`), built in room space.
##
## He comes in at the beast's den (the user's word, 2026-10-26: the den
## first, the crystal hall second), out of a misty valley at dusk through
## its great mouth: low and jagged, torches, bones, a rusted shield. The
## first wave is met there. Behind it a short tunnel shut by a timber gate:
## when the second wave comes (or the first is the only one and falls) it
## creaks open ([method open_way], on every peer). Then the high crystal
## hall: the sky through a hole in its dome, a shaft of light down on the
## floor, a pool glowing still and blue, crystals at its walls; the second
## wave comes out of the rift there, and the portals stand at its far end.
##
## Everything is built in the Blender kit's frame (the hall at +z, the den
## at -z) under one node turned round: in the room the den is at +z, where
## he comes in.

const DIR := "res://assets/dungeon/twin_cave/"
const KIT := DIR + "twin_cave_lowpoly.glb"
## The same numbers as the Blender script's: centre z, half-width,
## half-length, height.
const HALL_A := Vector4(30.0, 24.0, 20.5, 17.0)
const HALL_D := Vector4(-27.0, 25.0, 23.0, 11.5)
const TUN_W := 4.6
const TUN_H := 6.6
const POOL := Vector4(-11.5, 33.0, 5.2, 8.0)
const MOUTH_W := 13.0
## Where the gate stands across the tunnel (z), its leaves' hinges (x) and
## how far they swing open (degrees).
const GATE_Z := 2.5
const LEAF_HINGE := 3.78
const OPEN_DEG := 100.0
## Where the first wave stands (the room's z): the middle of the den.
const WAVE_ONE_Z := 22.0

static var _kit: Node3D
static var _crystal_mat: StandardMaterial3D
static var _water_mat: StandardMaterial3D


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
	_shadows(_piece(room, "TGround", Vector3.ZERO), GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	_shadows(_piece(room, "TValley", Vector3.ZERO), GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	for name: String in ["THallA", "THallD", "TTunnel", "TWayIn"]:
		var shell := _piece(room, name, Vector3.ZERO)
		_shadows(shell, GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED)
		_solid_shell(shell)
	var pool := _piece(room, "TPool", Vector3.ZERO)
	_shadows(pool, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	var water := _pool_water()
	var mid := room.to_global(Vector3(POOL.x, 0.0, POOL.y))
	water.set_shader_parameter("centre", Vector2(mid.x, mid.z))
	for mi in pool.find_children("*", "MeshInstance3D", true, false) + [pool]:
		if mi is MeshInstance3D:
			(mi as MeshInstance3D).material_override = water
	# the pool is not waded: its rim of rocks stops him
	d._blocker(room, Vector3(POOL.z * 1.9, 3.0, POOL.w * 1.9), Vector3(POOL.x, 1.5, POOL.y))
	_backstop(room)
	# he stays in the den: the mouth's lip stops him (the valley is to look
	# at; out on it he saw the rock's back, 2026-10-25)
	# (behind where he comes in now: at the lip of the mouth)
	d._blocker(room, Vector3(MOUTH_W * 2.4, 8.0, 1.0), Vector3(0.0, 4.0, HALL_D.x - HALL_D.z - 3.5))
	_hall(d, room, rng)
	_gate(d, room)
	_den(d, room, rng)
	TerracePlaces._motes(room, 30.0, 40.0, Color(0.80, 0.86, 0.95), 70)


## Dark rock behind all of it, round the sides, the way in's end and over
## the roof (but for the hall's hole): where a seam in the shell lets the eye
## through it finds rock, not sky (the user's word, 2026-10-25: chinks of
## sky); it also keeps the sun out but through the hole.
static func _backstop(room: Node3D) -> void:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.025, 0.022, 0.02)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var hole := HALL_A.x
	var parts := [
		# (the sides stop short of the den's mouth: seen out of it they stood
		# black against the valley)
		[Vector3(1.0, 34.0, 108.0), Vector3(-33.0, 12.0, 12.0)],
		[Vector3(1.0, 34.0, 108.0), Vector3(33.0, 12.0, 12.0)],
		[Vector3(68.0, 34.0, 1.0), Vector3(0.0, 12.0, 66.0)],
		[Vector3(68.0, 1.0, hole - 6.0 + 56.0), Vector3(0.0, 22.0, (hole - 6.0 - 56.0) * 0.5)],
		[Vector3(68.0, 1.0, 66.0 - hole - 6.0), Vector3(0.0, 22.0, (66.0 + hole + 6.0) * 0.5)],
		[Vector3(27.0, 1.0, 12.0), Vector3(-19.5, 22.0, hole)],
		[Vector3(27.0, 1.0, 12.0), Vector3(19.5, 22.0, hole)],
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


## The crystal hall: the crystals at its walls glowing, the shaft under the hole.
static func _hall(d: Dungeon, room: Node3D, rng: RandomNumberGenerator) -> void:
	var cz := HALL_A.x
	var n := 16
	for k in n:
		var a := TAU * (float(k) + rng.randf_range(-0.3, 0.3)) / float(n)
		var dir := Vector2(cos(a), sin(a))
		var at := Vector3(dir.x * HALL_A.y * 0.86, 0.0, cz + dir.y * HALL_A.z * 0.86)
		# not in the tunnel's way, nor the way in, nor the pool
		if absf(at.x) < 7.0 or Vector2((at.x - POOL.x) / POOL.z, (at.z - POOL.y) / POOL.w).length() < 1.25:
			continue
		if _near_portal(at):
			continue
		var c := _piece(room, "TCrystal%d" % rng.randi_range(0, 3), at, rng.randf_range(0.0, TAU))
		c.scale = Vector3.ONE * rng.randf_range(1.3, 2.2)
		_shadows(c, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
		_solid_hull(c)
		if k % 3 == 0:
			var glow := OmniLight3D.new()
			glow.light_color = Color(0.35, 0.92, 0.85)
			glow.light_energy = 1.3
			glow.omni_range = 8.0
			glow.position = at + Vector3(-dir.x * 1.2, 1.4, -dir.y * 1.2)
			glow.set_meta(&"designed_shadow", false)
			room.add_child(glow)
	# crystals over the pool, their light in it
	for k in 3:
		var at := Vector3(POOL.x - POOL.z * 0.9 + rng.randf_range(-0.5, 0.5), 0.0, POOL.y + (float(k) - 1.0) * POOL.w * 0.7)
		var c := _piece(room, "TCrystal%d" % (k % 4), at, rng.randf_range(0.0, TAU))
		c.scale = Vector3.ONE * rng.randf_range(1.2, 1.8)
		_solid_hull(c)
	for k in 3:
		var at := Vector3(POOL.x + rng.randf_range(-1.5, 1.5), -0.2, POOL.y + (float(k) - 1.0) * POOL.w * 0.45)
		var c := _piece(room, "TCrystal%d" % (k % 4), at, rng.randf_range(0.0, TAU))
		c.scale = Vector3.ONE * rng.randf_range(0.6, 0.9)
	for k in 14:
		var a := rng.randf() * TAU
		var r := rng.randf_range(0.55, 0.8)
		var at := Vector3(cos(a) * HALL_A.y * r, 0.0, cz + sin(a) * HALL_A.z * r)
		if absf(at.x) < 5.0 or _near_portal(at) or Vector2((at.x - POOL.x) / POOL.z, (at.z - POOL.y) / POOL.w).length() < 1.3:
			continue
		var c := _piece(room, "TCrystal%d" % rng.randi_range(0, 3), at, rng.randf_range(0.0, TAU))
		c.scale = Vector3.ONE * rng.randf_range(0.35, 0.6)
		_shadows(c, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	var motes := Node3D.new()
	motes.position = Vector3(0.0, 0.0, cz)
	room.add_child(motes)
	TerracePlaces._motes(motes, HALL_A.y * 1.4, HALL_A.z * 1.4, Color(0.55, 0.85, 1.0), 60)
	TerracePlaces._haze(room, Vector3(POOL.x, 0.3, POOL.y), Vector3(POOL.z * 2.2, 0.8, POOL.w * 2.2), 0.015)
	_shadows(_piece(room, "TPoolRim", Vector3.ZERO), GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	_shadows(_piece(room, "THoleRim", Vector3.ZERO), GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED)
	var slab := _piece(room, "TSlab", Vector3(POOL.x + 1.0, -0.15, POOL.y - 2.0), 0.4)
	_shadows(slab, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	# the sky seen up through the hole: a bright disc over it (the sky
	# itself showed dull grey through the haze up there)
	var sky := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 7.0
	disc.bottom_radius = 7.0
	disc.height = 0.1
	sky.mesh = disc
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.albedo_color = Color(0.86, 0.92, 0.98)
	sm.disable_fog = true
	sky.material_override = sm
	sky.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sky.position = Vector3(0.0, HALL_A.w + 3.5, cz)
	room.add_child(sky)

	var pool_glow := OmniLight3D.new()
	pool_glow.light_color = Color(0.35, 0.92, 0.85)
	pool_glow.light_energy = 1.1
	pool_glow.omni_range = 10.0
	pool_glow.position = Vector3(POOL.x - 2.0, 1.2, POOL.y)
	pool_glow.set_meta(&"designed_shadow", false)
	room.add_child(pool_glow)
	# boulders on the floor's edges
	for k in 6:
		var a := rng.randf() * TAU
		var at := Vector3(cos(a) * HALL_A.y * 0.75, 0.0, cz + sin(a) * HALL_A.z * 0.75)
		if absf(at.x) < 7.0 or Vector2((at.x - POOL.x) / POOL.z, (at.z - POOL.y) / POOL.w).length() < 1.4:
			continue
		if _near_portal(at):
			continue
		var b := _piece(room, "TBoulder%d" % rng.randi_range(0, 2), at, rng.randf_range(0.0, TAU))
		_solid_hull(b)
	# the shaft of light down from the hole, seen in the air
	# (a thin air filling the hall's middle: only the sun's slant through the
	# hole lights it, so the shaft is drawn where the light really goes)
	var air := FogVolume.new()
	air.shape = RenderingServer.FOG_VOLUME_SHAPE_ELLIPSOID
	air.size = Vector3(26.0, 30.0, 30.0)
	air.position = Vector3(0.0, 6.0, cz)
	var am := FogMaterial.new()
	am.density = 0.005
	am.albedo = Color(0.95, 0.92, 0.86)
	# its edge soft, or the air's box shows against the dark (2026-10-25)
	am.edge_fade = 1.0
	air.material = am
	if Graphics.current != Graphics.Level.LOW:
		room.add_child(air)


## Whether a spot (kit frame) is near where the portals or the way out
## stand: in the room at (±9, -l/2+10) and (0, -l/2+15), at the hall's far
## end; in the kit's frame, turned, at +z.
static func _near_portal(at: Vector3) -> bool:
	for spot: Vector3 in [Vector3(9.0, 0.0, 45.0), Vector3(-9.0, 0.0, 45.0), Vector3(0.0, 0.0, 40.0)]:
		if Vector2(at.x - spot.x, at.z - spot.z).length() < 5.0:
			return true
	return false


## The pool's water as in the picture the user chose (A1, 2026-10-26):
## bright turquoise and clear, its pale bed seen through it, slow rings of
## ripples spreading over it, light playing on the bed.
const POOL_WATER := """
shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_disabled, specular_schlick_ggx;
uniform vec4 shallow : source_color = vec4(0.36, 0.92, 0.88, 1.0);
uniform vec4 deep : source_color = vec4(0.03, 0.50, 0.60, 1.0);
uniform vec2 centre = vec2(0.0);
uniform float depth_reach = 0.6;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D depth_tex : hint_depth_texture, filter_linear_mipmap;
varying vec3 wp;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
float rings(vec2 p) {
	float r = 0.0;
	for (int i = 0; i < 3; i++) {
		vec2 c = centre + vec2(sin(float(i) * 2.1) * 1.4, cos(float(i) * 1.7) * 2.6);
		float d = length(p - c);
		r += sin(d * 3.0 - TIME * 0.9 + float(i) * 2.0) * exp(-d * 0.3);
	}
	return r / 3.0;
}
void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += rings(wp.xz) * 0.006;
}
void fragment() {
	float e = 0.08;
	float h = rings(wp.xz);
	vec2 slope = vec2(rings(wp.xz + vec2(e, 0.0)) - h, rings(wp.xz + vec2(0.0, e)) - h) / e;
	vec3 nw = normalize(vec3(-slope.x * 0.05, 1.0, -slope.y * 0.05));
	NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);
	float d = texture(depth_tex, SCREEN_UV).r;
	vec4 behind = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, d, 1.0);
	behind.xyz /= behind.w;
	float depth = clamp(VERTEX.z - behind.z, 0.0, 20.0);
	float k = 1.0 - exp(-depth / depth_reach);
	vec3 bed = textureLod(screen_tex, SCREEN_UV + slope * 0.01 * k, 0.0).rgb;
	vec3 c = mix(bed * shallow.rgb * 1.1 + shallow.rgb * 0.22, deep.rgb, k * 0.8);
	c += vec3(0.75, 1.0, 1.0) * smoothstep(0.35, 0.9, h) * 0.12;
	float play = pow(vnoise(wp.xz * 1.8 + vec2(TIME * 0.15, TIME * 0.1)) * vnoise(wp.xz * 2.6 - vec2(TIME * 0.12, 0.0)), 1.4);
	ALBEDO = c;
	EMISSION = vec3(0.30, 0.90, 0.90) * (0.06 + 0.35 * play * (1.0 - k * 0.6));
	ROUGHNESS = 0.05;
	SPECULAR = 0.5;
	ALPHA = smoothstep(0.0, 0.03, depth);
}
"""
static var _pool_shader: Shader


static func _pool_water() -> ShaderMaterial:
	if _pool_shader == null:
		_pool_shader = Shader.new()
		_pool_shader.code = POOL_WATER
	var m := ShaderMaterial.new()
	m.shader = _pool_shader
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
	_shadows(_piece(gate, "TGateFrame", Vector3.ZERO), GeometryInstance3D.SHADOW_CASTING_SETTING_ON)
	for side: float in [-1.0, 1.0]:
		var leaf := _piece(gate, "TGateLeaf", Vector3(side * LEAF_HINGE, 0.0, 0.0), 0.0 if side < 0.0 else PI)
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
	var t := _piece(room, "TTorch", at, yaw)
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


## An iron fire-bowl on its legs, its fire and warm light (D1).
static func _brazier(room: Node3D, at: Vector3, rng: RandomNumberGenerator) -> void:
	var b := _piece(room, "TBrazier", at, rng.randf_range(0.0, TAU) if rng != null else 0.0)
	TerracePlaces._post_col(b, 0.45, 1.1)
	var tip := at + Vector3(0.0, 1.05, 0.0)
	CryptTomb._flames(room, tip, [Vector3.ZERO], Color(1.0, 0.62, 0.3), false, 2.0)
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.66, 0.38)
	lamp.light_energy = 3.5
	lamp.omni_range = 11.0
	lamp.position = tip + Vector3(0.0, 0.6, 0.0)
	lamp.set_meta(&"designed_shadow", false)
	room.add_child(lamp)


## The den: stalagmites like teeth round it, torches, the dead, the mouth's
## cold light.
static func _den(d: Dungeon, room: Node3D, rng: RandomNumberGenerator) -> void:
	var cz := HALL_D.x
	var n := 22
	for k in n:
		var a := TAU * (float(k) + rng.randf_range(-0.3, 0.3)) / float(n)
		var dir := Vector2(cos(a), sin(a))
		var at := Vector3(dir.x * HALL_D.y * rng.randf_range(0.72, 0.88), 0.0, cz + dir.y * HALL_D.z * rng.randf_range(0.72, 0.88))
		# the tunnel's end and the mouth kept clear (the portals stand there)
		if absf(at.x) < 7.0 and (at.z > cz + 8.0 or at.z < cz - 10.0):
			continue
		var f := _piece(room, "TFang%d" % rng.randi_range(0, 3), at, rng.randf_range(0.0, TAU))
		f.scale = Vector3.ONE * rng.randf_range(0.8, 1.3)
		_solid_hull(f)
	# hanging teeth from the roof are the shell's; a few fallen at the sides
	for k in 5:
		var side := -1.0 if k % 2 == 0 else 1.0
		var at := Vector3(side * rng.randf_range(13.0, 18.0), 0.0, cz + rng.randf_range(-12.0, 10.0))
		var b := _piece(room, "TBoulder%d" % rng.randi_range(1, 3), at, rng.randf_range(0.0, TAU))
		_solid_hull(b)
	# torches on stakes round the floor, not in the middle
	var torches := [Vector3(-11.0, 0.0, cz + 12.0), Vector3(11.5, 0.0, cz + 11.0), Vector3(-14.0, 0.0, cz - 2.0),
			Vector3(14.0, 0.0, cz - 3.0), Vector3(-10.5, 0.0, cz - 14.0), Vector3(10.5, 0.0, cz - 14.5)]
	for at: Vector3 in torches:
		_torch(room, at * Vector3(1.25, 1.0, 1.0), rng.randf_range(0.0, TAU))
	# the dead: bones by the walls, a rusted shield or two
	OrcSpoils._materials()
	for k in 7:
		var a := rng.randf() * TAU
		var at := Vector3(cos(a) * HALL_D.y * 0.68, 0.0, cz + sin(a) * HALL_D.z * 0.6)
		if absf(at.x) < 6.0:
			at.x = 6.0 * signf(at.x + 0.01)
		OrcSpoils._bone_heap(d, room, at, rng)
	for k in 2:
		var at := Vector3((-1.0 if k == 0 else 1.0) * rng.randf_range(8.0, 12.0), 0.02, cz + rng.randf_range(-6.0, 8.0))
		_piece(room, "TShield", at, rng.randf_range(0.0, TAU))
	# the cold blue of the dusk in at the mouth
	var dusk := SpotLight3D.new()
	dusk.light_color = Color(1.0, 0.82, 0.62)
	dusk.light_energy = 3.0
	dusk.spot_range = 45.0
	dusk.spot_angle = 55.0
	dusk.position = Vector3(0.0, 7.0, cz - HALL_D.z - 6.0)
	dusk.rotation = Vector3(-deg_to_rad(12.0), 0.0, 0.0)
	dusk.set_meta(&"designed_shadow", false)
	room.add_child(dusk)
	# a thin mist lying in the mouth (thick, standing in it whites all out)
	TerracePlaces._haze(room, Vector3(0.0, 1.5, cz - HALL_D.z + 4.0), Vector3(24.0, 3.0, 8.0), 0.008)


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
	# a soft glow from within, not a lamp (the user's word, 2026-10-25: the
	# crystals far too bright)
	_crystal_mat.albedo_color = Color(0.70, 1.0, 0.95)
	_crystal_mat.roughness = 0.12
	_crystal_mat.emission_enabled = true
	_crystal_mat.emission = Color(0.10, 0.55, 0.52)
	_crystal_mat.emission_energy_multiplier = 0.5
	_water_mat = StandardMaterial3D.new()
	# dark and still: it gives back the crystals' glow, not the white sky
	_water_mat.albedo_color = Color(0.02, 0.06, 0.08)
	_water_mat.roughness = 0.45
	_water_mat.metallic_specular = 0.12
	_water_mat.emission_enabled = true
	_water_mat.emission = Color(0.02, 0.08, 0.14)
	_kit = (load(KIT) as PackedScene).instantiate() as Node3D
	for mi: MeshInstance3D in _kit.find_children("*", "MeshInstance3D", true, false):
		var mesh := mi.mesh
		for s in mesh.get_surface_count():
			var mat := mesh.surface_get_material(s)
			match String(mat.resource_name) if mat != null else "":
				"Crystal":
					mi.set_surface_override_material(s, _crystal_mat)
				"Water":
					mi.set_surface_override_material(s, _water_mat)
				"Iron", "Rust":
					mi.set_surface_override_material(s, TerracePlaces._solid(0.0, 1.0, 0.5))
				"Wood":
					mi.set_surface_override_material(s, TerracePlaces._solid(0.0, 1.0, 0.95))
				"Far":
					mi.set_surface_override_material(s, TerracePlaces._solid(0.0, 1.0, 1.0))
				_:
					mi.set_surface_override_material(s, TerracePlaces._solid(0.0, 1.2, 0.92))


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
