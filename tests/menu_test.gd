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
	# Loudly, and first. A menu whose script failed to parse instantiates as a
	# bare Control and every check below it reads null — which is how a broken
	# menu once got a clean run out of this suite.
	_check("the menu scene builds at all",
			menu != null and menu.get_script() != null and menu.get("_pages") != null)
	if menu == null or menu.get_script() == null:
		return
	root.add_child(menu)
	await _wait(3)

	# Every page exists and exactly one of them is up.
	var pages: Dictionary = menu.get("_pages")
	_check("the menu builds every page", pages.size() == 5, "%d" % pages.size())
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

	# It stands still, and turns when dragged across, so the player sees the
	# other side when they want to.
	var stage := stages[&"avtandil"] as CharacterPortrait
	var stand := stage.find_child("Stand", true, false) as Node3D
	var angle: float = stand.rotation.y
	await _wait(20)
	_check("it stands still on its own", is_equal_approx(stand.rotation.y, angle),
			"%.2f -> %.2f" % [angle, stand.rotation.y])
	var drag := InputEventMouseMotion.new()
	drag.button_mask = MOUSE_BUTTON_MASK_LEFT
	drag.relative = Vector2(60, 0)
	menu.call("_on_stage_input", drag)
	_check("and a drag across it turns it", not is_equal_approx(stand.rotation.y, angle),
			"%.2f -> %.2f" % [angle, stand.rotation.y])

	# The description belongs to whoever is on the stage.
	var lines := (pages[2] as Control).find_child("Lines", true, false) as VBoxContainer
	var named := ""
	if lines != null and lines.get_child_count() > 0:
		named = (lines.get_child(0) as Label).text
	_check("the description is the picked character's", named == "AVTANDIL",
			"'%s'" % named)

	# Under the stage, who he is: for Tariel, the square-headed one he was or
	# the warrior after Ashen; for the archer, the green ranger hooded or
	# bareheaded, or the one he was. Neither has a choice of hair.
	var face_row := (pages[2] as Control).find_child("FaceRow", true, false) as Control
	var hair_row := (pages[2] as Control).find_child("HairRow", true, false) as Control
	# Avtandil has two looks now: AS HE WAS, and YOUR OWN, made on the spot
	# (the maker, [PolysplitLook]).
	_check("the archer offers his own look and one made for him",
			face_row != null and face_row.visible)
	var face_was: int = _game.face(&"tariel")
	menu.set("_chosen", &"tariel")
	menu.call("_refresh_cards")
	await _wait(3)
	_check("Tariel does", face_row != null and face_row.visible)
	_check("but no hair to pick", hair_row != null and not hair_row.visible)
	var knight := (stages[&"tariel"] as CharacterPortrait).rig() as SkinnedRig
	var face_from: int = knight.face
	menu.call("_step_face", 1)
	var faces_on := 0
	for key: StringName in knight.faces:
		var face_mesh := knight.find_child("tariel_face_" + String(key), true, false) as MeshInstance3D
		if face_mesh != null and face_mesh.visible:
			faces_on += 1
	# A look worn on a figure of its own (see SkinnedRig.figures) is that figure.
	if knight.wearing_figure() and knight._figure != null and knight._figure.visible:
		faces_on += 1
	_check("the arrow puts on the other look, and only it", knight.face == (face_from + 1) % knight.faces.size()
			and faces_on == 1, "%d -> %d, %d shown" % [face_from, knight.face, faces_on])
	_check("the hair shows only on the square head",
			_hairs_shown(knight) == (0 if knight.wearing_whole() else 1))
	_check("and the look is remembered", _game.face(&"tariel") == knight.face)

	# YOUR OWN: the maker in the dossier's place, a class dressing him, every
	# change on the stage and remembered; the dossier back for any other look.
	var look_was: Dictionary = _game.look(&"tariel")
	var dossier := (pages[2] as Control).find_child("Dossier", true, false) as Control
	var maker := (pages[2] as Control).find_child("Maker", true, false) as Control
	knight.set_face(knight.faces.find(SkinnedRig.CUSTOM))
	menu.call("_refresh_picks")
	await _wait(2)
	_check("YOUR OWN puts the maker where the dossier was", maker != null and maker.visible
			and dossier != null and not dossier.visible)
	menu.set("_maker_tab", "CLASS")
	var cls_was := String(knight.get_look()["cls"])
	menu.call("_maker_step", "cls", 1)
	await _wait(2)
	var made := knight.get_look()
	var spec: Dictionary = PolysplitLook.CLASSES[made["g"]][made["cls"]]
	_check("a class dresses him in its clothes, hat and arms", String(made["cls"]) != cls_was
			and made["top"] == made["cls"] and made["hat"] == spec["hat"]
			and knight._figure != null and knight._figure.visible,
			"%s -> %s: %s, figure %s" % [cls_was, made["cls"], made, knight._figure])
	_check("and it is remembered", String(_game.look(&"tariel").get("cls", "")) == String(made["cls"]))
	var g_was := String(made["g"])
	menu.call("_maker_step", "g", 1)
	await _wait(2)
	var g_now := String(knight.get_look()["g"])
	_check("the body changed, on a figure of its own", g_now != g_was
			and knight._figure == knight._figs[StringName("ps" + g_now)]["node"], "%s -> %s" % [g_was, g_now])
	var tabs_rows := 0
	menu.call("_maker_show", "FACE")
	for kind: String in (menu.get("_maker_rows") as Dictionary):
		var row := (menu.get("_maker_rows") as Dictionary)[kind] as Control
		tabs_rows += 1 if row.visible else 0
	_check("a tab shows its own rows (FACE: six)", tabs_rows == 6, "%d" % tabs_rows)
	knight.set_face(0)
	menu.call("_refresh_picks")
	await _wait(1)
	_check("another look puts the dossier back", dossier.visible and not maker.visible)
	_game.set_look(&"tariel", look_was)
	_game.set_face(&"tariel", face_was)

	# Every character can be taken into a game with other people — including the
	# archer. He was briefly barred while the bow did not cross the wire, and
	# barring characters is the wrong answer to a missing feature: there are two
	# more of them coming.
	menu.set("_chosen", &"avtandil")
	menu.set("_multiplayer", true)
	menu.call("_show", 2)
	await _wait(2)
	_check("the archer can be taken into a game with other people",
			menu.get("_chosen") == &"avtandil", "ended up on %s" % menu.get("_chosen"))
	var archer := (menu.get("_cards") as Dictionary).get(&"avtandil") as Control
	_check("and nothing is greyed out", archer != null and archer.modulate.a > 0.99,
			"alpha %.2f" % (archer.modulate.a if archer != null else 0.0))

	var note := (pages[2] as Control).find_child("ModeNote", true, false) as Label
	_check("multiplayer says what it is", note != null and not note.text.is_empty(),
			"'%s'" % (note.text if note != null else "<missing>"))
	_check("and there is a page for hosting and joining",
			(pages[4] as Control).find_child("Address", true, false) is LineEdit)
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

	Graphics.apply(self, Graphics.Level.MEDIUM)
	await _wait(2)
	_check("medium keeps the sun's shadow", sun.shadow_enabled)
	_check("but in one short cascade",
			sun.directional_shadow_mode == DirectionalLight3D.SHADOW_ORTHOGONAL
			and sun.directional_shadow_max_distance < 80.0,
			"mode %d, %.0f m" % [sun.directional_shadow_mode, sun.directional_shadow_max_distance])
	_check("and draws between the two", root.scaling_3d_scale > 0.75 and root.scaling_3d_scale < 1.0,
			"%.2f" % root.scaling_3d_scale)

	# The setting survives being asked for again, which is what a menu does.
	Graphics.apply(self, Graphics.Level.HIGH)
	await _wait(2)
	_check("and it all comes back", sun.shadow_enabled
			and is_equal_approx(root.scaling_3d_scale, 1.0)
			and (grass == null or grass.draw_distance > 100.0))
	_check("the sun's own cascades and reach included",
			sun.directional_shadow_mode == DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
			and is_equal_approx(sun.directional_shadow_max_distance, 95.0),
			"mode %d, %.0f m" % [sun.directional_shadow_mode, sun.directional_shadow_max_distance])

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
## How many hair meshes of every skull are showing on `rig`.
func _hairs_shown(rig: SkinnedRig) -> int:
	var on := 0
	for mesh in rig.find_children("tariel_hair_*", "MeshInstance3D", true, false):
		if (mesh as MeshInstance3D).visible:
			on += 1
	return on


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
