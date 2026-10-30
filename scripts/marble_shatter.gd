class_name MarbleShatter
extends Node3D
## The world is laid of marble tiles, and what dies breaks along them
## (2026-10-30, the user's word: everything should break the way it is
## built; the old gold blaze, red at the break, was not liked).
##
## Cheap way: no physics bodies. At the break the body's skinned meshes are
## baked as they are posed, their own faces dealt out among a few seeds
## (the nearest seed takes a face), so every piece is a handful of the
## model's real tiles in their own colours. Each piece gets a second skin
## inside it, turned over and drawn in fresh-broken stone, so a piece seen
## from its open side shows marble, not a hole. The pieces fly on their own
## sums (gravity, a bounce or two on the floor under the body), lie a while
## and sink into the ground.
##
## First a crack runs over the body ([member CRACK_SHADER], drawn over it as
## an overlay), then it breaks. Three looks to choose from ([member style]):
## A stone (few heavy pieces, grey dust), B crystal (many small sharp
## shards, cold light in the cracks, no dust), C marble (tiles, pale marble
## inside, white dust). Every peer breaks its own (it is only a look).

enum Style { GOLD, STONE, CRYSTAL, MARBLE }

## Which look a death takes. GOLD: the old DeathShatter blaze.
static var style: int = Style.MARBLE

const SND := "res://sounds/shatter/"
const LETTER := ["", "a", "b", "c"]

## Per look: pieces per metre of body, flight, fall, rest, inside colour, dust.
const LOOK := {
	Style.STONE: {
		"pieces": 7.0, "least": 9, "most": 22, "out": Vector2(0.4, 1.4), "up": Vector2(0.3, 1.5), "deep": 0.25,
		"spin": 3.0, "gravity": 15.0, "bounce": 0.22, "lie": 2.6, "crack": 0.22,
		"core": Color(0.62, 0.6, 0.56), "crack_col": Color(0.12, 0.1, 0.09), "crack_glow": 0.0,
		"dust": Color(0.6, 0.57, 0.52), "dust_n": 26, "shine": 0.0, "sink": 1.3,
	},
	Style.CRYSTAL: {
		"pieces": 26.0, "least": 30, "most": 70, "out": Vector2(1.6, 3.8), "up": Vector2(1.0, 3.0), "deep": 0.25,
		"spin": 9.0, "gravity": 11.0, "bounce": 0.35, "lie": 0.9, "crack": 0.16,
		"core": Color(0.82, 0.9, 0.97), "crack_col": Color(0.78, 0.9, 1.0), "crack_glow": 1.6,
		"dust": Color(0.9, 0.95, 1.0), "dust_n": 0, "shine": 0.85, "sink": 0.0,
	},
	Style.MARBLE: {
		"pieces": 8.0, "least": 12, "most": 26, "out": Vector2(0.35, 1.2), "up": Vector2(0.3, 1.3), "deep": 0.2,
		"spin": 5.5, "gravity": 13.0, "bounce": 0.2, "lie": 4.0, "crack": 0.32,
		"core": Color(0.93, 0.91, 0.87), "crack_col": Color(0.16, 0.14, 0.13), "crack_glow": 0.0,
		"dust": Color(0.94, 0.92, 0.88), "dust_n": 16, "shine": 0.35, "sink": 1.1,
	},
}

## The crack: cells of a world-space voronoi, their borders drawn as thin
## dark lines with a pale lip, spreading out from `from` as `amount` grows.
const CRACK_SHADER := """
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, shadows_disabled, unshaded;
uniform vec3 from = vec3(0.0);
uniform float reach = 1.5;
uniform float amount = 0.0;
uniform float cell = 0.22;
uniform vec4 line_col : source_color = vec4(0.12, 0.1, 0.09, 1.0);
uniform vec4 lip_col : source_color = vec4(0.95, 0.93, 0.9, 1.0);
uniform float glow = 0.0;
varying vec3 wpos;
vec3 h3(vec3 p) {
	p = vec3(dot(p, vec3(127.1, 311.7, 74.7)), dot(p, vec3(269.5, 183.3, 246.1)), dot(p, vec3(113.5, 271.9, 124.6)));
	return fract(sin(p) * 43758.5453);
}
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec3 p = wpos / cell;
	vec3 i = floor(p);
	float d1 = 9.0; float d2 = 9.0;
	for (int x = -1; x <= 1; x++) {
		for (int y = -1; y <= 1; y++) {
			for (int z = -1; z <= 1; z++) {
				vec3 g = vec3(float(x), float(y), float(z));
				vec3 o = g + h3(i + g) - fract(p);
				float d = dot(o, o);
				if (d < d1) { d2 = d1; d1 = d; } else if (d < d2) { d2 = d; }
			}
		}
	}
	float edge = sqrt(d2) - sqrt(d1);
	float spread = clamp((amount * reach * 1.25 - distance(wpos, from)) / 0.25, 0.0, 1.0);
	float w = 0.07 * spread;
	float line = 1.0 - smoothstep(w * 0.5, w, edge);
	float lip = (1.0 - smoothstep(w, w * 2.2, edge)) * (1.0 - line);
	ALBEDO = mix(lip_col.rgb, line_col.rgb, line) * (1.0 + glow * line);
	ALPHA = clamp(line + lip * 0.55, 0.0, 1.0) * spread;
}
"""
static var _crack_shader: Shader

var _look: Dictionary
var _style := Style.MARBLE
var _body: WeakRef
var _crack: ShaderMaterial
var _crack_time := 0.0
var _t := 0.0
var _broken := false
var _floor_y := 0.0
## [MeshInstance3D, velocity, spin axis*speed, radius, resting time]
var _pieces: Array = []
var _blow_at := Vector3.ZERO
var _blow_dir := Vector3.FORWARD
var _blow_side := Vector3.RIGHT
var _blow_power := 1.0
var _blow_way := Vector3.FORWARD
var _motion: StoneCrack.Motion = null
## Chunks that broke again on the floor, at most so many
var _splits := 0
var _added: Array = []
const SPLITS := 7


static func r_of(reach: float) -> float:
	return clampf(reach * 0.55, 0.03, 0.6)


## Cracks `body` (a corpse's visual root) and breaks it a beat later.
## `slow`: the corpse has lain a while, the crack takes longer.
static func begin(into: Node, body: Node3D, slow: bool = false) -> MarbleShatter:
	if into == null or body == null or not is_instance_valid(body) or style == Style.GOLD:
		return null
	var it := MarbleShatter.new()
	it.name = "MarbleShatter"
	it._style = style
	it._look = LOOK[style]
	it._body = weakref(body)
	it._crack_time = float(it._look["crack"]) * (2.4 if slow else 1.0)
	# struck dead: it breaks there and then, under the blow, before any of
	# its dying is played (the user, 2026-10-30); one that has lain a while
	# still cracks over first
	if not slow and StoneCrack.live():
		it._crack_time = 0.0
	into.add_child(it)
	it._start_crack(body)
	return it


