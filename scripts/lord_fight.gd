class_name LordFight
extends Node

## The orc lord's fight, the run's end (the user's word, 2026-10-21: a boss to
## remember, "what will make the player want to stay"):
##
## * **His coming** — when the court wakes his name comes up across the screen
##   ("ღრაშაკი", the lord of the orcs), the braziers by his throne blaze up, the
##   horn; he roars and comes. His bar, with his name, along the screen's foot
##   ([PlayerHud], from his `boss_name` meta).
## * **Half his health gone** — his rage ([PackBrute]: he roars, glows, is
##   quicker and hits harder, his longer combos); the sky over the roof goes red, lightning, embers on the
##   wind; two of his guard come out of the fire by his throne.
## * **Down** — his guard fall with him, the red goes out of the sky and the
##   sun comes up over the palace.
##
## Made by [Dungeon] with the last place's creatures ([method setup]), woken
## with it ([method wake]).

const NAME := "ღრაშაკი"
const TITLE := "ორკების მბრძანებელი"
## His guard (made with him, out of sight, so none is read in mid-fight).
const GUARD := {"arm_right": "longsword", "arm_left": "none", "hand_combo_chance": Vector2(0.1, 0.3),
		"max_health": 420.0, "hit_damage": 58.0}
const GUARDS := 2

var _d: Dungeon
var _i: int = -1
var lord: Node3D
var guards: Array[Node3D] = []
var phase: int = 0
var won: bool = false
var _card: CanvasLayer
var _embers: GPUParticles3D
var _flare_lights: Array[Dictionary] = []
var _woke: bool = false


## His bar's name, and his rage at half his health, put on him as he is made.
static func dress(body: Node3D) -> void:
	body.set_meta(&"boss_name", "%s — %s" % [NAME, TITLE])
	if "rage_at" in body:
		body.set(&"rage_at", 0.5)


## For place `i` of `d`, its lord among its creatures: his guard made now.
func setup(d: Dungeon, i: int) -> void:
	_d = d
	_i = i
	for item: Variant in d._room_foes[i]:
		if is_instance_valid(item) and (item as Node).has_meta(&"gift"):
			lord = item
	if lord == null:
		return
	dress(lord)
	var creatures := d._creatures_node()
	var scene := d._foe_scene(Dungeon.ORC)
	if creatures == null or scene == null:
		return
	var c := d.centre(i)
	var r := d._room(i)
	for k in GUARDS:
		var body := scene.instantiate() as Node3D
		body.name = "D%d_Guard_%d" % [d.id, k]
		for key: String in GUARD:
			body.set(StringName(key), GUARD[key])
		body.set("band", StringName("dungeon_%d_guard" % d.id))
		body.set("camp_centre", Vector3(c.x, c.y, c.z))
		if "leash_radius" in body:
			body.set("leash_radius", 0.01)
		body.set_meta(&"level", int(r["lv"]))
		if body.has_signal(&"hurt"):
			body.connect(&"hurt", d._on_foe_hurt.bind(body))
		body.position = c + Vector3(float(k) * 1.5 + 6.0, -40.0, 0.0)
		body.visible = false
		body.process_mode = Node.PROCESS_MODE_DISABLED
		creatures.add_child(body)
		d._watch_foe(body)
		guards.append(body)


## The court woken: his name across the screen, the fires up, the horn.
func wake() -> void:
	if lord == null or _woke:
		return
	_woke = true
	_show_card()
	Sfx.play_flat(_d, Dungeon.SND + "horn.wav", 0.9, -2.0)
	var game := _d.get_node_or_null("/root/Game")
	var line := greeting(game)
	if game != null and game.has_method(&"meet_lord"):
		game.call(&"meet_lord")
	get_tree().create_timer(4.4).timeout.connect(speak.bind(line))
	_flare(2.6, 0.4)
	get_tree().create_timer(2.2).timeout.connect(_flare.bind(1.3, 2.5))


func _process(_delta: float) -> void:
	if won or lord == null:
		return
	if not is_instance_valid(lord):
		_on_down()
		return
	# his bar is at the foot of the screen, not over his head
	var over: Variant = lord.get("_health_bar")
	if over is Node3D and (over as Node3D).visible:
		(over as Node3D).visible = false
	var under: Variant = lord.get("_stamina_bar")
	if under is Node3D and (under as Node3D).visible:
		(under as Node3D).visible = false
	if not is_instance_valid(lord) or bool(lord.get("is_dead")):
		_on_down()
	elif phase == 0 and bool(lord.get("raging")):
		_second()


