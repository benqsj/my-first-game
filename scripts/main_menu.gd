extends Control

## The front of the game: play, settings, out.
##
## Built in code rather than laid out in the editor, because almost all of it is
## the *same* three or four widgets with the same styling, and a script that
## makes one button well makes twenty. Everything that decides how it looks is
## at the top of this file, so tuning the look is editing a constant rather than
## hunting through a scene tree.
##
## Four pages, one visible at a time: the root, the choice of solo or co-op, the
## character select, and the settings. Nothing here knows how the game works —
## it sets what the player picked on the `Game` autoload and loads the level.

const WORLD := "res://scenes/world/greybox_world.tscn"

#region Look
const GOLD := Color("d0a044")
const GOLD_DIM := Color("8a6a2c")
const CREAM := Color("ece4d6")
const SLATE := Color("15181d")
const SLATE_DEEP := Color("0a0c0f")
const PANEL := Color("1d222a")
const PANEL_HOT := Color("272e39")
const CRIMSON := Color("76202a")

const TITLE_SIZE := 92
const HEADING_SIZE := 34
const BUTTON_SIZE := 26
const BODY_SIZE := 17
const BUTTON_WIDTH := 340.0
const BUTTON_HEIGHT := 58.0
#endregion

enum Page { ROOT, MODE, CHARACTERS, SETTINGS }

## Two players is a mode the menu offers and the game cannot yet honour. It is
## on the screen because the flow is the flow; it says so rather than pretending.
var _co_op: bool = false
var _page: Page = Page.ROOT
var _pages: Dictionary = {}
var _chosen: StringName = &""
var _cards: Dictionary = {}
var _graphics_buttons: Dictionary = {}
## The autoload, looked up once. It holds what was chosen last time and is what
## the choices made here are written to.
var _game: Node


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_background()

	_game = get_node_or_null("/root/Game")
	_chosen = _game.character() if _game != null else &"tariel"

	_pages[Page.ROOT] = _build_root()
	_pages[Page.MODE] = _build_mode()
	_pages[Page.CHARACTERS] = _build_characters()
	_pages[Page.SETTINGS] = _build_settings()
	_show(Page.ROOT)


func _unhandled_input(event: InputEvent) -> void:
	# Escape goes back a page, and out of the game from the front one.
	if not event.is_action_pressed("ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	match _page:
		Page.ROOT:
			get_tree().quit()
		Page.CHARACTERS:
			_show(Page.MODE)
		_:
			_show(Page.ROOT)


#region Pages
func _build_root() -> Control:
	var page := _page_column()
	page.add_child(_title())
	var buttons := _button_column()
	buttons.add_child(_button("PLAY", func() -> void: _show(Page.MODE)))
	buttons.add_child(_button("SETTINGS", func() -> void: _show(Page.SETTINGS)))
	buttons.add_child(_button("EXIT", func() -> void: get_tree().quit()))
	page.add_child(buttons)
	return page


func _build_mode() -> Control:
	var page := _page_column()
	page.add_child(_heading("HOW MANY OF YOU"))
	var buttons := _button_column()
	buttons.add_child(_button("SOLO PLAY", func() -> void:
			_co_op = false
			_show(Page.CHARACTERS)))
	buttons.add_child(_button("CO-OP PLAY", func() -> void:
			_co_op = true
			_show(Page.CHARACTERS)))
	buttons.add_child(_button("BACK", func() -> void: _show(Page.ROOT), true))
	page.add_child(buttons)
	return page


func _build_characters() -> Control:
	var page := _page_column()
	page.add_child(_heading("WHO ARE YOU"))

	var note := _label("", BODY_SIZE, GOLD_DIM)
	note.name = "CoOpNote"
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page.add_child(note)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 28)
	var roster: Array = _game.roster() if _game != null else []
	for id: StringName in roster:
		var card := _character_card(id)
		_cards[id] = card
		row.add_child(card)
	page.add_child(row)

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0.0, 10.0)
	page.add_child(gap)

	var buttons := _button_column()
	buttons.add_child(_button("START", func() -> void: _start()))
	buttons.add_child(_button("BACK", func() -> void: _show(Page.MODE), true))
	page.add_child(buttons)
	return page


