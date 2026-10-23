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
## ([PackCreature] for those that only stand yet). The melee ones fight
## ([Brawler], scenes/enemies/pack/, tools/make_pack_brawlers.py, on the
## clips baked onto the pack's skeleton by tools/creature_clips.gd); the
## skeleton archer and mage still stand in the pack's poses.
## The game's other creatures and bosses are still in the lands.
const ENTRIES: Array[Array] = [
	["Orc", "res://scenes/enemies/pack/orc.tscn", false],
	["Goblin", "res://scenes/enemies/pack/goblin.tscn", false],
	["Ogre", "res://scenes/enemies/pack/ogre.tscn", false],
	["Troll", "res://scenes/enemies/pack/troll.tscn", false],
	["Ghoul", "res://scenes/enemies/pack/ghoul.tscn", false],
	["Golem", "res://scenes/enemies/pack/golem.tscn", false],
	["Zombie (man)", "res://scenes/enemies/pack/zombie_m.tscn", false],
	["Zombie (woman)", "res://scenes/enemies/pack/zombie_f.tscn", false],
	["Skeleton", "res://scenes/enemies/pack/skeleton.tscn", false],
	["Skeleton warrior", "res://scenes/enemies/pack/skeleton_warrior.tscn", false],
	["Skeleton archer", "res://scenes/enemies/pack/skeleton_archer.tscn", false],
	["Skeleton mage", "res://scenes/enemies/pack/skeleton_mage.tscn", false],
	["Skeleton lord", "res://scenes/enemies/pack/skeleton_lord.tscn", true],
	# (the user's word, 2026-10-23: every creature the game uses up here)
	["Imp", "res://scenes/enemies/imp.tscn", false],
	["Puglin", "res://scenes/enemies/puglin.tscn", false],
	["Wolf", "res://scenes/enemies/wolf.tscn", false],
	["Ghost skull", "res://scenes/enemies/pack/ghost_skull.tscn", false],
	["Dragonet", "res://scenes/enemies/pack/dragonet.tscn", false],
	["Orc skirmisher", "res://scenes/enemies/pack/orc_skirmisher.tscn", false],
	["Minotaur", "res://scenes/enemies/minotaur.tscn", true],
	["Pig butcher", "res://scenes/enemies/pack/pig_butcher.tscn", true],
	["Orc Lord", "res://scenes/enemies/pack/orc_chief.tscn", true],
	["Centaur", "res://scenes/enemies/centaur.tscn", true],
	["Demon", "res://scenes/enemies/demon.tscn", true],
	["Arkdeva", "res://scenes/enemies/arkdeva.tscn", true],
]
## How much faster than its own a creature goes (the user's word, 2026-10-23:
## from F1, a creature's clips and combos sped up): what is called up from
## then on, and at once what stands on the floor ([member Monster.tempo]).
## The first is the one shown at the start.
const TEMPOS: Array[float] = [1.0, 1.1, 1.2, 1.3, 1.4, 1.5, 1.75, 2.0, 0.7, 0.8, 0.9]
## The orc's versions (2026-10-14, the user's word: all of them up from F1):
## its looks (skin, paint, blood: [OrcFighter] `force_*`), the skirmisher, the
## chief, and a pair. Not in the opening ring: its own row on the board.
const ORC_LOOKS: Array[Array] = [
	["Forest, red bands", "res://scenes/enemies/pack/orc.tscn", {"force_skin": 0}],
	["Swamp brown, skull", "res://scenes/enemies/pack/orc.tscn", {"force_skin": 1}],
	["Skirmisher", "res://scenes/enemies/pack/orc_skirmisher.tscn", {}],
	["Chief", "res://scenes/enemies/pack/orc_chief.tscn", {}],
]
## How far in front of the hero a creature is called up, and a boss.
const AHEAD := 7.0
const AHEAD_BOSS := 13.0
## The combo practice (2026-10-10): the big ones with combos made by hand.
const DRILL_KINDS: Array[Array] = [
	["Ogre", "res://scenes/enemies/pack/ogre.tscn"],
	["Troll", "res://scenes/enemies/pack/troll.tscn"],
	["Golem", "res://scenes/enemies/pack/golem.tscn"],
	["Orc", "res://scenes/enemies/pack/orc.tscn"],
]

