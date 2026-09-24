class_name Inventory
extends CanvasLayer

## What the player carries, opened with **I**.
##
## For now that is the shield. The knight has two and carries one at a time:
##
## * **The round shield** — light. Blocks, and **parries**: met as it comes up,
##   a blow is thrown back and whoever threw it reels open.
## * **The tower shield** — tall and heavy. It cannot parry, but a blow taken on
##   it costs little more than half the stamina, and he crouches behind it.
##
## Characters with no shield see their weapon and a note that they carry none.
## The world does not stop while it is open — the game may be online — so the
## body simply stands still: [member Player.menu_open] holds its input off.
##
## 1 and 2 put a shield on, as clicking its card does; I or Escape closes.

enum Shields { ROUND, TOWER }

const NAMES := ["Round shield", "Tower shield"]
const LINES := [
	"Light. Blocks, and parries: raise it as the blow comes and the blow is thrown back, its striker left open.",
	"Tall and heavy. Cannot parry, but a blow on it costs half the stamina, and he crouches behind it.",
]
const WEAPONS := ["Sword", "Bow", "Staff"]

var player: Player

var _root: Control
var _cards: Array[Button] = []
var _icons: Array[Control] = []


func _ready() -> void:
	layer = 6
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.visible = false
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	var panel := PanelContainer.new()
	var style := MenuStyle.panel_style(Color(MenuStyle.SLATE, 0.96))
	style.border_color = MenuStyle.GOLD_DIM
	style.set_border_width_all(1)
	style.content_margin_left = 34.0
	style.content_margin_right = 34.0
	style.content_margin_top = 24.0
	style.content_margin_bottom = 24.0
	panel.add_theme_stylebox_override("panel", style)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_root.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	panel.add_child(column)
	column.add_child(MenuStyle.heading("INVENTORY"))

	var weapon := MenuStyle.label("", MenuStyle.BODY_SIZE, MenuStyle.GOLD)
	weapon.name = "Weapon"
	column.add_child(weapon)

	var row := HBoxContainer.new()
	row.name = "Shields"
	row.add_theme_constant_override("separation", 18)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(row)
	for i in NAMES.size():
		row.add_child(_card(i))

	var none := MenuStyle.label("He carries no shield.", MenuStyle.BODY_SIZE, MenuStyle.GOLD_DIM)
	none.name = "None"
	column.add_child(none)
	column.add_child(MenuStyle.label("1 / 2  put one on        I  close", 15, MenuStyle.GOLD_DIM))


func _card(i: int) -> Button:
	var card := Button.new()
	card.custom_minimum_size = Vector2(320, 260)
	card.focus_mode = Control.FOCUS_NONE
	card.pressed.connect(func() -> void: equip(i))
	var stack := VBoxContainer.new()
	stack.set_anchors_preset(Control.PRESET_FULL_RECT)
	stack.offset_top = 14
	stack.offset_bottom = -12
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_theme_constant_override("separation", 8)
	card.add_child(stack)
	var icon := Control.new()
	icon.custom_minimum_size = Vector2(0, 120)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.draw.connect(_draw_icon.bind(icon, i))
	stack.add_child(icon)
	var title := MenuStyle.label(NAMES[i], 22, MenuStyle.CREAM)
	title.name = "Title"
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(title)
	var text := MenuStyle.label(LINES[i], 14, MenuStyle.GOLD_DIM)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = Vector2(280, 0)
	text.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	stack.add_child(text)
	_cards.append(card)
	_icons.append(icon)
	return card


## The two shields, drawn: the round one with its boss and studs, the tower one
## crimson with the cross.
func _draw_icon(icon: Control, i: int) -> void:
	var c := icon.size * 0.5
	if i == Shields.ROUND:
		icon.draw_circle(c, 52.0, Color(0.55, 0.42, 0.18))
		icon.draw_circle(c, 47.0, Color(0.78, 0.8, 0.84))
		for k in 8:
			var a := TAU * k / 8.0
			icon.draw_line(c, c + Vector2(cos(a), sin(a)) * 44.0, Color(0.8, 0.6, 0.2), 3.0)
			icon.draw_circle(c + Vector2(cos(a), sin(a)) * 40.0, 3.5, Color(0.12, 0.12, 0.14))
		icon.draw_circle(c, 11.0, Color(0.85, 0.62, 0.2))
	else:
		var w := 70.0
		var h := 112.0
		var body := PackedVector2Array()
		for k in 13:
			var a := PI + PI * k / 12.0
			body.append(c + Vector2(cos(a) * w * 0.5, -h * 0.5 + 22.0 + sin(a) * 22.0))
		body.append(c + Vector2(w * 0.5, h * 0.5))
		body.append(c + Vector2(-w * 0.5, h * 0.5))
		icon.draw_colored_polygon(body, Color(0.12, 0.12, 0.13))
		var inner := PackedVector2Array()
		for p in body:
			inner.append(c + (p - c) * 0.9)
		icon.draw_colored_polygon(inner, Color(0.5, 0.06, 0.07))
		var gold := Color(0.85, 0.62, 0.2)
		icon.draw_rect(Rect2(c + Vector2(-4, -36), Vector2(8, 70)), gold)
		icon.draw_rect(Rect2(c + Vector2(-24, -8), Vector2(48, 8)), gold)
		icon.draw_circle(c + Vector2(0, -4), 8.0, gold)


func _input(event: InputEvent) -> void:
	if player == null or not is_instance_valid(player):
		return
	if event.is_action_pressed("inventory"):
		toggle()
		get_viewport().set_input_as_handled()
		return
	if not _root.visible:
		return
	if event.is_action_pressed("ui_cancel"):
		toggle()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		var key := (event as InputEventKey).physical_keycode
		if key == KEY_1:
			equip(Shields.ROUND)
		elif key == KEY_2:
			equip(Shields.TOWER)


func is_open() -> bool:
	return _root.visible


func toggle() -> void:
	_root.visible = not _root.visible
	player.menu_open = _root.visible
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if _root.visible else Input.MOUSE_MODE_CAPTURED
	if _root.visible:
		_refresh()


func equip(kind: int) -> void:
	if player == null or not _has_shield():
		return
	player.set_shield(kind)
	_refresh()


func _has_shield() -> bool:
	return player.profile != null and player.profile.can_block


func _refresh() -> void:
	var weapon := _root.find_child("Weapon", true, false) as Label
	var shields := _root.find_child("Shields", true, false) as Control
	var none := _root.find_child("None", true, false) as Control
	var kind := int(player.profile.weapon) if player.profile != null else 0
	var who := player.profile.display_name if player.profile != null else ""
	weapon.text = "%s  ·  %s" % [who, WEAPONS[clampi(kind, 0, WEAPONS.size() - 1)]]
	shields.visible = _has_shield()
	none.visible = not _has_shield()
	for i in _cards.size():
		var chosen := i == player.shield_kind
		MenuStyle.style_button(_cards[i], chosen)
		var title := _cards[i].find_child("Title", true, false) as Label
		title.text = NAMES[i] + ("  (carried)" if chosen else "")
		_icons[i].queue_redraw()
