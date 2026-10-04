class_name Intro
extends Node

## How the story begins.
##
## A new game from the menu (a solo one: the menu's Start leaves word with
## [code]Game.story_pending[/code]) does not drop the hero on the square. He
## is lying unarmed in a glade of the wolves' wood on the hill north of the
## village, his feet towards it, looking at the sky. The dragon comes out of
## the wood behind him: we never see it close, only its shadow going over
## him and the wind of it. He gets up facing the village, and from there we
## watch it — small, far off — rain fire on the roofs in a few quick passes
## and be gone ([VillageFire]). Then the film hands him the game: follow the
## smoke. Every creature is kept out of sight for the film, and the ones near
## the glade stay away until he has reached the village.
##
## When he comes in among the houses a second, shorter film plays: Datvi the
## woodcutter on the square tells him what happened, that the village needs
## timber to rebuild, and that something strange has come into the wood —
## clear it, and he will have arms and what Datvi can teach him.
##
## Either film is skipped with Space; the world is then put as it would have
## been at its end. A level loaded any other way (a test, co-op) has no story
## and nothing here runs.

## Where the hero lies (x, z): the big glade in the wolves' wood, from which
## the village shows between the trees.
const LIE_AT := Vector2(46.0, 128.0)
## What he faces when he is up: the village.
const LOOK_AT := Vector2(66.0, 45.0)
## Creatures this near the glade stay away until he is in the village.
const QUIET_ROUND := 48.0
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
## Creatures put out of the way: node -> its process mode before.
var _hidden: Dictionary = {}
## The hero's arms, hidden while the film has him lying unarmed.
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
	await _opening()


#region The opening
func _opening() -> void:
	stage = 1
	_cut = Cutscene.new()
	_cut.name = "Opening"
	add_child(_cut)
	_cut.black()
	_hide_creatures()
	_hide_arms()
	# Down in the grass, his feet to the village (he gets up facing it), and
	# let him settle before the film takes him.
	var lie := _ground(LIE_AT) + Vector3.UP * 0.05
	var to_village := _ground(LOOK_AT) - lie
	_player.global_position = lie
	_player.rotation.y = atan2(-to_village.x, -to_village.z)
	_player.velocity = Vector3.ZERO
	_lie_down()
	for i in 6:
		await get_tree().physics_frame
	_player.global_position = Vector3(lie.x, _player.global_position.y, lie.z)
	_cut.begin(_player)
	_lie_down()
	var p := _player.global_position
	var fwd := Vector3(to_village.x, 0.0, to_village.z).normalized()
	var side := fwd.cross(Vector3.UP).normalized()

	# Down out of the sky over the glade to him.
	_cut.shot(p + fwd * 5.0 + Vector3(0.0, 21.0, 0.0), p + Vector3(0.0, 0.0, 0.5),
			p + side * 2.2 + fwd * 1.0 + Vector3.UP * 3.0, p + Vector3.UP * 0.3, 8.0)
	await _cut.fade(false, 2.2)
	await _cut.wait(4.6)

	# Low beside him. Something goes over: its shadow across him and the
	# grass, the ground shaking with the wind of it — and that is all of it.
	_cut.shot(p + side * 3.4 + Vector3.UP * 1.0 - fwd * 0.6, p + Vector3.UP * 0.25,
			p + side * 3.1 + Vector3.UP * 1.1 - fwd * 0.4, p + Vector3.UP * 0.3, 5.0)
	_launch_dragon(p, fwd)
	var waited := 0.0
	while dragon != null and not _cut.skipped and waited < 6.0:
		var off := dragon.global_position - p
		if off.dot(fwd) > 10.0:
			break
		if Vector2(off.x, off.z).length() < 26.0:
			_cut.shake(1.4)
		await get_tree().process_frame
		waited += get_process_delta_time()
	await _cut.wait(0.5)

	# Up off the grass, already facing where it went.
	_cut.shot(p + fwd * 3.3 + side * 1.7 + Vector3.UP * 1.0, p + Vector3.UP * 0.5,
			p + fwd * 3.0 + side * 1.5 + Vector3.UP * 1.3, p + Vector3.UP * 1.2, 2.6)
	if not _cut.skipped and _player.rig != null:
		_player.rig.play_clip(GET_UP, 0.12)
	await _cut.wait(2.0)

	# Over his shoulder: the village down the hill, the dragon small over it,
	# fire coming down on the roofs.
	var look := fire.smoke_point() + Vector3.UP * 5.0
	_cut.shot(p - fwd * 2.6 + side * 0.9 + Vector3.UP * 1.9, look,
			p - fwd * 1.9 + side * 0.7 + Vector3.UP * 1.8, look, 8.0)
	_raiding = true
	await _cut.wait(2.6)
	await _cut.say(_hero_name(), "სოფელი...!", 1.8)
	await _cut.wait(1.4)
	await _cut.say(_hero_name(), "იწვის! სოფელი იწვის!", 2.4)
	await _cut.wait(0.4)
	_end_opening()