var _root: Control
## The orc's corner and what is picked in it: version, right, left, make.
var _orc_room: Control
var _orc_pick: Array[int] = [0, 0, 0, 2, 0, 0]
## The second panel, on the right: what is picked, before it is called up
## (the user's word, 2026-10-14), and what its button calls up.
var _preview: CreaturePreview
var _picked: Callable = Callable()
var _look_label: Label
var _count: int = 0
var _frozen: bool = false
## Creatures wait for the hero's first blow before they fight back, and the
## hero loses no health here. Both on by default: this is a place to look.
var _wait_for_blow: bool = true
## One of [constant TEMPOS].
var _tempo: float = 1.0
var _unhurt: bool = true
## The test arena's own board (its four orcs waiting, the hero unhurt, the
## creatures waiting for his first blow); false: the same board in a solo
## game's world (the user's word, 2026-10-15), where it only calls up what is
## picked, every rule off, and clears only what it called up.
@export var in_arena: bool = true
## The combo practice: which of `DRILL_KINDS`, which combo, the one called up
## for it (none: not practising), and the labels showing them.
var _drill_kind: int = 0
var _drill_combo: int = 0
var _drill_body: Node3D = null
var _drill_kind_label: Label
var _drill_combo_label: Label
var _drill_enraged: bool = false
## The board's scroll and what is in it.
var _scroll: ScrollContainer
var _column: VBoxContainer
## The rooms' corner: whether a room is shown with its creatures.
var _rooms_with_foes: bool = false


