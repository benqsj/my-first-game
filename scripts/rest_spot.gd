class_name RestSpot
extends Node3D

## The places to get one's breath back in a run (the user's word, 2026-10-21:
## not every room a fight, as in Hades): no creatures, the way on open at once.
##
## * **spring** ("წმინდა წყარო") — a quiet cloister open to the sky, a basin of
##   water that glows in the middle. Stepping into it heals him whole and fills
##   his flasks again, once.
## * **prison** ("ტყვეების ოთახი") — where the orcs kept their prisoners: cages
##   down both sides, the dead in most, one man alive in the last. Come to his
##   cage and he is free: he thanks him, gives him a thing he had hidden, and
##   goes — he will be living in the village from now on ([method Game.free_prisoner]).
##
## Built by [Dungeon] ([method build]) with its own helpers; this node, in the
## middle of the place, watches for the hero.

const NAMES := ["გიორგი", "დავითი", "ლევანი", "ზურაბი", "ვახტანგი", "ირაკლი", "ბექა", "ნიკა"]
var kind: String = ""
var _d: Dungeon
var _used: bool = false
var _water: ShaderMaterial
var _light: OmniLight3D
var _man: Villager
var _cage: Node3D
## the living man's door in the cave's cells: locked till the jailers' key
## is found (the user's word, 2026-10-25: kill them, take the key, open it)
var _door: Node3D
var _i: int = -1
var _key: Node3D
var _has_key: bool = false
var _last_down: Vector3 = Vector3.INF
var _nag_at: int = 0
var _name: String = ""


## The place `kind` in `room` (its index `i`).
static func build(d: Dungeon, room: Node3D, i: int, what: String) -> void:
	var r := d._room(i)
	var w: float = r["w"]
	var l: float = r["l"]
	var h: float = r["h"]
	if what == "cell_cave":
		# the prisoners in cells cut into a cave, under its roof (the
		# user's word, 2026-10-25): [CellCave] builds it all
		var cave := RestSpot.new()
		cave.name = "Rest"
		cave.kind = what
		cave._d = d
		cave._i = i
		room.add_child(cave)
		cave._build_cave(room, w, l)
		return
	d._crag_under(room, w + Dungeon.WALL_T * 2.0, l + Dungeon.WALL_T * 2.0, PalaceVista.DROP + 40.0, -24.0)
	d._solid(room, d._floor_mat(i), Vector3(w + Dungeon.WALL_T * 2.0, 1.0, l + Dungeon.WALL_T * 2.0), Vector3(0.0, -0.5, 0.0))
	# the prisoners' room in a stone of its own, darker and colder than the
	# palace's (the user's word, 2026-10-23: other walls, another floor)
	var walls := d._wall_mat
	if what == "prison":
		walls = d._wall_mat.duplicate() as ShaderMaterial
		walls.set_shader_parameter("stone", Color(0.40, 0.40, 0.42))
		# Ashen's look (the user's word, 2026-10-25): the blocks even and
		# smooth, the joints soft, no moss; the light and the air do the rest
		walls.set_shader_parameter("photo", 0.25)
		walls.set_shader_parameter("mottle", 0.35)
		walls.set_shader_parameter("moss_amt", 0.0)
		walls.set_shader_parameter("grout", Color(0.31, 0.31, 0.33))
	d._solid(room, walls, Vector3(w + Dungeon.WALL_T * 2.0, 24.0, l + Dungeon.WALL_T * 2.0), Vector3(0.0, -13.0, 0.0), false)
	for side: float in [-1.0, 1.0]:
		d._solid(room, walls, Vector3(Dungeon.WALL_T, h, l + Dungeon.WALL_T * 2.0),
				Vector3(side * (w + Dungeon.WALL_T) * 0.5, h * 0.5, 0.0))
		d._solid(room, walls, Vector3(w + Dungeon.WALL_T * 2.0, h, Dungeon.WALL_T),
				Vector3(0.0, h * 0.5, side * (l + Dungeon.WALL_T) * 0.5))
	d._wall_columns(room, i, w, l, h)
	d._motes(room, w, l, h)
	var spot := RestSpot.new()
	spot.name = "Rest"
	spot.kind = what
	spot._d = d
	room.add_child(spot)
	match what:
		"spring":
			spot._build_spring(room, w, l)
		"prison":
			spot._build_prison(room, w, l, h)


