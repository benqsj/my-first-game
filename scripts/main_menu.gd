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
## The empty floor to try creatures, bosses and looks on ([ArenaPanel]).
const ARENA := "res://scenes/world/test_arena.tscn"
## Whether START goes to the arena rather than the land.
var _arena: bool = false
const NetScript := preload("res://scripts/net.gd")

## The three columns of the character screen, in pixels: a roster tile, and the
## stage the picked one stands on. The dossier takes what is left.
const TILE := Vector2(268.0, 104.0)
## Taller and wider than it was (440 x 500): a great sword held out was cut
## off at its edge (the picture runs past it too, `STAGE_BLEED`).
const STAGE := Vector2(540.0, 600.0)
## How far the hero's picture runs out past the stage either side (into the
## gaps beside it, the picture's ground clear): a great sword held out stays
## whole without the camera standing back and the hero drawn smaller than
## the others (the user's word, 2026-10-05).
const STAGE_BLEED := 116.0
## Room kept under the stage for the look/colour/hair rows, shown or not, so
## the stage stays where it is from hero to hero (and the page fits 900 high:
## at 540 the stage pushed the roster off the bottom).
const PICKS_HEIGHT := 108.0
## The right-hand plate (the dossier, or the maker in its place).
const PLATE_WIDTH := 528.0


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
var _display_buttons: Dictionary = {}
## Seconds the menu has been up: what the stage's light breathes by.
var _stage_clock: float = 0.0
## The display choices on the settings page, in order: [Game]'s keys.
const DISPLAY_NAMES := {
	"window": "WINDOW", "1280x720": "1280×720", "1920x1080": "1920×1080",
	"2560x1440": "2560×1440", "fullscreen": "FULL SCREEN",
}
## The autoload, looked up once. It holds what was chosen last time and is what
## the choices made here are written to.
var _game: Node
## The connection, when there is one to make. Looked up the same way as `_game`
## so a menu built on its own in a test still works with neither present.
var _net: Node
## Where a join is typed, and where anything that went wrong is said.
var _address: LineEdit
var _trouble: Label
## The games heard on this network, one button each, and the line under them.
var _found: VBoxContainer
var _found_note: Label
## The button at the bottom of the character page, which says different things
## depending on whether there is anyone else to wait for.
var _go: Button
## Under the stage: the picked hero's face and hair, each stepped through with
## two arrows (shown only for a hero who has a choice of it): kind -> the row.
var _pick_rows: Dictionary = {}
## The maker ([PolysplitLook]), in the dossier's place while the picked hero
## wears YOUR OWN: its rows in four tabs, each an arrow either side of what is
## picked of that kind.
const MAKER_TABS := {
	"OUTFIT": ["cls", "g"],
	"FACE": ["eyes", "brows", "mouth", "beard", "hair", "hc", "skin"],
	"GEAR": ["top", "bottom", "extra", "hat", "cloth"],
	"ARMS": ["w", "o", "ws"],
}
const MAKER_LABELS := {
	"cls": "OUTFIT", "g": "BODY", "eyes": "EYES", "brows": "BROWS", "mouth": "MOUTH", "beard": "BEARD",
	"hair": "HAIR", "hc": "HAIR COLOUR", "skin": "SKIN", "top": "TOP", "bottom": "LEGS", "extra": "MORE", "hat": "HAT",
	"cloth": "CLOTH", "w": "WEAPON", "o": "OTHER HAND", "ws": "STYLE",
}
var _maker_tab: String = "OUTFIT"
var _maker_rows: Dictionary = {}
var _maker_tabs: Dictionary = {}
## Which of the extras the MORE row is on (it steps through them all; the
## button by it puts the one shown on or off).
var _extra_at: int = 0
## The people the roster shows ([constant PEOPLES]), and their banners.
var _people: StringName = &"human"
var _people_buttons: Dictionary = {}


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = UiArt.theme()
	MenuStyle.background(self)

	_game = get_node_or_null("/root/Game")
	_net = get_node_or_null("/root/Net")
	var music := get_node_or_null("/root/Music")
	if music != null:
		music.call("play", &"menu")
	if _net != null:
		# Coming back from a game, or from a join that did not take. Either way
		# there is no connection to be holding on to on the front screen.
		_net.call("leave")
		_net.connect("hosting_failed", _on_net_trouble)
		_net.connect("join_failed", _on_net_trouble)
		_net.connect("games_changed", _refresh_found)
	_chosen = _game.character() if _game != null else &"tariel"
	_people = _profile(_chosen).people

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


## The front: the name of the game and three words under it, down the left
## where the backdrop is darkest, with the mountains and the moon to the right.
func _build_root() -> Control:
	var page := Control.new()
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# a band of shadow down the left for the words to stand in
	var band := Control.new()
	band.set_anchors_preset(Control.PRESET_FULL_RECT)
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.draw.connect(func() -> void:
		var h := band.size.y
		var edge := 740.0
		band.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(edge, 0), Vector2(edge, h), Vector2(0, h)]),
				PackedColorArray([Color(0.01, 0.01, 0.02, 0.72), Color(0.01, 0.01, 0.02, 0.0),
				Color(0.01, 0.01, 0.02, 0.0), Color(0.01, 0.01, 0.02, 0.72)]))
		pass)
	page.add_child(band)

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	column.offset_left = 110.0
	column.offset_right = 110.0 + 520.0
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 44)
	page.add_child(column)

	column.add_child(MenuStyle.title())
	var buttons := MenuStyle.button_column()
	buttons.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	buttons.add_child(MenuStyle.word_button("PLAY", func() -> void: _show(Page.MODE)))
	buttons.add_child(MenuStyle.word_button("SETTINGS", func() -> void: _show(Page.SETTINGS)))
	buttons.add_child(MenuStyle.word_button("EXIT", func() -> void: get_tree().quit()))
	column.add_child(buttons)

	var foot := MenuStyle.label("1 – 4 players  ·  LAN co-op  ·  early build", MenuStyle.BODY_SIZE - 3,
			Color(MenuStyle.GOLD_DIM, 0.8))
	foot.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	foot.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	foot.grow_vertical = Control.GROW_DIRECTION_BEGIN
	foot.offset_right = -36.0
	foot.offset_bottom = -26.0
	foot.offset_left = -640.0
	foot.offset_top = -56.0
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	foot.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	page.add_child(foot)
	return page


## A page that is a card in the middle of the screen: a dark, gold-edged plate
## over the backdrop, with a heading, and the column the caller fills.
func _card_page(heading: String) -> Array:
	var page := CenterContainer.new()
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", MenuStyle.plate(Vector2(68.0, 48.0)))
	page.add_child(card)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 22)
	card.add_child(column)
	column.add_child(MenuStyle.heading(heading))
	return [page, column]


