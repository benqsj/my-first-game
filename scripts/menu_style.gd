class_name MenuStyle
extends Object

## What every screen in the game is made of.
##
## The front menu and the pause menu are the same handful of widgets with the
## same look, so the look lives in one place. Everything that decides it is a
## constant here: change `GOLD` and both screens change.
##
## Static, and every function returns a node rather than taking one, so a screen
## is a list of calls rather than a scene tree to keep in step with a script.

const GOLD := Color("d0a044")
const GOLD_DIM := Color("8a6a2c")
const CREAM := Color("ece4d6")
const SLATE := Color("15181d")
const SLATE_DEEP := Color("0a0c0f")
const PANEL := Color("1d222a")
const PANEL_HOT := Color("272e39")
const CRIMSON := Color("76202a")

const TITLE_SIZE := 92
const HEADING_SIZE := 34
const BUTTON_SIZE := 26
const BODY_SIZE := 17
const BUTTON_WIDTH := 340.0
const BUTTON_HEIGHT := 58.0

## Dusk over the mountains ([MenuBackdrop]): a sky, the moon, three ranges
## drifting and sparks rising, the left side sunk into shadow for the menu.
static func background(onto: Control) -> void:
	var sky := ColorRect.new()
	sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	sky.color = SLATE_DEEP
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	onto.add_child(sky)
	onto.add_child(MenuBackdrop.new())


static func page_column() -> Control:
	var page := VBoxContainer.new()
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	page.alignment = BoxContainer.ALIGNMENT_CENTER
	page.add_theme_constant_override("separation", 26)
	return page


static func button_column() -> VBoxContainer:
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 12)
	return column


static func title() -> Control:
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 6)
	var title := label("VEPXIS", TITLE_SIZE + 12, Color("e9bd5c"), "deco")
	title.add_theme_color_override("font_shadow_color", Color(0.95, 0.5, 0.12, 0.38))
	title.add_theme_constant_override("shadow_offset_x", 0)
	title.add_theme_constant_override("shadow_offset_y", 0)
	title.add_theme_constant_override("shadow_outline_size", 26)
	title.add_theme_color_override("font_outline_color", Color("3a2208"))
	title.add_theme_constant_override("outline_size", 6)
	stack.add_child(title)
	stack.add_child(ornament(420.0))
	var sub := label("THE KNIGHT IN THE PANTHER'S SKIN", BODY_SIZE + 2, Color("c79a4a"), "head")
	sub.add_theme_constant_override("line_spacing", 4)
	stack.add_child(sub)
	return stack


## A gold rule with a diamond in the middle and a dot at each end.
static func ornament(width: float) -> Control:
	var line := Control.new()
	line.custom_minimum_size = Vector2(width, 16.0)
	line.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	line.draw.connect(func() -> void:
		var y := line.size.y * 0.5
		var mid := line.size.x * 0.5
		var w := line.size.x
		# two hairlines fading out to the ends, a diamond between two small ones
		line.draw_polygon(PackedVector2Array([Vector2(0, y - 0.5), Vector2(mid - 16, y - 1.0),
				Vector2(mid - 16, y + 1.0), Vector2(0, y + 0.5)]),
				PackedColorArray([Color(GOLD_DIM, 0.0), GOLD, GOLD, Color(GOLD_DIM, 0.0)]))
		line.draw_polygon(PackedVector2Array([Vector2(mid + 16, y - 1.0), Vector2(w, y - 0.5),
				Vector2(w, y + 0.5), Vector2(mid + 16, y + 1.0)]),
				PackedColorArray([GOLD, Color(GOLD_DIM, 0.0), Color(GOLD_DIM, 0.0), GOLD]))
		line.draw_colored_polygon(PackedVector2Array([Vector2(mid, y - 7), Vector2(mid + 8, y),
				Vector2(mid, y + 7), Vector2(mid - 8, y)]), GOLD)
		line.draw_colored_polygon(PackedVector2Array([Vector2(mid, y - 3.5), Vector2(mid + 4, y),
				Vector2(mid, y + 3.5), Vector2(mid - 4, y)]), Color("3a2208"))
		for side in [-1.0, 1.0]:
			var at := Vector2(mid + side * 14.0, y)
			line.draw_colored_polygon(PackedVector2Array([at + Vector2(0, -3), at + Vector2(3, 0),
					at + Vector2(0, 3), at + Vector2(-3, 0)]), GOLD_DIM))
	return line