func _build_settings() -> Control:
	var page := _page_column()
	page.add_child(_heading("SETTINGS"))

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	row.add_child(_label("GRAPHICS", BUTTON_SIZE, CREAM))
	for level: int in [Graphics.Level.LOW, Graphics.Level.HIGH]:
		var button := _button("LOW" if level == Graphics.Level.LOW else "HIGH",
				func() -> void: _set_graphics(level as Graphics.Level))
		button.custom_minimum_size = Vector2(160.0, BUTTON_HEIGHT)
		_graphics_buttons[level] = button
		row.add_child(button)
	page.add_child(row)

	page.add_child(_label(
			"Low turns shadows off, draws at seven tenths of the resolution and\n"
			+ "softens the textures. It is for machines that are short of frames.",
			BODY_SIZE, GOLD_DIM))

	var buttons := _button_column()
	buttons.add_child(_button("BACK", func() -> void: _show(Page.ROOT), true))
	page.add_child(buttons)
	return page


func _show(page: Page) -> void:
	_page = page
	for key: Page in _pages:
		(_pages[key] as Control).visible = key == page
	if page == Page.CHARACTERS:
		_refresh_cards()
		var note := (_pages[page] as Control).find_child("CoOpNote", true, false) as Label
		if note != null:
			note.text = "Co-op is not wired up yet — this will start a solo game." \
					if _co_op else ""
	elif page == Page.SETTINGS:
		_refresh_graphics()
#endregion


#region Characters
## One card per character, with what makes them different read straight off
## their profile — so the card cannot drift from the numbers the game uses.
func _character_card(id: StringName) -> Control:
	var profile := _profile(id)
	var card := Button.new()
	card.custom_minimum_size = Vector2(340.0, 380.0)
	card.focus_mode = Control.FOCUS_NONE
	card.pressed.connect(func() -> void:
		_chosen = id
		_refresh_cards())

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override("separation", 10)
	column.offset_left = 22.0
	column.offset_right = -22.0
	column.offset_top = 22.0
	column.offset_bottom = -22.0
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(column)

	column.add_child(_label(profile.display_name.to_upper(), HEADING_SIZE, GOLD))
	column.add_child(_label(
			"BOW" if profile.weapon == CharacterProfile.Weapon.BOW else "SWORD AND SHIELD",
			BODY_SIZE, CRIMSON.lightened(0.35)))
	column.add_child(_rule())
	for line in _stat_lines(profile):
		column.add_child(_label(line, BODY_SIZE, CREAM))
	column.add_child(_rule())
	var blurb := _label(profile.blurb, BODY_SIZE, GOLD_DIM)
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	blurb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(blurb)
	return card


## What actually differs between them, in the words a player would use.
func _stat_lines(profile: CharacterProfile) -> Array[String]:
	var knight := _profile(&"tariel")
	var lines: Array[String] = []
	lines.append("Run    %.1f m/s%s" % [profile.run_speed,
			_compare(profile.run_speed, knight.run_speed, "faster", "slower")])
	var roll := profile.dash_speed * profile.dash_duration
	lines.append("Roll   %.1f m%s" % [roll,
			_compare(roll, knight.dash_speed * knight.dash_duration, "further", "shorter")])
	lines.append("Crit   %.0f%%%s" % [profile.crit_chance * 100.0,
			_compare(profile.crit_chance, knight.crit_chance, "more often", "less often")])
	lines.append("Block  %s" % ("yes, behind a shield" if profile.can_block else "no shield"))
	return lines


## " — faster" and the like, but only when there is something to say.
func _compare(mine: float, theirs: float, better: String, worse: String) -> String:
	if is_equal_approx(mine, theirs):
		return ""
	return "   — %s" % (better if mine > theirs else worse)


func _refresh_cards() -> void:
	for id: StringName in _cards:
		var card := _cards[id] as Button
		var picked := id == _chosen
		var style := _panel_style(PANEL_HOT if picked else PANEL)
		style.border_color = GOLD if picked else Color(0.0, 0.0, 0.0, 0.0)
		style.set_border_width_all(2 if picked else 0)
		for slot in ["normal", "hover", "pressed", "focus"]:
			card.add_theme_stylebox_override(slot, style)