func _start_crack(body: Node3D) -> void:
	var box0 := _box(body)
	var from := box0.get_center() + Vector3.UP * box0.size.y * 0.15
	# a stone skin ([StoneCrack]): its breaking runs out over all of it
	# (the user did not like a net of cracks drawn over the body)
	if _crack_time <= 0.0:
		# its pieces still follow its crack net, from its first blow on
		if body.has_meta(&"stone_skins") or StoneCrack.live():
			StoneCrack.skins_of(body)
		return
	if StoneCrack.live() and StoneCrack.spread(body, from, _crack_time):
		Sfx.play(self, SND + "crack_%s.wav" % LETTER[_style], null, from, randf_range(0.95, 1.08), 0.0)
		return
	if _crack_shader == null:
		_crack_shader = Shader.new()
		_crack_shader.code = CRACK_SHADER
	_crack = ShaderMaterial.new()
	_crack.shader = _crack_shader
	var box := _box(body)
	var hit := box.get_center() + Vector3.UP * box.size.y * 0.15
	_crack.set_shader_parameter("from", hit)
	_crack.set_shader_parameter("reach", maxf(box.size.length() * 0.6, 0.8))
	_crack.set_shader_parameter("line_col", _look["crack_col"])
	_crack.set_shader_parameter("lip_col", Color(0.96, 0.94, 0.9) if _style != Style.CRYSTAL else Color(0.9, 0.96, 1.0))
	_crack.set_shader_parameter("glow", _look["crack_glow"])
	_crack.set_shader_parameter("cell", 0.16 if _style == Style.CRYSTAL else (0.3 if _style == Style.STONE else 0.22))
	for g in body.find_children("*", "GeometryInstance3D", true, false):
		(g as GeometryInstance3D).material_overlay = _crack
	Sfx.play(self, SND + "crack_%s.wav" % LETTER[_style], null, hit, randf_range(0.95, 1.08), 0.0)


func _process(delta: float) -> void:
	_t += delta
	if not _broken:
		var body: Node3D = _body.get_ref()
		if body == null or not is_instance_valid(body):
			queue_free()
			return
		var k := clampf(_t / maxf(_crack_time, 0.01), 0.0, 1.0)
		if _crack != null:
			_crack.set_shader_parameter("amount", k * (2.0 - k))
		if _t >= _crack_time:
			_break(body)
		return
	_fly(delta)


## The body's box in the world as it is posed: round its bones (a skinned
## mesh's own box is its rest pose in the model's units, centimetres for
## the orc, so it cannot be used), its meshes' boxes where it has none.
static func _box(body: Node3D) -> AABB:
	var pts := DeathShatter.body_points(body)
	if not pts.is_empty():
		var b := AABB(pts[0], Vector3.ZERO)
		for p in pts:
			b = b.expand(p)
		return b.grow(0.18)
	var box := AABB()
	var first := true
	for node in body.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null or not mi.is_visible_in_tree():
			continue
		var b := mi.global_transform * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	if first:
		box = AABB(body.global_position, Vector3(0.6, 1.8, 0.6))
	return box


