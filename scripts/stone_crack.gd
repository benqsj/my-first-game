class_name StoneCrack
extends RefCounted
## A blow on a creature of the marble world cracks it where it lands, and only
## there; struck again there it cracks further, and pieces break off it with
## blood under them (2026-10-30, the user's words, over several rounds: like
## striking stone; cracks, not stripes; first cracks here and there, then it
## breaks bit by bit; where it breaks, blood).
##
## Instead of blood ([method Blood.splatter] hands over to [method hit]):
## * [constant SHADER] is drawn over the creature's skinned meshes (their
##   material_overlay; their own materials untouched). Its cracks and broken
##   pieces are cells of a net laid in the model's rest pose (each corner's
##   rest place in a texture read by VERTEX_ID), so they stay on the body as
##   it moves. Each blow is kept as a sphere in that rest space (place,
##   reach, power, at most [constant MOST]): how hurt a spot is is the sum of
##   the blows round it, so cracks show only where it was struck;
## * the first blows ([constant CRACK_HITS], while it is barely hurt) only
##   crack it; after that a blow breaks the cells it hurts enough off whole,
##   showing wet blood, and those pieces of its skin fly off;
## * a breath of stone dust and a stone tick (`sounds/shatter/hit_<n>.wav`).
## At its death [MarbleShatter] runs a wave of cracks over it ([method spread])
## and breaks it apart.
## Every peer does it ([method Fighter.net_bleed] is call_local); it all comes
## from the point struck, so all see the same.

const SHADER := preload("res://shaders/stone_body.gdshader")
const SND := "res://sounds/shatter/hit_%d.wav"
## The blows kept (the shader's MOST).
const MOST := 24
## A cell of the net (the shader's `cell`), metres.
const CELL := 0.26
## A cracking blow: its reach (× the creature's size) and power; a breaking
## one's. Hurt 0.6 and more breaks a cell off.
const CRACK_REACH := 0.3
const CRACK_POWER := 0.24
const BREAK_REACH := 0.36
const BREAK_POWER := 0.55
## The first blows (up to CRACK_HITS, while it has more than BREAK_BELOW of
## its health) only crack it.
const CRACK_HITS := 3
const BREAK_BELOW := 0.7
## The most pieces one blow knocks off.
const CHIPS := 6
const BLOOD := Color(0.42, 0.015, 0.012)
## The broken inside of a piece: dark bloodied stone.
const INSIDE := Color(0.2, 0.05, 0.04)

## Off: blood as before.
static var on: bool = true


## The marble world in force: only in the new fight (F3, [member
## Player.action_souls]; the user, 2026-10-30), its cracks, its breaking and
## its floors; the old fight keeps its blood and gold.
static func live() -> bool:
	return on and Player.action_souls and MarbleShatter.style != MarbleShatter.Style.GOLD


