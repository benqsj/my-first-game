class_name SpellBolt
extends Arrow

## The mage's bolt: a ball of light with lightning crackling off the back of it
## (`assets/magic-person/magic-attack/skill1.glb`), flying straight.
##
## An [Arrow] in everything that matters — the same sweep from one tick to the
## next so nothing fast tunnels through it, the same `take_hit()` on whatever it
## meets, the same launch from the controller — and different in how it looks
## and ends: it glows and lights what it passes, trails gold rather than cut
## air, and where it strikes it bursts in a flash and is gone instead of
## sticking.

const MODEL := "res://assets/magic-person/magic-attack/skill1.glb"
## The model's orb is 1.24 across its radius; this makes it a hand's width.
const MODEL_SCALE := 0.14

## How long the burst lasts.
@export var burst_time: float = 0.3
@export var glow_colour: Color = Color(1.0, 0.82, 0.38)

var _light: OmniLight3D
var _flicker: float = 0.0


func _ready() -> void:
	super()
	streak_tint = Color(1.0, 0.86, 0.45, 0.8)
	wake_tint = Color(1.0, 0.75, 0.3, 0.22)
	crit_tint = Color(1.0, 0.95, 0.75, 0.9)
	trail_width = 0.12
	wake_spread = 3.0
	spin = 5.0
	bite = 0.0
	if ResourceLoader.exists(MODEL):
		var model := (load(MODEL) as PackedScene).instantiate() as Node3D
		# The orb leads: its tail runs off down the model's +Z, the flight is
		# this node's +Y.
		model.rotation = Vector3(PI * 0.5, 0.0, 0.0)
		model.scale = Vector3.ONE * MODEL_SCALE
		add_child(model)
		var glow := StandardMaterial3D.new()
		glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		glow.albedo_color = glow_colour
		glow.emission_enabled = true
		glow.emission = glow_colour
		glow.emission_energy_multiplier = 2.5
		for node in model.find_children("*", "MeshInstance3D", true, false):
			(node as MeshInstance3D).material_override = glow
			(node as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_light = OmniLight3D.new()
	_light.light_color = glow_colour
	_light.light_energy = 2.2
	_light.omni_range = 4.5
	add_child(_light)


func _process(delta: float) -> void:
	if _light == null or _spent:
		return
	# A crackle rather than a steady lamp.
	_flicker += delta * 30.0
	_light.light_energy = 2.0 + 0.6 * sin(_flicker) * sin(_flicker * 0.37)


func _strike(what: Node3D, where: Vector3) -> void:
	_spent = true
	_velocity = Vector3.ZERO
	for ribbon in [_trail, _wake]:
		if ribbon == null:
			continue
		ribbon.emitting = false
		ribbon.get_tree().create_timer(ribbon.fade_time + 0.1).timeout.connect(ribbon.queue_free)
	_trail = null
	_wake = null
	struck.emit(what, where, _critical)
	if what != null and what.has_method("take_hit"):
		var blow := global_transform.basis.y
		what.call("take_hit", _damage, where, blow, _critical, false, _shooter)
	_burst(where)


## The flash where it lands: a ball of light that swells and goes, and the lamp
## flaring with it. The bolt itself goes with the flash.
func _burst(where: Vector3) -> void:
	for child in get_children():
		if child is Node3D and child != _light and child != _steady:
			(child as Node3D).visible = false
	var flash := MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radius = 0.5
	ball.height = 1.0
	ball.radial_segments = 16
	ball.rings = 8
	flash.mesh = ball
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(glow_colour.r, glow_colour.g, glow_colour.b, 0.9)
	flash.material_override = mat
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(flash)
	flash.global_position = where
	flash.scale = Vector3.ONE * 0.2
	var tween := create_tween().set_parallel(true)
	tween.tween_property(flash, "scale", Vector3.ONE * (1.6 if _critical else 1.1), burst_time) \
			.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_property(mat, "albedo_color:a", 0.0, burst_time)
	if _light != null:
		_light.light_energy = 6.0
		tween.tween_property(_light, "light_energy", 0.0, burst_time)
	tween.chain().tween_callback(queue_free)


func _settle(_delta: float) -> void:
	pass