func _break(body: Node3D) -> void:
	_broken = true
	_t = 0.0
	var box := _box(body)
	var centre := box.get_center()
	var tall := clampf(box.size.y, 0.5, 6.0)
	var count := clampi(int(float(_look["pieces"]) * tall), int(_look["least"]), int(_look["most"]))
	if Graphics.current == Graphics.Level.LOW:
		count = maxi(int(count * 0.5), 6)
	# seeds among the body's bones, as it is posed
	var pts := DeathShatter.body_points(body)
	if pts.is_empty():
		pts.append(centre)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var seeds := PackedVector3Array()
	for i in count:
		var p := pts[rng.randi_range(0, pts.size() - 1)]
		seeds.append(p + Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * 0.12 * tall)
	# each piece: per material, its faces' corners [verts, normals, uvs, colours]
	var parts: Array = []
	for i in count:
		parts.append({})
	# a stone skin breaks along its own crack net: its pieces are the net's
	# cells, a few together (PIECE), so they come apart where it cracked
	var keys := {}
	var keyed: Array[bool] = []
	keyed.resize(count)
	keyed.fill(false)
	var piece := PIECE * clampf(tall / 1.9, 0.8, 2.2)
	var started := Time.get_ticks_usec()
	var core := _core_material()
	var skins := StoneCrack.skins_of(body) if body.has_meta(&"stone_skins") else []
	var blows: Array = body.get_meta(&"stone_blows", [])
	# the killing blow: where, which way, how hard
	_blow_at = centre
	_blow_dir = Vector3.ZERO
	_blow_power = 1.0
	var last: Array = body.get_meta(&"stone_last", [])
	if last.size() >= 3:
		_blow_at = last[0]
		_blow_dir = last[1]
		_blow_power = clampf(lerpf(0.85, 1.25, float(last[2]) - 0.5), 0.8, 1.3)
	_blow_way = _blow_dir.normalized() if _blow_dir.length_squared() > 0.0001 else Vector3.ZERO
	_blow_way.y = clampf(_blow_way.y, -0.25, 0.8)
	_blow_dir.y = 0.0
	_motion = body.get_meta(&"stone_motion") as StoneCrack.Motion if body.has_meta(&"stone_motion") else null
	if _blow_dir.length_squared() < 0.0001:
		_blow_dir = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1))
	_blow_dir = _blow_dir.normalized()
	_blow_side = _blow_dir.cross(Vector3.UP)
	if _blow_way == Vector3.ZERO:
		_blow_way = _blow_dir
	if not skins.is_empty():
		core.albedo_color = StoneCrack.INSIDE
		# rough broken stone: no shine (big broken sides caught the sun and
		# showed white, like paper)
		core.roughness = 1.0
		core.metallic_specular = 0.15
	for node in body.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null or not mi.is_visible_in_tree():
			continue
		var mesh: Mesh = mi.mesh
		if mi.skin != null and mi.get_node_or_null(mi.skeleton) is Skeleton3D:
			mesh = mi.bake_mesh_from_current_skeleton_pose()
		if mesh == null:
			continue
		var xf := mi.global_transform
		for s in mesh.get_surface_count():
			if mesh.surface_get_primitive_type(s) != Mesh.PRIMITIVE_TRIANGLES:
				continue
			var mat: Material = mi.get_active_material(s)
			# a stone skin: its pieces coloured per corner, broken or whole
			var skin := {}
			for sk in skins:
				if sk["mi"] == mi:
					skin = sk
			var rest: PackedVector3Array = skin["rest"][s] if not skin.is_empty() and s < (skin["rest"] as Array).size() else PackedVector3Array()
			var arr := mesh.surface_get_arrays(s)
			var vv: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var nn: PackedVector3Array = arr[Mesh.ARRAY_NORMAL] if arr[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
			var uu: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV] if arr[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
			var cc: PackedColorArray = arr[Mesh.ARRAY_COLOR] if arr[Mesh.ARRAY_COLOR] != null else PackedColorArray()
			var ii: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			var tris := int((ii.size() if not ii.is_empty() else vv.size()) / 3.0)
			var wv := PackedVector3Array()
			wv.resize(vv.size())
			for v in vv.size():
				wv[v] = xf * vv[v]
			for t in tris:
				var a := ii[t * 3] if not ii.is_empty() else t * 3
				var b := ii[t * 3 + 1] if not ii.is_empty() else t * 3 + 1
				var c := ii[t * 3 + 2] if not ii.is_empty() else t * 3 + 2
				var mid := (wv[a] + wv[b] + wv[c]) / 3.0
				var best := 0
				var bd := INF
				for k in count:
					var d := mid.distance_squared_to(seeds[k])
					if d < bd:
						bd = d
						best = k
				if not rest.is_empty() and a < rest.size() and b < rest.size() and c < rest.size():
					var cell := StoneCrack.cell_of((rest[a] + rest[b] + rest[c]) / 3.0)
					var feature := (Vector3(cell) + StoneCrack.h3(cell)) * StoneCrack.CELL / piece
					var key := Vector3i(floori(feature.x), floori(feature.y), floori(feature.z))
					if not keys.has(key):
						keys[key] = parts.size()
						parts.append({})
						keyed.append(true)
					best = int(keys[key])
				var part: Dictionary = parts[best]
				if not part.has(mat):
					part[mat] = [[], [], [], []]
				var bin: Array = part[mat]
				# where blows broke it off: blood on the piece there
				var bloody := false
				if not rest.is_empty() and a < rest.size() and b < rest.size() and c < rest.size():
					var rmid := (rest[a] + rest[b] + rest[c]) / 3.0
					if StoneCrack.hurt_at(rmid, blows) > 0.2:
						bloody = StoneCrack.cell_broken(StoneCrack.cell_of(rmid), blows)
				for v in [a, b, c]:
					(bin[0] as Array).append(wv[v])
					(bin[1] as Array).append((xf.basis * nn[v]).normalized() if not nn.is_empty() else Vector3.UP)
					(bin[2] as Array).append(uu[v] if not uu.is_empty() else Vector2.ZERO)
					if not rest.is_empty():
						# for the blood drawn over the piece: broken here or not
						(bin[3] as Array).append(Color(StoneCrack.BLOOD, 1.0 if bloody else 0.0))
					elif not skins.is_empty():
						(bin[3] as Array).append(Color(0, 0, 0, 0))
					else:
						(bin[3] as Array).append(cc[v] if not cc.is_empty() else Color.WHITE)
	if OS.is_debug_build() and not keys.is_empty():
		print("MarbleShatter: %d pieces from the net in %.1f ms" % [keys.size(), (Time.get_ticks_usec() - started) / 1000.0])
	body.visible = false
	for g in body.find_children("*", "GeometryInstance3D", true, false):
		(g as GeometryInstance3D).material_overlay = null

	# the floor under it
	_floor_y = box.position.y
	var down := get_world_3d().direct_space_state.intersect_ray(
			PhysicsRayQueryParameters3D.create(centre + Vector3.UP * 0.5, centre + Vector3.DOWN * 8.0, 1))
	if not down.is_empty():
		_floor_y = (down["position"] as Vector3).y

	var shadows := Graphics.current != Graphics.Level.LOW and _style != Style.CRYSTAL
	# a stone skin breaks in two steps: first into a few big chunks that
	# topple, each crumbling to its pieces where it hits the floor
	var small: Array = []
	for i in parts.size():
		var part: Dictionary = parts[i]
		if part.is_empty():
			continue
		var mesh := ArrayMesh.new()
		var mid := Vector3.ZERO
		var n := 0
		for mat in part:
			for v in (part[mat][0] as Array):
				mid += v as Vector3
				n += 1
		mid /= float(maxi(n, 1))
		var reach := 0.0
		# the inside is drawn in towards its seed, which lies on a bone, in the
		# body, so the broken sides run into the limb as a wedge of stone
		var core_at := seeds[i] - mid if not keyed[i] else _inward(part, mid)
		var inside_v := PackedVector3Array()
		var inside_n := PackedVector3Array()
		# its outer edges (an edge only one of its faces has): position key ->
		# [a, b, the face's middle, how many faces have it]
		var edges := {}
		var deep := float(_look["deep"])
		for mat in part:
			var bin: Array = part[mat]
			var vs := PackedVector3Array(bin[0] as Array)
			var nv := PackedVector3Array(bin[1] as Array)
			for v in vs.size():
				vs[v] -= mid
				reach = maxf(reach, vs[v].length())
			var arr := []
			arr.resize(Mesh.ARRAY_MAX)
			arr[Mesh.ARRAY_VERTEX] = vs
			arr[Mesh.ARRAY_NORMAL] = nv
			arr[Mesh.ARRAY_TEX_UV] = PackedVector2Array(bin[2] as Array)
			arr[Mesh.ARRAY_COLOR] = PackedColorArray(bin[3] as Array)
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
			mesh.surface_set_material(mesh.get_surface_count() - 1, mat as Material)
			# the inside: the same faces turned over, drawn well in, so the
			# piece has a body of stone and not a skin
			for t in int(vs.size() / 3.0):
				for v in [t * 3 + 2, t * 3 + 1, t * 3]:
					inside_v.append(core_at + (vs[v] - core_at) * deep)
					inside_n.append(-nv[v])
				var face_mid := (vs[t * 3] + vs[t * 3 + 1] + vs[t * 3 + 2]) / 3.0
				for e in 3:
					var a := vs[t * 3 + e]
					var b := vs[t * 3 + (e + 1) % 3]
					var key := _edge_key(a, b)
					if edges.has(key):
						(edges[key] as Array)[3] = int((edges[key] as Array)[3]) + 1
					else:
						edges[key] = [a, b, face_mid, 1]
		# the broken sides: from each outer edge in to the inside
		for key in edges:
			var e: Array = edges[key]
			if int(e[3]) != 1:
				continue
			var a: Vector3 = e[0]
			var b: Vector3 = e[1]
			var face_mid: Vector3 = e[2]
			var ia := core_at + (a - core_at) * deep
			var ib := core_at + (b - core_at) * deep
			var side := (a - core_at).cross(b - core_at)
			if side.length_squared() < 1e-12:
				continue
			side = side.normalized()
			if side.dot(face_mid - core_at) > 0.0:
				side = -side
			for p in [a, b, ib, a, ib, ia]:
				inside_v.append(p as Vector3)
				inside_n.append(side)
		if not inside_v.is_empty():
			var arr := []
			arr.resize(Mesh.ARRAY_MAX)
			arr[Mesh.ARRAY_VERTEX] = inside_v
			arr[Mesh.ARRAY_NORMAL] = inside_n
			# nothing of the stone overlay on it (a corner with no colour is
			# white and whole to it: the broken sides showed white as paper)
			var none := PackedColorArray()
			none.resize(inside_v.size())
			none.fill(Color(0, 0, 0, 0))
			arr[Mesh.ARRAY_COLOR] = none
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
			mesh.surface_set_material(mesh.get_surface_count() - 1, core)
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		if not skins.is_empty():
			mi.material_overlay = _corner_material()
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows and reach > 0.12 \
				else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		mi.global_position = mid
		var away := mid - centre
		away.y = 0.0
		away = away.normalized() if away.length_squared() > 0.0001 else Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized()
		var o: Vector2 = _look["out"]
		var u: Vector2 = _look["up"]
		# the high pieces fly a little more, the feet stay
		var height := clampf((mid.y - box.position.y) / maxf(box.size.y, 0.01), 0.0, 1.0)
		var vel := away * rng.randf_range(o.x, o.y) * (0.5 + height) + Vector3.UP * rng.randf_range(u.x, u.y) * (0.4 + height)
		var spin := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized() \
				* float(_look["spin"]) * rng.randf_range(0.5, 1.0)
		if not skins.is_empty():
			# the blow breaks it and carries it: most of it goes the way the
			# blow went, hardest near where it landed; the top topples over
			# that way, the legs drop where they stood (the user, 2026-10-30:
			# not burst as if it blew up)
			# each piece goes on as its limb was going (an arm swung flies on
			# where it swung) ...
			var carried := Vector3.ZERO
			if _motion != null:
				carried = _motion.speed_at(mid).limit_length(9.0) * 1.15
			# ... and where the blade went in, the way the blade went
			var near := clampf(1.0 - mid.distance_to(_blow_at) / maxf(tall * 0.6, 0.45), 0.0, 1.0)
			var cut := lerpf(0.0, 5.5, pow(near, 1.4)) * _blow_power
			vel = carried + _blow_way * cut * rng.randf_range(0.8, 1.2)
			# the rest of it a little after the blow, falling apart
			vel += _blow_dir * rng.randf_range(0.2, 0.9) * (0.2 + height) * _blow_power
			vel += away * rng.randf_range(0.1, 0.5) * (0.3 + height)
			vel += _blow_side * rng.randf_range(-0.5, 0.5) * (0.2 + near)
			vel.y += rng.randf_range(0.0, 0.7) * near
			# tumbling the way it goes
			var flat := Vector3(vel.x, 0.0, vel.z)
			spin = Vector3.UP.cross(flat) * rng.randf_range(1.2, 2.4) / maxf(r_of(reach), 0.15) * 0.25 \
					+ Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * 1.5
		if not skins.is_empty():
			# a stone skin's pieces crumble to grit and dust where they come
			# down (the rough chunks left lying were not liked)
			# its main colour: that of the material most of it is made of
			var main: Material = null
			var most := -1
			for mat in part:
				var n2 := (part[mat][0] as Array).size()
				if n2 > most:
					most = n2
					main = mat as Material
			_pieces.append([mi, vel, spin, clampf(reach * 0.55, 0.03, 0.6), 0.0, 0.0,
					_piece_colour(main, part[main][2] as Array, part[main][0] as Array), reach])
			# the clean chunk at once, in the very frame it breaks, filling the
			# piece's own box (any change of shape in flight showed, however
			# it was blended: the user, 2026-10-30)
			var fresh: Array = _pieces[_pieces.size() - 1]
			_swap(fresh)
			if fresh.size() > 8:
				_follow(fresh, 1.0)
		else:
			_pieces.append([mi, vel, spin, clampf(reach * 0.55, 0.03, 0.6), 0.0])

	_dust(centre, box)
	if not skins.is_empty():
		# grit and blood thrown up with it
		SkillFx.particles(self, centre, {
			"amount": 46, "life": 1.1, "one_shot": true, "explosiveness": 0.95, "add": false,
			"speed": Vector2(2.0, 5.0), "dir": (_blow_dir + Vector3.UP * 0.5).normalized(), "spread": 35.0, "gravity": Vector3(0, -14.0, 0),
			"damping": 0.6, "size": Vector2(0.04, 0.1) * clampf(tall / 1.9, 0.8, 2.0), "grow": 0.1,
			"box": box.size * 0.3,
			"colors": [Color(0.3, 0.02, 0.02, 1.0), Color(0.45, 0.42, 0.38, 1.0), Color(0.4, 0.36, 0.32, 0.0)],
		})
		SkillFx.particles(self, Vector3(centre.x, _floor_y + 0.3, centre.z), {
			"amount": 22, "life": 2.0, "one_shot": true, "explosiveness": 0.85, "add": false,
			"speed": Vector2(0.8, 2.4), "dir": Vector3.UP, "spread": 85.0, "gravity": Vector3(0, -0.2, 0),
			"damping": 1.4, "size": Vector2(0.6, 1.3) * clampf(tall / 1.9, 0.8, 2.0), "grow": 1.0,
			"box": Vector3(box.size.x * 0.4, 0.2, box.size.z * 0.4),
			"colors": [Color(0.62, 0.58, 0.52, 0.0), Color(0.62, 0.58, 0.52, 0.5), Color(0.62, 0.58, 0.52, 0.0)],
		})
	Sfx.play(self, SND + "break_%s_%d.wav" % [LETTER[_style], rng.randi_range(1, 3)], null, centre,
			randf_range(0.92, 1.06) / sqrt(clampf(tall / 1.9, 0.7, 2.5)), 2.0)
	WindBlast.shake(self, 0.05 if _style == Style.CRYSTAL else 0.08, 0.25, 14.0)
	var life := float(_look["lie"]) + float(_look["sink"]) + 2.5
	get_tree().create_timer(life, false).timeout.connect(queue_free)


## A stone skin's piece flies as the body's own for SWAP s, then is swapped,
## under the dust, for a clean chunk of stone its size (the user,
## 2026-10-30: the body's own pieces had rough, spiky shapes; chunks with four
## and five sided faces; swapped so the eye does not see it).
const SWAP := 0.02
const BLEND := 0.14
## Chunk shapes made once: a box pulled out of square, a corner or two cut
## off (those cut faces the broken stone, the rest its colour).
const CHUNKS := 10
static var _chunk_meshes: Array[ArrayMesh] = []
static var _skin_mats: Dictionary = {}
static var _blood_mats: Array[StandardMaterial3D] = []


func _swap(p: Array) -> void:
	var mi := p[0] as MeshInstance3D
	if not mi.visible:
		p[5] = -1.0
		return
	_chunks_made()
	# the chunk takes the piece's own box (its long side long, its flat side
	# flat), so the one grows where the other was
	var box := mi.mesh.get_aabb()
	var dims := box.size * 0.95
	var long := clampf(maxf(dims.x, maxf(dims.y, dims.z)), 0.1, 0.7)
	dims = dims * (long / maxf(maxf(dims.x, maxf(dims.y, dims.z)), 0.001))
	dims = Vector3(maxf(dims.x, long * 0.5), maxf(dims.y, long * 0.5), maxf(dims.z, long * 0.5))
	var size := long
	var chunk := MeshInstance3D.new()
	chunk.mesh = _chunk_meshes[randi() % _chunk_meshes.size()]
	chunk.set_surface_override_material(0, _skin_mat(p[6] as Color))
	chunk.set_surface_override_material(1, _blood_mats[randi() % _blood_mats.size()])
	chunk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if size > 0.25 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(chunk)
	# turned its own way, so its faces do not line up with the piece's
	var turn := Basis(Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized(), randf_range(-0.3, 0.3))
	p.append(chunk)
	p.append(dims)
	p.append(turn)
	p.append(box.get_center())
	p.append(false)
	_follow(p, 0.0)
	if _puffs < 14:
		_puffs += 1
		SkillFx.particles(self, mi.global_position, {
			"amount": 5, "life": 0.6, "one_shot": true, "explosiveness": 1.0, "add": false,
			"speed": Vector2(0.6, 1.6), "dir": Vector3.UP, "spread": 120.0, "gravity": Vector3(0, -9.0, 0),
			"damping": 0.8, "size": Vector2(0.04, 0.08) * clampf(size * 2.5, 0.7, 2.0), "grow": 0.2, "sphere": size * 0.3,
			"colors": [Color(0.42, 0.015, 0.012, 1.0), Color(0.3, 0.0, 0.0, 1.0), Color(0.25, 0.0, 0.0, 0.0)],
		})


## While a piece turns into its chunk (BLEND s): the piece shrinks into the
## chunk as the chunk grows out of it, the two as one, so no moment shows
## one shape giving way to another. At the end the chunk is the piece.
func _follow(p: Array, k: float) -> void:
	var mi := p[0] as MeshInstance3D
	var chunk := p[8] as MeshInstance3D
	var e := k * k * (3.0 - 2.0 * k)
	var dims: Vector3 = p[9]
	var b := mi.global_basis.orthonormalized()
	var at := mi.global_position + b * (p[11] as Vector3)
	chunk.global_transform = Transform3D(b * (p[10] as Basis) * Basis.from_scale(dims * maxf(0.5 + 0.5 * e, 0.01)), at)
	if k >= 1.0:
		mi.queue_free()
		chunk.global_transform = Transform3D(b * (p[10] as Basis) * Basis.from_scale(dims), at)
		p[0] = chunk
		p[3] = (dims.x + dims.y + dims.z) / 3.0 * 0.4
		p[5] = -1.0
		return
	mi.global_basis = b * Basis.from_scale(Vector3.ONE * maxf(1.0 - e, 0.01))


## A big chunk come down hard breaks again where it lands: two or three
## smaller, thrown on a little the way it was going.
func _split(p: Array, vel: Vector3) -> void:
	var mi := p[0] as MeshInstance3D
	p[12] = true
	_splits += 1
	var dims: Vector3 = p[9]
	var at := mi.global_position
	var flat := Vector3(vel.x, 0.0, vel.z)
	for i in randi_range(2, 3):
		var c := MeshInstance3D.new()
		c.mesh = _chunk_meshes[randi() % _chunk_meshes.size()]
		c.set_surface_override_material(0, mi.get_surface_override_material(0))
		c.set_surface_override_material(1, _blood_mats[randi() % _blood_mats.size()])
		c.cast_shadow = mi.cast_shadow
		add_child(c)
		var d := dims * randf_range(0.5, 0.68)
		var off := Vector3(randf_range(-1, 1), 0.0, randf_range(-1, 1)).normalized()
		var turn := Basis(Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized(), randf_range(-PI, PI))
		c.global_transform = Transform3D(turn * Basis.from_scale(d), at + off * maxf(d.x, d.z) * 0.45)
		var v := flat * randf_range(0.45, 0.8) + off * randf_range(0.6, 1.6) + Vector3.UP * randf_range(1.0, 2.4)
		var sp := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * 6.0
		_added.append([c, v, sp, (d.x + d.y + d.z) / 3.0 * 0.4, 0.0])
	mi.visible = false
	SkillFx.particles(self, Vector3(at.x, _floor_y + 0.1, at.z), {
		"amount": 8, "life": 1.0, "one_shot": true, "explosiveness": 1.0, "add": false,
		"speed": Vector2(0.5, 1.5), "dir": Vector3.UP, "spread": 80.0, "gravity": Vector3(0, -1.0, 0),
		"damping": 1.6, "size": Vector2(0.25, 0.5), "grow": 1.0, "sphere": 0.15,
		"colors": [Color(0.62, 0.58, 0.52, 0.0), Color(0.62, 0.58, 0.52, 0.45), Color(0.62, 0.58, 0.52, 0.0)],
	})
	Sfx.play(self, StoneCrack.SND % randi_range(1, 4), null, at, randf_range(0.75, 0.95), -8.0)


## The colour a piece shows: its material's, read where its corners lie on
## the material's texture (the pack's mask in its three colours; a texture
## times its colour), so a chunk swapped in for it keeps its look.
static var _images: Dictionary = {}


## (by area: weighed by corners, small busy parts such as nails, which
## have many, outvoted the skin around them)
static func _piece_colour(m: Material, uvs: Array, verts: Array) -> Color:
	var tex: Texture2D = null
	if m is BaseMaterial3D:
		tex = (m as BaseMaterial3D).albedo_texture
	elif m is ShaderMaterial:
		var t: Variant = (m as ShaderMaterial).get_shader_parameter("mask_tex")
		if t is Texture2D:
			tex = t
	var tris := int(mini(uvs.size(), verts.size()) / 3.0)
	if tex == null or tris == 0:
		return StoneCrack.colour_of(m)
	var img := _image_of(tex)
	if img == null:
		return StoneCrack.colour_of(m)
	var sum := Color(0, 0, 0, 0)
	var votes := [0.0, 0.0, 0.0]
	var weight := 0.0
	var step := maxi(1, int(tris / 40.0))
	for k in range(0, tris, step):
		var i := k * 3
		var area := ((verts[i + 1] as Vector3) - (verts[i] as Vector3)).cross((verts[i + 2] as Vector3) - (verts[i] as Vector3)).length()
		if area <= 0.0:
			continue
		var uv: Vector2 = ((uvs[i] as Vector2) + (uvs[i + 1] as Vector2) + (uvs[i + 2] as Vector2)) / 3.0
		var x := clampi(int(fposmod(uv.x, 1.0) * img.get_width()), 0, img.get_width() - 1)
		var y := clampi(int(fposmod(uv.y, 1.0) * img.get_height()), 0, img.get_height() - 1)
		var t := img.get_pixel(x, y)
		if m is ShaderMaterial:
			# the pack's mask: one of its three colours, whichever most of
			# the piece is (an average of them gave colours it never had)
			if t.a < 0.5:
				continue
			var ch := 0 if t.r >= t.g and t.r >= t.b else (1 if t.g >= t.b else 2)
			votes[ch] = float(votes[ch]) + area
		else:
			sum += t * (m as BaseMaterial3D).albedo_color * area
		weight += area
	if m is ShaderMaterial:
		var best := 0
		for ch in 3:
			if float(votes[ch]) > float(votes[best]):
				best = ch
		return _vec_colour((m as ShaderMaterial).get_shader_parameter("color%d" % (best + 1)))
	if weight <= 0.0:
		return StoneCrack.colour_of(m)
	sum /= weight
	return Color(sum.r, sum.g, sum.b, 1.0)


static func _vec_colour(v: Variant) -> Color:
	if v is Color:
		return v
	if v is Vector3:
		var w := v as Vector3
		return Color(w.x, w.y, w.z)
	return Color(0.7, 0.68, 0.64)


static func _image_of(tex: Texture2D) -> Image:
	var key := tex.get_rid().get_id()
	if not _images.has(key):
		var img := tex.get_image()
		if img != null:
			if img.is_compressed():
				img.decompress()
			if img.get_width() > 256:
				img.resize(256, maxi(1, int(256.0 * img.get_height() / img.get_width())), Image.INTERPOLATE_BILINEAR)
		_images[key] = img
	return _images[key]


static func _skin_mat(colour: Color) -> StandardMaterial3D:
	var key := colour.to_html()
	if not _skin_mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = colour
		m.roughness = 0.8
		_skin_mats[key] = m
	return _skin_mats[key]


static func _chunks_made() -> void:
	if not _chunk_meshes.is_empty():
		return
	# where it broke: wet blood, a lighter and a darker
	for c in [StoneCrack.BLOOD, StoneCrack.BLOOD.darkened(0.35), StoneCrack.BLOOD.lerp(StoneCrack.INSIDE, 0.4)]:
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 0.22
		m.metallic_specular = 0.7
		_blood_mats.append(m)
	var rng := RandomNumberGenerator.new()
	rng.seed = 90210
	for i in CHUNKS:
		_chunk_meshes.append(_chunk(rng))


## A chunk about a unit across: faces as polygons [points, broken?], a box
## stretched and leant at random, cut by 1–3 planes.
static func _chunk(rng: RandomNumberGenerator) -> ArrayMesh:
	var c := [Vector3(-0.5, -0.5, -0.5), Vector3(0.5, -0.5, -0.5), Vector3(0.5, 0.5, -0.5), Vector3(-0.5, 0.5, -0.5),
			Vector3(-0.5, -0.5, 0.5), Vector3(0.5, -0.5, 0.5), Vector3(0.5, 0.5, 0.5), Vector3(-0.5, 0.5, 0.5)]
	var quads := [[0, 3, 2, 1], [4, 5, 6, 7], [0, 1, 5, 4], [3, 7, 6, 2], [0, 4, 7, 3], [1, 2, 6, 5]]
	var shape := Basis.from_scale(Vector3(rng.randf_range(0.75, 1.25), rng.randf_range(0.55, 0.95), rng.randf_range(0.75, 1.25)))
	shape = Basis(Vector3(rng.randf(), rng.randf(), rng.randf()).normalized(), rng.randf_range(-0.35, 0.35)) * shape
	shape.x += Vector3(0, rng.randf_range(-0.15, 0.15), 0)
	var faces: Array = []
	for q in quads:
		var poly: Array = []
		for k in q:
			poly.append(shape * (c[k] as Vector3))
		faces.append([poly, false])
	for cut in rng.randi_range(2, 3):
		var n := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized()
		faces = _clip(faces, Plane(n, rng.randf_range(0.18, 0.32)))
	# (packed arrays are values: kept by name, not reached through an Array)
	var skin_v := PackedVector3Array()
	var skin_n := PackedVector3Array()
	var cut_v := PackedVector3Array()
	var cut_n := PackedVector3Array()
	var mid := Vector3.ZERO
	var count := 0
	for f in faces:
		for v in (f[0] as Array):
			mid += v as Vector3
			count += 1
	mid /= float(maxi(count, 1))
	for f in faces:
		var poly: Array = f[0]
		if poly.size() < 3:
			continue
		var n := ((poly[1] as Vector3) - (poly[0] as Vector3)).cross((poly[2] as Vector3) - (poly[0] as Vector3)).normalized()
		var centre := Vector3.ZERO
		for v in poly:
			centre += v as Vector3
		centre /= float(poly.size())
		var flip := n.dot(centre - mid) < 0.0
		if flip:
			n = -n
		for k in range(1, poly.size() - 1):
			var tri := [poly[0], poly[k], poly[k + 1]] if flip else [poly[0], poly[k + 1], poly[k]]
			for v in tri:
				if f[1]:
					cut_v.append((v as Vector3) - mid)
					cut_n.append(n)
				else:
					skin_v.append((v as Vector3) - mid)
					skin_n.append(n)
	var mesh := ArrayMesh.new()
	for bin in [[skin_v, skin_n], [cut_v, cut_n]]:
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = bin[0]
		arr[Mesh.ARRAY_NORMAL] = bin[1]
		if (bin[0] as PackedVector3Array).is_empty():
			# a surface must have something: a speck inside
			arr[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3.ZERO, Vector3(0.001, 0, 0), Vector3(0, 0.001, 0)])
			arr[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.UP, Vector3.UP, Vector3.UP])
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return mesh


