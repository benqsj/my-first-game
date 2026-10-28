class_name DungeonBuild
extends RefCounted

## A portal place put up: its floor, walls, roof, props, plants, lights and
## the little that moves in it ([Dungeon]'s rooms). Taken out of dungeon.gd
## (2026-10-28) so the run's flow and a place's building are apart; every
## function takes the dungeon as `dun` and works on it as it did before.
## [Dungeon] keeps a one-line function of the same name for each one called
## from outside this file (other scripts, signals, the run itself).

static func _build_room(dun: Dungeon, i: int) -> void:
	DungeonBuild._build_room_body(dun, i)
	if i < dun._room_nodes.size():
		DungeonBuild._block_fires(dun, dun._room_nodes[i])


static func _build_room_body(dun: Dungeon, i: int) -> void:
	var r := dun._room(i)
	var kind: String = r["kind"]
	var w: float = r["w"]
	var l: float = r["l"]
	var h: float = r["h"]
	var c := dun.centre(i)
	var room := Node3D.new()
	room.name = "Room%d" % (i + 1)
	room.position = c
	dun.add_child(room)
	while dun._room_nodes.size() <= i:
		dun._room_nodes.append(null)
	dun._room_nodes[i] = room
	match kind:
		"cave":
			PlaceBuild.cave(dun, room, i)
			return
		"twin_cave":
			TwinCave.build(dun, room, w, l, dun._rng)
			return
		"forest":
			DungeonBuild._build_forest(dun, room, i)
			return
		"sky":
			DungeonBuild._build_sky(dun, room, i)
			return
		"crypt":
			PlaceBuild.crypt(dun, room, i)
			return
		"flood_crypt":
			CryptTomb.build(dun, room, w, l, dun._rng)
			return
		"swamp":
			DungeonBuild._build_swamp(dun, room, i)
			return
		"mountain":
			DungeonBuild._build_mountain(dun, room, i)
			return
		"rampart":
			DungeonBuild._build_rampart(dun, room, i)
			return
		"spring", "holy_spring", "prison", "cell_cave":
			RestSpot.build(dun, room, i, kind)
			return
		"lord_court":
			ThroneCourt.build(dun, room, w, l, dun._rng)
			return
		"war_camp":
			ThroneCourt.build(dun, room, w, l, dun._rng, "a")
			return
		"lake", "fort", "falls", "clouds", "gold_hall":
			TerracePlaces.build(dun, room, kind, w, l, dun._rng)
			return
		"altar":
			PortalEvent.build(dun, room, i, kind)
			return
	var last := kind == "throne"
	var far := -l * 0.5 - Dungeon.WALL_T * 0.5
	var near := l * 0.5 + Dungeon.WALL_T * 0.5
	# The crag under it, down into the lands.
	DungeonBuild._crag_under(dun, room, w + Dungeon.WALL_T * 2.0, l + Dungeon.WALL_T * 2.0, PalaceVista.DROP + 40.0, -24.0)

	# The floor (with the strip under the next doorway), and the rock under it.
	DungeonBuild._solid(dun, room, dun._floor_mat(i), Vector3(w + Dungeon.WALL_T * 2.0, 1.0, l + Dungeon.WALL_T), Vector3(0.0, -0.5, -Dungeon.WALL_T * 0.5))
	# The palace's own footings, going down into the crag.
	DungeonBuild._solid(dun, room, dun._wall_mat, Vector3(w + Dungeon.WALL_T * 2.0, 24.0, l + Dungeon.WALL_T), Vector3(0.0, -13.0, -Dungeon.WALL_T * 0.5), false)

	# The long walls; the terrace has one side open over the drop.
	for side: float in [-1.0, 1.0]:
		var x := side * (w + Dungeon.WALL_T) * 0.5
		if kind == "terrace" and side > 0.0:
			DungeonBuild._balustrade(dun, room, Vector3(w * 0.5 - 0.3, 0.0, 0.0), l + Dungeon.WALL_T)
			continue
		if kind == "throne":
			DungeonBuild._parapet(dun, room, Vector3(x, 0.0, -Dungeon.WALL_T * 0.5), Vector3(Dungeon.WALL_T, h, l + Dungeon.WALL_T * 2.0))
			continue
		if kind == "court":
			DungeonBuild._window_wall(dun, room, x, l, h)
		else:
			DungeonBuild._solid(dun, room, dun._wall_mat, Vector3(Dungeon.WALL_T, h, l + Dungeon.WALL_T * 2.0), Vector3(x, h * 0.5, -Dungeon.WALL_T * 0.5))
	# The near wall, where he came in by.
	DungeonBuild._solid(dun, room, dun._wall_mat, Vector3(w + Dungeon.WALL_T * 2.0, h, Dungeon.WALL_T), Vector3(0.0, h * 0.5, near))
	# The far wall with its gate (shut: the way on is by the portals), or the
	# lord's court's open end over the drop.
	if not last:
		var wall_h := h
		var wall_w := w + Dungeon.WALL_T * 2.0
		var piece := (wall_w - Dungeon.DOOR_W) * 0.5
		for side: float in [-1.0, 1.0]:
			DungeonBuild._solid(dun, room, dun._wall_mat, Vector3(piece, wall_h, Dungeon.WALL_T),
					Vector3(side * (Dungeon.DOOR_W + piece) * 0.5, wall_h * 0.5, far))
		DungeonBuild._solid(dun, room, dun._wall_mat, Vector3(Dungeon.DOOR_W, wall_h - Dungeon.DOOR_H, Dungeon.WALL_T),
				Vector3(0.0, Dungeon.DOOR_H + (wall_h - Dungeon.DOOR_H) * 0.5, far))
		DungeonBuild._door_frame(dun, room, Vector3(0.0, 0.0, far))
		DungeonBuild._build_gate(dun, room, Vector3(0.0, 0.0, far))
	else:
		DungeonBuild._balustrade_across(dun, room, Vector3(0.0, 0.0, -l * 0.5 + 0.3), w)

	# A cornice along the tops of the walls.
	if kind == "hall" or kind == "court":
		for side: float in [-1.0, 1.0]:
			var x := side * (w * 0.5 + 0.2)
			DungeonBuild._trim(dun, room, Vector3(0.6, 0.45, l), Vector3(x, h - 0.6, 0.0))
	if kind == "court":
		DungeonBuild._merlons(dun, room, w, l, h)

	# Columns: two rows in a hall (and a tall vault on beams), along the walls elsewhere.
	if kind == "hall":
		DungeonBuild._battle_remains(dun, room, w, l)
		DungeonBuild._hall_columns(dun, room, i, w, l, h)
		DungeonBuild._ceiling(dun, room, w, l, h, r.has("hole"))
		DungeonBuild._high_windows(dun, room, w, l, h)
	elif kind == "court":
		DungeonBuild._wall_columns(dun, room, i, w, l, h)
		DungeonBuild._basin(dun, room)
		DungeonBuild._fallen_column(dun, room, Vector3(-w * 0.25, 0.0, l * 0.22), 0.6)
	elif kind == "terrace":
		DungeonBuild._blades_in_floor(dun, room, w, l, 8)
		DungeonBuild._wall_columns(dun, room, i, w, l, h, true)
		DungeonBuild._fallen_column(dun, room, Vector3(w * 0.18, 0.0, -l * 0.28), -0.4)
	else:
		DungeonBuild._ruins(dun, room, i, w, l)
		DungeonBuild._blades_in_floor(dun, room, w, l, 14)
		DungeonBuild._dais(dun, room, l)
		DungeonBuild._throne(dun, room, l)

	# the orcs' own over it all (the user's word, 2026-10-21: one should see
	# the orcs have taken it)
	OrcSpoils.dress(dun, room, kind, w, l, h, kind == "hall" and not r.has("hole"))
	DungeonBuild._wainscot(dun, room, kind, w, l)
	DungeonBuild._rubble_round(dun, room, i, w, l)
	DungeonBuild._motes(dun, room, w, l, h)
	# (the standing braziers down the hall's aisle gone: the user's word,
	# 2026-10-23)


## A fire low enough to walk into (the user's word, 2026-10-23: in places he
## went through the fire) gets a post round it no one goes through.
static func _block_fires(dun: Dungeon, room: Node3D) -> void:
	if room == null:
		return
	for n in room.find_children("*", "Node3D", true, false):
		if not n.is_in_group(&"dungeon_flame"):
			continue
		var f := n as Node3D
		var low := f.global_position.y - room.global_position.y
		if low > 2.2 or low < -0.5:
			continue
		var r := clampf(float(f.get_meta(&"size", 1.0)) * 0.3, 0.3, 0.9)
		var post := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = r
		cyl.height = 2.4
		shape.shape = cyl
		post.add_child(shape)
		room.add_child(post)
		post.global_position = Vector3(f.global_position.x, room.global_position.y + 1.2, f.global_position.z)


## An iron bowl of fire on three legs, waist high.
static func _standing_brazier(dun: Dungeon, room: Node3D, at: Vector3) -> void:
	var holder := Node3D.new()
	holder.position = at
	room.add_child(holder)
	for k in 3:
		var a := TAU * float(k) / 3.0
		var leg := MeshInstance3D.new()
		var lm := BoxMesh.new()
		lm.size = Vector3(0.07, 1.15, 0.07)
		leg.mesh = lm
		leg.material_override = dun._iron_mat
		leg.position = Vector3(sin(a) * 0.28, 0.55, cos(a) * 0.28)
		leg.rotation = Vector3(cos(a) * 0.22, 0.0, -sin(a) * 0.22)
		holder.add_child(leg)
	var bowl := MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = 0.55
	bm.bottom_radius = 0.22
	bm.height = 0.38
	bm.radial_segments = 12
	bowl.mesh = bm
	bowl.material_override = dun._iron_mat
	bowl.position = Vector3(0.0, 1.22, 0.0)
	holder.add_child(bowl)
	var coals := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.48
	cm.bottom_radius = 0.48
	cm.height = 0.04
	coals.mesh = cm
	if dun._coals_mat == null:
		var sh := Shader.new()
		sh.code = Dungeon.COALS_SHADER
		dun._coals_mat = ShaderMaterial.new()
		dun._coals_mat.shader = sh
	coals.material_override = dun._coals_mat
	coals.position = Vector3(0.0, 1.39, 0.0)
	holder.add_child(coals)
	holder.add_child(DungeonBuild._flame(dun, Vector3(0.0, 1.42, 0.0), 1.7, 22))
	dun._crackle(holder, Vector3(0.0, 1.4, 0.0))
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.62, 0.3)
	light.light_energy = 1.6
	light.omni_range = 10.0
	light.position = Vector3(0.0, 2.0, 0.0)
	holder.add_child(DungeonBuild._fire_light(dun, light))


static func _solid(dun: Dungeon, parent: Node3D, mat: Material, size: Vector3, at: Vector3, block: bool = true) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = at
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = mat
	body.add_child(mesh)
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	# Walls go on up, unseen, so nobody climbs out over them.
	var tall := block and size.y > 2.5 and at.y > 0.0
	bs.size = Vector3(size.x, size.y + (Dungeon.BLOCK_H if tall else 0.0), size.z)
	shape.shape = bs
	shape.position.y = (Dungeon.BLOCK_H * 0.5) if tall else 0.0
	body.add_child(shape)
	parent.add_child(body)
	return body


static func _deco(dun: Dungeon, parent: Node3D, mat: Material, mesh: Mesh, at: Vector3) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = mat
	m.position = at
	parent.add_child(m)
	return m


static func _trim(dun: Dungeon, parent: Node3D, size: Vector3, at: Vector3) -> void:
	var box := BoxMesh.new()
	box.size = size
	DungeonBuild._deco(dun, parent, dun._trim_mat, box, at)


