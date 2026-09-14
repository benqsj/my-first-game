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
	_check("play opens the choice of solo or co-op", _visible_pages(pages) == 1)

	menu.call("_show", 2)
	await _wait(2)
	var cards: Dictionary = menu.get("_cards")
	_check("character select offers every character",
			cards.size() == _game.roster().size(), "%d cards" % cards.size())

	# Co-op says what it is rather than pretending.
	menu.set("_co_op", true)
	menu.call("_show", 2)
	await _wait(2)
	var note := (pages[2] as Control).find_child("CoOpNote", true, false) as Label
	_check("co-op says it is not ready yet", note != null and not note.text.is_empty(),
			"'%s'" % (note.text if note != null else "<missing>"))
	menu.set("_co_op", false)
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
