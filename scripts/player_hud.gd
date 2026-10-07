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
## * **The skills are four sockets on a gilt plate at the bottom**, keys 1 to
##   4: the skill's painted plate ([UiArt] icons), its key on a little tab
##   under it, and while it is coming back a shadow that sweeps round off it
##   like a clock hand with the seconds left. Short of the stamina for it, it
##   is greyed and its key goes red. It flashes gold when it is ready again;
##   used, its name shows over the plate for a moment. An empty socket is a
##   dark one.

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
## What he has just picked up off the ground ([LootItem]), and its picture.
var _found: String = ""
var _found_pic: Texture2D = null
var _found_time: float = 9.0
var _said_time: float = 9.0
## The hero's [Leveling], found once it is there; the last experience gained and
## the last level reached, and how long ago.
var _book: Leveling
var _gain: float = 0.0
var _gain_time: float = 9.0
var _up_level: int = 0
var _up_time: float = 9.0
## His gold ([Purse]): the count top right, and the last change rising off it
## (gold for found, red for stolen).
var _purse: Purse
var _gold_by: int = 0
var _gold_time: float = 9.0
var _poison: HeroPoison
const POISONED := Color(0.36, 0.7, 0.12)

const GOLD := Color(0.95, 0.78, 0.36)
const GOLD_DEEP := Color(0.55, 0.38, 0.12)
## The longest a bar grows, however high the level.
const MAX_BAR := 480.0

const SLOT := 62.0
const SLOT_GAP := 12.0
const SLOT_BOTTOM := 34.0
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
	_found_time += delta
	_gain_time += delta
	_up_time += delta
	_gold_time += delta
	if _purse == null:
		_purse = Purse.of(player)
		if _purse != null:
			_purse.changed.connect(func(_total: int, by: int) -> void:
				_gold_by = by if _gold_time > 1.2 or signi(by) != signi(_gold_by) else _gold_by + by
				_gold_time = 0.0)
	if _poison == null:
		_poison = HeroPoison.of(player)
	if _book == null:
		_book = player.get_node_or_null(^"Leveling") as Leveling
		if _book != null:
			_book.gained.connect(func(amount: float) -> void:
				_gain = amount
				_gain_time = 0.0)
			_book.leveled_up.connect(func(level: int) -> void:
				_up_level = level
				# "LEVEL UP" when he is set down out of the light ([LevelBeam]).
				_up_time = -LevelBeam.LAND_AT)
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
	var poisoned := _poison != null and _poison.poisoned()
	_bar(at, minf(player.max_health * HEALTH_SCALE, MAX_BAR), HEALTH_HEIGHT,
			player.health / maxf(player.max_health, 1.0), POISONED if poisoned else HEALTH,
			_lost / maxf(player.max_health, 1.0), HEALTH_LOST)
	at.y += HEALTH_HEIGHT + GAP
	var winded := player.is_winded()
	_bar(at, minf(player.max_stamina * STAMINA_SCALE, MAX_BAR), STAMINA_HEIGHT,
			maxf(player.stamina, 0.0) / maxf(player.max_stamina, 1.0),
			STAMINA_SPENT if winded else STAMINA, 0.0, Color.TRANSPARENT)
	_draw_skills()
	_draw_level()
	_draw_gold()
	_draw_found()


## He picked up `what` ([LootItem]): its picture and name, a moment, low in
## the middle of the screen.
func found(what: String, pic: Texture2D = null) -> void:
	_found = what
	_found_pic = pic
	_found_time = 0.0