func _build_mode() -> Control:
	var made := _card_page("HOW WILL YOU RIDE")
	var column := made[1] as VBoxContainer
	var buttons := MenuStyle.button_column()
	buttons.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	buttons.add_child(MenuStyle.button("ALONE", func() -> void:
			_multiplayer = false
			_arena = false
			_show(Page.CHARACTERS)))
	buttons.add_child(MenuStyle.button("WITH COMPANIONS", func() -> void:
			_multiplayer = true
			_show(Page.CHARACTERS)))
	buttons.add_child(MenuStyle.button("TEST ARENA", func() -> void:
			_multiplayer = false
			_arena = true
			_show(Page.CHARACTERS)))
	buttons.add_child(MenuStyle.button("BACK", func() -> void: _show(Page.ROOT), true))
	column.add_child(buttons)
	column.add_child(MenuStyle.label("Up to four of you, on the same network, against the same monsters.",
			MenuStyle.BODY_SIZE - 1, MenuStyle.GOLD_DIM))
	return made[0]


## The hero select, the way the big games lay it out: the roster down the
## left, a face and a name each; whoever is picked large in the middle,
## standing in a pool of their own colour; on an ornate plate to the right
## everything there is to know about them (or the maker, for YOUR OWN), and
## the way on under it.
func _build_characters() -> Control:
	var page := Control.new()
	page.set_anchors_preset(Control.PRESET_FULL_RECT)

	# a darker floor under the three columns, so they read off the sky
	var shade := Control.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.draw.connect(func() -> void:
		var w := shade.size.x
		var h := shade.size.y
		shade.draw_polygon(PackedVector2Array([Vector2(0, h * 0.45), Vector2(w, h * 0.45), Vector2(w, h),
				Vector2(0, h)]), PackedColorArray([Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.0),
				Color(0, 0, 0, 0.55), Color(0, 0, 0, 0.55)]))
		shade.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w * 0.3, 0), Vector2(w * 0.3, h),
				Vector2(0, h)]), PackedColorArray([Color(0, 0, 0, 0.45), Color(0, 0, 0, 0.0),
				Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.45)])))
	page.add_child(shade)

	var frame := MarginContainer.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		frame.add_theme_constant_override("margin_" + side, 48)
	frame.add_theme_constant_override("margin_top", 26)
	frame.add_theme_constant_override("margin_bottom", 22)
	page.add_child(frame)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	frame.add_child(column)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 26)
	var head := MenuStyle.heading("CHOOSE YOUR HERO")
	top.add_child(head)
	var note := MenuStyle.label("", MenuStyle.BODY_SIZE, MenuStyle.GOLD_DIM)
	note.name = "ModeNote"
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top.add_child(note)
	column.add_child(top)

	var roster: Array = _game.roster() if _game != null else []
	var middle := HBoxContainer.new()
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	middle.add_theme_constant_override("separation", 0)

	# The roster, down the left.
	var tiles := VBoxContainer.new()
	tiles.name = "Roster"
	tiles.alignment = BoxContainer.ALIGNMENT_CENTER
	tiles.add_theme_constant_override("separation", 10)
	tiles.add_child(_people_row())
	for id: StringName in roster:
		var tile := _roster_tile(id)
		_cards[id] = tile
		tiles.add_child(tile)
	middle.add_child(tiles)
	var left_gap := Control.new()
	left_gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	middle.add_child(left_gap)

	# Whoever is picked, in the middle.
	var stage_column := VBoxContainer.new()
	stage_column.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	stage_column.add_theme_constant_override("separation", 0)
	stage_column.add_child(_stage(roster))
	var turn := MenuStyle.label("◂  DRAG TO TURN  ▸", MenuStyle.BODY_SIZE - 5, Color(MenuStyle.GOLD_DIM, 0.85), "head")
	turn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stage_column.add_child(turn)
	var picks := VBoxContainer.new()
	picks.custom_minimum_size = Vector2(0.0, PICKS_HEIGHT)
	picks.add_theme_constant_override("separation", 2)
	picks.add_child(_picker("face"))
	picks.add_child(_picker("tint"))
	picks.add_child(_picker("hair"))
	stage_column.add_child(picks)
	middle.add_child(stage_column)
	var mid_gap := Control.new()
	mid_gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	middle.add_child(mid_gap)

	# The plate, and the way on under it.
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(PLATE_WIDTH, 0.0)
	right.add_theme_constant_override("separation", 14)
	var upper := Control.new()
	upper.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(upper)
	right.add_child(_dossier())
	right.add_child(_maker())
	var lower := Control.new()
	lower.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(lower)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override("separation", 12)
	var back := MenuStyle.button("BACK", func() -> void: _show(Page.MODE), true)
	back.custom_minimum_size = Vector2(170.0, 56.0)
	back.alignment = HORIZONTAL_ALIGNMENT_CENTER
	buttons.add_child(back)
	# One button, two destinations. Solo starts the game; together, the choice
	# still has to be made *first* — it is sent with the announcement, and a peer
	# whose character is unknown is a peer with nothing to spawn.
	_go = MenuStyle.button("START", func() -> void:
			if _multiplayer:
				_show(Page.CONNECT)
			else:
				_start())
	_go.custom_minimum_size = Vector2(300.0, 60.0)
	_go.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_go.add_theme_font_override("font", UiArt.font("title"))
	_go.add_theme_font_size_override("font_size", MenuStyle.BUTTON_SIZE + 2)
	var bright := MenuStyle.panel_style(Color(0.44, 0.11, 0.1, 0.95))
	bright.border_color = MenuStyle.GOLD
	bright.set_border_width_all(2)
	bright.set_corner_radius_all(3)
	bright.shadow_color = Color(0.6, 0.12, 0.06, 0.4)
	bright.shadow_size = 10
	var brighter := bright.duplicate() as StyleBoxFlat
	brighter.bg_color = Color(0.62, 0.17, 0.12, 0.98)
	brighter.border_color = UiArt.GOLD_LIGHT
	brighter.shadow_color = Color(0.95, 0.5, 0.2, 0.4)
	brighter.shadow_size = 18
	_go.add_theme_stylebox_override("normal", bright)
	for slot in ["hover", "pressed", "focus"]:
		_go.add_theme_stylebox_override(slot, brighter)
	_go.add_theme_color_override("font_color", MenuStyle.CREAM)
	_go.add_theme_color_override("font_hover_color", Color.WHITE)
	buttons.add_child(_go)
	right.add_child(buttons)
	middle.add_child(right)
	column.add_child(middle)
	return page