## A convex body (faces [points, broken?]) cut by `plane`: what lies on its
## far side kept, the cut closed by a new broken face.
static func _clip(faces: Array, plane: Plane) -> Array:
	var out: Array = []
	var cut_points: Array = []
	for f in faces:
		var poly: Array = f[0]
		var kept: Array = []
		for k in poly.size():
			var a: Vector3 = poly[k]
			var b: Vector3 = poly[(k + 1) % poly.size()]
			var da := plane.distance_to(a)
			var db := plane.distance_to(b)
			if da <= 0.0:
				kept.append(a)
			if (da < 0.0) != (db < 0.0):
				var x := a.lerp(b, da / (da - db))
				kept.append(x)
				cut_points.append(x)
		if kept.size() >= 3:
			out.append([kept, f[1]])
	if cut_points.size() >= 3:
		var centre := Vector3.ZERO
		for v in cut_points:
			centre += v as Vector3
		centre /= float(cut_points.size())
		var u := ((cut_points[0] as Vector3) - centre).normalized()
		var w := plane.normal.cross(u)
		cut_points.sort_custom(func(x: Vector3, y: Vector3) -> bool:
			return atan2((x - centre).dot(w), (x - centre).dot(u)) < atan2((y - centre).dot(w), (y - centre).dot(u)))
		out.append([cut_points, true])
	return out


