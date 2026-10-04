class_name Intro
extends Node

## How the story begins.
##
## A new game from the menu (a solo one: the menu's Start leaves word with
## [code]Game.story_pending[/code]) does not drop the hero on the square:
##
## 1. **The wood.** He lies unarmed in a glade high in the wolves' wood,
##    looking at the sky, his feet to the south. Something goes over — never
##    seen, only its shadow across him and the wind of it tearing at the
##    leaves ([DragonFlyby] [code]unseen[/code]). He gets up facing the way
##    it went: "What was that...? A dragon?" The game is his; the village
##    cannot be seen from up here.
## 2. **The sighting.** Coming down the hill, where the trees open
##    ([const SIGHT_Z]), a short film: the village below, burning
##    ([VillageFire]). "The village... it's burning!" Then the fire goes out
##    as he walks down to it.
## 3. **The arrival.** Coming in among the houses, the last film: what the
##    fire left — houses fallen in and black — and Datvi on the square: the
##    village needs timber, strange monsters are in the wood, clear it and
##    he will have arms and experience.
##
## Until he has taken Datvi's job he is unarmed ([member Player.unarmed]: no
## sword, no shield, nothing to strike with), and the wood's creatures keep
## away. Taking it, Datvi gives him his arms and the wood fills again.
## Every film is skipped with Space; the world is then put as it would have
## been at its end. A level loaded any other way (a test, co-op) has no story
## and nothing here runs.

enum Stage { NONE, OPENING, TO_SIGHT, SIGHTING, TO_VILLAGE, ARRIVAL, VILLAGE }

## Where the hero lies (x, z): a glade up on the ridge of the wolves' wood,
## where the trees hide the village.
const LIE_AT := Vector2(70.0, 168.0)
## The village (x, z): where he looks when he is up, where the dragon goes.
const LOOK_AT := Vector2(66.0, 45.0)
## Coming down past this z the trees open on the village: the sighting.
const SIGHT_Z := 134.0
## The wood (x, z, width, depth): its creatures keep away while he is unarmed.
const WOOD := Rect2(-40.0, 90.0, 170.0, 110.0)
## Coming in here (x, z, width, depth) is coming into the village.
const VILLAGE_IN := Rect2(18.0, 8.0, 104.0, 80.0)
## Seconds the fire takes to go out after the sighting.
const GOING_OUT := 22.0
const DATVI := "დათვი მეშეშე"
const HERO_NAMES := {
	&"tariel": "ტარიელი", &"avtandil": "ავთანდილი", &"warrior": "მეომარი",
	&"mage": "ჯადოქარი", &"rogue": "ასასინი",
}
const GET_UP := &"LayToIdle"
const LIE_DOWN := &"IdleToLay"

## Plays even without the menu's word (tests and reels).
@export var force: bool = false
## The films (and the unarmed walk down to the village) — off for now, the
## user's word (2026-10-04): a new game starts on the square of the village
## as the dragon left it, fallen in and black, smoke still going up. The
## films are kept to be put back.
@export var films: bool = false

var stage: Stage = Stage.NONE
var fire: VillageFire
var dragon: DragonFlyby

var _world: Node3D
var _player: Player
var _cut: Cutscene
var _layer: CanvasLayer
var _goal: Label
var _arms_tick: float = 0.0
## Creatures put out of the way: node -> its process mode before.
var _hidden: Dictionary = {}
## The hero's arms, hidden while he is unarmed.
var _arms: Array[MeshInstance3D] = []


func _ready() -> void:
	set_process(false)
	var game := get_node_or_null("/root/Game")
	var pending := force or (game != null and bool(game.get(&"story_pending")))
	if not pending:
		return
	if game != null:
		game.set(&"story_pending", false)
	_world = get_parent() as Node3D
	_begin.call_deferred()


func _begin() -> void:
	# The world dresses its village and spawns the hero in its own _ready,
	# which runs after this one.
	for i in 120:
		await get_tree().process_frame
		_player = _world.call(&"player") as Player if _world.has_method(&"player") else null
		if _player != null and _player.rig != null and i > 4:
			break
	if _player == null:
		return
	fire = VillageFire.new()
	fire.name = "VillageFire"
	_world.add_child(fire)
	var houses := _world.get_node_or_null("Level/Village/Houses") as Node3D
	if houses != null:
		fire.dress(houses)
	fire.restored.connect(_on_restored)
	_build_goal()
	set_process(true)
	if not films:
		_aftermath()
		return
	_player.unarmed = true
	_hide_arms()
	await _opening()


