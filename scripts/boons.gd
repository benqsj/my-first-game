class_name Boons
extends Node

## Blessings for the run through a dungeon (the user's word, 2026-10-21: the
## reward one picks should change how one fights, as in Hades). A place whose
## portal promised "კურთხევა" leaves three lights when it is cleared, each a
## blessing with its name and what it does over it; he walks into the one he
## wants and the other two go out. What he has taken holds till he leaves the
## dungeon, for every hero in it; a list of them stays on the screen's left.
##
## The [Dungeon] makes one of these and hands it every creature it puts up
## ([method watch]) and every hero ([method watch_hero]). What each blessing
## does is done here, on the host, where the hits are decided: through the
## creature's [HurtboxComponent] `struck` signal, its `died`, and the hero's
## `dodge_started`; and two shares on the hero himself ([member Player.dealt_scale],
## [member Player.taken_scale]).

## Each blessing: its name, a line on what it does, its colour.
const ALL := {
	&"burn": {"name": "ცეცხლის ხმალი", "text": "დარტყმა მტერს ცეცხლს უკიდებს", "tint": Color(1.0, 0.45, 0.1)},
	&"sparks": {"name": "ნაპერწკლების ნაბიჯი", "text": "დაძვრენისას ნაპერწკლები\nსცვივა და ახლოს მდგომებს წვავს",
			"tint": Color(1.0, 0.75, 0.25)},
	&"third": {"name": "მესამე დარტყმა", "text": "ყოველი მესამე დარტყმა\nმტერს უკან აგდებს", "tint": Color(0.85, 0.85, 0.95)},
	&"thirst": {"name": "სისხლის წყურვილი", "text": "მოკლული მტერი\nსიცოცხლეს გიბრუნებს", "tint": Color(0.9, 0.12, 0.15)},
	&"chain": {"name": "ელვის ჯაჭვი", "text": "დარტყმა ხანდახან ელვას\nგადასცემს ორ ახლო მტერს", "tint": Color(0.45, 0.7, 1.0)},
	&"frost": {"name": "ყინვის კბილი", "text": "დარტყმა მტერს ყინავს\nდა ანელებს", "tint": Color(0.6, 0.92, 1.0)},
	&"fury": {"name": "მძვინვარება", "text": "რაც ნაკლები სიცოცხლე გაქვს,\nმით უფრო ძლიერად ურტყამ", "tint": Color(1.0, 0.25, 0.1)},
	&"iron": {"name": "რკინის კანი", "text": "მტრის დარტყმები\nმეოთხედით ნაკლებად გტკივა", "tint": Color(0.6, 0.62, 0.68)},
	&"swift": {"name": "ქარის ფეხი", "text": "უფრო სწრაფად დარბიხარ", "tint": Color(0.55, 1.0, 0.65)},
	&"burst": {"name": "სიკვდილის აფეთქება", "text": "მოკლული მტერი ფეთქდება\nდა გვერდით მდგომებს აზიანებს",
			"tint": Color(1.0, 0.5, 0.2)},
	&"second": {"name": "მეორე სუნთქვა", "text": "ერთხელ სიკვდილს გადაურჩები:\nნახევარი სიცოცხლით დგები", "tint": Color(1.0, 0.92, 0.6)},
	&"leech": {"name": "ვამპირის პირი", "text": "დარტყმის ნაწილი\nსიცოცხლედ გიბრუნდება", "tint": Color(0.7, 0.1, 0.35)},
}
## How many lights a blessing place leaves.
const OFFERED := 3
## How many lights are laid to choose from (the village's priest makes it
## four, [Trades]).
var lights: int = OFFERED
## How near he walks to a light to take it.
const TAKE_AT := 1.6

## What each does, how much.
const BURN_SECONDS := 3.0
const BURN_SHARE := 0.22          # of the blow, a second
const SPARK_RADIUS := 3.6
const SPARK_DAMAGE := 34.0
const SPARK_GAP := 0.6            # s between two showers
const THIRD_PUSH := 9.0
const THIRST_SHARE := 0.07        # of his health, a kill
const CHAIN_CHANCE := 0.3
const CHAIN_SHARE := 0.6
const CHAIN_REACH := 8.0
const FROST_SECONDS := 2.5
const FURY_MOST := 0.6            # at the edge of death, this much more
const IRON_TAKEN := 0.75
const SWIFT := 1.15
const BURST_RADIUS := 4.5
const BURST_DAMAGE := 55.0
const LEECH_SHARE := 0.05