## A stone skin's piece in flight until it comes down (or has flown
## CRUMBLE_AFTER s), then crumbling: grit and dust where it is, shrinking
## away in CRUMBLE_TIME s as it settles. [mesh, velocity, spin, radius,
## age, crumbling (-1 not yet)]
const CRUMBLE_AFTER := 1.0
const CRUMBLE_TIME := 0.35
var _puffs := 0


func _fly_crumbling(p: Array, delta: float, g: float) -> void:
	var mi := p[0] as MeshInstance3D
	if not mi.visible:
		return
	var vel: Vector3 = p[1]
	var spin: Vector3 = p[2]
	var r := float(p[3])
	p[4] = float(p[4]) + delta
	var low := _floor_y + r * 0.6
	var crumbling := float(p[5])
	if crumbling < 0.0 and (mi.global_position.y <= low or float(p[4]) > CRUMBLE_AFTER):
		crumbling = 0.0
		_crumble_at(mi.global_position, r)
	vel.y -= g * delta
	if crumbling >= 0.0:
		crumbling += delta
		vel.x *= 1.0 - minf(6.0 * delta, 1.0)
		vel.z *= 1.0 - minf(6.0 * delta, 1.0)
		var k := clampf(crumbling / CRUMBLE_TIME, 0.0, 1.0)
		mi.scale = Vector3.ONE * maxf(1.0 - k * k * (3.0 - 2.0 * k), 0.01)
		if k >= 1.0:
			mi.visible = false
	mi.global_position += vel * delta
	if mi.global_position.y < low:
		mi.global_position.y = low
		vel.y = 0.0
	if spin.length_squared() > 0.0001:
		mi.global_basis = Basis(spin.normalized(), spin.length() * delta) * mi.global_basis
	p[1] = vel
	p[2] = spin
	p[5] = crumbling


