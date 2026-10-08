class_name SceneLoader
extends CanvasLayer

## The way from one screen to another: the front menu into a level, a level
## back out to the menu.
##
## `change_scene_to_file()` alone loads the next scene on the spot, and a level
## that takes seconds to load and set itself up left whatever was on the screen
## frozen in place all that while — the menu with its button still lit, or the
## game behind its pause menu — with nothing to say anything was happening.
## This puts a screen up first, says so, reads the next scene in on a worker
## thread with a bar for how far it has got, and stays up over the new scene
## while it builds itself and while [PipelineWarmup] shows it to the renderer
## behind its black. Nothing about what gets loaded changes.
##
##     SceneLoader.go(get_tree(), "res://scenes/world/greybox_world.tscn")

## Above everything, [PipelineWarmup]'s black (128) included.
const LAYER := 129
## Frames to wait for the new scene to have settled, at most, whatever it does.
const SETTLE_MAX := 900

enum Step { SHOW, LOADING, SWAPPED, DONE }

var _path: String = ""
var _step: Step = Step.SHOW
var _shown: int = 0
var _waited: int = 0
var _progress: float = 0.0
var _bar: Control
var _words: Label


## Leaves the current scene for the one at `path`, behind a loading screen.
static func go(tree: SceneTree, path: String) -> void:
	# One at a time: a second click on START while the first is under way is
	# not a second load.
	for child in tree.root.get_children():
		if child is SceneLoader:
			return
	var screen := SceneLoader.new()
	screen._path = path
	screen.name = "SceneLoader"
	tree.root.add_child.call_deferred(screen)


func _ready() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	var page := Control.new()
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	page.mouse_filter = Control.MOUSE_FILTER_STOP
	MenuStyle.background(page)
	add_child(page)

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	column.grow_horizontal = Control.GROW_DIRECTION_BOTH
	column.grow_vertical = Control.GROW_DIRECTION_BEGIN
	column.offset_bottom = -90.0
	column.add_theme_constant_override("separation", 14)
	page.add_child(column)
	_words = MenuStyle.label("LOADING", MenuStyle.HEADING_SIZE - 6, MenuStyle.CREAM, "title")
	_words.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	_words.add_theme_constant_override("shadow_offset_y", 2)
	column.add_child(_words)
	_bar = Control.new()
	_bar.custom_minimum_size = Vector2(420.0, 6.0)
	_bar.draw.connect(_draw_bar)
	column.add_child(_bar)


func _process(_delta: float) -> void:
	match _step:
		Step.SHOW:
			# Up on the screen for a frame before anything heavy starts, or the
			# player would never see it. Then the old scene goes — freed now,
			# not after the new one is in, so the two are never both held.
			_shown += 1
			if _shown < 2:
				return
			# Not while the heroes' profiles are still coming in on their worker
			# ([method Game.profiles_ready]): two loads of the same rig at once
			# is how the loader hung.
			var game := get_node_or_null(^"/root/Game")
			if game != null and game.has_method(&"profiles_ready") and not game.call(&"profiles_ready") \
					and _shown < 60 * 30:
				return
			get_tree().unload_current_scene.call_deferred()
			if ResourceLoader.load_threaded_request(_path, "", true) != OK:
				push_error("SceneLoader: cannot load '%s'." % _path)
				queue_free()
				return
			_step = Step.LOADING
		Step.LOADING:
			var got: Array = []
			var status := ResourceLoader.load_threaded_get_status(_path, got)
			if not got.is_empty():
				_set_progress(float(got[0]))
			if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				return
			var scene := ResourceLoader.load_threaded_get(_path) as PackedScene
			if scene == null:
				push_error("SceneLoader: '%s' did not load." % _path)
				queue_free()
				return
			_set_progress(1.0)
			_words.text = "PREPARING THE WORLD" if _path.contains("/world/") else "LOADING"
			_step = Step.SWAPPED
			# Its setting-up happens in here, on this thread: the screen holds
			# as it was last drawn until that is done.
			get_tree().change_scene_to_packed(scene)
		Step.SWAPPED:
			# Until the new scene is in and [PipelineWarmup] has finished
			# showing it to the renderer (it frees itself when done).
			_waited += 1
			var now := get_tree().current_scene
			var settled := now != null and now.get_node_or_null("PipelineWarmup") == null
			if (settled and _waited > 2) or _waited > SETTLE_MAX:
				_step = Step.DONE
				queue_free()


func _set_progress(share: float) -> void:
	_progress = maxf(_progress, clampf(share, 0.0, 1.0))
	if _bar != null:
		_bar.queue_redraw()


func _draw_bar() -> void:
	var size := _bar.size
	_bar.draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.0, 0.55))
	_bar.draw_rect(Rect2(Vector2.ZERO, Vector2(size.x * _progress, size.y)), MenuStyle.GOLD)
	_bar.draw_rect(Rect2(Vector2.ZERO, size), Color(MenuStyle.GOLD_DIM, 0.8), false, 1.0)