## What has been taken so far, in order.
var taken: Array[StringName] = []
## The lights standing now: {node, id}.
var _lights: Array[Dictionary] = []
var _second_used: Dictionary = {}
var _cuts: Dictionary = {}        # hero id -> blade hits landed
var _sparked: Dictionary = {}     # hero id -> when he last threw sparks
var _list: VBoxContainer
var _dungeon: Dungeon
var _rng := RandomNumberGenerator.new()
static var _bolt_mats: Dictionary = {}


func _init(dungeon: Dungeon = null) -> void:
	_dungeon = dungeon
	name = "Boons"
	_rng.randomize()


func has(id: StringName) -> bool:
	return taken.has(id)


## Up to `n` blessings not yet taken, at random.
func offer(n: int = OFFERED) -> Array[StringName]:
	var left: Array[StringName] = []
	for id: StringName in ALL:
		if not taken.has(id):
			left.append(id)
	left.shuffle()
	return left.slice(0, mini(n, left.size()))


#region Taking them
## The lights of three blessings round `at` (a place just cleared).
func lay(at: Vector3, into: Node3D) -> void:
	clear_lights()
	var ids := offer(lights)
	var n := ids.size()
	for k in n:
		# in a shallow arc, far enough apart that their words do not run together
		var across := (float(k) - float(n - 1) * 0.5) * 6.5
		var back := absf(float(k) - float(n - 1) * 0.5) * 1.5
		_lights.append({"node": _light(ids[k], at + Vector3(across, 0.0, back), into), "id": ids[k]})


func clear_lights() -> void:
	for l: Dictionary in _lights:
		if is_instance_valid(l["node"]):
			(l["node"] as Node).queue_free()
	_lights.clear()


func _light(id: StringName, at: Vector3, into: Node3D) -> Node3D:
	var info: Dictionary = ALL[id]
	var tint: Color = info["tint"]
	var holder := Node3D.new()
	holder.name = "Boon_%s" % id
	into.add_child(holder)
	holder.global_position = at
	var orb := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.42
	sphere.height = 0.84
	orb.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	mat.emission_enabled = true
	mat.emission = tint
	mat.emission_energy_multiplier = 3.5
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	orb.material_override = mat
	orb.position = Vector3(0.0, 1.5, 0.0)
	orb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(orb)
	var bob := orb.create_tween().set_loops()
	bob.tween_property(orb, "position:y", 1.75, 1.1).set_trans(Tween.TRANS_SINE)
	bob.tween_property(orb, "position:y", 1.5, 1.1).set_trans(Tween.TRANS_SINE)
	var light := OmniLight3D.new()
	light.light_color = tint
	light.light_energy = 2.2
	light.omni_range = 5.0
	light.position = Vector3(0.0, 1.6, 0.0)
	holder.add_child(light)
	var title := Label3D.new()
	title.text = String(info["name"])
	title.font_size = 60
	title.pixel_size = 0.0075
	title.outline_size = 14
	title.modulate = tint.lerp(Color.WHITE, 0.35)
	title.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	title.no_depth_test = true
	title.position = Vector3(0.0, 2.75, 0.0)
	holder.add_child(title)
	var what := Label3D.new()
	what.text = String(info["text"])
	what.font_size = 36
	what.pixel_size = 0.0075
	what.outline_size = 10
	what.modulate = Color(0.95, 0.92, 0.86)
	what.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	what.no_depth_test = true
	what.position = Vector3(0.0, 2.3, 0.0)
	holder.add_child(what)
	var world := Blood.world_of(into)
	if world != null:
		SkillFx.burst(world, at + Vector3.UP * 1.5, tint, 40, Vector2(1.0, 3.0), Vector3.UP, 180.0,
				Vector2(0.04, 0.1), Vector3(0, 0.5, 0), 1.2)
	return holder


