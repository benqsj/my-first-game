class_name WindBlast
extends RefCounted

## The pieces of a great shot of wind (the Piercing Arrow, after Ironeye's
## Single Shot): the burst of white shards off the bow, speed lines racing
## down the line, bands of air winding round it and opening out, a wall of
## mist left hanging along it, and the camera jolted. All white-grey and
## see-through; nothing is coloured and nothing lights anything.

const AIR := Color(0.93, 0.95, 0.98)
const MIST := Color(0.82, 0.84, 0.88)

static var _band_mat: StandardMaterial3D = null


## The release: a white flash and shards of it thrown forward in a cone.
static func release(into: Node, at: Vector3, dir: Vector3) -> void:
	if into == null:
		return
	SkillFx.flash(into, at, AIR, 0.6, 0.12, 2.5)
	cone(into, at, dir)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var side := _side(dir)
	var up := side.cross(dir).normalized()
	for i in 12:
		var a := rng.randf() * TAU
		var tilt := rng.randf_range(0.25, 1.1)
		var way := (dir * cos(tilt) + (side * cos(a) + up * sin(a)) * sin(tilt)).normalized()
		var from := at + way * 0.12
		_streak(into, from, from + way * rng.randf_range(0.5, 1.3), 0.012, 0.16, way * 1.5)
	# The air round him pushed out all at once.
	mist(into, at, 6, 0.6, Vector2(0.8, 1.6), 1.0)


## The blast itself, at the bow: a cone of air bursting forward — it
## reaches `reach` metres and opens to `radius` in a fifth of a second, then
## thins out — with two broad soft swirls turning round its mouth. This is
## where the mass of the effect is, by the archer, as in the reference.
static func cone(into: Node, at: Vector3, dir: Vector3, reach: float = 9.0, radius: float = 2.6,
		life: float = 0.55) -> void:
	if into == null:
		return
	var mi := MeshInstance3D.new()
	mi.mesh = _cone_mesh()
	var mat := _band_material().duplicate() as StandardMaterial3D
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	into.add_child(mi)
	var base := Basis.looking_at(dir, Vector3.RIGHT if absf(dir.dot(Vector3.UP)) > 0.95 else Vector3.UP)
	var place := func(u: float) -> void:
		if not is_instance_valid(mi):
			return
		var grow := 1.0 - pow(1.0 - minf(u * 2.6, 1.0), 3.0)
		var b := base.rotated(dir, u * 3.0)
		var r := radius * (0.3 + 0.7 * grow)
		mi.global_transform = Transform3D(Basis(b.x * r, b.y * r, b.z * reach * (0.15 + 0.85 * grow)), at)
		mat.albedo_color.a = 0.34 * (1.0 - u) * (1.0 - u) * end_on(mi, dir, 0.55)
	place.call(0.0)
	var tw := mi.create_tween()
	tw.tween_method(place, 0.0, 1.0, life)
	tw.tween_callback(mi.queue_free)
	# Broad swirls round the mouth of it.
	for k in 2:
		twister(into, at + dir * 0.3, dir, 3.5, 0.5, 2.2 + 0.6 * float(k), 0.6 + 0.15 * float(k),
				float(k) * PI, 9.0, 1.6, 0.5)


## A punch of the camera's field of view (wider, then back), for the shot's
## kick — local, only for a camera near it.
static func kick(near: Node3D, degrees: float = 7.0, time: float = 0.4, reach: float = 30.0) -> void:
	if near == null or not near.is_inside_tree():
		return
	var cam := near.get_viewport().get_camera_3d()
	if cam == null or cam.global_position.distance_to(near.global_position) > reach:
		return
	var was := cam.fov
	var tw := cam.create_tween()
	tw.tween_property(cam, "fov", was + degrees, time * 0.15).set_ease(Tween.EASE_OUT)
	tw.tween_property(cam, "fov", was, time * 0.85).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)


## Speed lines: thin streaks strewn round the first `reach` metres of the
## line, racing on along it as they fade.
static func speed_lines(into: Node, from: Vector3, dir: Vector3, reach: float, count: int = 22) -> void:
	if into == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var side := _side(dir)
	var up := side.cross(dir).normalized()
	for i in count:
		var along := rng.randf_range(0.5, reach)
		var a := rng.randf() * TAU
		var r := rng.randf_range(0.35, 2.4)
		var at := from + dir * along + (side * cos(a) + up * sin(a)) * r
		var length := rng.randf_range(2.0, 5.0)
		_streak(into, at, at + dir * length, 0.008, rng.randf_range(0.18, 0.32), dir * 14.0)