#region The spring
func _build_spring(room: Node3D, w: float, l: float) -> void:
	var stone := _d._trim_mat
	# a fountain of pale stone and gold (the user's word, 2026-10-21: "a good fountain")
	_water = PlaceBuild.fountain(_d, self)["water"]
	# its eight-sided wall stops him: he drinks from the rim
	for k in 8:
		var a := TAU * float(k) / 8.0
		var face := _d._blocker(self, Vector3(4.6, 1.2, 0.5), Vector3(sin(a) * 5.4, 0.6, cos(a) * 5.4))
		face.rotation.y = a
	_light = OmniLight3D.new()
	_light.light_color = Color(0.55, 0.85, 1.0)
	_light.light_energy = 1.8
	_light.omni_range = 14.0
	_light.position = Vector3(0.0, 3.0, 0.0)
	add_child(_light)
	# a shaft of light down on it from above
	var beam := CylinderMesh.new()
	beam.top_radius = 2.4
	beam.bottom_radius = 3.4
	beam.height = 14.0
	beam.cap_top = false
	beam.cap_bottom = false
	var bm := StandardMaterial3D.new()
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	bm.cull_mode = BaseMaterial3D.CULL_DISABLED
	bm.albedo_color = Color(0.5, 0.75, 1.0, 0.07)
	var shaft := _d._deco(self, bm, beam, Vector3(0.0, 7.0, 0.0))
	shaft.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# benches round it, candles at the walls, ivy
	for k in 4:
		var a := PI * 0.25 + TAU * float(k) / 4.0
		var bench := BoxMesh.new()
		bench.size = Vector3(2.4, 0.45, 0.6)
		var b := _d._deco(self, stone, bench, Vector3(sin(a) * 8.6, 0.23, cos(a) * 8.6))
		b.rotation.y = a
	for k in 6:
		var side := -1.0 if k % 2 == 0 else 1.0
		_d._candles(room, Vector3(side * (w * 0.5 - 1.2), 0.0, -l * 0.3 + floorf(float(k) / 2.0) * l * 0.3), k % 2 == 0)
	var sound := _d._loop("stream_loop.wav")
	if sound != null:
		var player := AudioStreamPlayer3D.new()
		player.stream = sound
		player.volume_db = -4.0
		player.unit_size = 6.0
		player.max_distance = 40.0
		player.bus = &"Dungeon"
		player.position = Vector3(0.0, 1.0, 0.0)
		add_child(player)
		player.play()
	var note := Label3D.new()
	note.text = "შედი წყაროში — განიკურნები"
	note.font_size = 48
	note.pixel_size = 0.01
	note.outline_size = 10
	note.modulate = Color(0.75, 0.92, 1.0)
	note.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	note.position = Vector3(0.0, 4.2, 0.0)
	note.name = "Note"
	add_child(note)


func _drink(hero: Player) -> void:
	_used = true
	for h in _d._heroes():
		if h.is_dead:
			continue
		h.heal(h.max_health)
		h.flasks_left = h.flask_count
	var world := Blood.world_of(self)
	if world != null:
		SkillFx.burst(world, hero.global_position + Vector3.UP, Color(0.6, 0.9, 1.0), 90, Vector2(2.0, 6.0),
				Vector3.UP, 180.0, Vector2(0.05, 0.14), Vector3(0, -1.0, 0), 1.3)
	_d._say("წყარომ განგკურნა", 3.0)
	Sfx.play(_d, Dungeon.SND + "portal_open.wav", null, global_position + Vector3.UP, 1.8, -2.0)
	var dim := create_tween()
	dim.tween_method(func(v: float) -> void: _water.set_shader_parameter(&"used", v), 0.0, 0.7, 2.0)
	dim.parallel().tween_property(_light, "light_energy", 0.8, 2.0)
	var note := get_node_or_null(^"Note")
	if note != null:
		note.queue_free()