func _ready() -> void:
	layer = 20
	if not in_arena:
		_wait_for_blow = false
		_unhurt = false
	_root = PanelContainer.new()
	_root.add_theme_stylebox_override("panel", MenuStyle.panel_style(Color(0.08, 0.09, 0.11, 0.88)))
	_root.position = Vector2(16.0, 16.0)
	add_child(_root)
	# the board scrolls when it is taller than the screen (the user's word,
	# 2026-10-23: the bottom of it went under the screen's edge)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_root.add_child(_scroll)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	_scroll.add_child(column)
	_column = column
	get_viewport().size_changed.connect(_fit_height)
	column.add_child(MenuStyle.label("ADMIN MODE  (F1)", MenuStyle.BODY_SIZE + 1, MenuStyle.GOLD))

	var looks := HBoxContainer.new()
	looks.add_child(_small("<", func() -> void: _step_look(-1)))
	_look_label = MenuStyle.label("", MenuStyle.BODY_SIZE - 2, MenuStyle.CREAM)
	_look_label.custom_minimum_size = Vector2(150.0, 0.0)
	_look_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	looks.add_child(_look_label)
	looks.add_child(_small(">", func() -> void: _step_look(1)))
	column.add_child(MenuStyle.label("Look", MenuStyle.BODY_SIZE - 3, MenuStyle.GOLD_DIM))
	column.add_child(looks)

	# Every room of the orcs' portal, to go and look round (the user's word,
	# 2026-10-21: to see them all and say what to change): pressed, he is
	# put at its door; from the open world the dungeon is loaded for it.
	column.add_child(MenuStyle.label("Rooms (orc portal)", MenuStyle.BODY_SIZE - 3, MenuStyle.GOLD_DIM))
	var rooms := GridContainer.new()
	rooms.columns = 7
	for place: String in Dungeon.VIEW:
		rooms.add_child(_small(String(Dungeon.VIEW[place][1]), _view_room.bind(place)))
	column.add_child(rooms)
	column.add_child(_toggle("With creatures", false, func(on: bool) -> void: _rooms_with_foes = on))

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
				if String(entry[0]) == "Orc":
					# the orc opens its own corner: its versions and its arms
					list.add_child(_small("Orc  >", func() -> void:
						_orc_room.visible = not _orc_room.visible
						if _orc_room.visible:
							_preview_orc()))
				else:
					# picked: shown on the right, called up from there
					list.add_child(_small(String(entry[0]), _pick.bind(String(entry[1]), boss, String(entry[0]))))
		lists.add_child(list)
	# the orc's corner (2026-10-14): which version, what it holds in each
	# hand and in what make, then called up as picked
	var orcs := VBoxContainer.new()
	orcs.add_theme_constant_override("separation", 4)
	orcs.visible = false
	_orc_room = orcs
	orcs.add_child(MenuStyle.label("Orc", MenuStyle.BODY_SIZE - 3, MenuStyle.GOLD_DIM))
	var names: Array = ORC_LOOKS.map(func(l: Array) -> String: return String(l[0]))
	orcs.add_child(_stepper("Version", names, func(i: int) -> void: _orc_set(0, i)))
	orcs.add_child(_stepper("Right hand", OrcFighter.RIGHT_ARMS.map(_arm_name),
			func(i: int) -> void: _orc_set(1, i)))
	orcs.add_child(_stepper("Left hand", OrcFighter.LEFT_ARMS.map(_arm_name),
			func(i: int) -> void: _orc_set(2, i)))
	orcs.add_child(_stepper("Make", OrcFighter.ARM_STYLES, func(i: int) -> void: _orc_set(3, i)))
	orcs.add_child(_stepper("Gear", OrcFighter.OUTFITS.keys().map(func(k: String) -> String:
			return "its own" if k == "" else k), func(i: int) -> void: _orc_set(4, i)))
	orcs.add_child(_stepper("Cape", OrcFighter.CAPES.keys().map(func(k: String) -> String:
			return "none" if k == "" else k), func(i: int) -> void: _orc_set(5, i)))
	var go := HBoxContainer.new()
	go.add_child(_small("Call up", _call_up_picked_orc))
	go.add_child(_small("A pair", func() -> void:
		_call_up_picked_orc()
		call_up(String(ORC_LOOKS[2][1]), false, null, ORC_LOOKS[2][2])))
	go.add_child(_small("All versions", _call_up_orcs))
	orcs.add_child(go)
	lists.add_child(orcs)

	column.add_child(MenuStyle.label("The floor", MenuStyle.BODY_SIZE - 3, MenuStyle.GOLD_DIM))
	var tools := HBoxContainer.new()
	tools.add_child(_small("Heal", _heal))
	tools.add_child(_small("Hold still", _toggle_freeze))
	tools.add_child(_small("Clear", _clear))
	tools.add_child(_small("Everyone", _populate_all))
	tools.add_child(_small("The four orcs", _populate))
	column.add_child(tools)
	var rules := HBoxContainer.new()
	rules.add_child(_toggle("Wait for my blow", _wait_for_blow, func(on: bool) -> void: _wait_for_blow = on))
	rules.add_child(_toggle("Can't be hurt", _unhurt, func(on: bool) -> void: _unhurt = on))
	column.add_child(rules)
	column.add_child(_stepper("Speed (clips, combos, paces)", TEMPOS.map(func(t: float) -> String:
			return "x%.2f" % t), _set_tempo))

	# The combo practice: one of the big ones does one of its combos over and
	# over, to learn its timing (when to roll).
	column.add_child(MenuStyle.label("Combo practice", MenuStyle.BODY_SIZE - 3, MenuStyle.GOLD_DIM))
	var kind_row := HBoxContainer.new()
	kind_row.add_child(_small("<", func() -> void: _step_drill_kind(-1)))
	_drill_kind_label = MenuStyle.label("", MenuStyle.BODY_SIZE - 2, MenuStyle.CREAM)
	_drill_kind_label.custom_minimum_size = Vector2(150.0, 0.0)
	_drill_kind_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kind_row.add_child(_drill_kind_label)
	kind_row.add_child(_small(">", func() -> void: _step_drill_kind(1)))
	column.add_child(kind_row)
	var combo_row := HBoxContainer.new()
	combo_row.add_child(_small("<", func() -> void: _step_drill_combo(-1)))
	_drill_combo_label = MenuStyle.label("", MenuStyle.BODY_SIZE - 2, MenuStyle.CREAM)
	_drill_combo_label.custom_minimum_size = Vector2(150.0, 0.0)
	_drill_combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	combo_row.add_child(_drill_combo_label)
	combo_row.add_child(_small(">", func() -> void: _step_drill_combo(1)))
	column.add_child(combo_row)
	var drill_row := HBoxContainer.new()
	drill_row.add_child(_small("Practise", start_drill))
	drill_row.add_child(_small("Stop", stop_drill))
	drill_row.add_child(_toggle("Enraged", false, _set_drill_enraged))
	column.add_child(drill_row)
	_refresh_drill()
	_root.visible = false
	_preview = CreaturePreview.new()
	_preview.visible = false
	_preview.call_up_pressed.connect(func() -> void:
		if _picked.is_valid():
			_picked.call())
	add_child(_preview)
	_refresh_look.call_deferred()
	if in_arena:
		_populate.call_deferred()


