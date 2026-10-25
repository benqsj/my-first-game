class_name ThroneCourt
extends RefCounted

## The orc lord's court (the "throne" place; the user's pick of the concept
## pictures, 2026-10-25: C first, A and B as well). High-end low poly as the
## forest: the pieces in `throne_court_lowpoly.glb` (Blender,
## `vepxis-art/world/throne_court_lowpoly.py`).
##
## * **c** (the default): a round arena of grey flagstones on a cliff top in
##   the mist, a broken low wall and standing stones round it, the stairs up
##   at the way in; at the far end the lord's rough stone throne on a dais
##   under a great twisted tree in rust-red leaf, totems of wood and bone,
##   tall poles with dark red banners, a fire either side of the dais (his
##   guard come out of them: [LordFight], at ±6.5, −l/2+9). Ashen's pale
##   light ([method Dungeon._court_look]).
## * **a**: the warlord's camp on a mountain fortress: dark flagstones, a
##   palisade of sharpened logs round it, stone towers at its corners, his
##   throne of black iron with a great orc skull over it, iron braziers,
##   racks of spears and shields, war banners; a grey dusk. (Liked as a
##   place of its own, 2026-10-25: the "camp" place is built as this.)
## * **b**: the old royal court the orcs took: pale arcades down both sides,
##   a domed pavilion over the golden throne, two heroes in stone by it,
##   cypresses, gold braziers, long banners, the snowy mountains round about;
##   a golden afternoon (the terraces' own pieces, [TerracePlaces]).
##
## The place is 64 by 64 only so that its round floor fits: an unseen wall
## stands round the rim at [constant RIM].

const DIR := "res://assets/dungeon/throne_court/"
const KIT := DIR + "throne_court_lowpoly.glb"
## The same numbers as the Blender script's.
const WALK_R := 30.0
const RIM := 30.6
const DAIS_Z := -27.0
const TREE_Z := -31.5
const RIM_H := 6.0
## The tree as big as the concept's: over the whole far end.
const TREE_S := 1.7
## Where the long stairs start, out at the cliff's lip past the gap.
const STAIRS_AT := 34.2
## The orcs baked in stone (`_shots_tmp/bake_orc_statues.gd`; the user,
## 2026-10-25: no statues of men in the orcs' places).
const ORC_STATUES := "res://assets/dungeon/statues/%s.res"
## Which look (F2's board; "" is "c").
static var look := ""

static var _kit: Node3D


## The look in force: "a", "b" or "c".
static func current() -> String:
	return look if look in ["a", "b", "c"] else "c"


## `which`: a look to build whatever F2's board says ("a" for the orcs' war
## camp, a place of its own: "camp" in [constant Dungeon.PLACES]).
static func build(d: Dungeon, room: Node3D, w: float, l: float, rng: RandomNumberGenerator, which := "") -> void:
	_ready_kit()
	match which if which != "" else current():
		"a":
			_camp(d, room, w, l, rng)
		"b":
			_royal(d, room, w, l, rng)
		_:
			_misty(d, room, w, l, rng)