## A band of air winding round the line at `at`: a ribbon partway round a
## circle, twisting forward as it goes, opening from `from_r` to `to_r` and
## fading over `life` seconds while it turns.
static func band(into: Node, at: Vector3, dir: Vector3, from_r: float, to_r: float, life: float,
		start_angle: float, sweep: float = 3.4) -> void:
	if into == null:
		return
	var mi := MeshInstance3D.new()
	mi.mesh = _band_mesh(sweep)
	mi.material_override = _band_material().duplicate()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	into.add_child(mi)
	var base := Basis.looking_at(dir, Vector3.RIGHT if absf(dir.dot(Vector3.UP)) > 0.95 else Vector3.UP)
	var mat := mi.material_override as StandardMaterial3D
	var place := func(u: float) -> void:
		if not is_instance_valid(mi):
			return
		var r := lerpf(from_r, to_r, 1.0 - pow(1.0 - u, 3.0))
		mi.global_transform = Transform3D(base.rotated(dir, start_angle + u * 1.6).scaled(Vector3.ONE * r), at)
		mat.albedo_color.a = 0.35 * (1.0 - u * u) * end_on(mi, dir)
	place.call(0.0)
	var tw := mi.create_tween()
	tw.tween_method(place, 0.0, 1.0, life)
	tw.tween_callback(mi.queue_free)


## A stretch of the tornado the arrow leaves: `strands` ribbons wound round
## the line from `at` on for `length` metres, spinning about it fast, opening
## from `from_r` to `to_r` and fading over `life`. Laid end to end as the
## arrow goes they make one twisting funnel of air.
static func twister(into: Node, at: Vector3, dir: Vector3, length: float, from_r: float, to_r: float,
		life: float, phase: float, spin: float = 14.0, width: float = 1.0, strength: float = 0.6) -> void:
	if into == null:
		return
	var mi := MeshInstance3D.new()
	mi.mesh = _helix_mesh(length, 0.35, 2, width)
	var mat := _band_material().duplicate() as StandardMaterial3D
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	into.add_child(mi)
	var base := Basis.looking_at(dir, Vector3.RIGHT if absf(dir.dot(Vector3.UP)) > 0.95 else Vector3.UP)
	var place := func(u: float) -> void:
		if not is_instance_valid(mi):
			return
		var r := lerpf(from_r, to_r, 1.0 - pow(1.0 - u, 2.0))
		var b := base.rotated(dir, phase + u * life * spin)
		mi.global_transform = Transform3D(Basis(b.x * r, b.y * r, b.z), at)
		mat.albedo_color.a = strength * minf(u * 6.0, 1.0) * (1.0 - u * u) * end_on(mi, dir)
	place.call(0.0)
	var tw := mi.create_tween()
	tw.tween_method(place, 0.0, 1.0, life)
	tw.tween_callback(mi.queue_free)


## Mist left hanging: `count` big soft puffs round `at`, drifting out and up.
static func mist(into: Node, at: Vector3, count: int, spread: float, size: Vector2, life: float) -> void:
	if into == null:
		return
	SkillFx.particles(into, at, {
		"amount": count, "life": life, "one_shot": true, "explosiveness": 0.85,
		"speed": Vector2(1.0, 3.0), "spread": 180.0, "dir": Vector3.UP, "damping": 1.2,
		"gravity": Vector3(0, 0.25, 0), "sphere": spread, "size": size, "grow": 0.85, "add": false,
		"colors": [Color(1, 1, 1, 0.0), Color(MIST.r, MIST.g, MIST.b, 0.03), Color(MIST.r, MIST.g, MIST.b, 0.0)],
	})


## Jolts the camera looking at it (if it is near): a few quick offsets,
## settling back.
static func shake(near: Node3D, strength: float = 0.12, time: float = 0.35, reach: float = 30.0) -> void:
	if near == null or not near.is_inside_tree():
		return
	var cam := near.get_viewport().get_camera_3d()
	if cam == null or cam.global_position.distance_to(near.global_position) > reach:
		return
	var tw := cam.create_tween()
	var steps := 7
	for i in steps:
		var k := strength * (1.0 - float(i) / float(steps))
		tw.tween_property(cam, "h_offset", randf_range(-k, k), time / float(steps + 1))
		tw.parallel().tween_property(cam, "v_offset", randf_range(-k, k) * 0.7, time / float(steps + 1))
	tw.tween_property(cam, "h_offset", 0.0, time / float(steps + 1))
	tw.parallel().tween_property(cam, "v_offset", 0.0, time / float(steps + 1))