func _end_opening() -> void:
	_raiding = false
	var skipped := _cut.skipped
	fire.burn_all()
	if dragon != null:
		dragon.queue_free()
		dragon = null
	if skipped and _player.rig != null:
		# Up at once (a skip mid-film can leave him lying).
		_player.rig.play_clip(GET_UP, 0.05, 8.0)
	var toward := fire.smoke_point() - _player.global_position
	_player.rotation.y = atan2(-toward.x, -toward.z)
	_aim_camera(toward)
	_show_arms()
	# Everything back but what is round the glade: the walk down is his own.
	_show_creatures(QUIET_ROUND)
	_cut.end()
	_cut = null
	stage = 2
	_show_goal("მიჰყევი კვამლს — სოფელი გორის ძირშია")


func _lie_down() -> void:
	if _player.rig != null:
		_player.rig.hold_clip(LIE_DOWN, 0.995)


## Out of the wood behind him, over him low and fast, down to the village and
## round it once, and away to the south-east.
func _launch_dragon(p: Vector3, fwd: Vector3) -> void:
	dragon = DragonFlyby.new()
	dragon.name = "Dragon"
	_world.add_child(dragon)
	var c := fire.smoke_point()
	var line := PackedVector3Array([
		p - fwd * 130.0 + Vector3(-6.0, 42.0, 0.0),
		p - fwd * 40.0 + Vector3(-2.0, 24.0, 0.0),
		p + Vector3(0.0, 15.0, 0.0),
		p + fwd * 45.0 + Vector3(0.0, 20.0, 0.0),
		Vector3(c.x - 8.0, c.y + 28.0, c.z + 26.0),
		Vector3(c.x + 26.0, c.y + 25.0, c.z + 4.0),
		Vector3(c.x + 6.0, c.y + 24.0, c.z - 24.0),
		Vector3(c.x - 26.0, c.y + 26.0, c.z - 4.0),
		Vector3(c.x - 4.0, c.y + 30.0, c.z + 18.0),
		Vector3(c.x + 70.0, c.y + 60.0, c.z - 70.0),
		Vector3(c.x + 200.0, c.y + 130.0, c.z - 240.0),
	])
	dragon.speed = 42.0
	dragon.fly(line)
	dragon.clip(DragonFlyby.FLAP)
	dragon.arrived.connect(func() -> void:
		if dragon != null:
			dragon.queue_free()
			dragon = null)


## Over the village it slows and throws fire, quickly, here and there.
func _raid(delta: float) -> void:
	if dragon == null or fire == null:
		return
	var c := fire.smoke_point()
	var over := Vector2(dragon.global_position.x - c.x, dragon.global_position.z - c.z).length() < 48.0
	dragon.speed = move_toward(dragon.speed, 24.0 if over else 42.0, 20.0 * delta)
	if not _raiding or not over:
		return
	_raid_cooldown -= delta
	if _raid_cooldown > 0.0:
		return
	var kind := fire.nearest_unlit(dragon.global_position)
	if kind == &"":
		return
	_raid_cooldown = 0.32
	var target := fire.roof_of(kind)
	dragon.fireball(target, 0.5, func(_at: Vector3) -> void:
		if fire != null:
			fire.ignite(kind, 2.0))
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
	_hide_creatures()
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
	await _cut.say(DATVI, "ხალხი გადავარჩინეთ, მაგრამ მარანი და ხუთი სახლი ნაცარში წევს.", 3.6)
	var mid := (stand + d) * 0.5
	var across := Vector3(to_d.z, 0.0, -to_d.x).normalized()
	_cut.shot(mid + across * 6.4 + Vector3.UP * 2.2, mid + Vector3.UP * 1.4,
			mid + across * 5.6 + Vector3.UP * 2.0, mid + Vector3.UP * 1.4, 11.0)
	await _cut.say(DATVI, "სოფლის ასაღდგენად ხეები დაგვჭირდება... მაგრამ ტყეში უცნაური მონსტრები გამოჩნდნენ.", 4.2)
	await _cut.say(DATVI, "შენ თუ ტყეს გაწმენდ, მე შენ იარაღებს და გამოცდილებას მოგცემ.", 3.8)
	_aim_camera(to_d)
	_show_creatures(0.0)
	_cut.end()
	_cut = null
	stage = 4
	_since_arrival = 0.0
	_show_goal("დაელაპარაკე დათვს (F)")
#endregion


func _process(delta: float) -> void:
	if dragon != null:
		_raid(delta)
	match stage:
		1:
			# The rig shows its arms again as it pleases (a look worn, a
			# sheath): kept hidden as long as he lies there.
			_hide_arms()
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


#region Out of the way
## Every creature out of sight and still.
func _hide_creatures() -> void:
	var creatures := _world.get_node_or_null("Enemies")
	if creatures == null:
		return
	for node in creatures.get_children():
		var body := node as Node3D
		if body == null or _hidden.has(body):
			continue
		_hidden[body] = body.process_mode
		body.visible = false
		body.process_mode = Node.PROCESS_MODE_DISABLED


## Back as they were, all but those within `keep_away` of the glade (none
## kept away when it is 0).
func _show_creatures(keep_away: float) -> void:
	var glade := Vector2(LIE_AT.x, LIE_AT.y)
	for body: Node3D in _hidden.keys():
		if not is_instance_valid(body):
			_hidden.erase(body)
			continue
		if keep_away > 0.0 and Vector2(body.global_position.x, body.global_position.z).distance_to(glade) < keep_away:
			continue
		body.visible = true
		body.process_mode = _hidden[body]
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