## Into `place` of the orcs' portal: here if this is the dungeon, else the
## dungeon loaded for it. The board closes so he can walk round.
func _view_room(place: String) -> void:
	var world := _world()
	var rooms := world.get_node_or_null(^"Level/Rooms") as Dungeon if world != null else null
	if is_open():
		toggle()
	if rooms != null:
		rooms.view_place(place, _rooms_with_foes)
		return
	var game := get_node_or_null(^"/root/Game")
	if game == null:
		return
	game.set(&"dungeon_id", 0)
	game.set(&"portal_return", 0)
	game.set(&"view_place", place)
	SceneLoader.go(get_tree(), Portals.DUNGEON)


## "< value >" under a small heading, calling `picked` with the index.
func _stepper(title: String, values: Array, picked: Callable) -> Control:
	var box := VBoxContainer.new()
	box.add_child(MenuStyle.label(title, MenuStyle.BODY_SIZE - 4, MenuStyle.GOLD_DIM))
	var row := HBoxContainer.new()
	var shown := MenuStyle.label(String(values[0]), MenuStyle.BODY_SIZE - 3, MenuStyle.CREAM)
	shown.custom_minimum_size = Vector2(150.0, 0.0)
	shown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var at := [0]
	var step := func(by: int) -> void:
		at[0] = wrapi(at[0] + by, 0, values.size())
		shown.text = String(values[at[0]])
		picked.call(at[0])
	row.add_child(_small("<", func() -> void: step.call(-1)))
	row.add_child(shown)
	row.add_child(_small(">", func() -> void: step.call(1)))
	box.add_child(row)
	return box


static func _arm_name(id: String) -> String:
	if id == "":
		return "its own falchion"
	if id == "none":
		return "empty"
	return String(PolysplitLook.AW.get(id, {}).get("name", id)).replace(" (NEW)", "").capitalize()


## What is picked in the orc's corner, as it would be set on the orc.
func _orc_props() -> Dictionary:
	var look: Array = ORC_LOOKS[_orc_pick[0]]
	var props: Dictionary = (look[2] as Dictionary).duplicate()
	props["arm_right"] = OrcFighter.RIGHT_ARMS[_orc_pick[1]]
	props["arm_left"] = OrcFighter.LEFT_ARMS[_orc_pick[2]]
	props["arm_style"] = OrcFighter.ARM_STYLES[_orc_pick[3]]
	props["outfit"] = OrcFighter.OUTFITS.keys()[_orc_pick[4]]
	props["cape"] = OrcFighter.CAPES.keys()[_orc_pick[5]]
	return props


## The orc as picked in its corner.
func _call_up_picked_orc() -> void:
	call_up(String(ORC_LOOKS[_orc_pick[0]][1]), false, null, _orc_props())


func _orc_set(which: int, i: int) -> void:
	_orc_pick[which] = i
	_preview_orc()


func _preview_orc() -> void:
	var props := _orc_props()
	var right := String(props["arm_right"])
	var note := "%s · %s" % [_arm_name(right), String(props["arm_style"])]
	if String(props["arm_left"]) not in ["", "none"]:
		note += " · left: " + _arm_name(String(props["arm_left"]))
	if String(props["outfit"]) != "":
		note += " · " + String(props["outfit"])
	if String(props["cape"]) != "":
		note += " · " + String(props["cape"])
	_show_pick(String(ORC_LOOKS[_orc_pick[0]][1]), props, "Orc — " + String(ORC_LOOKS[_orc_pick[0]][0]), note,
			_call_up_picked_orc)


## A creature of the lists picked: shown on the right, called up from there.
func _pick(path: String, boss: bool, title: String) -> void:
	_show_pick(path, {}, title, "", func() -> void: call_up(path, boss))


func _show_pick(path: String, props: Dictionary, title: String, note: String, go: Callable) -> void:
	if _preview == null:
		return
	_picked = go
	_preview.visible = true
	_preview.show_creature(path, props, title, note)
	_place_preview.call_deferred()


