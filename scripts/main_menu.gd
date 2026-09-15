extends Control

## The front of the game: play, settings, out.
##
## Built in code rather than laid out in the editor, because almost all of it is
## the *same* three or four widgets with the same styling, and a script that
## makes one button well makes twenty. Everything that decides how it looks is
## at the top of this file, so tuning the look is editing a constant rather than
## hunting through a scene tree.
##
## Five pages, one visible at a time: the root, the choice of solo or together,
## the character select, the settings, and — when it is together — hosting or
## joining. Nothing here knows how the game works: it writes what the player
## picked onto the `Game` autoload and hands the connection to [Net].

const WORLD := "res://scenes/world/greybox_world.tscn"

## The three columns of the character screen, in pixels: a roster tile, and the
## stage the picked one stands on. The dossier takes what is left.
const TILE := Vector2(196.0, 178.0)
const STAGE := Vector2(400.0, 560.0)


## Appended rather than inserted: the pages are addressed by number from the
## tests, and renumbering them to make room in the middle is a change nobody
## asked for.
enum Page { ROOT, MODE, CHARACTERS, SETTINGS, CONNECT }

## Whether the character page leads to a game or to the host/join page. The
## character has to be picked either way and *first*, because it is sent with
## the announcement the moment a peer connects.
var _multiplayer: bool = false
var _page: Page = Page.ROOT
var _pages: Dictionary = {}
var _chosen: StringName = &""
## The roster tiles down the left, and the full-length portrait of each in the
## middle — one is built per character and only the picked one is shown.
var _cards: Dictionary = {}
var _stages: Dictionary = {}
var _graphics_buttons: Dictionary = {}
## The autoload, looked up once. It holds what was chosen last time and is what
## the choices made here are written to.
var _game: Node
## The connection, when there is one to make. Looked up the same way as `_game`
## so a menu built on its own in a test still works with neither present.
var _net: Node
## Where a join is typed, and where anything that went wrong is said.
var _address: LineEdit
var _trouble: Label
## The button at the bottom of the character page, which says different things
## depending on whether there is anyone else to wait for.
var _go: Button


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	MenuStyle.background(self)

	_game = get_node_or_null("/root/Game")
	_net = get_node_or_null("/root/Net")
	if _net != null:
		# Coming back from a game, or from a join that did not take. Either way
		# there is no connection to be holding on to on the front screen.
		_net.call("leave")
		_net.connect("hosting_failed", _on_net_trouble)
		_net.connect("join_failed", _on_net_trouble)
	_chosen = _game.character() if _game != null else &"tariel"

	for page: Page in [Page.ROOT, Page.MODE, Page.CHARACTERS, Page.SETTINGS, Page.CONNECT]:
		var built := _build(page)
		add_child(built)
		_pages[page] = built
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
func _build(page: Page) -> Control:
	match page:
		Page.MODE:
			return _build_mode()
		Page.CHARACTERS:
			return _build_characters()
		Page.SETTINGS:
			return _build_settings()
		Page.CONNECT:
			return _build_connect()
	return _build_root()


func _build_root() -> Control:
	var page := MenuStyle.page_column()
	page.add_child(MenuStyle.title())
	var buttons := MenuStyle.button_column()
	buttons.add_child(MenuStyle.button("PLAY", func() -> void: _show(Page.MODE)))
	buttons.add_child(MenuStyle.button("SETTINGS", func() -> void: _show(Page.SETTINGS)))
	buttons.add_child(MenuStyle.button("EXIT", func() -> void: get_tree().quit()))
	page.add_child(buttons)
	return page


func _build_mode() -> Control:
	var page := MenuStyle.page_column()
	page.add_child(MenuStyle.heading("HOW MANY OF YOU"))
	var buttons := MenuStyle.button_column()
	buttons.add_child(MenuStyle.button("SOLO PLAY", func() -> void:
			_multiplayer = false
			_show(Page.CHARACTERS)))
	buttons.add_child(MenuStyle.button("MULTIPLAYER", func() -> void:
			_multiplayer = true
			_show(Page.CHARACTERS)))
	buttons.add_child(MenuStyle.button("BACK", func() -> void: _show(Page.ROOT), true))
	page.add_child(buttons)
	return page


## Three columns: who there is, who is picked, and what picking them means.
##
## The roster down the left is a face each with a name over it, small enough
## that four of them fit and nothing has to be read to use it. The middle is the
## one picked, full length and turning. The right is everything the old cards
## crammed under their own portraits — with one character on screen there is
## room to lay it out instead of stacking it.
func _build_characters() -> Control:
	var page := MenuStyle.page_column()
	page.add_child(MenuStyle.heading("WHO ARE YOU"))

	var note := MenuStyle.label("", MenuStyle.BODY_SIZE, MenuStyle.GOLD_DIM)
	note.name = "ModeNote"
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page.add_child(note)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 34)

	var roster: Array = _game.roster() if _game != null else []
	var faces := VBoxContainer.new()
	faces.add_theme_constant_override("separation", 14)
	faces.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for id: StringName in roster:
		var tile := _roster_tile(id)
		_cards[id] = tile
		faces.add_child(tile)
	row.add_child(faces)

	var stage := _stage(roster)
	row.add_child(stage)
	row.add_child(_dossier())
	page.add_child(row)

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0.0, 12.0)
	page.add_child(gap)

	var buttons := MenuStyle.button_column()
	# One button, two destinations. Solo starts the game; together, the choice
	# still has to be made *first* — it is sent with the announcement, and a peer
	# whose character is unknown is a peer with nothing to spawn.
	_go = MenuStyle.button("START", func() -> void:
			if _multiplayer:
				_show(Page.CONNECT)
			else:
				_start())
	buttons.add_child(_go)
	buttons.add_child(MenuStyle.button("BACK", func() -> void: _show(Page.MODE), true))
	page.add_child(buttons)
	return page