## No films: the village as it is when he walks in at the end of them — the
## fire out, the burnt houses fallen in, smoke going up — and him on the
## square, armed, Datvi's job there to take.
func _aftermath() -> void:
	fire.burn_all()
	fire.die_down(0.01)
	fire.ruin_all()
	stage = Stage.VILLAGE


func _film(title: String) -> Cutscene:
	var cut := Cutscene.new()
	cut.name = title
	add_child(cut)
	return cut


#region The wood
func _opening() -> void:
	stage = Stage.OPENING
	_cut = _film("Opening")
	_cut.black()
	_settle_creatures(true)
	# Down in the grass, his feet to the south (he gets up facing it), and
	# let him settle before the film takes him.
	var lie := _ground(LIE_AT) + Vector3.UP * 0.05
	var away := _ground(LOOK_AT) - lie
	var fwd := Vector3(away.x, 0.0, away.z).normalized()
	var side := fwd.cross(Vector3.UP).normalized()
	_player.global_position = lie
	_player.rotation.y = atan2(-fwd.x, -fwd.z)
	_player.velocity = Vector3.ZERO
	_lie_down()
	for i in 6:
		await get_tree().physics_frame
	_player.global_position = Vector3(lie.x, _player.global_position.y, lie.z)
	_cut.begin(_player)
	_lie_down()
	var p := _player.global_position

	# Down out of the sky over the glade to him.
	_cut.shot(p + Vector3(0.0, 20.0, 0.0) - fwd * 2.0, p + Vector3(0.0, 0.0, 0.5),
			p + side * 2.2 + fwd * 1.0 + Vector3.UP * 3.0, p + Vector3.UP * 0.3, 8.0)
	await _cut.fade(false, 2.2)
	await _cut.wait(4.6)

	# Low beside him. Something goes over: a shadow across him and the grass,
	# the leaves torn off the trees, the ground shaking — and that is all.
	_cut.shot(p + side * 3.4 + Vector3.UP * 1.0 - fwd * 0.6, p + Vector3.UP * 0.25,
			p + side * 3.1 + Vector3.UP * 1.1 - fwd * 0.4, p + Vector3.UP * 0.3, 5.0)
	_launch_dragon(p, fwd)
	var waited := 0.0
	var gusted := false
	while dragon != null and not _cut.skipped and waited < 6.0:
		var off := dragon.global_position - p
		if not gusted and off.dot(fwd) > -14.0:
			gusted = true
			_gust(p, fwd)
		if Vector2(off.x, off.z).length() < 26.0:
			_cut.shake(1.4)
		if off.dot(fwd) > 16.0:
			break
		await get_tree().process_frame
		waited += get_process_delta_time()
	_kindle_later()
	await _cut.wait(0.6)

	# Up off the grass, facing where it went.
	_cut.shot(p + fwd * 3.3 + side * 1.7 + Vector3.UP * 1.0, p + Vector3.UP * 0.5,
			p + fwd * 3.0 + side * 1.5 + Vector3.UP * 1.3, p + Vector3.UP * 1.2, 2.6)
	if not _cut.skipped and _player.rig != null:
		_player.rig.play_clip(GET_UP, 0.12)
	await _cut.wait(2.0)
	# Looking after it, into the trees.
	_cut.shot(p + fwd * 2.4 + side * 0.9 + Vector3.UP * 1.55, p + Vector3.UP * 1.55,
			p + fwd * 2.0 + side * 0.7 + Vector3.UP * 1.6, p + Vector3.UP * 1.6, 6.0)
	await _cut.say(_hero_name(), "ეს რა იყო...?", 2.0)
	await _cut.wait(0.5)
	await _cut.say(_hero_name(), "დრაკონი?!", 1.8)
	await _cut.wait(0.3)

	var skipped := _cut.skipped
	if dragon != null:
		dragon.queue_free()
		dragon = null
	if skipped and _player.rig != null:
		# Up at once (a skip mid-film can leave him lying).
		_player.rig.play_clip(GET_UP, 0.05, 8.0)
	_player.rotation.y = atan2(-fwd.x, -fwd.z)
	_aim_camera(fwd)
	_kindle_now()
	_cut.end()
	_cut = null
	stage = Stage.TO_SIGHT
	_settle_creatures(false)
	_show_goal("გაჰყევი — ტყის ძირისკენ, სამხრეთით")


func _lie_down() -> void:
	if _player.rig != null:
		_player.rig.hold_clip(LIE_DOWN, 0.995)


