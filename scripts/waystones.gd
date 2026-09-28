class_name Waystones
extends Node3D

## The travelling fires of the open world (the map's `teleports`): a ring of
## stones round a fire in every village, at the ways between the lands and
## before every boss.
##
## Walk up to one and press **interact** (F): a cold fire is lit, and stays lit.
## At a lit fire the same key opens the list of every other lit fire, the up
## and down keys pick one, F again goes there. A fire has to have been lit by
## hand before it can be gone to, so the lands are walked once before they are
## skipped. Which fires are lit is kept for the session, for everyone on this
## peer; the village square's fire is lit from the start.

## How near a fire a hero has to stand to use it.
@export var reach: float = 3.6
## The fires lit from the start (by key).
@export var lit_at_start: PackedStringArray = ["tp_core"]

signal lit(key: String)
signal travelled(key: String)

## key -> {key, name, region, kind, at: Vector3}
var fires: Dictionary = {}
## The keys of the lit ones, in the order they were lit.
var lit_keys: PackedStringArray = []

var _lights: Dictionary = {}
var _near: String = ""
var _choosing := false
var _choice := 0
var _layer: CanvasLayer
var _prompt: Label
var _panel: PanelContainer
var _list: Label


func _ready() -> void:
	var lands := Lands.current
	if lands == null or not is_instance_valid(lands):
		return
	for tp: Dictionary in lands.info.get("teleports", []):
		var key := String(tp["key"])
		var x := float(tp["x"])
		var z := float(tp["z"])
		var at := Vector3(x, Terrain.height(x, z), z)
		fires[key] = {"key": key, "name": String(tp.get("name", key)), "region": String(tp.get("region", "")),
				"kind": String(tp.get("kind", "way")), "at": at}
		_build_fire(key, at)
	for key in lit_at_start:
		if fires.has(key):
			light(key)
	_build_hud()


func _build_fire(key: String, at: Vector3) -> void:
	var holder := Node3D.new()
	holder.name = key
	holder.position = at
	add_child(holder)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key)
	# the ring: nine stones standing round, one taller where the way comes in
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.46, 0.45, 0.42)
	stone.roughness = 0.95
	var tex := load("res://assets/terrain_real/aerial_rocks_02_diff.jpg") as Texture2D
	if tex != null:
		stone.albedo_texture = tex
		stone.uv1_triplanar = true
		stone.uv1_world_triplanar = true
		stone.uv1_scale = Vector3.ONE * 0.4
	for i in 9:
		var a := TAU * i / 9.0
		var h := 1.9 if i == 0 else rng.randf_range(0.9, 1.4)
		var box := BoxMesh.new()
		box.size = Vector3(0.6, h, 0.45)
		var mi := MeshInstance3D.new()
		mi.mesh = box
		mi.material_override = stone
		var local := Vector3(cos(a) * 3.0, 0.0, sin(a) * 3.0)
		var ground := Terrain.height(at.x + local.x, at.z + local.z) - at.y
		mi.transform = Transform3D(Basis(Vector3.UP, -a), local + Vector3(0.0, ground + h * 0.5 - 0.25, 0.0))
		holder.add_child(mi)
	var fire := load("res://assets/forest/Campfire_Teepee.obj") as Mesh
	if fire != null:
		var mi := MeshInstance3D.new()
		mi.mesh = fire
		mi.scale = Vector3.ONE * 1.5
		holder.add_child(mi)
	# the flame, off until lit
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(0.55, 0.75, 1.0)
	lamp.light_energy = 2.6
	lamp.omni_range = 11.0
	lamp.position = Vector3(0.0, 1.3, 0.0)
	lamp.visible = false
	holder.add_child(lamp)
	var flames := CPUParticles3D.new()
	flames.amount = 16
	flames.lifetime = 0.9
	flames.position = Vector3(0.0, 0.4, 0.0)
	flames.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	flames.emission_sphere_radius = 0.4
	flames.direction = Vector3.UP
	flames.spread = 10.0
	flames.initial_velocity_min = 1.0
	flames.initial_velocity_max = 2.0
	flames.gravity = Vector3(0.0, 0.8, 0.0)
	flames.scale_amount_min = 0.3
	flames.scale_amount_max = 0.6
	var quad := QuadMesh.new()
	quad.size = Vector2(0.5, 0.8)
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	fm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	fm.billboard_keep_scale = true
	fm.vertex_color_use_as_albedo = true
	quad.material = fm
	flames.mesh = quad
	var fade := Gradient.new()
	fade.set_color(0, Color(0.35, 0.6, 1.0, 0.8))
	fade.set_color(1, Color(0.1, 0.2, 0.8, 0.0))
	flames.color_ramp = fade
	flames.emitting = false
	holder.add_child(flames)
	_lights[key] = [lamp, flames]


## Lights the fire `key` (for tests, and from the key).
func light(key: String) -> void:
	if not fires.has(key) or key in lit_keys:
		return
	lit_keys.append(key)
	var parts: Array = _lights.get(key, [])
	if parts.size() == 2:
		(parts[0] as OmniLight3D).visible = true
		(parts[1] as CPUParticles3D).emitting = true
	lit.emit(key)


