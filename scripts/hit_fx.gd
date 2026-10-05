class_name HitFx
extends Node3D

## What a blade throws off when it meets something hard (VFX plan, the user's
## pick of 2026-10-05), drawn with textures (assets/fx/tex/hit_*, Kenney and
## Cartoon FX, see SOURCES.txt) rather than by code:
##
## * &"stone": a small flash, a few short sparks, grey chips thrown out and
##   falling, a puff of dust ([method SkinnedRig.blade_landed] on a golem, a
##   wall, a rock).
## * &"wood": splinters and a little brown dust, no sparks (a trunk, a fence).
## * &"bone": pale chips and a small flash.
## * &"metal": steel on steel, a cut caught on a guard ([method ImpactFx.strike]
##   &"guard"): a hot star, spikes, a spray of long sparks falling, a brief
##   warm light.
## * &"shield": a blow taken on his shield ([ParryFlash], less than a parry):
##   spikes, sparks and a few splinters (no ring: it showed as a second shield,
##   the user's word 2026-10-05).
## * &"clash": blade on blade, a parry ([ParryFlash] at full size): a wide
##   flare, a spinning four-point star, a ring, the most sparks, a bright light.
##
## Each is one node of a few one-shot [GPUParticles3D] that frees itself; the
## materials and meshes are made once per look and shared. `normal` is the way
## the sparks fly (out of what was struck, towards the viewer or the striker);
## `heft` scales a heavy blow up a little.

const TEX := "res://assets/fx/tex/"
## Seconds before a burst frees itself: the longest of its parts (the dust).
const LIFE := 1.6

const HOT := [[0.0, Color(3.0, 2.8, 2.4, 1.0)], [0.2, Color(2.6, 1.9, 0.8, 1.0)],
		[0.6, Color(2.0, 0.9, 0.25, 0.9)], [1.0, Color(1.2, 0.3, 0.05, 0.0)]]

static var _tex: Dictionary = {}
## Shared [QuadMesh]es with their materials, by a key of the look.
static var _quads: Dictionary = {}
## Shared [ParticleProcessMaterial]s, by the part's name.
static var _process: Dictionary = {}


## Throws the burst `kind` into `into` (the level) at `at`.
static func spawn(into: Node, kind: StringName, at: Vector3, normal: Vector3, heft: float = 1.0) -> HitFx:
	if into == null or not into.is_inside_tree():
		return null
	var fx := HitFx.new()
	into.add_child(fx)
	fx.global_position = at
	fx._build(kind, normal.normalized() if normal.length_squared() > 0.0001 else Vector3.UP,
			clampf(heft, 0.6, 2.0))
	return fx


## The way out of a hit at `at` that reads well on the screen: towards the
## view, tipped up a little; `toward` (a striker) when there is no camera.
static func facing_out(from: Node, at: Vector3, toward: Vector3 = Vector3.INF) -> Vector3:
	var cam: Camera3D = null
	if from != null and from.is_inside_tree():
		cam = from.get_viewport().get_camera_3d()
	var out := Vector3.UP
	if cam != null:
		out = cam.global_position - at
	elif toward != Vector3.INF:
		out = toward - at
	out.y = maxf(out.y, 0.0)
	return (out.normalized() + Vector3.UP * 0.35).normalized()


func _build(kind: StringName, normal: Vector3, heft: float) -> void:
	top_level = true
	var big := lerpf(1.0, 1.35, clampf(heft - 1.0, 0.0, 1.0))
	match kind:
		&"stone":
			_part("stone_flash", "hit_star", Vector2(0.35, 0.35) * big, true, 1, 0.08, normal)
			_part("stone_sparks", "hit_spark_streak", Vector2(0.06, 0.28), true, int(9 * big), 0.28, normal)
			_part("stone_chips", "hit_chips_stone", Vector2(0.06, 0.06), false, int(12 * big), 0.85, normal)
			_part("dust", "hit_dust", Vector2(0.4, 0.4) * big, false, 5, 1.0, normal)
			_lamp(Color(1.0, 0.75, 0.45), 1.5, 0.1, 2.5)
		&"wood":
			_part("wood_chips", "hit_chips_wood", Vector2(0.085, 0.085), false, int(12 * big), 0.8, normal)
			_part("wood_dust", "hit_dust", Vector2(0.45, 0.45) * big, false, 3, 1.0, normal)
		&"bone":
			_part("stone_flash", "hit_star", Vector2(0.3, 0.3) * big, true, 1, 0.08, normal)
			_part("bone_chips", "hit_chips_stone", Vector2(0.05, 0.05), false, int(10 * big), 0.7, normal)
		&"metal":
			_part("metal_star", "hit_star", Vector2(0.7, 0.7) * big, true, 1, 0.12, normal)
			_part("spikes", "hit_spikes", Vector2(0.45, 0.45) * big, true, 1, 0.09, normal)
			_part("metal_sparks", "hit_spark_streak", Vector2(0.08, 0.42), true, int(28 * big), 0.42, normal)
			_lamp(Color(1.0, 0.75, 0.4), 2.2, 0.14, 3.0)
		&"shield":
			_part("spikes", "hit_spikes", Vector2(0.55, 0.55) * big, true, 1, 0.1, normal)
			_part("shield_sparks", "hit_spark_streak", Vector2(0.07, 0.32), true, int(14 * big), 0.35, normal)
			_part("shield_chips", "hit_chips_wood", Vector2(0.07, 0.07), false, int(5 * big), 0.7, normal)
			_lamp(Color(1.0, 0.85, 0.55), 2.5 * big, 0.14, 3.0)
		&"clash":
			_part("flare", "hit_flare", Vector2(1.6, 0.8) * big, true, 1, 0.16, normal)
			_part("star4", "hit_star4", Vector2(0.9, 0.9) * big, true, 1, 0.22, normal)
			_part("ring", "hit_ring", Vector2(1.6, 1.6) * big, true, 1, 0.26, normal)
			_part("clash_sparks", "hit_spark_streak", Vector2(0.08, 0.5), true, int(36 * big), 0.5, normal)
			_lamp(Color(1.0, 0.9, 0.7), 3.5 * big, 0.2, 4.0)
	get_tree().create_timer(LIFE).timeout.connect(queue_free)