## A blow landed on `creature` at `point`, going `along`. False when it is
## not one of the marble world's (then it bleeds as before).
static func hit(world: Node, creature: Node3D, point: Vector3, along: Vector3, strength: float = 1.0) -> bool:
	if not live() or world == null:
		return false
	if creature == null or not creature.is_inside_tree() or not creature.is_in_group(&"enemy"):
		return false
	var size := _size(creature)
	var out := _out_of(creature, point, along)
	var owner := _owner(creature)
	# the last blow, where and which way: at its death the pieces go that
	# way ([MarbleShatter])
	if owner != null:
		owner.set_meta(&"stone_last", [point, along, strength])
		# and how its limbs move, so at its death each piece goes on as its
		# limb was going (an arm swung at him flies at him)
		if not owner.has_meta(&"stone_motion"):
			var m := Motion.new()
			m.name = "StoneMotion"
			m.creature = weakref(creature)
			m.body = owner
			owner.add_child(m)
			owner.set_meta(&"stone_motion", m)
	var skins := skins_of(owner)
	var hits := int(creature.get_meta(&"stone_hits", 0)) + 1
	creature.set_meta(&"stone_hits", hits)
	var left := 1.0
	var hp: Variant = creature.get(&"health")
	var most: Variant = creature.get(&"max_health")
	if hp is float and most is float and float(most) > 0.0:
		left = float(hp) / float(most)
	var cracking := hits <= CRACK_HITS and left > BREAK_BELOW
	var heft := lerpf(0.85, 1.25, clampf(strength - 0.5, 0.0, 1.0))
	var at := point
	var broke: Array = []
	if not skins.is_empty():
		var posed := _posed(skins)
		var snap := _nearest(skins, posed, point, out)
		if not snap.is_empty():
			at = snap[0]
			out = ((snap[1] as Vector3) * 0.6 + out * 0.4).normalized()
			var reach := (CRACK_REACH if cracking else BREAK_REACH) * size * heft
			var power := (CRACK_POWER if cracking else BREAK_POWER) * heft
			var before := (owner.get_meta(&"stone_blows") as Array).duplicate(true)
			_add_blow(owner, snap[2] as Vector3, reach, power)
			if not cracking:
				broke = _broken_now(skins, posed, before, owner.get_meta(&"stone_blows") as Array,
						snap[2] as Vector3, reach)
	_fling(world, broke, at, out, size)
	SkillFx.particles(world, at, {
		"amount": 6, "life": 0.9, "one_shot": true, "explosiveness": 0.9, "add": false,
		"speed": Vector2(0.3, 1.0), "dir": out, "spread": 50.0, "gravity": Vector3(0, -0.4, 0),
		"damping": 2.0, "size": Vector2(0.2, 0.38) * clampf(size, 0.8, 2.0), "grow": 0.8,
		"colors": [Color(0.8, 0.77, 0.72, 0.0), Color(0.8, 0.77, 0.72, 0.35), Color(0.8, 0.77, 0.72, 0.0)],
	})
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector3i(roundi(point.x * 50.0), roundi(point.y * 50.0), roundi(point.z * 50.0)))
	Sfx.play(world, SND % rng.randi_range(1, 4), null, at,
			rng.randf_range(0.94, 1.08) / sqrt(clampf(size, 0.7, 2.5)), -2.0)
	return true


## The node whose meshes are the creature's look: its `body` (Visuals).
static func _owner(creature: Node3D) -> Node3D:
	var body: Variant = creature.get(&"body")
	return body as Node3D if body is Node3D else creature


## How big `creature` is against a man (1.9 m), from its bones as it
## stands; worked out once.
static func _size(creature: Node3D) -> float:
	if creature.has_meta(&"stone_size"):
		return float(creature.get_meta(&"stone_size"))
	var box := MarbleShatter._box(_owner(creature))
	var s := clampf(box.size.y / 1.9, 0.5, 4.0)
	creature.set_meta(&"stone_size", s)
	return s


## Which way is out of the body at `point`: mostly back the way the blade
## came (the side struck faces the striker), a little away from its middle.
static func _out_of(creature: Node3D, point: Vector3, along: Vector3) -> Vector3:
	var radial := point - (creature.global_position + Vector3.UP * (point.y - creature.global_position.y))
	radial = radial.normalized() if radial.length_squared() > 0.0001 else Vector3.ZERO
	var back := -along
	back.y *= 0.5
	var out := back.normalized() * 0.75 + radial * 0.25
	return out.normalized() if out.length_squared() > 0.0001 else Vector3.BACK