## Host or join. Nothing here decides who you are — that is already settled by
## the time this page is up.
func _build_connect() -> Control:
	var made := _card_page("PLAY TOGETHER")
	var page := made[1] as VBoxContainer

	_trouble = MenuStyle.label("", MenuStyle.BODY_SIZE, MenuStyle.CRIMSON.lightened(0.45))
	_trouble.name = "Trouble"
	_trouble.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page.add_child(_trouble)

	var buttons := MenuStyle.button_column()
	buttons.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var host := MenuStyle.button("HOST GAME", func() -> void: _host())
	host.alignment = HORIZONTAL_ALIGNMENT_CENTER
	buttons.add_child(host)
	page.add_child(buttons)

	# Hosts on this Wi-Fi call out once a second; each one heard is a button.
	page.add_child(MenuStyle.label("games on your network:", MenuStyle.BODY_SIZE, MenuStyle.GOLD_DIM))
	_found = VBoxContainer.new()
	_found.name = "Found"
	_found.alignment = BoxContainer.ALIGNMENT_CENTER
	_found.add_theme_constant_override("separation", 8)
	page.add_child(_found)
	_found_note = MenuStyle.label("", MenuStyle.BODY_SIZE, MenuStyle.GOLD_DIM)
	_found_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page.add_child(_found_note)

	page.add_child(MenuStyle.label("or type the host's address:", MenuStyle.BODY_SIZE, MenuStyle.GOLD_DIM))

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	_address = LineEdit.new()
	_address.name = "Address"
	_address.text = "127.0.0.1"
	_address.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_address.custom_minimum_size = Vector2(260.0, MenuStyle.BUTTON_HEIGHT)
	_address.add_theme_font_size_override("font_size", MenuStyle.BUTTON_SIZE - 4)
	var field := MenuStyle.panel_style(Color(0.0, 0.0, 0.0, 0.5))
	field.border_color = MenuStyle.GOLD_DIM
	field.border_width_bottom = 1
	_address.add_theme_stylebox_override("normal", field)
	_address.add_theme_stylebox_override("focus", field)
	_address.add_theme_color_override("font_color", MenuStyle.CREAM)
	_address.text_submitted.connect(func(_typed: String) -> void: _join())
	row.add_child(_address)
	var join := MenuStyle.button("JOIN", func() -> void: _join())
	join.custom_minimum_size = Vector2(180.0, MenuStyle.BUTTON_HEIGHT)
	join.alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(join)
	page.add_child(row)

	var mine: Array[String] = NetScript.lan_addresses() if _net != null else []
	page.add_child(MenuStyle.label(
			"Everyone fights the same monsters. Nobody can hurt anybody else yet.\n"
			+ ("If you host, the others join at: %s" % ", ".join(mine) if not mine.is_empty()
				else "This computer is not on a network — only this machine can join."),
			MenuStyle.BODY_SIZE - 1, MenuStyle.GOLD_DIM))

	var back := MenuStyle.button_column()
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.add_child(MenuStyle.button("BACK", func() -> void: _show(Page.CHARACTERS), true))
	page.add_child(back)
	return made[0]


func _build_settings() -> Control:
	var made := _card_page("SETTINGS")
	var page := made[1] as VBoxContainer

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	row.add_child(MenuStyle.label("GRAPHICS", MenuStyle.BUTTON_SIZE - 2, MenuStyle.CREAM))
	for level: Graphics.Level in Graphics.ORDER:
		var button := MenuStyle.button(Graphics.label(level),
				func() -> void: _set_graphics(level))
		button.custom_minimum_size = Vector2(150.0, MenuStyle.BUTTON_HEIGHT)
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		_graphics_buttons[level] = button
		row.add_child(button)
	page.add_child(row)

	var screen_row := HBoxContainer.new()
	screen_row.alignment = BoxContainer.ALIGNMENT_CENTER
	screen_row.add_theme_constant_override("separation", 10)
	screen_row.add_child(MenuStyle.label("SCREEN", MenuStyle.BUTTON_SIZE - 2, MenuStyle.CREAM))
	for key: String in DISPLAY_NAMES:
		var button := MenuStyle.button(String(DISPLAY_NAMES[key]), func() -> void: _set_display(key))
		button.custom_minimum_size = Vector2(128.0, MenuStyle.BUTTON_HEIGHT - 8.0)
		button.add_theme_font_size_override("font_size", MenuStyle.BODY_SIZE)
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		_display_buttons[key] = button
		screen_row.add_child(button)
	page.add_child(screen_row)

	page.add_child(MenuStyle.label(
			"Medium keeps a shorter shadow and draws at 85% of the resolution.\n"
			+ "Low turns shadows off, draws at seven tenths and softens the textures.",
			MenuStyle.BODY_SIZE - 1, MenuStyle.GOLD_DIM))

	var buttons := MenuStyle.button_column()
	buttons.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	buttons.add_child(MenuStyle.button("BACK", func() -> void: _show(Page.ROOT), true))
	page.add_child(buttons)
	return made[0]
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
	# Listen for hosts only while the page that lists them is up.
	if _net != null:
		if page == Page.CONNECT:
			_net.call("start_looking")
			_refresh_found()
		else:
			_net.call("stop_looking")
	if page == Page.SETTINGS:
		_refresh_graphics()
#endregion


#region Characters
## Each hero's own colour: the light they stand in on the stage, the edge of
## their tile when picked, the fill of their bars.
const ACCENT := {
	&"tariel": Color("d0892e"),
	&"avtandil": Color("6fae4a"),
	&"mage": Color("4f8ee8"),
	&"rogue": Color("a04ad8"),
	&"warrior": Color("b8433a"),
	&"elf_archer": Color("8fd06a"),
	&"elf_mage": Color("d8e6f2"),
	&"dark_archer": Color("8a6ad8"),
	&"dark_mage": Color("b05ce0"),
	&"dark_rogue": Color("6a5a9a"),
}
## What they are called, under their name.
const EPITHET := {
	&"tariel": "The Knight in the Panther's Skin",
	&"avtandil": "Hunter of Arabia, Tariel's sworn brother",
	&"mage": "Keeper of the storm",
	&"rogue": "The blade in the dark",
	&"warrior": "Two hands on one great sword",
	&"elf_archer": "Of Elvareti, the fallen world",
	&"elf_mage": "Keeper of the moon's light",
	&"dark_archer": "Last through the gate",
	&"dark_mage": "The enemy's own dark, turned on it",
	&"dark_rogue": "The blade in the dark",
}
## The peoples the roster is grouped by, in their order on the banners: what
## each is called and its light.
const PEOPLES := {
	&"human": {"name": "HUMANS", "light": Color("d0892e")},
	&"elf": {"name": "ELVES", "light": Color("bfe0a0")},
	&"dark": {"name": "DARK ELVES", "light": Color("9a72e0")},
}


func _accent(id: StringName) -> Color:
	return ACCENT.get(id, MenuStyle.GOLD)


## One tile in the roster: the character's face in a frame, their name and
## what they are called under it.
## The peoples' banners over the roster: one picked shows its heroes alone.
func _people_row() -> Control:
	var row := HBoxContainer.new()
	row.name = "Peoples"
	row.add_theme_constant_override("separation", 6)
	row.custom_minimum_size = Vector2(TILE.x, 0.0)
	for key: StringName in PEOPLES:
		var spec: Dictionary = PEOPLES[key]
		var button := Button.new()
		button.name = "People_%s" % key
		button.text = String(spec["name"])
		button.focus_mode = Control.FOCUS_NONE
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0.0, 44.0)
		button.add_theme_font_override("font", UiArt.font("head"))
		button.add_theme_font_size_override("font_size", MenuStyle.BODY_SIZE - 4)
		button.pressed.connect(func() -> void: _pick_people(key))
		_people_buttons[key] = button
		row.add_child(button)
	return row


## Shows `people`'s heroes on the roster, and picks the first of them unless
## the one picked is already theirs.
func _pick_people(people: StringName) -> void:
	_people = people
	if _profile(_chosen).people != people:
		for id: StringName in _cards:
			if _profile(id).people == people:
				_chosen = id
				break
	_refresh_cards()


