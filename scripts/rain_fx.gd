class_name RainFx
extends Node3D

## What the Rain of Arrows throws off besides its arrows ([ArrowRain]), drawn
## with textures (assets/fx/tex/rain_*, hit_*: Kenney, Cartoon FX, Vefects,
## Area of Effect Spell, see SOURCES.txt). Three looks for the user to pick
## from ([member look], the user's word 2026-10-05: on the shot and while it
## falls):
##
## * [constant DUST] — wind and earth: a gust off the bow and a puff of dust
##   at his feet as the arrow goes up; faint streaks of cut air coming down
##   with the volley; each arrow that goes into the ground kicks up a clod and
##   a little dust, and a low haze of it hangs over the patch after.
## * [constant VOLLEY] (the user's pick, 2026-10-05) — the same, louder: a
##   glint high up where the volley turns over, more dust. No ring on the
##   ground under it (the user's word).
## * [constant GOLD] — a hunter's spell: rays and sparks of gold off the bow,
##   a gold rune turning on the ground under the fall, gold streaks, the
##   arrows' lines gold, sparks where they land.
##
## Everything here is seen only; the arrows hurt as they always did. Every
## peer draws its own from the same rain.

enum { DUST, VOLLEY, GOLD }
const LOOK_NAMES := ["ქარი და მტვერი", "ზალპი", "ოქრო (რუნა)"]
## Which look every rain is drawn in.
static var look: int = VOLLEY

const TEX := "res://assets/fx/tex/"
const GOLD_HOT := Color(2.2, 1.6, 0.55)
const GOLD_SOFT := Color(1.0, 0.78, 0.32)
const EARTH := Color(0.42, 0.34, 0.24)

static var _tex: Dictionary = {}
static var _quads: Dictionary = {}

var _radius: float = 3.8
var _mark: Decal
var _sheet: GPUParticles3D


#region The shot up
## As the arrow goes up off the bow at `hand`, on its way `up`; `feet` the
## ground under him.
static func loosed(into: Node, hand: Vector3, up: Vector3, feet: Vector3) -> void:
	if into == null or not into.is_inside_tree():
		return
	var fx := _burst(into, hand, 1.4)
	var way := up.normalized() if up.length_squared() > 0.01 else Vector3.UP
	match look:
		DUST, VOLLEY:
			fx._emit("rain_gust", Vector2(1.3, 1.3), false, 2, 0.36, _gust_motion(), Color(0.95, 0.95, 0.92, 0.7))
			fx._emit("rain_haze", Vector2(0.75, 0.75), false, 4, 0.9, _puff_motion(way), Color(0.9, 0.88, 0.84, 0.5))
			if look == VOLLEY:
				fx._emit("hit_star4", Vector2(0.45, 0.45), true, 1, 0.12, _still_motion(), Color(1.0, 0.95, 0.85))
			var dust := _burst(into, feet + Vector3.UP * 0.05, 1.6)
			dust._emit("rain_dust", Vector2(1.1, 1.1), false, 7 if look == VOLLEY else 5, 1.1, _ring_motion(),
					Color(EARTH.lightened(0.3), 0.7), true)
		GOLD:
			fx._emit("rain_rays", Vector2(1.1, 1.1), true, 1, 0.28, _grow_motion(), GOLD_HOT)
			fx._emit("hit_flare", Vector2(0.7, 0.7), true, 1, 0.18, _still_motion(), GOLD_HOT)
			fx._emit("hit_spark_streak", Vector2(0.05, 0.3), true, 14, 0.5, _sparks_motion(way, 50.0, 6.0, 14.0),
					GOLD_HOT, false, true)
			fx._lamp(GOLD_SOFT, 2.0, 0.25, 4.0)
#endregion


#region Over the patch
## What lies over the patch while it falls, a child of the rain (so it goes
## with it when it follows what it was loosed at): the ring or the rune on the
## ground, the streaks coming down, the haze after.
static func cover(rain: Node3D, radius: float, delay: float, duration: float) -> RainFx:
	var fx := RainFx.new()
	fx.name = "RainFx"
	fx._radius = radius
	rain.add_child(fx)
	fx.position = Vector3.ZERO
	# no ring on the ground under the volley (the user's word, 2026-10-05):
	# only the gold look lays its rune
	if look == GOLD:
		fx._ground_mark("rain_rune", GOLD_SOFT, 1.5, delay, duration)
	return fx