## Out of the wood behind him, low over him, on down the hill to the village
## and away: never seen, only its shadow on the ground.
func _launch_dragon(p: Vector3, fwd: Vector3) -> void:
	dragon = DragonFlyby.new()
	dragon.name = "Dragon"
	dragon.unseen = true
	_world.add_child(dragon)
	var c := fire.smoke_point()
	var line := PackedVector3Array([
		p - fwd * 130.0 + Vector3(-6.0, 40.0, 0.0),
		p - fwd * 40.0 + Vector3(-2.0, 22.0, 0.0),
		p + Vector3(0.0, 14.0, 0.0),
		p + fwd * 60.0 + Vector3(0.0, 22.0, 0.0),
		Vector3(c.x, c.y + 30.0, c.z),
		Vector3(c.x + 60.0, c.y + 70.0, c.z - 120.0),
	])
	dragon.speed = 40.0
	dragon.fly(line)
	dragon.clip(DragonFlyby.FLAP)
	dragon.arrived.connect(func() -> void:
		if dragon != null:
			dragon.queue_free()
			dragon = null)


## The wind of it: leaves and dust torn up and thrown the way it went.
func _gust(p: Vector3, fwd: Vector3) -> void:
	var from := p - fwd * 4.0 + Vector3.UP * 1.5
	SkillFx.particles(_world, from, {
		"amount": 220, "life": 2.4, "one_shot": true, "explosiveness": 0.6,
		"speed": Vector2(6.0, 15.0), "dir": (fwd + Vector3.UP * 0.25).normalized(), "spread": 28.0,
		"gravity": Vector3(0, -2.0, 0), "damping": 2.0, "size": Vector2(0.06, 0.16),
		"box": Vector3(7.0, 3.0, 7.0), "add": false, "spin": true,
		"colors": [Color(0.32, 0.42, 0.14, 1.0), Color(0.45, 0.36, 0.14, 1.0), Color(0.3, 0.24, 0.1, 0.0)],
	})
	SkillFx.particles(_world, p - fwd * 2.0 + Vector3.UP * 0.3, {
		"amount": 40, "life": 2.0, "one_shot": true, "explosiveness": 0.7,
		"speed": Vector2(3.0, 8.0), "dir": fwd, "spread": 30.0,
		"gravity": Vector3(0, 0.2, 0), "damping": 1.5, "size": Vector2(1.2, 2.6),
		"box": Vector3(5.0, 0.3, 5.0), "add": false, "grow": 0.2,
		"colors": [Color(0.5, 0.45, 0.36, 0.0), Color(0.5, 0.45, 0.36, 0.35), Color(0.55, 0.5, 0.42, 0.0)],
	})


## The roofs catch a few seconds after it has gone over, one after another,
## out of his sight: the smoke is what shows over the trees.
func _kindle_later() -> void:
	var i := 0
	for kind: StringName in fire.kinds():
		var at := 3.0 + i * 0.45
		i += 1
		get_tree().create_timer(at).timeout.connect(func() -> void:
			if fire != null:
				fire.ignite(kind, 2.0))


func _kindle_now() -> void:
	for kind: StringName in fire.kinds():
		if not fire.is_burnt(kind):
			fire.ignite(kind, 2.0)
#endregion


#region The sighting
func _sighting() -> void:
	stage = Stage.SIGHTING
	_hide_goal()
	_cut = _film("Sighting")
	_cut.begin(_player)
	_settle_creatures(true)
	var p := _player.global_position
	var c := fire.smoke_point()
	var to_v := Vector3(c.x - p.x, 0.0, c.z - p.z).normalized()
	var side := to_v.cross(Vector3.UP).normalized()
	_player.rotation.y = atan2(-to_v.x, -to_v.z)
	# Over his shoulder, down through the trees.
	var behind := _clear_eye(p + Vector3.UP * 1.7, -to_v * 2.2 + side * 0.6 + Vector3.UP * 1.0)
	_cut.shot(behind, c + Vector3.UP * 4.0, behind + to_v * 0.5, c + Vector3.UP * 4.0, 3.2)
	await _cut.wait(1.2)
	await _cut.say(_hero_name(), "სოფელი...!", 1.6)
	# The village from the edge of the wood: the roofs alight, the smoke.
	# (High over the open ground between the wall and the wood.)
	var edge := Vector2(c.x + 4.0, c.z + 47.0)
	var eye := _ground(edge) + Vector3.UP * 27.0
	_cut.shot(eye, c + Vector3.UP * 2.0, eye + Vector3(-2.0, -4.0, -7.0), c + Vector3.UP * 1.5, 6.5)
	await _cut.wait(0.6)
	await _cut.say(_hero_name(), "ის იწვის!", 2.4)
	await _cut.wait(1.6)
	_kindle_now()
	_aim_camera(to_v)
	_cut.end()
	_cut = null
	fire.die_down(GOING_OUT)
	stage = Stage.TO_VILLAGE
	_settle_creatures(false)
	_show_goal("ჩადი სოფელში")
