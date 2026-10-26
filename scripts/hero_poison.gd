class_name HeroPoison
extends Node3D

## Venom in a hero: what a ghoul's claws and bite leave in him. A bar, not
## stacks (the user's word, 2026-10-27, after the ghoul's films): a claw that
## lands throws it up a lot at once ([method apply_venom] `amount`), and more
## creeps in after it (`creep`, at `CREEP_RATE` a second); while there is
## venom in him it eats his health, the more venom the faster
## (`FULL_DPS` a second when the bar is full), and once nothing has come in
## for `HOLD` seconds it wears off (`WEAR_RATE` a second).
##
## Seen: green drops and a haze rising off him, green veins on him, his
## health bar runs green and the venom bar under it ([PlayerHud]); on his own
## screen the edges go green and veins creep in from them, as strong as the
## venom ([member VIGNETTE]).
##
## Hung under each [Player] by [World] as `HeroPoison`, on every peer. The host
## decides who is poisoned (a ghoul's blow reaching him) and tells everyone;
## each peer runs the bar the same way, and the hero's own peer, which owns
## his health, takes it off.

const COLOUR := Color(0.42, 1.0, 0.2)
const TICK := 0.5
## The bar's top.
const FULL := 100.0
## Health a second taken with the bar full (less as it is lower).
const FULL_DPS := 8.0
const CREEP_RATE := 6.0
const HOLD := 2.5
const WEAR_RATE := 7.0
const VIGNETTE := "res://assets/fx/poison_vignette.gdshader"
const VEINS := "res://assets/fx/poison_veins.gdshader"

## 0 to FULL.
var venom: float = 0.0
var _creep: float = 0.0
var _since: float = 99.0
var _tick: float = 0.0
var _drops: GPUParticles3D
var _haze: GPUParticles3D
var _screen: CanvasLayer
var _screen_mat: ShaderMaterial
var _veins_mat: ShaderMaterial
var _veined: Array[MeshInstance3D] = []


static func of(hero: Node) -> HeroPoison:
	return hero.get_node_or_null(^"HeroPoison") as HeroPoison if hero != null else null


func poisoned() -> bool:
	return venom > 0.5


## How full the bar is, 0 to 1.
func share() -> float:
	return venom / FULL


## Host: venom in, `amount` at once and `creep` more over the next seconds.
func apply_venom(amount: float, creep: float = 0.0) -> void:
	if is_inside_tree() and multiplayer.has_multiplayer_peer():
		net_venom.rpc(amount, creep)
	else:
		net_venom(amount, creep)


@rpc("any_peer", "call_local", "reliable")
func net_venom(amount: float, creep: float) -> void:
	var sender := multiplayer.get_remote_sender_id() if is_inside_tree() else 0
	if sender != 0 and sender != 1:
		return
	venom = minf(venom + amount, FULL)
	_creep += creep
	_since = 0.0


func _process(delta: float) -> void:
	var hero := get_parent() as Node3D
	if hero == null:
		return
	if bool(hero.get("is_dead")):
		venom = 0.0
		_creep = 0.0
	_since += delta
	if _creep > 0.0:
		var step := minf(_creep, CREEP_RATE * delta)
		venom = minf(venom + step, FULL)
		_creep -= step
		_since = 0.0
	elif _since > HOLD:
		venom = maxf(venom - WEAR_RATE * delta, 0.0)
	_show(hero, venom / FULL)
	if venom <= 0.0 or not hero.is_multiplayer_authority():
		_tick = 0.0
		return
	_tick += delta
	if _tick < TICK:
		return
	_tick -= TICK
	if hero.has_method(&"_take_damage"):
		hero.call(&"_take_damage", FULL_DPS * TICK * venom / FULL)


#region Seen
func _show(hero: Node3D, k: float) -> void:
	var on := k > 0.005
	if _drops == null and on:
		_drops = _make_drops(24, 0.9, Color(COLOUR, 0.9), 0.025, Vector3.UP * 1.0, 0.35)
		_haze = _make_drops(22, 1.6, Color(0.45, 0.9, 0.25, 0.3), 0.22, Vector3.UP * 0.9, 0.45)
		add_child(_drops)
		add_child(_haze)
	if _drops != null:
		_drops.emitting = on
		_drops.amount_ratio = clampf(k, 0.3, 1.0)
		_haze.emitting = k > 0.25
		_haze.amount_ratio = clampf(k, 0.3, 1.0)
	_show_veins(hero, k)
	_show_screen(hero, k)


## Green veins on him, glowing up and down: laid over his meshes while the
## venom is in him (where nothing else is laid over them), taken off after.
func _show_veins(hero: Node3D, k: float) -> void:
	if k <= 0.005:
		if not _veined.is_empty():
			for mi in _veined:
				if is_instance_valid(mi) and mi.material_overlay == _veins_mat:
					mi.material_overlay = null
			_veined.clear()
		return
	if _veins_mat == null:
		_veins_mat = ShaderMaterial.new()
		_veins_mat.shader = load(VEINS)
	_veins_mat.set_shader_parameter(&"amount", k)
	if _veined.is_empty():
		var rig := hero.get(&"rig") as Node
		if rig == null:
			return
		for node in rig.find_children("*", "MeshInstance3D", true, false):
			var mi := node as MeshInstance3D
			if mi.material_overlay == null and mi.is_visible_in_tree():
				mi.material_overlay = _veins_mat
				_veined.append(mi)


## On his own screen only: the edges green, veins creeping in from them.
func _show_screen(hero: Node3D, k: float) -> void:
	var mine := hero.is_multiplayer_authority() and hero.get(&"camera") != null
	if not mine or k <= 0.005:
		if _screen != null:
			_screen.visible = false
		return
	if _screen == null:
		_screen = CanvasLayer.new()
		_screen.layer = 4
		var rect := ColorRect.new()
		rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_screen_mat = ShaderMaterial.new()
		_screen_mat.shader = load(VIGNETTE)
		rect.material = _screen_mat
		_screen.add_child(rect)
		add_child(_screen)
	_screen.visible = true
	_screen_mat.set_shader_parameter(&"amount", k)


func _make_drops(amount: int, life: float, colour: Color, size: float, at: Vector3,
		spread: float) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.position = at
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = spread
	mat.direction = Vector3.UP
	mat.spread = 25.0
	mat.initial_velocity_min = 0.2
	mat.initial_velocity_max = 0.6
	mat.gravity = Vector3(0.0, 0.4, 0.0)
	mat.scale_min = 0.6
	mat.scale_max = 1.3
	var fade := Gradient.new()
	fade.set_color(0, colour)
	fade.set_color(1, Color(colour, 0.0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	mat.color_ramp = ramp
	p.process_material = mat
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size) * 2.0
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.albedo_texture = SkillFx.dot()
	quad.material = m
	p.draw_pass_1 = quad
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p
#endregion