## The volley coming down from `source` (high over the patch, a little back
## towards the archer), over `duration`: faint streaks of the air it cuts, and
## a glint up there where it turns over.
func falling(source: Vector3, duration: float) -> void:
	var tint := Color(0.92, 0.94, 1.0, 0.38) if look != GOLD else Color(GOLD_HOT, 0.6)
	var p := GPUParticles3D.new()
	p.amount = 46 if look != DUST else 34
	p.lifetime = 0.5
	p.local_coords = false
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = AABB(Vector3(-12, -20, -12), Vector3(24, 30, 24))
	var pm := ParticleProcessMaterial.new()
	var down := (global_position - source).normalized()
	pm.direction = down
	pm.spread = 3.0
	pm.initial_velocity_min = 30.0
	pm.initial_velocity_max = 36.0
	pm.gravity = Vector3.ZERO
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(_radius * 0.9, 0.5, _radius * 0.9)
	pm.color_ramp = _ramp([[0.0, Color(tint, 0.0)], [0.2, tint], [0.8, tint], [1.0, Color(tint, 0.0)]])
	p.process_material = pm
	p.draw_pass_1 = _quad("rain_streak", Vector2(0.09, 1.8), look == GOLD, false)
	p.transform_align = GPUParticles3D.TRANSFORM_ALIGN_Z_BILLBOARD_Y_TO_VELOCITY
	add_child(p)
	# its emitter half way down, so the streaks are seen over the patch, not
	# up where the camera never looks
	p.global_position = global_position.lerp(source, 0.55)
	p.emitting = true
	_sheet = p
	get_tree().create_timer(duration, false).timeout.connect(func() -> void:
		if is_instance_valid(p):
			p.emitting = false)
	if look == VOLLEY or look == GOLD:
		var glint := _burst(get_parent().get_parent(), source, 1.0)
		if look == VOLLEY:
			glint._emit("hit_star4", Vector2(1.6, 1.6), true, 1, 0.3, _still_motion(), Color(1.0, 0.97, 0.9, 0.8))
		else:
			glint._emit("rain_rays", Vector2(2.4, 2.4), true, 1, 0.4, _grow_motion(), GOLD_HOT)
			glint._emit("hit_flare", Vector2(1.4, 1.4), true, 1, 0.3, _still_motion(), GOLD_HOT)


## The haze of dust over the patch once the most of it has come down.
func settle() -> void:
	if look == GOLD:
		return
	var p := _emit("rain_haze", Vector2(2.2, 2.2), false, 9 if look == VOLLEY else 7, 2.4, _haze_motion(_radius),
			Color(EARTH.lightened(0.35), 0.45), true)
	p.position = Vector3.UP * 0.5


## The ring or rune laid on the ground: up over `delay`, held through the fall,
## gone half a second after. `turn` radians a second.
func _ground_mark(texture: String, tint: Color, turn: float, delay: float, duration: float) -> void:
	var d := Decal.new()
	d.size = Vector3(_radius * 2.25, 3.0, _radius * 2.25)
	d.texture_albedo = _texture(texture)
	d.texture_emission = _texture(texture)
	d.emission_energy = 1.6 if look == GOLD else 0.5
	d.albedo_mix = 1.0
	d.modulate = Color(tint, 0.0)
	d.upper_fade = 0.3
	d.lower_fade = 0.3
	d.cull_mask = 1
	add_child(d)
	d.position = Vector3.UP * 0.5
	_mark = d
	var a := 0.55 if look == GOLD else 0.4
	var tw := d.create_tween()
	tw.tween_property(d, "modulate", Color(tint, a), maxf(delay, 0.1)).set_ease(Tween.EASE_OUT)
	tw.tween_interval(duration)
	tw.tween_property(d, "modulate", Color(tint, 0.0), 0.6)
	if turn != 0.0:
		var spin := d.create_tween()
		spin.tween_property(d, "rotation:y", turn * (delay + duration + 0.6), delay + duration + 0.6)