#region His second stage
func _second() -> void:
	phase = 1
	speak("ტკივილი?! მცველებო — აქეთ! ცეცხლიდან!")
	_d._say("%s გაცოფდა!" % NAME, 3.0)
	Sfx.play_flat(_d, Dungeon.SND + "thunder.wav", 0.85, 0.0)
	_d._lightning()
	get_tree().create_timer(1.6).timeout.connect(_d._lightning)
	_red_sky(true)
	_flare(2.2, 0.3)
	_ember_wind()
	# his guard out of the fires by his throne, one after the other
	var c := _d.centre(_i)
	var l: float = _d._room(_i)["l"]
	var out := 0
	for body in guards:
		var side := -1.0 if out % 2 == 0 else 1.0
		var spot := c + Vector3(side * 6.5, 0.3, -l * 0.5 + 9.0)
		get_tree().create_timer(0.9 + 0.6 * float(out)).timeout.connect(_guard_out.bind(body, spot, l))
		out += 1


func _guard_out(body: Node3D, spot: Vector3, l: float) -> void:
	if won or not is_instance_valid(body):
		return
	_d._alive.append(body)
	_d._spawned += 1
	body.global_position = spot
	body.visible = true
	body.process_mode = Node.PROCESS_MODE_INHERIT
	if "leash_radius" in body:
		body.set("leash_radius", l)
	var hero := _d._nearest_hero(spot)
	if hero != null and body.has_method("_rouse"):
		body.call_deferred("_rouse", hero)
	var world := Blood.world_of(_d)
	if world != null:
		SkillFx.burst(world, spot + Vector3.UP * 1.2, Color(1.0, 0.42, 0.12), 70, Vector2(1.5, 5.0), Vector3.UP,
				150.0, Vector2(0.06, 0.18), Vector3(0, 1.2, 0), 1.2)
	Sfx.play(_d, Dungeon.SND + "portal_whoosh.wav", null, spot + Vector3.UP, 0.8, -4.0)


## The sky over the roof red (or back from it, `on` false, slowly).
func _red_sky(on: bool) -> void:
	var sky := _d._sky_mat
	var env := _d._env
	if sky == null or env == null:
		return
	var from_top: Color = sky.get_shader_parameter("top_col")
	var from_hor: Color = sky.get_shader_parameter("hor_col")
	var from_fog := env.fog_light_color
	var from_amb := env.ambient_light_color
	var to_top := Color(0.16, 0.015, 0.02)
	var to_hor := Color(0.62, 0.1, 0.05)
	var to_fog := Color(0.42, 0.09, 0.06)
	var to_amb := from_amb.lerp(Color(0.85, 0.35, 0.3), 0.45)
	var step := func(u: float) -> void:
		sky.set_shader_parameter("top_col", from_top.lerp(to_top, u))
		sky.set_shader_parameter("hor_col", from_hor.lerp(to_hor, u))
		env.fog_light_color = from_fog.lerp(to_fog, u)
		env.ambient_light_color = from_amb.lerp(to_amb, u)
	var tw := create_tween()
	tw.tween_method(step, 0.0, 1.0, 2.5 if on else 0.1)


## Embers blown across the whole court.
func _ember_wind() -> void:
	var r := _d._room(_i)
	var w: float = r["w"]
	var l: float = r["l"]
	var p := GPUParticles3D.new()
	p.name = "LordEmbers"
	p.amount = 260
	p.lifetime = 5.0
	p.preprocess = 2.0
	p.position = _d.centre(_i) + Vector3(-w * 0.2, 0.3, 0.0)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(w * 0.5, 0.5, l * 0.5)
	pm.direction = Vector3(0.6, 1.0, 0.0)
	pm.spread = 25.0
	pm.initial_velocity_min = 0.8
	pm.initial_velocity_max = 2.2
	pm.gravity = Vector3(1.2, 0.35, 0.0)
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 1.2
	pm.turbulence_noise_scale = 3.0
	pm.scale_min = 0.5
	pm.scale_max = 1.3
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.15, 0.7, 1.0])
	ramp.colors = PackedColorArray([Color(1.0, 0.7, 0.3, 0.0), Color(1.0, 0.55, 0.2, 1.0),
			Color(1.0, 0.3, 0.08, 0.8), Color(0.6, 0.1, 0.02, 0.0)])
	var rt := GradientTexture1D.new()
	rt.gradient = ramp
	pm.color_ramp = rt
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.06, 0.06)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.vertex_color_use_as_albedo = true
	q.material = m
	p.draw_pass_1 = q
	p.visibility_aabb = AABB(Vector3(-w, -2.0, -l) * 0.7, Vector3(w, 14.0, l) * 1.4)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_d.add_child(p)
	_embers = p
#endregion


