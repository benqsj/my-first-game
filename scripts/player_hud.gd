class_name PlayerHud
extends CanvasLayer

## Your own body's health and stamina, in the top-left corner, and the words
## across the screen when it falls.
##
## Built only for the player you drive — nobody needs to see four sets of bars —
## and it reads the [Player] directly every frame rather than listening for
## changes: two numbers, drawn, costs nothing, and it can never fall out of step
## with the body the way a missed signal would leave it.
##
## * **The bars grow with the pool.** A knight with 160 health has a longer bar
##   than a mage with 100, so the difference between them is seen, not read.
## * **What a blow took lingers.** The chunk a hit takes off stays drawn, pale,
##   for a moment and then drains down to the new level — so a big hit reads as
##   big even though the bar itself drops at once.
## * **Stamina says when it is spent.** Emptied, the bar dims until it has
##   started coming back, which is the stretch in which nothing costing stamina
##   can be done.
## * **The level is a gilt shield** at the head of the bars with the number in
##   it, the hero's name over the bars; the experience towards the next level a
##   gold line along the whole bottom edge, cut in tenths ([Leveling]). What a
##   kill brought rises off its count ("+10 EXP"); a new level is "LEVEL UP" at
##   the top of the screen, and the shield throws out light.
## * **The skills are four squares at the bottom**, keys 1 to 4: the skill's
##   picture, its key in the corner, and while it is coming back a shade that
##   drains down off it with the seconds left. It flashes when it is ready again;
##   used, its name shows over the bar for a moment. An empty slot is a dark one.

## Pixels per point of health and of stamina.
const HEALTH_SCALE := 2.1
const STAMINA_SCALE := 2.4
const MARGIN := Vector2(74.0, 30.0)
const HEALTH_HEIGHT := 13.0
const STAMINA_HEIGHT := 8.0
const GAP := 6.0

const FRAME := Color(0.05, 0.04, 0.04, 0.72)
const EDGE := Color(0.83, 0.72, 0.5, 0.55)
const HEALTH := Color(0.74, 0.1, 0.09)
const HEALTH_LOST := Color(0.95, 0.82, 0.55, 0.85)
const STAMINA := Color(0.36, 0.68, 0.31)
const STAMINA_SPENT := Color(0.36, 0.68, 0.31, 0.35)

var player: Player

var _bars: Control
var _lost: float = -1.0
var _lost_wait: float = 0.0
var _death: Label
var _band: ColorRect
var _death_time: float = 0.0
## Per slot: how long ago it came ready (for the flash), and what was left of
## its cooldown last frame.
var _ready_flash: PackedFloat32Array = PackedFloat32Array([9.0, 9.0, 9.0, 9.0])
var _last_left: PackedFloat32Array = PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
var _said: String = ""
var _said_time: float = 9.0
## The hero's [Leveling], found once it is there; the last experience gained and
## the last level reached, and how long ago.
var _book: Leveling
var _gain: float = 0.0
var _gain_time: float = 9.0
var _up_level: int = 0
var _up_time: float = 9.0

const GOLD := Color(0.95, 0.78, 0.36)
const GOLD_DEEP := Color(0.55, 0.38, 0.12)
## The longest a bar grows, however high the level.
const MAX_BAR := 480.0

const SLOT := 56.0
const SLOT_GAP := 10.0
const SLOT_BOTTOM := 26.0
const SLOT_FILL := Color(0.08, 0.07, 0.06, 0.78)
const SLOT_EMPTY := Color(0.05, 0.05, 0.05, 0.45)
const SLOT_SHADE := Color(0.0, 0.0, 0.0, 0.62)
const ICON := Color(0.95, 0.86, 0.62)


func _ready() -> void:
	layer = 4
	_bars = Control.new()
	_bars.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bars.draw.connect(_draw_bars)
	add_child(_bars)

	_band = ColorRect.new()
	_band.color = Color(0.0, 0.0, 0.0, 0.0)
	_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_band.anchor_left = 0.0
	_band.anchor_right = 1.0
	_band.anchor_top = 0.5
	_band.anchor_bottom = 0.5
	_band.offset_top = -70.0
	_band.offset_bottom = 70.0
	add_child(_band)

	_death = Label.new()
	_death.text = "YOU HAVE FALLEN"
	_death.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_death.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_death.set_anchors_preset(Control.PRESET_FULL_RECT)
	_death.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_death.add_theme_font_size_override("font_size", 64)
	_death.add_theme_color_override("font_color", Color(0.72, 0.09, 0.08))
	_death.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_death.add_theme_constant_override("shadow_offset_x", 2)
	_death.add_theme_constant_override("shadow_offset_y", 3)
	_death.modulate.a = 0.0
	add_child(_death)
	if player != null:
		player.skill_used.connect(_on_skill_used)


