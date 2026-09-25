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
## * **The skills are five squares at the bottom**, keys 1 to 5: the skill's
##   picture, its key in the corner, and while it is coming back a shade that
##   drains down off it with the seconds left. It flashes when it is ready again;
##   used, its name shows over the bar for a moment. An empty slot is a dark one.

## Pixels per point of health and of stamina.
const HEALTH_SCALE := 2.1
const STAMINA_SCALE := 2.4
const MARGIN := Vector2(18.0, 40.0)
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
var _ready_flash: PackedFloat32Array = PackedFloat32Array([9.0, 9.0, 9.0, 9.0, 9.0])
var _last_left: PackedFloat32Array = PackedFloat32Array([0.0, 0.0, 0.0, 0.0, 0.0])
var _said: String = ""
var _said_time: float = 9.0

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
	_bar(at, player.max_health * HEALTH_SCALE, HEALTH_HEIGHT,
			player.health / maxf(player.max_health, 1.0), HEALTH,
			_lost / maxf(player.max_health, 1.0), HEALTH_LOST)
	at.y += HEALTH_HEIGHT + GAP
	var winded := player.is_winded()
	_bar(at, player.max_stamina * STAMINA_SCALE, STAMINA_HEIGHT,
			maxf(player.stamina, 0.0) / maxf(player.max_stamina, 1.0),
			STAMINA_SPENT if winded else STAMINA, 0.0, Color.TRANSPARENT)
	_draw_skills()


func _on_skill_used(_slot: int, id: StringName) -> void:
	_said = String(Player.SKILLS[id]["name"])
	_said_time = 0.0


## The five squares, bottom centre.
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