## Where going to the fire `key` puts a hero: beside it, not in it.
func arrival(key: String) -> Vector3:
	var at: Vector3 = fires[key]["at"]
	var p := Vector2(at.x + 3.9, at.z + 1.2)
	return Vector3(p.x, Terrain.height(p.x, p.y) + 0.3, p.y)


## Sends `who` to the lit fire `key`.
func travel(who: Node3D, key: String) -> bool:
	if who == null or not key in lit_keys:
		return false
	who.global_position = arrival(key)
	if who is CharacterBody3D:
		(who as CharacterBody3D).velocity = Vector3.ZERO
	travelled.emit(key)
	return true


func _local_player() -> Player:
	for node in get_tree().get_nodes_in_group(&"player"):
		var body := node as Player
		if body != null and body.is_multiplayer_authority():
			return body
	return null


func _process(_delta: float) -> void:
	var me := _local_player()
	var best := ""
	if me != null:
		var closest := reach
		for key: String in fires:
			var at: Vector3 = fires[key]["at"]
			var gap := Vector2(at.x - me.global_position.x, at.z - me.global_position.z).length()
			if gap < closest and absf(at.y - me.global_position.y) < 4.0:
				closest = gap
				best = key
	if best != _near:
		_near = best
		_choosing = false
	_refresh()


func _destinations() -> Array[String]:
	var out: Array[String] = []
	for key in lit_keys:
		if key != _near:
			out.append(key)
	return out


func _unhandled_input(event: InputEvent) -> void:
	if _near == "":
		return
	if _choosing:
		var list := _destinations()
		if event.is_action_pressed(&"ui_up"):
			_choice = wrapi(_choice - 1, 0, maxi(list.size(), 1))
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed(&"ui_down"):
			_choice = wrapi(_choice + 1, 0, maxi(list.size(), 1))
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed(&"ui_cancel"):
			_choosing = false
			get_viewport().set_input_as_handled()
	if not event.is_action_pressed(&"interact") or event.is_echo():
		return
	get_viewport().set_input_as_handled()
	interact()


## What F does at the fire the hero stands by. Called by the key and by tests.
func interact() -> void:
	if _near == "":
		return
	if not _near in lit_keys:
		light(_near)
		return
	var list := _destinations()
	if list.is_empty():
		return
	if not _choosing:
		_choosing = true
		_choice = 0
		return
	var key := list[clampi(_choice, 0, list.size() - 1)]
	_choosing = false
	travel(_local_player(), key)


func _refresh() -> void:
	if _prompt == null:
		return
	if _near == "":
		_prompt.hide()
		_panel.hide()
		return
	var fire: Dictionary = fires[_near]
	if not _near in lit_keys:
		_prompt.text = "[F]  დაანთე კოცონი — %s" % fire["name"]
	elif _destinations().is_empty():
		_prompt.text = "%s — სხვა ანთებული კოცონი ჯერ არ არის" % fire["name"]
	elif not _choosing:
		_prompt.text = "[F]  გზა სხვა კოცონთან — %s" % fire["name"]
	else:
		_prompt.text = "[↑ ↓]  აირჩიე   [F]  წადი   [Esc]  დარჩი"
	_prompt.show()
	if _choosing:
		var lines := PackedStringArray()
		var list := _destinations()
		for i in list.size():
			var f: Dictionary = fires[list[i]]
			lines.append(("▶  " if i == _choice else "     ") + String(f["name"]))
		_list.text = "\n".join(lines)
		_panel.show()
	else:
		_panel.hide()


func _build_hud() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 5
	add_child(_layer)
	_prompt = Label.new()
	_prompt.anchor_left = 0.5
	_prompt.anchor_right = 0.5
	_prompt.anchor_top = 1.0
	_prompt.anchor_bottom = 1.0
	_prompt.offset_left = -300
	_prompt.offset_right = 300
	_prompt.offset_top = -150
	_prompt.offset_bottom = -120
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_theme_font_size_override("font_size", 20)
	_prompt.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
	_prompt.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_prompt.add_theme_constant_override("outline_size", 6)
	_prompt.hide()
	_layer.add_child(_prompt)
	_panel = PanelContainer.new()
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 0.5
	_panel.anchor_bottom = 0.5
	_panel.offset_left = -220
	_panel.offset_right = 220
	_panel.offset_top = -200
	_panel.offset_bottom = 200
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.05, 0.07, 0.1, 0.88)
	box.border_color = Color(0.45, 0.62, 0.9, 0.9)
	box.set_border_width_all(2)
	box.set_corner_radius_all(6)
	box.set_content_margin_all(16)
	_panel.add_theme_stylebox_override("panel", box)
	_list = Label.new()
	_list.add_theme_font_size_override("font_size", 19)
	_list.add_theme_color_override("font_color", Color(0.9, 0.93, 1.0))
	_panel.add_child(_list)
	_panel.hide()
	_layer.add_child(_panel)