func _roster_tile(id: StringName) -> Control:
	var profile := _profile(id)
	var tile := Button.new()
	tile.name = "Tile_%s" % id
	tile.custom_minimum_size = Vector2(TILE.x, TILE.y)
	tile.focus_mode = Control.FOCUS_NONE
	tile.pressed.connect(func() -> void:
		_chosen = id
		_refresh_cards())

	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 12)
	row.offset_left = 6.0
	row.offset_right = -8.0
	row.offset_top = 6.0
	row.offset_bottom = -6.0
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(row)

	var face := CharacterPortrait.of(profile, Vector2(TILE.y - 12.0, TILE.y - 12.0), CharacterPortrait.Frame.BUST)
	face.name = "Face"
	row.add_child(face)
	var words := VBoxContainer.new()
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.add_theme_constant_override("separation", 0)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(words)
	var caption := MenuStyle.label(profile.display_name.to_upper(), MenuStyle.BODY_SIZE + 1, MenuStyle.CREAM, "title")
	caption.name = "Name"
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	words.add_child(caption)
	var what := MenuStyle.label(_arms(profile), MenuStyle.BODY_SIZE - 5, MenuStyle.GOLD_DIM, "head")
	what.name = "Arms"
	what.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	words.add_child(what)
	return tile


## The middle: whoever is picked, full length and turning, in a pool of their
## own light on a round stone. One portrait per character, built once and shown
## one at a time — a `SubViewport` is not a thing to rebuild every click.
func _stage(roster: Array) -> Control:
	var stage := Control.new()
	stage.name = "Stage"
	stage.custom_minimum_size = Vector2(STAGE.x, STAGE.y)
	# Its own size, whatever the window: taller windows get more room round
	# it, not a stretched stage with the figure left standing at its top.
	stage.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# Dragged across, it turns the one standing on it; left alone, they stand
	# still.
	stage.mouse_filter = Control.MOUSE_FILTER_STOP
	stage.mouse_default_cursor_shape = Control.CURSOR_DRAG
	stage.gui_input.connect(_on_stage_input)
	stage.draw.connect(func() -> void: _draw_stage(stage))
	for id: StringName in roster:
		var full := CharacterPortrait.of(_profile(id), STAGE + Vector2(STAGE_BLEED * 2.0, 0.0))
		full.name = "Full_%s" % id
		# In the face and the hair picked last time; set before the model is
		# in the tree, so it comes up wearing them.
		if full.rig() != null and _game != null:
			full.rig().set(&"face", int(_game.call(&"face", id)))
			full.rig().set(&"hair", int(_game.call(&"hair", id)))
			if _game.has_method(&"tint"):
				full.rig().set(&"tint", int(_game.call(&"tint", id)))
			if _game.has_method(&"look"):
				full.rig().set(&"ps_look", _game.call(&"look", id))
		_stages[id] = full
		stage.add_child(full)
		full.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		full.offset_left = -STAGE_BLEED
		full.offset_right = STAGE_BLEED
	return stage


## A row under the stage: an arrow either side of the name of the face (or
## the hair) that is on. `kind` is "face" or "hair": the rig's `faces` /
## `face_names` / `set_face()`, or the same for hair.
func _picker(kind: String) -> Control:
	var row := HBoxContainer.new()
	row.name = kind.capitalize() + "Row"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	var back := _arrow("‹", func() -> void: _step(kind, -1))
	back.name = "Back"
	row.add_child(back)
	var called := MenuStyle.label("", MenuStyle.BODY_SIZE - 1, MenuStyle.CREAM, "head")
	called.name = "Name"
	called.custom_minimum_size = Vector2(340.0, 0.0)
	called.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(called)
	var on := _arrow("›", func() -> void: _step(kind, 1))
	on.name = "Next"
	row.add_child(on)
	_pick_rows[kind] = row
	return row


## A small square arrow button, gold on dark, lit under the mouse.
func _arrow(glyph: String, pressed: Callable, size: Vector2 = Vector2(38.0, 32.0)) -> Button:
	var button := Button.new()
	button.text = glyph
	button.custom_minimum_size = size
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_override("font", UiArt.font("bold"))
	button.add_theme_font_size_override("font_size", 26)
	button.pressed.connect(pressed)
	var idle := StyleBoxFlat.new()
	idle.bg_color = Color(0.06, 0.05, 0.06, 0.75)
	idle.border_color = Color(MenuStyle.GOLD_DIM, 0.8)
	idle.set_border_width_all(1)
	idle.set_corner_radius_all(3)
	idle.content_margin_top = -2.0
	idle.content_margin_bottom = 2.0
	var hot := idle.duplicate() as StyleBoxFlat
	hot.bg_color = Color(0.3, 0.2, 0.07, 0.9)
	hot.border_color = MenuStyle.GOLD
	hot.shadow_color = Color(0.95, 0.6, 0.2, 0.25)
	hot.shadow_size = 6
	var off := idle.duplicate() as StyleBoxFlat
	off.bg_color = Color(0.04, 0.04, 0.05, 0.4)
	off.border_color = Color(MenuStyle.GOLD_DIM, 0.25)
	button.add_theme_stylebox_override("normal", idle)
	button.add_theme_stylebox_override("hover", hot)
	button.add_theme_stylebox_override("pressed", hot)
	button.add_theme_stylebox_override("focus", idle)
	button.add_theme_stylebox_override("disabled", off)
	button.add_theme_color_override("font_color", MenuStyle.GOLD)
	button.add_theme_color_override("font_hover_color", UiArt.GOLD_LIGHT)
	button.add_theme_color_override("font_disabled_color", Color(MenuStyle.GOLD_DIM, 0.4))
	return button


## The hero whose figure the maker dresses: the rig's (an elf is the
## archer's, the mage's or the assassin's), or the picked id.
func _ps_hero() -> StringName:
	var model := _chosen_rig()
	var hero: Variant = model.get(&"polysplit_hero") if model != null else null
	return hero if hero is StringName and hero != &"" else _chosen


## The picked hero's model on the stage.
func _chosen_rig() -> Node3D:
	var full := _stages.get(_chosen) as CharacterPortrait
	return full.rig() if full != null else null


## What each face (or hair) of the picked hero is called; empty for one with
## no choice of it.
func _pick_list(kind: String) -> Array:
	var model := _chosen_rig()
	if model == null or not model.has_method(&"set_" + kind):
		return []
	var names: Variant = model.get(StringName(kind + "_names"))
	return names as Array if names is Array else []


## The next (or last) face or hair, on the stage and remembered.
func _step(kind: String, by: int) -> void:
	var names := _pick_list(kind)
	if names.size() < 2:
		return
	var model := _chosen_rig()
	var index := wrapi(int(model.get(StringName(kind))) + by, 0, names.size())
	model.call(&"set_" + kind, index)
	if _game != null:
		_game.call(&"set_" + kind, _chosen, index)
		# YOUR OWN is worn as it was made: what it is made of is kept with it
		if kind == "face" and model.has_method(&"get_look") and _game.has_method(&"set_look"):
			_game.call(&"set_look", _chosen, model.call(&"get_look"))
	_refresh_picks()


func _step_hair(by: int) -> void:
	_step("hair", by)


func _step_face(by: int) -> void:
	_step("face", by)