## The second panel against the right edge.
func _place_preview() -> void:
	if _preview == null:
		return
	_preview.reset_size()
	var wide := _preview.get_viewport_rect().size.x
	_preview.position = Vector2(wide - _preview.size.x - 16.0, 16.0)


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
	_fit_height()
	if _preview != null:
		_preview.visible = _root.visible and _picked.is_valid()
		if not _root.visible:
			_preview.clear()
			_picked = Callable()
	var hero := _hero()
	if hero != null:
		hero.menu_open = _root.visible
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if _root.visible else Input.MOUSE_MODE_CAPTURED
	_refresh_look()


## As tall as what is on it, but no taller than the screen.
func _fit_height() -> void:
	if _scroll == null or _column == null:
		return
	var room := get_viewport().get_visible_rect().size.y - 48.0
	_scroll.custom_minimum_size.y = minf(_column.get_combined_minimum_size().y, maxf(room, 200.0))
	_root.reset_size()


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
## Two orcs with great swords waiting, one either side of the middle, each
## fighting its own way (the user's word, 2026-10-14: the rest put away —
## called up from F1 when wanted, or all of them with "Everyone").
const ARENA_ORCS := [
	# (the user's word, 2026-10-15) two Warrior Orcs, each its own combos, in
	# bone; the Orc Lord with all of them, bare-headed (no hair: the user did
	# not like it), its great sword black; the raider with its two blades
	["Warrior Orc", "res://scenes/enemies/pack/orc.tscn", Vector3(-10.0, 0.0, -12.0),
			{"title": "Warrior Orc", "arm_right": "greatsword", "arm_style": "bone", "outfit": "Warlord",
			"cape": "Black cape", "force_skin": 0, "combo_set": ["cleave", "power", "turn_cleave", "spin_cleave",
					"lunge", "counter", "trap", "frenzy"]}],
	["Warrior Orc", "res://scenes/enemies/pack/orc.tscn", Vector3(-3.5, 0.0, -12.0),
			{"title": "Warrior Orc", "arm_right": "curvedgreatsword", "arm_style": "bone", "outfit": "Ashen",
			"cape": "Crimson cape", "force_skin": 1, "combo_set": ["heavy_string", "sweep_slam", "ual_crush",
					"ual_spin", "heavy_combo", "lunge", "counter", "trap", "frenzy"]}],
	["Orc Lord", "res://scenes/enemies/pack/orc_chief.tscn", Vector3(3.5, 0.0, -14.0),
			{"title": "Orc Lord", "arm_right": "greatsword", "arm_style": "black", "outfit": "Lord",
			"cape": "Black cape", "force_skin": 0, "force_paint": 0, "combo_rest": Vector2(2.4, 3.4)}],
	["Orc Raider", "res://scenes/enemies/pack/orc.tscn", Vector3(10.0, 0.0, -12.0),
			{"title": "Orc Raider", "force_skin": 0, "outfit": "Rust"}],
]


func _populate() -> void:
	# The hero is spawned a frame after the level is ready.
	for i in 3:
		await get_tree().process_frame
	var hero := _hero()
	for o: Array in ARENA_ORCS:
		var body := call_up(String(o[1]), false, o[2], o[3])
		# turned to him, not to the middle
		if body != null and hero != null:
			var to := hero.global_position - body.global_position
			to.y = 0.0
			if to.length_squared() > 0.01:
				body.rotation.y = atan2(to.x, to.z) + PI


## Every creature and boss in two rings, as the arena once opened.
func _populate_all() -> void:
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
func call_up(path: String, boss: bool = false, where: Variant = null, props: Dictionary = {}) -> Node3D:
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
	# on the floor the hero stands on: the island in the sky is 160 m up
	# (the user's word, 2026-10-23: nothing could be called up there)
	at.y = hero.global_position.y + 0.2
	var body := scene.instantiate() as Node3D
	_count += 1
	body.name = "Arena_%s_%d" % [path.get_file().get_basename(), _count]
	body.set("band", StringName("arena_%d" % _count))
	body.set("camp_centre", Vector3(at.x, at.y - 0.2, at.z))
	body.position = at
	body.rotation.y = atan2(-ahead.x, -ahead.z) + PI
	for key: String in props:
		body.set(StringName(key), props[key])
	if body is Monster:
		body.set_meta(&"own_tempo", (body as Monster).tempo)
		(body as Monster).tempo *= _tempo
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


