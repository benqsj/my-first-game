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
## `F1` shows and hides the board. While it is up the mouse is free and the hero
## does not turn with it (`Player.menu_open`), as with the inventory.

## label, scene, and whether it is a boss (drawn in its own column).
const ENTRIES: Array[Array] = [
	["Wolf", "res://scenes/enemies/wolf.tscn", false],
	["Golem", "res://scenes/enemies/golem.tscn", false],
	["Imp", "res://scenes/enemies/imp.tscn", false],
	["Puglin", "res://scenes/enemies/puglin.tscn", false],
	["Orc", "res://scenes/enemies/orc.tscn", false],
	["Orc, great axe", "res://scenes/enemies/orc_greataxe.tscn", false],
	["Frog marauder", "res://scenes/enemies/frog.tscn", false],
	["Demon", "res://scenes/enemies/demon.tscn", false],
	["One-eyed ogre", "res://scenes/enemies/ogre.tscn", false],
	["Arkdeva", "res://scenes/enemies/arkdeva.tscn", true],
	["Minotaur", "res://scenes/enemies/minotaur.tscn", true],
	["Centaur", "res://scenes/enemies/centaur.tscn", true],
	["Knight of darkness", "res://scenes/enemies/dark_knight.tscn", true],
	["Dragon: Terror Bringer", "res://scenes/enemies/dragon_terror.tscn", true],
	["Dragon: Nightmare", "res://scenes/enemies/dragon_nightmare.tscn", true],
	["Dragon: Usurper", "res://scenes/enemies/dragon_usurper.tscn", true],
	["Dragon: Soul Eater", "res://scenes/enemies/dragon_souleater.tscn", true],
	# Only to look at (no clips, it does not fight): kept out of the repo.
	["Smaug (look only)", "res://scenes/enemies/smaug_preview.tscn", true],
]
## How far in front of the hero a creature is called up, and a boss.
const AHEAD := 7.0
const AHEAD_BOSS := 13.0

var _root: Control
var _look_label: Label
var _count: int = 0
var _frozen: bool = false


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
	_root.visible = false
	_refresh_look.call_deferred()


func _small(text: String, pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", MenuStyle.BODY_SIZE - 2)
	MenuStyle.style_button(button, false, true)
	button.pressed.connect(pressed)
	return button


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


## Calls a creature up in front of the hero, facing him, on ground of its own.
func call_up(path: String, boss: bool = false) -> Node3D:
	var hero := _hero()
	var creatures := _world().get_node_or_null("Enemies") if _world() != null else null
	var scene := load(path) as PackedScene
	if hero == null or creatures == null or scene == null:
		return null
	var ahead := -hero.global_transform.basis.z
	ahead.y = 0.0
	ahead = ahead.normalized() if ahead.length() > 0.01 else Vector3.FORWARD
	var at := hero.global_position + ahead * (AHEAD_BOSS if boss else AHEAD)
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
	return body


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