## A piece crumbling: its grit thrown a little and a puff of dust (only so
## many puffs a break, the rest share them).
func _crumble_at(at: Vector3, r: float) -> void:
	if _puffs >= 14:
		return
	_puffs += 1
	SkillFx.particles(self, at, {
		"amount": 10, "life": 0.7, "one_shot": true, "explosiveness": 1.0, "add": false,
		"speed": Vector2(0.8, 2.2), "dir": Vector3.UP, "spread": 70.0, "gravity": Vector3(0, -12.0, 0),
		"damping": 1.0, "size": Vector2(0.03, 0.07), "grow": 0.1, "sphere": r * 0.6,
		"colors": [Color(0.45, 0.42, 0.38, 1.0), Color(0.3, 0.03, 0.02, 1.0), Color(0.4, 0.36, 0.32, 0.0)],
	})
	SkillFx.particles(self, at, {
		"amount": 4, "life": 1.3, "one_shot": true, "explosiveness": 0.9, "add": false,
		"speed": Vector2(0.2, 0.7), "dir": Vector3.UP, "spread": 80.0, "gravity": Vector3(0, -0.2, 0),
		"damping": 1.5, "size": Vector2(0.4, 0.8) * clampf(r * 3.0, 0.6, 1.8), "grow": 1.0, "sphere": r * 0.5,
		"colors": [Color(0.62, 0.58, 0.52, 0.0), Color(0.62, 0.58, 0.52, 0.45), Color(0.62, 0.58, 0.52, 0.0)],
	})


