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

## A dark ground with a warm bloom behind the title, so the gold has something
## to sit on rather than floating on flat black.
static func background(onto: Control) -> void:
	var sky := ColorRect.new()
	sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	sky.color = SLATE_DEEP
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	onto.add_child(sky)

	var glow := TextureRect.new()
	glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ramp := GradientTexture2D.new()
	ramp.width = 8
	ramp.height = 256
	ramp.fill = GradientTexture2D.FILL_LINEAR
	ramp.fill_from = Vector2(0.0, 0.0)
	ramp.fill_to = Vector2(0.0, 1.0)
	var colours := Gradient.new()
	colours.set_color(0, SLATE)
	colours.set_color(1, SLATE_DEEP)
	colours.add_point(0.42, CRIMSON.darkened(0.62))
	ramp.gradient = colours
	glow.texture = ramp
	glow.stretch_mode = TextureRect.STRETCH_SCALE
	onto.add_child(glow)


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
	stack.add_theme_constant_override("separation", 2)
	var title := label("VEPXIS", TITLE_SIZE, GOLD)
	title.add_theme_constant_override("outline_size", 0)
	stack.add_child(title)
	stack.add_child(rule(280.0))
	stack.add_child(label("THE KNIGHT IN THE PANTHER'S SKIN", BODY_SIZE, GOLD_DIM))
	return stack


static func heading(text: String) -> Control:
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 6)
	stack.add_child(label(text, HEADING_SIZE, CREAM))
	stack.add_child(rule(180.0))
	return stack


static func label(text: String, size: int, colour: Color) -> Label:
	var label := Label.new()
	label.text = text
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
	button.add_theme_font_size_override("font_size", BUTTON_SIZE)
	button.pressed.connect(pressed)
	style_button(button, false, quiet)
	return button


## The one piece of styling everything else leans on: a flat panel with a gold
## edge down one side that fills in when the mouse is over it.
static func style_button(button: Button, chosen: bool, quiet: bool = false) -> void:
	var idle := panel_style(PANEL if not chosen else PANEL_HOT)
	idle.border_width_left = 4 if chosen else 2
	idle.border_color = GOLD if chosen else GOLD_DIM

	var hot := panel_style(PANEL_HOT)
	hot.border_width_left = 4
	hot.border_color = GOLD

	button.add_theme_stylebox_override("normal", idle)
	button.add_theme_stylebox_override("hover", hot)
	button.add_theme_stylebox_override("pressed", hot)
	button.add_theme_stylebox_override("focus", hot)
	button.add_theme_color_override("font_color", GOLD_DIM if quiet else CREAM)
	button.add_theme_color_override("font_hover_color", GOLD)
	button.add_theme_color_override("font_pressed_color", GOLD)


static func panel_style(fill: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.set_corner_radius_all(3)
	style.content_margin_left = 20.0
	style.content_margin_right = 20.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	return style