func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	# The pale chunk: held for a beat after the hit, then drained down.
	if _lost < player.health:
		_lost = player.health
		_lost_wait = 0.0
	elif _lost > player.health:
		_lost_wait += delta
		if _lost_wait > 0.6:
			_lost = move_toward(_lost, player.health, player.max_health * 0.6 * delta)
	for slot in Player.SKILL_SLOTS:
		var left := player.skill_cooldown_left(slot)
		if _last_left[slot] > 0.0 and left <= 0.0:
			_ready_flash[slot] = 0.0
		_last_left[slot] = left
		_ready_flash[slot] += delta
	_said_time += delta
	_gain_time += delta
	_up_time += delta
	if _book == null:
		_book = player.get_node_or_null(^"Leveling") as Leveling
		if _book != null:
			_book.gained.connect(func(amount: float) -> void:
				_gain = amount
				_gain_time = 0.0)
			_book.leveled_up.connect(func(level: int) -> void:
				_up_level = level
				_up_time = 0.0)
	_bars.queue_redraw()

	if player.is_dead:
		_death_time += delta
	else:
		_death_time = 0.0
	var shown := clampf((_death_time - 0.6) / 1.2, 0.0, 1.0)
	_death.modulate.a = shown
	_band.color = Color(0.0, 0.0, 0.0, 0.55 * shown)


func _draw_bars() -> void:
	if player == null or not is_instance_valid(player):
		return
	var at := MARGIN
	_bar(at, minf(player.max_health * HEALTH_SCALE, MAX_BAR), HEALTH_HEIGHT,
			player.health / maxf(player.max_health, 1.0), HEALTH,
			_lost / maxf(player.max_health, 1.0), HEALTH_LOST)
	at.y += HEALTH_HEIGHT + GAP
	var winded := player.is_winded()
	_bar(at, minf(player.max_stamina * STAMINA_SCALE, MAX_BAR), STAMINA_HEIGHT,
			maxf(player.stamina, 0.0) / maxf(player.max_stamina, 1.0),
			STAMINA_SPENT if winded else STAMINA, 0.0, Color.TRANSPARENT)
	_draw_skills()
	_draw_level()


