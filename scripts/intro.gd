class_name Intro
extends Node

## How the story begins.
##
## A new game from the menu (a solo one: the menu's Start leaves word with
## [code]Game.story_pending[/code]) does not drop the hero on the square. He
## is lying in the grass on the meadow south of the village, looking at the
## sky, when the dragon comes in low out of the south and goes over him. He
## gets up, turns, and watches it circle the village and set the roofs alight
## ([VillageFire]); then it is gone over the ridge to the north and the film
## hands him the game: follow the smoke.
##
## When he comes in among the houses a second, shorter film plays: Datvi the
## woodcutter on the square, telling him what happened and what is coming
## down out of the wood — and his job (the wolves) is the first of the ones
## that, done, put the village back up house by house.
##
## Either film is skipped with Space; the world is then put as it would have
## been at its end. A level loaded any other way (a test, co-op) has no story
## and nothing here runs.

## Where the hero lies (x, z): on the open meadow south of the village.
const LIE_AT := Vector2(64.0, -44.0)
## Which way he faces while lying (radians; the getting up keeps it).
const LIE_YAW := PI * 0.5
## Coming in here (x, z, width, depth) is coming into the village.
const VILLAGE_IN := Rect2(18.0, 8.0, 104.0, 80.0)
## Seconds after the arrival before the flames die down to a smoulder.
const SMOULDER_AFTER := 150.0
const DATVI := "დათვი მეშეშე"
const HERO_NAMES := {
	&"tariel": "ტარიელი", &"avtandil": "ავთანდილი", &"warrior": "მეომარი",
	&"mage": "ჯადოქარი", &"rogue": "ასასინი",
}
const GET_UP := &"LayToIdle"
const LIE_DOWN := &"IdleToLay"

## Plays even without the menu's word (tests and reels).
@export var force: bool = false
## Leaves the arrival film out (a reel of the opening only).
@export var opening_only: bool = false

## 0 nothing, 1 the opening film, 2 walking to the village, 3 the arrival
## film, 4 the village to rebuild.
var stage: int = 0
var fire: VillageFire
var dragon: DragonFlyby

var _world: Node3D
var _player: Player
var _cut: Cutscene
var _layer: CanvasLayer
var _goal: Label
var _since_arrival: float = 0.0
var _raid_cooldown: float = 0.0
var _raiding: bool = false


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
	await _opening()


