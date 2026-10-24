class_name CryptTomb
extends RefCounted

## The flooded crypt and the stone king's tomb behind it (the user's pick,
## 2026-10-24: sketch D's flooded crypt, but wide enough to run and fight in,
## A's vaults over it; through an arch at its end the king's tomb, sketch K
## without its pharaohs). High-end low poly as the forest: the pieces in
## `crypt_lowpoly.glb` (Blender, `vepxis-art/world/crypt_lowpoly.py`).
##
## The hall (z from −13 to the door at +l/2): ankle-deep water over the whole
## floor (walked through, not swum: the walking floor is the slabs under it),
## the old path down the nave just under the water, two rows of thick pillars
## under groin vaults broken open in places, the sun coming down through the
## holes; sarcophagi in the aisles, candles. The tomb (z from −13 to −l/2):
## dry, a tall pitched ceiling, guardians on plinths (heroes' statues in
## stone), braziers burning blue, the gold sarcophagus on its dais, and at the
## back the stone king on his throne ([TombKing] wakes him when the place's
## creatures are down).

const DIR := "res://assets/dungeon/crypt/"
const KIT := DIR + "crypt_lowpoly.glb"
## Where the hall ends and the tomb begins (room space z).
const SPLIT := -13.0
const WATER_Y := 0.10
## The heroes standing guard in the tomb (no hero twice in a place; the
## user's word, 2026-10-24: different heroes in different places).
const GUARDS := ["rogue", "elf_mage", "dark_rogue", "tariel", "elf_archer", "dark_mage"]
## Where the king sits (room space), facing the way in.
const THRONE_AT := Vector3(0.0, 0.0, -45.5)
## The seated king baked from the golem's body (`_shots_tmp/bake_king.gd`),
## where his statue sits and where he stands once he has risen.
const KING_STATUE := DIR + "king_statue.res"
const KING_SEAT := Vector3(0.0, 0.15, -45.75)
const THRONE_SCALE := 0.7
const KING_STAND := Vector3(0.0, 0.0, -41.0)
## The king himself: the golem's body with his crown and sword ([TombKing]
## in [Dungeon]: made with the place's creatures, woken when they are down).
const KING_SCENE := "res://scenes/enemies/pack/golem.tscn"
const KING_NAME := "ქვის მეფე"
const KING_HEALTH := 2200.0