#region C: the misty court
static func _misty(d: Dungeon, room: Node3D, w: float, l: float, rng: RandomNumberGenerator) -> void:
	_floor_and_rim(room)
	d._bounds(room, w, l)
	_shadows(_piece(room, "KFloor", Vector3.ZERO), GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	for name: String in ["KWall", "KMenhirs", "KCliff"]:
		_piece(room, name, Vector3.ZERO)
	# the stairs out of the gap at the way in, down and down into the cloud
	_piece(room, "KStairsLong", Vector3(0.0, 0.0, STAIRS_AT))
	_dais(d, room)
	_poles(room, rng)
	# two orcs in stone either side of the way in, looking up the court
	for sx: float in [-1.0, 1.0]:
		_orc_statue(room, Vector3(sx * 5.2, 0.0, WALK_R - 2.4), 0.0, "orc", Color(0.56, 0.56, 0.56))
	_far(room, rng)
	d._cloud_layers(room, -34.0)
	d._circling_birds(room)
	TerracePlaces._motes(room, w, l, Color(0.92, 0.92, 0.9), 140)
	_falling_leaves(room)


## The lord's dais, his throne, the tree over it, his totems and his fires.
static func _dais(d: Dungeon, room: Node3D) -> void:
	_steps(_piece(room, "KDais", Vector3(0.0, 0.0, DAIS_Z)))
	var seat := _piece(room, "KThrone", Vector3(0.0, 0.9, DAIS_Z - 1.6))
	TerracePlaces._box(seat, Vector3(2.4, 4.0, 1.8), Vector3(0.0, 2.0, -0.3))
	var tree := _piece(room, "KTree", Vector3(0.0, 0.9, TREE_Z), 0.4, TREE_S)
	TerracePlaces._post_col(tree, 1.3 / TREE_S, 8.0)
	_shadows(tree, GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED)
	for sx: float in [-1.0, 1.0]:
		var t := _piece(room, "KTotem", Vector3(sx * 3.6, 0.9, DAIS_Z - 1.4), sx * 0.3)
		TerracePlaces._post_col(t, 0.3, 4.0)
		var t2 := _piece(room, "KTotem", Vector3(sx * 10.5, 0.0, DAIS_Z + 3.5), sx * 0.5 + 0.2)
		TerracePlaces._post_col(t2, 0.3, 4.0)
		_fire(d, room, Vector3(sx * 7.6, 0.0, DAIS_Z + 0.5))


## A dais's steps walked up: three boxes, each a step higher and less deep
## (the same for the misty court's half-round and the camp's square one).
static func _steps(dais: Node3D) -> void:
	TerracePlaces._box(dais, Vector3(12.6, 0.3, 7.1), Vector3(0.0, 0.15, -0.47))
	TerracePlaces._box(dais, Vector3(11.2, 0.6, 6.6), Vector3(0.0, 0.3, -0.68))
	TerracePlaces._box(dais, Vector3(9.8, 0.9, 6.2), Vector3(0.0, 0.45, -0.9))


## A fire in its pit, low; its light is one the lord's fight flares ([method
## Dungeon._fire_light]).
static func _fire(d: Dungeon, room: Node3D, at: Vector3) -> void:
	var pit := _piece(room, "KFirePit", at, at.x * 0.1)
	TerracePlaces._post_col(pit, 1.1, 0.6)
	room.add_child(d._flame(at + Vector3(0.0, 0.25, 0.0), 1.8, 30))
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.6, 0.3)
	light.light_energy = 2.6
	light.omni_range = 12.0
	light.position = at + Vector3(0.0, 1.6, 0.0)
	room.add_child(d._fire_light(light))


## Tall poles round the rim, a dark red banner on each, turned to the middle;
## not over the way in, nor over the portals at (±9, −l/2+10).
static func _poles(room: Node3D, rng: RandomNumberGenerator) -> void:
	for deg: float in [-38.0, 38.0, -78.0, 78.0, -118.0, 118.0, -152.0, 152.0]:
		var a := deg_to_rad(deg)
		var at := Vector3(sin(a) * (WALK_R - 1.0), 0.0, cos(a) * (WALK_R - 1.0))
		var yaw := a + rng.randf_range(-0.2, 0.2)
		var p := _piece(room, "KPole", at, yaw)
		TerracePlaces._post_col(p, 0.25, 9.0)
		_piece(room, "KPoleCloth", at, yaw)