## An invisible wall: only something to stop the heroes.
static func _blocker(dun: Dungeon, parent: Node3D, size: Vector3, at: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = at
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	shape.shape = bs
	body.add_child(shape)
	parent.add_child(body)
	return body


## A courtyard's long wall: piers and high arched windows onto the mountains.
static func _window_wall(dun: Dungeon, room: Node3D, x: float, l: float, h: float) -> void:
	var n := 4
	var bay := (l + Dungeon.WALL_T * 2.0) / float(n)
	var sill := 2.4
	var head := h - 2.2
	var win := bay * 0.48
	for k in n:
		var z0 := l * 0.5 + Dungeon.WALL_T - bay * float(k)
		var mid := z0 - bay * 0.5
		var pier := (bay - win) * 0.5
		for s: float in [-1.0, 1.0]:
			DungeonBuild._solid(dun, room, dun._wall_mat, Vector3(Dungeon.WALL_T, h, pier), Vector3(x, h * 0.5, mid - Dungeon.WALL_T * 0.5 + s * (win + pier) * 0.5))
		DungeonBuild._solid(dun, room, dun._wall_mat, Vector3(Dungeon.WALL_T, sill, win), Vector3(x, sill * 0.5, mid - Dungeon.WALL_T * 0.5))
		DungeonBuild._solid(dun, room, dun._wall_mat, Vector3(Dungeon.WALL_T, h - head, win), Vector3(x, head + (h - head) * 0.5, mid - Dungeon.WALL_T * 0.5))
		# A carved lintel and sill.
		var lintel := BoxMesh.new()
		lintel.size = Vector3(Dungeon.WALL_T + 0.3, 0.5, win + 0.8)
		DungeonBuild._deco(dun, room, dun._trim_mat, lintel, Vector3(x, head + 0.25, mid - Dungeon.WALL_T * 0.5))
		var sill_box := BoxMesh.new()
		sill_box.size = Vector3(Dungeon.WALL_T + 0.4, 0.3, win + 0.6)
		DungeonBuild._deco(dun, room, dun._trim_mat, sill_box, Vector3(x, sill + 0.15, mid - Dungeon.WALL_T * 0.5))
		DungeonBuild._blocker(dun, room, Vector3(Dungeon.WALL_T, head - sill, win), Vector3(x, sill + (head - sill) * 0.5, mid - Dungeon.WALL_T * 0.5))


## Battlements along the courtyard's tops.
static func _merlons(dun: Dungeon, room: Node3D, w: float, l: float, h: float) -> void:
	for side: float in [-1.0, 1.0]:
		var x := side * (w + Dungeon.WALL_T) * 0.5
		var k := 0.0
		while k < l:
			var box := BoxMesh.new()
			box.size = Vector3(Dungeon.WALL_T, 1.1, 1.3)
			DungeonBuild._deco(dun, room, dun._wall_mat, box, Vector3(x, h + 0.55, l * 0.5 - 1.0 - k))
			k += 2.6


## A balustrade along `length` at `at` (running along z), the drop beyond it.
static func _balustrade(dun: Dungeon, room: Node3D, at: Vector3, length: float) -> void:
	DungeonBuild._trim(dun, room, Vector3(0.5, 0.18, length), at + Vector3(0.0, 1.1, -Dungeon.WALL_T * 0.5))
	DungeonBuild._trim(dun, room, Vector3(0.6, 0.2, length), at + Vector3(0.0, 0.1, -Dungeon.WALL_T * 0.5))
	var k := 0.0
	var post := CylinderMesh.new()
	post.top_radius = 0.09
	post.bottom_radius = 0.14
	post.height = 0.85
	post.radial_segments = 8
	while k < length:
		DungeonBuild._deco(dun, room, dun._trim_mat, post, at + Vector3(0.0, 0.62, length * 0.5 - Dungeon.WALL_T * 0.5 - 0.3 - k))
		k += 0.45
	DungeonBuild._blocker(dun, room, Vector3(0.6, 12.0, length), at + Vector3(0.0, 6.0, -Dungeon.WALL_T * 0.5))
	# The palace's own wall going down into the cloud.
	var cliff := BoxMesh.new()
	cliff.size = Vector3(2.0, 90.0, length + 2.0)
	DungeonBuild._deco(dun, room, dun._wall_mat, cliff, at + Vector3(0.7, -45.2, -Dungeon.WALL_T * 0.5))


## The same across the far end of the boss's court.
static func _balustrade_across(dun: Dungeon, room: Node3D, at: Vector3, w: float) -> void:
	DungeonBuild._trim(dun, room, Vector3(w, 0.18, 0.5), at + Vector3(0.0, 1.1, 0.0))
	DungeonBuild._trim(dun, room, Vector3(w, 0.2, 0.6), at + Vector3(0.0, 0.1, 0.0))
	var post := CylinderMesh.new()
	post.top_radius = 0.09
	post.bottom_radius = 0.14
	post.height = 0.85
	post.radial_segments = 8
	var k := 0.0
	while k < w:
		DungeonBuild._deco(dun, room, dun._trim_mat, post, at + Vector3(-w * 0.5 + 0.3 + k, 0.62, 0.0))
		k += 0.45
	DungeonBuild._blocker(dun, room, Vector3(w, 12.0, 0.6), at + Vector3(0.0, 6.0, 0.0))
	var cliff := BoxMesh.new()
	cliff.size = Vector3(w + 6.0, 90.0, 2.0)
	DungeonBuild._deco(dun, room, dun._wall_mat, cliff, at + Vector3(0.0, -45.2, -0.7))


## The boss's court: a low parapet with crenels, the drop below it.
static func _parapet(dun: Dungeon, room: Node3D, at: Vector3, size: Vector3) -> void:
	var box := BoxMesh.new()
	box.size = Vector3(size.x, 1.3, size.z)
	DungeonBuild._deco(dun, room, dun._wall_mat, box, at + Vector3(0.0, 0.65, 0.0))
	var k := 0.0
	while k < size.z:
		var m := BoxMesh.new()
		m.size = Vector3(size.x, 0.9, 1.2)
		DungeonBuild._deco(dun, room, dun._wall_mat, m, at + Vector3(0.0, 1.75, size.z * 0.5 - 1.0 - k))
		k += 2.4
	DungeonBuild._blocker(dun, room, Vector3(size.x, 14.0, size.z), at + Vector3(0.0, 7.0, 0.0))
	var cliff := BoxMesh.new()
	cliff.size = Vector3(size.x + 1.0, 90.0, size.z)
	DungeonBuild._deco(dun, room, dun._wall_mat, cliff, at + Vector3(signf(at.x) * 0.5, -45.2, 0.0))


## A carved frame round a doorway, both faces.
static func _door_frame(dun: Dungeon, room: Node3D, at: Vector3) -> void:
	for face: float in [-1.0, 1.0]:
		var z := at.z + face * (Dungeon.WALL_T * 0.5 + 0.15)
		for side: float in [-1.0, 1.0]:
			DungeonBuild._trim(dun, room, Vector3(0.7, Dungeon.DOOR_H + 0.4, 0.3), Vector3(side * (Dungeon.DOOR_W * 0.5 + 0.35), Dungeon.DOOR_H * 0.5, z))
		DungeonBuild._trim(dun, room, Vector3(Dungeon.DOOR_W + 1.4, 0.8, 0.35), Vector3(0.0, Dungeon.DOOR_H + 0.4, z))
		# A shield-shaped boss of gold over the door.
		var boss := BoxMesh.new()
		boss.size = Vector3(1.0, 1.2, 0.2)
		var b := DungeonBuild._deco(dun, room, dun._gold_mat, boss, Vector3(0.0, Dungeon.DOOR_H + 1.4, z + face * 0.1))
		b.rotation.z = PI * 0.25


## Two rows of tall columns down a hall, banners between, torches on them.
static func _hall_columns(dun: Dungeon, room: Node3D, i: int, w: float, l: float, h: float) -> void:
	var n := maxi(3, int(l / 9.0))
	for k in n:
		var z := l * 0.5 - (float(k) + 0.5) * l / float(n)
		for side: float in [-1.0, 1.0]:
			var x := side * (w * 0.5 - 4.5)
			DungeonBuild._column(dun, room, i, Vector3(x, 0.0, z), h, 1.15)
			if k % 2 == 0:
				DungeonBuild._torch(dun, room, Vector3(x - side * 0.85, 3.6, z))
			# Banners on the walls between the columns.
			if k < n - 1:
				DungeonBuild._hang_banner(dun, room, Vector3(side * (w * 0.5 - 0.1), h - 2.2, z - l / float(n) * 0.5), side, minf(7.0, h * 0.45))


static func _wall_columns(dun: Dungeon, room: Node3D, i: int, w: float, l: float, h: float, one_side: bool = false) -> void:
	var n := maxi(3, int(l / 10.0))
	for k in n:
		var z := l * 0.5 - (float(k) + 0.5) * l / float(n)
		for side: float in [-1.0, 1.0]:
			if one_side and side > 0.0:
				continue
			var x := side * (w * 0.5 - 0.9)
			DungeonBuild._column(dun, room, i, Vector3(x, 0.0, z), h * 0.9, 0.9)
			if k % 2 == 1:
				DungeonBuild._torch(dun, room, Vector3(x - side * 0.7, 3.4, z))


static func _column(dun: Dungeon, room: Node3D, i: int, at: Vector3, h: float, thick: float) -> void:
	var base := BoxMesh.new()
	base.size = Vector3(thick * 2.0, 0.6, thick * 2.0)
	DungeonBuild._solid(dun, room, dun._trim_mat, base.size, at + Vector3(0.0, 0.3, 0.0))
	var shaft := CylinderMesh.new()
	shaft.top_radius = thick * 0.62
	shaft.bottom_radius = thick * 0.7
	shaft.height = h - 1.4
	shaft.radial_segments = 14
	var parts: Array[MeshInstance3D] = []
	parts.append(DungeonBuild._deco(dun, room, dun._wall_mat, shaft, at + Vector3(0.0, 0.6 + (h - 1.4) * 0.5, 0.0)))
	var blocker := DungeonBuild._blocker(dun, room, Vector3(thick * 1.3, h, thick * 1.3), at + Vector3(0.0, h * 0.5, 0.0))
	var cap := BoxMesh.new()
	cap.size = Vector3(thick * 1.9, 0.8, thick * 1.9)
	parts.append(DungeonBuild._deco(dun, room, dun._trim_mat, cap, at + Vector3(0.0, h - 0.4, 0.0)))
	# Gilded rings at the shaft's foot and neck.
	for y: float in [1.0, h - 1.0]:
		var band := CylinderMesh.new()
		band.top_radius = thick * 0.74
		band.bottom_radius = thick * 0.74
		band.height = 0.18
		band.radial_segments = 14
		parts.append(DungeonBuild._deco(dun, room, dun._gold_mat, band, at + Vector3(0.0, y, 0.0)))
	dun._columns.append({"room": i, "at": room.position + at, "local": at, "h": h, "thick": thick,
			"parts": parts, "blocker": blocker, "node": room, "broken": false})


static func _hang_banner(dun: Dungeon, room: Node3D, at: Vector3, side: float, long: float) -> void:
	var cloth := QuadMesh.new()
	cloth.size = Vector2(2.0, long)
	var cl := DungeonBuild._deco(dun, room, DungeonBuild._torn_cloth(dun), cloth, at + Vector3(-side * 0.1, -long * 0.5, 0.0))
	cl.rotation.y = PI * 0.5
	for z: float in [-0.75, 0.75]:
		var stripe := BoxMesh.new()
		stripe.size = Vector3(0.09, long, 0.14)
		DungeonBuild._deco(dun, room, dun._gold_mat, stripe, at + Vector3(-side * 0.11, -long * 0.5, z))
	var rod := CylinderMesh.new()
	rod.top_radius = 0.06
	rod.bottom_radius = 0.06
	rod.height = 2.4
	var r := DungeonBuild._deco(dun, room, dun._gold_mat, rod, at + Vector3(-side * 0.15, 0.05, 0.0))
	r.rotation.x = PI * 0.5
	# A golden lozenge on it.
	var mark := BoxMesh.new()
	mark.size = Vector3(0.1, 0.7, 0.7)
	var m := DungeonBuild._deco(dun, room, dun._gold_mat, mark, at + Vector3(-side * 0.13, -long * 0.35, 0.0))
	m.rotation.x = PI * 0.25


## A hall's roof: a flat ceiling on deep beams, iron braziers hanging from it.
## Where `hole` is set, the roof has fallen in over the middle: the sky
## through it, sunlight down it, its beams broken and the rubble under it.
static func _ceiling(dun: Dungeon, room: Node3D, w: float, l: float, h: float, hole: bool = false) -> void:
	var hz := 0.0
	var hl := 0.0
	var hw := 0.0
	if hole:
		hz = -l * 0.08
		hl = 16.0
		hw = 14.0
	var full_l := l + Dungeon.WALL_T * 2.0
	if not hole:
		var slab := BoxMesh.new()
		slab.size = Vector3(w + Dungeon.WALL_T * 2.0, 1.0, full_l)
		DungeonBuild._deco(dun, room, dun._wood_mat, slab, Vector3(0.0, h + 0.5, -Dungeon.WALL_T * 0.5))
	else:
		# Four slabs round the hole.
		var near_l := (l * 0.5 + Dungeon.WALL_T) - (hz + hl * 0.5)
		var far_l := (hz - hl * 0.5) - (-l * 0.5 - Dungeon.WALL_T * 2.0)
		var a := BoxMesh.new()
		a.size = Vector3(w + Dungeon.WALL_T * 2.0, 1.0, near_l)
		DungeonBuild._deco(dun, room, dun._wood_mat, a, Vector3(0.0, h + 0.5, hz + hl * 0.5 + near_l * 0.5))
		var b := BoxMesh.new()
		b.size = Vector3(w + Dungeon.WALL_T * 2.0, 1.0, far_l)
		DungeonBuild._deco(dun, room, dun._wood_mat, b, Vector3(0.0, h + 0.5, hz - hl * 0.5 - far_l * 0.5))
		for side: float in [-1.0, 1.0]:
			var sw := (w + Dungeon.WALL_T * 2.0 - hw) * 0.5
			var c := BoxMesh.new()
			c.size = Vector3(sw, 1.0, hl)
			DungeonBuild._deco(dun, room, dun._wood_mat, c, Vector3(side * (hw * 0.5 + sw * 0.5), h + 0.5, hz))
		# Moonlight down through it, and what fell.
		var beam := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = hw * 0.45
		cyl.bottom_radius = hw * 0.6
		cyl.height = h + 2.0
		cyl.radial_segments = 16
		cyl.cap_top = false
		cyl.cap_bottom = false
		beam.mesh = cyl
		var bm := ShaderMaterial.new()
		bm.shader = dun._beam_shader
		bm.set_shader_parameter("tint", Color(1.0, 0.88, 0.66))
		bm.set_shader_parameter("strength", 0.03)
		beam.material_override = bm
		beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		beam.position = Vector3(0.0, h * 0.5, hz)
		room.add_child(beam)
		var shaft := SpotLight3D.new()
		shaft.light_color = Color(1.0, 0.88, 0.7)
		shaft.light_energy = 4.0
		shaft.spot_range = h + 8.0
		shaft.spot_angle = 28.0
		shaft.shadow_enabled = true
		shaft.position = Vector3(0.0, h + 4.0, hz)
		shaft.rotation.x = -PI * 0.5
		room.add_child(shaft)
		DungeonBuild._rubble(dun, room, Vector3(2.0, 0.0, hz + 1.5), 3.2, 24, 99)
		DungeonBuild._rubble(dun, room, Vector3(-5.0, 0.0, hz - 3.0), 2.0, 12, 7)
		# A beam come down, lying on the rubble (the user's word, 2026-10-21:
		# it stood on its end in the air).
		var fallen := BoxMesh.new()
		fallen.size = Vector3(0.9, 0.8, 13.0)
		var fb := DungeonBuild._deco(dun, room, dun._wood_mat, fallen, Vector3(-2.5, 0.75, hz + 1.0))
		fb.rotation = Vector3(0.09, 0.55, 0.04)
		var lie := DungeonBuild._blocker(dun, room, Vector3(0.9, 1.2, 13.0), Vector3(-2.5, 0.6, hz + 1.0))
		lie.rotation.y = 0.55
		# ivy hanging down over the broken edge (no grass on the floor: the
		# user's word, 2026-10-23, too much of it)
		for k in 8:
			var side := -1.0 if k % 2 == 0 else 1.0
			var at := Vector3(side * hw * 0.5, h - 0.3, hz + dun._rng.randf_range(-hl * 0.4, hl * 0.4))
			DungeonBuild._necro_put(dun, room, "EA_Nature_Ivy_01a" if k % 3 != 0 else "EA_Nature_Ivy_01c", at, PI * 0.5 * side, 2.4, false)
	var n := int(l / 5.0)
	for k in n + 1:
		var z := l * 0.5 - float(k) * l / float(n)
		if hole and absf(z - hz) < hl * 0.5:
			# Its broken ends sticking out over the hole.
			for side: float in [-1.0, 1.0]:
				var stub := BoxMesh.new()
				stub.size = Vector3((w - hw) * 0.5 + 1.5, 0.9, 0.7)
				var st := DungeonBuild._deco(dun, room, dun._wood_mat, stub, Vector3(side * (hw * 0.5 + (w - hw) * 0.25 - 0.75), h - 0.45, z))
				st.rotation.z = side * 0.06
			continue
		var beam_box := BoxMesh.new()
		beam_box.size = Vector3(w, 0.9, 0.7)
		DungeonBuild._deco(dun, room, dun._wood_mat, beam_box, Vector3(0.0, h - 0.45, z))
	for side: float in [-1.0, 1.0]:
		var long := BoxMesh.new()
		long.size = Vector3(0.8, 1.1, l)
		DungeonBuild._deco(dun, room, dun._wood_mat, long, Vector3(side * (w * 0.5 - 4.5), h - 1.0, 0.0))
	for k in 3:
		var z := l * 0.5 - (float(k) + 0.5) * l / 3.0
		if hole and absf(z - hz) < hl * 0.5 + 2.0:
			continue
		DungeonBuild._hanging_brazier(dun, room, Vector3(0.0, h, z), h)


static func _hanging_brazier(dun: Dungeon, room: Node3D, top: Vector3, h: float) -> void:
	var drop := minf(h - 6.0, 9.0)
	dun._creaks.append(room.position + top + Vector3(0.0, -drop * 0.5, 0.0))
	var chain := CylinderMesh.new()
	chain.top_radius = 0.04
	chain.bottom_radius = 0.04
	chain.height = drop
	DungeonBuild._deco(dun, room, dun._iron_mat, chain, top + Vector3(0.0, -drop * 0.5, 0.0))
	var bowl := CylinderMesh.new()
	bowl.top_radius = 0.9
	bowl.bottom_radius = 0.35
	bowl.height = 0.5
	bowl.radial_segments = 10
	var at := top + Vector3(0.0, -drop - 0.25, 0.0)
	DungeonBuild._deco(dun, room, dun._iron_mat, bowl, at)
	room.add_child(DungeonBuild._flame(dun, at + Vector3(0.0, 0.2, 0.0), 2.2, 40))
	dun._crackle(room, at)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.66, 0.36)
	light.light_energy = 3.4
	light.omni_range = 22.0
	light.position = at + Vector3(0.0, 0.6, 0.0)
	room.add_child(DungeonBuild._fire_light(dun, light))