#endregion


#region The arrival
func _arrival() -> void:
	stage = Stage.ARRIVAL
	_hide_goal()
	_cut = _film("Arrival")
	_cut.begin(_player)
	await _cut.fade(true, 0.5)
	_settle_creatures(true)
	# Out by now, whatever was left, and fallen in.
	fire.die_down(0.01)
	fire.ruin_all()
	# Long enough in the dark for the last flames in the air to die.
	await _cut.wait(1.2)
	var datvi := _world.get_node_or_null("People/Datvi") as Node3D
	var d := datvi.global_position if datvi != null else Vector3(66.0, 0.0, 40.5)
	# Him a few steps short of Datvi, facing him.
	var stand := _ground(Vector2(d.x - 0.6, d.z - 3.4))
	_player.global_position = stand
	var to_d := d - stand
	_player.rotation.y = atan2(-to_d.x, -to_d.z)
	var c := fire.smoke_point()
	_cut.shot(c + Vector3(44.0, 24.0, -46.0), c + Vector3(0.0, 2.0, 0.0),
			c + Vector3(30.0, 15.0, -36.0), c + Vector3(-2.0, 3.0, 2.0), 9.0)
	await _cut.fade(false, 0.8)
	await _cut.say(DATVI, "შენც დაინახე? ტყის მხრიდან მოფრინდა, ცეცხლი დაგვაყარა და წავიდა.", 4.0)
	await _cut.say(DATVI, "ხალხი გადავარჩინეთ, მაგრამ მარანი და ხუთი სახლი დაინგრა და დაიწვა.", 3.6)
	var mid := (stand + d) * 0.5
	var across := Vector3(to_d.z, 0.0, -to_d.x).normalized()
	_cut.shot(mid + across * 6.4 + Vector3.UP * 2.2, mid + Vector3.UP * 1.4,
			mid + across * 5.6 + Vector3.UP * 2.0, mid + Vector3.UP * 1.4, 11.0)
	await _cut.say(DATVI, "სოფლის ასაღდგენად ხეები დაგვჭირდება... მაგრამ ტყეში უცნაური მონსტრები გამოჩნდნენ.", 4.2)
	await _cut.say(DATVI, "შენ თუ ტყეს გაწმენდ, მე შენ იარაღებს და გამოცდილებას მოგცემ.", 3.8)
	_aim_camera(to_d)
	_cut.end()
	_cut = null
	stage = Stage.VILLAGE
	_settle_creatures(false)
	_show_goal("დაელაპარაკე დათვს (F)")
#endregion


func _process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	# The rig shows its arms again as it pleases (a look worn, a sheath):
	# kept hidden as long as he has none.
	if _player.unarmed:
		_arms_tick -= delta
		if _arms_tick <= 0.0 or stage == Stage.OPENING:
			_arms_tick = 0.25
			_hide_arms()
	var at := Vector2(_player.global_position.x, _player.global_position.z)
	match stage:
		Stage.TO_SIGHT:
			if at.y < SIGHT_Z:
				_sighting()
		Stage.TO_VILLAGE:
			if VILLAGE_IN.has_point(at):
				_arrival()
		Stage.VILLAGE:
			if _player.unarmed:
				var book := get_tree().get_first_node_in_group(&"quest_book") as QuestBook
				if book != null and int(book.state.get(&"wolves", QuestBook.State.OFFERED)) != QuestBook.State.OFFERED:
					_arm()


## Datvi's job taken: his arms, and the wood full again.
func _arm() -> void:
	_player.unarmed = false
	_show_arms()
	_settle_creatures(false)
	_show_goal("დათვმა იარაღი მოგცა — გაწმინდე ტყე")
	get_tree().create_timer(6.0).timeout.connect(_hide_goal)


func _on_restored(kinds: Array[StringName], _job: StringName) -> void:
	var names: Array[String] = []
	for kind: StringName in kinds:
		names.append(String(VillageFire.NAMES.get(kind, "სახლი")))
	_show_goal("სოფელი აღდგება: %s" % " და ".join(names))
	get_tree().create_timer(6.0).timeout.connect(_hide_goal)