## Shallow water: clear over the slabs (feet and legs seen in it), tinted
## teal, darker by the walls; slow ripples, the light's caustics moving on it,
## pools of brighter light under the vaults' holes; rings spreading from
## every step taken in it and a little foam round whoever stands in it
## ([CryptWater] feeds `drops`, `bodies` and `now`).
const SHALLOW := """
shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back, diffuse_burley, specular_schlick_ggx;
uniform vec4 tint : source_color = vec4(0.30, 0.66, 0.66, 1.0);
uniform vec4 deep : source_color = vec4(0.05, 0.20, 0.24, 1.0);
uniform vec4 foam_col : source_color = vec4(0.86, 0.94, 0.96, 1.0);
uniform vec4 sun_col : source_color = vec4(1.0, 0.94, 0.80, 1.0);
uniform vec4 drops[24];
uniform vec4 bodies[8];
uniform vec4 pools[4];
uniform float now = 0.0;
uniform vec2 half_size = vec2(22.0, 31.5);
uniform vec2 centre = vec2(0.0, 0.0);
uniform sampler2D depth_tex : hint_depth_texture, filter_linear_mipmap;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
varying vec3 wpos;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}
float rings(vec2 p) {
	float h = 0.0;
	for (int k = 0; k < 24; k++) {
		vec4 d = drops[k];
		float age = now - d.z;
		if (d.w <= 0.0 || age < 0.0 || age > 2.4) continue;
		float r = 0.2 + age * 1.15;
		float dist = distance(p, d.xy);
		float band = exp(-pow((dist - r) * 4.0, 2.0));
		h += sin((dist - r) * 14.0) * band * (1.0 - age / 2.4) * d.w;
	}
	return h;
}
float swell(vec2 p, float t) {
	return noise(p * 0.7 + vec2(t * 0.1, t * 0.07)) * 0.6 + noise(p * 1.5 - vec2(t * 0.16, -t * 0.12)) * 0.4;
}
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float t = TIME;
	float e = 0.05;
	vec2 p = wpos.xz;
	// the base swell gentle, the rings from steps sharper
	float b0 = swell(p, t);
	float r0 = rings(p);
	float sx = (b0 - swell(p + vec2(e, 0.0), t)) / e * 0.012 + (r0 - rings(p + vec2(e, 0.0))) / e * 0.05;
	float sz = (b0 - swell(p + vec2(0.0, e), t)) / e * 0.012 + (r0 - rings(p + vec2(0.0, e))) / e * 0.05;
	vec3 n = normalize(vec3(sx, 1.0, sz));
	NORMAL = (VIEW_MATRIX * vec4(n, 0.0)).xyz;
	// what is under it, bent by the ripples
	float d = texture(depth_tex, SCREEN_UV).r;
	vec4 v = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, d, 1.0);
	v.xyz /= v.w;
	float under = clamp((VERTEX.z - v.z) / 0.8, 0.0, 1.0);
	vec3 below = texture(screen_tex, SCREEN_UV + n.xz * 0.02).rgb;
	// darker towards the walls, where it is deeper
	vec2 q = abs(p - centre) / half_size;
	float edge = smoothstep(0.7, 1.0, max(q.x, q.y));
	vec3 col = below * tint.rgb * 1.35;
	col = mix(col, deep.rgb, clamp(under * 0.35 + edge * 0.45, 0.0, 1.0));
	// the light's caustics, and the pools of it under the holes
	float c1 = noise(p * 1.6 + vec2(t * 0.35, t * 0.22));
	float c2 = noise(p * 2.1 - vec2(t * 0.28, -t * 0.4));
	float caus = smoothstep(0.55, 0.85, 1.0 - abs(c1 - c2) * 2.2);
	float lit = 0.0;
	for (int k = 0; k < 4; k++) {
		if (pools[k].z <= 0.0) continue;
		float dd = distance(p, pools[k].xy) / pools[k].z;
		lit += (1.0 - smoothstep(0.6, 1.0, dd)) * pools[k].w;
	}
	// (outside the pools only a breath of it: in the dark crypt even a little
	// light of its own showed the whole water patterned)
	vec3 glow = sun_col.rgb * lit * (0.25 + caus * 0.6) + vec3(0.5, 0.85, 0.95) * caus * 0.016;
	// foam round whoever stands in it, and on the young rings
	float foam = 0.0;
	for (int k = 0; k < 8; k++) {
		if (bodies[k].w <= 0.0) continue;
		float dist = distance(p, bodies[k].xy);
		foam += exp(-pow((dist - bodies[k].z) * 7.0, 2.0)) * bodies[k].w;
	}
	foam = clamp(foam * (0.5 + noise(p * 9.0 + t) * 0.6), 0.0, 1.0);
	float fres = pow(1.0 - clamp(dot(normalize(VIEW), NORMAL), 0.0, 1.0), 4.0);
	ALBEDO = mix(col, foam_col.rgb, foam * 0.7);
	EMISSION = glow + foam_col.rgb * foam * 0.08;
	// broad, soft reflections (sharp ones blotched it white at a slant);
	// the rings' crests caught by the light instead
	ROUGHNESS = 0.28;
	METALLIC = 0.0;
	SPECULAR = 0.4;
	EMISSION += vec3(0.55, 0.75, 0.85) * clamp(r0, 0.0, 1.0) * 0.22;
	ALPHA = clamp(0.62 + fres * 0.2 + edge * 0.2 + foam * 0.4, 0.0, 0.95);
}
"""

static var _kit: Node3D