## The courtyard's dry basin in the middle.
static func _basin(dun: Dungeon, room: Node3D) -> void:
	for side: float in [-1.0, 1.0]:
		DungeonBuild._solid(dun, room, dun._trim_mat, Vector3(7.0, 0.8, 0.5), Vector3(0.0, 0.4, side * 3.25))
		DungeonBuild._solid(dun, room, dun._trim_mat, Vector3(0.5, 0.8, 7.0), Vector3(side * 3.25, 0.4, 0.0))
	var water := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(6.0, 6.0)
	water.mesh = plane
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color(0.08, 0.06, 0.14)
	wm.metallic = 0.3
	wm.roughness = 0.05
	water.material_override = wm
	water.position = Vector3(0.0, 0.55, 0.0)
	room.add_child(water)
	var plinth := BoxMesh.new()
	plinth.size = Vector3(1.2, 2.2, 1.2)
	DungeonBuild._solid(dun, room, dun._trim_mat, plinth.size, Vector3(0.0, 1.1, 0.0))
	var urn := CylinderMesh.new()
	urn.top_radius = 0.7
	urn.bottom_radius = 0.3
	urn.height = 0.8
	DungeonBuild._deco(dun, room, dun._gold_mat, urn, Vector3(0.0, 2.6, 0.0))


## Broken columns round the boss's court.
static func _ruins(dun: Dungeon, room: Node3D, i: int, w: float, l: float) -> void:
	var heights: Array[float] = [7.0, 3.2, 9.0, 1.8, 5.5, 8.0, 2.4, 6.5]
	for k in 8:
		var side := -1.0 if k % 2 == 0 else 1.0
		var z := l * 0.5 - 8.0 - floorf(float(k) / 2.0) * (l - 24.0) / 3.0
		DungeonBuild._column(dun, room, i, Vector3(side * (w * 0.5 - 3.0), 0.0, z), heights[k], 1.2)
		if k % 3 == 0:
			DungeonBuild._torch(dun, room, Vector3(side * (w * 0.5 - 4.2), 1.2, z))


## A raised dais at the far end, where the way out will stand.
static func _dais(dun: Dungeon, room: Node3D, l: float) -> void:
	for k in 3:
		DungeonBuild._solid(dun, room, dun._trim_mat, Vector3(20.0 - float(k) * 3.5, 0.3, 11.0 - float(k) * 2.5),
				Vector3(0.0, 0.15 + float(k) * 0.3, -l * 0.5 + 6.0 - float(k) * 0.6))


## What is seen from the open rooms: the v5 lands far below and round the
## palace, their mountains on the horizon ([PalaceVista]), and the crag the
## palace stands on going down to them.
static func _vista(dun: Dungeon) -> void:
	var lands := PalaceVista.new()
	lands.name = "Vista"
	# The palace over the middle of the lands' basin.
	var mid := -Dungeon.STEP_GAP * float(dun.steps.size() - 1) * 0.5
	lands.position = Vector3(-560.0, 0.0, mid + 120.0)
	dun.add_child(lands)


## A dark panelled band along the foot of the walls.
static func _wainscot(dun: Dungeon, room: Node3D, kind: String, w: float, l: float) -> void:
	if kind == "throne":
		return
	for side: float in [-1.0, 1.0]:
		if kind == "terrace" and side > 0.0:
			continue
		var box := BoxMesh.new()
		box.size = Vector3(0.25, 1.5, l)
		DungeonBuild._deco(dun, room, dun._wood_mat if kind == "hall" else dun._trim_mat, box, Vector3(side * (w * 0.5 - 0.12), 0.75, 0.0))
		var rail := BoxMesh.new()
		rail.size = Vector3(0.32, 0.12, l)
		DungeonBuild._deco(dun, room, dun._gold_mat if kind == "hall" else dun._trim_mat, rail, Vector3(side * (w * 0.5 - 0.14), 1.52, 0.0))


