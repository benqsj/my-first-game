class_name HeroBurn
extends Node3D

## A hero alight (a skeleton archer's burning arrow, [BowFighter]): flames
## licking up off him, embers, a warm flickering light, for `left` seconds.
## Made on every peer by the archer's [method BowFighter.net_burn]; the hero's
## own peer, which owns his health, takes `dps` off it. Rolling does not put
## it out; it burns down.

const TICK := 0.5

var left: float = 0.0
var dps: float = 6.0
var _tick: float = 0.0
var _flames: GPUParticles3D
var _embers: GPUParticles3D
var _light: OmniLight3D
var _age: float = 0.0


## Sets `hero` alight for `seconds` (renewed, never shortened).
static func ignite(hero: Node3D, seconds: float, burn_dps: float) -> void:
	if hero == null or not is_instance_valid(hero) or bool(hero.get("is_dead")):
		return
	var burn := hero.get_node_or_null(^"HeroBurn") as HeroBurn
	if burn == null:
		burn = HeroBurn.new()
		burn.name = "HeroBurn"
		hero.add_child(burn)
	burn.left = maxf(burn.left, seconds)
	burn.dps = burn_dps


func _ready() -> void:
	position = Vector3.UP * 1.0
	_flames = SkillFx.particles(self, global_position, {
		"amount": 60, "life": 0.5, "speed": Vector2(0.3, 0.9), "spread": 30.0, "local": false,
		"gravity": Vector3(0, 2.5, 0), "size": Vector2(0.18, 0.34), "sphere": 0.35,
		"tex": SkillFx.flame(), "quad": Vector2(0.5, 1.0), "add": false, "grow": 0.2,
		"colors": [Color(1.0, 0.62, 0.18, 0.0), Color(1.0, 0.5, 0.08, 0.9), Color(0.92, 0.2, 0.02, 0.8),
				Color(0.25, 0.03, 0.0, 0.0)],
	})
	_embers = SkillFx.particles(self, global_position, {
		"amount": 18, "life": 0.9, "speed": Vector2(0.5, 1.4), "spread": 50.0, "local": false,
		"gravity": Vector3(0, 1.0, 0), "size": Vector2(0.03, 0.05), "sphere": 0.3, "add": true,
		"colors": [Color(1.0, 0.8, 0.4, 1.0), Color(1.0, 0.4, 0.05, 0.0)],
	})
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.45, 0.1)
	_light.omni_range = 3.5
	_light.shadow_enabled = false
	add_child(_light)


func _process(delta: float) -> void:
	_age += delta
	var hero := get_parent() as Node3D
	left -= delta
	if hero == null or left <= 0.0 or bool(hero.get("is_dead")):
		_flames.emitting = false
		_embers.emitting = false
		_light.light_energy = move_toward(_light.light_energy, 0.0, delta * 6.0)
		if left < -1.0 or (hero != null and bool(hero.get("is_dead"))):
			queue_free()
		return
	_flames.emitting = true
	_embers.emitting = true
	_light.light_energy = 1.6 + 0.6 * sin(_age * 23.0) * sin(_age * 7.0)
	if not hero.is_multiplayer_authority():
		return
	_tick += delta
	if _tick < TICK:
		return
	_tick -= TICK
	if hero.has_method(&"_take_damage"):
		hero.call(&"_take_damage", dps * TICK)