#endregion


#region The prison
func _build_prison(room: Node3D, w: float, l: float, h: float) -> void:
	OrcSpoils._materials()
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	# three rows of cages down the sides, the far end kept clear for the way on
	var rows: Array[float] = [l * 0.32, l * 0.13, -l * 0.06]
	for k in rows.size():
		for side: float in [-1.0, 1.0]:
			if k == 1 and side > 0.0:
				continue
			OrcSpoils._cage(_d, room, Vector3(side * (w * 0.5 - 3.0), 0.0, rows[k]), rng)
	# the middle one on the right: the living one
	var at := Vector3(w * 0.5 - 3.0, 0.0, rows[1])
	_cage = Node3D.new()
	_cage.position = at
	room.add_child(_cage)
	OrcSpoils._cage_body(_d, _cage, 1.1, 2.4)
	_d._blocker(room, Vector3(2.3, 2.6, 2.3), at + Vector3(0.0, 1.3, 0.0))
	_man = Villager.new()
	_man.variant = 3 + _freed_count()
	_man.look = Villager.freed_look(_freed_count())
	_man.crouched = true
	_cage.add_child(_man)
	_man.set_process(false)
	_name = NAMES[_freed_count() % NAMES.size()]
	var shout := Label3D.new()
	shout.text = "მიშველე!"
	shout.font_size = 52
	shout.pixel_size = 0.01
	shout.outline_size = 10
	shout.modulate = Color(1.0, 0.92, 0.8)
	shout.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	shout.position = Vector3(0.0, 2.9, 0.0)
	shout.name = "Shout"
	_cage.add_child(shout)
	# the orcs' marks on it: blood, their banners (the braziers and the bones
	# in the middle gone: the user's word, 2026-10-23)
	OrcSpoils._wall_banners(_d, room, w, l, h)
	OrcSpoils._blood(_d, room, w, l, 10, rng)
	position = Vector3.ZERO