## Every version of the orc in a row in front of the hero, a pace apart.
func _call_up_orcs() -> void:
	var hero := _hero()
	if hero == null:
		return
	var ahead := -hero.global_transform.basis.z
	ahead.y = 0.0
	ahead = ahead.normalized() if ahead.length() > 0.01 else Vector3.FORWARD
	var side := ahead.cross(Vector3.UP)
	for i in ORC_LOOKS.size():
		var look: Array = ORC_LOOKS[i]
		var at := hero.global_position + ahead * 10.0 + side * (float(i) - float(ORC_LOOKS.size() - 1) * 0.5) * 3.4
		var body := call_up(String(look[1]), false, at, look[2])
		if body != null:
			# facing him, not the arena's middle
			var to := hero.global_position - at
			body.rotation.y = atan2(to.x, to.z) + PI


func _clear() -> void:
	var creatures := _world().get_node_or_null("Enemies") if _world() != null else null
	if creatures == null:
		return
	for child in creatures.get_children():
		# (in the world, only what was called up here)
		if in_arena or String(child.name).begins_with("Arena_"):
			child.queue_free()


## Every creature on the floor (and what is called up next) at `TEMPOS[i]`
## times its own pace.
func _set_tempo(i: int) -> void:
	_tempo = TEMPOS[i]
	var creatures := _world().get_node_or_null("Enemies") if _world() != null else null
	if creatures == null:
		return
	for child in creatures.get_children():
		var m := child as Monster
		if m != null and (in_arena or String(m.name).begins_with("Arena_")):
			if not m.has_meta(&"own_tempo"):
				m.set_meta(&"own_tempo", m.tempo)
			m.set_tempo(float(m.get_meta(&"own_tempo")) * _tempo)


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
	# and not still going the way it was (a shot at it leads by its velocity)
	if still and body is CharacterBody3D:
		(body as CharacterBody3D).velocity = Vector3.ZERO


## The combos of the kind picked, by name (from the one called up; the
## ogre's are its class's).
func _drill_names() -> Array:
	var out: Array = []
	if _drill_body != null and is_instance_valid(_drill_body):
		var list: Variant = OgreFighter.COMBOS if _drill_body is OgreFighter else _drill_body.get(&"_hand_combos")
		if list is Array:
			for c: Dictionary in list:
				out.append(String(c["name"]).replace("_", " "))
	elif _drill_kind == 0:
		for c: Dictionary in OgreFighter.COMBOS:
			out.append(String(c["name"]).replace("_", " "))
	return out


func _refresh_drill() -> void:
	if _drill_kind_label == null:
		return
	_drill_kind_label.text = String(DRILL_KINDS[_drill_kind][0])
	var names := _drill_names()
	if names.is_empty():
		_drill_combo_label.text = "combo %d" % (_drill_combo + 1)
	else:
		_drill_combo = posmod(_drill_combo, names.size())
		_drill_combo_label.text = "%d. %s" % [_drill_combo + 1, names[_drill_combo]]


func _step_drill_kind(by: int) -> void:
	_drill_kind = posmod(_drill_kind + by, DRILL_KINDS.size())
	_drill_combo = 0
	if _drill_body != null and is_instance_valid(_drill_body):
		start_drill()
	_refresh_drill()


func _step_drill_combo(by: int) -> void:
	var names := _drill_names()
	_drill_combo = posmod(_drill_combo + by, maxi(names.size(), 1))
	_apply_drill()
	_refresh_drill()


## The practice begun (again): the floor cleared, the kind called up in front
## of him, fighting at once, set to its combo.
func start_drill() -> void:
	_clear()
	var was := _wait_for_blow
	_wait_for_blow = false
	_drill_body = call_up(String(DRILL_KINDS[_drill_kind][1]), false, null)
	_wait_for_blow = was
	if _drill_body == null:
		return
	# no kneeling in the middle of it: the timing is the point here
	_drill_body.set(&"stance", 0.0)
	_apply_drill()
	_refresh_drill()


func _set_drill_enraged(on: bool) -> void:
	_drill_enraged = on
	_apply_drill()


func stop_drill() -> void:
	if _drill_body != null and is_instance_valid(_drill_body):
		_drill_body.queue_free()
	_drill_body = null
	_refresh_drill()


func _apply_drill() -> void:
	if _drill_body == null or not is_instance_valid(_drill_body):
		return
	_drill_body.set(&"drill_combo", _drill_combo)
	_drill_body.set(&"raging", _drill_enraged)


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
