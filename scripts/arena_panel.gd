class_name ArenaPanel
extends CanvasLayer

## The test arena's board: an empty floor, and on it whatever is wanted to try.
##
## Every creature and boss the game has is a button: pressed, one is called up
## a few paces in front of the hero, facing him, with a patch of ground of its
## own there (its own band, its camp where it stood), so it fights at once and
## never wanders home across the floor. Beside them: the hero's looks, stepped
## through on the spot (the rig's `set_face`), so a new look can be seen moving
## and fighting without going back to the menu; making him whole again; holding
## every creature still to walk round it; and clearing the floor.
##
## By default a creature called up here waits for the hero's first blow before
## it fights back, and the hero loses no health (both can be switched off).
##
## `F1` shows and hides the board. While it is up the mouse is free and the hero
## does not turn with it (`Player.menu_open`), as with the inventory.

## label, scene, and whether it is a boss (drawn in its own column).
## Only Polysplit's Biped Creatures stand here now (CREATURES_PACK.md), each
## with the arms it came with, or none where it came with none
## ([PackCreature]). Most have no clips yet and stand in the pack's poses;
## the skeleton and the skeleton warrior fight ([Brawler], on the clips
## baked onto the pack's skeleton by tools/creature_clips.gd).
## The game's other creatures and bosses are still in the lands.
const ENTRIES: Array[Array] = [
	["Orc", "res://scenes/creatures/orc.tscn", false],
	["Goblin", "res://scenes/creatures/goblin.tscn", false],
	["Ogre", "res://scenes/creatures/ogre.tscn", false],
	["Troll", "res://scenes/creatures/troll.tscn", false],
	["Ghoul", "res://scenes/creatures/ghoul.tscn", false],
	["Golem", "res://scenes/creatures/golem.tscn", false],
	["Zombie (man)", "res://scenes/creatures/zombie_m.tscn", false],
	["Zombie (woman)", "res://scenes/creatures/zombie_f.tscn", false],
	["Skeleton", "res://scenes/enemies/skeleton.tscn", false],
	["Skeleton warrior", "res://scenes/enemies/skeleton_warrior.tscn", false],
	["Skeleton archer", "res://scenes/creatures/skeleton_archer.tscn", false],
	["Skeleton mage", "res://scenes/creatures/skeleton_mage.tscn", false],
	["Skeleton, all in one", "res://scenes/creatures/skeleton_all.tscn", false],
]
## How far in front of the hero a creature is called up, and a boss.
const AHEAD := 7.0
const AHEAD_BOSS := 13.0

var _root: Control
var _look_label: Label
var _count: int = 0
var _frozen: bool = false
## Creatures wait for the hero's first blow before they fight back, and the
## hero loses no health here. Both on by default: this is a place to look.
var _wait_for_blow: bool = true
var _unhurt: bool = true


func _ready() -> void:
	layer = 20
	_root = PanelContainer.new()
	_root.add_theme_stylebox_override("panel", MenuStyle.panel_style(Color(0.08, 0.09, 0.11, 0.88)))
	_root.position = Vector2(16.0, 16.0)
	add_child(_root)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	_root.add_child(column)
	column.add_child(MenuStyle.label("TEST ARENA  (F1)", MenuStyle.BODY_SIZE + 1, MenuStyle.GOLD))

	var looks := HBoxContainer.new()
	looks.add_child(_small("<", func() -> void: _step_look(-1)))
	_look_label = MenuStyle.label("", MenuStyle.BODY_SIZE - 2, MenuStyle.CREAM)
	_look_label.custom_minimum_size = Vector2(150.0, 0.0)
	_look_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	looks.add_child(_look_label)
	looks.add_child(_small(">", func() -> void: _step_look(1)))
	column.add_child(MenuStyle.label("Look", MenuStyle.BODY_SIZE - 3, MenuStyle.GOLD_DIM))
	column.add_child(looks)

	var lists := HBoxContainer.new()
	lists.add_theme_constant_override("separation", 10)
	column.add_child(lists)
	for boss: bool in [false, true]:
		if not ENTRIES.any(func(e: Array) -> bool: return bool(e[2]) == boss):
			continue
		var list := VBoxContainer.new()
		list.add_theme_constant_override("separation", 4)
		list.add_child(MenuStyle.label("Bosses" if boss else "Creatures", MenuStyle.BODY_SIZE - 3, MenuStyle.GOLD_DIM))
		for entry: Array in ENTRIES:
			if bool(entry[2]) == boss and ResourceLoader.exists(String(entry[1])):
				list.add_child(_small(String(entry[0]), _call_up.bind(String(entry[1]), boss)))
		lists.add_child(list)

	column.add_child(MenuStyle.label("The floor", MenuStyle.BODY_SIZE - 3, MenuStyle.GOLD_DIM))
	var tools := HBoxContainer.new()
	tools.add_child(_small("Heal", _heal))
	tools.add_child(_small("Hold still", _toggle_freeze))
	tools.add_child(_small("Clear", _clear))
	column.add_child(tools)
	var rules := HBoxContainer.new()
	rules.add_child(_toggle("Wait for my blow", _wait_for_blow, func(on: bool) -> void: _wait_for_blow = on))
	rules.add_child(_toggle("Can't be hurt", _unhurt, func(on: bool) -> void: _unhurt = on))
	column.add_child(rules)
	_root.visible = false
	_refresh_look.call_deferred()
	_populate.call_deferred()