#endregion


#region An arrow in the ground
## Where one of the volley went into the ground (not a body: what bleeds,
## bleeds, [Blood]).
static func landed(into: Node, at: Vector3) -> void:
	if into == null or not into.is_inside_tree():
		return
	var fx := _burst(into, at + Vector3.UP * 0.03, 1.4)
	var big := 1.25 if look == VOLLEY else 1.0
	fx._emit("rain_dust", Vector2(1.0, 1.0) * big, false, 3, 1.0, _kick_motion(), Color(EARTH.lightened(0.3), 0.7), true)
	fx._emit("hit_chips_stone", Vector2(0.07, 0.07), false, int(7 * big), 0.65, _clods_motion(), Color(0.3, 0.23, 0.15),
			true, false, 3)
	if look == GOLD:
		fx._emit("hit_spark_streak", Vector2(0.035, 0.18), true, 6, 0.35, _sparks_motion(Vector3.UP, 60.0, 2.0, 5.0),
				GOLD_HOT, false, true)
#endregion


#region Making them
static func _burst(into: Node, at: Vector3, life: float) -> RainFx:
	var fx := RainFx.new()
	into.add_child(fx)
	fx.top_level = true
	fx.global_position = at
	fx.get_tree().create_timer(life, false).timeout.connect(fx.queue_free)
	return fx


## One emitter on this node, one shot unless it is a sheet: `texture` on a
## `size` quad, `add`itive (light) or laid over and lit (dust, clods), its
## colour over life faded from `tint`.
func _emit(texture: String, size: Vector2, add: bool, amount: int, life: float, pm: ParticleProcessMaterial,
		tint: Color, lit: bool = false, align: bool = false, frames: int = 1) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = maxi(amount, 1)
	p.lifetime = life
	p.one_shot = true
	p.explosiveness = 1.0
	p.randomness = 0.4
	p.local_coords = false
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := pm.duplicate() as ParticleProcessMaterial
	m.color = tint
	p.process_material = m
	p.draw_pass_1 = _quad(texture, size, add, not align, lit, frames)
	if align:
		p.transform_align = GPUParticles3D.TRANSFORM_ALIGN_Z_BILLBOARD_Y_TO_VELOCITY
	add_child(p)
	p.emitting = true
	return p


func _lamp(color: Color, energy: float, time: float, reach: float) -> void:
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = energy
	l.omni_range = reach
	add_child(l)
	l.create_tween().tween_property(l, "light_energy", 0.0, time)


