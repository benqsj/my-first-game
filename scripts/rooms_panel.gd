class_name RoomsPanel
extends CanvasLayer

## The rooms' board (`F2`; the user's word, 2026-10-24: F1 for the creatures
## only, F2 for the rooms): every room of the orcs' portal to go and look
## round (pressed, he is put at its door; from the open world the dungeon is
## loaded for it), and each room's own looks to switch while standing in it
## (the palace hall's bright afternoon or its storm, its rain).
##
## While it is up the mouse is free and the hero does not turn with it
## (`Player.menu_open`), as with F1's board.

var _root: Control
var _scroll: ScrollContainer
var _column: VBoxContainer
## Whether a room is shown with its creatures.
var _with_foes: bool = false
var _mood_buttons: Dictionary = {}
var _court_buttons: Dictionary = {}


func _ready() -> void:
	layer = 21
	_root = PanelContainer.new()
	_root.add_theme_stylebox_override("panel", MenuStyle.panel_style(Color(0.08, 0.09, 0.11, 0.88)))
	_root.position = Vector2(16.0, 16.0)
	add_child(_root)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_root.add_child(_scroll)
	_column = VBoxContainer.new()
	_column.add_theme_constant_override("separation", 6)
	_scroll.add_child(_column)
	get_viewport().size_changed.connect(_fit_height)
	_column.add_child(MenuStyle.label("ROOMS  (F2)", MenuStyle.BODY_SIZE + 1, MenuStyle.GOLD))

	_column.add_child(MenuStyle.label("Rooms (orc portal)", MenuStyle.BODY_SIZE - 3, MenuStyle.GOLD_DIM))
	var rooms := GridContainer.new()
	rooms.columns = 5
	for place: String in Dungeon.VIEW:
		# by the room's Georgian name, as the game calls it (the user looked
		# for "აკლდამა", 2026-10-26)
		var label := String(Dungeon.PLACES[place]["name"]) if Dungeon.PLACES.has(place) else String(Dungeon.VIEW[place][1])
		rooms.add_child(_small(label, _view_room.bind(place)))
	_column.add_child(rooms)
	_column.add_child(_toggle("With creatures", false, func(on: bool) -> void: _with_foes = on))
	# the places' dangers on and off (2026-10-28; the swamp's poison is gone)
	_column.add_child(_toggle("Falling stones (cave, crypt)", RoomHazards.falls_on, func(on: bool) -> void:
		RoomHazards.falls_on = on
		RoomHazards.refresh(_dungeon())))

	# the palace hall: its weather, bright or stormy, and the storm's rain
	_column.add_child(MenuStyle.label("Palace hall", MenuStyle.BODY_SIZE - 3, MenuStyle.GOLD_DIM))
	var moods := HBoxContainer.new()
	for m: Array in [["sun", "Bright"], ["storm", "Storm"]]:
		var b := _small(String(m[1]), _set_mood.bind(String(m[0])))
		b.toggle_mode = true
		b.button_pressed = TerracePlaces.hall_mood == m[0]
		_mood_buttons[m[0]] = b
		moods.add_child(b)
	_column.add_child(moods)
	_column.add_child(_toggle("Rain (in the storm)", TerracePlaces.hall_rain,
			func(on: bool) -> void: TerracePlaces.set_hall_rain(on)))
	# the lord's court: its looks (2026-10-25; the camp, A, now a place of
	# its own), pressed, he is put in it
	_column.add_child(MenuStyle.label("Lord's court", MenuStyle.BODY_SIZE - 3, MenuStyle.GOLD_DIM))
	var courts := HBoxContainer.new()
	for c: Array in [["c", "C  Mist"], ["b", "B  Royal"]]:
		var b := _small(String(c[1]), _set_court.bind(String(c[0])))
		b.toggle_mode = true
		b.button_pressed = ThroneCourt.current() == c[0]
		_court_buttons[c[0]] = b
		courts.add_child(b)
	_column.add_child(courts)
	_root.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F2:
		toggle()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	_root.visible = not _root.visible
	_fit_height()
	# one board at a time: F1's closes when this one opens
	var other := get_parent().get_node_or_null(^"ArenaPanel") as ArenaPanel if get_parent() != null else null
	if _root.visible and other != null and other.is_open():
		other.toggle()
	var hero := _hero()
	if hero != null:
		hero.menu_open = _root.visible
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if _root.visible else Input.MOUSE_MODE_CAPTURED


func is_open() -> bool:
	return _root.visible


## Into `place` of the orcs' portal: here if this is the dungeon, else the
## dungeon loaded for it. The board closes so he can walk round.
func _view_room(place: String) -> void:
	var rooms := _dungeon()
	if is_open():
		toggle()
	if rooms != null:
		rooms.view_place(place, _with_foes)
		return
	var game := get_node_or_null(^"/root/Game")
	if game == null:
		return
	game.set(&"dungeon_id", 0)
	game.set(&"portal_return", 0)
	game.set(&"view_place", place)
	SceneLoader.go(get_tree(), Portals.DUNGEON)


## The palace hall's weather, at once if he is in it.
func _set_mood(mood: String) -> void:
	TerracePlaces.set_hall_mood(mood)
	for key: String in _mood_buttons:
		(_mood_buttons[key] as Button).set_pressed_no_signal(key == mood)
	var rooms := _dungeon()
	if rooms != null:
		rooms._apply_phase(rooms._phase)


## The lord's court in look `which`, and he is put in it (it is built anew).
func _set_court(which: String) -> void:
	ThroneCourt.look = which
	for key: String in _court_buttons:
		(_court_buttons[key] as Button).set_pressed_no_signal(key == which)
	_view_room("throne")


func _dungeon() -> Dungeon:
	var world := get_parent() as World
	return world.get_node_or_null(^"Level/Rooms") as Dungeon if world != null else null


func _hero() -> Player:
	var world := get_parent() as World
	return world.player() if world != null else null


## As tall as what is on it, but no taller than the screen.
func _fit_height() -> void:
	if _scroll == null or _column == null:
		return
	var room := get_viewport().get_visible_rect().size.y - 48.0
	_scroll.custom_minimum_size.y = minf(_column.get_combined_minimum_size().y, maxf(room, 200.0))
	_root.reset_size()


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