## A piece of a stone skin, metres (× its height against a man's): a few
## cells of its crack net.
const PIECE := 0.5


## Where a piece's broken sides run in to (from its middle): a little way in
## under its own faces, so it is a chunk and not a long spike (walls run to
## a bone deep in the body showed as spikes).
func _inward(part: Dictionary, mid: Vector3) -> Vector3:
	var n := Vector3.ZERO
	var reach := 0.0
	for mat in part:
		var bin: Array = part[mat]
		for v in (bin[1] as Array):
			n += v as Vector3
		for v in (bin[0] as Array):
			reach = maxf(reach, ((v as Vector3) - mid).length())
	n = n.normalized() if n.length_squared() > 0.0001 else Vector3.UP
	return -n * clampf(reach * 0.55, 0.05, 0.4)


## [node, velocity, spin, members [mesh instance, radius], age]
var _chunks: Array = []
var _crumbled := 0


## The pieces `small` [mesh instance, radius] gathered into a few big
## chunks round the body (each its nearest of a few seeds spread over it),
## each toppling away from the middle; they crumble in [method _fly].
func _gather(small: Array, centre: Vector3, rng: RandomNumberGenerator) -> void:
	var box := AABB((small[0][0] as Node3D).global_position, Vector3.ZERO)
	for m in small:
		box = box.expand((m[0] as Node3D).global_position)
	var k := clampi(roundi(box.size.y / 1.9 * 2.5) + 2, 3, 6)
	# seeds spread over it: each the piece farthest from those chosen
	var seeds: Array[Vector3] = [(small[rng.randi_range(0, small.size() - 1)][0] as Node3D).global_position]
	while seeds.size() < k:
		var far := Vector3.ZERO
		var fd := -1.0
		for m in small:
			var p := (m[0] as Node3D).global_position
			var near := INF
			for q in seeds:
				near = minf(near, p.distance_squared_to(q))
			if near > fd:
				fd = near
				far = p
		seeds.append(far)
	var groups: Array = []
	for i in k:
		groups.append([])
	for m in small:
		var p := (m[0] as Node3D).global_position
		var best := 0
		var bd := INF
		for i in k:
			var d := p.distance_squared_to(seeds[i])
			if d < bd:
				bd = d
				best = i
		(groups[best] as Array).append(m)
	for g in groups:
		if (g as Array).is_empty():
			continue
		var mid := Vector3.ZERO
		for m in g:
			mid += (m[0] as Node3D).global_position
		mid /= float((g as Array).size())
		var chunk := Node3D.new()
		add_child(chunk)
		chunk.global_position = mid
		for m in g:
			(m[0] as Node3D).reparent(chunk)
		var away := mid - centre
		away.y = 0.0
		away = away.normalized() if away.length_squared() > 0.0001 else Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized()
		var height := clampf((mid.y - box.position.y) / maxf(box.size.y, 0.01), 0.0, 1.0)
		var vel := away * rng.randf_range(0.3, 1.0) * (0.4 + height) + Vector3.UP * rng.randf_range(0.0, 0.9) * height
		# it topples outward: turning about the line across its way out
		var spin := away.cross(Vector3.DOWN).normalized() * rng.randf_range(1.2, 2.8) \
				+ Vector3(rng.randf_range(-0.4, 0.4), rng.randf_range(-0.4, 0.4), rng.randf_range(-0.4, 0.4))
		_chunks.append([chunk, vel, spin, g, 0.0])


## A chunk hits the floor: its pieces go their own ways from where it is.
func _crumble(c: Array) -> void:
	var chunk := c[0] as Node3D
	var vel: Vector3 = c[1]
	var o: Vector2 = _look["out"]
	var u: Vector2 = _look["up"]
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for m in c[3]:
		var mi := m[0] as MeshInstance3D
		mi.reparent(self)
		var away := mi.global_position - chunk.global_position
		away.y = 0.0
		away = away.normalized() if away.length_squared() > 0.0001 else Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized()
		var v := Vector3(vel.x, 0.0, vel.z) * 0.35 + away * rng.randf_range(o.x, o.y) + Vector3.UP * rng.randf_range(u.x, u.y) * 0.6
		var spin := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized() \
				* float(_look["spin"]) * rng.randf_range(0.5, 1.0)
		_pieces.append([mi, v, spin, float(m[1]), 0.0])
	var at := Vector3(chunk.global_position.x, _floor_y, chunk.global_position.z)
	SkillFx.particles(self, at + Vector3.UP * 0.15, {
		"amount": 8, "life": 1.2, "one_shot": true, "explosiveness": 0.9, "add": false,
		"speed": Vector2(0.4, 1.2), "dir": Vector3.UP, "spread": 70.0, "gravity": Vector3(0, -0.3, 0),
		"damping": 1.6, "size": Vector2(0.35, 0.7), "grow": 0.9, "sphere": 0.3,
		"colors": [Color(0.6, 0.57, 0.52, 0.0), Color(0.6, 0.57, 0.52, 0.4), Color(0.6, 0.57, 0.52, 0.0)],
	})
	if _crumbled < 3:
		Sfx.play(self, StoneCrack.SND % rng.randi_range(1, 4), null, at, randf_range(0.6, 0.75), 0.0)
	_crumbled += 1
	chunk.queue_free()


