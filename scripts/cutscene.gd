class_name Cutscene
extends Node

## A stretch of film played in the level instead of the game: its own camera,
## black bars above and below, a line of speech at the bottom, and Space (or
## Enter) to skip it. The story ([Intro]) writes the shots; this is the camera
## crew and the screen.
##
##     var cut := Cutscene.new()
##     add_child(cut)
##     cut.begin(player)
##     cut.shot(from, look, to, look_to, 4.0)
##     await cut.say("Datvi", "...", 3.0)
##     cut.end()
##
## While it runs the hero is the film's: no physics tick of his own, no input,
## no health to lose, and his HUD hidden. [method end] hands everything back.
## Every wait returns at once after a skip, so a story written as a run of
## awaits falls straight through to its end; it only has to put the world in
## its last state when [member skipped] is set.

signal finished(was_skipped: bool)

## Each bar's share of the screen's height.
const BAR := 0.115
const BARS_IN := 0.6

var player: Player
var camera: Camera3D
var skipped: bool = false
var running: bool = false

var _layer: CanvasLayer
var _top: ColorRect
var _bottom: ColorRect
var _black: ColorRect
var _who: Label
var _line: Label
var _hint: Label
var _move: Dictionary = {}
var _shake: float = 0.0
var _clock: float = 0.0
var _hud_was: bool = true
var _immortal_was: bool = false


func _ready() -> void:
	_build_screen()


## Takes the screen (and `who`, if given) over.
func begin(who: Player = null) -> void:
	player = who
	running = true
	skipped = false
	camera = Camera3D.new()
	camera.name = "FilmCamera"
	camera.fov = 50.0
	camera.near = 0.08
	camera.far = 1400.0
	add_child(camera)
	if player != null and is_instance_valid(player):
		camera.global_transform = player.camera.global_transform
		player.set_physics_process(false)
		player.set_process_unhandled_input(false)
		player.velocity = Vector3.ZERO
		_immortal_was = player.immortal
		player.immortal = true
		var hud := player.get_node_or_null("Hud") as CanvasLayer
		if hud != null:
			_hud_was = hud.visible
			hud.visible = false
		_set_map(false)
	camera.make_current()
	var t := create_tween().set_parallel()
	t.tween_property(_top, "anchor_bottom", BAR, BARS_IN).set_trans(Tween.TRANS_SINE)
	t.tween_property(_bottom, "anchor_top", 1.0 - BAR, BARS_IN).set_trans(Tween.TRANS_SINE)


## Gives the screen back: the hero's camera, his body and his HUD.
func end() -> void:
	if not running:
		return
	running = false
	_move = {}
	if player != null and is_instance_valid(player):
		player.set_physics_process(true)
		player.set_process_unhandled_input(true)
		player.immortal = _immortal_was
		player.camera.make_current()
		var hud := player.get_node_or_null("Hud") as CanvasLayer
		if hud != null:
			hud.visible = _hud_was
		_set_map(true)
	_who.text = ""
	_line.text = ""
	_hint.visible = false
	var t := create_tween().set_parallel()
	t.tween_property(_top, "anchor_bottom", 0.0, BARS_IN).set_trans(Tween.TRANS_SINE)
	t.tween_property(_bottom, "anchor_top", 1.0, BARS_IN).set_trans(Tween.TRANS_SINE)
	t.tween_property(_black, "color:a", 0.0, 0.4)
	t.chain().tween_callback(queue_free)
	finished.emit(skipped)


## The corner map ([WorldMap]) shown or hidden with the HUD.
func _set_map(shown: bool) -> void:
	var chart := player.get_node_or_null("Map")
	if chart == null:
		return
	if chart is CanvasLayer:
		(chart as CanvasLayer).visible = shown
	elif chart is CanvasItem:
		(chart as CanvasItem).visible = shown


#region Shots
## Moves the camera from `from` to `to` over `seconds`, looking from `look`
## to `look_to` the while. With `track` set the camera looks at that node
## (`track_lift` above it) instead.
func shot(from: Vector3, look: Vector3, to: Vector3, look_to: Vector3, seconds: float,
		track: Node3D = null, track_lift: float = 0.0) -> void:
	_move = {"from": from, "to": to, "look": look, "look_to": look_to, "time": 0.0,
			"seconds": maxf(seconds, 0.01), "track": track, "lift": track_lift}
	_frame(0.0)


## The camera held still at `at`, looking at `look`.
func still(at: Vector3, look: Vector3) -> void:
	shot(at, look, at, look, 1.0)


## A shake that dies away: a roar, a wingbeat overhead.
func shake(strength: float) -> void:
	_shake = maxf(_shake, strength)


