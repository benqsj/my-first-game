class_name BlackSun
extends Node3D

## The dark elf's Black Sun ([DarkSkills], the user's word 2026-10-07): a
## black sphere hangs in the air over where she points, the light bent round
## it as round a hole in the world, a thin ring of violet fire whirling about
## it, and for `PULL` seconds it draws in everything round it: dust, smoke and
## streaks of wind running in over the ground and through the air, and every
## foe within `REACH` dragged toward it (a boss is not dragged but held back,
## going at `BOSS_PACE` of its pace, as if against the wind). Then it shrinks
## in on itself and bursts: what is within `BLAST` takes a spell's blow, less
## at the edge, and is thrown back.
##
## Drawn on every peer from the same message ([method Player.net_dark_sun]).
## The pull is worked on each body's own peer (the host for a creature, a
## hero's own for him in PvP), after its own physics tick; only the host's
## burst hurts.

const HIGH := 2.8
const REACH := 6.0
const PULL := 2.0
## How fast it drags (m/s), at the edge of its reach and nearer; it lets go a
## metre short of the middle.
const DRAG := 6.5
const NEAR := 1.0
## A boss keeps this share of its pace inside it.
const BOSS_PACE := 0.45
const BLAST := 3.6
## The burst's worth at the edge of `BLAST`, of what it is in the middle.
const EDGE := 0.55
const CORE := 0.75
const COLLAPSE := 0.22

var caster: Player
var damage: float = 0.0
var critical: bool = false

var _age: float = 0.0
var _burst := false
var _core: MeshInstance3D
var _core_mat: ShaderMaterial
var _lens: MeshInstance3D
var _lens_mat: ShaderMaterial
var _disk: MeshInstance3D
var _disk_mat: ShaderMaterial
var _swirl: Decal
var _dark: OmniLight3D
var _glow: OmniLight3D
var _emitters: Array[GPUParticles3D] = []
var _last: Dictionary = {}
var _trail_tick: float = 0.0
var _ground := Vector3.ZERO

static var _core_shader: Shader
static var _lens_shader: Shader
static var _disk_shader: Shader
const STREAK := preload("res://assets/fx/tex/rain_streak.png")


## The sun over `ground` (the ground under where she points).
static func rise(into: Node, ground: Vector3, by: Player, hurt: float, crit: bool) -> BlackSun:
	if into == null:
		return null
	var s := BlackSun.new()
	s.caster = by
	s.damage = hurt
	s.critical = crit
	s._ground = ground
	into.add_child(s)
	s.global_position = ground + Vector3.UP * HIGH
	return s


func _ready() -> void:
	# after the bodies' own ticks, so their steps are taken before it drags
	process_physics_priority = 120
	var into := get_parent()
	if _core_shader == null:
		_core_shader = Shader.new()
		_core_shader.code = CORE_SHADER
		_lens_shader = Shader.new()
		_lens_shader.code = LENS_SHADER
		_disk_shader = Shader.new()
		_disk_shader.code = DISK_SHADER
	# the hole: black, its rim burning violet
	_core_mat = ShaderMaterial.new()
	_core_mat.shader = _core_shader
	_core_mat.set_shader_parameter(&"rim_color", DarkFx.VOID)
	_core = _sphere(_core_mat, 1.0)
	_core.scale = Vector3.ONE * 0.01
	# the light bent round it
	_lens_mat = ShaderMaterial.new()
	_lens_mat.shader = _lens_shader
	_lens = _sphere(_lens_mat, 1.0)
	_lens.scale = Vector3.ONE * 0.01
	# drawn first of what is see-through, so the ring and the wind show over it
	_lens.sorting_offset = -4.0
	# the ring of fire about it, turned to the eye ([method _face_disk])
	_disk_mat = ShaderMaterial.new()
	_disk_mat.shader = _disk_shader
	_disk_mat.set_shader_parameter(&"veins", DarkFx.VEINS)
	_disk_mat.set_shader_parameter(&"hot", DarkFx.HOT)
	_disk_mat.set_shader_parameter(&"cold", DarkFx.VOID)
	var q := QuadMesh.new()
	q.size = Vector2(1.0, 1.0)
	q.orientation = PlaneMesh.FACE_Y
	_disk = MeshInstance3D.new()
	_disk.mesh = q
	_disk.material_override = _disk_mat
	_disk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_disk)
	_disk.scale = Vector3.ONE * 0.01
	# the ground under it drawn into a whirl, darkened
	_swirl = DarkFx.decal(into, _ground, DarkFx.SPIKES, REACH * 1.6, Color(DarkFx.VOID, 0.0), 1.0, 0.6)
	# a light that takes light away, and a little violet from its ring
	_dark = OmniLight3D.new()
	_dark.light_negative = true
	_dark.light_energy = 0.0
	_dark.omni_range = REACH * 1.2
	add_child(_dark)
	_glow = OmniLight3D.new()
	_glow.light_color = DarkFx.VOID
	_glow.light_energy = 0.0
	_glow.omni_range = 5.0
	add_child(_glow)
	_wind(into)