#region The stone skin
## The skinned meshes of `owner` with the crack net drawn over them, made the
## first time it is asked for: per mesh {mi, material, rest (per surface, its
## corners' rest places in metres), surfaces (index arrays), colour}. Empty
## headless (skins cannot be baked there) or where it has no skinned mesh.
static func skins_of(owner: Node3D) -> Array:
	if owner == null:
		return []
	if owner.has_meta(&"stone_skins"):
		return owner.get_meta(&"stone_skins")
	var out: Array = []
	owner.set_meta(&"stone_blows", [])
	if DisplayServer.get_name() != "headless":
		for node in owner.find_children("*", "MeshInstance3D", true, false):
			var mi := node as MeshInstance3D
			if mi.mesh == null or mi.skin == null or not mi.is_visible_in_tree():
				continue
			if not (mi.get_node_or_null(mi.skeleton) is Skeleton3D):
				continue
			var unit := maxf(mi.global_basis.get_scale().x, 0.0001)
			var rests: Array = []
			var surfaces: Array = []
			for s in mi.mesh.get_surface_count():
				var arr := mi.mesh.surface_get_arrays(s)
				var rv: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
				var r := PackedVector3Array()
				r.resize(rv.size())
				for v in rv.size():
					r[v] = rv[v] * unit
				rests.append(r)
				surfaces.append(arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array())
			var first: PackedVector3Array = rests[0]
			if first.is_empty():
				continue
			var w := 256
			var h := maxi(1, ceili(first.size() / float(w)))
			var floats := PackedFloat32Array()
			floats.resize(w * h * 3)
			floats.fill(0.0)
			for v in first.size():
				floats[v * 3] = first[v].x
				floats[v * 3 + 1] = first[v].y
				floats[v * 3 + 2] = first[v].z
			var img := Image.create_from_data(w, h, false, Image.FORMAT_RGBF, floats.to_byte_array())
			var mat := ShaderMaterial.new()
			mat.shader = SHADER
			mat.set_shader_parameter("rest", ImageTexture.create_from_image(img))
			mat.set_shader_parameter("rest_w", w)
			mat.set_shader_parameter("cell", CELL)
			mi.material_overlay = mat
			out.append({"mi": mi, "material": mat, "rest": rests, "surfaces": surfaces,
					"colour": colour_of(mi.get_active_material(0))})
	owner.set_meta(&"stone_skins", out)
	return out


## The main colour of a material: a plain one's albedo, a pack creature's
## skin (creature_rgb's first colour).
static func colour_of(m: Material) -> Color:
	if m is BaseMaterial3D:
		return (m as BaseMaterial3D).albedo_color
	if m is ShaderMaterial:
		var c: Variant = (m as ShaderMaterial).get_shader_parameter("color1")
		if c is Color:
			return c
		if c is Vector3:
			var v := c as Vector3
			return Color(v.x, v.y, v.z)
	return Color(0.7, 0.68, 0.64)


## A blow kept: merged into one already near it, or a new one (the weakest
## dropped past MOST); sent to every skin's shader.
static func _add_blow(owner: Node3D, at: Vector3, reach: float, power: float) -> void:
	var blows: Array = owner.get_meta(&"stone_blows")
	var merged := false
	for b in blows:
		if (b[0] as Vector3).distance_to(at) < float(b[1]) * 0.35:
			b[1] = maxf(float(b[1]), reach)
			b[2] = float(b[2]) + power
			merged = true
			break
	if not merged:
		blows.append([at, reach, power])
		if blows.size() > MOST:
			blows.sort_custom(func(x: Array, y: Array) -> bool: return float(x[2]) > float(y[2]))
			blows.resize(MOST)
	owner.set_meta(&"stone_blows", blows)
	send(owner)


## The blows to every skin's shader.
static func send(owner: Node3D) -> void:
	var blows: Array = owner.get_meta(&"stone_blows", [])
	var places := PackedVector4Array()
	var powers := PackedFloat32Array()
	for b in blows:
		var p: Vector3 = b[0]
		places.append(Vector4(p.x, p.y, p.z, float(b[1])))
		powers.append(float(b[2]))
	while places.size() < MOST:
		places.append(Vector4(0, 0, 0, 1))
		powers.append(0.0)
	for sk in owner.get_meta(&"stone_skins", []):
		var m := sk["material"] as ShaderMaterial
		m.set_shader_parameter("hit_at", places)
		m.set_shader_parameter("hit_power", powers)
		m.set_shader_parameter("hit_count", blows.size())


## How hurt the rest place `p` is under `blows` (the shader's hurt_at,
## without its death wave).
static func hurt_at(p: Vector3, blows: Array) -> float:
	var h := 0.0
	for b in blows:
		var d := p.distance_to(b[0] as Vector3) / float(b[1])
		h += float(b[2]) * pow(clampf(1.0 - d, 0.0, 1.0), 0.7)
	return h