static func build(d: Dungeon, room: Node3D, w: float, l: float, rng: RandomNumberGenerator) -> void:
	_ready_kit()
	var hw := w * 0.5
	var hl := l * 0.5
	_floor(d, room, w, l)
	_hall(d, room, hw, hl, rng)
	_tomb(d, room, hw, hl, rng)
	TerracePlaces._motes(room, w, l, Color(0.82, 0.86, 0.92), 200)
	TerracePlaces._haze(room, Vector3(0.0, 6.0, (hl + SPLIT) * 0.5), Vector3(w, 12.0, hl - SPLIT), 0.003)


# ---------------------------------------------------------------- the kit
static func _ready_kit() -> void:
	if _kit != null and is_instance_valid(_kit):
		return
	_kit = (load(KIT) as PackedScene).instantiate() as Node3D
	for mi: MeshInstance3D in _kit.find_children("*", "MeshInstance3D", true, false):
		var mesh := mi.mesh
		for s in mesh.get_surface_count():
			var mat := mesh.surface_get_material(s)
			match String(mat.resource_name) if mat != null else "":
				"Gold", "Bronze":
					mi.set_surface_override_material(s, TerracePlaces._solid(0.0, 1.1, 0.45))
				"Wax":
					mi.set_surface_override_material(s, TerracePlaces._solid(0.0, 1.2, 0.6))
				"Marble":
					mi.set_surface_override_material(s, TerracePlaces._solid(0.12, 1.0, 0.55))
				"Root":
					mi.set_surface_override_material(s, TerracePlaces._solid(0.0, 1.0, 0.9))
				_:
					mi.set_surface_override_material(s, TerracePlaces._solid(0.25))


static func _piece(room: Node3D, piece: String, at: Vector3, yaw: float = 0.0, s: float = 1.0) -> Node3D:
	var src := _kit.get_node_or_null(piece) as Node3D
	if src == null:
		push_warning("CryptTomb: no piece " + piece)
		return null
	var n := src.duplicate() as Node3D
	n.transform = Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * s), at)
	room.add_child(n)
	return n


