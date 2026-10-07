class_name HeroPoison
extends Node3D

## Poison on a hero: what a ghoul's claws leave in him (the user's pick,
## 2026-10-07). Up to `MAX` stacks, each on its own clock; each eats
## `dps` of his health a second while it lasts. Green drops rise off him and
## his health bar runs green ([PlayerHud]).
##
## Hung under each [Player] by [World] as `HeroPoison`, on every peer. The host
## decides who is poisoned ([method apply], a ghoul's blow reaching him) and
## tells everyone; the hero's own peer, which owns his health, takes it off.

const MAX := 3
const TICK := 0.5
const COLOUR := Color(0.42, 1.0, 0.2)

var stacks: PackedFloat32Array = PackedFloat32Array()
var dps: float = 0.0
var _tick: float = 0.0
var _drops: GPUParticles3D


static func of(hero: Node) -> HeroPoison:
	return hero.get_node_or_null(^"HeroPoison") as HeroPoison if hero != null else null


func poisoned() -> bool:
	return not stacks.is_empty()


## Host: one more stack, `seconds` long, `per_second` each.
func apply(seconds: float, per_second: float) -> void:
	if is_inside_tree() and multiplayer.has_multiplayer_peer():
		net_apply.rpc(seconds, per_second)
	else:
		net_apply(seconds, per_second)


@rpc("any_peer", "call_local", "reliable")
func net_apply(seconds: float, per_second: float) -> void:
	var sender := multiplayer.get_remote_sender_id() if is_inside_tree() else 0
	if sender != 0 and sender != 1:
		return
	dps = maxf(dps, per_second)
	if stacks.size() < MAX:
		stacks.append(seconds)
	else:
		var oldest := 0
		for i in stacks.size():
			if stacks[i] < stacks[oldest]:
				oldest = i
		stacks[oldest] = seconds


func _process(delta: float) -> void:
	var hero := get_parent() as Node3D
	if hero == null:
		return
	if bool(hero.get("is_dead")):
		stacks.clear()
	for i in range(stacks.size() - 1, -1, -1):
		stacks[i] -= delta
		if stacks[i] <= 0.0:
			stacks.remove_at(i)
	if stacks.is_empty():
		dps = 0.0
		_tick = 0.0
	_show(not stacks.is_empty())
	if stacks.is_empty() or not hero.is_multiplayer_authority():
		return
	_tick += delta
	if _tick < TICK:
		return
	_tick -= TICK
	if hero.has_method(&"_take_damage"):
		hero.call(&"_take_damage", dps * TICK * float(stacks.size()))


func _show(on: bool) -> void:
	if _drops == null:
		if not on:
			return
		_drops = _make_drops()
		add_child(_drops)
	_drops.emitting = on
	_drops.amount_ratio = clampf(float(stacks.size()) / float(MAX), 0.34, 1.0)


func _make_drops() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 24
	p.lifetime = 0.9
	p.position = Vector3.UP * 1.0
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 0.35
	mat.direction = Vector3.UP
	mat.spread = 25.0
	mat.initial_velocity_min = 0.3
	mat.initial_velocity_max = 0.7
	mat.gravity = Vector3(0.0, 0.4, 0.0)
	mat.scale_min = 0.6
	mat.scale_max = 1.2
	var fade := Gradient.new()
	fade.set_color(0, Color(COLOUR, 0.9))
	fade.set_color(1, Color(COLOUR, 0.0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	mat.color_ramp = ramp
	p.process_material = mat
	var dot := SphereMesh.new()
	dot.radius = 0.025
	dot.height = 0.05
	dot.radial_segments = 6
	dot.rings = 3
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = COLOUR
	m.emission_enabled = true
	m.emission = COLOUR
	dot.material = m
	p.draw_pass_1 = dot
	return p