## The shader's cell hash (pcg3d of the cell's whole coordinates).
static func h3(c: Vector3i) -> Vector3:
	var x := (c.x + 65536) & 0xFFFFFFFF
	var y := (c.y + 65536) & 0xFFFFFFFF
	var z := (c.z + 65536) & 0xFFFFFFFF
	x = (x * 1664525 + 1013904223) & 0xFFFFFFFF
	y = (y * 1664525 + 1013904223) & 0xFFFFFFFF
	z = (z * 1664525 + 1013904223) & 0xFFFFFFFF
	x = (x + y * z) & 0xFFFFFFFF
	y = (y + z * x) & 0xFFFFFFFF
	z = (z + x * y) & 0xFFFFFFFF
	x ^= x >> 16
	y ^= y >> 16
	z ^= z >> 16
	x = (x + y * z) & 0xFFFFFFFF
	y = (y + z * x) & 0xFFFFFFFF
	z = (z + x * y) & 0xFFFFFFFF
	return Vector3(x, y, z) / 4294967295.0


## The cell of the net a rest place lies in (its nearest feature point).
static func cell_of(p: Vector3) -> Vector3i:
	var q := p / CELL
	var i := Vector3i(floori(q.x), floori(q.y), floori(q.z))
	var best := INF
	var at := i
	for z in range(-1, 2):
		for y in range(-1, 2):
			for x in range(-1, 2):
				var c := i + Vector3i(x, y, z)
				var d := (Vector3(c) + h3(c)).distance_squared_to(q)
				if d < best:
					best = d
					at = c
	return at


## Whether a cell is broken off under `blows` (the shader's test, at its
## middle).
static func cell_broken(c: Vector3i, blows: Array) -> bool:
	var mid := (Vector3(c) + h3(c)) * CELL
	return hurt_at(mid, blows) + (h3(c + Vector3i(17, 17, 17)).x - 0.5) * 0.3 > 0.6