static func _streak(into: Node, a: Vector3, b: Vector3, radius: float, life: float, drift: Vector3) -> void:
	var rod := SkillFx.rod(into, a, b, AIR, radius, 0.9)
	if rod == null:
		return
	var mat := rod.material_override as StandardMaterial3D
	mat.albedo_color.a = 0.55
	var tw := rod.create_tween().set_parallel(true)
	tw.tween_property(rod, "global_position", rod.global_position + drift * life, life)
	tw.tween_property(mat, "albedo_color:a", 0.0, life)
	tw.chain().tween_callback(rod.queue_free)


## How much of a ring round the line to show from where the camera is: all
## of it seen from the side, little of it seen down the line (from behind the
## archer, where rings stack into a target of circles).
static func end_on(node: Node3D, dir: Vector3, least: float = 0.3) -> float:
	var cam := node.get_viewport().get_camera_3d() if node.is_inside_tree() else null
	if cam == null:
		return 1.0
	var look := -cam.global_basis.z
	return lerpf(1.0, least, smoothstep(0.55, 0.92, absf(look.dot(dir))))


static func _side(dir: Vector3) -> Vector3:
	var s := dir.cross(Vector3.UP)
	if s.length_squared() < 0.001:
		s = dir.cross(Vector3.RIGHT)
	return s.normalized()


## A unit ribbon partway round a circle in the XY plane (the line is -Z),
## creeping forward as it goes round so it reads as a twist of wind; its ends
## fade out.
static func _band_mesh(sweep: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 28
	for i in n:
		var rows: Array = []
		for step in [0, 1]:
			var t := float(i + step) / float(n)
			var a := t * sweep
			var ring := Vector3(cos(a), sin(a), 0.0)
			var ahead := Vector3(0.0, 0.0, -t * 0.9)
			rows.append([ring + ahead, sin(t * PI) * (0.55 + 0.45 * t)])
		_soft_quad(st, rows[0][0], rows[1][0], Vector3(0.0, 0.0, 0.5), rows[0][1], rows[1][1])
	return st.commit()


## `strands` ribbons wound `turns` times round a unit circle in XY while
## running `length` along -Z; each ribbon thins and fades at its ends and is
## brighter on its leading edge.
static func _helix_mesh(length: float, turns: float, strands: int, width: float = 1.0) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 40
	for k in strands:
		var off := TAU * float(k) / float(strands)
		for i in n:
			var rows: Array = []
			for step in [0, 1]:
				var t := float(i + step) / float(n)
				var a := off + t * turns * TAU
				rows.append([Vector3(cos(a), sin(a), 0.0) + Vector3(0.0, 0.0, -t * length), sin(t * PI)])
			_soft_quad(st, rows[0][0], rows[1][0], Vector3(0.0, 0.0, 0.7 * width), rows[0][1], rows[1][1])
	return st.commit()


## One step of a soft ribbon from `a` to `b`, `across` wide: see-through at
## both edges, brightest down its middle — air, not a wire.
static func _soft_quad(st: SurfaceTool, a: Vector3, b: Vector3, across: Vector3, alpha_a: float,
		alpha_b: float) -> void:
	var h := across * 0.5
	var edge := Color(1, 1, 1, 0.0)
	var mid_a := Color(1, 1, 1, alpha_a)
	var mid_b := Color(1, 1, 1, alpha_b)
	# Two strips, outer edge to middle on either side.
	for side in [-1.0, 1.0]:
		var verts: Array[Vector3] = [a + h * side, a, b + h * side, b]
		var cols: Array[Color] = [edge, mid_a, edge, mid_b]
		for idx in [0, 1, 2, 1, 3, 2]:
			st.set_color(cols[idx])
			st.add_vertex(verts[idx])


## An open cone, apex at the origin, mouth a unit circle one unit down -Z:
## clear at the apex and the rim, thickest a little way in — a bell of air.
static func _cone_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var seg := 32
	var rows := 8
	for j in rows:
		for i in seg:
			var quad: Array[Vector3] = []
			var cols: Array[Color] = []
			for dj in [0, 1]:
				for di in [0, 1]:
					var t := float(j + dj) / float(rows)
					var a := TAU * float(i + di) / float(seg)
					# A bell: the side flares out towards the mouth.
					var r := pow(t, 0.6)
					quad.append(Vector3(cos(a) * r, sin(a) * r, -t))
					cols.append(Color(1, 1, 1, sin(pow(t, 0.8) * PI) * 0.9))
			for idx in [0, 1, 2, 1, 3, 2]:
				st.set_color(cols[idx])
				st.add_vertex(quad[idx])
	return st.commit()


static func _band_material() -> StandardMaterial3D:
	if _band_mat == null:
		_band_mat = StandardMaterial3D.new()
		_band_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_band_mat.vertex_color_use_as_albedo = true
		_band_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_band_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_band_mat.albedo_color = Color(AIR.r, AIR.g, AIR.b, 0.75)
	return _band_mat
