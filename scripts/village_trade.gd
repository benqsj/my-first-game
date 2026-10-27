class_name VillageTrade
extends Node3D

## A man he freed from the orcs, at his stall in the village, plying his
## trade ([Trades]: the smith, the healer, the priest). Come up to him and
## [F]: what the next of his work does and what it costs in tusks; [F] again
## buys it, put on the hero there and then and kept for good.

const NEAR := 3.4

var trade: String = "smith"
var man_name: String = ""
var variant: int = 3

var _man: Villager
var _sign: Label3D
var _layer: CanvasLayer
var _prompt: Label
var _panel: PanelContainer
var _text: Label
var _open: bool = false
var _near: bool = false


func _ready() -> void:
	var info: Dictionary = Trades.ALL[trade]
	var tint: Color = info["tint"]
	_stall(tint)
	_man = Villager.new()
	_man.name = "Man"
	_man.variant = variant
	_man.look = Villager.freed_look(variant - 3)
	_man.position = Vector3(0.0, 0.0, -0.9)
	var stand: Array[Vector3] = [to_global(Vector3(0.0, 0.0, -0.9))]
	_man.spots = stand
	add_child(_man)
	_sign = Label3D.new()
	_sign.text = "%s %s" % [String(info["name"]), man_name]
	_sign.font_size = 46
	_sign.outline_size = 10
	_sign.pixel_size = 0.01
	_sign.modulate = tint.lerp(Color.WHITE, 0.4)
	_sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_sign.position = Vector3(0.0, 3.3, 0.0)
	add_child(_sign)
	_ui()


## His stall: a table under an awning in his colour, and his things on it.
func _stall(tint: Color) -> void:
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.36, 0.24, 0.14)
	wood.roughness = 0.9
	var cloth := StandardMaterial3D.new()
	cloth.albedo_color = tint.darkened(0.45)
	cloth.roughness = 0.95
	cloth.cull_mode = BaseMaterial3D.CULL_DISABLED
	_box(wood, Vector3(2.4, 0.12, 1.0), Vector3(0.0, 0.95, 0.4))
	for x: float in [-1.1, 1.1]:
		for z: float in [0.0, 0.8]:
			_box(wood, Vector3(0.1, 0.95, 0.1), Vector3(x, 0.47, z))
		_box(wood, Vector3(0.12, 2.6, 0.12), Vector3(x * 1.15, 1.3, -1.6))
		_box(wood, Vector3(0.12, 2.3, 0.12), Vector3(x * 1.15, 1.15, 1.0))
	var awning := _box(cloth, Vector3(2.8, 0.05, 2.9), Vector3(0.0, 2.45, -0.3))
	awning.rotation.x = 0.13
	match trade:
		"smith":
			var iron := StandardMaterial3D.new()
			iron.albedo_color = Color(0.12, 0.12, 0.13)
			iron.metallic = 0.8
			iron.roughness = 0.4
			_box(iron, Vector3(0.7, 0.25, 0.3), Vector3(1.6, 0.75, 0.2))
			_box(iron, Vector3(0.35, 0.5, 0.25), Vector3(1.6, 0.35, 0.2))
			for k in 3:
				var blade := _box(iron, Vector3(0.08, 0.02, 0.9), Vector3(-0.7 + float(k) * 0.5, 1.03, 0.45))
				blade.rotation.y = 0.2 * float(k - 1)
			var coals := StandardMaterial3D.new()
			coals.albedo_color = Color(0.2, 0.05, 0.02)
			coals.emission_enabled = true
			coals.emission = Color(1.0, 0.35, 0.08)
			coals.emission_energy_multiplier = 2.5
			_box(coals, Vector3(0.6, 0.2, 0.6), Vector3(-1.7, 0.6, -0.4))
			_glow(Color(1.0, 0.45, 0.15), Vector3(-1.7, 1.0, -0.4))
		"healer":
			for k in 6:
				var glass := StandardMaterial3D.new()
				glass.albedo_color = [Color(0.3, 0.9, 0.4), Color(0.9, 0.2, 0.2), Color(0.4, 0.6, 1.0)][k % 3]
				glass.emission_enabled = true
				glass.emission = glass.albedo_color
				glass.emission_energy_multiplier = 0.6
				var flask := CylinderMesh.new()
				flask.top_radius = 0.04
				flask.bottom_radius = 0.09
				flask.height = 0.24
				var m := MeshInstance3D.new()
				m.mesh = flask
				m.material_override = glass
				m.position = Vector3(-0.9 + float(k) * 0.36, 1.13, 0.35 + 0.15 * float(k % 2))
				add_child(m)
			_glow(Color(0.5, 1.0, 0.6), Vector3(0.0, 1.6, 0.4))
		"priest":
			var wax := StandardMaterial3D.new()
			wax.albedo_color = Color(0.92, 0.88, 0.75)
			wax.emission_enabled = true
			wax.emission = Color(1.0, 0.8, 0.45)
			wax.emission_energy_multiplier = 0.3
			for k in 5:
				var candle := _box(wax, Vector3(0.07, 0.25 + 0.06 * float(k % 3), 0.07),
						Vector3(-0.8 + float(k) * 0.4, 1.15, 0.5))
				candle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var gold := StandardMaterial3D.new()
			gold.albedo_color = Color(0.85, 0.65, 0.25)
			gold.metallic = 0.9
			gold.roughness = 0.3
			_box(gold, Vector3(0.08, 0.7, 0.08), Vector3(0.0, 1.35, 0.2))
			_box(gold, Vector3(0.4, 0.08, 0.08), Vector3(0.0, 1.5, 0.2))
			_glow(Color(1.0, 0.85, 0.55), Vector3(0.0, 1.6, 0.4))


