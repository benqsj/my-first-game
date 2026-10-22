class_name RunSummary
extends CanvasLayer

## The end of a run through the orc portal, won or lost (the user's word,
## 2026-10-21: what makes a player come back): how long it took against his
## best, how far he came, how many fell to him, the tusks he takes home, the
## blessings he had — and what is new in the village for them.

var won: bool = false
var _rise: Button
var _risen: bool = false
var lines: Dictionary = {}
var _box: PanelContainer


static func make(d: Dungeon, did_win: bool) -> RunSummary:
	var s := RunSummary.new()
	s.name = "RunSummary"
	s.won = did_win
	var game := d.get_node_or_null("/root/Game")
	var seconds := d.run_seconds()
	var record: Dictionary = {}
	if game != null and game.has_method(&"end_run"):
		record = game.call(&"end_run", did_win, seconds)
	var cleared := 0
	# the run's steps, a place to rest not one of them
	for k in d.cleared.size():
		if d.cleared[k] and not d.is_rest(k):
			cleared += 1
	var names: Array[String] = []
	if d.boons != null:
		for id in d.boons.taken:
			names.append(String(Boons.ALL[id]["name"]))
	s.lines = {
		"time": seconds, "best": float(record.get("best", 0.0)), "new_best": bool(record.get("new_best", false)),
		"places": cleared, "of": d.stage_count(), "kills": d.run_kills, "tusks": d.run_tusks,
		"tusks_all": int(game.get(&"tusks")) if game != null else 0, "boons": names,
		"runs": int(record.get("runs", 0)), "wins": int(record.get("wins", 0)),
	}
	d.add_child(s)
	return s


static func clock(t: float) -> String:
	var whole := int(t)
	return "%d:%02d" % [whole / 60, whole % 60]


func _ready() -> void:
	layer = 6
	_box = PanelContainer.new()
	_box.anchor_left = 0.5
	_box.anchor_right = 0.5
	_box.anchor_top = 0.18
	_box.offset_left = -300
	_box.offset_right = 300
	var look := StyleBoxFlat.new()
	look.bg_color = Color(0.05, 0.04, 0.035, 0.9)
	look.border_color = Color(0.78, 0.6, 0.3, 0.95) if won else Color(0.6, 0.15, 0.12, 0.95)
	look.set_border_width_all(2)
	look.set_corner_radius_all(8)
	look.set_content_margin_all(22)
	_box.add_theme_stylebox_override("panel", look)
	add_child(_box)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	_box.add_child(col)
	_line(col, "გამარჯვება!" if won else "დამარცხდი", 44, Color(0.92, 0.75, 0.4) if won else Color(0.8, 0.2, 0.16))
	_line(col, "გარბენი #%d   ·   გამარჯვებები: %d" % [int(lines["runs"]), int(lines["wins"])], 18, Color(0.7, 0.68, 0.62))
	col.add_child(HSeparator.new())
	var t := float(lines["time"])
	var time_text := "დრო: %s" % clock(t)
	if won and bool(lines["new_best"]):
		time_text += "   — ახალი რეკორდი!"
	elif won and int(lines["wins"]) == 1:
		time_text += "   — პირველი გამარჯვება!"
	elif float(lines["best"]) > 0.0:
		time_text += "   (საუკეთესო %s)" % clock(float(lines["best"]))
	_line(col, time_text, 24, Color(0.95, 0.9, 0.8))
	_line(col, "გავლილი ადგილები: %d / %d" % [int(lines["places"]), int(lines["of"])], 24, Color(0.95, 0.9, 0.8))
	_line(col, "მოკლული მტრები: %d" % int(lines["kills"]), 24, Color(0.95, 0.9, 0.8))
	_line(col, "ორკის ეშვი: +%d   (სულ %d)" % [int(lines["tusks"]), int(lines["tusks_all"])], 24, Color(1.0, 0.86, 0.55))
	var names: Array = lines["boons"]
	if not names.is_empty():
		_line(col, "კურთხევები: " + ", ".join(PackedStringArray(names)), 19, Color(0.8, 0.82, 0.95))
	col.add_child(HSeparator.new())
	_line(col, "ეშვები სოფელში დახარჯე — მჭედელთან, მკურნალთან, მღვდელთან.", 17, Color(0.7, 0.7, 0.66))
	if not won:
		# fallen: he rises in the village when he says so
		_rise = Button.new()
		_rise.text = "გაცოცხლდი სოფელში   [F]"
		_rise.custom_minimum_size = Vector2(320, 52)
		_rise.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_rise.add_theme_font_size_override("font_size", 24)
		_rise.pressed.connect(rise)
		col.add_child(_rise)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_rise.grab_focus.call_deferred()
	_box.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_box, "modulate:a", 1.0, 0.6)
	if won:
		tw.tween_interval(11.0)
		tw.tween_property(_box, "modulate:a", 0.0, 1.0)
		tw.tween_callback(queue_free)


func _unhandled_input(event: InputEvent) -> void:
	if _rise == null or _risen or event.is_echo():
		return
	if event.is_action_pressed(&"interact") or event.is_action_pressed(&"ui_accept"):
		get_viewport().set_input_as_handled()
		rise()


## Up again in the village: out of the dungeon by its gate ([method Dungeon.leave]).
func rise() -> void:
	if _risen:
		return
	_risen = true
	var d := get_parent() as Dungeon
	if d != null:
		d.leave()


func _line(into: Container, text: String, size: int, tint: Color) -> void:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", tint)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 4)
	into.add_child(l)
