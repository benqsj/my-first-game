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
## A solo game in the open world without its camps: the creatures are behind
## the five gates now ([Portals], portal_dungeons_plan.md). Set by the menu.
var peaceful: bool = false
## Which dungeon is being loaded ([Dungeon]), -1 for none.
var dungeon_id: int = -1
## A dungeon place to be put straight into on loading it, to look round
## (F1's "Rooms", [ArenaPanel]): "" for the run as usual.
var view_place: String = ""
## Which gate the hero comes back out by, -1 for the usual spawn.
var portal_return: int = -1
## Brought into a dungeon late, through the door the others are taking
## ([method Net.bring_waiting]): the place to be built first instead of the
## first step's ({step, place, reward, cursed, goal, plan, lore_put}).
var join_at: Dictionary = {}
## The dungeons closed (index -> true), and each hero's best level so far
## (id -> level): what he has outside the dungeons. Kept between runs (the
## user's word, 2026-10-21: what is won in a dungeon is his for good).
var closed_portals: Dictionary = {}
var best_level: Dictionary = {}
## The prisoners freed in the dungeons (their keys, [Dungeon]): each one
## comes to live in the village. Kept between runs.
var freed: Array[String] = []
## His gold, kept for good (the user's word, 2026-10-27: all with gold now,
## no more orcs' tusks): what his [Purse] gains and loses is added here, and
## a new world's purse starts from it. What he has bought with it of the
## freed men's trades (trade -> level, [Trades]).
var gold: int = 0
var trade_levels: Dictionary = {}
## Runs through the portals, the ones won, and the fastest win (s, 0: none).
var runs: int = 0
var wins: int = 0
var best_time: float = 0.0
## The palace's story read so far ([LoreStone]), and how often he has stood
## before the orc lord and how often the lord has beaten him ([LordFight]).
var lore_read: int = 0
var lord_met: int = 0
var lord_beat: int = 0


## Dungeon `index` is closed: its gate is marked, and the hero keeps its last level.
func close_portal(index: int) -> void:
	closed_portals[index] = true
	var top := int(Portals.DEFS[clampi(index, 0, Portals.DEFS.size() - 1)]["to"])
	best_level[_chosen] = maxi(int(best_level.get(_chosen, 1)), top)
	_save_settings()


## His own hero's purse changed by `by` ([World] hooks it up).
func gold_changed(by: int) -> void:
	if by == 0:
		return
	gold = maxi(gold + by, 0)
	_save_settings()


func read_lore() -> void:
	lore_read += 1
	_save_settings()


func meet_lord() -> void:
	lord_met += 1
	_save_settings()


func beaten_by_lord() -> void:
	lord_beat += 1
	_save_settings()


## A run ended ([RunSummary]): counted, and its time against the best.
func end_run(won: bool, seconds: float) -> Dictionary:
	runs += 1
	var new_best := false
	if won:
		wins += 1
		if best_time <= 0.0 or seconds < best_time:
			new_best = best_time > 0.0
			best_time = seconds
	_save_settings()
	return {"runs": runs, "wins": wins, "best": best_time, "new_best": new_best}


## The next level of `trade` bought, if it is open and he has the gold; his
## purse (`purse`, shown on the screen) paid out of too.
func buy_trade(trade: String, purse: Purse = null) -> bool:
	if not Trades.open(self, trade):
		return false
	var price := Trades.cost(self, trade)
	if price < 0 or gold < price:
		return false
	gold -= price
	if purse != null:
		# (set, not taken: the bank is paid above, once)
		purse.gold = maxi(purse.gold - price, 0)
		purse.changed.emit(purse.gold, 0)
	trade_levels[trade] = int(trade_levels.get(trade, 0)) + 1
	_save_settings()
	return true


## A prisoner freed in a dungeon (`who`): he will be in the village from now on.
func free_prisoner(who: String) -> void:
	if who == "" or freed.has(who):
		return
	freed.append(who)
	_save_settings()
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
## What each hero has found and carries ([method Player.gain]): item keys
## ([method Inventory.key_of]), by the hero's id.
var _owned: Dictionary = {}
var _worn: Dictionary = {}
var _graphics: Graphics.Level = Graphics.Level.HIGH
## Every hero's profile, once loaded, kept for the run ([method profile_of]).
var _profiles: Dictionary = {}
## How the game sits on the screen: one of [constant DISPLAYS]'s keys.
var _display: String = "window"
## The rest of the settings page (release_polish_plan §3): the screen's sync,
## a cap on frames a second (0: none), and how loud all of it and the music
## are (0..1).
var _vsync: bool = true
var _fps_cap: int = 0
var _volume: float = 1.0
var _music_volume: float = 1.0
## The frame caps offered, in order (0: none).
const FPS_CAPS: Array[int] = [30, 60, 120, 0]

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