## He walks into a light: that blessing is his, the others go out.
func _process(_delta: float) -> void:
	if _dungeon != null and not _lights.is_empty():
		for hero in _dungeon._heroes():
			if hero.is_dead:
				continue
			for l: Dictionary in _lights:
				var node := l["node"] as Node3D
				if not is_instance_valid(node):
					continue
				var gap := Vector2(hero.global_position.x - node.global_position.x,
						hero.global_position.z - node.global_position.z).length()
				if gap < TAKE_AT:
					take(StringName(l["id"]), node.global_position)
					return
	# fury: what he deals rises as his health falls
	if has(&"fury") and _dungeon != null:
		for hero in _dungeon._heroes():
			var left := clampf(hero.health / maxf(hero.max_health, 1.0), 0.0, 1.0)
			hero.dealt_scale = 1.0 + FURY_MOST * clampf((1.0 - left) / 0.85, 0.0, 1.0)


## `id` taken (at `where`, the light he took it from).
func take(id: StringName, where: Vector3 = Vector3.INF) -> void:
	if taken.has(id) or not ALL.has(id):
		return
	taken.append(id)
	var tint: Color = ALL[id]["tint"]
	clear_lights()
	if _dungeon != null:
		for hero in _dungeon._heroes():
			_put_on(hero, id)
		_dungeon._say("კურთხევა: %s" % String(ALL[id]["name"]), 3.0)
		var world := Blood.world_of(_dungeon)
		if world != null and where != Vector3.INF:
			SkillFx.burst(world, where + Vector3.UP * 1.5, tint, 70, Vector2(2.0, 6.0), Vector3.UP, 180.0,
					Vector2(0.05, 0.14), Vector3(0, -2.0, 0), 1.0)
		Sfx.play(_dungeon, Dungeon.SND + "portal_open.wav", null, where if where != Vector3.INF else Vector3.ZERO,
				1.6, -2.0)
	_redraw_list()


## What a blessing changes on the hero himself, as it is taken.
func _put_on(hero: Player, id: StringName) -> void:
	match id:
		&"iron":
			hero.taken_scale *= IRON_TAKEN
		&"swift":
			hero.run_speed *= SWIFT
#endregion


#region What they do
## A creature put up in the dungeon: its hits and its death are watched.
func watch(body: Node3D) -> void:
	if body == null or body.has_meta(&"boons_watched"):
		return
	body.set_meta(&"boons_watched", true)
	# through its own door, so the creature's answer to a swing stays hooked up
	var box: HurtboxComponent = body.call(&"hurtbox") if body.has_method(&"hurtbox") else HurtboxComponent.of(body)
	if box != null:
		box.struck.connect(_on_struck.bind(body))
	if body.has_signal(&"died"):
		body.connect(&"died", _on_died.bind(body))


## A hero in the dungeon: his dodges watched, and what he has taken put on him.
func watch_hero(hero: Player) -> void:
	if hero.has_meta(&"boons_watched"):
		return
	hero.set_meta(&"boons_watched", true)
	hero.dodge_started.connect(_on_dodge.bind(hero))
	for id in taken:
		_put_on(hero, id)


func _on_struck(hit: HitInfo, body: Node3D) -> void:
	var hero := hit.from as Player
	if hero == null or taken.is_empty() or not is_instance_valid(body):
		return
	if hit.by_blade:
		var key := hero.get_instance_id()
		_cuts[key] = int(_cuts.get(key, 0)) + 1
		if has(&"third") and int(_cuts[key]) % 3 == 0 and body.has_method(&"react"):
			var push := body.global_position - hero.global_position
			push.y = 0.0
			body.call(&"react", &"knock", hero, push.normalized() * THIRD_PUSH)
			_flash(body.global_position + Vector3.UP * 1.2, ALL[&"third"]["tint"])
		if has(&"chain") and _rng.randf() < CHAIN_CHANCE:
			_chain(hero, body, hit.damage * CHAIN_SHARE)
	if has(&"burn"):
		var marks := Afflictions.of(body)
		if marks != null:
			marks.apply(&"burn", BURN_SECONDS, hero, hit.damage * BURN_SHARE)
	if has(&"frost"):
		var marks := Afflictions.of(body)
		if marks != null:
			marks.apply(&"chill", FROST_SECONDS, hero, 0.0)
	if has(&"leech") and not hero.is_dead:
		hero.heal(hit.damage * LEECH_SHARE)