## Tall stained-glass windows high in a hall's long walls, light slanting in.
static func _high_windows(dun: Dungeon, room: Node3D, w: float, l: float, h: float) -> void:
	var n := maxi(3, int(l / 14.0))
	var tall := minf(h * 0.38, 9.0)
	var wide := 2.6
	for k in n:
		var z := l * 0.5 - (float(k) + 0.5) * l / float(n)
		for side: float in [-1.0, 1.0]:
			var x := side * (w * 0.5 - 0.02)
			var glass := MeshInstance3D.new()
			var q := QuadMesh.new()
			q.size = Vector2(wide, tall)
			glass.mesh = q
			var gm := ShaderMaterial.new()
			gm.shader = dun._glass_shader
			glass.material_override = gm
			glass.position = Vector3(x, h - 2.5 - tall * 0.5, z)
			glass.rotation.y = -side * PI * 0.5
			glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			room.add_child(glass)
			# A carved frame.
			for e: float in [-1.0, 1.0]:
				var jamb := BoxMesh.new()
				jamb.size = Vector3(0.35, tall + 0.4, 0.3)
				DungeonBuild._deco(dun, room, dun._trim_mat, jamb, Vector3(x - side * 0.15, glass.position.y, z + e * (wide * 0.5 + 0.15)))
			var sill := BoxMesh.new()
			sill.size = Vector3(0.5, 0.3, wide + 0.9)
			DungeonBuild._deco(dun, room, dun._trim_mat, sill, Vector3(x - side * 0.2, glass.position.y - tall * 0.5 - 0.15, z))
			# Light slanting down from it across the hall, on one side only.
			if side < 0.0 and k % 2 == 0:
				var beam := MeshInstance3D.new()
				var cyl := CylinderMesh.new()
				cyl.top_radius = wide * 0.35
				cyl.bottom_radius = wide * 0.6
				var length := (h - 2.5) * 1.6
				cyl.height = length
				cyl.radial_segments = 12
				cyl.cap_top = false
				cyl.cap_bottom = false
				beam.mesh = cyl
				var bm := ShaderMaterial.new()
				bm.shader = dun._beam_shader
				bm.set_shader_parameter("tint", Color(1.0, 0.8, 0.6))
				bm.set_shader_parameter("strength", 0.045)
				beam.material_override = bm
				beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				var top := Vector3(x, h - 2.5 - tall * 0.5, z)
				var foot := Vector3(x * 0.15, 0.0, z - 3.0)
				beam.position = (top + foot) * 0.5
				var dir := (top - foot).normalized()
				beam.basis = Basis(Quaternion(Vector3.UP, dir))
				room.add_child(beam)


## Dust hanging in the air of a room, lit where the light is.
static func _motes(dun: Dungeon, room: Node3D, w: float, l: float, h: float) -> void:
	var dust := GPUParticles3D.new()
	dust.amount = 160
	dust.lifetime = 14.0
	dust.preprocess = 14.0
	dust.position = Vector3(0.0, minf(h, 12.0) * 0.5, 0.0)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(w * 0.45, minf(h, 12.0) * 0.45, l * 0.45)
	pm.gravity = Vector3(0.0, -0.02, 0.0)
	pm.initial_velocity_min = 0.02
	pm.initial_velocity_max = 0.12
	pm.spread = 180.0
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.4
	pm.scale_min = 0.6
	pm.scale_max = 1.4
	var fade := Gradient.new()
	fade.set_color(0, Color(1.0, 0.9, 0.8, 0.0))
	fade.add_point(0.5, Color(1.0, 0.9, 0.8, 0.35))
	fade.set_color(fade.get_point_count() - 1, Color(1.0, 0.9, 0.8, 0.0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	pm.color_ramp = ramp
	dust.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.035, 0.035)
	var qm := StandardMaterial3D.new()
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	qm.vertex_color_use_as_albedo = true
	q.material = qm
	dust.draw_pass_1 = q
	dust.visibility_aabb = AABB(Vector3(-w, -h, -l) * 0.6, Vector3(w, h, l) * 1.2)
	room.add_child(dust)


## The orc lord's seat on the dais, braziers either side of it.
static func _throne(dun: Dungeon, room: Node3D, l: float) -> void:
	var z := -l * 0.5 + 3.4
	var y := 0.9
	DungeonBuild._solid(dun, room, dun._wall_mat, Vector3(3.2, 1.0, 2.6), Vector3(0.0, y + 0.5, z))
	DungeonBuild._solid(dun, room, dun._wall_mat, Vector3(3.2, 5.5, 0.7), Vector3(0.0, y + 2.75, z - 1.0))
	for side: float in [-1.0, 1.0]:
		DungeonBuild._solid(dun, room, dun._wall_mat, Vector3(0.5, 1.6, 2.6), Vector3(side * 1.6, y + 1.3, z))
		var horn := CylinderMesh.new()
		horn.top_radius = 0.0
		horn.bottom_radius = 0.25
		horn.height = 1.8
		horn.radial_segments = 6
		var hn := DungeonBuild._deco(dun, room, dun._iron_mat, horn, Vector3(side * 1.4, y + 6.1, z - 1.0))
		hn.rotation.z = -side * 0.35
	var seat := BoxMesh.new()
	seat.size = Vector3(2.4, 0.15, 2.0)
	DungeonBuild._deco(dun, room, dun._cloth_mat, seat, Vector3(0.0, y + 1.08, z + 0.1))
	var skull := SphereMesh.new()
	skull.radius = 0.45
	skull.height = 0.8
	DungeonBuild._deco(dun, room, dun._trim_mat, skull, Vector3(0.0, y + 5.0, z - 0.6))
	for side: float in [-1.0, 1.0]:
		var bowl := CylinderMesh.new()
		bowl.top_radius = 0.9
		bowl.bottom_radius = 0.4
		bowl.height = 0.6
		var at := Vector3(side * 6.0, y + 1.6, z + 1.0)
		DungeonBuild._solid(dun, room, dun._iron_mat, Vector3(0.4, 1.6, 0.4), at + Vector3(0.0, -0.9, 0.0))
		DungeonBuild._deco(dun, room, dun._iron_mat, bowl, at)
		room.add_child(DungeonBuild._flame(dun, at + Vector3(0.0, 0.25, 0.0), 3.0, 50))
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.6, 0.3)
		light.light_energy = 3.6
		light.omni_range = 20.0
		light.position = at + Vector3(0.0, 1.0, 0.0)
		room.add_child(DungeonBuild._fire_light(dun, light))


## An iron portcullis filling the doorway at `at`, down.
static func _build_gate(dun: Dungeon, room: Node3D, at: Vector3) -> Node3D:
	var gate := StaticBody3D.new()
	gate.name = "Gate"
	gate.position = at
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(Dungeon.DOOR_W, Dungeon.DOOR_H, 0.4)
	shape.shape = bs
	shape.position.y = Dungeon.DOOR_H * 0.5
	gate.add_child(shape)
	var bars := 13
	for b in bars:
		var bar := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.06
		cyl.bottom_radius = 0.06
		cyl.height = Dungeon.DOOR_H
		cyl.radial_segments = 6
		bar.mesh = cyl
		bar.material_override = dun._iron_mat
		bar.position = Vector3(-Dungeon.DOOR_W * 0.5 + (float(b) + 0.5) * Dungeon.DOOR_W / float(bars), Dungeon.DOOR_H * 0.5, 0.0)
		gate.add_child(bar)
		var tip := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 0.09
		cone.height = 0.3
		tip.mesh = cone
		tip.material_override = dun._iron_mat
		tip.rotation.x = PI
		tip.position = Vector3(bar.position.x, -0.1, 0.0)
		gate.add_child(tip)
	for hh: float in [1.2, 3.0, 4.8, 6.6]:
		var rail := MeshInstance3D.new()
		var rb := BoxMesh.new()
		rb.size = Vector3(Dungeon.DOOR_W, 0.12, 0.16)
		rail.mesh = rb
		rail.material_override = dun._iron_mat
		rail.position = Vector3(0.0, hh, 0.0)
		gate.add_child(rail)
	room.add_child(gate)
	return gate


## A fire (the user's word, 2026-10-20: the palace's fires prettier): a flame
## drawn whole by a shader, its tongues licking up and tearing off, white-gold
## at its root and dark red at its tips, sparks going up from it. Its light
## flickers ([method _fire_light]).
static func _flame(dun: Dungeon, at: Vector3, size: float, amount: int) -> Node3D:
	var fire := Node3D.new()
	fire.position = at
	fire.add_to_group(&"dungeon_flame")
	fire.set_meta(&"size", size)
	if dun._fire_mat == null:
		var sh := Shader.new()
		sh.code = Dungeon.FLAME_SHADER
		dun._fire_mat = ShaderMaterial.new()
		dun._fire_mat.shader = sh
	var small := size < 1.0
	var dims := Vector2(0.55, 0.85) * size if not small else Vector2(0.3, 0.5) * size
	var key := snappedf(size, 0.05)
	var quad: QuadMesh = dun._fire_quads.get(key) as QuadMesh
	if quad == null:
		quad = QuadMesh.new()
		quad.size = dims
		quad.center_offset = Vector3(0.0, dims.y * 0.42, 0.0)
		quad.material = dun._fire_mat
		dun._fire_quads[key] = quad
	var body := MeshInstance3D.new()
	body.mesh = quad
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.custom_aabb = AABB(Vector3(-dims.x * 0.5, -0.1, -dims.x * 0.5), Vector3(dims.x, dims.y + 0.2, dims.x))
	fire.add_child(body)
	if small:
		return fire
	fire.add_child(DungeonBuild._embers(dun, size, maxi(4, amount / 4)))
	return fire


## Sparks going up from a fire, swirling, dying out.
static func _embers(dun: Dungeon, size: float, amount: int) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = 1.8
	p.local_coords = true
	p.randomness = 0.6
	if dun._ember_draw == null:
		dun._ember_draw = QuadMesh.new()
		dun._ember_draw.size = Vector2(0.035, 0.035)
		var qm := StandardMaterial3D.new()
		qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		qm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		qm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		qm.vertex_color_use_as_albedo = true
		qm.albedo_color = Color(4.0, 2.6, 1.4)
		dun._ember_draw.material = qm
	var key := snappedf(size, 0.05)
	var pm: ParticleProcessMaterial = dun._ember_pms.get(key) as ParticleProcessMaterial
	if pm == null:
		pm = ParticleProcessMaterial.new()
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		pm.emission_sphere_radius = 0.1 * size
		pm.direction = Vector3.UP
		pm.spread = 22.0
		pm.initial_velocity_min = 0.6 * size
		pm.initial_velocity_max = 1.3 * size
		pm.gravity = Vector3(0.0, 0.25, 0.0)
		pm.damping_min = 0.2
		pm.damping_max = 0.6
		pm.turbulence_enabled = true
		pm.turbulence_noise_strength = 1.4
		pm.turbulence_noise_scale = 1.6
		pm.turbulence_influence_min = 0.05
		pm.turbulence_influence_max = 0.15
		pm.scale_min = 0.5
		pm.scale_max = 1.4
		var fade := Gradient.new()
		fade.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
		fade.colors = PackedColorArray([Color(1.0, 0.85, 0.5, 1.0), Color(1.0, 0.45, 0.1, 0.9), Color(0.6, 0.1, 0.0, 0.0)])
		var ramp := GradientTexture1D.new()
		ramp.gradient = fade
		pm.color_ramp = ramp
		dun._ember_pms[key] = pm
	p.process_material = pm
	p.draw_pass_1 = dun._ember_draw
	p.visibility_aabb = AABB(Vector3(-2, -0.5, -2) * size, Vector3(4, 5, 4) * size)
	return p


## A fire's light, flickering with it ([method _flicker_fires]).
static func _fire_light(dun: Dungeon, light: OmniLight3D) -> OmniLight3D:
	dun._fire_lights.append({"light": light, "base": light.light_energy, "at": dun._rng.randf_range(0.0, 100.0)})
	return light


static func _torch(dun: Dungeon, room: Node3D, at: Vector3) -> void:
	var holder := Node3D.new()
	holder.position = at
	room.add_child(holder)
	var cup := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.2
	cm.bottom_radius = 0.07
	cm.height = 0.36
	cup.mesh = cm
	cup.material_override = dun._iron_mat
	holder.add_child(cup)
	holder.add_child(DungeonBuild._flame(dun, Vector3(0.0, 0.22, 0.0), 1.2, 18))
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.64, 0.32)
	light.light_energy = 2.6
	light.omni_range = 14.0
	light.position = Vector3(0.0, 0.4, 0.0)
	holder.add_child(DungeonBuild._fire_light(dun, light))