## A timing probe for the exported game (release_polish_plan.md §1.1): an
## export template takes no `--script`, so `VEPXIS_PROBE=/abs/path.gd` names a
## GDScript (extends Node) that is compiled here and put beside the scenes,
## outliving them. Nobody sets it but the measuring scripts.
func _start_probe() -> void:
	var path := OS.get_environment("VEPXIS_PROBE")
	if path == "" or not FileAccess.file_exists(path):
		return
	var code := GDScript.new()
	code.source_code = FileAccess.get_file_as_string(path)
	if code.reload() != OK:
		push_error("Game: the probe %s did not compile." % path)
		return
	var probe := Node.new()
	probe.set_script(code)
	probe.name = "Probe"
	get_tree().root.add_child.call_deferred(probe)


func _ready() -> void:
	Controls.apply()
	# a companion who joins fights the host's fight ([method set_fight_quick])
	multiplayer.peer_connected.connect(func(id: int) -> void:
		if multiplayer.is_server():
			net_fight.rpc_id(id, Player.action_souls))
	# Closing is ours to decide: see `_notification`.
	get_tree().set_auto_accept_quit(false)
	_load_settings()
	_apply_display()
	_apply_frames()
	_apply_volumes.call_deferred()
	_start_probe()
	var argv := OS.get_cmdline_user_args()
	var connect_as := ""
	var address := "127.0.0.1"
	var relay := ""
	for at in argv.size():
		var word: String = argv[at]
		var id := StringName(word.to_lower())
		if CHARACTERS.has(id):
			_chosen = id
		elif word == "--host":
			connect_as = "host"
		elif word == "--host-online":
			connect_as = "host_online"
		elif word == "--join-code" and at + 1 < argv.size():
			connect_as = "join_code"
			address = argv[at + 1]
		elif word == "--relay" and at + 1 < argv.size():
			relay = argv[at + 1]
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
	_start_loading_profiles()
	if connect_as != "":
		# Deferred: the other autoloads are not up yet, and neither is anything
		# to change scene *to*.
		_auto_connect.call_deferred(connect_as, address, relay)


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
func _auto_connect(how: String, address: String, relay: String = "") -> void:
	var net := get_node_or_null("/root/Net")
	if net == null:
		push_error("Game: asked to %s, but there is no Net autoload." % how)
		return
	if relay != "":
		net.set(&"relay_url", relay)
	match how:
		"host":
			net.call("host", _chosen)
		"host_online":
			net.call("host_online", _chosen)
		"join_code":
			net.call("join_code", address, _chosen)
		_:
			net.call("join", address, _chosen)


## Who is being played, as an id.
func character() -> StringName:
	return _chosen


## And everything that is known about them. Never null: an id that has lost its
## resource falls back to the default rather than handing back nothing.
func profile() -> CharacterProfile:
	var found := profile_of(_chosen)
	if found == null:
		push_error("Game: '%s' has no usable profile." % _chosen)
		found = profile_of(DEFAULT)
	return found


## `id`'s profile (the default's for an id that is not a hero), loaded once and
## kept.
##
## Kept, because a profile carries its hero's whole model (`visuals`) and
## nothing else holds on to one between uses: loaded loose, every `load()` read
## the model off the disk again, 0.3-0.4 s for each of the elves. The menu asked
## for all ten dozens of times over — the roster, every tile, every refresh —
## and that was most of the ten seconds and more it took to come up.
func profile_of(id: StringName) -> CharacterProfile:
	if not CHARACTERS.has(id):
		id = DEFAULT
	var found := _profiles.get(id) as CharacterProfile
	if found != null:
		return found
	var path: String = CHARACTERS[id]
	# Whatever is on its way in now is waited for first, ours or not: a second
	# load of the rig it shares with ours, side by side with it, is the hang
	# [method _start_loading_profiles] is about.
	if _loading != &"":
		var was := _loading
		var got := ResourceLoader.load_threaded_get(CHARACTERS[was]) as CharacterProfile
		_loading = &""
		if got != null and not _profiles.has(was):
			_profiles[was] = got
		found = _profiles.get(id) as CharacterProfile
	if found == null:
		found = load(path) as CharacterProfile
	if found != null:
		_profiles[id] = found
	return found


## Whether every hero's profile is in (the level waits for that: see
## [SceneLoader]).
func profiles_ready() -> bool:
	return _loading == &"" and _queue.is_empty()


## The profiles still to come in the background, and the one coming now.
var _queue: Array[StringName] = []
var _loading: StringName = &""