static func _floor(d: Dungeon, room: Node3D, w: float, l: float) -> void:
	var slab := d._solid(room, TerracePlaces._solid(0.0), Vector3(w + 2.0, 1.0, l + 2.0), Vector3(0.0, -0.5, 0.0))
	for mi in slab.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).visible = false
	var f := _piece(room, "KFloor", Vector3.ZERO)
	if f != null:
		for g in f.find_children("*", "GeometryInstance3D", true, false) + [f]:
			if g is GeometryInstance3D:
				(g as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	d._bounds(room, w, l)


## A wall from `a` to `b` of `piece` bays, its face to the room (`yaw`), and
## a box behind it no one walks through.
static func _wall(room: Node3D, a: Vector3, b: Vector3, yaw: float, piece: String, n: int, h: float,
		middle: String = "", alt: String = "") -> void:
	var along := b - a
	for k in n:
		var name := middle if middle != "" and k == int(n / 2.0) else piece
		if alt != "" and k % 2 == 1:
			name = alt
		var at := a + along * ((float(k) + 0.5) / float(n))
		var seg := _piece(room, name, at, yaw)
		if seg != null:
			seg.scale.x = along.length() / float(n) / (12.0 if name == "KWallArch" else 8.0) * 1.003
		if name == "KWallNiche":
			# candles in the niche (its back 0.3 m into the wall's face)
			var inside := at + Basis(Vector3.UP, yaw) * Vector3(0.0, 1.26, 0.55)
			_piece(room, "KCandles", inside, yaw)
			_flames(room, inside + Vector3(0.0, 0.32, 0.0), [Vector3.ZERO], Color(1.0, 0.7, 0.36), false, 0.8)
	var holder := Node3D.new()
	holder.position = (a + b) * 0.5
	room.add_child(holder)
	var size := Vector3(absf(along.x) + 2.0, h + Dungeon.BLOCK_H, absf(along.z) + 2.0)
	if middle == "KWallArch":
		# the arch kept open: two boxes either side of it
		var side := (along.length() - 8.0) * 0.5
		for sx: float in [-1.0, 1.0]:
			TerracePlaces._box(holder, Vector3(side, size.y, 2.0), Vector3(sx * (4.0 + side * 0.5), size.y * 0.5, 0.0))
		TerracePlaces._box(holder, Vector3(8.0, size.y - 11.0, 2.0), Vector3(0.0, 11.0 + (size.y - 11.0) * 0.5, 0.0))
	else:
		TerracePlaces._box(holder, size, Vector3(0.0, size.y * 0.5, 0.0))


static func _cap(room: Node3D, at: Vector3, size: Vector3) -> void:
	var lid := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	lid.mesh = bm
	lid.material_override = _dark_stone()
	lid.position = at
	room.add_child(lid)


## The plain stone of lids and fills, out of sight above the vaults (a box
## has no colours of its own: the low-poly shader would draw it white).
static var _dark: StandardMaterial3D
static func _dark_stone() -> StandardMaterial3D:
	if _dark == null:
		_dark = StandardMaterial3D.new()
		_dark.albedo_color = Color(0.16, 0.18, 0.21)
		_dark.roughness = 1.0
	return _dark


static func _shadows_both(n: Node3D) -> void:
	for g in n.find_children("*", "GeometryInstance3D", true, false) + [n]:
		if g is GeometryInstance3D:
			(g as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED


# ---------------------------------------------------------------- the hall
static func _hall(d: Dungeon, room: Node3D, hw: float, hl: float, rng: RandomNumberGenerator) -> void:
	var h := 15.0
	var z0 := SPLIT
	var z1 := hl
	# walls: the long sides, the doors behind the way in, the arch at the end
	_wall(room, Vector3(-hw - 1.0, 0.0, z0 - 1.0), Vector3(-hw - 1.0, 0.0, z1 + 1.0), PI * 0.5, "KWall", 8, h, "", "KWallNiche")
	_wall(room, Vector3(hw + 1.0, 0.0, z0 - 1.0), Vector3(hw + 1.0, 0.0, z1 + 1.0), -PI * 0.5, "KWall", 8, h, "", "KWallNiche")
	_wall(room, Vector3(-hw - 2.0, 0.0, z1 + 1.0), Vector3(hw + 2.0, 0.0, z1 + 1.0), PI, "KWall", 5, h, "KWallDoor")
	# the end wall: the arch (12 m piece) in the middle, plain bays beside it
	var arch := _piece(room, "KWallArch", Vector3(0.0, 0.0, z0 - 1.0), 0.0)
	for sx: float in [-1.0, 1.0]:
		for k in 2:
			_piece(room, "KWall", Vector3(sx * (6.0 + 4.0 + float(k) * 8.0), 0.0, z0 - 1.0), 0.0)
	var endw := Node3D.new()
	endw.position = Vector3(0.0, 0.0, z0 - 1.0)
	room.add_child(endw)
	var full := h + Dungeon.BLOCK_H
	for sx: float in [-1.0, 1.0]:
		TerracePlaces._box(endw, Vector3(hw - 4.0 + 2.0, full, 2.0), Vector3(sx * (4.0 + (hw - 4.0 + 2.0) * 0.5), full * 0.5, 0.0))
	TerracePlaces._box(endw, Vector3(8.0, full - 15.0, 2.0), Vector3(0.0, 15.0 + (full - 15.0) * 0.5, 0.0))
	if arch == null:
		push_warning("CryptTomb: no arch")
	# two rows of pillars under groin vaults; holes broken in some, the sun
	# down through them
	var zs: Array[float] = []
	var z := z1 - 4.0
	while z > z0 + 1.0:
		zs.append(z)
		z -= 8.0
	for cz: float in zs:
		for sx: float in [-1.0, 1.0]:
			var p := _piece(room, "KPillar", Vector3(sx * 10.0, 0.0, cz))
			if p != null:
				TerracePlaces._post_col(p, 1.35, 9.0)
	var holes := {"n2": true, "n5": true, "a3": true}
	for k in zs.size() - 1:
		var cz := (zs[k] + zs[k + 1]) * 0.5
		var nave := _piece(room, "KVaultNaveHole" if holes.has("n%d" % k) else "KVaultNave", Vector3(0.0, 9.0, cz))
		if nave != null:
			_shadows_both(nave)
		# a lid over each whole bay above its vault (over the gaps between
		# the nave's and the aisles' vaults); none over the broken ones
		if not holes.has("n%d" % k):
			_cap(room, Vector3(0.0, 14.4, cz), Vector3(20.0, 0.5, 8.0))
		for sx: float in [-1.0, 1.0]:
			var hole := holes.has("a%d" % k) and sx < 0.0
			var aisle := _piece(room, "KVaultAisleHole" if hole else "KVaultAisle", Vector3(sx * 16.0, 9.0, cz))
			if aisle != null:
				_shadows_both(aisle)
			if not hole:
				_cap(room, Vector3(sx * 16.0, 14.4, cz), Vector3(12.4, 0.5, 8.0))
			# the gap between the aisle's vault and the nave's, over the pillars
			_cap(room, Vector3(sx * 10.2, 11.7, cz), Vector3(0.8, 5.4, 8.0))
	# the ends of the vaults (between the last pillars and the walls): plain
	# stone over them
	for ends: Vector2 in [Vector2(zs[0], z1 + 1.0), Vector2(z0 - 1.0, zs[zs.size() - 1])]:
		var lid := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(hw * 2.0 + 2.0, 0.6, absf(ends.y - ends.x))
		lid.mesh = bm
		lid.material_override = _dark_stone()
		lid.position = Vector3(0.0, 9.3, (ends.x + ends.y) * 0.5)
		room.add_child(lid)
	# the vaults' end arches closed above the spring, and a lid over the ends
	for ez: float in [zs[0], zs[zs.size() - 1]]:
		_cap(room, Vector3(0.0, 11.9, ez), Vector3(hw * 2.0 + 2.0, 5.6, 0.8))
	# the water over the whole hall, the old path under it down the nave
	var water := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(hw * 2.0, z1 - z0)
	water.mesh = plane
	# (its own copy: the rings and pools are this place's)
	var m := TerracePlaces._code("crypt_water", SHALLOW).duplicate() as ShaderMaterial
	water.material_override = m
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	water.position = Vector3(0.0, WATER_Y, (z0 + z1) * 0.5)
	room.add_child(water)
	m.set_shader_parameter("half_size", Vector2(hw, (z1 - z0) * 0.5))
	var ripples := CryptWater.new()
	ripples.name = "Ripples"
	# the light's pools under the holes broken in the vaults (room space)
	var pools: Array[Vector3] = []
	for key: String in holes:
		var k := int(key.substr(1))
		if k + 1 < zs.size():
			pools.append(Vector3(-16.0 if key.begins_with("a") else 0.0, (zs[k] + zs[k + 1]) * 0.5, 3.4))
	ripples.setup(d, water, m, Vector2(hw, (z1 - z0) * 0.5), pools)
	room.add_child(ripples)
	_piece(room, "KWalk", Vector3(0.0, 0.0, (z0 + z1) * 0.5 + 0.5))
	# the sun's shafts down through the holes: a denser air there for the
	# light to show in
	for key: String in holes:
		var k := int(key.substr(1))
		if k + 1 >= zs.size():
			continue
		var fv := FogVolume.new()
		fv.shape = RenderingServer.FOG_VOLUME_SHAPE_CYLINDER
		fv.size = Vector3(6.0, 10.0, 6.0)
		var fm := FogMaterial.new()
		fm.density = 0.06
		fm.albedo = Color(1.0, 0.98, 0.94)
		fv.material = fm
		fv.position = Vector3(-16.0 if key.begins_with("a") else 0.0, 4.6, (zs[k] + zs[k + 1]) * 0.5)
		room.add_child(fv)
	# iron rings of candles hung over the nave
	for k: int in [1, 4]:
		if k + 1 >= zs.size():
			continue
		var cz := (zs[k] + zs[k + 1]) * 0.5
		var top := Vector3(0.0, 13.6 - 4.5, cz)
		_piece(room, "KChandelier", top, rng.randf_range(0.0, TAU))
		var tips: Array = []
		for c in 8:
			var a := TAU * float(c) / 8.0
			tips.append(Vector3(cos(a) * 1.3, 0.35, sin(a) * 1.3))
		_flames(room, top, tips, Color(1.0, 0.72, 0.4), false)
		var o := OmniLight3D.new()
		o.light_color = Color(1.0, 0.74, 0.44)
		o.light_energy = 2.2
		o.omni_range = 13.0
		o.position = top + Vector3(0.0, -0.6, 0.0)
		room.add_child(o)
	# candles floating on the water, drifting a little
	for k in 16:
		var at := Vector3(rng.randf_range(-20.0, 20.0), WATER_Y - 0.01, rng.randf_range(z0 + 3.0, z1 - 3.0))
		if absf(absf(at.x) - 10.0) < 2.0:
			at.x += 3.0 * signf(at.x)
		var fc := _piece(room, "KFloatCandle", at, rng.randf_range(0.0, TAU))
		if fc == null:
			continue
		_flames(fc, Vector3(0.0, 0.3, 0.0), [Vector3(-0.07, 0.0, 0.0), Vector3(0.08, -0.04, 0.0)], Color(1.0, 0.74, 0.4), false, 0.7)
		var tw := fc.create_tween().set_loops()
		var drift := Vector3(rng.randf_range(-0.5, 0.5), 0.0, rng.randf_range(-0.5, 0.5))
		var t := rng.randf_range(5.0, 9.0)
		tw.tween_property(fc, "position", at + drift + Vector3(0.0, 0.015, 0.0), t).set_trans(Tween.TRANS_SINE)
		tw.tween_property(fc, "position", at, t).set_trans(Tween.TRANS_SINE)
	# sarcophagi in the aisles, candles by the pillars
	var kinds := ["KSarc0", "KSarcAskew", "KSarc1", "KSarc0", "KSarc1", "KSarcAskew", "KSarc0"]
	for k in mini(kinds.size(), zs.size() - 1):
		var cz := (zs[k] + zs[k + 1]) * 0.5
		for sx: float in [-1.0, 1.0]:
			var at := Vector3(sx * 16.5, 0.0, cz + rng.randf_range(-1.0, 1.0))
			var sarc := _piece(room, String(kinds[(k + (1 if sx > 0.0 else 0)) % kinds.size()]), at, rng.randf_range(-0.12, 0.12))
			if sarc != null:
				TerracePlaces._box(sarc, Vector3(1.6, 1.4, 2.8), Vector3(0.0, 0.7, 0.0))
	var lit := 0
	for k in zs.size():
		if k % 2 == 1:
			continue
		for sx: float in [-1.0, 1.0]:
			var at := Vector3(sx * 8.3, 0.0, zs[k] - 1.6)
			var c := _piece(room, "KCandelabra", at, rng.randf_range(0.0, TAU))
			if c != null:
				TerracePlaces._post_col(c, 0.3, 1.8)
			_flames(room, at + Vector3(0.0, 1.95, 0.0), [Vector3(-0.32, 0.0, 0.0), Vector3(0.0, 0.1, 0.0), Vector3(0.32, 0.0, 0.0)],
					Color(1.0, 0.72, 0.38), lit < 6)
			lit += 1


# ---------------------------------------------------------------- the tomb
static func _tomb(d: Dungeon, room: Node3D, hw: float, hl: float, rng: RandomNumberGenerator) -> void:
	var h := 16.0
	var tw := 15.0
	var z0 := -hl
	var z1 := SPLIT - 2.0
	_wall(room, Vector3(-tw - 1.0, 0.0, z0 - 1.0), Vector3(-tw - 1.0, 0.0, z1), PI * 0.5, "KTombWall", 5, h)
	_wall(room, Vector3(tw + 1.0, 0.0, z0 - 1.0), Vector3(tw + 1.0, 0.0, z1), -PI * 0.5, "KTombWall", 5, h)
	_wall(room, Vector3(-tw - 2.0, 0.0, z0 - 1.0), Vector3(tw + 2.0, 0.0, z0 - 1.0), 0.0, "KTombWall", 4, h)
	var roof := _piece(room, "KTombRoof", Vector3(0.0, h, (z0 + z1) * 0.5 - 0.5))
	if roof != null:
		roof.scale = Vector3((tw * 2.0 + 2.0) / 30.0, 1.0, (z1 - z0 + 2.0) / 38.0)
		_shadows_both(roof)
	# the king's throne at the back, the gold sarcophagus on its dais before it
	var throne := _piece(room, "KThrone", THRONE_AT, 0.0, THRONE_SCALE)
	if throne != null:
		TerracePlaces._box(throne, Vector3(6.5, 1.2, 3.4), Vector3(0.0, 0.6, 0.0))
		TerracePlaces._box(throne, Vector3(3.6, 7.0, 2.4), Vector3(0.0, 3.5, -0.6))
	_king_statue(room)
	var dais := _piece(room, "KTombDais", Vector3(0.0, 0.0, -28.0))
	if dais != null:
		TerracePlaces._box(dais, Vector3(5.0, 0.6, 6.0), Vector3(0.0, 0.3, 0.0))
	var gold := _piece(room, "KSarcGold", Vector3(0.0, 0.6, -28.0))
	if gold != null:
		TerracePlaces._box(gold, Vector3(1.6, 1.4, 2.8), Vector3(0.0, 0.7, 0.0))
	# guardians along the walls, heroes in grey stone on plinths, facing in
	var k := 0
	for sx: float in [-1.0, 1.0]:
		for gz: float in [-21.0, -31.0, -41.0]:
			var at := Vector3(sx * (tw - 2.2), 0.0, gz)
			_guard(room, at, -sx * PI * 0.5, String(GUARDS[k % GUARDS.size()]))
			k += 1
	# braziers burning blue
	for at: Vector3 in [Vector3(-6.0, 0.0, -22.0), Vector3(6.0, 0.0, -22.0), Vector3(-5.0, 0.0, -44.0), Vector3(5.0, 0.0, -44.0)]:
		var b := _piece(room, "KBrazier", at)
		if b != null:
			TerracePlaces._post_col(b, 0.5, 1.6)
		_flames(room, at + Vector3(0.0, 1.6, 0.0), [Vector3.ZERO], Color(0.45, 0.65, 1.0), true, 2.2)
	# the tomb's own cold light, violet from above
	for z: float in [-24.0, -40.0]:
		var o := OmniLight3D.new()
		o.light_color = Color(0.56, 0.46, 1.0)
		o.light_energy = 1.4
		o.omni_range = 22.0
		o.position = Vector3(0.0, 11.0, z)
		room.add_child(o)


static func _king_statue(room: Node3D) -> void:
	if not ResourceLoader.exists(KING_STATUE):
		return
	var mi := MeshInstance3D.new()
	mi.name = "KingStatue"
	mi.mesh = load(KING_STATUE) as Mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.60, 0.58, 0.64)
	mat.roughness = 0.9
	mi.material_override = mat
	mi.transform = Transform3D(Basis(Vector3.UP, PI), KING_SEAT)
	room.add_child(mi)


## The statue gone as the king rises: dust bursting from it, stones falling,
## the rumble (each peer's own, when [Dungeon] says so).
static func wake_statue(d: Dungeon, room: Node3D) -> void:
	if room == null or not is_instance_valid(room):
		return
	var statue := room.get_node_or_null(^"KingStatue") as Node3D
	var at := room.global_position + KING_SEAT + Vector3(0.0, 1.6, 0.0)
	var world := Blood.world_of(d)
	if world != null:
		SkillFx.burst(world, at, Color(0.62, 0.6, 0.66, 0.8), 60, Vector2(1.0, 4.0), Vector3.UP, 180.0,
				Vector2(0.15, 0.4), Vector3(0, -3.0, 0), 1.6)
		DustRing.burst(world, room.global_position + KING_STAND + Vector3.UP * 0.05, 1.2)
	Sfx.play(d, Dungeon.SND + "crumble.wav", null, at, 0.7, 2.0)
	if statue != null:
		var tw := statue.create_tween()
		tw.tween_property(statue, "scale", Vector3(1.0, 0.02, 1.0), 0.5).set_ease(Tween.EASE_IN)
		tw.tween_callback(statue.hide)


## His crown and sword on the golem's body.
static func dress_king(body: Node3D) -> void:
	_ready_kit()
	var sk: Skeleton3D = null
	for s: Skeleton3D in body.find_children("*", "Skeleton3D", true, false):
		if s.find_bone("head_joint") >= 0 and String(s.get_path()).contains("Visuals"):
			sk = s
	if sk == null:
		return
	for pair: Array in [["head_joint", "KCrown", Transform3D(Basis(), Vector3(0.0, 0.32, 0.0))],
			["R_equip_joint", "KSword", Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3.ZERO)]]:
		var att := BoneAttachment3D.new()
		att.bone_name = String(pair[0])
		sk.add_child(att)
		var src := _kit.get_node_or_null(String(pair[1])) as Node3D
		if src == null:
			continue
		var n := src.duplicate() as Node3D
		n.transform = pair[2]
		att.add_child(n)


