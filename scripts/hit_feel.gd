class_name HitFeel
extends RefCounted

## The moment a blade goes in, felt by both of them: the swing and the body it
## bit held still together for the same beat (a light cut a breath, the last
## of a string or a heavy blow longer), and the body lit for an instant where
## it was struck. [ImpactFx] has the view and the sound; [HitReact] the body
## thrown over, which runs on the real clock and so goes on through the hold.

## How long a blow of `weight` (`SkinnedRig.cut_weight`: 0.6 the dash's cut,
## 1 a light one, 1.35–1.6 the end of a string, 1.5+ a heavy blow) holds.
static func stop_for(weight: float) -> float:
	return clampf(LIGHT_STOP + PER_WEIGHT * (weight - 1.0), MIN_STOP, MAX_STOP)

const LIGHT_STOP := 0.07
const PER_WEIGHT := 0.09
const MIN_STOP := 0.04
const MAX_STOP := 0.14

## The colour the body is lit, and how bright at a light cut and a heavy one.
const FLASH_TINT := Color(1.0, 0.93, 0.86)
const FLASH_LIGHT := 0.16
const FLASH_HEAVY := 0.34
const FLASH_TIME := 0.1
## Meshes lit at most, so a body of many parts costs little.
const MAX_MESHES := 48

static var _shader: Shader


## Both halves of the bite on `victim`: held, and lit. A big one (its
## `bite_hold` under 1, [PackBrute]) is held that share of it, or not at all:
## a blade does not stop an ogre's swing (Elden Ring's big ones take the cut
## without a pause; only their stance gives).
static func bite(victim: Node3D, weight: float) -> void:
	if victim == null or not victim.is_inside_tree():
		return
	var seconds := stop_for(weight) * hold_share(victim)
	hold(victim, seconds)
	flash(victim, lerpf(FLASH_LIGHT, FLASH_HEAVY, clampf((weight - 1.0) / 0.6, 0.0, 1.0)))


## Holds whatever is moving `victim` still for `seconds`: a rig with a hold of
## its own (the wolf's) is asked; a creature that steps its clips itself reads
## `pace()` as it does; any other clip player is stopped from advancing (manual
## process) and let go after. All on the real clock, so the hold neither drifts
## with the time scale nor fights code that sets the clips' rate.
static func hold(victim: Node3D, seconds: float) -> void:
	if victim == null or seconds <= 0.0:
		return
	var rig: Variant = victim.get(&"rig")
	if rig is Object and (rig as Object).has_method(&"hitstop") and not (rig is CharacterRig):
		(rig as Object).call(&"hitstop", seconds)
		return
	var tree := victim.get_tree()
	if tree == null:
		return
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	var was := int(victim.get_meta(&"bite_until")) if victim.has_meta(&"bite_until") else 0
	victim.set_meta(&"bite_until", maxi(was, until))
	for node in victim.find_children("*", "AnimationPlayer", true, false):
		var player := node as AnimationPlayer
		if player.has_meta(&"bite_until"):
			player.set_meta(&"bite_until", maxi(int(player.get_meta(&"bite_until")), until))
		elif player.callback_mode_process == AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL:
			continue  # stepped by its creature, which asks pace()
		else:
			player.set_meta(&"bite_mode", player.callback_mode_process)
			player.set_meta(&"bite_until", until)
			player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		tree.create_timer(seconds, true, false, true).timeout.connect(_let_go.bind(player))


## The rate a creature that steps its own clips steps them at: all but still
## while a bite holds it, else 1.
static func pace(creature: Node) -> float:
	if creature == null or not creature.has_meta(&"bite_until"):
		return 1.0
	if Time.get_ticks_msec() < int(creature.get_meta(&"bite_until")):
		return HELD_RATE
	creature.remove_meta(&"bite_until")
	return 1.0


## The share of a bite `creature` is held for (its `bite_hold`, else all).
static func hold_share(creature: Node) -> float:
	var share: Variant = creature.get(&"bite_hold") if creature != null else null
	return clampf(float(share), 0.0, 1.0) if share is float else 1.0


## Whether `creature` is held in a bite now.
static func is_held(creature: Node) -> bool:
	return creature != null and creature.has_meta(&"bite_until") \
			and Time.get_ticks_msec() < int(creature.get_meta(&"bite_until"))

const HELD_RATE := 0.04


static func _let_go(player: AnimationPlayer) -> void:
	if not is_instance_valid(player) or not player.has_meta(&"bite_until"):
		return
	if Time.get_ticks_msec() + 2 < int(player.get_meta(&"bite_until")):
		return
	player.callback_mode_process = int(player.get_meta(&"bite_mode")) as AnimationMixer.AnimationCallbackModeProcess
	player.remove_meta(&"bite_until")
	player.remove_meta(&"bite_mode")


## The body lit for an instant, brightest at its edges, and faded out. Meshes
## already wearing an overlay (an affliction, the blood) are left as they are.
static func flash(victim: Node3D, amount: float) -> void:
	if victim == null or amount <= 0.0:
		return
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	var mat := ShaderMaterial.new()
	mat.shader = _shader
	mat.set_shader_parameter(&"tint", FLASH_TINT)
	mat.set_shader_parameter(&"amount", amount)
	var lit: Array[MeshInstance3D] = []
	for node in victim.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.material_overlay != null or not mi.is_visible_in_tree():
			continue
		mi.material_overlay = mat
		lit.append(mi)
		if lit.size() >= MAX_MESHES:
			break
	if lit.is_empty():
		return
	var tw := victim.create_tween()
	tw.tween_property(mat, "shader_parameter/amount", 0.0, FLASH_TIME) \
			.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(func() -> void:
		for mi in lit:
			if is_instance_valid(mi) and mi.material_overlay == mat:
				mi.material_overlay = null)


const SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled;
uniform vec3 tint : source_color = vec3(1.0);
uniform float amount = 0.0;
void fragment() {
	float rim = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	ALBEDO = tint * amount * (0.1 + 0.9 * rim * rim * rim);
}
"""