## Far pillars of rock standing out of the mist round about.
static func _far(room: Node3D, rng: RandomNumberGenerator) -> void:
	for k in 14:
		var a := float(k) / 14.0 * TAU + rng.randf_range(-0.15, 0.15)
		var r := rng.randf_range(160.0, 380.0)
		var big := rng.randf() < 0.5
		var s := rng.randf_range(0.7, 1.3)
		var p := _piece(room, "KSpire1" if big else "KSpire0", Vector3(sin(a) * r, rng.randf_range(-80.0, -55.0), cos(a) * r),
				rng.randf_range(0.0, TAU), s)
		_shadows(p, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)


## A few red leaves drifting down from the tree, across the dais.
static func _falling_leaves(room: Node3D) -> void:
	var p := GPUParticles3D.new()
	p.amount = 36
	p.lifetime = 10.0
	p.preprocess = 10.0
	p.position = Vector3(0.0, 16.0, TREE_Z + 2.0)
	p.visibility_aabb = AABB(Vector3(-20.0, -14.0, -20.0), Vector3(40.0, 20.0, 40.0))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(12.0, 3.0, 9.0)
	pm.gravity = Vector3(0.25, -0.45, 0.35)
	pm.initial_velocity_min = 0.0
	pm.initial_velocity_max = 0.3
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.8
	pm.turbulence_noise_scale = 2.5
	pm.angle_min = 0.0
	pm.angle_max = 360.0
	pm.angular_velocity_min = -90.0
	pm.angular_velocity_max = 90.0
	pm.scale_min = 0.7
	pm.scale_max = 1.2
	var fade := Gradient.new()
	fade.set_color(0, Color(0.70, 0.30, 0.16, 0.0))
	fade.add_point(0.1, Color(0.70, 0.30, 0.16, 0.9))
	fade.add_point(0.85, Color(0.62, 0.24, 0.14, 0.9))
	fade.set_color(fade.get_point_count() - 1, Color(0.6, 0.22, 0.13, 0.0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	pm.color_ramp = ramp
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.16, 0.11)
	var qm := StandardMaterial3D.new()
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.vertex_color_use_as_albedo = true
	qm.albedo_texture = PlaceBuild.soft_dot()
	q.material = qm
	p.draw_pass_1 = q
	room.add_child(p)


#endregion


#region A: the warlord's camp
static func _camp(d: Dungeon, room: Node3D, w: float, l: float, rng: RandomNumberGenerator) -> void:
	var hw := w * 0.5
	var hl := l * 0.5
	_flat_floor(d, room, w, l)
	_shadows(_piece(room, "APFloor", Vector3.ZERO), GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	d._crag_under(room, w + 6.0, l + 6.0, PalaceVista.DROP + 40.0, -24.0)
	# the palisade round it (its rails to the room), open in the middle of the near side
	var e := hw + 0.3
	var n := int(ceil(2.0 * e / 8.0))
	var seg := 2.0 * e / float(n)
	for k in n:
		var t := -e + (float(k) + 0.5) * seg
		for side: Array in [[Vector3(-e, 0.0, t), PI * 0.5], [Vector3(e, 0.0, t), -PI * 0.5], [Vector3(t, 0.0, -e), 0.0]]:
			var p := _piece(room, "APalisade", side[0] as Vector3, float(side[1]))
			p.scale.x = seg / 8.0 * 1.01
		if absf(t) > 5.0:
			var near := _piece(room, "APalisade", Vector3(t, 0.0, e), PI)
			near.scale.x = seg / 8.0 * 1.01
	for at: Vector3 in [Vector3(-e - 0.8, 0.0, -e - 0.8), Vector3(e + 0.8, 0.0, -e - 0.8), Vector3(-e - 0.8, 0.0, e + 0.8),
			Vector3(e + 0.8, 0.0, e + 0.8), Vector3(-6.2, 0.0, e + 1.4), Vector3(6.2, 0.0, e + 1.4)]:
		_piece(room, "ATower", at, rng.randf_range(-0.05, 0.05))
	# the lord's dais and his throne, his braziers, his totems
	_steps(_piece(room, "ADais", Vector3(0.0, 0.0, DAIS_Z)))
	var seat := _piece(room, "AThrone", Vector3(0.0, 0.9, DAIS_Z - 1.6))
	TerracePlaces._box(seat, Vector3(2.6, 4.0, 1.8), Vector3(0.0, 2.0, -0.3))
	for sx: float in [-1.0, 1.0]:
		_iron_fire(d, room, Vector3(sx * 7.6, 0.0, DAIS_Z + 0.5))
		_iron_fire(d, room, Vector3(sx * 15.0, 0.0, -6.0))
		var t := _piece(room, "KTotem", Vector3(sx * 4.0, 0.9, DAIS_Z - 1.2), sx * 0.3)
		TerracePlaces._post_col(t, 0.3, 4.0)
		for z: float in [-14.0, 0.0, 14.0]:
			var pole := _piece(room, "KPole", Vector3(sx * (hw - 1.4), 0.0, z), PI * 0.5)
			TerracePlaces._post_col(pole, 0.25, 9.0)
			_piece(room, "KPoleCloth", Vector3(sx * (hw - 1.4), 0.0, z), PI * 0.5)
		for z: float in [-8.0, 7.0, 21.0]:
			var rack := _piece(room, "ARack", Vector3(sx * (hw - 1.0), 0.0, z), -sx * PI * 0.5)
			TerracePlaces._box(rack, Vector3(3.2, 2.6, 1.0), Vector3(0.0, 1.3, 0.0))
	# two orcs in stone by the gap in the palisade, and the stairs out of it
	# down into the cloud
	for sx: float in [-1.0, 1.0]:
		_orc_statue(room, Vector3(sx * 9.0, 0.0, hl - 3.0), 0.0, "orc_lord" if sx < 0.0 else "orc", Color(0.30, 0.29, 0.29))
	_piece(room, "KStairsLong", Vector3(0.0, 0.0, hw + 1.0))
	TerracePlaces._ready_kit()
	TerracePlaces._ring(room, ["Mount2", "Mount0"], 320.0, 520.0, [-2.6, -1.9, -1.2, -0.6, 0.0, 0.6, 1.2, 1.9, 2.6], -150.0, rng, 1.6, 2.4)
	d._cloud_layers(room, -60.0)
	d._circling_birds(room)
	TerracePlaces._motes(room, w, l, Color(1.0, 0.7, 0.45), 120)


## An iron brazier, its fire high in the bowl; its light the lord's fight flares.
static func _iron_fire(d: Dungeon, room: Node3D, at: Vector3) -> void:
	var b := _piece(room, "ABrazier", at)
	TerracePlaces._post_col(b, 0.8, 1.4)
	room.add_child(d._flame(at + Vector3(0.0, 1.35, 0.0), 2.0, 32))
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.58, 0.28)
	light.light_energy = 2.8
	light.omni_range = 13.0
	light.position = at + Vector3(0.0, 2.4, 0.0)
	room.add_child(d._fire_light(light))
#endregion


#region B: the royal court
static func _royal(d: Dungeon, room: Node3D, w: float, l: float, rng: RandomNumberGenerator) -> void:
	TerracePlaces._ready_kit()
	var hw := w * 0.5
	var hl := l * 0.5
	_flat_floor(d, room, w, l)
	var f := TerracePlaces._piece(room, "CFloor", Vector3.ZERO, 0.0, 1.0, false)
	if f != null:
		f.scale = Vector3(w / 66.0, 1.0, l / 78.0)
	d._crag_under(room, w + 14.0, l + 6.0, PalaceVista.DROP + 40.0, -24.0)
	# arcades down both sides and across both ends, banners on their piers
	var bay := 5.9
	var n := int(ceil((l + 2.0) / bay))
	for side: float in [-1.0, 1.0]:
		for k in n:
			var z := -hl - 1.0 + (float(k) + 0.5) * (l + 2.0) / float(n)
			var a := TerracePlaces._piece(room, "CArcade", Vector3(side * (hw + 1.0), 0.0, z), -PI * 0.5 * side)
			if a != null:
				a.scale.x = (l + 2.0) / float(n) / bay
			if k % 2 == 0:
				TerracePlaces._piece(room, "BannerLong", Vector3(side * (hw - 0.1), 8.6, z - (l + 2.0) / float(n) * 0.5), -PI * 0.5 * side)
		d._blocker(room, Vector3(2.0, 14.0, l + 2.0), Vector3(side * (hw + 1.0), 7.0, 0.0))
		TerracePlaces._piece(room, "CGallery", Vector3(side * (hw + 4.6), 0.0, 0.0), 0.0 if side < 0.0 else PI)
		var stone := StandardMaterial3D.new()
		stone.albedo_color = Color(0.70, 0.60, 0.47)
		stone.roughness = 0.9
		d._solid(room, stone, Vector3(1.2, 14.0, l + 6.0), Vector3(side * (hw + 7.5), 7.0, 0.0), false)
	var m := int(ceil((w + 2.0) / bay))
	for end: float in [-1.0, 1.0]:
		for k in m:
			var x := -hw - 1.0 + (float(k) + 0.5) * (w + 2.0) / float(m)
			var a := TerracePlaces._piece(room, "CArcadeEnd", Vector3(x, 0.0, end * (hl + 1.0)), PI if end > 0.0 else 0.0)
			if a != null:
				a.scale.x = (w + 2.0) / float(m) / bay
		d._blocker(room, Vector3(w + 2.0, 14.0, 2.0), Vector3(0.0, 7.0, end * (hl + 1.0)))
	# the golden throne on its dais, a gold brazier
	# either side, two heroes in stone by it
	var dais := TerracePlaces._piece(room, "CDais", Vector3(0.0, 0.0, DAIS_Z))
	if dais != null:
		TerracePlaces._box(dais, Vector3(12.0, 0.9, 6.0), Vector3(0.0, 0.45, 0.0))
		TerracePlaces._box(dais, Vector3(2.4, 4.5, 2.0), Vector3(0.0, 2.2, -1.6))
	# domed pavilions at the far corners, behind the arcades
	for sx: float in [-1.0, 1.0]:
		TerracePlaces._piece(room, "CPavilion", Vector3(sx * (hw + 3.0), 0.0, -hl - 3.0), 0.0)
	var heroes: Array = TerracePlaces.PLACE_HEROES.get("clouds", ["dark_mage", "dark_archer"])
	for sx: float in [-1.0, 1.0]:
		TerracePlaces._brazier(d, room, Vector3(sx * 7.6, 0.0, DAIS_Z + 0.5), 3.6)
		TerracePlaces._knight(room, Vector3(sx * 11.5, 0.0, DAIS_Z - 0.5), 0.0, false, String(heroes[0 if sx < 0.0 else 1]))
		# cypresses in their pots down the sides
		var cz := -14.0
		while cz < hl - 6.0:
			var pot := TerracePlaces._piece(room, "PlanterSand", Vector3(sx * (hw - 2.6), 0.0, cz))
			if pot != null:
				TerracePlaces._box(pot, Vector3(1.5, 1.2, 1.5), Vector3(0.0, 0.6, 0.0))
			TerracePlaces._piece(room, "Cypress%d" % (absi(int(cz)) % 2), Vector3(sx * (hw - 2.6), 0.95, cz),
					rng.randf_range(0.0, TAU), rng.randf_range(0.9, 1.05))
			cz += 9.5
	TerracePlaces._ring(room, ["Mount2", "Mount0"], 260.0, 420.0, [-2.6, -1.9, -1.2, -0.6, 0.0, 0.6, 1.2, 1.9, 2.6], -140.0, rng, 1.6, 2.4)
	d._cloud_layers(room, -60.0)
	d._circling_birds(room)
	TerracePlaces._motes(room, w, l, Color(1.0, 0.92, 0.7), 180)
#endregion


## An orc in stone (`which`: "orc" or "orc_lord") on a plinth, `tint` its stone.
static var _orc_meshes: Dictionary = {}
static func _orc_statue(room: Node3D, at: Vector3, yaw: float, which: String, tint: Color) -> void:
	var p := TerracePlaces._piece(room, "PostPlinth", at, yaw)
	if p != null:
		TerracePlaces._box(p, Vector3(1.4, 3.0, 1.4), Vector3(0.0, 1.5, 0.0))
	var path := ORC_STATUES % which
	if not _orc_meshes.has(which):
		_orc_meshes[which] = load(path) as Mesh if ResourceLoader.exists(path) else null
	var m := _orc_meshes[which] as Mesh
	if m == null:
		return
	var mi := MeshInstance3D.new()
	mi.mesh = m
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	mat.roughness = 0.9
	mi.material_override = mat
	var aabb := m.get_aabb()
	var k := 3.0 / maxf(aabb.size.y, 0.01)
	mi.transform = Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * k), at + Vector3(0.0, 2.15 - aabb.position.y * k, 0.0))
	room.add_child(mi)