## Where every corner of the skins is now (world), and its normal: per
## mesh, per surface [positions, normals].
static func _posed(skins: Array) -> Array:
	var out: Array = []
	for sk in skins:
		var mi := sk["mi"] as MeshInstance3D
		var mesh := mi.bake_mesh_from_current_skeleton_pose()
		var per: Array = []
		var xf := mi.global_transform
		for s in (sk["surfaces"] as Array).size():
			if mesh == null or s >= mesh.get_surface_count():
				per.append([PackedVector3Array(), PackedVector3Array()])
				continue
			var arr := mesh.surface_get_arrays(s)
			var vv: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var nn: PackedVector3Array = arr[Mesh.ARRAY_NORMAL] if arr[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
			var wv := PackedVector3Array()
			wv.resize(vv.size())
			var wn := PackedVector3Array()
			wn.resize(vv.size())
			for i in vv.size():
				wv[i] = xf * vv[i]
				wn[i] = (xf.basis * nn[i]).normalized() if not nn.is_empty() else Vector3.UP
			per.append([wv, wn])
		out.append(per)
	return out


## The corner nearest `point` on the side facing `out` (any side if `out` is
## zero): [position, normal, its rest place], or empty.
static func _nearest(skins: Array, posed: Array, point: Vector3, out: Vector3) -> Array:
	var best := INF
	var res: Array = []
	var any := out.length_squared() < 0.0001
	for k in posed.size():
		for s in (posed[k] as Array).size():
			var wv: PackedVector3Array = posed[k][s][0]
			var wn: PackedVector3Array = posed[k][s][1]
			for i in wv.size():
				var d := wv[i].distance_squared_to(point)
				if d < best and (any or wn[i].dot(out) > 0.1):
					best = d
					res = [wv[i], wn[i], (skins[k]["rest"][s] as PackedVector3Array)[i]]
	return res


## The faces (near the blow) whose cell broke off with it: [a, b, c (world),
## normal, colour].
static func _broken_now(skins: Array, posed: Array, before: Array, after: Array, at_rest: Vector3, reach: float) -> Array:
	var out: Array = []
	var seen := {}
	for k in skins.size():
		var sk: Dictionary = skins[k]
		for s in (sk["surfaces"] as Array).size():
			var idx: PackedInt32Array = sk["surfaces"][s]
			var rest: PackedVector3Array = sk["rest"][s]
			var wv: PackedVector3Array = posed[k][s][0]
			var wn: PackedVector3Array = posed[k][s][1]
			if wv.is_empty():
				continue
			var tris := int((idx.size() if not idx.is_empty() else wv.size()) / 3.0)
			for t in tris:
				var a := idx[t * 3] if not idx.is_empty() else t * 3
				var b := idx[t * 3 + 1] if not idx.is_empty() else t * 3 + 1
				var c := idx[t * 3 + 2] if not idx.is_empty() else t * 3 + 2
				var mid := (rest[a] + rest[b] + rest[c]) / 3.0
				if mid.distance_to(at_rest) > reach * 1.1:
					continue
				var cell := cell_of(mid)
				if not seen.has(cell):
					seen[cell] = cell_broken(cell, after) and not cell_broken(cell, before)
				if seen[cell]:
					out.append([wv[a], wv[b], wv[c], (wn[a] + wn[b] + wn[c]).normalized(), sk["colour"]])
	return out


## Over `time` a wave of cracks runs out over all of `owner` from `from`
## (world; its death, before [MarbleShatter] breaks it). False if it has no
## stone skin.
static func spread(owner: Node3D, from: Vector3, time: float) -> bool:
	var skins := skins_of(owner)
	if skins.is_empty():
		return false
	var posed := _posed(skins)
	var snap := _nearest(skins, posed, from, Vector3.ZERO)
	if snap.is_empty():
		return false
	var at_rest: Vector3 = snap[2]
	var reach := 0.1
	for sk in skins:
		for v in (sk["rest"][0] as PackedVector3Array):
			reach = maxf(reach, v.distance_to(at_rest))
	var it := Spread.new()
	it.skins = skins
	it.from = at_rest
	it.reach = reach
	it.time = maxf(time, 0.05)
	owner.add_child(it)
	return true


## How a struck creature's bones move: where each was and how fast it went,
## kept from frame to frame while it lives (and through a hit's pause, when
## nothing moves, the last true speeds kept).
class Motion extends Node:
	var creature: WeakRef
	var body: Node3D
	var points := PackedVector3Array()
	var vels := PackedVector3Array()

	func _process(delta: float) -> void:
		var c := creature.get_ref() as Node
		if c == null or body == null or delta <= 0.0:
			return
		if c.get(&"is_dead") == true:
			set_process(false)
			return
		var now := PackedVector3Array()
		for node in body.find_children("*", "Skeleton3D", true, false):
			var skel := node as Skeleton3D
			var xf := skel.global_transform
			for b in skel.get_bone_count():
				now.append(xf * skel.get_bone_global_pose(b).origin)
		if now.size() == points.size():
			var moved := 0.0
			for i in now.size():
				moved += now[i].distance_squared_to(points[i])
			if moved > 1e-6:
				vels.resize(now.size())
				for i in now.size():
					vels[i] = (now[i] - points[i]) / delta
		points = now

	## How fast the body was going at `at`: its nearest bone's speed.
	func speed_at(at: Vector3) -> Vector3:
		if vels.size() != points.size() or vels.is_empty():
			return Vector3.ZERO
		var best := 0
		var d := INF
		for i in points.size():
			var e := points[i].distance_squared_to(at)
			if e < d:
				d = e
				best = i
		return vels[best]


class Spread extends Node:
	var skins: Array
	var from: Vector3
	var reach := 1.0
	var time := 0.3
	var t := 0.0

	func _process(delta: float) -> void:
		t += delta
		var front := t / time * (reach + 0.35)
		for sk in skins:
			var m := sk["material"] as ShaderMaterial
			m.set_shader_parameter("wave_from", from)
			m.set_shader_parameter("wave_reach", front)
		if t >= time:
			set_process(false)
#endregion


#region Pieces knocked off
## The broken faces fly off: each a wedge, its face in the creature's
## colour, blood behind. A few, the biggest, at most [constant CHIPS].
static func _fling(world: Node, broke: Array, at: Vector3, out: Vector3, size: float) -> void:
	if broke.is_empty() or not (world is Node3D):
		return
	broke.sort_custom(func(x: Array, y: Array) -> bool:
		return _area(x) > _area(y))
	var flight := Flight.new()
	(world as Node3D).add_child(flight)
	var down := (world as Node3D).get_world_3d().direct_space_state.intersect_ray(
			PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.3, at + Vector3.DOWN * 12.0, 1))
	flight.floor_y = (down["position"] as Vector3).y if not down.is_empty() else at.y - 1.5
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector3i(roundi(at.x * 50.0), roundi(at.y * 50.0), roundi(at.z * 50.0))) + 7
	for f in broke.slice(0, CHIPS):
		var a: Vector3 = f[0]
		var b: Vector3 = f[1]
		var c: Vector3 = f[2]
		var n: Vector3 = f[3]
		var mid := (a + b + c) / 3.0
		# a little block of stone, not the face's own wedge (spiky shapes
		# were not liked, 2026-10-30): the skin's colour, wet blood where it
		# broke ([MarbleShatter]'s chunks)
		var thick := clampf(sqrt(_area(f)) * 1.1, 0.04, 0.14 * size)
		MarbleShatter._chunks_made()
		var mi := MeshInstance3D.new()
		mi.mesh = MarbleShatter._chunk_meshes[rng.randi_range(0, MarbleShatter._chunk_meshes.size() - 1)]
		mi.set_surface_override_material(0, MarbleShatter._skin_mat(f[4] as Color))
		mi.set_surface_override_material(1, MarbleShatter._blood_mats[rng.randi_range(0, MarbleShatter._blood_mats.size() - 1)])
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		flight.add_child(mi)
		mi.global_transform = Transform3D(Basis(Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized(),
				rng.randf_range(-PI, PI)) * Basis.from_scale(Vector3.ONE * thick), mid)
		var block := thick
		thick *= 0.4
		var vel := (n * rng.randf_range(1.2, 2.6) + out * 0.8 + Vector3.UP * rng.randf_range(0.6, 1.8)) * clampf(sqrt(size), 0.8, 1.6)
		var spin := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized() * rng.randf_range(4.0, 9.0)
		flight.pieces.append([mi, vel, spin, clampf(thick, 0.02, 0.1), 0.0, block])