## The level: a gilt shield at the head of the bars with the number in it and
## the hero's name over them; the experience a Lineage-style gold line along
## the very bottom of the screen, cut in tenths, with the count over its left
## end and what a kill brought rising off it; a new level "LEVEL UP" at the top
## of the screen, and the shield throwing out light.
func _draw_level() -> void:
	if _book == null:
		return
	var font := ThemeDB.fallback_font
	var view := _bars.size
	var glow := 1.0 - clampf(_up_time / 2.0, 0.0, 1.0)
	# The shield.
	var c := Vector2(38.0, 38.0)
	if glow > 0.0:
		for k in 12:
			var t := TAU * k / 12.0 + _up_time * 0.8
			var d := Vector2(cos(t), sin(t))
			_bars.draw_line(c + d * 26.0, c + d * (34.0 + 26.0 * glow), Color(1.0, 0.9, 0.55, 0.55 * glow), 2.0)
		_bars.draw_circle(c, 30.0 + 6.0 * glow, Color(1.0, 0.85, 0.45, 0.25 * glow))
	var outer := PackedVector2Array([Vector2(12, 10), Vector2(64, 10), Vector2(64, 44), Vector2(38, 68),
			Vector2(12, 44)])
	var inner := PackedVector2Array([Vector2(16, 14), Vector2(60, 14), Vector2(60, 42), Vector2(38, 63),
			Vector2(16, 42)])
	_bars.draw_colored_polygon(outer, Color(0.06, 0.05, 0.05, 0.88))
	_bars.draw_colored_polygon(inner, Color(0.16, 0.08, 0.07, 0.9))
	var ring := outer.duplicate()
	ring.append(outer[0])
	_bars.draw_polyline(ring, GOLD.lerp(Color(1, 1, 0.9), glow), 2.0)
	var ring2 := inner.duplicate()
	ring2.append(inner[0])
	_bars.draw_polyline(ring2, Color(GOLD, 0.45), 1.0)
	var lv_w := font.get_string_size("LEVEL", HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
	_bars.draw_string(font, Vector2(c.x - lv_w * 0.5, 25.0), "LEVEL", HORIZONTAL_ALIGNMENT_LEFT, -1, 9,
			Color(GOLD, 0.85))
	var lv := str(_book.level)
	var w := font.get_string_size(lv, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
	_bars.draw_string(font, Vector2(c.x - w * 0.5 + 1.0, 50.0), lv, HORIZONTAL_ALIGNMENT_LEFT, -1, 26,
			Color(0, 0, 0, 0.8))
	_bars.draw_string(font, Vector2(c.x - w * 0.5, 49.0), lv, HORIZONTAL_ALIGNMENT_LEFT, -1, 26,
			Color(1.0, 0.95, 0.82).lerp(Color(1, 1, 1), glow))
	# The name over the bars.
	var hero_name := player.profile.display_name if player.profile != null else ""
	_bars.draw_string(font, MARGIN + Vector2(1.0, -6.0), hero_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 14,
			Color(0, 0, 0, 0.8))
	_bars.draw_string(font, MARGIN + Vector2(0.0, -7.0), hero_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 14,
			Color(1.0, 0.93, 0.8))
	# The experience, along the bottom edge.
	var top := _book.at_top()
	var share := 1.0 if top else clampf(_book.xp / 100.0, 0.0, 1.0)
	var line := Rect2(Vector2(0.0, view.y - 7.0), Vector2(view.x, 7.0))
	_bars.draw_rect(line, Color(0.03, 0.03, 0.03, 0.8))
	var fill := Rect2(line.position + Vector2(0, 2), Vector2(view.x * share, 4.0))
	_bars.draw_rect(fill, Color(0.78, 0.55, 0.16))
	_bars.draw_rect(Rect2(fill.position, Vector2(fill.size.x, 1.5)), Color(1.0, 0.9, 0.55, 0.9))
	if share > 0.0 and share < 1.0:
		_bars.draw_circle(Vector2(view.x * share, line.position.y + 4.0), 3.0, Color(1.0, 0.92, 0.6, 0.9))
	for k in range(1, 10):
		var tx := view.x * k / 10.0
		_bars.draw_line(Vector2(tx, line.position.y + 1.0), Vector2(tx, line.end.y), Color(0, 0, 0, 0.7), 1.0)
	_bars.draw_line(line.position, Vector2(view.x, line.position.y), Color(GOLD, 0.55), 1.0)
	var label := "EXP  MAX" if top else "EXP  %.2f%%" % _book.xp
	var lx := 12.0
	var ly := line.position.y - 6.0
	_bars.draw_string(font, Vector2(lx + 1.0, ly + 1.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0, 0, 0, 0.8))
	_bars.draw_string(font, Vector2(lx, ly), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1.0, 0.88, 0.6))
	if _gain_time < 1.8:
		var a := 1.0 - clampf((_gain_time - 1.0) / 0.8, 0.0, 1.0)
		var lw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		var gain := "+%.2f%%" % _gain
		var at := Vector2(lx + lw + 14.0, ly - 16.0 * _gain_time)
		_bars.draw_string(font, at + Vector2(1, 1), gain, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0, 0, 0, 0.7 * a))
		_bars.draw_string(font, at, gain, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1.0, 0.85, 0.35, a))
	# A new level, at the top of the screen.
	if _up_time < 3.2:
		var a := clampf(_up_time / 0.2, 0.0, 1.0) * (1.0 - clampf((_up_time - 2.4) / 0.8, 0.0, 1.0))
		var pop := 1.0 + 0.35 * (1.0 - clampf(_up_time / 0.3, 0.0, 1.0))
		var y := view.y * 0.2
		var title := "L E V E L   U P"
		var tw := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 40).x
		_bars.draw_set_transform(Vector2(view.x * 0.5, y), 0.0, Vector2(pop, pop))
		_bars.draw_string(font, Vector2(-tw * 0.5 + 2.0, 2.0), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 40,
				Color(0, 0, 0, 0.75 * a))
		_bars.draw_string(font, Vector2(-tw * 0.5, 0.0), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 40,
				Color(1.0, 0.86, 0.42, a))
		_bars.draw_set_transform(Vector2.ZERO)
		var sub := "Level %d" % _up_level
		var sw := font.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
		_bars.draw_string(font, Vector2((view.x - sw) * 0.5 + 1.5, y + 31.5), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 20,
				Color(0, 0, 0, 0.85 * a))
		_bars.draw_string(font, Vector2((view.x - sw) * 0.5, y + 30.0), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 20,
				Color(1.0, 0.9, 0.6, a))
		var half := tw * 0.5 + 30.0
		for side: float in [-1.0, 1.0]:
			var from := Vector2(view.x * 0.5 + side * (sw * 0.5 + 14.0), y + 23.0)
			var to := Vector2(view.x * 0.5 + side * half, y + 23.0)
			_bars.draw_line(from, to, Color(GOLD, 0.7 * a), 1.0)
			_bars.draw_colored_polygon(PackedVector2Array([to + Vector2(side * 5.0, 0), to + Vector2(0, -3),
					to + Vector2(-side * 5.0, 0), to + Vector2(0, 3)]), Color(GOLD, 0.8 * a))


