class_name IceShard
extends SpellBolt

## One of the elf's Frost Spears ([MageSkills]): a long six-sided spike of ice
## thrown point first. A [SpellBolt] in how it flies — it hunts what it was
## thrown at, it is dodged only in time, dodged it flies on past and strikes
## whatever stands behind, and it goes through m.def — but it leaves at speed
## (it has hung in the air already), trails a thin white streak and frost, and
## breaks into ice where it strikes.

const ICE := Color(0.62, 0.9, 1.0)
const ICE_HOT := Color(0.9, 0.98, 1.0)
## The spike, in metres (the model is drawn at `MODEL_SCALE`, the bolt's).
const LENGTH := 0.78
const RADIUS := 0.085


func _ready() -> void:
	glow_colour = ICE
	super()
	# already up to speed when let go, and no great ramp after
	start_share = 0.65
	ramp_distance = 5.0
	ramp_min = 2.0
	ramp_max = 8.0
	ramp_curve = 1.0
	steer = 30.0
	if _model != null:
		_model.queue_free()
	_model = spike(LENGTH / MODEL_SCALE, RADIUS / MODEL_SCALE, 1.6)
	add_child(_model)
	if _light != null:
		_light.light_color = ICE
		_light.light_energy = 1.4
		_light.omni_range = 2.6


func _process(delta: float) -> void:
	super(delta)
	# full size from the moment it is thrown (the bolt swells from a spark)
	if _model != null and not _fading and not _spent:
		_model.scale = Vector3.ONE * MODEL_SCALE


## A spike of ice along +Y, its point up: a long six-sided cone over a short
## one, so it reads as a crystal from any side. `glow` its emission.
static func spike(length: float, radius: float, glow: float) -> Node3D:
	var root := Node3D.new()
	root.name = "Spike"
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.78, 0.94, 1.0, 0.88)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = ICE
	mat.emission_energy_multiplier = glow
	mat.roughness = 0.08
	mat.metallic = 0.25
	mat.rim_enabled = true
	mat.rim = 1.0
	var tip := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = radius
	cone.height = length * 0.78
	cone.radial_segments = 6
	cone.rings = 1
	tip.mesh = cone
	tip.material_override = mat
	tip.position = Vector3(0.0, length * 0.39 - length * 0.11, 0.0)
	tip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(tip)
	var foot := MeshInstance3D.new()
	var back := CylinderMesh.new()
	back.top_radius = radius
	back.bottom_radius = 0.0
	back.height = length * 0.22
	back.radial_segments = 6
	back.rings = 1
	foot.mesh = back
	foot.material_override = mat
	foot.position = Vector3(0.0, -length * 0.11 - length * 0.11, 0.0)
	foot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(foot)
	return root


## A thin white streak behind it and frost falling off it.
func _lay_trail() -> void:
	var into := get_parent()
	if into == null:
		return
	_tails.append(_tail(into, 0.09, 0.2, 1.4, Color(ICE_HOT, 0.85), Color(ICE, 0.0)))
	_tails[0].head = _model if _model != null else self
	_embers = SkillFx.particles(self, global_position, {"amount": 24, "life": 0.45,
			"speed": Vector2(0.1, 0.5), "spread": 180.0, "gravity": Vector3(0, -1.5, 0),
			"size": Vector2(0.025, 0.05), "sphere": 0.05,
			"colors": [Color(ICE_HOT, 1.0), Color(ICE, 0.0)]})


## It breaks where it strikes: a white flash, chips of ice thrown out and
## falling, a puff of frost.
func _burst(where: Vector3) -> void:
	for child in get_children():
		if child is Node3D and child != _light and child != _steady:
			(child as Node3D).visible = false
	var into := get_parent()
	if into == null:
		queue_free()
		return
	SkillFx.flash(into, where, ICE_HOT, 0.45, 0.16, 3.0)
	SkillFx.particles(into, where, {"amount": 12, "one_shot": true, "explosiveness": 1.0, "life": 0.7,
			"speed": Vector2(2.0, 4.5), "spread": 180.0, "gravity": Vector3(0, -12, 0),
			"size": Vector2(0.04, 0.09), "spin": true,
			"colors": [Color(ICE_HOT, 1.0), Color(ICE, 1.0), Color(ICE, 0.0)]})
	SkillFx.particles(into, where, {"amount": 6, "one_shot": true, "explosiveness": 0.9, "life": 0.6,
			"speed": Vector2(0.3, 1.0), "spread": 180.0, "size": Vector2(0.25, 0.4), "add": false,
			"colors": [Color(0.92, 0.97, 1.0, 0.35), Color(0.9, 0.95, 1.0, 0.0)]})
	if _light != null:
		_light.global_position = where
		_light.light_energy = 4.0
		create_tween().tween_property(_light, "light_energy", 0.0, 0.3)
	get_tree().create_timer(0.4).timeout.connect(queue_free)