func _draw_found() -> void:
	if _found == "" or _found_time > 3.2:
		return
	var a := clampf(_found_time / 0.2, 0.0, 1.0) * (1.0 - clampf((_found_time - 2.6) / 0.6, 0.0, 1.0))
	var font := UiArt.font("bold")
	var view := _bars.size
	var side := 64.0
	var text_w := font.get_string_size(_found, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
	var w := side + 14.0 + maxf(text_w, font.get_string_size("FOUND", HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x) + 28.0
	var box := Rect2(Vector2((view.x - w) * 0.5, view.y * 0.62), Vector2(w, side + 16.0))
	_bars.draw_rect(box, Color(0.05, 0.04, 0.04, 0.72 * a))
	_bars.draw_rect(box, Color(EDGE, EDGE.a * a), false, 1.0)
	var pic_rect := Rect2(box.position + Vector2(10.0, 8.0), Vector2(side, side))
	_bars.draw_rect(pic_rect, Color(SLOT_FILL, SLOT_FILL.a * a))
	if _found_pic != null:
		_bars.draw_texture_rect(_found_pic, pic_rect, false, Color(1, 1, 1, a))
	var x := pic_rect.end.x + 14.0
	_bars.draw_string(font, Vector2(x, box.position.y + 30.0), "FOUND", HORIZONTAL_ALIGNMENT_LEFT, -1, 14,
			Color(GOLD, 0.85 * a))
	_bars.draw_string(font, Vector2(x, box.position.y + 58.0), _found, HORIZONTAL_ALIGNMENT_LEFT, -1, 22,
			Color(1.0, 0.95, 0.85, a))


## The gold: a coin and the count in the top right corner.
func _draw_gold() -> void:
	if _purse == null:
		return
	var font := UiArt.font("bold")
	var view := _bars.size
	var text := str(_purse.gold)
	var size := 22
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var right := view.x - 28.0
	var c := Vector2(right - w - 18.0, 36.0)
	_bars.draw_circle(c + Vector2(1.5, 2.0), 11.0, Color(0, 0, 0, 0.5))
	_bars.draw_circle(c, 11.0, GOLD_DEEP)
	_bars.draw_circle(c, 9.0, GOLD)
	_bars.draw_arc(c, 6.0, 0.0, TAU, 18, GOLD_DEEP, 1.5)
	_bars.draw_string(font, Vector2(right - w + 1.5, 44.0 + 2.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size,
			Color(0, 0, 0, 0.7))
	_bars.draw_string(font, Vector2(right - w, 44.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, GOLD)
	if _gold_by != 0 and _gold_time < 1.6:
		var a := 1.0 - clampf((_gold_time - 0.8) / 0.8, 0.0, 1.0)
		var rise := _gold_time * 18.0
		var tint := Color(1.0, 0.9, 0.5, a) if _gold_by > 0 else Color(1.0, 0.3, 0.22, a)
		var said := ("+%d" % _gold_by) if _gold_by > 0 else ("%d" % _gold_by)
		var sw := font.get_string_size(said, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
		_bars.draw_string(font, Vector2(right - sw, 70.0 + rise * (1.0 if _gold_by < 0 else -0.3)), said,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 18, tint)


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


## The four sockets on their plate, bottom centre.
func _draw_skills() -> void:
	var view := _bars.size
	var n := Player.SKILL_SLOTS
	var width := SLOT * n + SLOT_GAP * (n - 1)
	var origin := Vector2((view.x - width) * 0.5, view.y - SLOT_BOTTOM - SLOT)
	var font := UiArt.font("title")
	var digits := UiArt.font("bold")
	UiArt.draw_frame(_bars, Rect2(origin - Vector2(22.0, 12.0), Vector2(width + 44.0, SLOT + 28.0)), "bar_plate", 20.0)
	for slot in n:
		var at := origin + Vector2((SLOT + SLOT_GAP) * slot, 0.0)
		var rect := Rect2(at, Vector2(SLOT, SLOT))
		var id := player.skill_in(slot)
		var flash := 1.0 - clampf(_ready_flash[slot] / 0.5, 0.0, 1.0)
		if flash > 0.0 and id != &"":
			for k in 4:
				_bars.draw_rect(rect.grow(3.0 + 3.0 * k * flash), Color(1.0, 0.82, 0.4, 0.16 * flash), false, 3.0)
		UiArt.draw_frame(_bars, rect.grow(3.0), "socket", 8.0)
		if id == &"":
			_bars.draw_string(digits, at + Vector2(0.0, SLOT * 0.5 + 6.0), "—", HORIZONTAL_ALIGNMENT_CENTER, SLOT, 18,
					Color(1, 1, 1, 0.15))
		else:
			var short := player.stamina < float(Player.SKILLS[id].get("stamina", 0.0))
			var left := player.skill_cooldown_left(slot)
			var inner := rect.grow(-3.0)
			var tex := UiArt.icon("skill_" + String(id))
			var tint := Color.WHITE if not short else Color(0.55, 0.5, 0.5)
			if left > 0.0:
				tint = tint.darkened(0.25)
			if tex != null:
				_bars.draw_texture_rect(tex, inner, false, tint)
			else:
				_icon(id, rect)
			if left > 0.0:
				var share := clampf(left / maxf(player.skill_cooldown(slot), 0.01), 0.0, 1.0)
				_sweep(inner, share)
				var secs := str(ceili(left))
				var y := at.y + SLOT * 0.5 + 9.0
				_bars.draw_string_outline(digits, Vector2(at.x, y), secs, HORIZONTAL_ALIGNMENT_CENTER, SLOT, 24, 5,
						Color(0, 0, 0, 0.85))
				_bars.draw_string(digits, Vector2(at.x, y), secs, HORIZONTAL_ALIGNMENT_CENTER, SLOT, 24,
						Color(1.0, 0.96, 0.86))
			if flash > 0.0:
				_bars.draw_rect(inner, Color(1.0, 0.9, 0.6, 0.35 * flash))
				_bars.draw_rect(rect.grow(2.0), Color(1.0, 0.9, 0.6, flash), false, 2.0)
		# No key under the socket (the user's word, 2026-10-05: the numbers are
		# not needed); a skill short of stamina is greyed.
	if _said != "" and _said_time < 1.4:
		var a := 1.0 - clampf((_said_time - 0.9) / 0.5, 0.0, 1.0)
		var y := origin.y - 26.0
		_bars.draw_string_outline(font, Vector2(0.0, y), _said, HORIZONTAL_ALIGNMENT_CENTER, view.x, 22, 6,
				Color(0, 0, 0, 0.7 * a))
		_bars.draw_string(font, Vector2(0.0, y), _said, HORIZONTAL_ALIGNMENT_CENTER, view.x, 22,
				Color(1.0, 0.88, 0.6, a))


## The cooldown's shadow over `rect`: a pie of `share` of a turn, from twelve
## o'clock round, clipped to the square.
func _sweep(rect: Rect2, share: float) -> void:
	if share <= 0.0:
		return
	var c := rect.get_center()
	var r := rect.size.x
	var pts := PackedVector2Array([c])
	var steps := maxi(3, int(48 * share))
	# the pie runs from where the hand is now back round to twelve o'clock
	var start := TAU * (1.0 - share)
	for k in steps + 1:
		var t := -PI * 0.5 + start + (TAU - start) * k / steps
		var p := c + Vector2(cos(t), sin(t)) * r
		p.x = clampf(p.x, rect.position.x, rect.end.x)
		p.y = clampf(p.y, rect.position.y, rect.end.y)
		pts.append(p)
	_bars.draw_colored_polygon(pts, Color(0.0, 0.0, 0.0, 0.62))
	# the hand
	var hand := -PI * 0.5 + start
	var tip := c + Vector2(cos(hand), sin(hand)) * r
	tip.x = clampf(tip.x, rect.position.x, rect.end.x)
	tip.y = clampf(tip.y, rect.position.y, rect.end.y)
	_bars.draw_line(c, tip, Color(1.0, 0.85, 0.5, 0.7), 1.5)


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
		&"frost_spears":
			# A crescent of ice spears over a ring, all pointing one way.
			var ice := Color(0.7, 0.92, 1.0)
			for k in 5:
				var a := deg_to_rad(lerpf(-60.0, 60.0, k / 4.0))
				var base := c + Vector2(sin(a) * 15.0 - 6.0, -cos(a) * 9.0 + 4.0)
				var tip := base + Vector2(14.0, -6.0)
				var along := (tip - base).normalized()
				var side := Vector2(-along.y, along.x)
				_bars.draw_colored_polygon(PackedVector2Array([tip, base + side * 2.6, base - along * 3.0,
						base - side * 2.6]), ice)
			_bars.draw_arc(c + Vector2(-2, 14), 9.0, PI * 1.1, PI * 1.9, 12, Color(ice, 0.6), 1.5)
		&"frost_step":
			# Her shape gone to frost on the left, a streak, and a flash on the
			# right; crystals left standing on the ground between.
			var ice := Color(0.7, 0.92, 1.0)
			var ground := c.y + 13.0
			_bars.draw_line(Vector2(c.x - 20.0, ground), Vector2(c.x + 20.0, ground), Color(ice, 0.45), 3.0)
			for k in 5:
				var x := c.x - 15.0 + 7.5 * k
				var tall := 5.0 + 3.0 * float((k * 7) % 3)
				_bars.draw_colored_polygon(PackedVector2Array([Vector2(x - 2.2, ground), Vector2(x + 0.6 * (k - 2), ground - tall),
						Vector2(x + 2.2, ground)]), ice)
			for k in 4:
				_bars.draw_circle(c + Vector2(-16.0 + 2.5 * (k % 2), -8.0 + 5.0 * k), 1.4, Color(ice, 0.8 - 0.15 * k))
			_bars.draw_line(c + Vector2(-12, -2), c + Vector2(10, -2), Color(ice, 0.85), 2.0)
			_bars.draw_colored_polygon(PackedVector2Array([c + Vector2(16, -2), c + Vector2(9, -6), c + Vector2(9, 2)]), ice)
			_bars.draw_circle(c + Vector2(15, -2), 6.0, Color(1, 1, 1, 0.35))
		&"dark_grasp":
			# Two black hands up out of a violet ring, clawed fingers closing.
			var violet := Color(0.72, 0.45, 1.0)
			var ink := Color(0.1, 0.04, 0.14)
			var ring := PackedVector2Array()
			for k in 25:
				var t := TAU * k / 24.0
				ring.append(c + Vector2(cos(t) * 18.0, 13.0 + sin(t) * 5.0))
			_bars.draw_polyline(ring, violet, 2.0)
			for k in 2:
				var s := -1.0 if k == 0 else 1.0
				var wrist := c + Vector2(s * 7.0, -4.0)
				var root := c + Vector2(s * 9.0, 13.0)
				_bars.draw_line(root, wrist, violet, 6.0)
				_bars.draw_line(root, wrist, ink, 3.5)
				for f in 4:
					var a := deg_to_rad(-40.0 + 22.0 * f) * s
					var knuckle := wrist + Vector2(sin(a), -cos(a)) * 5.0
					var tip := knuckle + Vector2(sin(a - s * 0.9), -cos(a - s * 0.9)) * 8.0
					_bars.draw_line(wrist, knuckle, violet, 2.5)
					_bars.draw_line(knuckle, tip, violet, 1.8)
		&"black_comets":
			# Three black rocks coming down from the top left, each dragging
			# a tail of violet fire, and the ground cracked where one struck.
			var violet := Color(0.72, 0.45, 1.0)
			var ink := Color(0.1, 0.04, 0.14)
			var heads: Array[Vector2] = [Vector2(-12.0, 2.0), Vector2(3.0, -9.0), Vector2(11.0, 9.0)]
			for k in heads.size():
				var head := c + heads[k]
				var big := 5.5 if k == 2 else 4.0
				var back := Vector2(-0.72, -0.7)
				_bars.draw_line(head + back * 3.0, head + back * 15.0, Color(violet, 0.35), big * 1.6)
				_bars.draw_line(head + back * 2.0, head + back * 11.0, Color(violet, 0.8), big * 0.7)
				_bars.draw_circle(head, big + 1.2, violet)
				_bars.draw_circle(head, big, ink)
			var hit := c + Vector2(11.0, 17.0)
			for k in 5:
				var a := deg_to_rad(-160.0 + 35.0 * k)
				_bars.draw_line(hit + Vector2(cos(a), sin(a)) * 4.0, hit + Vector2(cos(a), sin(a)) * 9.0, violet, 1.5)
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
		&"stun_arrow":
			# An arrow flying flat, three little stars going round over it.
			var gold := Color(1.0, 0.86, 0.3)
			_bars.draw_line(c + Vector2(-19, 7), c + Vector2(15, 7), ICON, 2.0)
			_bars.draw_colored_polygon(PackedVector2Array([c + Vector2(21, 7), c + Vector2(13, 3),
					c + Vector2(13, 11)]), ICON)
			_bars.draw_line(c + Vector2(-19, 7), c + Vector2(-14, 3), Color(0.85, 0.3, 0.25), 2.0)
			_bars.draw_line(c + Vector2(-19, 7), c + Vector2(-14, 11), Color(0.85, 0.3, 0.25), 2.0)
			var orbit := PackedVector2Array()
			for k in 25:
				var t := TAU * k / 24.0
				orbit.append(c + Vector2(cos(t) * 12.0, -9.0 + sin(t) * 4.0))
			_bars.draw_polyline(orbit, Color(gold, 0.45), 1.0)
			for k in 3:
				var t := TAU * k / 3.0 + 0.4
				var at := c + Vector2(cos(t) * 12.0, -9.0 + sin(t) * 4.0)
				var pts := PackedVector2Array()
				for j in 10:
					var r := 4.0 if j % 2 == 0 else 1.7
					var u := TAU * j / 10.0 - PI * 0.5
					pts.append(at + Vector2(cos(u), sin(u)) * r)
				_bars.draw_colored_polygon(pts, gold)
		&"rising_cut":
			# A sword brought up from low: the blade up and over, the arc it cut
			# rising behind it, and the dust of the run at its foot.
			var arc := PackedVector2Array()
			for k in 13:
				var t := lerpf(PI * 0.95, PI * 1.6, k / 12.0)
				arc.append(c + Vector2(cos(t), sin(t)) * 18.0 + Vector2(4, 4))
			_bars.draw_polyline(arc, Color(0.75, 0.9, 1.0, 0.85), 3.0)
			var hilt := c + Vector2(-8, 13)
			var tip := c + Vector2(10, -18)
			var along := (tip - hilt).normalized()
			var side := Vector2(-along.y, along.x)
			_bars.draw_colored_polygon(PackedVector2Array([tip, hilt + along * 6.0 + side * 3.0,
					hilt + along * 6.0 - side * 3.0]), Color(0.85, 0.88, 0.9))
			_bars.draw_line(hilt + along * 6.0 + side * 7.0, hilt + along * 6.0 - side * 7.0, ICON, 3.0)
			_bars.draw_line(hilt + along * 5.0, hilt - along * 3.0, Color(0.55, 0.12, 0.12), 3.5)
			for k in 3:
				_bars.draw_circle(c + Vector2(-16.0 + 5.0 * k, 18.0 - 2.0 * (k % 2)), 2.2, Color(0.75, 0.65, 0.5, 0.7))
		&"shadow_slide":
			# A cut swept across out of a slide: its arc, the blade at the end
			# of it, and the shadows it slid in from fading behind.
			var shade := Color(0.55, 0.3, 1.0)
			for k in 3:
				var x := -18.0 + 6.0 * k
				_bars.draw_line(c + Vector2(x, -10), c + Vector2(x - 4.0, 16), Color(shade, 0.3 + 0.2 * k), 4.0)
			var arc := PackedVector2Array()
			for k in 13:
				var t := lerpf(PI * 1.15, PI * 1.85, k / 12.0)
				arc.append(c + Vector2(cos(t) * 19.0 + 6.0, sin(t) * 12.0 + 8.0))
			_bars.draw_polyline(arc, Color(0.75, 0.9, 1.0, 0.85), 3.0)
			var hilt := c + Vector2(8, 10)
			var tip := c + Vector2(22, -10)
			var along := (tip - hilt).normalized()
			var side := Vector2(-along.y, along.x)
			_bars.draw_colored_polygon(PackedVector2Array([tip, hilt + along * 5.0 + side * 2.5,
					hilt + along * 5.0 - side * 2.5]), Color(0.85, 0.88, 0.9))
			_bars.draw_line(hilt + along * 5.0 + side * 6.0, hilt + along * 5.0 - side * 6.0, ICON, 3.0)
			_bars.draw_line(hilt + along * 4.0, hilt - along * 4.0, Color(0.55, 0.12, 0.12), 3.5)
		&"shadow_lance":
			# A sword held level, point first, the shadows it slid in on
			# strung out behind the hand, and a spark where the point arrives.
			var shade := Color(0.55, 0.3, 1.0)
			for k in 3:
				var x := -20.0 + 6.0 * k
				_bars.draw_line(c + Vector2(x, -9), c + Vector2(x - 3.0, 15), Color(shade, 0.3 + 0.2 * k), 4.0)
			var hilt := c + Vector2(-6, 2)
			var tip := c + Vector2(20, 2)
			_bars.draw_colored_polygon(PackedVector2Array([tip, hilt + Vector2(6, -2.5), hilt + Vector2(6, 2.5)]),
					Color(0.85, 0.88, 0.9))
			_bars.draw_line(hilt + Vector2(6, -7), hilt + Vector2(6, 7), ICON, 3.0)
			_bars.draw_line(hilt + Vector2(5, 0), hilt + Vector2(-4, 0), Color(0.55, 0.12, 0.12), 3.5)
			for k in 4:
				var a := -0.9 + 0.6 * k
				_bars.draw_line(tip + Vector2(2, 0), tip + Vector2(2, 0) + Vector2(cos(a), sin(a)) * 6.0,
						Color(1.0, 0.95, 0.75, 0.9), 1.5)
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