static func _guard(room: Node3D, at: Vector3, yaw: float, hero: String) -> void:
	var p := _piece(room, "KPlinth", at, yaw)
	if p != null:
		TerracePlaces._box(p, Vector3(1.9, 3.0, 1.9), Vector3(0.0, 1.5, 0.0))
	var m := TerracePlaces._statue_mesh(hero)
	if m == null:
		return
	var mi := MeshInstance3D.new()
	mi.mesh = m
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.46, 0.45, 0.51)
	mat.roughness = 0.9
	mi.material_override = mat
	var aabb := m.get_aabb()
	var k := 3.1 / maxf(aabb.size.y, 0.01)
	mi.transform = Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * k), at + Vector3(0.0, 1.0 - aabb.position.y * k, 0.0))
	room.add_child(mi)


## Little flames at `at` + each of `tips`, a light with them if `light`.
static func _flames(room: Node3D, at: Vector3, tips: Array, tint: Color, light: bool, size := 1.0) -> void:
	for tip: Vector3 in tips:
		var p := GPUParticles3D.new()
		p.amount = 10 if size < 1.5 else 28
		p.lifetime = 0.5
		p.position = at + tip
		var pm := ParticleProcessMaterial.new()
		pm.direction = Vector3.UP
		pm.spread = 8.0
		pm.initial_velocity_min = 0.2 * size
		pm.initial_velocity_max = 0.5 * size
		pm.gravity = Vector3(0.0, 0.6, 0.0)
		pm.scale_min = 0.6
		pm.scale_max = 1.0
		var fade := Gradient.new()
		fade.set_color(0, Color(tint.lerp(Color.WHITE, 0.5), 1.0))
		fade.set_color(fade.get_point_count() - 1, Color(tint, 0.0))
		var ramp := GradientTexture1D.new()
		ramp.gradient = fade
		pm.color_ramp = ramp
		p.process_material = pm
		var q := QuadMesh.new()
		q.size = Vector2(0.09, 0.14) * size
		var qm := StandardMaterial3D.new()
		qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		qm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		qm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		qm.vertex_color_use_as_albedo = true
		qm.albedo_texture = PlaceBuild.soft_dot()
		q.material = qm
		p.draw_pass_1 = q
		room.add_child(p)
	if light:
		var o := OmniLight3D.new()
		o.light_color = tint
		o.light_energy = 1.6 * size
		o.omni_range = 7.0 * size
		o.position = at + Vector3(0.0, 0.3, 0.0)
		room.add_child(o)
