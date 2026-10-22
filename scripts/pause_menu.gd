extends CanvasLayer

## The menu that comes up mid-game: carry on, change a setting, or leave.
##
## It lives in the level rather than in the front menu, because it has to be
## reachable from inside a game and has to be able to stop one. `Escape` opens
## it; the tree is paused while it is up, so the world holds still underneath.
##
## Same widgets and the same look as the front menu — both come out of
## [MenuStyle], so there is one place to change either.

const MENU := "res://scenes/ui/main_menu.tscn"

enum Page { ROOT, SETTINGS, CONTROLS }

var _page: Page = Page.ROOT
var _pages: Dictionary = {}
var _graphics_buttons: Dictionary = {}
var _game: Node
var _screen: Control


func _ready() -> void:
	# The pause menu is the one thing that has to keep running while the game
	# does not, and the one thing that must never be hidden behind the world.
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	_game = get_node_or_null("/root/Game")

	_screen = Control.new()
	_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_screen)

	# A wash over the game rather than the menu's own ground: the fight should
	# still be visible behind it, dimmed.
	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(MenuStyle.SLATE_DEEP, 0.78)
	_screen.add_child(shade)

	for page: Page in [Page.ROOT, Page.SETTINGS, Page.CONTROLS]:
		var built := _build(page)
		_screen.add_child(built)
		_pages[page] = built
	_screen.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	if not _screen.visible:
		open()
	elif _page == Page.SETTINGS:
		_show(Page.ROOT)
	else:
		resume()


#region Opening and closing
## Stops the game and puts the menu up.
##
## **Online it does not stop the game.** A paused tree stops that peer's
## `MultiplayerSynchronizer`s and its ENet polling, so one player opening a menu
## would freeze their knight in everyone else's window and eventually time the
## connection out. Nobody else agreed to be paused. What the menu keeps either
## way is the mouse: releasing it is the only way out of capture, and that half
## has to work whether or not the world is holding still.
func open() -> void:
	_screen.visible = true
	_show(Page.ROOT)
	get_tree().paused = not _online()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## Hands the game back.
func resume() -> void:
	_screen.visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Ends the game and goes back to the front. Unpausing first, because a tree
## that changes scene while paused loads the next one paused as well — and
## hanging up, because leaving a game means leaving the people in it.
func quit_to_menu() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var net := get_node_or_null("/root/Net")
	if net != null:
		net.call("leave")
	SceneLoader.go(get_tree(), MENU)


## True while there are other people in the game to consider.
func _online() -> bool:
	var net := get_node_or_null("/root/Net")
	return net != null and bool(net.call("is_online"))
#endregion


#region Pages
func _build(page: Page) -> Control:
	if page == Page.SETTINGS:
		return _build_settings()
	if page == Page.CONTROLS:
		return _build_controls()
	return _build_root()


func _build_root() -> Control:
	var column := MenuStyle.page_column()
	column.add_child(MenuStyle.heading("PAUSED"))
	var buttons := MenuStyle.button_column()
	buttons.add_child(MenuStyle.button("RESUME", resume))
	buttons.add_child(MenuStyle.button("SETTINGS", func() -> void: _show(Page.SETTINGS)))
	buttons.add_child(MenuStyle.button("CONTROLS", func() -> void: _show(Page.CONTROLS)))
	buttons.add_child(MenuStyle.button("EXIT TO MAIN MENU", quit_to_menu, true))
	column.add_child(buttons)
	return column


func _build_settings() -> Control:
	var column := MenuStyle.page_column()
	column.add_child(MenuStyle.heading("SETTINGS"))

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	row.add_child(MenuStyle.label("GRAPHICS", MenuStyle.BUTTON_SIZE, MenuStyle.CREAM))
	for level: Graphics.Level in Graphics.ORDER:
		var button := MenuStyle.button(Graphics.label(level),
				func() -> void: _set_graphics(level))
		button.custom_minimum_size = Vector2(160.0, MenuStyle.BUTTON_HEIGHT)
		_graphics_buttons[level] = button
		row.add_child(button)
	column.add_child(row)

	# how loud, here too: it is in the middle of a fight that one wants it
	for which: String in ["volume", "music"]:
		var sound_row := HBoxContainer.new()
		sound_row.alignment = BoxContainer.ALIGNMENT_CENTER
		sound_row.add_theme_constant_override("separation", 14)
		var name_label := MenuStyle.label("SOUND" if which == "volume" else "MUSIC", MenuStyle.BUTTON_SIZE, MenuStyle.CREAM)
		name_label.custom_minimum_size = Vector2(120.0, 0.0)
		sound_row.add_child(name_label)
		var slider := HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.05
		slider.custom_minimum_size = Vector2(380.0, 28.0)
		slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if _game != null:
			slider.value = float(_game.call(&"music_volume") if which == "music" else _game.call(&"volume"))
		slider.value_changed.connect(func(v: float) -> void:
			if _game != null:
				_game.call(&"set_volume", which, v, false))
		slider.drag_ended.connect(func(_changed: bool) -> void:
			if _game != null:
				_game.call(&"set_volume", which, slider.value, true))
		sound_row.add_child(slider)
		column.add_child(sound_row)

	var buttons := MenuStyle.button_column()
	buttons.add_child(MenuStyle.button("BACK", func() -> void: _show(Page.ROOT), true))
	column.add_child(buttons)
	return column


func _build_controls() -> Control:
	var column := MenuStyle.page_column()
	column.add_child(MenuStyle.heading("CONTROLS"))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 40)
	grid.add_theme_constant_override("v_separation", 6)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	for row: Array in Controls.rows():
		grid.add_child(MenuStyle.label(String(row[0]), MenuStyle.BODY_SIZE, MenuStyle.GOLD))
		grid.add_child(MenuStyle.label(String(row[1]), MenuStyle.BODY_SIZE, MenuStyle.CREAM))
	column.add_child(grid)
	var buttons := MenuStyle.button_column()
	buttons.add_child(MenuStyle.button("BACK", func() -> void: _show(Page.ROOT), true))
	column.add_child(buttons)
	return column


func _show(page: Page) -> void:
	_page = page
	for key: Page in _pages:
		(_pages[key] as Control).visible = key == page
	if page == Page.SETTINGS:
		_refresh_graphics()


func _set_graphics(level: Graphics.Level) -> void:
	if _game != null:
		_game.set_graphics(level)
	_refresh_graphics()


func _refresh_graphics() -> void:
	var current: Graphics.Level = _game.graphics() if _game != null else Graphics.Level.HIGH
	for level: int in _graphics_buttons:
		MenuStyle.style_button(_graphics_buttons[level] as Button, level == current)
#endregion