## What is drawn in: streaks of wind from all round, black wisps spiralling
## in, and dust and grit dragged over the ground.
func _wind(into: Node) -> void:
	var at := global_position
	# streaks through the air, each lying along the way it goes
	var streaks := GPUParticles3D.new()
	streaks.amount = 140
	streaks.lifetime = 0.8
	streaks.local_coords = false
	streaks.transform_align = GPUParticles3D.TRANSFORM_ALIGN_Z_BILLBOARD_Y_TO_VELOCITY
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE_SURFACE
	pm.emission_sphere_radius = REACH
	pm.direction = Vector3.UP
	pm.spread = 180.0
	pm.initial_velocity_min = 0.0
	pm.initial_velocity_max = 1.0
	pm.radial_accel_min = -22.0
	pm.radial_accel_max = -16.0
	pm.tangential_accel_min = 2.0
	pm.tangential_accel_max = 5.0
	pm.scale_min = 0.6
	pm.scale_max = 1.2
	pm.scale_curve = SkillFx.swell(0.3)
	pm.color_ramp = SkillFx.ramp([Color(0.9, 0.82, 1.0, 0.0), Color(0.9, 0.82, 1.0, 0.8), Color(DarkFx.VOID, 0.9), Color(DarkFx.VOID, 0.0)])
	streaks.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.09, 1.6)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = STREAK
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	quad.material = m
	streaks.draw_pass_1 = quad
	streaks.visibility_aabb = AABB(Vector3.ONE * -REACH * 1.3, Vector3.ONE * REACH * 2.6)
	into.add_child(streaks)
	streaks.global_position = at
	streaks.emitting = true
	_emitters.append(streaks)
	# black wisps spiralling in
	var wisps := SkillFx.particles(into, at, {"amount": 40, "life": 1.1, "ring": Vector2(REACH * 0.5, REACH * 0.9),
			"speed": Vector2(0.0, 0.4), "orbit": -9.0, "tangent": 7.0, "size": Vector2(0.9, 1.5), "grow": 0.4,
			"add": false, "tex": DarkFx.PUFF, "spin": true,
			"colors": [Color(DarkFx.INK, 0.0), Color(DarkFx.INK, 0.65), Color(0.08, 0.04, 0.1, 0.0)]})
	wisps.visibility_aabb = AABB(Vector3.ONE * -REACH * 1.3, Vector3.ONE * REACH * 2.6)
	_emitters.append(wisps)
	# dust and grit dragged over the ground
	var dust := SkillFx.particles(into, _ground + Vector3.UP * 0.15, {"amount": 50, "life": 1.0,
			"ring": Vector2(REACH * 0.35, REACH), "speed": Vector2(0.0, 0.3), "orbit": -10.0, "tangent": 4.0,
			"gravity": Vector3(0, 0.6, 0), "size": Vector2(0.5, 1.0), "grow": 0.5, "add": false,
			"tex": DarkFx.PUFF, "spin": true,
			"colors": [Color(0.42, 0.38, 0.36, 0.0), Color(0.4, 0.36, 0.35, 0.35), Color(0.3, 0.26, 0.3, 0.0)]})
	dust.visibility_aabb = AABB(Vector3.ONE * -REACH * 1.3, Vector3.ONE * REACH * 2.6)
	_emitters.append(dust)
	# violet motes falling into it
	var motes := SkillFx.particles(into, at, {"amount": 50, "life": 0.7, "sphere": REACH * 0.7,
			"speed": Vector2(0.0, 0.2), "orbit": -14.0, "tangent": 6.0, "size": Vector2(0.03, 0.06), "grow": 0.2,
			"colors": [Color(DarkFx.HOT, 0.0), Color(DarkFx.HOT, 1.0), Color(DarkFx.VOID, 0.0)]})
	_emitters.append(motes)


func _sphere(mat: Material, radius: float) -> MeshInstance3D:
	var s := SphereMesh.new()
	s.radius = radius
	s.height = radius * 2.0
	s.radial_segments = 32
	s.rings = 16
	var mi := MeshInstance3D.new()
	mi.mesh = s
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


