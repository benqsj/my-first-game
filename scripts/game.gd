extends Node

## What the game knows before a level loads: who is being played.
##
## An autoload rather than something passed in, because the choice is made on a
## screen that is gone by the time the world exists. The world simply asks.
##
## The character can also be named on the command line, which is how a test — or
## anyone who has not built the menu yet — plays somebody other than the default:
##
##     godot --path . -- avtandil

const CHARACTERS := {
	&"tariel": "res://scenes/player/tariel.tres",
	&"avtandil": "res://scenes/player/avtandil.tres",
	&"mage": "res://scenes/player/mage.tres",
	&"rogue": "res://scenes/player/rogue.tres",
	&"warrior": "res://scenes/player/warrior.tres",
	# the elves and the dark elves (2026-10-05): the archer's, the mage's and
	# the assassin's rigs, worn as YOUR OWN of their people
	&"elf_archer": "res://scenes/player/elf_archer.tres",
	&"elf_mage": "res://scenes/player/elf_mage.tres",
	&"dark_archer": "res://scenes/player/dark_archer.tres",
	&"dark_mage": "res://scenes/player/dark_mage.tres",
	&"dark_rogue": "res://scenes/player/dark_rogue.tres",
}
const DEFAULT := &"tariel"

## Where the settings live between runs.
const SETTINGS := "user://settings.cfg"

## Emitted when the choice changes, so a menu can show it without polling.
signal character_changed(id: StringName)
signal graphics_changed(level: Graphics.Level)

var _chosen: StringName = DEFAULT
## A new story to begin: the menu's Start sets it for a solo game, and the
## level's [Intro] takes it (and clears it) to play the opening film.
var story_pending: bool = false
## Each hero's hair, picked on the hero select: id -> an index into the rig's
## `hairs`. Remembered between runs.
var _hairs: Dictionary = {}
## And each hero's face: id -> an index into their rig's `faces`.
var _faces: Dictionary = {}
## And the colour each hero's clothes are dyed: id -> an index into their
## rig's `TINTS` (only THE NIGHT ELF has any).
var _tints: Dictionary = {}
## And the look each hero was made into on the hero select ([PolysplitLook]):
## id -> the look, worn while their face is YOUR OWN.
var _looks: Dictionary = {}
var _graphics: Graphics.Level = Graphics.Level.HIGH
## How the game sits on the screen: one of [constant DISPLAYS]'s keys.
var _display: String = "window"

## The choices: a window of the size it opened at, bigger windows, or the whole
## screen. The pictures scale with the window (stretch mode `canvas_items`), so
## these decide how many pixels the game has, not how big the menus are.
const DISPLAYS := {
	"window": Vector2i(1600, 900),
	"1280x720": Vector2i(1280, 720),
	"1920x1080": Vector2i(1920, 1080),
	"2560x1440": Vector2i(2560, 1440),
	"fullscreen": Vector2i.ZERO,
}


func _ready() -> void:
	Controls.apply()
	# Closing is ours to decide: see `_notification`.
	get_tree().set_auto_accept_quit(false)
	_load_settings()
	_apply_display()
	var argv := OS.get_cmdline_user_args()
	var connect_as := ""
	var address := "127.0.0.1"
	for at in argv.size():
		var word: String = argv[at]
		var id := StringName(word.to_lower())
		if CHARACTERS.has(id):
			_chosen = id
		elif word == "--host":
			connect_as = "host"
		elif word == "--join":
			connect_as = "join"
			# The next word is the address, unless it is a character name or
			# another switch — `--join avtandil` means "join the default address
			# playing the archer", which is the shorter thing to type.
			if at + 1 < argv.size():
				var next: String = argv[at + 1]
				if not next.begins_with("--") and not CHARACTERS.has(StringName(next.to_lower())):
					address = next
	Graphics.apply(get_tree(), _graphics)
	if connect_as != "":
		# Deferred: the other autoloads are not up yet, and neither is anything
		# to change scene *to*.
		_auto_connect.call_deferred(connect_as, address)


## Command is the evade on a Mac, and Q puts the weapons away — so Command-Q
## happens in a fight, and must not quit the game from under the player. Out of
## a fight, or any other way of closing the window, closes it.
func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_CLOSE_REQUEST:
		return
	var in_play := get_tree().current_scene is World
	if in_play and Controls.is_mac() and Input.is_key_pressed(KEY_META) and Input.is_physical_key_pressed(KEY_Q):
		return
	get_tree().quit()


## Straight into a game from the command line, skipping the menu. This is how
## two windows on one machine become a host and a client without anybody
## clicking anything:
##
##     godot --path . -- --host tariel
##     godot --path . -- --join 127.0.0.1 avtandil
func _auto_connect(how: String, address: String) -> void:
	var net := get_node_or_null("/root/Net")
	if net == null:
		push_error("Game: asked to %s, but there is no Net autoload." % how)
		return
	if how == "host":
		net.call("host", _chosen)
	else:
		net.call("join", address, _chosen)


## Who is being played, as an id.
func character() -> StringName:
	return _chosen


## And everything that is known about them. Never null: an id that has lost its
## resource falls back to the default rather than handing back nothing.
func profile() -> CharacterProfile:
	var found := load(CHARACTERS.get(_chosen, CHARACTERS[DEFAULT])) as CharacterProfile
	if found == null:
		push_error("Game: '%s' has no usable profile." % _chosen)
		found = load(CHARACTERS[DEFAULT]) as CharacterProfile
	return found


