class_name DungeonHud
extends RefCounted

## The dungeon's own screen: the run's steps on top, the map, the words said
## on screen. Taken out of dungeon.gd (2026-10-28); every function takes the
## dungeon as `dun`.

static func _build_hud(dun: Dungeon) -> void:
	dun._layer = CanvasLayer.new()
	dun._layer.layer = 5
	dun.add_child(dun._layer)
	# The dark the heroes go through from one place to the next.
	dun._fade = ColorRect.new()
	dun._fade.color = Color(0.0, 0.0, 0.0, 0.0)
	dun._fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	dun._fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dun._layer.add_child(dun._fade)
	dun._banner = Label.new()
	dun._banner.anchor_left = 0.5
	dun._banner.anchor_right = 0.5
	dun._banner.anchor_top = 0.0
	dun._banner.anchor_bottom = 0.0
	dun._banner.offset_left = -400
	dun._banner.offset_right = 400
	dun._banner.offset_top = 90
	dun._banner.offset_bottom = 140
	dun._banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dun._banner.add_theme_font_size_override("font_size", 30)
	dun._banner.add_theme_color_override("font_color", Color(0.9, 0.82, 1.0))
	dun._banner.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	dun._banner.add_theme_constant_override("outline_size", 8)
	dun._banner.hide()
	dun._layer.add_child(dun._banner)
	# the run's map along the top: its ten steps, the bosses marked, where he is
	dun._map = Control.new()
	dun._map.name = "RunMap"
	dun._map.anchor_left = 0.5
	dun._map.anchor_right = 0.5
	dun._map.offset_left = -230.0
	dun._map.offset_right = 230.0
	dun._map.offset_top = 18.0
	dun._map.offset_bottom = 56.0
	dun._map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dun._map.draw.connect(func() -> void: DungeonHud._draw_map(dun))
	dun._layer.add_child(dun._map)


## The run's map (the user's word, 2026-10-22): a mark a step, joined, gold
## for those cleared, the one he is in ringed bright; a boss's mark larger, a
## red diamond; in a place to rest, a small blue drop between the steps it
## sits between, not one of them.
static func _draw_map(dun: Dungeon) -> void:
	var n := dun.stage_count()
	if n <= 1:
		return
	var w := dun._map.size.x
	var y := dun._map.size.y * 0.5
	var gap := w / float(n - 1)
	var here := dun.stage_of(dun.current)
	var resting := dun.is_rest(dun.current)
	var gold := Color(1.0, 0.84, 0.45)
	var dim := Color(0.75, 0.7, 0.85, 0.55)
	var font := ThemeDB.fallback_font
	dun._map.draw_line(Vector2(0.0, y), Vector2(w, y), Color(0.0, 0.0, 0.0, 0.55), 5.0)
	dun._map.draw_line(Vector2(0.0, y), Vector2(gap * float(here - 1), y), Color(gold, 0.85), 2.0)
	if here < n:
		dun._map.draw_line(Vector2(gap * float(here - 1), y), Vector2(w, y), dim, 2.0)
	var stage := 0
	for k in dun.steps.size():
		if dun.is_rest(k):
			continue
		var x := gap * float(stage)
		var boss := dun.is_boss(k)
		var done := k < dun.cleared.size() and dun.cleared[k]
		var size := 9.0 if boss else 6.0
		var fill := gold if done else (Color(0.95, 0.3, 0.25) if boss else Color(0.2, 0.18, 0.26))
		var edge := Color(0.95, 0.35, 0.3) if boss else (gold if done else dim)
		if boss:
			var pts := PackedVector2Array([Vector2(x, y - size), Vector2(x + size, y), Vector2(x, y + size), Vector2(x - size, y)])
			dun._map.draw_colored_polygon(pts, fill)
			pts.append(pts[0])
			dun._map.draw_polyline(pts, edge, 2.0)
		else:
			dun._map.draw_circle(Vector2(x, y), size, fill)
			dun._map.draw_arc(Vector2(x, y), size, 0.0, TAU, 20, edge, 1.5)
		if stage + 1 == here and not resting:
			dun._map.draw_arc(Vector2(x, y), size + 5.0, 0.0, TAU, 28, Color(1.0, 0.95, 0.8), 2.5)
		if font != null:
			dun._map.draw_string(font, Vector2(x - 8.0, y + size + 14.0), str(stage + 1), HORIZONTAL_ALIGNMENT_CENTER, 16.0, 11,
					Color(1.0, 0.95, 0.85, 0.85 if stage + 1 == here else 0.5))
		stage += 1
	if resting:
		var x := gap * (float(here - 1) - 0.5)
		dun._map.draw_circle(Vector2(x, y), 5.0, Color(0.45, 0.8, 1.0))
		dun._map.draw_arc(Vector2(x, y), 10.0, 0.0, TAU, 24, Color(0.75, 0.92, 1.0), 2.0)


static func _say(dun: Dungeon, text: String, seconds: float) -> void:
	if dun._banner == null:
		return
	dun._banner.text = text
	dun._banner.show()
	dun._banner_until = Time.get_ticks_msec() / 1000.0 + seconds