#region Places beyond the palace
## A model of the forest kit (assets/forest), loaded once.
static func _kit(dun: Dungeon, name: String) -> Mesh:
	if dun._models.has(name):
		return dun._models[name]
	var path := "res://assets/forest/%s.obj" % name
	var mesh: Mesh = load(path) as Mesh if ResourceLoader.exists(path) else null
	dun._models[name] = mesh
	return mesh


## A kit model in `room` at `at`, `tall` metres high, turned `yaw`.
static func _prop(dun: Dungeon, room: Node3D, name: String, at: Vector3, tall: float, yaw: float, shadow: bool = true) -> MeshInstance3D:
	var mesh := DungeonBuild._kit(dun, name)
	if mesh == null:
		return null
	var m := MeshInstance3D.new()
	m.mesh = mesh
	var box := mesh.get_aabb()
	var s := tall / maxf(box.size.y, 0.01)
	m.scale = Vector3.ONE * s
	m.position = at - Vector3(0.0, box.position.y * s, 0.0)
	m.rotation.y = yaw
	if not shadow:
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	room.add_child(m)
	return m


## A trunk nobody walks through.
static func _post(dun: Dungeon, room: Node3D, at: Vector3, radius: float, tall: float) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = radius
	cyl.height = tall
	shape.shape = cyl
	body.add_child(shape)
	body.position = at + Vector3(0.0, tall * 0.5, 0.0)
	room.add_child(body)


## Unseen walls round a place without walls of its own.
static func _bounds(dun: Dungeon, room: Node3D, w: float, l: float) -> void:
	DungeonBuild._blocker(dun, room, Vector3(1.0, Dungeon.BLOCK_H, l + 2.0), Vector3(-w * 0.5 - 0.5, Dungeon.BLOCK_H * 0.5, 0.0))
	DungeonBuild._blocker(dun, room, Vector3(1.0, Dungeon.BLOCK_H, l + 2.0), Vector3(w * 0.5 + 0.5, Dungeon.BLOCK_H * 0.5, 0.0))
	DungeonBuild._blocker(dun, room, Vector3(w + 2.0, Dungeon.BLOCK_H, 1.0), Vector3(0.0, Dungeon.BLOCK_H * 0.5, -l * 0.5 - 0.5))
	DungeonBuild._blocker(dun, room, Vector3(w + 2.0, Dungeon.BLOCK_H, 1.0), Vector3(0.0, Dungeon.BLOCK_H * 0.5, l * 0.5 + 0.5))


## Great rocks under a place's footprint, down into the lands far below.
static func _crag_under(dun: Dungeon, room: Node3D, w: float, l: float, depth: float, top: float = -1.0) -> void:
	var z := l * 0.5
	var k := 0
	while z > -l * 0.5 - 10.0:
		var crag := MeshInstance3D.new()
		crag.mesh = RockWave._crag_mesh(k % RockWave.SHAPES)
		var box := crag.mesh.get_aabb()
		var want := Vector3(w * dun._rng.randf_range(1.0, 1.4), depth, dun._rng.randf_range(40.0, 70.0))
		crag.scale = Vector3(want.x / maxf(box.size.x, 0.01), want.y / maxf(box.size.y, 0.01), want.z / maxf(box.size.z, 0.01))
		crag.position = Vector3(dun._rng.randf_range(-5.0, 5.0), 0.0, z - 15.0)
		crag.position.y = top - (box.position.y + box.size.y) * crag.scale.y
		crag.rotation.y = dun._rng.randf_range(-0.3, 0.3)
		crag.material_override = dun._rock_mat
		crag.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		room.add_child(crag)
		z -= 40.0
		k += 1


## A rock of `size` (x, y, z metres) at `at`, turned `yaw`, in `mat`.
static func _boulder(dun: Dungeon, room: Node3D, at: Vector3, size: Vector3, yaw: float, mat: Material, shadow: bool = true,
		solid: bool = true) -> MeshInstance3D:
	var crag := MeshInstance3D.new()
	crag.mesh = RockWave._crag_mesh(dun._rng.randi_range(0, RockWave.SHAPES - 1))
	var box := crag.mesh.get_aabb()
	crag.scale = Vector3(size.x / maxf(box.size.x, 0.01), size.y / maxf(box.size.y, 0.01), size.z / maxf(box.size.z, 0.01))
	crag.position = at - Vector3(0.0, box.position.y * crag.scale.y, 0.0)
	crag.rotation.y = yaw
	crag.material_override = mat
	if not shadow:
		crag.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	room.add_child(crag)
	if solid:
		DungeonBuild._rock_body(dun, crag)
	return crag


## A rock one cannot walk into (the user's word, 2026-10-22: the heroes went
## through the rocks): its hull, made at its own size — the body under the
## stretched rock undoes the stretch, and the hull's points take it instead,
## so it is never scaled unevenly. It goes on turning with the rock (a rock
## hung upside down, tipped).
static func _rock_body(dun: Dungeon, crag: MeshInstance3D) -> void:
	var hull: ConvexPolygonShape3D = dun._hulls.get(crag.mesh) as ConvexPolygonShape3D
	if hull == null:
		hull = crag.mesh.create_convex_shape(true, true) as ConvexPolygonShape3D
		dun._hulls[crag.mesh] = hull
	if hull == null:
		return
	var pts := PackedVector3Array()
	for p in hull.points:
		pts.append(p * crag.scale)
	var shape := ConvexPolygonShape3D.new()
	shape.points = pts
	var body := StaticBody3D.new()
	body.name = "Solid"
	body.scale = Vector3(1.0 / crag.scale.x, 1.0 / crag.scale.y, 1.0 / crag.scale.z)
	var col := CollisionShape3D.new()
	col.shape = shape
	body.add_child(col)
	crag.add_child(body)


## A rock turned upside down under something, its top at `top` (its own
## frame's height), hanging down from there.
static func _hang(dun: Dungeon, rock: MeshInstance3D, top: float) -> void:
	rock.rotation.x = PI
	var box := rock.mesh.get_aabb()
	rock.position.y = top + box.position.y * rock.scale.y


## The forest (the user's pick of the concept pictures, 2026-10-23: an old
## oak wood round a mossy glade; [ForestGlade] builds it): giant oaks round a
## wide glade of moss and mud, ruined gates, beams of sun, a light mist low on
## the ground, leaves coming down. Nothing in the glade to go behind.
static func _build_forest(dun: Dungeon, room: Node3D, i: int) -> void:
	var r := dun._room(i)
	var w: float = r["w"]
	var l: float = r["l"]
	ForestGlade.build(dun, room, w, l, dun._rng)
	DungeonBuild._crag_under(dun, room, w + 110.0, l + 110.0, PalaceVista.DROP + 60.0, -1.0)
	# (no sheets of mist: the volumetric fog is the air here, 2026-10-23)
	DungeonBuild._falling_leaves(dun, room, w, l)
	DungeonBuild._circling_birds(dun, room)


## A spot at the edge of the forest's clearing, along bearing `a`: in the
## outer band, next to the trees, the middle left clear.
static func _forest_edge(dun: Dungeon, w: float, l: float, a: float) -> Vector3:
	var reach := dun._rng.randf_range(0.78, 0.96)
	var dir := Vector2(sin(a), cos(a))
	var to_side := minf(w * 0.5 / maxf(absf(dir.x), 0.001), l * 0.5 / maxf(absf(dir.y), 0.001))
	return Vector3(dir.x * to_side * reach, 0.0, dir.y * to_side * reach)


## The dead wood's trees: bare ones, and the twisted ones with their leaves
## stripped.
static func _a_dead_tree(dun: Dungeon) -> String:
	if dun._rng.randf() < 0.7:
		return "DeadTree_%d" % dun._rng.randi_range(1, 5)
	return "TwistedTree_%d" % dun._rng.randi_range(1, 5)


## A sharpened stake driven into the earth, leaning, a skull on it if `skull`.
static func _stake(dun: Dungeon, room: Node3D, at: Vector3, skull: bool) -> void:
	var holder := Node3D.new()
	holder.position = at
	holder.rotation = Vector3(dun._rng.randf_range(-0.25, 0.25), dun._rng.randf_range(0.0, TAU), dun._rng.randf_range(-0.25, 0.25))
	room.add_child(holder)
	var tall := dun._rng.randf_range(1.8, 2.6)
	var pole := CylinderMesh.new()
	pole.top_radius = 0.09
	pole.bottom_radius = 0.12
	pole.height = tall
	pole.radial_segments = 6
	var pm := MeshInstance3D.new()
	pm.mesh = pole
	pm.material_override = dun._wood_mat
	pm.position = Vector3(0.0, tall * 0.5, 0.0)
	holder.add_child(pm)
	var tip := CylinderMesh.new()
	tip.top_radius = 0.0
	tip.bottom_radius = 0.09
	tip.height = 0.35
	tip.radial_segments = 6
	var tm := MeshInstance3D.new()
	tm.mesh = tip
	tm.material_override = dun._wood_mat
	tm.position = Vector3(0.0, tall + 0.17, 0.0)
	holder.add_child(tm)
	if skull:
		OrcSpoils._skull(dun, holder, Vector3(0.0, tall - 0.02, 0.0), 1.15)
	DungeonBuild._blocker(dun, room, Vector3(0.3, tall, 0.3), at + Vector3(0.0, tall * 0.5, 0.0))


## Dead leaves coming down through the bare wood, slowly, turning.
static func _falling_leaves(dun: Dungeon, room: Node3D, w: float, l: float) -> void:
	var p := GPUParticles3D.new()
	p.amount = 70
	p.lifetime = 9.0
	p.preprocess = 9.0
	p.position = Vector3(0.0, 9.0, 0.0)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(w * 0.5, 1.0, l * 0.5)
	pm.gravity = Vector3(0.3, -0.9, 0.1)
	pm.initial_velocity_min = 0.0
	pm.initial_velocity_max = 0.3
	pm.damping_min = 0.5
	pm.damping_max = 1.0
	pm.angle_min = -180.0
	pm.angle_max = 180.0
	pm.angular_velocity_min = -120.0
	pm.angular_velocity_max = 120.0
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 1.2
	pm.scale_min = 0.7
	pm.scale_max = 1.3
	pm.color = Color(0.32, 0.2, 0.1)
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.12, 0.09)
	var qm := StandardMaterial3D.new()
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	qm.vertex_color_use_as_albedo = true
	qm.cull_mode = BaseMaterial3D.CULL_DISABLED
	qm.roughness = 1.0
	q.material = qm
	p.draw_pass_1 = q
	p.visibility_aabb = AABB(Vector3(-w, -12, -l), Vector3(w * 2.0, 16.0, l * 2.0))
	room.add_child(p)