## One emitter of the part `part` (its motion: [method _motion]), drawn with
## `texture` on a `size` quad, `add`itive (light) or laid over (chips, dust).
func _part(part: String, texture: String, size: Vector2, add: bool, amount: int, life: float, normal: Vector3) -> void:
	var p := GPUParticles3D.new()
	p.amount = maxi(amount, 1)
	p.lifetime = life
	p.one_shot = true
	p.explosiveness = 1.0
	p.randomness = 0.4
	p.local_coords = false
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var align := part.ends_with("sparks")
	var frames := 3 if part.ends_with("chips") else 1
	p.process_material = _motion(part)
	p.draw_pass_1 = _quad(texture, size, add, not align, frames)
	if align:
		p.transform_align = GPUParticles3D.TRANSFORM_ALIGN_Z_BILLBOARD_Y_TO_VELOCITY
	add_child(p)
	# the burst's own frame: its local +Y along `normal`, so one process
	# material serves every way a hit can face
	p.basis = _toward(normal)
	p.emitting = true


static func _toward(normal: Vector3) -> Basis:
	var side := normal.cross(Vector3.FORWARD if absf(normal.dot(Vector3.FORWARD)) < 0.95 else Vector3.RIGHT).normalized()
	var fwd := side.cross(normal).normalized()
	return Basis(side, normal, fwd)