func _build_cave(room: Node3D, w: float, l: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	var cell := CellCave.build(_d, room, w, l, rng)
	_cage = Node3D.new()
	_cage.position = cell.get("at", Vector3(CellCave.FRONT_X + 1.2, 0.0, 6.75))
	room.add_child(_cage)
	_door = cell.get("door") as Node3D
	# he stands at his door and watches (the user's word, 2026-10-25: not
	# crouched; standing or sitting)
	_man = Villager.new()
	_man.variant = 3 + _freed_count()
	_man.look = Villager.freed_look(_freed_count())
	_man.crouched = false
	_man.rotation.y = -PI * 0.5
	_cage.add_child(_man)
	_name = NAMES[_freed_count() % NAMES.size()]
	var shout := Label3D.new()
	shout.text = "მიშველე!\nგასაღები ციხისმცველს აქვს"
	shout.font_size = 44
	shout.pixel_size = 0.01
	shout.outline_size = 10
	shout.modulate = Color(1.0, 0.92, 0.8)
	shout.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	shout.position = Vector3(-2.6, 3.0, 0.0)
	# (seen over the cell's frame, not cut by it)
	shout.no_depth_test = true
	shout.name = "Shout"
	_cage.add_child(shout)
	position = Vector3.ZERO
	# the jailers are made after the place is built ([method Dungeon._spawn_room]):
	# watched for where the last of them falls, the key dropped there
	_d.room_cleared.connect(_on_cleared)
	get_tree().create_timer(0.5).timeout.connect(_watch_jailers)


func _watch_jailers() -> void:
	if _d == null or _i < 0 or _i >= _d._room_foes.size():
		return
	for body: Variant in _d._room_foes[_i]:
		if is_instance_valid(body) and (body as Node).has_signal(&"died"):
			(body as Node).connect(&"died", _on_jailer_down.bind(body))


func _on_jailer_down(body: Variant) -> void:
	if is_instance_valid(body):
		_last_down = (body as Node3D).global_position


## The place cleared: the jailers' key falls where the last of them fell
## (in the middle if none was here: F1's look round).
func _on_cleared(i: int) -> void:
	if i != _i or _key != null or _used:
		return
	var at := to_local(_last_down) if _last_down != Vector3.INF else Vector3(0.0, 0.0, 4.0)
	at = Vector3(clampf(at.x, -13.5, 13.5), 0.0, clampf(at.z, -21.0, 21.0))
	_key = Node3D.new()
	_key.name = "Key"
	_key.position = at
	add_child(_key)
	var ring := CellCave._piece(_key, "PKey", Vector3(0.0, 0.7, 0.0))
	ring.name = "Ring"
	ring.scale = Vector3.ONE * 1.6
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.8, 0.42)
	glow.light_energy = 1.4
	glow.omni_range = 3.5
	glow.position = Vector3(0.0, 0.8, 0.0)
	glow.set_meta(&"designed_shadow", false)
	_key.add_child(glow)
	var note := Label3D.new()
	note.text = "გასაღები"
	note.font_size = 40
	note.pixel_size = 0.01
	note.outline_size = 10
	note.modulate = Color(1.0, 0.86, 0.5)
	note.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	note.position = Vector3(0.0, 1.6, 0.0)
	_key.add_child(note)
	# it falls from the jailer's belt and spins there
	ring.position.y = 2.4
	var fall := ring.create_tween()
	fall.tween_property(ring, "position:y", 0.7, 0.45).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	var spin := ring.create_tween().set_loops()
	spin.tween_property(ring, "rotation:y", TAU, 2.4).from(0.0)
	var world := Blood.world_of(self)
	if world != null:
		SkillFx.burst(world, _key.global_position + Vector3.UP * 0.7, Color(1.0, 0.82, 0.45), 30, Vector2(1.0, 3.0),
				Vector3.UP, 180.0, Vector2(0.04, 0.1), Vector3(0, -1.5, 0), 0.8)
	_d._say("ციხისმცველებმა გასაღები დააგდეს", 3.0)
	var shout := _cage.get_node_or_null(^"Shout") as Label3D
	if shout != null:
		shout.text = "გასაღები! გამიღე კარი!"


func _take_key(_hero: Player) -> void:
	_has_key = true
	var world := Blood.world_of(self)
	if world != null:
		SkillFx.burst(world, _key.global_position + Vector3.UP * 0.7, Color(1.0, 0.85, 0.5), 24, Vector2(1.0, 2.5),
				Vector3.UP, 180.0, Vector2(0.04, 0.1), Vector3(0, 0.5, 0), 0.7)
	_key.queue_free()
	_key = null
	_d._say("გასაღები შენთანაა — გააღე საკანი", 3.0)


func _freed_count() -> int:
	var game := get_node_or_null(^"/root/Game")
	return (game.get(&"freed") as Array).size() if game != null and game.get(&"freed") != null else 0