#region The opening
func _opening() -> void:
	stage = 1
	_cut = Cutscene.new()
	_cut.name = "Opening"
	add_child(_cut)
	_cut.black()
	# Down in the grass, and let him settle on it before the film takes him.
	var lie := _ground(LIE_AT) + Vector3.UP * 0.05
	_player.global_position = lie
	_player.rotation.y = LIE_YAW
	_player.velocity = Vector3.ZERO
	_lie_down()
	for i in 6:
		await get_tree().physics_frame
	_player.global_position = Vector3(lie.x, _player.global_position.y, lie.z)
	_cut.begin(_player)
	_lie_down()
	var p := _player.global_position
	var head := p + _facing() * 0.9

	# The sky over the meadow, coming down to him.
	_cut.shot(p + Vector3(12.0, 17.0, -7.0), p + Vector3(0.0, 0.0, 1.5),
			p + Vector3(2.8, 3.2, -2.6), p + Vector3(0.0, 0.3, 0.0), 8.5)
	await _cut.fade(false, 2.2)
	await _cut.wait(3.0)
	_launch_dragon(p)
	await _cut.wait(3.3)

	# By his head, looking up the way he is looking: the sky, and something
	# in it coming out of the south.
	_cut.shot(head + Vector3(1.4, 0.55, 0.7), p + Vector3(-6.0, 30.0, -60.0),
			head + Vector3(1.6, 0.7, 0.5), p + Vector3(-6.0, 30.0, -60.0), 2.4)
	await _cut.wait(2.2)
	if dragon != null and not _cut.skipped:
		_cut.shot(head + Vector3(1.6, 0.7, 0.5), Vector3.ZERO, head + Vector3(2.2, 0.9, 0.2), Vector3.ZERO,
				4.0, dragon, 0.0)
		# Until it has gone over him.
		var waited := 0.0
		while dragon != null and not _cut.skipped and waited < 7.0:
			var off := dragon.global_position - p
			if off.z > 6.0:
				break
			if Vector2(off.x, off.z).length() < 22.0:
				_cut.shake(1.3)
			await get_tree().process_frame
			waited += get_process_delta_time()
		await _cut.wait(0.9)

	# Up off the grass, and round to where it went.
	_cut.shot(p + Vector3(3.6, 1.0, -2.4), p + Vector3(0.0, 0.7, 0.4),
			p + Vector3(3.2, 1.25, -2.0), p + Vector3(0.0, 1.1, 0.4), 3.2)
	if not _cut.skipped and _player.rig != null:
		_player.rig.play_clip(GET_UP, 0.12)
	await _cut.wait(1.7)
	var toward := fire.smoke_point() - p
	var yaw := atan2(-toward.x, -toward.z)
	var turn := create_tween()
	turn.tween_property(_player, "rotation:y", _player.rotation.y + wrapf(yaw - _player.rotation.y, -PI, PI), 0.7) \
			.set_trans(Tween.TRANS_SINE)
	await _cut.wait(0.9)

	# Over his shoulder: the village, the dragon over it, the fire.
	var back := -toward.normalized()
	back.y = 0.0
	back = back.normalized()
	var side := back.cross(Vector3.UP).normalized()
	var look := fire.smoke_point() + Vector3.UP * 6.0
	_cut.shot(p + back * 3.4 + side * 1.1 + Vector3.UP * 2.0, look,
			p + back * 2.4 + side * 0.8 + Vector3.UP * 1.9, look, 9.0)
	_raiding = true
	await _cut.wait(3.0)
	await _cut.say(_hero_name(), "სოფელი... ის სოფლისკენ მიფრინავს!", 2.6)
	await _cut.wait(1.4)
	await _cut.say(_hero_name(), "იწვის! სოფელი იწვის!", 2.4)
	await _cut.wait(0.6)
	_end_opening()


func _end_opening() -> void:
	_raiding = false
	var skipped := _cut.skipped
	fire.burn_all()
	if dragon != null and skipped:
		dragon.queue_free()
		dragon = null
	elif dragon != null:
		# Off over the ridge to the north, whatever is left of its line.
		dragon.speed = 30.0
	if skipped and _player.rig != null:
		# Up at once (a skip mid-film can leave him lying).
		_player.rig.play_clip(GET_UP, 0.05, 8.0)
	var toward := fire.smoke_point() - _player.global_position
	_player.rotation.y = atan2(-toward.x, -toward.z)
	_aim_camera(toward)
	_cut.end()
	_cut = null
	stage = 2
	_show_goal("მიჰყევი კვამლს — სოფელი ჩრდილოეთითაა")


func _lie_down() -> void:
	if _player.rig == null:
		return
	var rig := _player.rig
	if rig.has_method(&"hold_clip"):
		rig.call(&"hold_clip", LIE_DOWN, 0.995)


func _launch_dragon(p: Vector3) -> void:
	dragon = DragonFlyby.new()
	dragon.name = "Dragon"
	_world.add_child(dragon)
	var c := fire.smoke_point()
	var line := PackedVector3Array([
		p + Vector3(-30.0, 60.0, -170.0),
		p + Vector3(-10.0, 30.0, -60.0),
		p + Vector3(1.0, 10.0, 2.0),
		p + Vector3(6.0, 22.0, 46.0),
		Vector3(c.x + 30.0, c.y + 26.0, c.z - 12.0),
		Vector3(c.x + 34.0, c.y + 28.0, c.z + 22.0),
		Vector3(c.x + 4.0, c.y + 30.0, c.z + 38.0),
		Vector3(c.x - 34.0, c.y + 28.0, c.z + 14.0),
		Vector3(c.x - 26.0, c.y + 26.0, c.z - 18.0),
		Vector3(c.x + 6.0, c.y + 30.0, c.z - 10.0),
		Vector3(c.x + 14.0, c.y + 50.0, c.z + 90.0),
		Vector3(c.x + 20.0, c.y + 110.0, c.z + 260.0),
	])
	dragon.speed = 27.0
	dragon.fly(line)
	dragon.clip(DragonFlyby.FLAP)
	dragon.arrived.connect(func() -> void:
		if dragon != null:
			dragon.queue_free()
			dragon = null)