static func _area(f: Array) -> float:
	return ((f[1] as Vector3) - (f[0] as Vector3)).cross((f[2] as Vector3) - (f[0] as Vector3)).length() * 0.5


## Small pieces in flight: fall, a bounce, lie a moment, shrink away.
class Flight extends Node3D:
	static var _mats: Dictionary = {}
	var pieces: Array = []
	var floor_y := 0.0
	var t := 0.0

	static func material(colour: Color, wet: bool) -> StandardMaterial3D:
		var key := "%s%s" % [colour.to_html(), wet]
		if _mats.has(key):
			return _mats[key]
		var m := StandardMaterial3D.new()
		m.albedo_color = colour
		m.roughness = 0.25 if wet else 0.8
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_mats[key] = m
		return m

	func _process(delta: float) -> void:
		t += delta
		for p in pieces:
			var mi := p[0] as MeshInstance3D
			var vel: Vector3 = p[1]
			var spin: Vector3 = p[2]
			var r := float(p[3])
			if float(p[4]) <= 0.0:
				vel.y -= 15.0 * delta
				mi.global_position += vel * delta
				if spin.length_squared() > 0.0001:
					mi.global_basis = Basis(spin.normalized(), spin.length() * delta) * mi.global_basis
				if mi.global_position.y < floor_y + r:
					mi.global_position.y = floor_y + r
					if absf(vel.y) < 1.0:
						p[4] = 0.0001
						vel = Vector3.ZERO
						spin = Vector3.ZERO
					else:
						vel = Vector3(vel.x * 0.5, -vel.y * 0.3, vel.z * 0.5)
						spin *= 0.5
				p[1] = vel
				p[2] = spin
			else:
				p[4] = float(p[4]) + delta
				# it lies a while on the ground, then goes down into it
				var k := clampf((float(p[4]) - 5.0) / 0.8, 0.0, 1.0)
				if k > 0.0:
					mi.global_position.y = floor_y + float(p[3]) - k * k * (float(p[5]) + 0.05)
		if t > 7.5:
			queue_free()
#endregion