func _refresh_picks() -> void:
	_refresh_maker()
	for kind: String in _pick_rows:
		var row := _pick_rows[kind] as HBoxContainer
		var names := _pick_list(kind)
		var shown := names.size() > 1
		# Hidden when there is nothing to pick; the rows' room under the stage
		# is kept (PICKS_HEIGHT), so the stage does not jump.
		row.visible = shown
		for button in [row.get_node("Back"), row.get_node("Next")]:
			(button as Button).disabled = not shown
		if shown:
			var index := clampi(int(_chosen_rig().get(StringName(kind))), 0, names.size() - 1)
			(row.get_node("Name") as Label).text = "%s:  %s    %d / %d" % [
					{"face": "LOOK", "tint": "COLOUR"}.get(kind, kind.to_upper()), String(names[index]).to_upper(),
					index + 1, names.size()]


## Turns whoever is on the stage as the mouse is dragged across it (either
## button), or a finger across a touch screen.
func _on_stage_input(event: InputEvent) -> void:
	var across := 0.0
	var motion := event as InputEventMouseMotion
	if motion != null and motion.button_mask & (MOUSE_BUTTON_MASK_LEFT | MOUSE_BUTTON_MASK_RIGHT):
		across = motion.relative.x
	var drag := event as InputEventScreenDrag
	if drag != null:
		across = drag.relative.x
	if across == 0.0:
		return
	var full := _stages.get(_chosen) as CharacterPortrait
	if full != null:
		full.spin(across * 0.012)


func _draw_stage(stage: Control) -> void:
	var light := _accent(_chosen)
	var w := stage.size.x
	var h := stage.size.y
	var pulse := 0.5 + 0.5 * sin(_stage_clock * 1.6)
	# A soft shaft of light from above, widening to the floor: one polygon
	# with its colours faded top to bottom, so there are no bands in it.
	var top_half := w * 0.07
	var foot_half := w * 0.4
	var floor_y := h * 0.91
	stage.draw_polygon(PackedVector2Array([
			Vector2(w * 0.5 - top_half, -h * 0.1), Vector2(w * 0.5 + top_half, -h * 0.1),
			Vector2(w * 0.5 + foot_half, floor_y), Vector2(w * 0.5 - foot_half, floor_y)]),
			PackedColorArray([Color(light, 0.0), Color(light, 0.0),
			Color(light, 0.16 + 0.04 * pulse), Color(light, 0.16 + 0.04 * pulse)]))
	# The glow behind them, breathing.
	var heart := Vector2(w * 0.5, h * 0.5)
	for r in range(14, 0, -1):
		stage.draw_circle(heart, w * 0.042 * r, Color(light, 0.018 + 0.008 * pulse))
	# The stone they stand on, lit on its rim, with a halo on the ground.
	var ground := Vector2(w * 0.5, floor_y)
	stage.draw_set_transform(ground, 0.0, Vector2(1.0, 0.22))
	for r in range(8, 0, -1):
		stage.draw_circle(Vector2.ZERO, w * (0.36 + 0.035 * r), Color(light, 0.025 * (1.0 - r / 9.0) + 0.01 * pulse))
	stage.draw_circle(Vector2.ZERO, w * 0.36, Color(0.02, 0.02, 0.03, 0.9))
	stage.draw_circle(Vector2.ZERO, w * 0.3, Color(light, 0.1 + 0.05 * pulse))
	stage.draw_arc(Vector2.ZERO, w * 0.36, 0.0, TAU, 72, Color(light.lightened(0.2), 0.95), 3.0, true)
	stage.draw_arc(Vector2.ZERO, w * 0.43, 0.0, TAU, 72, Color(light, 0.3 + 0.2 * pulse), 1.5, true)
	stage.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Motes drifting up in the light.
	for i in 16:
		var hashed := float(i) * 12.9898
		var x := w * 0.5 + (fmod(sin(hashed) * 43758.5453, 1.0)) * foot_half * 0.8
		var rise := fmod(_stage_clock * (0.06 + 0.02 * (i % 4)) + float(i) / 16.0, 1.0)
		var y := floor_y - rise * h * 0.8
		stage.draw_circle(Vector2(x, y), 1.6 + (i % 3), Color(light.lightened(0.4), 0.5 * (1.0 - rise)))


func _process(delta: float) -> void:
	_stage_clock += delta
	if _page != Page.CHARACTERS:
		return
	var page := _pages.get(Page.CHARACTERS) as Control
	var stage := page.find_child("Stage", true, false) as Control if page != null else null
	if stage != null:
		stage.queue_redraw()


## The right, while the picked hero wears YOUR OWN: what he is made of, a row
## for each kind of part, four tabs of them.
func _maker() -> Control:
	var panel := PanelContainer.new()
	panel.name = "Maker"
	panel.custom_minimum_size = Vector2(PLATE_WIDTH, 0.0)
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	panel.visible = false
	panel.add_theme_stylebox_override("panel", MenuStyle.plate(Vector2(32.0, 28.0)))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	var called := MenuStyle.label("YOUR OWN", MenuStyle.HEADING_SIZE - 6, MenuStyle.CREAM, "title")
	called.name = "Called"
	called.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	column.add_child(called)
	var note := MenuStyle.label("Make him your own: an outfit first, then his face, clothes and arms. "
			+ "Every change is kept.", MenuStyle.BODY_SIZE - 2, MenuStyle.GOLD_DIM)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	column.add_child(note)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 4)
	for tab: String in MAKER_TABS:
		var button := MenuStyle.button(tab, func() -> void: _maker_show(tab), true)
		button.name = "Tab" + tab
		button.custom_minimum_size = Vector2(112.0, 40.0)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.add_theme_font_size_override("font_size", MenuStyle.BODY_SIZE - 1)
		tabs.add_child(button)
		_maker_tabs[tab] = button
	column.add_child(tabs)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0.0, 4.0)
	column.add_child(gap)
	for tab: String in MAKER_TABS:
		for kind: String in MAKER_TABS[tab]:
			column.add_child(_maker_row(kind))
	return panel


func _maker_row(kind: String) -> Control:
	var row := HBoxContainer.new()
	row.name = "Make_" + kind
	row.custom_minimum_size = Vector2(0.0, 40.0)
	row.add_theme_constant_override("separation", 8)
	var what := MenuStyle.label(MAKER_LABELS[kind], MenuStyle.BODY_SIZE - 4, MenuStyle.GOLD, "head")
	what.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	what.custom_minimum_size = Vector2(118.0, 0.0)
	what.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(what)
	var back := _arrow("‹", func() -> void: _maker_step(kind, -1))
	back.name = "Back"
	row.add_child(back)
	var value := MenuStyle.label("", MenuStyle.BODY_SIZE, MenuStyle.CREAM)
	value.name = "Value"
	value.custom_minimum_size = Vector2(250.0, 0.0)
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value.clip_text = true
	row.add_child(value)
	var on := _arrow("›", func() -> void: _maker_step(kind, 1))
	on.name = "Next"
	row.add_child(on)
	if kind in ["skin", "hc", "cloth"]:
		# a swatch to click for each colour, in place of the arrows
		back.visible = false
		on.visible = false
		value.visible = false
		var palette := HBoxContainer.new()
		palette.name = "Palette"
		palette.add_theme_constant_override("separation", 3)
		var count := PolysplitLook.CLOTHS if kind == "cloth" else PolysplitLook.SKINS
		for i in range(1, count + 1):
			var swatch := Button.new()
			swatch.name = "Swatch%d" % i
			swatch.focus_mode = Control.FOCUS_NONE
			swatch.custom_minimum_size = Vector2(22.0 if kind == "cloth" else 34.0, 30.0)
			swatch.tooltip_text = "%s %d" % [MAKER_LABELS[kind], i]
			swatch.pressed.connect(func() -> void: _maker_pick(kind, i))
			palette.add_child(swatch)
		row.add_child(palette)
	if kind == "extra":
		var wear := MenuStyle.button("WEAR", _maker_toggle_extra, true)
		wear.name = "Wear"
		wear.custom_minimum_size = Vector2(96.0, 32.0)
		wear.alignment = HORIZONTAL_ALIGNMENT_CENTER
		wear.add_theme_font_size_override("font_size", MenuStyle.BODY_SIZE - 4)
		row.add_child(wear)
	_maker_rows[kind] = row
	return row


