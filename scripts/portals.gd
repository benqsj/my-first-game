class_name Portals
extends Node3D

## The five gates of the open world (portal_dungeons_plan.md, 2026-10-19).
## Each leads to a dungeon of its own: rooms of a palace, a room cleared opens
## the next door, a boss at the end. All five stand open from the start; at a
## gate the level its dungeon is made for is shown, and a hero below it simply
## does not last in there.
##
## Walk up to one and press **interact** (F): the dungeon is loaded. Coming back
## out (or dying in there) puts the hero by the gate he went in by
## ([member Game.portal_return]).

const DUNGEON := "res://scenes/world/dungeon.tscn"
const WORLD := "res://scenes/world/greybox_world.tscn"

## The gates, in order: name, the level its dungeon starts and ends at, its
## violet, where it stands (x, z in the open world) and which way it faces (the
## yaw its opening looks towards), and whether its dungeon is built yet.
const DEFS: Array[Dictionary] = [
	{"name": "ორკების სასახლე", "from": 1, "to": 10, "tint": Color(0.58, 0.24, 0.98), "x": 44.0, "z": -16.0, "ready": true},
	{"name": "ჩონჩხების აკლდამა", "from": 10, "to": 20, "tint": Color(0.42, 0.25, 0.9), "x": 58.0, "z": -22.0, "ready": false},
	{"name": "ტროლების მღვიმე", "from": 20, "to": 30, "tint": Color(0.66, 0.2, 0.78), "x": 72.0, "z": -24.0, "ready": false},
	{"name": "დემონების ტაძარი", "from": 30, "to": 40, "tint": Color(0.75, 0.16, 0.55), "x": 86.0, "z": -22.0, "ready": false},
	{"name": "დრაკონის ციხე", "from": 40, "to": 50, "tint": Color(0.36, 0.18, 0.75), "x": 100.0, "z": -16.0, "ready": false},
]
const ROMAN := ["I", "II", "III", "IV", "V"]
## Where the gates face: the village square, so each opening is seen from it.
const LOOK_AT := Vector2(72.0, 30.0)

## How near a gate a hero has to stand to go in, and to read it.
@export var reach: float = 3.0
@export var read_from: float = 13.0

var gates: Array[Node3D] = []
var _labels: Array[Label3D] = []
var _near: int = -1
var _layer: CanvasLayer
var _prompt: Label
var _note_until: float = 0.0


func _ready() -> void:
	for i in DEFS.size():
		_build_gate(i)
	_build_hud()


## Where gate `i` stands, on the ground, in the level's frame.
static func spot(i: int) -> Vector3:
	var d: Dictionary = DEFS[clampi(i, 0, DEFS.size() - 1)]
	var x: float = d["x"]
	var z: float = d["z"]
	return Vector3(x, Terrain.height_under(x, z, 1.8), z)


## The yaw gate `i` is turned to.
static func yaw(i: int) -> float:
	var at := spot(i)
	return atan2(LOOK_AT.x - at.x, LOOK_AT.y - at.z)


## Where a hero coming out of gate `i` stands: a few steps before it.
static func arrival(i: int) -> Vector3:
	var at := spot(i)
	var y := yaw(i)
	var out := at + Vector3(sin(y), 0.0, cos(y)) * 3.2
	out.y = Terrain.height_under(out.x, out.z, 0.6) + 0.1
	return out


func _build_gate(i: int) -> void:
	var d: Dictionary = DEFS[i]
	var holder := Node3D.new()
	holder.name = "Gate%d" % (i + 1)
	holder.position = spot(i)
	holder.rotation.y = yaw(i)
	add_child(holder)
	var look := PortalLook.new()
	look.name = "Look"
	look.tint = d["tint"]
	holder.add_child(look)
	var label := Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 64
	label.outline_size = 14
	label.pixel_size = 0.006
	label.position = Vector3(0.0, 8.6, 0.0)
	label.modulate = Color(0.92, 0.85, 1.0, 0.0)
	label.outline_modulate = Color(0.05, 0.0, 0.1, 0.0)
	label.text = "%s  %s\nლეველი %d–%d%s" % [ROMAN[i], d["name"], int(d["from"]), int(d["to"]),
			"" if bool(d["ready"]) else "\n(ჯერ მზად არ არის)"]
	holder.add_child(label)
	gates.append(holder)
	_labels.append(label)


func _build_hud() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 5
	add_child(_layer)
	_prompt = Label.new()
	_prompt.anchor_left = 0.5
	_prompt.anchor_right = 0.5
	_prompt.anchor_top = 1.0
	_prompt.anchor_bottom = 1.0
	_prompt.offset_left = -320
	_prompt.offset_right = 320
	_prompt.offset_top = -150
	_prompt.offset_bottom = -120
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_theme_font_size_override("font_size", 20)
	_prompt.add_theme_color_override("font_color", Color(0.86, 0.78, 1.0))
	_prompt.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_prompt.add_theme_constant_override("outline_size", 6)
	_prompt.hide()
	_layer.add_child(_prompt)


func _local_player() -> Player:
	for node in get_tree().get_nodes_in_group(&"player"):
		var body := node as Player
		if body != null and body.is_multiplayer_authority():
			return body
	return null


func _process(_delta: float) -> void:
	var me := _local_player()
	var best := -1
	var closest := reach
	for i in gates.size():
		var at := gates[i].global_position
		var gap := INF
		if me != null:
			gap = Vector2(at.x - me.global_position.x, at.z - me.global_position.z).length()
		# The writing over a gate shows as the hero comes near it.
		var seen := clampf((read_from - gap) / 3.0, 0.0, 1.0)
		_labels[i].modulate.a = seen
		_labels[i].outline_modulate.a = seen
		if gap < closest:
			closest = gap
			best = i
	_near = best
	if _prompt == null:
		return
	var now := Time.get_ticks_msec() / 1000.0
	if _near < 0 and now > _note_until:
		_prompt.hide()
		return
	if now <= _note_until:
		_prompt.show()
		return
	var d: Dictionary = DEFS[_near]
	_prompt.text = "[F]  შესვლა — %s (ლეველი %d–%d)" % [d["name"], int(d["from"]), int(d["to"])]
	_prompt.show()


func _unhandled_input(event: InputEvent) -> void:
	if _near < 0 or not event.is_action_pressed(&"interact") or event.is_echo():
		return
	get_viewport().set_input_as_handled()
	enter(_near)


## Goes into gate `i`'s dungeon. False (and a word on the screen) when that
## dungeon is not built yet.
func enter(i: int) -> bool:
	var d: Dictionary = DEFS[i]
	if not bool(d["ready"]):
		_prompt.text = "%s — ეს დანჯენი ჯერ მზად არ არის" % d["name"]
		_note_until = Time.get_ticks_msec() / 1000.0 + 2.0
		return false
	var game := get_node_or_null("/root/Game")
	if game != null:
		game.set(&"dungeon_id", i)
		game.set(&"portal_return", i)
	SceneLoader.go(get_tree(), DUNGEON)
	return true