func _box(mat: Material, size: Vector3, at: Vector3) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = size
	var m := MeshInstance3D.new()
	m.mesh = box
	m.material_override = mat
	m.position = at
	add_child(m)
	return m


func _glow(tint: Color, at: Vector3) -> void:
	var light := OmniLight3D.new()
	light.light_color = tint
	light.light_energy = 1.2
	light.omni_range = 4.5
	light.position = at
	add_child(light)


#region Talking to him
func _ui() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 4
	add_child(_layer)
	_prompt = Label.new()
	_prompt.anchor_left = 0.5
	_prompt.anchor_right = 0.5
	_prompt.anchor_top = 0.64
	_prompt.offset_left = -300
	_prompt.offset_right = 300
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_theme_font_size_override("font_size", 24)
	_prompt.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_prompt.add_theme_constant_override("outline_size", 7)
	_prompt.hide()
	_layer.add_child(_prompt)
	_panel = PanelContainer.new()
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 0.5
	_panel.offset_left = -330
	_panel.offset_right = 330
	var look := StyleBoxFlat.new()
	look.bg_color = Color(0.06, 0.05, 0.04, 0.88)
	look.border_color = Color(0.7, 0.55, 0.3, 0.9)
	look.set_border_width_all(2)
	look.set_corner_radius_all(6)
	look.set_content_margin_all(16)
	_panel.add_theme_stylebox_override("panel", look)
	_text = Label.new()
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.add_theme_font_size_override("font_size", 22)
	_panel.add_child(_text)
	_panel.hide()
	_layer.add_child(_panel)


func _hero() -> Player:
	for node in get_tree().get_nodes_in_group(&"player"):
		var hero := node as Player
		if hero != null and hero.is_multiplayer_authority() and not hero.is_dead:
			return hero
	return null


func _process(_delta: float) -> void:
	var hero := _hero()
	var near := hero != null and hero.global_position.distance_to(global_position) < NEAR
	if near != _near:
		_near = near
		if not near:
			_open = false
	_prompt.visible = near and not _open
	_panel.visible = near and _open
	if _prompt.visible:
		_prompt.text = "[F]  %s %s" % [String(Trades.ALL[trade]["name"]), man_name]
	if _panel.visible:
		_text.text = _words()


func _words() -> String:
	var game := get_node_or_null(^"/root/Game")
	var info: Dictionary = Trades.ALL[trade]
	var lv := Trades.level(game, trade)
	var top := Trades.max_level(trade)
	var have := int(game.get(&"gold")) if game != null else 0
	var lines := "%s %s   ·   %d / %d\nოქრო: %d\n\n" % [String(info["name"]), man_name, lv, top, have]
	var price := Trades.cost(game, trade)
	if price < 0:
		return lines + "ჩემი ყველაფერი უკვე შენია, გმირო.\n(გაშორდი)"
	lines += "%s — %d ოქრო\n\n" % [Trades.next_words(game, trade), price]
	if have >= price:
		return lines + "[F]  იყიდე        (გაშორდი — არა)"
	return lines + "ოქრო არ გყოფნის — პორტალში მეტი მოიპოვე."


func _unhandled_input(event: InputEvent) -> void:
	if not _near or not event.is_action_pressed(&"interact") or event.is_echo():
		return
	get_viewport().set_input_as_handled()
	interact()


## [F]: open, or buy (tests call it too).
func interact() -> void:
	if not _open:
		_open = true
		return
	var game := get_node_or_null(^"/root/Game")
	if game == null:
		return
	var before := Trades.level(game, trade)
	var hero0 := _hero()
	if not bool(game.call(&"buy_trade", trade, Purse.of(hero0) if hero0 != null else null)):
		return
	var hero := _hero()
	var world := Blood.world_of(self)
	if hero != null:
		_put_on(hero, before + 1)
	if hero != null and world != null:
		SkillFx.burst(world, hero.global_position + Vector3.UP * 1.2, Trades.ALL[trade]["tint"], 50,
				Vector2(1.0, 3.5), Vector3.UP, 180.0, Vector2(0.06, 0.16), Vector3(0, 1.0, 0), 1.3)


## What the level just bought (`lv`) does, on him now.
func _put_on(hero: Player, lv: int) -> void:
	match trade:
		"smith":
			var per := float(Trades.ALL["smith"]["per"])
			hero.dealt_scale *= (1.0 + per * float(lv)) / (1.0 + per * float(lv - 1))
		"healer":
			hero.flask_count += 1
			hero.flasks_left += 1
#endregion