## A colour row's swatch clicked: that colour, on the stage and remembered.
func _maker_pick(kind: String, value: int) -> void:
	if not _making():
		return
	var look: Dictionary = _chosen_rig().call(&"get_look")
	look[kind] = value
	_maker_wear(look)


## The style box a colour swatch is drawn in: its colour (the hair's or the
## skin's half of the texture), gold-edged when it is the one worn.
func _swatch_style(colour: Color, on: bool, hover: bool = false) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = colour
	box.set_corner_radius_all(3)
	box.border_color = UiArt.GOLD_LIGHT if on else (MenuStyle.GOLD if hover else Color(0, 0, 0, 0.8))
	box.set_border_width_all(3 if on else (2 if hover else 1))
	if on:
		box.shadow_color = Color(1.0, 0.8, 0.4, 0.45)
		box.shadow_size = 5
	return box


## Whether the picked hero wears YOUR OWN.
func _making() -> bool:
	var model := _chosen_rig()
	if model == null or not model.has_method(&"get_look"):
		return false
	var all: Array = model.get(&"faces")
	var at := int(model.get(&"face"))
	return at < all.size() and all[at] == SkinnedRig.CUSTOM


## What can be picked of `kind` for the picked hero in `look`.
func _maker_options(kind: String, look: Dictionary) -> Array:
	var g := String(look.get("g", "m"))
	match kind:
		"cls":
			return PolysplitLook.classes(_ps_hero(), g)
		"g":
			return ["m", "f"]
		"eyes", "brows", "mouth":
			return range(5)
		"beard":
			return range(9) if g == "m" else []
		"hair":
			return range(15)
		"skin":
			return PolysplitLook.skins(String(look.get("race", "")))
		"hc":
			return range(1, PolysplitLook.SKINS + 1)
		"cloth":
			return range(1, PolysplitLook.CLOTHS + 1)
		"top", "bottom":
			# his own classes' clothes only; hats and arms are free
			return PolysplitLook.classes(_ps_hero(), g)
		"extra":
			return PolysplitLook.extras(_ps_hero(), g)
		"hat":
			var hats: Array = [""]
			hats.append_array(PolysplitLook.HAT_ORDER)
			return hats
		"w", "o":
			# what the outfit's class holds, the Advanced Weapons in the style picked
			return PolysplitLook.arms(_ps_hero(), String(look.get("cls", "")), kind, String(look.get("ws", "normal")),
					String(look.get("w", "")) if kind == "o" else "")
		"ws":
			return PolysplitLook.STYLES
	return []


func _maker_name(kind: String, value: Variant, look: Dictionary) -> String:
	match kind:
		"cls":
			return PolysplitLook.outfit_name(_ps_hero(), String(look.get("g", "m")), String(value))
		"g":
			return "MAN" if value == "m" else "WOMAN"
		"eyes", "brows", "mouth", "skin", "hc", "cloth":
			return str(int(value) + (1 if kind in ["eyes", "brows", "mouth"] else 0))
		"beard", "hair":
			return "NONE" if int(value) == 0 else str(int(value))
		"top", "bottom":
			return "BARE" if String(value) == "" else \
					PolysplitLook.outfit_name(_ps_hero(), String(look.get("g", "m")), String(value))
		"extra":
			var worn: bool = (look.get("extras", []) as Array).has(value)
			var called := PolysplitLook.extra_name(String(value), _ps_hero(), String(look.get("g", "m")))
			return called if not worn else "◆ %s" % called
		"hat":
			return "NONE" if String(value) == "" else String(PolysplitLook.HATS[value]["name"])
		"w", "o":
			return PolysplitLook.arm_name(String(value))
		"ws":
			return PolysplitLook.STYLE_NAMES.get(value, String(value).to_upper())
	return str(value)


func _maker_show(tab: String) -> void:
	_maker_tab = tab
	_refresh_maker()


## The next (or last) of `kind`, on the stage and remembered. A class dresses
## the hero in its clothes, hat and arms; the body changes the figure.
func _maker_step(kind: String, by: int) -> void:
	var model := _chosen_rig()
	if not _making():
		return
	var look: Dictionary = model.call(&"get_look")
	var options := _maker_options(kind, look)
	if options.is_empty():
		return
	if kind == "extra":
		_extra_at = wrapi(_extra_at + by, 0, options.size())
		_refresh_maker()
		return
	if options.size() < 2:
		return
	var at := options.find(look.get(kind))
	var value: Variant = options[wrapi(at + by, 0, options.size())]
	match kind:
		"cls":
			look = PolysplitLook.dress(look, _ps_hero(), String(value))
		"g":
			look = PolysplitLook.regendered(look, _ps_hero(), String(value))
		_:
			look[kind] = value
	_maker_wear(look)


## Puts the extra the MORE row shows on, or takes it off.
func _maker_toggle_extra() -> void:
	var model := _chosen_rig()
	if not _making():
		return
	var look: Dictionary = model.call(&"get_look")
	var options := _maker_options("extra", look)
	if options.is_empty():
		return
	var id: String = options[clampi(_extra_at, 0, options.size() - 1)]
	var worn: Array = look.get("extras", [])
	if worn.has(id):
		worn.erase(id)
	else:
		worn.append(id)
	look["extras"] = worn
	_maker_wear(look)


func _maker_wear(look: Dictionary) -> void:
	var model := _chosen_rig()
	model.call(&"set_look", look)
	if _game != null and _game.has_method(&"set_look"):
		_game.call(&"set_look", _chosen, model.call(&"get_look"))
	_refresh_maker()