func _small(text: String, pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", MenuStyle.BODY_SIZE - 2)
	MenuStyle.style_button(button, false, true)
	button.pressed.connect(pressed)
	return button


func _toggle(text: String, on: bool, changed: Callable) -> CheckButton:
	var box := CheckButton.new()
	box.text = text
	box.button_pressed = on
	box.focus_mode = Control.FOCUS_NONE
	box.add_theme_font_size_override("font_size", MenuStyle.BODY_SIZE - 3)
	box.toggled.connect(changed)
	return box


func _process(_delta: float) -> void:
	if _unhurt:
		var hero := _hero()
		if hero != null:
			hero.health = hero.max_health


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F1:
		toggle()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	_root.visible = not _root.visible
	var hero := _hero()
	if hero != null:
		hero.menu_open = _root.visible
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if _root.visible else Input.MOUSE_MODE_CAPTURED
	_refresh_look()


func is_open() -> bool:
	return _root.visible


func _world() -> World:
	return get_parent() as World


func _hero() -> Player:
	var world := _world()
	return world.player() if world != null else null


func _rig() -> SkinnedRig:
	var hero := _hero()
	if hero == null:
		return null
	var found := hero.find_children("*", "SkinnedRig", true, false)
	return found[0] as SkinnedRig if not found.is_empty() else null


## One of every creature and boss stands on the floor from the start, the
## creatures in a ring in front of the hero and the bosses in a wider one
## behind them, each facing the middle, each waiting for his blow.
func _populate() -> void:
	# The hero is spawned a frame after the level is ready.
	for i in 3:
		await get_tree().process_frame
	var kinds := [[], []]
	for entry: Array in ENTRIES:
		if ResourceLoader.exists(String(entry[1])):
			kinds[1 if bool(entry[2]) else 0].append(entry)
	var middle := Vector3(0.0, 0.0, -12.0)
	for ring in 2:
		var list: Array = kinds[ring]
		var radius := 11.0 if ring == 0 else 30.0
		for i in list.size():
			var angle := PI + TAU * (float(i) + 0.5) / float(list.size())
			var at := middle + Vector3(sin(angle), 0.0, cos(angle)) * radius
			call_up(String(list[i][1]), bool(list[i][2]), at)


## Calls a creature up in front of the hero, facing him, on ground of its own
## (or at `where`, facing the arena's middle).
func call_up(path: String, boss: bool = false, where: Variant = null) -> Node3D:
	var hero := _hero()
	var creatures := _world().get_node_or_null("Enemies") if _world() != null else null
	var scene := load(path) as PackedScene
	if hero == null or creatures == null or scene == null:
		return null
	var ahead := -hero.global_transform.basis.z
	ahead.y = 0.0
	ahead = ahead.normalized() if ahead.length() > 0.01 else Vector3.FORWARD
	var at := hero.global_position + ahead * (AHEAD_BOSS if boss else AHEAD)
	if where != null:
		at = where as Vector3
		ahead = (Vector3(0.0, 0.0, -12.0) - at)
		ahead.y = 0.0
		ahead = -ahead.normalized()
	at.y = 0.2
	var body := scene.instantiate() as Node3D
	_count += 1
	body.name = "Arena_%s_%d" % [path.get_file().get_basename(), _count]
	body.set("band", StringName("arena_%d" % _count))
	body.set("camp_centre", Vector3(at.x, 0.0, at.z))
	body.position = at
	body.rotation.y = atan2(-ahead.x, -ahead.z) + PI
	creatures.add_child(body)
	if _frozen:
		_hold(body, true)
	if _wait_for_blow:
		_make_wait(body)
	return body


## Blind until it is struck: its sight put away, given back (and turned on
## the hero) by the first blow that hurts it.
func _make_wait(body: Node) -> void:
	if not "sight_range" in body or not body.has_signal("hurt"):
		return
	var sight: float = body.get("sight_range")
	body.set("sight_range", 0.0)
	body.connect("hurt", func(_remaining: float) -> void:
		if not is_instance_valid(body):
			return
		body.set("sight_range", sight)
		var hero := _hero()
		if hero != null and body.has_method("_rouse"):
			body.call("_rouse", hero), CONNECT_ONE_SHOT)
	body.set_meta(&"arena_sight", sight)


func _call_up(path: String, boss: bool) -> void:
	call_up(path, boss)


func _clear() -> void:
	var creatures := _world().get_node_or_null("Enemies") if _world() != null else null
	if creatures == null:
		return
	for child in creatures.get_children():
		child.queue_free()


func _heal() -> void:
	var hero := _hero()
	if hero != null:
		hero.health = hero.max_health


func _toggle_freeze() -> void:
	_frozen = not _frozen
	var creatures := _world().get_node_or_null("Enemies") if _world() != null else null
	if creatures != null:
		for child in creatures.get_children():
			_hold(child, _frozen)


## Holds a creature still (no thinking, no walking; it keeps breathing).
func _hold(body: Node, still: bool) -> void:
	body.set_physics_process(not still)


func _step_look(by: int) -> void:
	var rig := _rig()
	if rig == null or rig.faces.is_empty():
		return
	rig.set_face(posmod(rig.face + by, rig.faces.size()))
	# Remembered as the menu's pick would be, so the next run starts in it.
	var game := get_node_or_null("/root/Game")
	if game != null:
		game.call("set_face", game.call("character"), rig.face)
	_refresh_look()


func _refresh_look() -> void:
	var rig := _rig()
	if _look_label == null:
		return
	if rig == null or rig.faces.is_empty():
		_look_label.text = "-"
	elif rig.face < rig.face_names.size():
		_look_label.text = rig.face_names[rig.face]
	else:
		_look_label.text = String(rig.faces[rig.face]).capitalize()