func _on_skill_used(_slot: int, id: StringName) -> void:
	_said = String(Player.SKILLS[id]["name"])
	_said_time = 0.0


## The four squares, bottom centre.
func _draw_skills() -> void:
	var view := _bars.size
	var n := Player.SKILL_SLOTS
	var width := SLOT * n + SLOT_GAP * (n - 1)
	var origin := Vector2((view.x - width) * 0.5, view.y - SLOT_BOTTOM - SLOT)
	var font := ThemeDB.fallback_font
	for slot in n:
		var at := origin + Vector2((SLOT + SLOT_GAP) * slot, 0.0)
		var rect := Rect2(at, Vector2(SLOT, SLOT))
		var id := player.skill_in(slot)
		_bars.draw_rect(rect.grow(2.0), FRAME)
		_bars.draw_rect(rect, SLOT_FILL if id != &"" else SLOT_EMPTY)
		if id != &"":
			_icon(id, rect)
			var left := player.skill_cooldown_left(slot)
			if left > 0.0:
				var share := clampf(left / maxf(player.skill_cooldown(slot), 0.01), 0.0, 1.0)
				_bars.draw_rect(Rect2(at, Vector2(SLOT, SLOT * share)), SLOT_SHADE)
				var secs := str(ceili(left))
				var w := font.get_string_size(secs, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
				_bars.draw_string(font, at + Vector2((SLOT - w) * 0.5, SLOT * 0.5 + 7.0), secs,
						HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 1, 1, 0.95))
		var edge := EDGE
		var flash := 1.0 - clampf(_ready_flash[slot] / 0.5, 0.0, 1.0)
		if flash > 0.0 and id != &"":
			edge = EDGE.lerp(Color(1.0, 0.95, 0.75, 1.0), flash)
			_bars.draw_rect(rect.grow(3.0 + 3.0 * flash), Color(1.0, 0.9, 0.6, 0.35 * flash), false, 2.0)
		_bars.draw_rect(rect.grow(2.0), edge, false, 1.0)
		# The key, in the corner.
		_bars.draw_string(font, at + Vector2(4.0, 14.0), str(slot + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 13,
				Color(1, 1, 1, 0.85 if id != &"" else 0.4))
	if _said != "" and _said_time < 1.4:
		var a := 1.0 - clampf((_said_time - 0.9) / 0.5, 0.0, 1.0)
		var w := font.get_string_size(_said, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
		_bars.draw_string(font, Vector2((view.x - w) * 0.5, origin.y - 14.0), _said, HORIZONTAL_ALIGNMENT_LEFT,
				-1, 18, Color(1.0, 0.92, 0.7, a))


## A skill's picture, drawn: Rain of Arrows is three arrows coming down on a
## ring.
func _icon(id: StringName, rect: Rect2) -> void:
	var c := rect.get_center()
	match id:
		&"arrow_rain":
			var ring := PackedVector2Array()
			for k in 25:
				var t := TAU * k / 24.0
				ring.append(c + Vector2(cos(t) * 17.0, 12.0 + sin(t) * 5.0))
			_bars.draw_polyline(ring, Color(ICON, 0.8), 1.5)
			for k in 3:
				var tip := c + Vector2(-11.0 + 11.0 * k, 9.0 - 3.0 * float(k % 2))
				var tail := tip + Vector2(7.0, -24.0)
				_bars.draw_line(tail, tip, ICON, 2.0)
				var along := (tip - tail).normalized()
				var side := Vector2(-along.y, along.x)
				_bars.draw_colored_polygon(PackedVector2Array([tip + along * 3.0, tip - along * 4.0 + side * 3.5,
						tip - along * 4.0 - side * 3.5]), ICON)
				_bars.draw_line(tail, tail + along * 5.0 + side * 3.0, Color(0.85, 0.3, 0.25), 2.0)
				_bars.draw_line(tail, tail + along * 5.0 - side * 3.0, Color(0.85, 0.3, 0.25), 2.0)
		&"hunters_mark":
			# The mark: a ring, four points in, an eye.
			var red := Color(0.95, 0.25, 0.18)
			_bars.draw_arc(c, 17.0, 0.0, TAU, 32, ICON, 2.0)
			for k in 4:
				var a := PI * 0.5 * k
				var d := Vector2(sin(a), -cos(a))
				var s := Vector2(-d.y, d.x)
				_bars.draw_colored_polygon(PackedVector2Array([c + d * 12.0, c + d * 21.0 + s * 4.0,
						c + d * 21.0 - s * 4.0]), ICON)
			var eye := PackedVector2Array()
			for k in 21:
				var t := TAU * k / 20.0
				eye.append(c + Vector2(cos(t) * 9.0, sin(t) * 4.5))
			_bars.draw_polyline(eye, red, 2.0)
			_bars.draw_line(c + Vector2(0, -4), c + Vector2(0, 4), red, 2.5)
		&"piercing_arrow":
			# One arrow straight through two bodies, rings along it.
			var wind := Color(0.45, 0.85, 1.0)
			for k in 2:
				var x := -4.0 + 12.0 * k
				_bars.draw_rect(Rect2(c + Vector2(x - 3.0, -12.0), Vector2(6.0, 24.0)), Color(0.55, 0.5, 0.42, 0.9))
			_bars.draw_line(c + Vector2(-21, 0), c + Vector2(17, 0), ICON, 2.0)
			_bars.draw_colored_polygon(PackedVector2Array([c + Vector2(22, 0), c + Vector2(15, -4),
					c + Vector2(15, 4)]), ICON)
			for k in 3:
				_bars.draw_arc(c + Vector2(-14.0 + 12.0 * k, 0), 5.0 + k, 0.0, TAU, 16, Color(wind, 0.8), 1.2)
		&"fire_arrow":
			# An arrow coming down with its head alight.
			var tip := c + Vector2(9, 11)
			var tail := c + Vector2(-12, -14)
			_bars.draw_line(tail, tip, ICON, 2.0)
			var along := (tip - tail).normalized()
			var side := Vector2(-along.y, along.x)
			_bars.draw_colored_polygon(PackedVector2Array([tip + along * 6.0 + side * 0.0, tip - along * 2.0 + side * 6.0,
					tip - side * 6.0 - along * 2.0, ]), Color(1.0, 0.55, 0.12))
			_bars.draw_colored_polygon(PackedVector2Array([tip + along * 2.0, tip - along * 1.0 + side * 3.0,
					tip - side * 3.0 - along * 1.0]), Color(1.0, 0.9, 0.5))
			for k in 3:
				_bars.draw_circle(tip - along * (8.0 + 6.0 * k) + side * (3.0 - 3.0 * k), 1.6, Color(1.0, 0.5, 0.1, 0.7))
		&"poison_blade":
			# A dagger point up, a green drop running off it.
			var venom := Color(0.45, 1.0, 0.25)
			_bars.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -20), c + Vector2(4, 4),
					c + Vector2(-4, 4)]), Color(0.8, 0.85, 0.85))
			_bars.draw_line(c + Vector2(0, -16), c + Vector2(0, 3), venom, 2.0)
			_bars.draw_line(c + Vector2(-9, 5), c + Vector2(9, 5), ICON, 3.0)
			_bars.draw_line(c + Vector2(0, 6), c + Vector2(0, 17), Color(0.55, 0.12, 0.12), 3.5)
			_bars.draw_circle(c + Vector2(9, 12), 3.5, venom)
			_bars.draw_colored_polygon(PackedVector2Array([c + Vector2(9, 5), c + Vector2(12, 11),
					c + Vector2(6, 11)]), venom)


## One bar: a dark frame with a thin gilt edge, what is left, and — if asked —
## a paler stretch past it for what was just lost.
func _bar(at: Vector2, width: float, height: float, full: float, colour: Color,
		ghost: float, ghost_colour: Color) -> void:
	var outer := Rect2(at - Vector2(2, 2), Vector2(width + 4, height + 4))
	_bars.draw_rect(outer, FRAME)
	if ghost > full:
		_bars.draw_rect(Rect2(at + Vector2(width * full, 0), Vector2(width * (ghost - full), height)),
				ghost_colour)
	if full > 0.0:
		_bars.draw_rect(Rect2(at, Vector2(width * clampf(full, 0.0, 1.0), height)), colour)
		# A lighter line along the top, so the bar reads as a bar and not a slab.
		_bars.draw_rect(Rect2(at, Vector2(width * clampf(full, 0.0, 1.0), maxf(height * 0.25, 1.0))),
				Color(1, 1, 1, 0.14))
	_bars.draw_rect(outer, EDGE, false, 1.0)