## A square place's floor walked on: a box at 0 (its drawn floor is a piece).
static func _flat_floor(d: Dungeon, room: Node3D, w: float, l: float) -> void:
	var slab := d._solid(room, TerracePlaces._solid(0.0), Vector3(w + 2.0, 1.0, l + 2.0), Vector3(0.0, -0.5, 0.0))
	for mi in slab.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).visible = false
	d._bounds(room, w, l)


## One round floor under it all and an unseen wall round its rim (as the
## island's, [SkyTemple]).
static func _floor_and_rim(room: Node3D) -> void:
	var body := StaticBody3D.new()
	body.name = "CourtFloor"
	var floor_shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = RIM + 1.0
	cyl.height = 1.0
	floor_shape.shape = cyl
	floor_shape.position.y = -0.5
	body.add_child(floor_shape)
	var n := 40
	var seg := TAU * RIM / float(n) + 0.4
	for k in n:
		var a := float(k) / float(n) * TAU
		var s := CollisionShape3D.new()
		var b := BoxShape3D.new()
		b.size = Vector3(seg, RIM_H, 1.0)
		s.shape = b
		s.transform = Transform3D(Basis(Vector3.UP, a), Vector3(sin(a) * (RIM + 0.5), RIM_H * 0.5, cos(a) * (RIM + 0.5)))
		body.add_child(s)
	room.add_child(body)


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
				"Leaves":
					mi.set_surface_override_material(s, TerracePlaces._foliage(0.04))
				"Cloth":
					mi.set_surface_override_material(s, TerracePlaces._foliage(0.14))
				"Iron", "Bone":
					mi.set_surface_override_material(s, TerracePlaces._solid(0.0, 1.0, 0.5))
				"Rock":
					mi.set_surface_override_material(s, TerracePlaces._solid(0.0, 1.05, 0.95))
				_:
					mi.set_surface_override_material(s, TerracePlaces._solid(0.15, 1.05, 0.9))


static func _piece(room: Node3D, piece: String, at: Vector3, yaw: float = 0.0, s: float = 1.0) -> Node3D:
	var src := _kit.get_node_or_null(piece) as Node3D
	if src == null:
		push_warning("ThroneCourt: no piece " + piece)
		var none := Node3D.new()
		room.add_child(none)
		return none
	var n := src.duplicate() as Node3D
	n.transform = Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * s), at)
	room.add_child(n)
	return n


static func _shadows(n: Node3D, how: GeometryInstance3D.ShadowCastingSetting) -> void:
	for g in n.find_children("*", "GeometryInstance3D", true, false) + [n]:
		if g is GeometryInstance3D:
			(g as GeometryInstance3D).cast_shadow = how
