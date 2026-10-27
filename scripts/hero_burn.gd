class_name HeroBurn
extends Node3D

## A hero alight (a skeleton archer's burning arrow, [BowFighter]; an imp's
## fireball, [Imp]) for `left` seconds. Made on every peer by the thrower's
## rpc; the hero's own peer, which owns his health, takes `dps` off it.
## Rolling does not put it out; it burns down.
##
## Drawn on him, not round him (the user, 2026-10-27, did not like a ball of
## flame hung on his chest): small tongues of flame lick up off his limbs and
## body, each following its bone, a thin smoke goes up off him, a few sparks,
## a low warm flicker of light. It flares up when it catches and dies down
## at the end.

const TICK := 0.5
## Bones it burns on, by the first that has a name with one of these in it
## (lower case), so it fits any hero's rig.
const PLACES := [["spine_03", "spine2", "chest"], ["spine_01", "spine", "hips", "pelvis"],
		["upperarm_l", "leftarm", "arm_l"], ["upperarm_r", "rightarm", "arm_r"],
		["lowerarm_l", "leftforearm", "forearm_l"], ["lowerarm_r", "rightforearm", "forearm_r"],
		["thigh_l", "leftupleg"], ["thigh_r", "rightupleg"], ["calf_l", "leftleg"], ["calf_r", "rightleg"],
		["head"]]
## Where a place's flames come from on a rig without those bones (height
## over his feet).
const BARE := [1.3, 1.0, 1.45, 1.45, 1.2, 1.2, 0.75, 0.75, 0.4, 0.4, 1.7]

var left: float = 0.0
var dps: float = 6.0
var _tick: float = 0.0
var _age: float = 0.0
var _skeleton: Skeleton3D
var _bones: Array[int] = []
var _tongues: Array[GPUParticles3D] = []
var _smoke: GPUParticles3D
var _sparks: GPUParticles3D
var _light: OmniLight3D


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
	var hero := get_parent() as Node3D
	var found := hero.find_children("*", "Skeleton3D", true, false)
	if not found.is_empty():
		_skeleton = found[0] as Skeleton3D
	for i in PLACES.size():
		var bone := -1
		if _skeleton != null:
			for key: String in PLACES[i]:
				for b in _skeleton.get_bone_count():
					if _skeleton.get_bone_name(b).to_lower().contains(key):
						bone = b
						break
				if bone >= 0:
					break
		_bones.append(bone)
		var big := i < 2
		_tongues.append(SkillFx.particles(self, hero.global_position + Vector3.UP * float(BARE[i]), {
			"amount": 18 if big else 10, "life": 0.5, "speed": Vector2(0.3, 0.7), "spread": 20.0,
			"gravity": Vector3(0, 2.6, 0), "size": Vector2(0.16, 0.26) if big else Vector2(0.11, 0.19),
			"sphere": 0.1 if big else 0.06, "grow": 0.2,
			"tex": SkillFx.flame(), "quad": Vector2(0.5, 1.0), "add": true,
			"colors": [Color(1.0, 0.75, 0.3, 0.0), Color(1.0, 0.55, 0.12, 0.95), Color(0.95, 0.28, 0.03, 0.75),
					Color(0.6, 0.08, 0.0, 0.3), Color(0.2, 0.02, 0.0, 0.0)],
		}))
	for t in _tongues:
		t.fixed_fps = 0
		t.interpolate = false
	_smoke = SkillFx.particles(self, hero.global_position + Vector3.UP * 1.5, {
		"amount": 14, "life": 1.3, "speed": Vector2(0.3, 0.6), "spread": 15.0,
		"gravity": Vector3(0, 0.6, 0), "size": Vector2(0.2, 0.35), "sphere": 0.2, "grow": 0.6,
		"add": false,
		"colors": [Color(0.15, 0.12, 0.1, 0.0), Color(0.18, 0.15, 0.13, 0.28), Color(0.3, 0.28, 0.27, 0.0)],
	})
	_sparks = SkillFx.particles(self, hero.global_position + Vector3.UP * 1.0, {
		"amount": 10, "life": 0.7, "speed": Vector2(0.5, 1.3), "spread": 35.0,
		"gravity": Vector3(0, 0.8, 0), "size": Vector2(0.02, 0.035), "box": Vector3(0.25, 0.6, 0.25),
		"add": true,
		"colors": [Color(1.0, 0.85, 0.5, 1.0), Color(1.0, 0.45, 0.08, 0.8), Color(1.0, 0.3, 0.05, 0.0)],
	})
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.48, 0.14)
	_light.omni_range = 3.0
	_light.light_energy = 0.0
	_light.shadow_enabled = false
	add_child(_light)
	_follow()


## Each place's flames on its bone (or its height on him).
func _follow() -> void:
	var hero := get_parent() as Node3D
	if hero == null:
		return
	var cam := get_viewport().get_camera_3d()
	for i in _tongues.size():
		var at := hero.global_position + Vector3.UP * float(BARE[i])
		if _bones[i] >= 0:
			at = (_skeleton.global_transform * _skeleton.get_bone_global_pose(_bones[i])).origin
		# a little towards the eye, so the flames lick on him and not inside him
		if cam != null:
			at += (cam.global_position - at).normalized() * 0.16
		_tongues[i].global_position = at
	_smoke.global_position = hero.global_position + Vector3.UP * 1.6
	_sparks.global_position = hero.global_position + Vector3.UP * 1.0
	_light.global_position = hero.global_position + Vector3.UP * 1.1


func _process(delta: float) -> void:
	_age += delta
	var hero := get_parent() as Node3D
	left -= delta
	_follow()
	var out := hero == null or left <= 0.0 or bool(hero.get("is_dead"))
	for t in _tongues:
		t.emitting = not out
		# it catches big and dies down small
		t.amount_ratio = clampf(0.55 + 0.45 * minf(left, 1.0), 0.3, 1.0) if _age > 0.35 else 1.0
	_smoke.emitting = not out
	_sparks.emitting = not out
	if out:
		_light.light_energy = move_toward(_light.light_energy, 0.0, delta * 4.0)
		if left < -1.2 or (hero != null and bool(hero.get("is_dead"))):
			queue_free()
		return
	var flare := 1.0 + 0.6 * clampf(1.0 - _age / 0.35, 0.0, 1.0)
	_light.light_energy = (0.9 + 0.35 * sin(_age * 21.0) * sin(_age * 6.3)) * flare
	if not hero.is_multiplayer_authority():
		return
	_tick += delta
	if _tick < TICK:
		return
	_tick -= TICK
	if hero.has_method(&"_take_damage"):
		hero.call(&"_take_damage", dps * TICK)