func _profile(id: StringName) -> CharacterProfile:
	if _game == null:
		return CharacterProfile.new()
	var paths: Dictionary = _game.get("CHARACTERS")
	return load(String(paths.get(id, paths.values()[0]))) as CharacterProfile
#endregion


#region Doing something about it
func _start() -> void:
	if _game != null:
		_game.choose(_chosen)
	get_tree().change_scene_to_file(WORLD)


func _set_graphics(level: Graphics.Level) -> void:
	if _game != null:
		_game.set_graphics(level)
	_refresh_graphics()


func _refresh_graphics() -> void:
	var current: Graphics.Level = _game.graphics() if _game != null else Graphics.Level.HIGH
	for level: int in _graphics_buttons:
		_style_button(_graphics_buttons[level] as Button, level == current)
#endregion


#region Widgets
## A dark ground with a warm bloom behind the title, so the gold has something
## to sit on rather than floating on flat black.
func _build_background() -> void:
	var sky := ColorRect.new()
	sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	sky.color = SLATE_DEEP
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sky)

	var glow := TextureRect.new()
	glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ramp := GradientTexture2D.new()
	ramp.width = 8
	ramp.height = 256
	ramp.fill = GradientTexture2D.FILL_LINEAR
	ramp.fill_from = Vector2(0.0, 0.0)
	ramp.fill_to = Vector2(0.0, 1.0)
	var colours := Gradient.new()
	colours.set_color(0, SLATE)
	colours.set_color(1, SLATE_DEEP)
	colours.add_point(0.42, CRIMSON.darkened(0.62))
	ramp.gradient = colours
	glow.texture = ramp
	glow.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(glow)


func _page_column() -> Control:
	var page := VBoxContainer.new()
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	page.alignment = BoxContainer.ALIGNMENT_CENTER
	page.add_theme_constant_override("separation", 26)
	add_child(page)
	return page


func _button_column() -> VBoxContainer:
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 12)
	return column


func _title() -> Control:
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 2)
	var title := _label("VEPXIS", TITLE_SIZE, GOLD)
	title.add_theme_constant_override("outline_size", 0)
	stack.add_child(title)
	stack.add_child(_rule(280.0))
	stack.add_child(_label("THE KNIGHT IN THE PANTHER'S SKIN", BODY_SIZE, GOLD_DIM))
	return stack


func _heading(text: String) -> Control:
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 6)
	stack.add_child(_label(text, HEADING_SIZE, CREAM))
	stack.add_child(_rule(180.0))
	return stack


func _label(text: String, size: int, colour: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", colour)
	return label


## A hairline of gold. Cheap, and it does more for the look than anything else
## on the screen.
func _rule(width: float = 0.0) -> Control:
	var line := ColorRect.new()
	line.color = GOLD_DIM
	line.custom_minimum_size = Vector2(width, 1.0)
	line.size_flags_horizontal = Control.SIZE_SHRINK_CENTER if width > 0.0 \
			else Control.SIZE_FILL
	return line


func _button(text: String, pressed: Callable, quiet: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(BUTTON_WIDTH, BUTTON_HEIGHT)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.add_theme_font_size_override("font_size", BUTTON_SIZE)
	button.pressed.connect(pressed)
	_style_button(button, false, quiet)
	return button


## The one piece of styling everything else leans on: a flat panel with a gold
## edge down one side that fills in when the mouse is over it.
func _style_button(button: Button, chosen: bool, quiet: bool = false) -> void:
	var idle := _panel_style(PANEL if not chosen else PANEL_HOT)
	idle.border_width_left = 4 if chosen else 2
	idle.border_color = GOLD if chosen else GOLD_DIM

	var hot := _panel_style(PANEL_HOT)
	hot.border_width_left = 4
	hot.border_color = GOLD

	button.add_theme_stylebox_override("normal", idle)
	button.add_theme_stylebox_override("hover", hot)
	button.add_theme_stylebox_override("pressed", hot)
	button.add_theme_stylebox_override("focus", hot)
	button.add_theme_color_override("font_color", GOLD_DIM if quiet else CREAM)
	button.add_theme_color_override("font_hover_color", GOLD)
	button.add_theme_color_override("font_pressed_color", GOLD)


func _panel_style(fill: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.set_corner_radius_all(3)
	style.content_margin_left = 20.0
	style.content_margin_right = 20.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	return style
#endregion