## Fireflies over the clearing (seen once it grows dark).
static func _fireflies(dun: Dungeon, room: Node3D, w: float, l: float) -> void:
	var p := GPUParticles3D.new()
	p.amount = 90
	p.lifetime = 6.0
	p.position = Vector3(0.0, 1.6, 0.0)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(w * 0.45, 1.2, l * 0.45)
	pm.gravity = Vector3.ZERO
	pm.initial_velocity_min = 0.1
	pm.initial_velocity_max = 0.4
	pm.direction = Vector3.UP
	pm.spread = 180.0
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.6
	var fade := Gradient.new()
	fade.set_color(0, Color(1.0, 0.9, 0.3, 0.0))
	fade.add_point(0.3, Color(1.0, 0.92, 0.35, 1.0))
	fade.add_point(0.7, Color(0.9, 1.0, 0.4, 1.0))
	fade.set_color(fade.get_point_count() - 1, Color(1.0, 0.9, 0.3, 0.0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	pm.color_ramp = ramp
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.22, 0.22)
	var qm := StandardMaterial3D.new()
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	qm.vertex_color_use_as_albedo = true
	qm.albedo_color = Color(2.0, 2.0, 1.2)
	# a soft round glow (the user's word, 2026-10-23: not squares)
	qm.albedo_texture = PlaceBuild.soft_dot()
	q.material = qm
	p.draw_pass_1 = q
	p.visibility_aabb = AABB(Vector3(-w, -2, -l), Vector3(w * 2.0, 6.0, l * 2.0))
	room.add_child(p)


## A model of the nature kit in glTF/ (the stylized trees, bushes, ferns,
## flowers, grass, rocks: the user's word, 2026-10-20, our own pretty
## low-poly trees), `scale` times its own size, turned `yaw`.
static func _nature(dun: Dungeon, room: Node3D, name: String, at: Vector3, scale: float, yaw: float, shadow: bool = true,
		bare: bool = false) -> Node3D:
	var path := "res://glTF/%s.gltf" % name
	var scene: PackedScene = dun._models.get(path) as PackedScene
	if scene == null:
		if not ResourceLoader.exists(path):
			return null
		scene = load(path) as PackedScene
		dun._models[path] = scene
	if scene == null:
		return null
	var n := scene.instantiate() as Node3D
	n.position = at
	n.rotation.y = yaw
	# the kit's twisted trees stand twice as tall as the rest, its flowers
	# as tall as a man
	if name.begins_with("TwistedTree"):
		scale *= 0.5
	elif name.begins_with("Flower"):
		scale *= 0.45
	n.scale = Vector3.ONE * scale
	room.add_child(n)
	if bare:
		DungeonBuild._strip_leaves(dun, n)
	DungeonBuild._solid_nature(dun, n, name)
	if not shadow:
		for m in n.find_children("*", "GeometryInstance3D", true, false):
			(m as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return n


## Trees and rocks of the kit stand in the way (the user's word, 2026-10-22:
## the heroes walked through them): a trunk for a tree, its hull for a rock,
## in the model's own frame (the node is scaled evenly).
static func _solid_nature(dun: Dungeon, n: Node3D, name: String) -> void:
	var holder: Node3D = n
	var shape: Shape3D = null
	var at := Vector3.ZERO
	if name.contains("Tree"):
		var trunk := CylinderShape3D.new()
		trunk.radius = 0.45
		trunk.height = 6.0
		shape = trunk
		at = Vector3(0.0, 3.0, 0.0)
	elif name.begins_with("Rock_"):
		var meshes := n.find_children("*", "MeshInstance3D", true, false)
		if meshes.is_empty():
			return
		var mesh := meshes[0] as MeshInstance3D
		var hull: ConvexPolygonShape3D = dun._hulls.get(mesh.mesh) as ConvexPolygonShape3D
		if hull == null:
			hull = mesh.mesh.create_convex_shape(true, true) as ConvexPolygonShape3D
			dun._hulls[mesh.mesh] = hull
		shape = hull
		# in the mesh's own frame, whatever the model's nodes do to it
		holder = mesh
	if shape == null:
		return
	var body := StaticBody3D.new()
	body.name = "Solid"
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position = at
	body.add_child(col)
	holder.add_child(body)


## A tree of the kit with its leaves taken off (the dead wood's).
static func _strip_leaves(dun: Dungeon, n: Node3D) -> void:
	for node in n.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		var am := mi.mesh as ArrayMesh
		if am == null:
			continue
		var bare: ArrayMesh = dun._bare_meshes.get(am) as ArrayMesh
		if bare == null:
			bare = am.duplicate() as ArrayMesh
			for k in range(bare.get_surface_count() - 1, -1, -1):
				var m := bare.surface_get_material(k)
				if m != null and m.resource_name.to_lower().contains("lea"):
					bare.surface_remove(k)
			dun._bare_meshes[am] = bare
		if bare.get_surface_count() == 0:
			mi.visible = false
		else:
			mi.mesh = bare


## The forest's trees, at random, the big leafy ones most of all.
static func _a_tree(dun: Dungeon) -> String:
	var roll := dun._rng.randf()
	if roll < 0.55:
		return "CommonTree_%d" % dun._rng.randi_range(1, 5)
	if roll < 0.9:
		return "Pine_%d" % dun._rng.randi_range(1, 5)
	if roll < 0.96:
		return "TwistedTree_%d" % dun._rng.randi_range(1, 5)
	return "DeadTree_%d" % dun._rng.randi_range(1, 5)


## A green tree: the broadleaf and the pine, never the red twisted one.
static func _a_green_tree(dun: Dungeon) -> String:
	if dun._rng.randf() < 0.65:
		return "CommonTree_%d" % dun._rng.randi_range(1, 5)
	return "Pine_%d" % dun._rng.randi_range(1, 5)


## The sea of cloud under the island: soft layers one over another.
static func _cloud_layers(dun: Dungeon, room: Node3D, base: float = -78.0) -> void:
	dun._cloud_layer_mats.clear()
	var sh := Shader.new()
	sh.code = Dungeon.CLOUD_LAYER_SHADER
	for k in 4:
		var m := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2(2600.0, 2600.0)
		m.mesh = plane
		var mat := ShaderMaterial.new()
		mat.shader = sh
		mat.set_shader_parameter("seed", float(k) * 13.7)
		mat.set_shader_parameter("cover", 0.42 + float(k) * 0.08)
		mat.set_shader_parameter("opacity", 0.55 + float(k) * 0.12)
		mat.set_shader_parameter("middle", Vector2(room.global_position.x, room.global_position.z))
		m.material_override = mat
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		m.position = Vector3(0.0, base + float(k) * (7.0 if base < -60.0 else 4.0), 0.0)
		room.add_child(m)
		dun._cloud_layer_mats.append(mat)
	dun._apply_phase(dun._phase)


## An island in the sky: a round temple arena on a floating rock over a sea of
## cloud (the user's pick of the concept pictures, 2026-10-23; [SkyTemple]
## builds it). The place is 56 m square only so that its round floor fits:
## an unseen wall stands round the rim at 28.6 m.
static func _build_sky(dun: Dungeon, room: Node3D, i: int) -> void:
	var r := dun._room(i)
	SkyTemple.build(dun, room, dun._rng)
	# the sea of cloud close under the island, so nothing shows below it
	DungeonBuild._cloud_layers(dun, room, -40.0)
	DungeonBuild._circling_birds(dun, room)
	DungeonBuild._motes(dun, room, float(r["w"]) * 0.7, float(r["l"]) * 0.7, 10.0)

#endregion


## A stream across the forest's clearing, stepping stones over it, its sound.
static func _stream(dun: Dungeon, room: Node3D, w: float, l: float) -> void:
	var z := l * 0.12
	var water := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(3.2, w + 80.0)
	water.mesh = plane
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = Dungeon.WATER_SHADER
	mat.shader = sh
	water.material_override = mat
	water.rotation.y = PI * 0.5 + 0.12
	water.position = Vector3(0.0, 0.04, z)
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	room.add_child(water)
	# its banks: stones along both sides
	for k in 40:
		var x := -w * 0.55 + float(k) * (w * 1.1 / 40.0)
		for side: float in [-1.0, 1.0]:
			var at := Vector3(x, 0.0, z + side * 1.9 + x * 0.12 + dun._rng.randf_range(-0.3, 0.3))
			DungeonBuild._prop(dun, room, "Rock_%d" % dun._rng.randi_range(1, 9), at, dun._rng.randf_range(0.25, 0.6), dun._rng.randf_range(0.0, TAU), false)
	for k in 3:
		var x := -6.0 + float(k) * 6.0
		DungeonBuild._prop(dun, room, "Stepping_Stone_%d" % (k + 1), Vector3(x, 0.02, z + x * 0.12), 0.25, dun._rng.randf_range(0.0, TAU), false)
	var stream := dun._loop("stream_loop.wav")
	if stream != null:
		for x: float in [-w * 0.3, w * 0.3]:
			var sound := AudioStreamPlayer3D.new()
			sound.stream = stream
			sound.volume_db = -6.0
			sound.unit_size = 5.0
			sound.max_distance = 30.0
			sound.bus = &"Dungeon"
			sound.position = Vector3(x, 0.3, z + x * 0.12)
			room.add_child(sound)
			sound.play(dun._rng.randf_range(0.0, 10.0))


## Mist lying low over the ground, drifting.
static func _mist(dun: Dungeon, room: Node3D, w: float, l: float, y: float, tint: Color, thick: float, count: int = 10) -> void:
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = Dungeon.MIST_SHADER
	mat.shader = sh
	mat.set_shader_parameter("tint", tint)
	mat.set_shader_parameter("thick", thick)
	for k in count:
		var m := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2(dun._rng.randf_range(18.0, 34.0), dun._rng.randf_range(18.0, 34.0))
		m.mesh = plane
		m.material_override = mat
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		m.position = Vector3(dun._rng.randf_range(-w * 0.45, w * 0.45), y + dun._rng.randf_range(0.0, 0.8),
				dun._rng.randf_range(-l * 0.45, l * 0.45))
		room.add_child(m)


## Butterflies over the flowers, by day.
static func _butterflies(dun: Dungeon, room: Node3D, w: float, l: float) -> void:
	var p := GPUParticles3D.new()
	p.amount = 26
	p.lifetime = 8.0
	p.position = Vector3(0.0, 1.0, 0.0)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(w * 0.42, 0.6, l * 0.42)
	pm.gravity = Vector3.ZERO
	pm.initial_velocity_min = 0.4
	pm.initial_velocity_max = 1.0
	pm.spread = 180.0
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 1.2
	pm.turbulence_noise_scale = 2.0
	var cols := Gradient.new()
	cols.set_color(0, Color(1.0, 0.85, 0.2))
	cols.add_point(0.5, Color(0.95, 0.4, 0.75))
	cols.set_color(cols.get_point_count() - 1, Color(0.4, 0.75, 1.0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = cols
	pm.color_initial_ramp = ramp
	pm.scale_min = 0.8
	pm.scale_max = 1.3
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.16, 0.12)
	var qm := StandardMaterial3D.new()
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	qm.vertex_color_use_as_albedo = true
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	q.material = qm
	p.draw_pass_1 = q
	p.visibility_aabb = AABB(Vector3(-w, -2, -l), Vector3(w * 2.0, 8.0, l * 2.0))
	room.add_child(p)


## Some of a cave's mushrooms give a light of their own.
static func _glow(dun: Dungeon, m: MeshInstance3D, tint: Color) -> void:
	if m == null:
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint.darkened(0.4)
	mat.emission_enabled = true
	mat.emission = tint
	mat.emission_energy_multiplier = 1.8
	m.material_override = mat
	var light := OmniLight3D.new()
	light.light_color = tint
	light.light_energy = 0.8
	light.omni_range = 4.0
	light.position = Vector3(0.0, 0.6 / maxf(m.scale.y, 0.01), 0.0)
	m.add_child(light)


## Birds circling the island, far off and near.
static func _circling_birds(dun: Dungeon, room: Node3D) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.08, 0.07, 0.07)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	for k in 7:
		var bird := Node3D.new()
		for side: float in [-1.0, 1.0]:
			var wing := MeshInstance3D.new()
			var wm := BoxMesh.new()
			wm.size = Vector3(1.4, 0.05, 0.45)
			wing.mesh = wm
			wing.material_override = mat
			wing.position = Vector3(side * 0.7, 0.0, 0.0)
			wing.name = "L" if side < 0.0 else "R"
			bird.add_child(wing)
		room.add_child(bird)
		dun._birds.append({"node": bird, "radius": dun._rng.randf_range(40.0, 120.0), "height": dun._rng.randf_range(8.0, 40.0),
				"speed": dun._rng.randf_range(0.08, 0.2) * (1.0 if k % 2 == 0 else -1.0), "at": dun._rng.randf_range(0.0, TAU)})


## Blades left standing in the floor where the orcs' fights were.
static func _blades_in_floor(dun: Dungeon, room: Node3D, w: float, l: float, count: int) -> void:
	for k in count:
		var sword := Node3D.new()
		var blade := MeshInstance3D.new()
		var bm := BoxMesh.new()
		var long := dun._rng.randf_range(0.9, 1.5)
		bm.size = Vector3(0.09, long, 0.025)
		blade.mesh = bm
		blade.material_override = dun._iron_mat
		blade.position = Vector3(0.0, long * 0.5 - 0.25, 0.0)
		sword.add_child(blade)
		var guard := MeshInstance3D.new()
		var gm := BoxMesh.new()
		gm.size = Vector3(0.36, 0.05, 0.06)
		guard.mesh = gm
		guard.material_override = dun._gold_mat if k % 3 == 0 else dun._iron_mat
		guard.position = Vector3(0.0, long - 0.25, 0.0)
		sword.add_child(guard)
		var grip := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.025
		cm.bottom_radius = 0.025
		cm.height = 0.22
		grip.mesh = cm
		grip.material_override = dun._wood_mat
		grip.position = Vector3(0.0, long - 0.12, 0.0)
		sword.add_child(grip)
		var x := dun._rng.randf_range(-w * 0.42, w * 0.42)
		var z := dun._rng.randf_range(-l * 0.4, l * 0.4)
		if absf(x) < 4.0:
			x += 6.0 * signf(x + 0.01)
		sword.position = Vector3(x, 0.0, z)
		sword.rotation = Vector3(dun._rng.randf_range(-0.35, 0.35), dun._rng.randf_range(0.0, TAU), dun._rng.randf_range(-0.35, 0.35))
		room.add_child(sword)
#endregion


#region Round 10: more places (the crypt, the swamp, the stormy mountain, the rampart)
## The graveyard kit's props (assets/necropoly: candles, chains, lanterns, the
## tomb niche, the swamp's grass, roots and stones), dressed as [NecroPlaces]
## dresses them: its palette, and a glow for what burns.
static func _necro(dun: Dungeon, name: String) -> Mesh:
	if dun._necro_meshes.is_empty():
		dun._necro_mat = ShaderMaterial.new()
		dun._necro_mat.shader = load("res://shaders/necro.gdshader")
		dun._necro_mat.set_shader_parameter(&"palette", load("res://assets/necropoly/necro_palette.png"))
		dun._necro_mat.set_shader_parameter(&"ours", 1.0)
		dun._necro_glow = StandardMaterial3D.new()
		dun._necro_glow.albedo_color = Color(1.0, 0.62, 0.25)
		dun._necro_glow.emission_enabled = true
		dun._necro_glow.emission = Color(1.0, 0.55, 0.2)
		dun._necro_glow.emission_energy_multiplier = 3.0
		var scene := load("res://assets/necropoly/necro_props.glb") as PackedScene
		if scene != null:
			var root := scene.instantiate()
			for node in root.find_children("*", "MeshInstance3D", true, false):
				var mi := node as MeshInstance3D
				var am := mi.mesh as ArrayMesh
				if am == null:
					continue
				var copy := am.duplicate() as ArrayMesh
				for k in copy.get_surface_count():
					var m := copy.surface_get_material(k)
					var lit := m != null and m.resource_name.contains("glow")
					copy.surface_set_material(k, dun._necro_glow if lit else dun._necro_mat)
				dun._necro_meshes[String(mi.name)] = copy
			root.free()
	return dun._necro_meshes.get(name) as Mesh


static func _necro_put(dun: Dungeon, room: Node3D, name: String, at: Vector3, yaw: float, size: float = 1.0, shadow: bool = true) -> MeshInstance3D:
	var mesh := DungeonBuild._necro(dun, name)
	if mesh == null:
		return null
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.transform = Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * size * 0.4), at)
	if not shadow:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	room.add_child(mi)
	return mi