## Picks a character. Takes effect the next time a level is loaded, which is
## what a menu wants: choosing is not the same as spawning.
func choose(id: StringName) -> void:
	if not CHARACTERS.has(id) or id == _chosen:
		return
	_chosen = id
	character_changed.emit(id)


## Which hair `id` wears (an index into their rig's `hairs`; 0 if never picked).
func hair(id: StringName) -> int:
	return int(_hairs.get(id, 0))


## Picks `id`'s hair, and remembers it.
func set_hair(id: StringName, index: int) -> void:
	_hairs[id] = index
	_save_settings()


## Which face `id` wears (an index into their rig's `faces`; 0 if never picked).
func face(id: StringName) -> int:
	return int(_faces.get(id, 0))


## Picks `id`'s face, and remembers it.
func set_face(id: StringName, index: int) -> void:
	_faces[id] = index
	_save_settings()


## Which colour `id`'s clothes are dyed (0, as they came, if never picked).
func tint(id: StringName) -> int:
	return int(_tints.get(id, 0))


## Dyes `id`'s clothes, and remembers it.
func set_tint(id: StringName, index: int) -> void:
	_tints[id] = index
	_save_settings()


## The look `id` was made into on the hero select (empty if never made).
func look(id: StringName) -> Dictionary:
	return (_looks.get(id, {}) as Dictionary).duplicate(true)


## Remembers `id`'s look.
func set_look(id: StringName, made: Dictionary) -> void:
	_looks[id] = made.duplicate(true)
	_save_settings()


## Every character there is, in the order they should be offered.
func roster() -> Array[StringName]:
	var ids: Array[StringName] = []
	for id: StringName in CHARACTERS:
		ids.append(id)
	return ids


#region Settings
## Which graphics setting is in force.
func graphics() -> Graphics.Level:
	return _graphics


## Changes it, applies it to whatever is loaded, and remembers it. Applying and
## storing together, because a setting that takes effect but is forgotten by the
## next run is a setting the player has to find twice.
func set_graphics(level: Graphics.Level) -> void:
	_graphics = level
	Graphics.apply(get_tree(), _graphics)
	_save_settings()
	graphics_changed.emit(_graphics)


## Puts the current setting onto a level that has just loaded. The world does
## not know about any of this; whoever spawns into it asks for it.
func apply_graphics() -> void:
	Graphics.apply(get_tree(), _graphics)


## Which display setting is in force, as a key of [constant DISPLAYS].
func display() -> String:
	return _display


func set_display(key: String) -> void:
	if not DISPLAYS.has(key):
		return
	_display = key
	_apply_display()
	_save_settings()


func _apply_display() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var window := get_window()
	if window == null:
		return
	if _display == "fullscreen":
		window.mode = Window.MODE_FULLSCREEN
		return
	if window.mode == Window.MODE_FULLSCREEN or window.mode == Window.MODE_EXCLUSIVE_FULLSCREEN:
		window.mode = Window.MODE_WINDOWED
	# "window" is the window as it opened, left alone (the editor may be
	# holding it); only a size the player picked moves it.
	if _display == "window":
		return
	window.mode = Window.MODE_WINDOWED
	var want: Vector2i = DISPLAYS[_display]
	# Never bigger than the screen it is on.
	var screen := DisplayServer.screen_get_usable_rect(window.current_screen)
	want = Vector2i(mini(want.x, screen.size.x), mini(want.y, screen.size.y))
	window.size = want
	window.position = screen.position + Vector2i(Vector2(screen.size - want) * 0.5)


func _load_settings() -> void:
	var file := ConfigFile.new()
	if file.load(SETTINGS) != OK:
		return
	var level := int(file.get_value("video", "graphics", Graphics.Level.HIGH))
	_graphics = Graphics.from_int(level)
	var shown := String(file.get_value("video", "display", "window"))
	_display = shown if DISPLAYS.has(shown) else "window"
	if file.has_section("hair"):
		for key in file.get_section_keys("hair"):
			_hairs[StringName(key)] = int(file.get_value("hair", key, 0))
	if file.has_section("face"):
		for key in file.get_section_keys("face"):
			_faces[StringName(key)] = int(file.get_value("face", key, 0))
	if file.has_section("tint"):
		for key in file.get_section_keys("tint"):
			_tints[StringName(key)] = int(file.get_value("tint", key, 0))
	if file.has_section("look"):
		for key in file.get_section_keys("look"):
			var made: Variant = file.get_value("look", key, {})
			if made is Dictionary:
				_looks[StringName(key)] = made


func _save_settings() -> void:
	var file := ConfigFile.new()
	file.set_value("video", "graphics", int(_graphics))
	file.set_value("video", "display", _display)
	for id: StringName in _hairs:
		file.set_value("hair", String(id), int(_hairs[id]))
	for id: StringName in _faces:
		file.set_value("face", String(id), int(_faces[id]))
	for id: StringName in _tints:
		file.set_value("tint", String(id), int(_tints[id]))
	for id: StringName in _looks:
		file.set_value("look", String(id), _looks[id])
	file.save(SETTINGS)
#endregion