static func _quad(texture: String, size: Vector2, add: bool, billboard: bool, lit: bool = false,
		frames: int = 1) -> QuadMesh:
	var key := "%s %s %s %s %s %d" % [texture, size, add, billboard, lit, frames]
	if _quads.has(key):
		return _quads[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL if lit else BaseMaterial3D.SHADING_MODE_UNSHADED
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


static func _base() -> ParticleProcessMaterial:
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.gravity = Vector3.ZERO
	pm.lifetime_randomness = 0.3
	pm.angle_min = -180.0
	pm.angle_max = 180.0
	return pm


static func _still_motion() -> ParticleProcessMaterial:
	var pm := _base()
	pm.spread = 0.0
	pm.color_ramp = _fade([[0.0, 1.0], [1.0, 0.0]])
	pm.scale_curve = _curve([Vector2(0, 0.6), Vector2(0.3, 1.0), Vector2(1, 0.8)])
	return pm


static func _grow_motion() -> ParticleProcessMaterial:
	var pm := _base()
	pm.spread = 0.0
	pm.color_ramp = _fade([[0.0, 1.0], [1.0, 0.0]])
	pm.scale_curve = _curve([Vector2(0, 0.2), Vector2(1, 1.0)])
	return pm


static func _gust_motion() -> ParticleProcessMaterial:
	var pm := _grow_motion()
	pm.angular_velocity_min = 500.0
	pm.angular_velocity_max = 700.0
	return pm


static func _puff_motion(way: Vector3) -> ParticleProcessMaterial:
	var pm := _base()
	pm.direction = way
	pm.spread = 25.0
	pm.initial_velocity_min = 1.0
	pm.initial_velocity_max = 2.2
	pm.damping_min = 2.0
	pm.damping_max = 3.0
	pm.color_ramp = _fade([[0.0, 0.0], [0.15, 1.0], [1.0, 0.0]])
	pm.scale_curve = _curve([Vector2(0, 0.4), Vector2(1, 1.5)])
	return pm


static func _ring_motion() -> ParticleProcessMaterial:
	var pm := _base()
	pm.direction = Vector3(1, 0.15, 0)
	pm.spread = 180.0
	pm.flatness = 0.9
	pm.initial_velocity_min = 1.2
	pm.initial_velocity_max = 2.4
	pm.damping_min = 2.0
	pm.damping_max = 3.0
	pm.color_ramp = _fade([[0.0, 0.0], [0.15, 1.0], [1.0, 0.0]])
	pm.scale_curve = _curve([Vector2(0, 0.5), Vector2(1, 1.4)])
	return pm


static func _kick_motion() -> ParticleProcessMaterial:
	var pm := _base()
	pm.spread = 35.0
	pm.initial_velocity_min = 0.4
	pm.initial_velocity_max = 1.1
	pm.damping_min = 1.5
	pm.damping_max = 2.0
	pm.angle_min = -15.0
	pm.angle_max = 15.0
	pm.color_ramp = _fade([[0.0, 0.0], [0.1, 1.0], [1.0, 0.0]])
	pm.scale_curve = _curve([Vector2(0, 0.4), Vector2(1, 1.3)])
	return pm


static func _clods_motion() -> ParticleProcessMaterial:
	var pm := _base()
	pm.spread = 40.0
	pm.initial_velocity_min = 1.6
	pm.initial_velocity_max = 3.4
	pm.gravity = Vector3(0, -12.0, 0)
	pm.scale_min = 0.6
	pm.scale_max = 1.4
	pm.angular_velocity_min = -400.0
	pm.angular_velocity_max = 400.0
	pm.anim_offset_min = 0.0
	pm.anim_offset_max = 1.0
	pm.color_ramp = _fade([[0.0, 1.0], [0.85, 1.0], [1.0, 0.0]])
	return pm


static func _sparks_motion(way: Vector3, spread: float, v_min: float, v_max: float) -> ParticleProcessMaterial:
	var pm := _base()
	pm.direction = way
	pm.spread = spread
	pm.initial_velocity_min = v_min
	pm.initial_velocity_max = v_max
	pm.gravity = Vector3(0, -9.0, 0)
	pm.damping_min = 2.0
	pm.damping_max = 3.0
	pm.color_ramp = _fade([[0.0, 1.0], [0.6, 0.8], [1.0, 0.0]])
	pm.scale_curve = _curve([Vector2(0, 1.0), Vector2(1, 0.3)])
	return pm


static func _haze_motion(radius: float) -> ParticleProcessMaterial:
	var pm := _base()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(radius * 0.7, 0.2, radius * 0.7)
	pm.spread = 80.0
	pm.initial_velocity_min = 0.1
	pm.initial_velocity_max = 0.4
	pm.gravity = Vector3(0, 0.12, 0)
	pm.angular_velocity_min = -20.0
	pm.angular_velocity_max = 20.0
	pm.color_ramp = _fade([[0.0, 0.0], [0.25, 1.0], [1.0, 0.0]])
	pm.scale_curve = _curve([Vector2(0, 0.6), Vector2(1, 1.3)])
	return pm


## A ramp of white whose alpha goes through `stops` ([offset, alpha] each);
## the particle's colour tints it.
static func _fade(stops: Array) -> GradientTexture1D:
	var rows: Array = []
	for st: Array in stops:
		rows.append([st[0], Color(1, 1, 1, float(st[1]))])
	return _ramp(rows)


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
#endregion