## Host or join. Nothing here decides who you are — that is already settled by
## the time this page is up.
func _build_connect() -> Control:
	var page := MenuStyle.page_column()
	page.add_child(MenuStyle.heading("PLAY TOGETHER"))

	_trouble = MenuStyle.label("", MenuStyle.BODY_SIZE, MenuStyle.CRIMSON.lightened(0.45))
	_trouble.name = "Trouble"
	_trouble.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page.add_child(_trouble)

	var buttons := MenuStyle.button_column()
	buttons.add_child(MenuStyle.button("HOST GAME", func() -> void: _host()))
	page.add_child(buttons)

	page.add_child(MenuStyle.label("or join one:", MenuStyle.BODY_SIZE, MenuStyle.GOLD_DIM))

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	_address = LineEdit.new()
	_address.name = "Address"
	_address.text = "127.0.0.1"
	_address.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_address.custom_minimum_size = Vector2(240.0, MenuStyle.BUTTON_HEIGHT)
	_address.add_theme_font_size_override("font_size", MenuStyle.BUTTON_SIZE - 4)
	_address.text_submitted.connect(func(_typed: String) -> void: _join())
	row.add_child(_address)
	var join := MenuStyle.button("JOIN", func() -> void: _join())
	join.custom_minimum_size = Vector2(180.0, MenuStyle.BUTTON_HEIGHT)
	row.add_child(join)
	page.add_child(row)

	page.add_child(MenuStyle.label(
			"Everyone fights the same wolves. Nobody can hurt anybody else yet.",
			MenuStyle.BODY_SIZE, MenuStyle.GOLD_DIM))

	var back := MenuStyle.button_column()
	back.add_child(MenuStyle.button("BACK", func() -> void: _show(Page.CHARACTERS), true))
	page.add_child(back)
	return page


func _build_settings() -> Control:
	var page := MenuStyle.page_column()
	page.add_child(MenuStyle.heading("SETTINGS"))

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	row.add_child(MenuStyle.label("GRAPHICS", MenuStyle.BUTTON_SIZE, MenuStyle.CREAM))
	for level: int in [Graphics.Level.LOW, Graphics.Level.HIGH]:
		var button := MenuStyle.button("LOW" if level == Graphics.Level.LOW else "HIGH",
				func() -> void: _set_graphics(level as Graphics.Level))
		button.custom_minimum_size = Vector2(160.0, MenuStyle.BUTTON_HEIGHT)
		_graphics_buttons[level] = button
		row.add_child(button)
	page.add_child(row)

	page.add_child(MenuStyle.label(
			"Low turns shadows off, draws at seven tenths of the resolution and\n"
			+ "softens the textures. It is for machines that are short of frames.",
			MenuStyle.BODY_SIZE, MenuStyle.GOLD_DIM))

	var buttons := MenuStyle.button_column()
	buttons.add_child(MenuStyle.button("BACK", func() -> void: _show(Page.ROOT), true))
	page.add_child(buttons)
	return page


func _show(page: Page) -> void:
	_page = page
	for key: Page in _pages:
		(_pages[key] as Control).visible = key == page
	if page == Page.CHARACTERS:
		_refresh_cards()
		var note := (_pages[page] as Control).find_child("ModeNote", true, false) as Label
		if note != null:
			note.text = "Pick who you are first — it is sent to the others when you connect." \
					if _multiplayer else ""
		if _go != null:
			_go.text = "CONTINUE" if _multiplayer else "START"
	elif page == Page.CONNECT:
		if _trouble != null:
			_trouble.text = ""
	elif page == Page.SETTINGS:
		_refresh_graphics()
#endregion


#region Characters
## One tile in the roster: the character's face, with their name over it.
##
## A face rather than a figure, because at this size a whole man is a shape.
## Kept small on purpose — the roster is for *choosing*, and everything there is
## to know about the choice is already on screen to the right of it.
func _roster_tile(id: StringName) -> Control:
	var profile := _profile(id)
	var tile := Button.new()
	tile.custom_minimum_size = Vector2(TILE.x, TILE.y)
	tile.focus_mode = Control.FOCUS_NONE
	tile.pressed.connect(func() -> void:
		_chosen = id
		_refresh_cards())

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override("separation", 2)
	column.offset_left = 8.0
	column.offset_right = -8.0
	column.offset_top = 8.0
	column.offset_bottom = -8.0
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(column)

	column.add_child(MenuStyle.label(profile.display_name.to_upper(),
			MenuStyle.BODY_SIZE + 3, MenuStyle.GOLD))
	column.add_child(CharacterPortrait.of(profile,
			Vector2(TILE.x - 16.0, TILE.y - 46.0), CharacterPortrait.Frame.FACE))
	return tile