## The maker for the picked hero, if he wears YOUR OWN (the dossier if not);
## the stage's camera close on the face while the face is being made.
func _refresh_maker() -> void:
	var page := _pages.get(Page.CHARACTERS) as Control
	if page == null:
		return
	var making := _making()
	var dossier := page.find_child("Dossier", true, false) as Control
	var maker := page.find_child("Maker", true, false) as Control
	if dossier != null:
		dossier.visible = not making
	if maker != null:
		maker.visible = making
	var full := _stages.get(_chosen) as CharacterPortrait
	if full != null:
		full.frame_close(making and _maker_tab == "FACE")
	if not making:
		return
	for tab: String in _maker_tabs:
		MenuStyle.style_button(_maker_tabs[tab] as Button, tab == _maker_tab, true)
	var called := page.find_child("Called", true, false) as Label
	if called != null:
		called.text = "%s  ·  YOUR OWN" % _profile(_chosen).display_name.to_upper()
	var look: Dictionary = _chosen_rig().call(&"get_look")
	for kind: String in _maker_rows:
		var row := _maker_rows[kind] as HBoxContainer
		row.visible = (MAKER_TABS[_maker_tab] as Array).has(kind)
		var options := _maker_options(kind, look)
		var choice := options.size() > (0 if kind == "extra" else 1)
		row.modulate.a = 1.0 if choice else 0.35
		for button in [row.get_node("Back"), row.get_node("Next")]:
			(button as Button).disabled = not choice
		var value := row.get_node("Value") as Label
		if options.is_empty():
			value.text = "—"
			continue
		var at := clampi(_extra_at, 0, options.size() - 1) if kind == "extra" else maxi(options.find(look.get(kind)), 0)
		value.text = _maker_name(kind, options[at], look)
		if kind in ["eyes", "brows", "mouth", "beard", "hair", "skin", "hc", "cloth"]:
			# which of how many: a bare number says nothing of how far there is to go
			value.text = "NONE" if value.text == "NONE" else "%d / %d" % [at + 1, options.size()]
		if kind in ["w", "o"] and options.size() > 2:
			value.text = "%s  %d/%d" % [value.text, at + 1, options.size()]
		if kind in ["skin", "hc", "cloth"]:
			var texture := "objects" if kind == "cloth" else "body"
			var worn := int(look.get(kind, look.get("skin", 1)))
			for swatch: Button in (row.get_node("Palette") as Container).get_children():
				var i := int(String(swatch.name).trim_prefix("Swatch"))
				var colour := PolysplitLook.swatch(texture, i, kind == "hc")
				swatch.add_theme_stylebox_override("normal", _swatch_style(colour, i == worn))
				swatch.add_theme_stylebox_override("hover", _swatch_style(colour, i == worn, true))
				swatch.add_theme_stylebox_override("pressed", _swatch_style(colour, true))
		if kind == "extra":
			var worn: bool = (look.get("extras", []) as Array).has(options[at])
			(row.get_node("Wear") as Button).text = "TAKE OFF" if worn else "WEAR"
#endregion


## The right: who they are and what picking them means, on the ornate plate.
func _dossier() -> Control:
	var panel := PanelContainer.new()
	panel.name = "Dossier"
	panel.custom_minimum_size = Vector2(PLATE_WIDTH, 0.0)
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	panel.add_theme_stylebox_override("panel", MenuStyle.plate(Vector2(36.0, 30.0)))

	var column := VBoxContainer.new()
	column.name = "Lines"
	column.add_theme_constant_override("separation", 9)
	panel.add_child(column)
	return panel


## Fills the dossier in for whoever is picked. Rebuilt rather than updated: it is
## a dozen small things, cheaper to make than to keep in step.
func _fill_dossier() -> void:
	var page := _pages.get(Page.CHARACTERS) as Control
	if page == null:
		return
	var column := page.find_child("Lines", true, false) as VBoxContainer
	if column == null:
		return
	for old in column.get_children():
		column.remove_child(old)
		old.queue_free()

	var profile := _profile(_chosen)
	var light := _accent(_chosen)
	var called := MenuStyle.label(profile.display_name.to_upper(), MenuStyle.HEADING_SIZE + 8, MenuStyle.CREAM, "title")
	called.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	called.add_theme_color_override("font_shadow_color", Color(light, 0.5))
	called.add_theme_constant_override("shadow_outline_size", 12)
	called.add_theme_constant_override("shadow_offset_x", 0)
	called.add_theme_constant_override("shadow_offset_y", 0)
	column.add_child(called)
	var epithet := MenuStyle.label(EPITHET.get(_chosen, ""), MenuStyle.BODY_SIZE, light.lightened(0.25))
	epithet.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	column.add_child(epithet)
	var arms := MenuStyle.label(_arms(profile), MenuStyle.BODY_SIZE - 3, MenuStyle.GOLD, "head")
	arms.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	column.add_child(arms)
	column.add_child(MenuStyle.ornament(PLATE_WIDTH - 80.0))
	for stat: Array in _stats(profile):
		column.add_child(_bar(stat[0], stat[1], stat[2], light))
	column.add_child(MenuStyle.ornament(PLATE_WIDTH - 80.0))
	var traits := MenuStyle.label(_traits(profile), MenuStyle.BODY_SIZE - 2, MenuStyle.GOLD)
	traits.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	traits.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(traits)
	var blurb := MenuStyle.label(profile.blurb, MenuStyle.BODY_SIZE - 1, MenuStyle.CREAM.darkened(0.2))
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	blurb.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	blurb.custom_minimum_size = Vector2(370.0, 0.0)
	column.add_child(blurb)


## Six bars, each against the best of the roster at it: [name, share, figure].
func _stats(profile: CharacterProfile) -> Array:
	var rows := [
		["POWER", func(p: CharacterProfile) -> float: return p.damage, "%.0f"],
		["VITALITY", func(p: CharacterProfile) -> float: return p.max_health, "%.0f"],
		["STAMINA", func(p: CharacterProfile) -> float: return p.max_stamina, "%.0f"],
		["SPEED", func(p: CharacterProfile) -> float: return p.run_speed, "%.1f m/s"],
		["EVASION", func(p: CharacterProfile) -> float: return p.dash_speed * p.dash_duration, "%.1f m"],
		["CRITICAL", func(p: CharacterProfile) -> float: return p.crit_chance * 100.0, "%.0f%%"],
	]
	var everyone: Array[CharacterProfile] = []
	for id: StringName in (_game.roster() if _game != null else []):
		everyone.append(_profile(id))
	if everyone.is_empty():
		everyone.append(profile)
	var out := []
	for row: Array in rows:
		var measure: Callable = row[1]
		var best := 0.0001
		for other in everyone:
			best = maxf(best, float(measure.call(other)))
		var mine := float(measure.call(profile))
		out.append([row[0], clampf(mine / best, 0.05, 1.0), row[2] % mine])
	return out


