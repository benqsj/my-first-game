extends SceneTree

## Headless checks for the front end: the menu's pages, what choosing a
## character does, and what the graphics setting actually changes.
##
##     godot --path . --headless --script res://tests/menu_test.gd

const MENU := "res://scenes/ui/main_menu.tscn"
const WORLD := "res://scenes/world/greybox_world.tscn"

var _failures := 0
var _game: Node


func _initialize() -> void:
	# Autoloads are nodes under the root; the global identifier for one is not
	# resolved when a --script main loop is compiled.
	_game = root.get_node_or_null("Game")
	await _check_menu()
	await _check_graphics()
	await _check_pause()

	print("")
	if _failures == 0:
		print("All checks passed.")
	else:
		print("%d check(s) FAILED." % _failures)
	quit(1 if _failures > 0 else 0)


func _check_menu() -> void:
	var menu: Control = load(MENU).instantiate()
	root.add_child(menu)
	await _wait(3)

	# Every page exists and exactly one of them is up.
	var pages: Dictionary = menu.get("_pages")
	_check("the menu builds all four pages", pages.size() == 4, "%d" % pages.size())
	_check("it opens on the front page", _visible_pages(pages) == 1,
			"%d visible" % _visible_pages(pages))

	menu.call("_show", 1)
	await _wait(2)
	_check("play opens the choice of solo or multiplayer", _visible_pages(pages) == 1)

	menu.call("_show", 2)
	await _wait(2)
	var cards: Dictionary = menu.get("_cards")
	_check("character select offers every character",
			cards.size() == _game.roster().size(), "%d cards" % cards.size())

	# And shows them. Choosing between a hooded archer and an armoured knight out
	# of a table of numbers is choosing a spreadsheet row. The roster tile down
	# the left is a face each; the middle is whoever is picked, full length.
	var shown := 0
	for id: StringName in cards:
		if _has_model(cards[id] as Control):
			shown += 1
	_check("every roster tile shows the face it is offering", shown == cards.size(),
			"%d of %d" % [shown, cards.size()])

	var stages: Dictionary = menu.get("_stages")
	_check("and there is a full-length one of each to stand in the middle",
			stages.size() == cards.size(), "%d of %d" % [stages.size(), cards.size()])

	# One at a time: the others are built but hidden, and a hidden `SubViewport`
	# should not be drawing or posing anyone.
	menu.set("_chosen", &"avtandil")
	menu.call("_refresh_cards")
	await _wait(2)
	var up := 0
	for id: StringName in stages:
		if (stages[id] as Control).visible:
			up += 1
	_check("with only the one picked on the stage", up == 1, "%d up" % up)

	# And it turns, so the player sees more of them than one side.
	var stage := stages[&"avtandil"] as CharacterPortrait
	var stand := stage.find_child("Stand", true, false) as Node3D
	var angle: float = stand.rotation.y
	await _wait(20)
	_check("and turns so both sides can be seen",
			not is_equal_approx(stand.rotation.y, angle),
			"%.2f -> %.2f" % [angle, stand.rotation.y])

	# The description belongs to whoever is on the stage.
	var lines := (pages[2] as Control).find_child("Lines", true, false) as VBoxContainer
	var named := ""
	if lines != null and lines.get_child_count() > 0:
		named = (lines.get_child(0) as Label).text
	_check("the description is the picked character's", named == "AVTANDIL",
			"'%s'" % named)

	# Co-op says what it is rather than pretending.
	menu.set("_multiplayer", true)
	menu.call("_show", 2)
	await _wait(2)
	var note := (pages[2] as Control).find_child("ModeNote", true, false) as Label
	_check("multiplayer says it is not ready yet", note != null and not note.text.is_empty(),
			"'%s'" % (note.text if note != null else "<missing>"))
	menu.set("_multiplayer", false)
	menu.call("_show", 2)
	await _wait(2)
	_check("and solo says nothing at all", note.text.is_empty())

	# Picking a card and starting carries the choice into the game.
	var was: StringName = _game.character()
	menu.set("_chosen", &"avtandil")
	menu.call("_start")
	await _wait(2)
	_check("starting carries the chosen character over", _game.character() == &"avtandil",
			"%s" % _game.character())
	_game.choose(was)
	menu.queue_free()
	await _wait(3)