static func heading(text: String) -> Control:
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 6)
	var head := label(text, HEADING_SIZE, CREAM, "title")
	head.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	head.add_theme_constant_override("shadow_offset_y", 2)
	stack.add_child(head)
	stack.add_child(ornament(240.0))
	return stack


## A line of lettering: `kind` is [UiArt]'s ("body" the plain reading face,
## "head"/"title" Cinzel's capitals, "deco" the game's name).
static func label(text: String, size: int, colour: Color, kind: String = "body") -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", UiArt.font(kind))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", colour)
	return label


## A hairline of gold. Cheap, and it does more for the look than anything else
## on the screen.
static func rule(width: float = 0.0) -> Control:
	var line := ColorRect.new()
	line.color = GOLD_DIM
	line.custom_minimum_size = Vector2(width, 1.0)
	line.size_flags_horizontal = Control.SIZE_SHRINK_CENTER if width > 0.0 \
			else Control.SIZE_FILL
	return line


static func button(text: String, pressed: Callable, quiet: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(BUTTON_WIDTH, BUTTON_HEIGHT)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.add_theme_font_size_override("font_size", BUTTON_SIZE - 2)
	button.add_theme_font_override("font", UiArt.font("head"))
	button.pressed.connect(pressed)
	style_button(button, false, quiet)
	return button


## The one piece of styling everything else leans on: a word on the dark,
## underlined by a hairline, that lights up into a gold-edged plate when the
## mouse is on it — the way the old games' menus did it, not a web form's.
static func style_button(button: Button, chosen: bool, quiet: bool = false) -> void:
	var idle := StyleBoxFlat.new()
	idle.bg_color = Color(0.05, 0.05, 0.07, 0.42) if not chosen else Color(0.24, 0.16, 0.06, 0.72)
	idle.border_width_bottom = 1
	idle.border_width_left = 3 if chosen else 0
	idle.border_color = Color(GOLD_DIM, 0.55) if not chosen else GOLD
	idle.set_corner_radius_all(2)
	if chosen:
		idle.shadow_color = Color(0.95, 0.6, 0.2, 0.15)
		idle.shadow_size = 6
	idle.content_margin_left = 22.0
	idle.content_margin_right = 22.0
	idle.content_margin_top = 10.0
	idle.content_margin_bottom = 10.0

	var hot := StyleBoxFlat.new()
	hot.bg_color = Color(0.26, 0.17, 0.06, 0.85)
	hot.border_width_left = 4
	hot.border_width_bottom = 1
	hot.border_width_top = 1
	hot.border_color = GOLD
	hot.set_corner_radius_all(2)
	hot.shadow_color = Color(0.95, 0.6, 0.2, 0.22)
	hot.shadow_size = 10
	hot.content_margin_left = 30.0
	hot.content_margin_right = 22.0
	hot.content_margin_top = 10.0
	hot.content_margin_bottom = 10.0

	button.add_theme_stylebox_override("normal", idle)
	button.add_theme_stylebox_override("hover", hot)
	button.add_theme_stylebox_override("pressed", hot)
	button.add_theme_stylebox_override("focus", hot)
	button.add_theme_stylebox_override("disabled", idle)
	button.add_theme_color_override("font_color", GOLD_DIM if quiet else CREAM)
	button.add_theme_color_override("font_hover_color", Color("f3c766"))
	button.add_theme_color_override("font_pressed_color", GOLD)
	button.add_theme_color_override("font_focus_color", Color("f3c766"))
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT if button.custom_minimum_size.x >= BUTTON_WIDTH else \
			HORIZONTAL_ALIGNMENT_CENTER


## The ornate plate ([UiArt] "panel"): dark, a gold double edge, gold
## corners; `pad` the room inside it.
static func plate(pad: Vector2 = Vector2(30.0, 26.0), light: bool = false) -> StyleBox:
	var box := UiArt.frame("panel_light" if light else "panel", 30.0)
	box.content_margin_left = pad.x
	box.content_margin_right = pad.x
	box.content_margin_top = pad.y
	box.content_margin_bottom = pad.y
	return box


static func panel_style(fill: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.set_corner_radius_all(3)
	style.content_margin_left = 20.0
	style.content_margin_right = 20.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	return style
