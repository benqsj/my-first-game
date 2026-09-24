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