func _check_graphics() -> void:
	var world: Node3D = load(WORLD).instantiate()
	root.add_child(world)
	current_scene = world
	await _wait(5)

	var sun := world.find_children("*", "DirectionalLight3D", true, false)[0] as DirectionalLight3D
	var grass := world.get_node_or_null("Level/Scatter") as GrassField

	Graphics.apply(self, Graphics.Level.HIGH)
	await _wait(2)
	_check("high keeps the shadows", sun.shadow_enabled)
	_check("and draws every pixel", is_equal_approx(root.scaling_3d_scale, 1.0),
			"%.2f" % root.scaling_3d_scale)
	_check("and leaves the textures alone",
			is_equal_approx(root.texture_mipmap_bias, 0.0), "%.2f" % root.texture_mipmap_bias)

	Graphics.apply(self, Graphics.Level.LOW)
	await _wait(2)
	_check("low turns the shadows off", not sun.shadow_enabled)
	_check("and draws fewer pixels", root.scaling_3d_scale < 0.8,
			"%.2f" % root.scaling_3d_scale)
	_check("and softens the textures", root.texture_mipmap_bias > 0.5,
			"%.2f" % root.texture_mipmap_bias)
	_check("and pulls the grass in", grass == null or grass.draw_distance < 100.0,
			"%.0f m" % (grass.draw_distance if grass != null else 0.0))

	# The setting survives being asked for again, which is what a menu does.
	Graphics.apply(self, Graphics.Level.HIGH)
	await _wait(2)
	_check("and it all comes back", sun.shadow_enabled
			and is_equal_approx(root.scaling_3d_scale, 1.0)
			and (grass == null or grass.draw_distance > 100.0))

	# What the player picked is remembered between runs.
	_game.set_graphics(Graphics.Level.LOW)
	_check("the choice is written down", FileAccess.file_exists(_game.get("SETTINGS")))
	_game.set_graphics(Graphics.Level.HIGH)
	world.queue_free()
	await _wait(3)


## The menu that comes up mid-game. It has to stop the world, let it go again,
## and be able to end the game — the last of which is the only way back to the
## front once you are in one.
func _check_pause() -> void:
	var world: Node3D = load(WORLD).instantiate()
	root.add_child(world)
	current_scene = world
	await _wait(5)

	var pause := world.get_node_or_null("PauseMenu")
	_check("the level carries a pause menu", pause != null)
	if pause == null:
		return
	var screen := pause.get_child(0) as Control
	_check("which starts out of the way", not screen.visible)
	_check("and the game is running", not paused)

	pause.call("open")
	await _wait(3)
	_check("it comes up when asked", screen.visible)
	_check("and the world holds still behind it", paused)
	_check("with the mouse given back", Input.mouse_mode == Input.MOUSE_MODE_VISIBLE)

	pause.call("resume")
	await _wait(3)
	_check("resume hands the game back", not screen.visible and not paused)

	# Leaving has to unpause on the way out, or the front menu loads paused and
	# nothing on it can be clicked.
	pause.call("open")
	await _wait(2)
	pause.call("quit_to_menu")
	await _wait(5)
	_check("exit to main menu unpauses", not paused)
	_check("and leaves the level", not is_instance_valid(world)
			or current_scene != world)
	await _wait(3)


## True when `where` carries a portrait with a camera and an actual model under
## it — the thing the game spawns, not a picture of one.
func _has_model(where: Control) -> bool:
	var found := where.find_children("*", "CharacterPortrait", true, false)
	if found.is_empty():
		return false
	var portrait := found[0] as Control
	var stand := portrait.find_child("Stand", true, false) as Node3D
	return stand != null \
			and not portrait.find_children("*", "Camera3D", true, false).is_empty() \
			and not stand.find_children("*", "MeshInstance3D", true, false).is_empty()


func _visible_pages(pages: Dictionary) -> int:
	var up := 0
	for key in pages:
		if (pages[key] as Control).visible:
			up += 1
	return up


func _wait(frames: int) -> void:
	for i in frames:
		await process_frame


func _check(label: String, condition: bool, detail: String = "") -> void:
	if condition:
		print("  ok   - %s" % label)
	else:
		_failures += 1
		print("  FAIL - %s %s" % [label, ("(%s)" % detail) if detail else ""])