func _on_died(body: Node3D) -> void:
	if _dungeon == null or taken.is_empty() or not is_instance_valid(body):
		return
	if has(&"thirst"):
		for hero in _dungeon._heroes():
			if not hero.is_dead and hero.global_position.distance_to(body.global_position) < 40.0:
				hero.heal(hero.max_health * THIRST_SHARE)
	if has(&"burst"):
		var at := body.global_position + Vector3.UP * 0.8
		var world := Blood.world_of(_dungeon)
		if world != null:
			SkillFx.burst(world, at, ALL[&"burst"]["tint"], 60, Vector2(3.0, 8.0), Vector3.UP, 180.0,
					Vector2(0.06, 0.16), Vector3(0, -4.0, 0), 0.7)
		ImpactFx.thud(_dungeon, at, true)
		var by: Player = _nearest_hero(at)
		for other in _foes_near(at, BURST_RADIUS, body):
			_hurt(other, BURST_DAMAGE * _level_share(), at, by, true)


## The hero threw himself aside: sparks fall where he was and burn the near.
func _on_dodge(_dir: Vector3, hero: Player) -> void:
	if not has(&"sparks") or hero.is_dead:
		return
	var now := Time.get_ticks_msec() / 1000.0
	var key := hero.get_instance_id()
	if now < float(_sparked.get(key, -10.0)) + SPARK_GAP:
		return
	_sparked[key] = now
	var at := hero.global_position + Vector3.UP * 0.6
	var world := Blood.world_of(hero)
	if world != null:
		SkillFx.burst(world, at, ALL[&"sparks"]["tint"], 50, Vector2(2.0, 5.0), Vector3.UP, 120.0,
				Vector2(0.04, 0.1), Vector3(0, -7.0, 0), 0.8)
	for other in _foes_near(at, SPARK_RADIUS, null):
		_hurt(other, SPARK_DAMAGE * _level_share(), at, hero, true)
		var marks := Afflictions.of(other)
		if marks != null:
			marks.apply(&"burn", 1.5, hero, SPARK_DAMAGE * 0.15)


## Lightning from `from` to up to two others near it.
func _chain(hero: Player, from: Node3D, damage: float) -> void:
	var near := _foes_near(from.global_position, CHAIN_REACH, from)
	near.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		return a.global_position.distance_squared_to(from.global_position) \
				< b.global_position.distance_squared_to(from.global_position))
	var last := from.global_position + Vector3.UP * 1.2
	for k in mini(2, near.size()):
		var other: Node3D = near[k]
		var to := other.global_position + Vector3.UP * 1.2
		_bolt(last, to)
		_hurt(other, damage, to, hero, true)
		last = to


## Who is it the hero is likely to be: the one nearest.
func _nearest_hero(at: Vector3) -> Player:
	return _dungeon._nearest_hero(at) if _dungeon != null else null


## The living creatures within `radius` of `at`, not `but`.
func _foes_near(at: Vector3, radius: float, but: Node3D) -> Array[Node3D]:
	var out: Array[Node3D] = []
	if _dungeon == null:
		return out
	for item: Variant in _dungeon._alive:
		if not is_instance_valid(item):
			continue
		var body := item as Node3D
		if body == but or bool(body.get(&"is_dead")) or not body.visible:
			continue
		if body.global_position.distance_to(at) <= radius:
			out.append(body)
	return out


func _hurt(body: Node3D, damage: float, at: Vector3, by: Player, magic: bool) -> void:
	if body.has_method(&"take_hit"):
		var blow := body.global_position - at
		blow.y = 0.3
		body.call(&"take_hit", damage, body.global_position + Vector3.UP * 1.1, blow.normalized(), false, true, by, magic)