## How a part's particles move and fade, made once. Their direction is local
## +Y, turned by the emitter to the hit's normal; gravity stays world down.
static func _motion(part: String) -> ParticleProcessMaterial:
	if _process.has(part):
		return _process[part]
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.gravity = Vector3.ZERO
	pm.lifetime_randomness = 0.35
	match part:
		"stone_flash":
			pm.color_ramp = _ramp([[0.0, Color(1, 0.92, 0.75, 1)], [1.0, Color(1, 0.8, 0.5, 0)]])
			_still(pm)
		"metal_star":
			pm.color_ramp = _ramp([[0.0, Color(1, 0.97, 0.85, 1)], [1.0, Color(1, 0.8, 0.4, 0)]])
			pm.scale_curve = _curve([Vector2(0, 0.5), Vector2(0.3, 1.0), Vector2(1, 0.6)])
			_still(pm)
		"spikes":
			pm.color_ramp = _ramp([[0.0, Color(2.0, 1.8, 1.3, 1)], [1.0, Color(1.5, 1.0, 0.5, 0)]])
			pm.scale_curve = _curve([Vector2(0, 0.45), Vector2(1, 1.05)])
			_still(pm)
		"flare":
			pm.color_ramp = _ramp([[0.0, Color(1, 1, 1, 1)], [1.0, Color(1, 0.85, 0.5, 0)]])
			pm.scale_curve = _curve([Vector2(0, 0.5), Vector2(0.25, 1.0), Vector2(1, 0.7)])
		"star4":
			pm.color_ramp = _ramp([[0.0, Color(1, 0.98, 0.9, 1)], [1.0, Color(1, 0.8, 0.4, 0)]])
			pm.scale_curve = _curve([Vector2(0, 0.3), Vector2(0.2, 1.0), Vector2(1, 0.8)])
			pm.angle_min = -180.0
			pm.angle_max = 180.0
			pm.angular_velocity_min = -400.0
			pm.angular_velocity_max = 400.0
		"ring":
			pm.color_ramp = _ramp([[0.0, Color(2.0, 1.9, 1.6, 0.9)], [1.0, Color(1.5, 1.2, 0.8, 0)]])
			pm.scale_curve = _curve([Vector2(0, 0.1), Vector2(1, 1.0)])
		"stone_sparks", "metal_sparks", "shield_sparks", "clash_sparks":
			var speed: Vector2 = {"stone_sparks": Vector2(3.0, 7.0), "metal_sparks": Vector2(4.0, 10.0),
					"shield_sparks": Vector2(3.0, 7.5), "clash_sparks": Vector2(5.0, 11.0)}[part]
			pm.spread = {"stone_sparks": 60.0, "metal_sparks": 70.0, "shield_sparks": 85.0, "clash_sparks": 100.0}[part]
			pm.initial_velocity_min = speed.x
			pm.initial_velocity_max = speed.y
			pm.gravity = Vector3(0.0, -11.0, 0.0)
			pm.damping_min = 2.5
			pm.damping_max = 3.5
			pm.color_ramp = _ramp(HOT)
			pm.scale_curve = _curve([Vector2(0, 1.0), Vector2(1, 0.3)])
		"stone_chips", "bone_chips", "wood_chips", "shield_chips":
			pm.direction = Vector3(0.0, 1.0, 0.0)
			pm.spread = 55.0
			pm.initial_velocity_min = 2.0
			pm.initial_velocity_max = 4.8
			pm.gravity = Vector3(0.0, -13.0, 0.0)
			pm.scale_min = 0.55
			pm.scale_max = 1.4
			pm.angle_min = -180.0
			pm.angle_max = 180.0
			pm.angular_velocity_min = -400.0
			pm.angular_velocity_max = 400.0
			pm.anim_offset_min = 0.0
			pm.anim_offset_max = 1.0
			var c: Color = {"stone_chips": Color(0.22, 0.21, 0.2), "bone_chips": Color(0.62, 0.6, 0.55),
					"wood_chips": Color(0.36, 0.24, 0.13), "shield_chips": Color(0.36, 0.24, 0.13)}[part]
			pm.color_ramp = _ramp([[0.0, c], [0.85, c], [1.0, Color(c, 0.0)]])
		"dust", "wood_dust":
			var d := Color(0.45, 0.43, 0.4) if part == "dust" else Color(0.45, 0.36, 0.26)
			pm.spread = 40.0
			pm.initial_velocity_min = 0.3
			pm.initial_velocity_max = 0.9
			pm.gravity = Vector3(0.0, 0.25, 0.0)
			pm.damping_min = 1.2
			pm.damping_max = 1.7
			pm.angle_min = -180.0
			pm.angle_max = 180.0
			pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
			pm.emission_sphere_radius = 0.08
			pm.scale_curve = _curve([Vector2(0, 0.4), Vector2(1, 1.6)])
			pm.color_ramp = _ramp([[0.0, Color(d, 0.0)], [0.12, Color(d, 0.3)], [1.0, Color(d, 0.0)]])
	_process[part] = pm
	return pm


static func _still(pm: ParticleProcessMaterial) -> void:
	pm.angle_min = -180.0
	pm.angle_max = 180.0


## The quad a part is drawn on, with its material, made once per look.
static func _quad(texture: String, size: Vector2, add: bool, billboard: bool, frames: int) -> QuadMesh:
	var key := "%s %s %s %s %d" % [texture, size, add, billboard, frames]
	if _quads.has(key):
		return _quads[key]
	var m := StandardMaterial3D.new()
	# light is drawn as it is; chips and dust are lit by the scene, as they
	# read far too pale unshaded under its exposure
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if add else BaseMaterial3D.SHADING_MODE_PER_PIXEL
	m.roughness = 1.0
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if add:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_texture = _texture(texture)
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.disable_receive_shadows = true
	if billboard:
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		m.billboard_keep_scale = true
		m.particles_anim_h_frames = frames
		m.particles_anim_v_frames = frames
		m.particles_anim_loop = false
	var q := QuadMesh.new()
	q.size = size
	q.material = m
	_quads[key] = q
	return q


static func _texture(name: String) -> Texture2D:
	if not _tex.has(name):
		_tex[name] = load(TEX + name + ".png")
	return _tex[name]


## A brief light where it struck.
func _lamp(color: Color, energy: float, time: float, reach: float) -> void:
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = energy
	l.omni_range = reach
	l.shadow_enabled = false
	add_child(l)
	l.create_tween().tween_property(l, "light_energy", 0.0, time).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)


static func _ramp(stops: Array) -> GradientTexture1D:
	var g := Gradient.new()
	var offs := PackedFloat32Array()
	var cols := PackedColorArray()
	for st: Array in stops:
		offs.append(float(st[0]))
		cols.append(st[1] as Color)
	g.offsets = offs
	g.colors = cols
	var t := GradientTexture1D.new()
	t.gradient = g
	return t


static func _curve(points: Array) -> CurveTexture:
	var c := Curve.new()
	for p: Vector2 in points:
		c.add_point(p)
	var t := CurveTexture.new()
	t.curve = c
	return t
