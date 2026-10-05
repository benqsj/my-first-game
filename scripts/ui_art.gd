class_name UiArt
extends Object
## The game's lettering, frames and icons (assets/ui, see CREDITS.txt there):
## one place that loads them, so the menu, the HUD and the bag look like one
## thing. Static and cached: a font or a frame is loaded once.
##
## * Lettering: Cinzel (titles, headings, buttons — carved capitals) and
##   Alegreya Sans (everything read: numbers, lines of text).
## * Frames: 9-slice PNGs baked by vepxis-art/tools/ui_frames.py — an ornate
##   panel with gold corners, a socket for a slot (and its lit edge), the
##   skill bar's plate, a tab.
## * Icons: skills' painted plates and the bag's glyphs, baked by
##   vepxis-art/tools/ui_icons.py out of game-icons.net (CC BY 3.0).

const FONTS := "res://assets/ui/fonts/"
const FRAMES := "res://assets/ui/frames/"
const ICONS := "res://assets/ui/icons/"

const GOLD := Color("d0a044")
const GOLD_LIGHT := Color("f3d48c")
const GOLD_DIM := Color("8a6a2c")
const CREAM := Color("ece4d6")
const MUTED := Color(0.72, 0.68, 0.6)

static var _cache: Dictionary = {}
static var _theme: Theme


static func _res(path: String) -> Resource:
	if _cache.has(path):
		return _cache[path]
	var res: Resource = load(path) if ResourceLoader.exists(path) else null
	_cache[path] = res
	return res


## "title" (Cinzel Bold), "head" (Cinzel Medium), "deco" (Cinzel Decorative,
## the game's name), "body" (Alegreya Sans Medium), "bold", "plain".
static func font(kind: String = "body") -> Font:
	var file: String = {
		"title": "Cinzel-Bold.ttf", "head": "Cinzel-Medium.ttf", "deco": "CinzelDecorative-Bold.ttf",
		"body": "AlegreyaSans-Medium.ttf", "bold": "AlegreyaSans-Bold.ttf", "plain": "AlegreyaSans-Regular.ttf",
	}.get(kind, "AlegreyaSans-Medium.ttf")
	var f := _res(FONTS + file) as Font
	return f if f != null else ThemeDB.fallback_font


## A skill's plate ("skill_<id>") or an item's glyph ("item_<id>"); null if
## there is none.
static func icon(name: String) -> Texture2D:
	return _res(ICONS + name + ".png") as Texture2D


static func frame_texture(name: String) -> Texture2D:
	return _res(FRAMES + name + ".png") as Texture2D


## A 9-slice frame as a style box ("panel", "panel_light", "socket",
## "socket_lit", "bar_plate", "tab", "tab_on"), its corners `margin` pixels.
static func frame(name: String, margin: float = 30.0, content: float = -1.0) -> StyleBox:
	var tex := frame_texture(name)
	if tex == null:
		var flat := StyleBoxFlat.new()
		flat.bg_color = Color(0.04, 0.04, 0.05, 0.85)
		flat.border_color = GOLD_DIM
		flat.set_border_width_all(1)
		return flat
	var box := StyleBoxTexture.new()
	box.texture = tex
	box.set_texture_margin_all(margin)
	box.set_content_margin_all(content if content >= 0.0 else margin)
	return box


## Draws `name`'s frame over `rect` on `onto` (a Control's draw).
static func draw_frame(onto: CanvasItem, rect: Rect2, name: String, margin: float = 30.0,
		tint: Color = Color.WHITE) -> void:
	var box := frame(name, margin)
	if box is StyleBoxTexture:
		(box as StyleBoxTexture).modulate_color = tint
	box.draw(onto.get_canvas_item(), rect)


## The theme the menus are drawn in: the lettering above, sizes as before.
static func theme() -> Theme:
	if _theme != null:
		return _theme
	_theme = Theme.new()
	_theme.default_font = font("body")
	_theme.default_font_size = 18
	_theme.set_font(&"font", &"Button", font("head"))
	_theme.set_font(&"font", &"LineEdit", font("body"))
	return _theme


## A centred line in `kind`'s lettering.
static func text(onto: CanvasItem, at: Vector2, line: String, size: int, colour: Color, kind: String = "body",
		align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0) -> void:
	onto.draw_string(font(kind), at, line, align, width, size, colour)


## `line` with a dark shadow under it, for lettering over the world.
static func text_shadowed(onto: CanvasItem, at: Vector2, line: String, size: int, colour: Color,
		kind: String = "body", align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0) -> void:
	var f := font(kind)
	onto.draw_string_outline(f, at + Vector2(0, 1), line, align, width, size, 4, Color(0, 0, 0, 0.55 * colour.a))
	onto.draw_string(f, at, line, align, width, size, colour)


## A gold rule with a diamond in its middle, from `from` to `to`.
static func rule(onto: CanvasItem, from: Vector2, to: Vector2, colour: Color = GOLD_DIM) -> void:
	var mid := (from + to) * 0.5
	var along := (to - from).normalized()
	onto.draw_line(from, mid - along * 9.0, colour, 1.0)
	onto.draw_line(mid + along * 9.0, to, colour, 1.0)
	var side := Vector2(-along.y, along.x)
	onto.draw_colored_polygon(PackedVector2Array([mid - along * 6.0, mid + side * 4.0, mid + along * 6.0,
			mid - side * 4.0]), GOLD)