## Two corners' positions as one key, either way round (the model's faces
## each have corners of their own, so faces meet by position, not index).
static func _edge_key(a: Vector3, b: Vector3) -> String:
	var qa := Vector3i(roundi(a.x * 2000.0), roundi(a.y * 2000.0), roundi(a.z * 2000.0))
	var qb := Vector3i(roundi(b.x * 2000.0), roundi(b.y * 2000.0), roundi(b.z * 2000.0))
	if qa > qb:
		var t := qa
		qa = qb
		qb = t
	return "%d,%d,%d|%d,%d,%d" % [qa.x, qa.y, qa.z, qb.x, qb.y, qb.z]


static var _corners: ShaderMaterial


## Drawn over a piece of a stone skin: the stone where its corners were
## broken (their colour's alpha), nothing elsewhere.
static func _corner_material() -> ShaderMaterial:
	if _corners == null:
		var sh := Shader.new()
		sh.code = """
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back;
void fragment() {
	if (COLOR.a < 0.5) {
		discard;
	}
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.25;
	SPECULAR = 0.7;
}
"""
		_corners = ShaderMaterial.new()
		_corners.shader = sh
	return _corners


## The broken stone inside a piece (both sides drawn: its sides are laid
## without caring which way they face).
func _core_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = _look["core"]
	m.roughness = 1.0 - float(_look["shine"]) * 0.7
	m.metallic_specular = 0.5 + float(_look["shine"]) * 0.4
	if _style == Style.CRYSTAL:
		m.emission_enabled = true
		m.emission = Color(0.7, 0.85, 1.0)
		m.emission_energy_multiplier = 0.6
	return m


func _dust(at: Vector3, box: AABB) -> void:
	var n := int(_look["dust_n"])
	var col: Color = _look["dust"]
	if n > 0:
		SkillFx.particles(self, at, {
			"amount": n, "life": 1.6, "one_shot": true, "explosiveness": 0.9, "add": false,
			"speed": Vector2(0.4, 1.6), "dir": Vector3.UP, "spread": 90.0, "gravity": Vector3(0, -0.3, 0),
			"damping": 1.6, "size": Vector2(0.35, 0.8) * clampf(box.size.y / 1.9, 0.6, 2.5), "grow": 1.0,
			"box": box.size * 0.35,
			"colors": [Color(col, 0.0), Color(col, 0.45), Color(col, 0.0)],
		})
	if _style == Style.CRYSTAL:
		# a glint of fine bits, cold, not fire
		SkillFx.particles(self, at, {
			"amount": 40, "life": 0.9, "one_shot": true, "explosiveness": 1.0, "add": true,
			"speed": Vector2(2.0, 5.0), "dir": Vector3.UP, "spread": 180.0, "gravity": Vector3(0, -6.0, 0),
			"damping": 2.0, "size": Vector2(0.03, 0.07), "grow": 0.1, "box": box.size * 0.3,
			"colors": [Color(0.85, 0.93, 1.0, 1.0), Color(0.7, 0.85, 1.0, 0.0)],
		})


func _fly(delta: float) -> void:
	if not _added.is_empty():
		_pieces.append_array(_added)
		_added.clear()
	var g := float(_look["gravity"])
	for c in _chunks.duplicate():
		var chunk := c[0] as Node3D
		var vel: Vector3 = c[1]
		var spin: Vector3 = c[2]
		c[4] = float(c[4]) + delta
		vel.y -= g * delta
		chunk.global_position += vel * delta
		chunk.global_basis = Basis(spin.normalized(), spin.length() * delta) * chunk.global_basis
		c[1] = vel
		var low := INF
		for m in c[3]:
			low = minf(low, (m[0] as Node3D).global_position.y - float(m[1]))
		if low <= _floor_y or float(c[4]) > 1.4:
			_crumble(c)
			_chunks.erase(c)
	var bounce := float(_look["bounce"])
	var lie := float(_look["lie"])
	var sink := float(_look["sink"])
	for p in _pieces:
		var mi := p[0] as MeshInstance3D
		if not is_instance_valid(mi):
			continue
		var r := float(p[3])
		var vel: Vector3 = p[1]
		var spin: Vector3 = p[2]
		var rest := float(p[4])
		if p.size() > 5 and float(p[5]) >= 0.0:
			p[5] = float(p[5]) + delta
			if p.size() <= 8 and float(p[5]) >= SWAP:
				_swap(p)
		if rest <= 0.0:
			vel.y -= g * delta
			mi.global_position += vel * delta
			if spin.length_squared() > 0.0001:
				mi.global_basis = Basis(spin.normalized(), spin.length() * delta) * mi.global_basis
			var low := _floor_y + r
			if mi.global_position.y < low:
				mi.global_position.y = low
				if p.size() > 12 and not bool(p[12]) and float(p[5]) < 0.0 and vel.y < -3.0 \
						and _splits < SPLITS and (p[9] as Vector3)[(p[9] as Vector3).max_axis_index()] > 0.24:
					# a big one comes down hard: it breaks again
					_split(p, vel)
					p[1] = Vector3.ZERO
					p[2] = Vector3.ZERO
					p[4] = 1e6
					continue
				if absf(vel.y) < 1.2:
					vel = Vector3.ZERO
					spin = Vector3.ZERO
					rest = 0.0001
				else:
					vel.y = -vel.y * bounce
					vel.x *= 0.55
					vel.z *= 0.55
					spin *= 0.5
			p[1] = vel
			p[2] = spin
			p[4] = rest
			if p.size() > 8 and float(p[5]) >= 0.0:
				_follow(p, clampf((float(p[5]) - SWAP) / BLEND, 0.0, 1.0))
			continue
		rest += delta
		p[4] = rest
		if p.size() > 8 and float(p[5]) >= 0.0:
			_follow(p, clampf((float(p[5]) - SWAP) / BLEND, 0.0, 1.0))
			mi = p[0] as MeshInstance3D
		if rest > lie:
			var k := clampf((rest - lie) / maxf(sink, 0.3), 0.0, 1.0)
			if sink > 0.0:
				# down into the ground
				mi.global_position.y = _floor_y + r - k * k * (r * 2.5 + 0.1)
			else:
				# the crystal's bits fade out small
				mi.scale = Vector3.ONE * maxf(1.0 - k, 0.01)
			if k >= 1.0:
				mi.visible = false