## The middle: whoever is picked, full length and turning. One portrait per
## character, built once and shown one at a time — a `SubViewport` is not a
## thing to throw away and rebuild every time the player moves down a list.
func _stage(roster: Array) -> Control:
	var stage := PanelContainer.new()
	stage.name = "Stage"
	stage.custom_minimum_size = Vector2(STAGE.x, STAGE.y)
	stage.add_theme_stylebox_override("panel", MenuStyle.panel_style(MenuStyle.PANEL))
	var slot := Control.new()
	slot.set_anchors_preset(Control.PRESET_FULL_RECT)
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(slot)
	for id: StringName in roster:
		var full := CharacterPortrait.of(_profile(id), STAGE)
		full.name = "Full_%s" % id
		_stages[id] = full
		slot.add_child(full)
	return stage


## The right: what picking them means. The same lines the old cards carried,
## with room to be read now that only one character's are on screen.
func _dossier() -> Control:
	var panel := PanelContainer.new()
	panel.name = "Dossier"
	panel.custom_minimum_size = Vector2(380.0, STAGE.y)
	panel.add_theme_stylebox_override("panel", MenuStyle.panel_style(MenuStyle.PANEL))

	var column := VBoxContainer.new()
	column.name = "Lines"
	column.add_theme_constant_override("separation", 10)
	column.offset_left = 24.0
	column.offset_right = -24.0
	column.offset_top = 24.0
	column.offset_bottom = -24.0
	panel.add_child(column)
	return panel


## Fills the dossier in for whoever is picked. Rebuilt rather than updated: it is
## eight labels, and eight labels are cheaper to make than to keep in step.
func _fill_dossier() -> void:
	var page := _pages.get(Page.CHARACTERS) as Control
	if page == null:
		return
	var column := page.find_child("Lines", true, false) as VBoxContainer
	if column == null:
		return
	for old in column.get_children():
		old.queue_free()

	var profile := _profile(_chosen)
	column.add_child(MenuStyle.label(profile.display_name.to_upper(),
			MenuStyle.HEADING_SIZE, MenuStyle.GOLD))
	column.add_child(MenuStyle.label(
			"BOW" if profile.weapon == CharacterProfile.Weapon.BOW else "SWORD AND SHIELD",
			MenuStyle.BODY_SIZE, MenuStyle.CRIMSON.lightened(0.35)))
	column.add_child(MenuStyle.rule())
	for line in _stat_lines(profile):
		var stat := MenuStyle.label(line, MenuStyle.BODY_SIZE, MenuStyle.CREAM)
		stat.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		column.add_child(stat)
	column.add_child(MenuStyle.rule())
	var blurb := MenuStyle.label(profile.blurb, MenuStyle.BODY_SIZE, MenuStyle.GOLD_DIM)
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	blurb.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	blurb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(blurb)


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
		var style := MenuStyle.panel_style(MenuStyle.PANEL_HOT if picked else MenuStyle.PANEL)
		style.border_color = MenuStyle.GOLD if picked else Color(0.0, 0.0, 0.0, 0.0)
		style.set_border_width_all(2 if picked else 0)
		for slot in ["normal", "hover", "pressed", "focus"]:
			card.add_theme_stylebox_override(slot, style)
	for id: StringName in _stages:
		(_stages[id] as Control).visible = id == _chosen
	_fill_dossier()


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
	# A solo game is a game with nobody else in it, which is not the same as a
	# game with a peer left over from last time still holding a socket open.
	if _net != null:
		_net.call("leave")
	get_tree().change_scene_to_file(WORLD)


## Opens the game to others and goes straight in. The host is a player.
func _host() -> void:
	if _game != null:
		_game.choose(_chosen)
	if _net == null:
		_on_net_trouble("Networking is not available in this build.")
		return
	_net.call("host", _chosen)


## Connects to whatever was typed. The world is loaded by [Net] once the
## handshake is through — a client that changes scene before that has nothing to
## be in the world with.
func _join() -> void:
	if _game != null:
		_game.choose(_chosen)
	if _net == null or _address == null:
		_on_net_trouble("Networking is not available in this build.")
		return
	if _trouble != null:
		_trouble.text = "Connecting to %s..." % _address.text.strip_edges()
	_net.call("join", _address.text, _chosen)


func _on_net_trouble(why: String) -> void:
	if _trouble != null:
		_trouble.text = why


func _set_graphics(level: Graphics.Level) -> void:
	if _game != null:
		_game.set_graphics(level)
	_refresh_graphics()


func _refresh_graphics() -> void:
	var current: Graphics.Level = _game.graphics() if _game != null else Graphics.Level.HIGH
	for level: int in _graphics_buttons:
		MenuStyle.style_button(_graphics_buttons[level] as Button, level == current)
#endregion