## Starts the profiles loading in the background, so that by the time the
## player has got as far as choosing a hero they are mostly in already.
##
## One at a time, on one worker, without sub-threads: four of the heroes share
## Tariel's rig (`tariel_rigged.glb`), and ten requests at once, each with its
## own sub-threads, had several threads loading that one file together ("Another
## resource is loaded from path ... possible cyclic resource inclusion") and could
## leave the loader waiting on itself for good — the main thread stuck in a
## `load()` of a profile that never finished, the game hung on its loading
## screen (the user's word, the v5 world, 2026-10-08).
func _start_loading_profiles() -> void:
	_queue.clear()
	for id: StringName in CHARACTERS:
		_queue.append(id)
	set_process(true)


func _process(_delta: float) -> void:
	if _loading != &"":
		var path: String = CHARACTERS[_loading]
		if ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			return
		var got := ResourceLoader.load_threaded_get(path) as CharacterProfile
		if got != null and not _profiles.has(_loading):
			_profiles[_loading] = got
		_loading = &""
	while not _queue.is_empty():
		var id: StringName = _queue.pop_front()
		if _profiles.has(id):
			continue
		if ResourceLoader.load_threaded_request(CHARACTERS[id], "", false) == OK:
			_loading = id
			return
	set_process(false)


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


## What hero `id` has on and in his hands now (the bag's choices: his look
## and outfit), kept from one level to the next (the user's word, 2026-10-20:
## what he took up in the land did not come with him into the dungeon).
func worn(id: StringName) -> Dictionary:
	return (_worn.get(id, {}) as Dictionary).duplicate(true)


func set_worn(id: StringName, made: Dictionary, garb: int) -> void:
	_worn[id] = {"look": made.duplicate(true), "garb": garb}
	# and for good (the user's word, 2026-10-21: the lord's sword his for
	# good, not for the session)
	_save_settings()


## What hero `id` has found and carries (item keys, [method Inventory.key_of]).
func owned(id: StringName) -> Array:
	return (_owned.get(id, []) as Array).duplicate()


## Remembers what hero `id` carries.
func set_owned(id: StringName, keys: Array) -> void:
	_owned[id] = keys.duplicate()
	_save_settings()


## Every character offered on the hero select, in their order: those of a
## people ([member CharacterProfile.people]). One of none (the mage, kept for
## the command line and the tests, 2026-10-05) is not offered.
func roster() -> Array[StringName]:
	var ids: Array[StringName] = []
	for id: StringName in CHARACTERS:
		var profile := profile_of(id)
		if profile != null and profile.people != &"":
			ids.append(id)
	return ids


#region Settings
## The fight he picked ([member Player.action_souls]): the old souls one or
## the quicker one (the user's word, 2026-10-29: chosen before the game, or
## F3 in it). Online the host's is the one in force.
var _fight_quick_own: bool = false


func fight_quick() -> bool:
	return Player.action_souls


## False when a companion (not the host) asks: the host's fight is the one.
func set_fight_quick(on: bool) -> bool:
	var online := multiplayer.has_multiplayer_peer() \
			and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED
	if online and not multiplayer.is_server():
		return false
	_fight_quick_own = on
	Player.action_souls = on
	_save_settings()
	if online:
		net_fight.rpc(on)
	return true


## Out of a game online: his own fight again.
func restore_fight() -> void:
	Player.action_souls = _fight_quick_own


## The host's fight, on a companion's game (not kept: his own comes back
## when he leaves, [method restore_fight]).
@rpc("authority", "call_remote", "reliable")
func net_fight(on: bool) -> void:
	Player.action_souls = on


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


## The setting a first run starts on, by the graphics chip: Ultra on a
## desktop card (an NVIDIA RTX, an AMD RX 6000 or later), High on Apple's
## larger chips and anything after the M2, Medium on a base M1/M2 and on
## what is not known, Low on Intel's own graphics.
static func suggested_graphics() -> Graphics.Level:
	var chip := RenderingServer.get_video_adapter_name().to_lower()
	if chip.contains("rtx") or chip.contains("rx 6") or chip.contains("rx 7") or chip.contains("rx 9"):
		return Graphics.Level.ULTRA
	if chip.contains("intel"):
		return Graphics.Level.LOW
	if chip.begins_with("apple m"):
		var big := chip.contains("pro") or chip.contains("max") or chip.contains("ultra")
		var later := not (chip.begins_with("apple m1") or chip.begins_with("apple m2"))
		return Graphics.Level.HIGH if big or later else Graphics.Level.MEDIUM
	return Graphics.Level.MEDIUM


func vsync() -> bool:
	return _vsync


func fps_cap() -> int:
	return _fps_cap


func volume() -> float:
	return _volume


func music_volume() -> float:
	return _music_volume


func set_vsync(on: bool) -> void:
	_vsync = on
	_apply_frames()
	_save_settings()


func set_fps_cap(cap: int) -> void:
	_fps_cap = maxi(cap, 0)
	_apply_frames()
	_save_settings()