## The dragon over the village throws fire at the roofs that are not alight.
func _raid(delta: float) -> void:
	if dragon == null or fire == null:
		return
	var c := fire.smoke_point()
	var over := Vector2(dragon.global_position.x - c.x, dragon.global_position.z - c.z).length() < 62.0
	dragon.speed = move_toward(dragon.speed, 17.0 if over else 27.0, 8.0 * delta)
	if not _raiding or not over:
		return
	_raid_cooldown -= delta
	if _raid_cooldown > 0.0:
		return
	var kind := fire.nearest_unlit(dragon.global_position)
	if kind == &"":
		return
	_raid_cooldown = 1.0
	var target := fire.roof_of(kind)
	dragon.fireball(target, 0.75, func(_at: Vector3) -> void:
		if fire != null:
			fire.ignite(kind, 2.5))
#endregion


#region The arrival
func _arrival() -> void:
	stage = 3
	_hide_goal()
	_cut = Cutscene.new()
	_cut.name = "Arrival"
	add_child(_cut)
	_cut.begin(_player)
	await _cut.fade(true, 0.5)
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
	await _cut.say(DATVI, "შენც დაინახე? სამხრეთიდან მოფრინდა, თავზე გადაგვიარა და სახურავები ჩალასავით აენთო.", 4.2)
	await _cut.say(DATVI, "მარანი, ხუთი სახლი... ხალხი გადავარჩინეთ, დანარჩენი ცეცხლმა წაიღო.", 3.6)
	var mid := (stand + d) * 0.5
	var across := Vector3(to_d.z, 0.0, -to_d.x).normalized()
	_cut.shot(mid + across * 6.4 + Vector3.UP * 2.2, mid + Vector3.UP * 1.4,
			mid + across * 5.6 + Vector3.UP * 2.0, mid + Vector3.UP * 1.4, 8.0)
	await _cut.say(DATVI, "ახლა კვამლის სუნზე ტყიდან მგლები ჩამოდიან.", 3.2)
	await _cut.say(DATVI, "ხელს თუ გამოგვიწვდი, სოფელს თავიდან ავაშენებთ — სახლ-სახლ.", 3.6)
	_aim_camera(to_d)
	_cut.end()
	_cut = null
	stage = 4
	_since_arrival = 0.0
	_show_goal("დაელაპარაკე დათვს (F) — სოფელი აღსადგენია")
#endregion


func _process(delta: float) -> void:
	if dragon != null:
		_raid(delta)
	match stage:
		2:
			if _player != null and is_instance_valid(_player) and not opening_only:
				var at := Vector2(_player.global_position.x, _player.global_position.z)
				if VILLAGE_IN.has_point(at):
					_arrival()
		4:
			_since_arrival += delta
			if _since_arrival > SMOULDER_AFTER and fire != null:
				fire.smoulder()
				_since_arrival = -INF
			var book := get_tree().get_first_node_in_group(&"quest_book") as QuestBook
			if _goal != null and _goal.visible and book != null \
					and int(book.state.get(&"wolves", QuestBook.State.OFFERED)) != QuestBook.State.OFFERED:
				_hide_goal()


func _on_restored(kinds: Array[StringName], _job: StringName) -> void:
	var names: Array[String] = []
	for kind: StringName in kinds:
		names.append(String(VillageFire.NAMES.get(kind, "სახლი")))
	_show_goal("სოფელი აღდგება: %s" % " და ".join(names))
	get_tree().create_timer(6.0).timeout.connect(_hide_goal)


#region Little things
func _ground(at: Vector2) -> Vector3:
	return Vector3(at.x, Terrain.height(at.x, at.y), at.y)


func _facing() -> Vector3:
	return -_player.global_transform.basis.z


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
