class_name NetHud
extends CanvasLayer

## One quiet line in the corner of an online game.
##
## For the host: the address the others type to join, and how many are in. For
## a client: how long a message takes to reach the host and back. That number is
## the first thing to look at when a fight feels late — on one Wi-Fi it should
## sit well under 30 ms; if it jumps into the hundreds, the network is the
## problem, not the game.

const NetScript := preload("res://scripts/net.gd")

var _line: Label
var _tick := 0.0


func _ready() -> void:
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS
	_line = Label.new()
	_line.position = Vector2(16.0, 12.0)
	_line.add_theme_font_size_override("font_size", 15)
	_line.add_theme_color_override("font_color", Color(0.93, 0.89, 0.84, 0.75))
	_line.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.8))
	_line.add_theme_constant_override("shadow_offset_x", 1)
	_line.add_theme_constant_override("shadow_offset_y", 1)
	add_child(_line)
	_refresh()


func _process(delta: float) -> void:
	_tick -= delta
	if _tick <= 0.0:
		_tick = 0.5
		_refresh()


func _refresh() -> void:
	var net := get_node_or_null("/root/Net")
	if net == null or not bool(net.call("is_online")):
		_line.text = ""
		return
	var roster: Dictionary = net.get("roster")
	if multiplayer.is_server():
		var addresses: Array[String] = NetScript.lan_addresses()
		var where := ", ".join(addresses) if not addresses.is_empty() else "no network found"
		_line.text = "HOSTING  ·  others join at %s  ·  %d/%d players" \
				% [where, roster.size(), NetScript.MAX_PLAYERS]
	else:
		var ping: int = net.call("ping_ms")
		_line.text = "ONLINE  ·  ping %d ms  ·  %d players" % [ping, roster.size()]
		var colour := Color(0.93, 0.89, 0.84, 0.75)
		if ping > 120:
			colour = Color(0.95, 0.45, 0.4, 0.9)
		elif ping > 60:
			colour = Color(0.95, 0.8, 0.4, 0.85)
		_line.add_theme_color_override("font_color", colour)