## Deeper places' creatures are hardier: what a blessing's own damage is worth
## grows with the place's level.
func _level_share() -> float:
	if _dungeon == null or _dungeon.current < 0:
		return 1.0
	return 1.0 + 0.18 * float(int(_dungeon._room(_dungeon.current).get("lv", 1)) - 1)


func _flash(at: Vector3, tint: Color) -> void:
	var world := Blood.world_of(_dungeon) if _dungeon != null else null
	if world != null:
		SkillFx.burst(world, at, tint, 24, Vector2(2.0, 5.0), Vector3.UP, 180.0, Vector2(0.04, 0.1),
				Vector3(0, -3.0, 0), 0.4)


## A crooked bolt of light from `a` to `b` in `tint`, gone in a moment.
func _bolt(a: Vector3, b: Vector3, tint: Color = Color(0.75, 0.9, 1.5)) -> void:
	if _dungeon == null:
		return
	var key := tint.to_html()
	var mat: StandardMaterial3D = _bolt_mats.get(key) as StandardMaterial3D
	if mat == null:
		mat = StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = tint
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.disable_receive_shadows = true
		_bolt_mats[key] = mat
	var holder := Node3D.new()
	_dungeon.add_child(holder)
	var points: Array[Vector3] = [a]
	var n := 6
	for k in range(1, n):
		var p := a.lerp(b, float(k) / float(n))
		p += Vector3(_rng.randf_range(-0.35, 0.35), _rng.randf_range(-0.35, 0.35), _rng.randf_range(-0.35, 0.35))
		points.append(p)
	points.append(b)
	for k in points.size() - 1:
		var p0: Vector3 = points[k]
		var p1: Vector3 = points[k + 1]
		var seg := CylinderMesh.new()
		seg.top_radius = 0.018
		seg.bottom_radius = 0.018
		seg.height = p0.distance_to(p1)
		seg.radial_segments = 4
		seg.rings = 1
		var m := MeshInstance3D.new()
		m.mesh = seg
		m.material_override = mat
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(m)
		var mid := (p0 + p1) * 0.5
		var up := (p1 - p0).normalized()
		var side := up.cross(Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
		m.global_transform = Transform3D(Basis(side, up, side.cross(up)), mid)
	var light := OmniLight3D.new()
	light.light_color = Color(tint.r, tint.g, tint.b).clamp() if tint.r <= 1.0 else Color(0.6, 0.75, 1.0)
	light.light_energy = 1.6
	light.omni_range = 6.0
	holder.add_child(light)
	light.global_position = (a + b) * 0.5
	ImpactFx.strike(_dungeon, b, &"guard")
	get_tree().create_timer(0.18).timeout.connect(holder.queue_free)
#endregion


## The hero would die: the second breath, once, if he has it.
func save_from_death(hero: Player) -> bool:
	if not has(&"second") or _second_used.has(hero.get_instance_id()):
		return false
	_second_used[hero.get_instance_id()] = true
	return true


#region The list on the screen
func show_list(layer: CanvasLayer) -> void:
	_list = VBoxContainer.new()
	_list.anchor_left = 0.0
	_list.anchor_top = 0.5
	_list.offset_left = 18
	_list.offset_top = -120
	_list.add_theme_constant_override("separation", 4)
	_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_list)
	_redraw_list()


func _redraw_list() -> void:
	if _list == null:
		return
	for child in _list.get_children():
		child.queue_free()
	if taken.is_empty():
		return
	var head := Label.new()
	head.text = "კურთხევები"
	head.add_theme_font_size_override("font_size", 22)
	head.add_theme_color_override("font_color", Color(0.95, 0.85, 0.6))
	head.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	head.add_theme_constant_override("outline_size", 6)
	_list.add_child(head)
	for id in taken:
		var row := Label.new()
		row.text = "◆ " + String(ALL[id]["name"])
		row.add_theme_font_size_override("font_size", 19)
		row.add_theme_color_override("font_color", (ALL[id]["tint"] as Color).lerp(Color.WHITE, 0.3))
		row.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		row.add_theme_constant_override("outline_size", 6)
		_list.add_child(row)
#endregion