func _process(delta: float) -> void:
	_clock += delta
	if not running or _move.is_empty():
		return
	_move["time"] = float(_move["time"]) + delta
	_frame(delta)


func _frame(delta: float) -> void:
	var k := clampf(float(_move["time"]) / float(_move["seconds"]), 0.0, 1.0)
	k = k * k * (3.0 - 2.0 * k)
	var at: Vector3 = (_move["from"] as Vector3).lerp(_move["to"], k)
	var look: Vector3 = (_move["look"] as Vector3).lerp(_move["look_to"], k)
	var track := _move["track"] as Node3D
	if track != null and is_instance_valid(track):
		look = track.global_position + Vector3.UP * float(_move["lift"])
	if _shake > 0.001:
		at += Vector3(sin(_clock * 37.0), sin(_clock * 29.0 + 1.3), sin(_clock * 33.0 + 2.1)) * _shake * 0.12
		_shake = maxf(0.0, _shake - delta * 1.6)
	camera.global_position = at
	if not at.is_equal_approx(look):
		var up := Vector3.UP if absf((look - at).normalized().y) < 0.98 else Vector3.FORWARD
		camera.look_at(look, up)
#endregion


#region Time and words
## Waits `seconds` of film; returns at once once skipped.
func wait(seconds: float) -> void:
	var left := seconds
	while left > 0.0 and not skipped and is_inside_tree():
		await get_tree().process_frame
		left -= get_process_delta_time()


## A line at the bottom of the screen for `seconds`; `who` above it in gold.
func say(who: String, text: String, seconds: float) -> void:
	_who.text = who
	_line.text = text
	_who.modulate.a = 0.0
	_line.modulate.a = 0.0
	var t := create_tween().set_parallel()
	t.tween_property(_who, "modulate:a", 1.0, 0.25)
	t.tween_property(_line, "modulate:a", 1.0, 0.25)
	await wait(seconds)
	if is_inside_tree() and not skipped:
		var out := create_tween().set_parallel()
		out.tween_property(_who, "modulate:a", 0.0, 0.25)
		out.tween_property(_line, "modulate:a", 0.0, 0.25)
		await wait(0.3)


## To black (`to_black`) or back from it, over `seconds`.
func fade(to_black: bool, seconds: float) -> void:
	var t := create_tween()
	t.tween_property(_black, "color:a", 1.0 if to_black else 0.0, seconds)
	await wait(seconds)
	if skipped:
		t.kill()


## The screen black at once (a film that opens out of the dark).
func black() -> void:
	_black.color.a = 1.0
#endregion


func _input(event: InputEvent) -> void:
	if not running or skipped:
		return
	var key := event as InputEventKey
	if (key != null and key.pressed and not key.echo and key.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]) \
			or (event is InputEventJoypadButton and event.is_pressed()
				and (event as InputEventJoypadButton).button_index == JOY_BUTTON_START):
		skip()
		get_viewport().set_input_as_handled()


## Cuts the film short: every wait returns at once.
func skip() -> void:
	if not running:
		return
	skipped = true
	_who.text = ""
	_line.text = ""


func _build_screen() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 40
	add_child(_layer)
	_top = _bar()
	_top.anchor_top = 0.0
	_top.anchor_bottom = 0.0
	_bottom = _bar()
	_bottom.anchor_top = 1.0
	_bottom.anchor_bottom = 1.0
	_black = ColorRect.new()
	_black.color = Color(0, 0, 0, 0)
	_black.set_anchors_preset(Control.PRESET_FULL_RECT)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_black)
	_who = _label(26, Color(1.0, 0.82, 0.45))
	_who.anchor_top = 1.0 - BAR - 0.075
	_who.anchor_bottom = 1.0 - BAR - 0.04
	_line = _label(30, Color(0.96, 0.94, 0.9))
	_line.anchor_top = 1.0 - BAR - 0.04
	_line.anchor_bottom = 1.0 - BAR + 0.02
	_hint = Label.new()
	_hint.text = "Space — გამოტოვება"
	_hint.add_theme_font_size_override("font_size", 16)
	_hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.45))
	_hint.anchor_left = 0.8
	_hint.anchor_right = 0.98
	_hint.anchor_top = 0.955
	_hint.anchor_bottom = 0.99
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_layer.add_child(_hint)


func _bar() -> ColorRect:
	var bar := ColorRect.new()
	bar.color = Color.BLACK
	bar.anchor_left = 0.0
	bar.anchor_right = 1.0
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(bar)
	return bar


func _label(size: int, color: Color) -> Label:
	var l := Label.new()
	l.anchor_left = 0.1
	l.anchor_right = 0.9
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 7)
	_layer.add_child(l)
	return l