## One stat: its name, a bar filled as far as they have of it, and the figure.
func _bar(what: String, share: float, figure: String, light: Color) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var called := MenuStyle.label(what, MenuStyle.BODY_SIZE - 4, MenuStyle.GOLD, "head")
	called.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	called.custom_minimum_size = Vector2(104.0, 0.0)
	row.add_child(called)
	var bar := Control.new()
	bar.custom_minimum_size = Vector2(190.0, 20.0)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.draw.connect(func() -> void:
		var y := bar.size.y * 0.5 - 5.0
		var width := bar.size.x
		var full := width * share
		bar.draw_rect(Rect2(-1, y - 1, width + 2, 12), Color(0, 0, 0, 0.6))
		bar.draw_rect(Rect2(0, y, width, 10), Color(1, 1, 1, 0.05))
		# the fill: dark at its root, bright at its head, a light line on top
		bar.draw_polygon(PackedVector2Array([Vector2(0, y), Vector2(full, y), Vector2(full, y + 10), Vector2(0, y + 10)]),
				PackedColorArray([light.darkened(0.55), light.lightened(0.1), light.darkened(0.1), light.darkened(0.7)]))
		bar.draw_rect(Rect2(0, y, full, 2), Color(light.lightened(0.55), 0.8))
		bar.draw_rect(Rect2(full - 2, y - 1, 2, 12), Color(light.lightened(0.6), 0.9))
		for i in range(1, 5):
			bar.draw_line(Vector2(width * i / 5.0, y), Vector2(width * i / 5.0, y + 10), Color(0, 0, 0, 0.55), 2.0)
		bar.draw_rect(Rect2(-1, y - 1, width + 2, 12), Color(MenuStyle.GOLD_DIM, 0.5), false, 1.0))
	row.add_child(bar)
	var value := MenuStyle.label(figure, MenuStyle.BODY_SIZE - 3, MenuStyle.CREAM)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.custom_minimum_size = Vector2(76.0, 0.0)
	row.add_child(value)
	return row


## What they can do that the others cannot, in a line.
func _traits(profile: CharacterProfile) -> String:
	var bits: Array[String] = []
	if profile.can_block:
		bits.append("blocks and parries")
	if profile.shadow_dodge:
		bits.append("a perfect roll leaves his shadow")
	if profile.levitation > 0.0:
		bits.append("floats %.1f s" % profile.levitation)
	if profile.weapon != CharacterProfile.Weapon.MELEE:
		bits.append("fights from afar")
	if not profile.can_block and profile.weapon == CharacterProfile.Weapon.MELEE:
		bits.append("the quickest hands")
	return "◆  " + "   ◆  ".join(bits)


## What they fight with, in a word or three.
func _arms(profile: CharacterProfile) -> String:
	match profile.weapon:
		CharacterProfile.Weapon.BOW:
			return "LONGBOW"
		CharacterProfile.Weapon.STAFF:
			return "STAFF AND LIGHTNING"
	if profile.display_name.to_lower().contains("warrior"):
		return "GREAT SWORD"
	return "SWORD AND SHIELD" if profile.can_block else "ONE LONG KNIFE"


func _refresh_cards() -> void:
	for key: StringName in _people_buttons:
		var banner := _people_buttons[key] as Button
		var light: Color = PEOPLES[key]["light"]
		var on := key == _people
		var flat := MenuStyle.panel_style(Color(light.darkened(0.78), 0.94) if on else Color(0.03, 0.03, 0.045, 0.7))
		flat.set_corner_radius_all(3)
		flat.border_color = light if on else Color(MenuStyle.GOLD_DIM, 0.35)
		flat.set_border_width_all(1)
		flat.border_width_bottom = 3 if on else 1
		if on:
			flat.shadow_color = Color(light, 0.35)
			flat.shadow_size = 10
		var lit := flat.duplicate() as StyleBoxFlat
		lit.border_color = light
		banner.add_theme_stylebox_override("normal", flat)
		banner.add_theme_stylebox_override("focus", flat)
		banner.add_theme_stylebox_override("hover", lit)
		banner.add_theme_stylebox_override("pressed", lit)
		banner.add_theme_color_override("font_color", light.lightened(0.35) if on else MenuStyle.GOLD_DIM)
		banner.add_theme_color_override("font_hover_color", light.lightened(0.5))
	for id: StringName in _cards:
		(_cards[id] as Control).visible = _profile(id).people == _people
	for id: StringName in _cards:
		var card := _cards[id] as Button
		var picked := id == _chosen
		var light := _accent(id)
		var style := MenuStyle.panel_style(Color(0.03, 0.03, 0.045, 0.78) if not picked
				else Color(light.darkened(0.72), 0.94))
		style.set_content_margin_all(0.0)
		style.set_corner_radius_all(3)
		style.border_color = light if picked else Color(MenuStyle.GOLD_DIM, 0.4)
		style.set_border_width_all(1)
		style.border_width_left = 5 if picked else 1
		if picked:
			style.shadow_color = Color(light, 0.4)
			style.shadow_size = 14
		var hover := style.duplicate() as StyleBoxFlat
		hover.border_color = light
		card.add_theme_stylebox_override("normal", style)
		card.add_theme_stylebox_override("focus", style)
		card.add_theme_stylebox_override("hover", hover)
		card.add_theme_stylebox_override("pressed", hover)
		var face := card.find_child("Face", true, false) as Control
		if face != null:
			face.modulate = Color.WHITE if picked else Color(0.62, 0.62, 0.66)
		var caption := card.find_child("Name", true, false) as Label
		if caption != null:
			caption.add_theme_color_override("font_color", light.lightened(0.45) if picked else MenuStyle.CREAM.darkened(0.25))
		var what := card.find_child("Arms", true, false) as Label
		if what != null:
			what.add_theme_color_override("font_color", MenuStyle.GOLD if picked else MenuStyle.GOLD_DIM)
	for id: StringName in _stages:
		(_stages[id] as Control).visible = id == _chosen
	var page := _pages.get(Page.CHARACTERS) as Control
	if page != null:
		var stage := page.find_child("Stage", true, false) as Control
		if stage != null:
			stage.queue_redraw()
	_fill_dossier()
	# The rig fills its list of hair in when it enters the tree, which may be
	# after this.
	_refresh_picks.call_deferred()


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
		# A solo game in the world opens with the story ([Intro]).
		_game.set(&"story_pending", not _arena)
	# A solo game is a game with nobody else in it, which is not the same as a
	# game with a peer left over from last time still holding a socket open.
	if _net != null:
		_net.call("leave")
	get_tree().change_scene_to_file(ARENA if _arena else WORLD)


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


## Rebuilds the list of games heard on the network.
func _refresh_found() -> void:
	if _found == null or _net == null:
		return
	for child in _found.get_children():
		child.queue_free()
	var games: Dictionary = _net.get("games")
	for address: String in games:
		var game: Dictionary = games[address]
		var full := int(game["players"]) >= int(game["max"])
		var text := "JOIN %s  ·  %d/%d  ·  %s" % [String(game["name"]).to_upper(),
				int(game["players"]), int(game["max"]), address]
		var button := MenuStyle.button(text, func() -> void:
				_address.text = address
				_join())
		button.custom_minimum_size = Vector2(520.0, MenuStyle.BUTTON_HEIGHT)
		if not bool(game["same_version"]):
			button.text = "%s  ·  %s (different version)" % [String(game["name"]), address]
			button.disabled = true
		elif full:
			button.disabled = true
		_found.add_child(button)
	if _found_note != null:
		_found_note.text = "Looking... (the host must press HOST GAME first)" if games.is_empty() else ""


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
	var shown: String = _game.display() if _game != null else "window"
	for key: String in _display_buttons:
		var button := _display_buttons[key] as Button
		MenuStyle.style_button(button, key == shown)
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER


func _set_display(key: String) -> void:
	if _game != null:
		_game.set_display(key)
	_refresh_graphics()
#endregion