## How loud: all of it (`which` "volume") or the music ("music"), 0..1.
## Applied at once; stored when `keep` (a slider stores as it is let go).
func set_volume(which: String, level: float, keep: bool = true) -> void:
	if which == "music":
		_music_volume = clampf(level, 0.0, 1.0)
	else:
		_volume = clampf(level, 0.0, 1.0)
	_apply_volumes()
	if keep:
		_save_settings()


func _apply_frames() -> void:
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if _vsync else DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = _fps_cap


func _apply_volumes() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(_volume, 0.0001)))
	AudioServer.set_bus_mute(0, _volume <= 0.001)
	var music := get_node_or_null(^"/root/Music")
	if music != null and music.has_method(&"set_loudness"):
		music.call(&"set_loudness", _music_volume)


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
		# the very first run: a setting the machine can hold, not the
		# designed one (a tester's base M1 at High was the stall he met first)
		_graphics = suggested_graphics()
		return
	var level := int(file.get_value("video", "graphics", -1))
	_graphics = Graphics.from_int(level) if level >= 0 else suggested_graphics()
	_fight_quick_own = bool(file.get_value("game", "action_souls", false))
	Player.action_souls = _fight_quick_own
	_vsync = bool(file.get_value("video", "vsync", true))
	_fps_cap = int(file.get_value("video", "fps_cap", 0))
	_volume = clampf(float(file.get_value("audio", "volume", 1.0)), 0.0, 1.0)
	_music_volume = clampf(float(file.get_value("audio", "music", 1.0)), 0.0, 1.0)
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
	if file.has_section("owned"):
		for key in file.get_section_keys("owned"):
			var keys: Variant = file.get_value("owned", key, [])
			if keys is Array:
				_owned[StringName(key)] = keys
	# what he wears and how far he has come: not for the tests, which start
	# from nothing every time
	if Inventory.under_test():
		return
	if file.has_section("worn"):
		for key in file.get_section_keys("worn"):
			var made: Variant = file.get_value("worn", key, {})
			if made is Dictionary:
				_worn[StringName(key)] = made
	var closed: Variant = file.get_value("progress", "closed", [])
	if closed is Array:
		for index: Variant in closed:
			closed_portals[int(index)] = true
	var best: Variant = file.get_value("progress", "best_level", {})
	if best is Dictionary:
		for key: Variant in best:
			best_level[StringName(String(key))] = int(best[key])
	var out: Variant = file.get_value("progress", "freed", [])
	if out is Array:
		for who: Variant in out:
			freed.append(String(who))
	gold = int(file.get_value("progress", "gold", 0))
	runs = int(file.get_value("progress", "runs", 0))
	wins = int(file.get_value("progress", "wins", 0))
	best_time = float(file.get_value("progress", "best_time", 0.0))
	lore_read = int(file.get_value("progress", "lore_read", 0))
	lord_met = int(file.get_value("progress", "lord_met", 0))
	lord_beat = int(file.get_value("progress", "lord_beat", 0))
	var levels: Variant = file.get_value("progress", "trades", {})
	if levels is Dictionary:
		for key: Variant in levels:
			trade_levels[String(key)] = int(levels[key])


func _save_settings() -> void:
	var file := ConfigFile.new()
	# over what is there: a test run leaves what he wears and has won alone
	file.load(SETTINGS)
	file.set_value("video", "graphics", int(_graphics))
	file.set_value("game", "action_souls", _fight_quick_own)
	file.set_value("video", "display", _display)
	file.set_value("video", "vsync", _vsync)
	file.set_value("video", "fps_cap", _fps_cap)
	file.set_value("audio", "volume", _volume)
	file.set_value("audio", "music", _music_volume)
	for id: StringName in _hairs:
		file.set_value("hair", String(id), int(_hairs[id]))
	for id: StringName in _faces:
		file.set_value("face", String(id), int(_faces[id]))
	for id: StringName in _tints:
		file.set_value("tint", String(id), int(_tints[id]))
	for id: StringName in _looks:
		file.set_value("look", String(id), _looks[id])
	for id: StringName in _owned:
		file.set_value("owned", String(id), _owned[id])
	if not Inventory.under_test():
		for id: StringName in _worn:
			file.set_value("worn", String(id), _worn[id])
		file.set_value("progress", "closed", closed_portals.keys())
		var best := {}
		for id: StringName in best_level:
			best[String(id)] = int(best_level[id])
		file.set_value("progress", "best_level", best)
		file.set_value("progress", "freed", freed)
		file.set_value("progress", "gold", gold)
		file.set_value("progress", "runs", runs)
		file.set_value("progress", "wins", wins)
		file.set_value("progress", "best_time", best_time)
		file.set_value("progress", "lore_read", lore_read)
		file.set_value("progress", "lord_met", lord_met)
		file.set_value("progress", "lord_beat", lord_beat)
		file.set_value("progress", "trades", trade_levels)
	file.save(SETTINGS)
#endregion
