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
var _name: String = ""


## The place `kind` in `room` (its index `i`).
static func build(d: Dungeon, room: Node3D, i: int, what: String) -> void:
	var r := d._room(i)
	var w: float = r["w"]
	var l: float = r["l"]
	var h: float = r["h"]
	d._crag_under(room, w + Dungeon.WALL_T * 2.0, l + Dungeon.WALL_T * 2.0, PalaceVista.DROP + 40.0, -24.0)
	d._solid(room, d._floor_mat(i), Vector3(w + Dungeon.WALL_T * 2.0, 1.0, l + Dungeon.WALL_T * 2.0), Vector3(0.0, -0.5, 0.0))
	d._solid(room, d._wall_mat, Vector3(w + Dungeon.WALL_T * 2.0, 24.0, l + Dungeon.WALL_T * 2.0), Vector3(0.0, -13.0, 0.0), false)
	for side: float in [-1.0, 1.0]:
		d._solid(room, d._wall_mat, Vector3(Dungeon.WALL_T, h, l + Dungeon.WALL_T * 2.0),
				Vector3(side * (w + Dungeon.WALL_T) * 0.5, h * 0.5, 0.0))
		d._solid(room, d._wall_mat, Vector3(w + Dungeon.WALL_T * 2.0, h, Dungeon.WALL_T),
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
	# the orcs' marks on it: bones, blood, their banners, a brazier for light
	OrcSpoils._wall_banners(_d, room, w, l, h)
	OrcSpoils._bone_heap(_d, room, Vector3(-3.0, 0.0, l * 0.1), rng)
	OrcSpoils._blood(_d, room, w, l, 10, rng)
	_d._standing_brazier(room, Vector3(-3.0, 0.0, l * 0.04))
	_d._standing_brazier(room, Vector3(3.0, 0.0, l * 0.22))
	position = Vector3.ZERO


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
		loot.net_loot(_cage.global_position + Vector3(-1.8, 0.0, 0.0), hero.get_path(), randi())
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