func _set_free(hero: Player) -> void:
	_used = true
	var key := "orc_palace:%s" % _name
	var game := get_node_or_null(^"/root/Game")
	if game != null and game.has_method(&"free_prisoner"):
		game.call(&"free_prisoner", key)
	# the cage door: its front bars drop
	var world := Blood.world_of(self)
	if world != null:
		SkillFx.burst(world, _cage.global_position + Vector3.UP * 1.2, Color(1.0, 0.85, 0.5), 50, Vector2(1.5, 4.0),
				Vector3.UP, 180.0, Vector2(0.05, 0.12), Vector3(0, -2.0, 0), 1.0)
	ImpactFx.strike(self, _cage.global_position + Vector3.UP, &"guard")
	# the cave cell's door: unlocked, it swings out into the room
	if _door != null and is_instance_valid(_door):
		var swing := _door.create_tween()
		swing.tween_property(_door, "rotation:y", deg_to_rad(105.0) * signf(_door.position.x), 1.4) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		Sfx.play(_d, Dungeon.SND + "creak.wav", null, _door.global_position + Vector3.UP, 1.0, -2.0)
	var bars := _cage.get_children()
	for node in bars:
		var m := node as MeshInstance3D
		if m != null and m.mesh is CylinderMesh and m.position.x < -0.3:
			var tw := m.create_tween()
			tw.tween_property(m, "position:y", -1.4, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	var shout := _cage.get_node_or_null(^"Shout") as Label3D
	if shout != null:
		var trade := Trades.trade_of(_freed_count() - 1)
		if trade != "":
			# the first three take up a trade in the village ([Trades])
			shout.text = "მადლობა, გმირო! მე %s ვარ.\nსოფელში %s ვიქნები —\nორკის ეშვებით მომაკითხე." \
					% [_name, String(Trades.ALL[trade]["name"])]
		else:
			shout.text = "მადლობა, გმირო! მე %s ვარ.\nეს შენთვის შემოვინახე —\nსოფელში დაგელოდები." % _name
		shout.font_size = 40
		shout.position.y = 3.2
	# what he kept hidden from the orcs: something for the bag
	var loot := LootDrop.of(self)
	if loot != null:
		var out := 2.8 if _door != null else 1.8
		loot.net_loot(_cage.global_position + Vector3(-out, 0.0, 0.0), hero.get_path(), randi())
	_d._say("%s გათავისუფლდა — სოფელში იცხოვრებს" % _name, 3.5)
	# he walks out, and away down the room, and is gone
	get_tree().create_timer(2.5).timeout.connect(_walk_off)


func _walk_off() -> void:
	if not is_instance_valid(_man):
		return
	var out := _man.global_position + Vector3(-3.0, 0.0, 0.0)
	_man.reparent(_d)
	_man.spots = [out, out + Vector3(0.0, 0.0, -6.0)]
	_man.set_process(true)
	# on the man himself, not on this place (it may be gone by then)
	var man := _man
	var t := man.get_tree().create_timer(7.0)
	t.timeout.connect(RestSpot._man_gone.bind(man), CONNECT_ONE_SHOT)


static func _man_gone(man: Node3D) -> void:
	if not is_instance_valid(man):
		return
	var world := Blood.world_of(man)
	if world != null:
		SkillFx.burst(world, man.global_position + Vector3.UP, Color(1.0, 0.9, 0.6), 30, Vector2(1.0, 3.0),
				Vector3.UP, 180.0, Vector2(0.05, 0.12), Vector3(0, 0.5, 0), 1.0)
	man.queue_free()
#endregion


func _process(_delta: float) -> void:
	if _used or _d == null:
		return
	for hero in _d._heroes():
		if hero.is_dead:
			continue
		match kind:
			"spring":
				var gap := Vector2(hero.global_position.x - global_position.x, hero.global_position.z - global_position.z)
				if gap.length() < 6.8:
					_drink(hero)
					return
			"prison":
				if _cage != null and hero.global_position.distance_to(_cage.global_position) < 3.0:
					_set_free(hero)
					return
			"cell_cave":
				if _key != null and Vector2(hero.global_position.x - _key.global_position.x,
						hero.global_position.z - _key.global_position.z).length() < 1.6:
					_take_key(hero)
				if _cage == null or hero.global_position.distance_to(_cage.global_position) > 3.2:
					continue
				if _has_key:
					_set_free(hero)
					return
				# locked: the jailers have its key
				if Time.get_ticks_msec() > _nag_at:
					_nag_at = Time.get_ticks_msec() + 6000
					_d._say("კარი დაკეტილია — გასაღები ციხისმცველს აქვს" if _key == null and not _d.cleared[_i] \
							else "კარი დაკეტილია — აიღე გასაღები", 2.5)