#region Down
func _on_down() -> void:
	won = true
	speak("შენ... მხოლოდ ერთი ხარ... ჩვენ — ურიცხვნი ვართ...")
	for body in guards:
		if is_instance_valid(body) and not bool(body.get("is_dead")) and body.visible:
			if body.has_method("_die"):
				body.call("_die")
		elif is_instance_valid(body) and not body.visible:
			body.queue_free()
	if is_instance_valid(_embers):
		_embers.emitting = false
	_flare(1.0, 3.0)
	# the dark lifts: the sun up over the palace
	get_tree().create_timer(2.0).timeout.connect(_dawn)


func _dawn() -> void:
	_d._to_phase(2.5, 10.0)
	_d._say("მზე ამოდის", 3.0)
	get_tree().create_timer(3.5).timeout.connect(_d.end_run.bind(true))
#endregion


#region His words
## What he says as he comes, by what has passed between them before (the
## user's word, 2026-10-21: he remembers).
static func greeting(game: Node) -> String:
	var met := int(game.get(&"lord_met")) if game != null and game.get(&"lord_met") != null else 0
	var beat := int(game.get(&"lord_beat")) if game != null and game.get(&"lord_beat") != null else 0
	var wins := int(game.get(&"wins")) if game != null and game.get(&"wins") != null else 0
	if wins > 0:
		return "ისევ შენ, ჩემი ხმლის ქურდო? ამჯერად ჩემს სასახლეს ცოცხალი ვერ დატოვებ."
	if met == 0:
		return "ადამიანი? ჩემს სასახლეში? შენი თავი ჩემს ძელს დაამშვენებს."
	if beat > 0:
		return "%d-ჯერ დაგამარცხე, პატარა გმირო. ისევ მოხვედი მოსაკვდავად?" % beat
	return "ისევ შენ... ამჯერად ბოლომდე მივალთ."


## What he says when he has beaten him.
static func gloat() -> String:
	return "კიდევ ერთი ძვალი ჩემს კოშკს. მოდი ხვალაც — დაგელოდები."


## A line of his, along the foot of the screen.
func speak(line: String) -> void:
	if not is_inside_tree():
		return
	var layer := CanvasLayer.new()
	layer.layer = 5
	var l := Label.new()
	l.text = "%s:  %s" % [NAME, line]
	l.anchor_left = 0.5
	l.anchor_right = 0.5
	l.anchor_top = 0.74
	l.offset_left = -520
	l.offset_right = 520
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", 26)
	l.add_theme_color_override("font_color", Color(0.95, 0.8, 0.55))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	l.add_theme_constant_override("outline_size", 8)
	layer.add_child(l)
	add_child(layer)
	l.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(l, "modulate:a", 1.0, 0.3)
	tw.tween_interval(4.5)
	tw.tween_property(l, "modulate:a", 0.0, 0.8)
	tw.tween_callback(layer.queue_free)
#endregion


#region His name, his fires
func _show_card() -> void:
	_card = CanvasLayer.new()
	_card.layer = 5
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(box)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 180)
	box.add_child(gap)
	var big := Label.new()
	big.text = NAME
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	big.add_theme_font_size_override("font_size", 72)
	big.add_theme_color_override("font_color", Color(0.86, 0.68, 0.36))
	big.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	big.add_theme_constant_override("shadow_offset_x", 3)
	big.add_theme_constant_override("shadow_offset_y", 4)
	box.add_child(big)
	var line := ColorRect.new()
	line.color = Color(0.7, 0.5, 0.25, 0.8)
	line.custom_minimum_size = Vector2(520, 2)
	line.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(line)
	var small := Label.new()
	small.text = TITLE
	small.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	small.add_theme_font_size_override("font_size", 30)
	small.add_theme_color_override("font_color", Color(0.78, 0.74, 0.68))
	small.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	small.add_theme_constant_override("shadow_offset_x", 2)
	small.add_theme_constant_override("shadow_offset_y", 2)
	box.add_child(small)
	box.modulate.a = 0.0
	add_child(_card)
	var tw := create_tween()
	tw.tween_property(box, "modulate:a", 1.0, 0.8)
	tw.tween_interval(2.6)
	tw.tween_property(box, "modulate:a", 0.0, 1.2)
	tw.tween_callback(_card.queue_free)


## The fires of his court `times` as bright, over `seconds`.
func _flare(times: float, seconds: float) -> void:
	if _flare_lights.is_empty():
		var c := _d.centre(_i)
		var r := _d._room(_i)
		var reach := maxf(float(r["w"]), float(r["l"])) * 0.6
		for f: Dictionary in _d._fire_lights:
			var light := f["light"] as OmniLight3D
			if is_instance_valid(light) and light.global_position.distance_to(c) < reach:
				_flare_lights.append({"f": f, "base": float(f["base"])})
	for entry in _flare_lights:
		var f: Dictionary = entry["f"]
		var tw := create_tween()
		tw.tween_method(func(v: float) -> void: f["base"] = v, float(f["base"]), float(entry["base"]) * times, seconds)
#endregion