func _process(delta: float) -> void:
	_age += delta
	if _burst:
		return
	var grow := 1.0 - pow(1.0 - clampf(_age / 0.3, 0.0, 1.0), 3.0)
	var end := PULL
	var shrink := clampf((_age - end) / COLLAPSE, 0.0, 1.0)
	var pulse := 1.0 + 0.05 * sin(_age * 18.0)
	var k := grow * (1.0 - shrink * shrink * 0.9)
	_core.scale = Vector3.ONE * CORE * k * pulse * (1.0 + 0.5 * shrink * (1.0 - shrink))
	_lens.scale = Vector3.ONE * CORE * 2.3 * k
	_lens_mat.set_shader_parameter(&"strength", grow * (1.0 + 2.0 * shrink))
	_disk.scale = Vector3.ONE * CORE * 5.0 * k
	_disk_mat.set_shader_parameter(&"turn", _age * 3.0)
	_face_disk()
	_disk_mat.set_shader_parameter(&"fade", grow)
	_swirl.rotation.y -= delta * 2.5
	_swirl.modulate.a = 0.7 * grow
	_dark.light_energy = 1.6 * grow
	_glow.light_energy = 1.5 * grow
	_trail_tick -= delta
	if _trail_tick <= 0.0:
		_trail_tick = 0.22
		for who in _foes():
			if _inside(who):
				DarkFx.smoke(get_parent(), who.global_position + Vector3.UP * 0.2, 2, 0.6, 0.6, 0.4, 0.2)
	if shrink >= 1.0:
		_explode()