## A cluster of candles burning, with the little light they give.
static func _candles(dun: Dungeon, room: Node3D, at: Vector3, light: bool = true) -> void:
	for k in dun._rng.randi_range(2, 4):
		DungeonBuild._necro_put(dun, room, ["EA_Candle_01a", "EA_Candle_01b", "EA_Candle_01c"][k % 3],
				at + Vector3(dun._rng.randf_range(-0.35, 0.35), 0.0, dun._rng.randf_range(-0.35, 0.35)), dun._rng.randf_range(0.0, TAU),
				dun._rng.randf_range(0.8, 1.3), false)
	room.add_child(DungeonBuild._flame(dun, at + Vector3(0.0, 0.45, 0.0), 0.6, 8))
	if light:
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.62, 0.3)
		l.light_energy = 1.4
		l.omni_range = 7.0
		l.position = at + Vector3(0.0, 0.8, 0.0)
		room.add_child(DungeonBuild._fire_light(dun, l))


## Old bones lying: a few long ones and a skull.
static func _bones(dun: Dungeon, room: Node3D, at: Vector3) -> void:
	if dun._bone_mat == null:
		dun._bone_mat = StandardMaterial3D.new()
		dun._bone_mat.albedo_color = Color(0.78, 0.74, 0.64)
		dun._bone_mat.roughness = 0.8
	for k in dun._rng.randi_range(3, 6):
		var b := CylinderMesh.new()
		b.top_radius = 0.04
		b.bottom_radius = 0.05
		b.height = dun._rng.randf_range(0.35, 0.7)
		b.radial_segments = 6
		var m := DungeonBuild._deco(dun, room, dun._bone_mat, b, at + Vector3(dun._rng.randf_range(-0.6, 0.6), 0.05, dun._rng.randf_range(-0.6, 0.6)))
		m.rotation = Vector3(PI * 0.5, dun._rng.randf_range(0.0, TAU), 0.0)
	var skull := SphereMesh.new()
	skull.radius = 0.13
	skull.height = 0.24
	skull.radial_segments = 10
	skull.rings = 5
	DungeonBuild._deco(dun, room, dun._bone_mat, skull, at + Vector3(0.0, 0.12, 0.0))


## A swamp: the user's pick (2026-10-23, concept "v1_village"), a bright
## mossy clearing between clear pools in real hollows; [SwampMere] builds it.
static func _build_swamp(dun: Dungeon, room: Node3D, i: int) -> void:
	var r := dun._room(i)
	SwampMere.build(dun, room, r["w"], r["l"], dun._rng)


## A mountain path in a storm (the user's word: a stormy mountain path):
## a broken shelf of rock high among the peaks, cliffs round it, a few pines
## bent by the wind, snow in the hollows, rain driven across it, the sky dark
## and lit by lightning.
static func _build_mountain(dun: Dungeon, room: Node3D, i: int) -> void:
	var r := dun._room(i)
	var w: float = r["w"]
	var l: float = r["l"]
	# the shelf: bare rock, dark with the rain, puddles in its hollows (the
	# user's word, 2026-10-21: not that floor; not the stones in the middle;
	# the rain finer, and the wet felt on him)
	var shelf := dun._rock_mat.duplicate() as ShaderMaterial
	shelf.set_shader_parameter("scale", 0.3)
	shelf.set_shader_parameter("rock_a", Color(0.26, 0.27, 0.30))
	shelf.set_shader_parameter("rock_b", Color(0.11, 0.12, 0.14))
	shelf.set_shader_parameter("band", Color(0.36, 0.36, 0.38))
	shelf.set_shader_parameter("moss", Color(0.16, 0.2, 0.12))
	shelf.set_shader_parameter("moss_amount", 0.35)
	shelf.set_shader_parameter("wet", 1.0)
	DungeonBuild._solid(dun, room, shelf, Vector3(w + 20.0, 1.0, l + 20.0), Vector3(0.0, -0.5, 0.0))
	DungeonBuild._crag_under(dun, room, w + 30.0, l + 30.0, PalaceVista.DROP + 120.0, -1.0)
	DungeonBuild._bounds(dun, room, w, l)
	# cliffs: great rocks along both long sides, the near and far ends open to
	# the drop; grey, wet, snow only high up
	var cliff := dun._rock_mat.duplicate() as ShaderMaterial
	cliff.set_shader_parameter("rock_a", Color(0.40, 0.41, 0.44))
	cliff.set_shader_parameter("rock_b", Color(0.18, 0.19, 0.22))
	cliff.set_shader_parameter("band", Color(0.48, 0.48, 0.51))
	cliff.set_shader_parameter("moss", Color(0.86, 0.88, 0.93))
	cliff.set_shader_parameter("moss_amount", 0.55)
	cliff.set_shader_parameter("wet", 0.9)
	for side: float in [-1.0, 1.0]:
		var z := -l * 0.5 - 6.0
		while z < l * 0.5 + 6.0:
			var tall := dun._rng.randf_range(14.0, 34.0)
			DungeonBuild._boulder(dun, room, Vector3(side * (w * 0.5 + dun._rng.randf_range(3.0, 8.0)), -2.0, z),
					Vector3(dun._rng.randf_range(12.0, 20.0), tall, dun._rng.randf_range(10.0, 16.0)), dun._rng.randf_range(0.0, TAU), cliff)
			z += dun._rng.randf_range(7.0, 11.0)
	# pines along the cliffs' feet, wind-bent; a few stones and tufts there
	for k in 10:
		var x := (w * dun._rng.randf_range(0.4, 0.5)) * (1.0 if k % 2 == 0 else -1.0)
		DungeonBuild._nature(dun, room, "Pine_%d" % dun._rng.randi_range(1, 5), Vector3(x, 0.0, dun._rng.randf_range(-l * 0.45, l * 0.45)),
				dun._rng.randf_range(1.2, 2.0), dun._rng.randf_range(0.0, TAU))
	for k in 16:
		var x := (w * dun._rng.randf_range(0.38, 0.48)) * (1.0 if k % 2 == 0 else -1.0)
		DungeonBuild._nature(dun, room, ["Grass_Wispy_Short", "Pebble_Round_3", "Rock_Medium_2", "Fern_1"][k % 4],
				Vector3(x, 0.0, dun._rng.randf_range(-l * 0.46, l * 0.46)), dun._rng.randf_range(0.8, 1.3), dun._rng.randf_range(0.0, TAU), false)
	# an old shrine of the road at the far end: a broken arch
	for side: float in [-1.0, 1.0]:
		DungeonBuild._column(dun, room, i, Vector3(side * 4.0, 0.0, -l * 0.3), 7.0, 0.9)
	var lintel := BoxMesh.new()
	lintel.size = Vector3(9.5, 0.9, 1.4)
	var lt := DungeonBuild._deco(dun, room, dun._trim_mat, lintel, Vector3(0.6, 7.2, -l * 0.3))
	lt.rotation.z = -0.08
	PlaceBuild.puddles(dun, room, w, l)
	DungeonBuild._rain(dun, room, w, l)
	PlaceBuild.splashes(room, w, l)


## Rain driven across a place.
static func _rain(dun: Dungeon, room: Node3D, w: float, l: float) -> void:
	var p := GPUParticles3D.new()
	p.amount = 5000
	p.lifetime = 1.0
	p.position = Vector3(0.0, 22.0, 0.0)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(w * 0.7, 1.0, l * 0.7)
	pm.direction = Vector3(0.25, -1.0, 0.1)
	pm.spread = 3.0
	pm.initial_velocity_min = 22.0
	pm.initial_velocity_max = 28.0
	pm.scale_min = 0.6
	pm.scale_max = 1.2
	pm.gravity = Vector3(0.0, -10.0, 0.0)
	pm.particle_flag_align_y = true
	p.process_material = pm
	# thin streaks soft at their edges and ends (the user's word, 2026-10-23:
	# squares, like hail)
	var q := QuadMesh.new()
	q.size = Vector2(0.035, 0.9)
	var qm := StandardMaterial3D.new()
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.albedo_color = Color(0.82, 0.86, 0.92, 0.22)
	qm.albedo_texture = PlaceBuild.streak()
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	qm.billboard_keep_scale = true
	q.material = qm
	p.draw_pass_1 = q
	p.visibility_aabb = AABB(Vector3(-w, -30, -l), Vector3(w * 2.0, 40.0, l * 2.0))
	room.add_child(p)