#region Out of the way
## Where the creatures should be: none in sight during a film; and the wood's
## kept away while he has nothing to fight them with.
func _settle_creatures(film: bool) -> void:
	var creatures := _world.get_node_or_null("Enemies")
	if creatures == null:
		return
	var unarmed := _player != null and _player.unarmed
	for node in creatures.get_children():
		var body := node as Node3D
		if body == null:
			continue
		var in_wood := WOOD.has_point(Vector2(body.global_position.x, body.global_position.z))
		var away := film or (unarmed and in_wood)
		if away and not _hidden.has(body):
			_hidden[body] = body.process_mode
			body.visible = false
			body.process_mode = Node.PROCESS_MODE_DISABLED
		elif not away and _hidden.has(body):
			body.visible = true
			body.process_mode = _hidden[body]
			_hidden.erase(body)
	for body: Node3D in _hidden.keys():
		if not is_instance_valid(body):
			_hidden.erase(body)


## Is this one of what he carries: a weapon, a shield, a blade in its sheath,
## a bow's string?
static func is_arm(mesh: MeshInstance3D) -> bool:
	var n := String(mesh.name)
	return n.begins_with("ps_w_") or n.begins_with("ps_o_") or n.begins_with("ps_shield") \
			or n.contains("sheathed") or String(mesh.get_parent().name).begins_with("bow_string")


func _hide_arms() -> void:
	if _player == null or _player.rig == null:
		return
	for mesh: MeshInstance3D in _player.rig.find_children("*", "MeshInstance3D", true, false):
		if mesh.visible and is_arm(mesh):
			mesh.visible = false
			if not _arms.has(mesh):
				_arms.append(mesh)


func _show_arms() -> void:
	for mesh in _arms:
		if is_instance_valid(mesh):
			mesh.visible = true
	_arms.clear()
#endregion


#region Little things
## Where to put a camera `off` from `eye` with nothing (a trunk, a bank) in
## between: brought in short of whatever is hit.
func _clear_eye(eye: Vector3, off: Vector3) -> Vector3:
	var space := _world.get_world_3d().direct_space_state
	var ray := PhysicsRayQueryParameters3D.create(eye, eye + off * 1.25, 1)
	ray.exclude = [_player.get_rid()]
	var hit := space.intersect_ray(ray)
	if hit.is_empty():
		return eye + off
	var reach := maxf(eye.distance_to(hit["position"] as Vector3) / 1.25 - 0.35, 0.4)
	return eye + off.normalized() * reach


func _ground(at: Vector2) -> Vector3:
	return Vector3(at.x, Terrain.height(at.x, at.y), at.y)


func _hero_name() -> String:
	var game := get_node_or_null("/root/Game")
	var id: StringName = game.call(&"character") if game != null else &"tariel"
	return String(HERO_NAMES.get(id, String(id).capitalize()))


## The hero's own camera put behind him looking along `toward`, so the film
## does not hand over a view the other way.
func _aim_camera(toward: Vector3) -> void:
	if _player == null:
		return
	var flat := Vector3(toward.x, 0.0, toward.z)
	if flat.length() < 0.01:
		return
	_player.camera_rig.rotation.y = atan2(-flat.x, -flat.z)
	_player.camera_rig.global_position = _player.global_position + Vector3.UP * _player.camera_height


func _build_goal() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 30
	add_child(_layer)
	_goal = Label.new()
	_goal.anchor_left = 0.25
	_goal.anchor_right = 0.75
	_goal.anchor_top = 0.08
	_goal.anchor_bottom = 0.13
	_goal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_goal.add_theme_font_size_override("font_size", 24)
	_goal.add_theme_color_override("font_color", Color(1.0, 0.86, 0.55))
	_goal.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_goal.add_theme_constant_override("outline_size", 7)
	_goal.visible = false
	_layer.add_child(_goal)


func _show_goal(text: String) -> void:
	_goal.text = text
	_goal.visible = true
	_goal.modulate.a = 0.0
	create_tween().tween_property(_goal, "modulate:a", 1.0, 0.6)


func _hide_goal() -> void:
	if _goal == null or not _goal.visible:
		return
	var t := create_tween()
	t.tween_property(_goal, "modulate:a", 0.0, 0.6)
	t.tween_callback(func() -> void: _goal.visible = false)
#endregion