## The ring tipped toward the eye, never seen edge on: its face between up
## and the camera.
func _face_disk() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var to := cam.global_position - global_position
	if to.length_squared() < 0.0001:
		return
	var n := (to.normalized() * 0.55 + Vector3.UP).normalized()
	var x := n.cross(Vector3.FORWARD if absf(n.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	var s := _disk.scale
	_disk.global_basis = Basis(x, n, x.cross(n)).orthonormalized().scaled(s)


func _physics_process(delta: float) -> void:
	if _burst or _age > PULL:
		return
	var grip := clampf(_age / 0.3, 0.0, 1.0)
	for who in _foes():
		if not who.is_multiplayer_authority():
			continue
		if not _inside(who):
			_last.erase(who)
			continue
		var now := who.global_position
		if ShadowGrasp.is_boss(who):
			# held back as if against the wind
			if _last.has(who):
				var was: Vector3 = _last[who]
				var moved := now - was
				moved.y = 0.0
				if moved.length() < 1.0:
					who.global_position = now - moved * (1.0 - BOSS_PACE)
			_last[who] = who.global_position
			continue
		var to := global_position - now
		to.y = 0.0
		var d := to.length()
		if d <= NEAR:
			continue
		var step := to / d * minf(DRAG * grip * delta, d - NEAR)
		var body := who as CharacterBody3D
		if body != null:
			body.move_and_collide(step)
		else:
			who.global_position += step


func _inside(who: Node3D) -> bool:
	var off := who.global_position - global_position
	if absf(who.global_position.y - _ground.y) > 3.5:
		return false
	off.y = 0.0
	return off.length() <= REACH


## The creatures, and the heroes she is hostile to (PvP).
func _foes() -> Array[Node3D]:
	var out: Array[Node3D] = []
	for node in get_tree().get_nodes_in_group(&"enemy"):
		var who := node as Node3D
		if who != null and who.get(&"is_dead") != true:
			out.append(who)
	if caster != null and is_instance_valid(caster) and Player.pvp_mode:
		for node in get_tree().get_nodes_in_group(&"player"):
			if caster.is_hostile_to(node):
				out.append(node as Node3D)
	return out


## It falls in on itself and bursts.
func _explode() -> void:
	_burst = true
	var into := get_parent()
	var at := global_position
	for p in _emitters:
		if is_instance_valid(p):
			p.emitting = false
			p.get_tree().create_timer(p.lifetime + 0.3, false).timeout.connect(p.queue_free)
	if multiplayer.is_server():
		_hurt(at)
	SkillFx.flash(into, at, DarkFx.VOID, 1.2, 0.14, 3.0)
	SkillFx.light(into, at, DarkFx.HOT, 6.0, 14.0, 0.5)
	SkillFx.ring(into, at, Vector3.UP, DarkFx.HOT, 0.3, BLAST * 1.3, 0.35, 0.03, 3.0)
	SkillFx.ring(into, at, (at - _ground + Vector3(0.3, 0.0, 0.2)).normalized(), DarkFx.VOID, 0.3, BLAST, 0.45, 0.02, 2.5)
	var shock := DarkFx.decal(into, _ground, DarkFx.SHOCK, 1.0, Color(DarkFx.VOID, 1.0), 2.5, 0.0)
	var tw := shock.create_tween().set_parallel(true)
	tw.tween_property(shock, "size", Vector3(BLAST * 3.0, 0.9, BLAST * 3.0), 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(shock, "modulate:a", 0.0, 0.45).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(shock.queue_free)
	var crack := DarkFx.decal(into, _ground, DarkFx.CRACK, BLAST * 1.8, Color(DarkFx.VOID, 1.0), 1.4, 0.8)
	var tw2 := crack.create_tween()
	tw2.tween_property(crack, "emission_energy", 0.0, 2.0).set_ease(Tween.EASE_IN)
	tw2.parallel().tween_property(crack, "modulate:a", 0.0, 4.0).set_ease(Tween.EASE_IN)
	tw2.tween_callback(crack.queue_free)
	DarkFx.black_fire(into, at, 0.0, 1.5, {"box": Vector3(0.5, 0.5, 0.5), "rate": 1.6})
	DarkFx.black_fire(into, _ground + Vector3.UP * 0.05, 1.6, 0.9, {"ring": Vector2(0.4, BLAST * 0.7), "rate": 1.4})
	DarkFx.embers(into, at, 50, Vector2(4.0, 10.0), 1.0)
	DarkFx.smoke(into, at, 14, 1.8, 1.8, 2.0, 1.0)
	WindBlast.shake(self, 0.12, 0.3, 26.0)
	if is_instance_valid(_swirl):
		var t3 := _swirl.create_tween()
		t3.tween_property(_swirl, "modulate:a", 0.0, 0.5)
		t3.tween_callback(_swirl.queue_free)
	queue_free()


## The host: what is within `BLAST` takes it, less at the edge, and is
## thrown back.
func _hurt(at: Vector3) -> void:
	for who in _foes():
		var off := who.global_position - at
		off.y = 0.0
		var br: Variant = who.get(&"body_radius")
		var r := float(br) if br != null else 0.4
		var d := maxf(off.length() - r * 0.6, 0.0)
		if d > BLAST or absf(who.global_position.y - _ground.y) > 3.5:
			continue
		var worth := damage * lerpf(1.0, EDGE, clampf(d / BLAST, 0.0, 1.0))
		var away := off.normalized() if off.length_squared() > 0.0001 else Vector3.FORWARD
		if who is Player:
			if who.get("net_dead") != true:
				who.call(&"receive_blow", worth, caster if is_instance_valid(caster) else self,
						0, 2, get_instance_id() % 100000, true)
			continue
		if who.has_method(&"take_hit"):
			who.call(&"take_hit", worth, who.global_position + Vector3.UP * 0.8, away + Vector3.UP * 0.5,
					critical, false, caster, true)
		if who.has_method(&"react"):
			who.call(&"react", &"knock", caster, away * 4.0)


const CORE_SHADER := """
shader_type spatial;
render_mode unshaded, cull_back;
uniform vec4 rim_color : source_color = vec4(0.6, 0.28, 1.0, 1.0);
void fragment() {
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	ALBEDO = rim_color.rgb * rim * 3.0;
}
"""

const LENS_SHADER := """
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, shadows_disabled;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float strength = 0.0;
void fragment() {
	// the light behind bent in toward the middle, most near the hole's edge
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	vec3 centre = (VIEW_MATRIX * vec4(NODE_POSITION_WORLD, 1.0)).xyz;
	vec2 to = centre.xy - VERTEX.xy;
	float k = smoothstep(0.0, 0.7, facing) * strength;
	vec2 uv = SCREEN_UV - vec2(to.x, -to.y) / max(-VERTEX.z, 0.5) * 0.22 * k;
	vec3 behind = textureLod(screen_tex, uv, 0.0).rgb;
	ALBEDO = behind * (1.0 - 0.15 * k);
	ALPHA = clamp(smoothstep(0.0, 0.5, facing) * strength, 0.0, 1.0);
}
"""

const DISK_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never, shadows_disabled;
uniform sampler2D veins : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform vec4 hot : source_color = vec4(0.92, 0.66, 1.0, 1.0);
uniform vec4 cold : source_color = vec4(0.6, 0.28, 1.0, 1.0);
uniform float turn = 0.0;
uniform float fade = 1.0;
void fragment() {
	vec2 p = UV - 0.5;
	float r = length(p) * 2.0;
	float a = atan(p.y, p.x);
	// a thin ring, brightest at its inner edge, gone toward its outer
	float band = smoothstep(0.22, 0.28, r) * (1.0 - smoothstep(0.32, 0.95, r));
	float swirl = texture(veins, vec2(a / 6.2831 * 2.0 + turn * 0.25 - r * 0.6, r * 0.5)).r;
	float s = band * (0.35 + 0.9 * swirl);
	vec3 col = mix(cold.rgb, hot.rgb, smoothstep(0.55, 0.9, swirl) * (1.0 - smoothstep(0.3, 0.7, r)));
	ALBEDO = col * s * 3.2 * fade;
	ALPHA = clamp(s * fade, 0.0, 1.0);
}
"""