## The castle's rampart (the user's word: a broken castle wall): a long
## walk along the top of the wall, its battlements broken here and there and
## the gaps blocked with rubble, a tower at each end, fires still burning from
## the fighting, arrows stuck in the stones, banners torn by the wind.
static func _build_rampart(dun: Dungeon, room: Node3D, i: int) -> void:
	var r := dun._room(i)
	var w: float = r["w"]
	var l: float = r["l"]
	DungeonBuild._solid(dun, room, dun._floor_mat(i), Vector3(w + Dungeon.WALL_T * 2.0, 1.0, l + Dungeon.WALL_T * 2.0), Vector3(0.0, -0.5, 0.0))
	DungeonBuild._solid(dun, room, dun._wall_mat, Vector3(w + Dungeon.WALL_T * 2.0, 40.0, l + Dungeon.WALL_T * 2.0), Vector3(0.0, -20.5, 0.0), false)
	DungeonBuild._crag_under(dun, room, w + 20.0, l + 20.0, PalaceVista.DROP + 40.0, -40.0)
	DungeonBuild._bounds(dun, room, w, l)
	# over the battlements' whole thickness and beyond, and the ends, so no
	# one climbs onto them and off (the user's word, 2026-10-23: he jumped
	# over and fell)
	for side: float in [-1.0, 1.0]:
		DungeonBuild._blocker(dun, room, Vector3(Dungeon.WALL_T + 3.0, Dungeon.BLOCK_H, l + 8.0), Vector3(side * (w * 0.5 + Dungeon.WALL_T * 0.5 + 1.0), Dungeon.BLOCK_H * 0.5, 0.0))
		DungeonBuild._blocker(dun, room, Vector3(w + 8.0, Dungeon.BLOCK_H, 3.0), Vector3(0.0, Dungeon.BLOCK_H * 0.5, side * (l * 0.5 + 1.5)))
	# the battlements: a breast-high wall, merlons on it, broken in places
	for side: float in [-1.0, 1.0]:
		var x := side * (w * 0.5 + Dungeon.WALL_T * 0.5)
		var z := -l * 0.5
		while z < l * 0.5:
			var piece := minf(dun._rng.randf_range(5.0, 9.0), l * 0.5 - z)
			var broken := dun._rng.randf() < 0.2
			var hh := 1.4 if broken else 2.2
			DungeonBuild._solid(dun, room, dun._wall_mat, Vector3(Dungeon.WALL_T, hh, piece), Vector3(x, hh * 0.5, z + piece * 0.5))
			if broken:
				DungeonBuild._rubble(dun, room, Vector3(x - side * 1.2, 0.0, z + piece * 0.5), 2.0, 10, int(z * 7.0))
			else:
				var mz := z + 0.8
				while mz < z + piece - 0.6:
					var merlon := BoxMesh.new()
					merlon.size = Vector3(Dungeon.WALL_T, 1.1, 1.0)
					DungeonBuild._deco(dun, room, dun._wall_mat, merlon, Vector3(x, hh + 0.55, mz))
					mz += 2.0
			z += piece
	# a tower at each end
	for end: float in [-1.0, 1.0]:
		var tower := CylinderMesh.new()
		tower.top_radius = w * 0.42
		tower.bottom_radius = w * 0.45
		tower.height = 26.0
		tower.radial_segments = 16
		DungeonBuild._deco(dun, room, dun._wall_mat, tower, Vector3(0.0, 13.0 - 6.0, end * (l * 0.5 + w * 0.42)))
		var roof := CylinderMesh.new()
		roof.top_radius = 0.0
		roof.bottom_radius = w * 0.5
		roof.height = 10.0
		roof.radial_segments = 16
		var rf := DungeonBuild._deco(dun, room, dun._wood_mat, roof, Vector3(0.0, 25.0, end * (l * 0.5 + w * 0.42)))
		if end > 0.0:
			# its roof half burnt away
			rf.scale = Vector3(1.0, 0.55, 1.0)
			rf.rotation.z = 0.25
	# what the fighting left: arrows, blades (the fires lying in the way gone:
	# the user's word, 2026-10-23, he walked through them)
	DungeonBuild._arrows(dun, room, w, l, 40)
	DungeonBuild._blades_in_floor(dun, room, w, l, 8)
	for k in 6:
		var side := -1.0 if k % 2 == 0 else 1.0
		DungeonBuild._hang_banner(dun, room, Vector3(side * (w * 0.5 + 0.6), 6.0, -l * 0.35 + floorf(float(k) / 2.0) * l * 0.35), side, 4.5)
		var pole := CylinderMesh.new()
		pole.top_radius = 0.07
		pole.bottom_radius = 0.07
		pole.height = 6.4
		DungeonBuild._deco(dun, room, dun._wood_mat, pole, Vector3(side * (w * 0.5 + 0.75), 3.0, -l * 0.35 + floorf(float(k) / 2.0) * l * 0.35))


## Arrows stuck in the floor where a volley came down.
static func _arrows(dun: Dungeon, room: Node3D, w: float, l: float, count: int) -> void:
	var fletch := StandardMaterial3D.new()
	fletch.albedo_color = Color(0.7, 0.66, 0.6)
	for k in count:
		var arrow := Node3D.new()
		var shaft := CylinderMesh.new()
		shaft.top_radius = 0.015
		shaft.bottom_radius = 0.015
		shaft.height = 0.75
		shaft.radial_segments = 5
		var s := MeshInstance3D.new()
		s.mesh = shaft
		s.material_override = dun._wood_mat
		s.position = Vector3(0.0, 0.3, 0.0)
		arrow.add_child(s)
		var f := MeshInstance3D.new()
		var fm := BoxMesh.new()
		fm.size = Vector3(0.12, 0.16, 0.01)
		f.mesh = fm
		f.material_override = fletch
		f.position = Vector3(0.0, 0.62, 0.0)
		arrow.add_child(f)
		arrow.position = Vector3(dun._rng.randf_range(-w * 0.45, w * 0.45), 0.0, dun._rng.randf_range(-l * 0.45, l * 0.45))
		arrow.rotation = Vector3(dun._rng.randf_range(-0.5, 0.5), dun._rng.randf_range(0.0, TAU), dun._rng.randf_range(-0.5, 0.5))
		room.add_child(arrow)


#region Round 10: the first hall livelier, blows seen
## What a fight long ago left in a hall: shields broken and spears, bones.
static func _battle_remains(dun: Dungeon, room: Node3D, w: float, l: float) -> void:
	# only the arrows now (the user's word, 2026-10-23: nothing else lying
	# about the hall's floor)
	for k in 0:
		var at := Vector3(dun._rng.randf_range(-w * 0.42, w * 0.42), 0.0, dun._rng.randf_range(-l * 0.42, l * 0.42))
		if absf(at.x) < 3.5:
			at.x += 6.0 * signf(at.x + 0.01)
		var shield := CylinderMesh.new()
		shield.top_radius = 0.5
		shield.bottom_radius = 0.5
		shield.height = 0.06
		shield.radial_segments = 14
		var sh := DungeonBuild._deco(dun, room, dun._wood_mat, shield, at + Vector3(0.0, 0.05, 0.0))
		sh.rotation = Vector3(dun._rng.randf_range(-0.3, 0.3), 0.0, dun._rng.randf_range(-0.3, 0.3))
		var rim := CylinderMesh.new()
		rim.top_radius = 0.53
		rim.bottom_radius = 0.53
		rim.height = 0.04
		rim.radial_segments = 14
		DungeonBuild._deco(dun, room, dun._iron_mat, rim, at + Vector3(0.0, 0.03, 0.0))
		var spear := CylinderMesh.new()
		spear.top_radius = 0.03
		spear.bottom_radius = 0.03
		spear.height = 2.4
		spear.radial_segments = 5
		var sp := DungeonBuild._deco(dun, room, dun._wood_mat, spear, at + Vector3(dun._rng.randf_range(-1.0, 1.0), 0.05, dun._rng.randf_range(-1.0, 1.0)))
		sp.rotation = Vector3(PI * 0.5, dun._rng.randf_range(0.0, TAU), 0.0)
		if k % 2 == 0:
			DungeonBuild._bones(dun, room, at + Vector3(1.2, 0.0, 0.6))
	DungeonBuild._arrows(dun, room, w, l, 18)


## The banners' cloth, torn: ragged at the foot, holed (the user's word: torn banners).
static func _torn_cloth(dun: Dungeon) -> ShaderMaterial:
	if dun._banner_mat == null:
		var sh := Shader.new()
		sh.code = """
shader_type spatial;
render_mode cull_disabled;
uniform vec4 cloth : source_color = vec4(0.30, 0.08, 0.38, 1.0);
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}
varying vec3 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 p = vec2(wpos.x + wpos.z, wpos.y);
	float ragged = noise(vec2(p.x * 3.0, 0.0)) * 0.25 + noise(vec2(p.x * 9.0, 1.0)) * 0.1;
	if (UV.y > 0.72 + ragged) { discard; }
	if (noise(p * 2.2) > 0.82) { discard; }
	float burn = smoothstep(0.62, 0.8, UV.y + ragged * 0.5);
	ALBEDO = mix(cloth.rgb * (0.75 + 0.35 * noise(p * 6.0)), vec3(0.05, 0.03, 0.02), burn);
	ROUGHNESS = 0.95;
}
"""
		dun._banner_mat = ShaderMaterial.new()
		dun._banner_mat.shader = sh
	return dun._banner_mat


## Broken stone in a heap at `at` (in `parent`'s frame): `size` across, `count` pieces.
static func _rubble(dun: Dungeon, parent: Node3D, at: Vector3, size: float, count: int, seed_n: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_n
	for k in count:
		var piece := MeshInstance3D.new()
		if k % 3 == 0:
			var block := BoxMesh.new()
			block.size = Vector3(rng.randf_range(0.5, 1.3), rng.randf_range(0.35, 0.7), rng.randf_range(0.5, 1.0)) * clampf(size / 2.0, 0.4, 1.4)
			piece.mesh = block
			piece.material_override = dun._wall_mat
		else:
			piece.mesh = RockWave._crag_mesh(k % RockWave.SHAPES)
			piece.material_override = dun._rock_mat
			var s := rng.randf_range(0.25, 0.75) * size * 0.6
			piece.scale = Vector3(s, s * rng.randf_range(0.5, 0.9), s)
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf()) * size
		piece.position = at + Vector3(cos(a) * r, rng.randf_range(0.0, 0.25) * (1.0 - r / maxf(size, 0.01)) * size, sin(a) * r)
		piece.rotation = Vector3(rng.randf_range(-0.4, 0.4), rng.randf() * TAU, rng.randf_range(-0.4, 0.4))
		parent.add_child(piece)


## Heaps along the walls and in the corners, where the palace has begun to come down.
static func _rubble_round(dun: Dungeon, room: Node3D, i: int, w: float, l: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 500 + i * 17 + dun.id
	for k in 4:
		var side := -1.0 if k % 2 == 0 else 1.0
		var z := rng.randf_range(-l * 0.4, l * 0.4)
		DungeonBuild._rubble(dun, room, Vector3(side * (w * 0.5 - 2.0), 0.0, z), rng.randf_range(1.2, 2.6), rng.randi_range(8, 16), rng.randi())


## A column lying where it fell long ago, in drums.
static func _fallen_column(dun: Dungeon, room: Node3D, at: Vector3, yaw: float) -> void:
	var dir := Vector3(sin(yaw), 0.0, cos(yaw))
	for k in 4:
		var drum := CylinderMesh.new()
		drum.top_radius = 0.6
		drum.bottom_radius = 0.6
		drum.height = 2.2
		drum.radial_segments = 14
		var d := DungeonBuild._deco(dun, room, dun._wall_mat, drum, at + dir * (float(k) * 2.5 + randf_range(-0.2, 0.2)) + Vector3(0.0, 0.6, 0.0))
		d.rotation = Vector3(PI * 0.5, yaw, float(k) * 0.3)
	DungeonBuild._solid(dun, room, dun._trim_mat, Vector3(2.0, 0.6, 2.0), at - dir * 2.0 + Vector3(0.0, 0.3, 0.0))
	var lying := DungeonBuild._blocker(dun, room, Vector3(1.2, 1.2, 10.0), at + dir * 3.75 + Vector3(0.0, 0.6, 0.0))
	lying.rotation.y = yaw
	DungeonBuild._rubble(dun, room, at + dir * 5.0, 1.4, 8, int(at.x * 13.0 + at.z))
