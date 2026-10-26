class_name SpiritSword
extends Node3D

## The skeleton mage's great sword of light ([MageFighter], the user's word
## 2026-10-26, shown in films first): it forms over the mage's head, hilt
## down, as if an unseen giant held it — the hilt first, then the blade
## burning up out of it, runes along it, energy running up it — and moves
## with the staff as the mage swings it (the staff's lean through the clip,
## `LEAN`): back as the staff goes back, then over and down in front onto the
## ground, a long sweep of light behind it, a burst where the tip lands. The
## blow itself is the mage's (host); this is what every peer sees. It goes
## out if the swing is cut short.

## The staff head's lean off straight up through CR_SK_GreatSwordSpell,
## toward the front positive, degrees, every 0.1 s of the clip (measured off
## the clip on the skeleton, 2026-10-26).
const LEAN: Array[float] = [29, 27, 22, 11, -17, -40, -53, -60, -63, -63, -62, -62, -60, -60, -68, -92,
		-123, -145, -160, -160, -145, -113, -77, -13, 61, 73, 73, 74, 74, 75, 75, 75, 75, 75, 75, 76, 76, 71,
		61, 43, 24, 17, 19, 24, 29, 32, 34, 34, 29]
## When it forms and when the tip meets the ground (s of the clip).
const APPEAR := 0.02
const HIT := 2.53
const LENGTH := 7.0
const HEIGHT := 3.4
const AHEAD := 0.3
const BACK_MOST := -115.0

var caster: Node3D
var clip: StringName = &"CR_SK_GreatSwordSpell"

var _pivot: Node3D
var _sword: Node3D
var _bmat: ShaderMaterial
var _amat: ShaderMaterial
var _light: OmniLight3D
var _im: ImmediateMesh
var _hist: Array = []
var _flash: MeshInstance3D
var _flash_mat: StandardMaterial3D
var _burst: OmniLight3D
var _age: float = 0.0
var _last_t: float = 0.0
var _hit_at: float = -1.0
var _gone_at: float = -1.0
var _down: float = 0.0
var _tip_len: float = 0.0
var _first_back: int = 0

const TRAIL_LIFE := 0.16

const BLADE_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform float reveal = 1.0;
uniform float fade = 1.0;
uniform float clock = 0.0;
uniform float aura = 0.0;
float hash(float n) { return fract(sin(n * 91.345) * 47453.21); }
void fragment() {
	float along = UV.y;
	if (along > reveal) { discard; }
	float across = abs(UV.x);
	float fres = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 2.0);
	vec3 deep = vec3(0.32, 0.12, 0.9);
	vec3 violet = vec3(0.62, 0.38, 1.0);
	vec3 hot = vec3(1.0, 0.93, 1.0);
	vec3 rune_c = vec3(0.55, 0.85, 1.0);
	float front = 1.0 - smoothstep(0.0, 0.06, reveal - along);
	if (aura > 0.5) {
		float soft = (1.0 - across) * (0.6 + 0.4 * fres);
		ALBEDO = mix(deep, violet, soft);
		ALPHA = soft * 0.22 * fade + front * 0.4 * fade;
	} else {
		float edge = smoothstep(0.75, 1.0, across);
		float ridge = 1.0 - smoothstep(0.0, 0.1, across);
		float flow = 0.5 + 0.5 * sin(along * 46.0 - clock * 9.0);
		flow *= 0.5 + 0.5 * sin(along * 13.0 + clock * 3.0);
		float cells = 34.0;
		float cell = floor(along * cells);
		float f = fract(along * cells);
		float h = hash(cell);
		float band = step(0.16, across) * (1.0 - step(0.42, across));
		float stroke = step(0.2, f) * (1.0 - step(0.8, f));
		float mark = mix(step(0.45, abs(fract(f * 2.0 + h) - 0.5) * 2.0), stroke * step(0.3, abs(across - 0.29) * 10.0 - h * 0.6), step(0.5, h));
		float rune = band * mark * step(0.25, h) * step(along, 0.82) * step(0.06, along);
		float pulse = 0.65 + 0.35 * sin(clock * 6.0 + cell * 0.7);
		vec3 c = mix(deep, violet, 0.5 + 0.5 * flow);
		c = mix(c, hot, max(edge, ridge));
		c = mix(c, rune_c, rune * pulse);
		c += hot * front;
		ALBEDO = c;
		float a = 0.35 + 0.25 * flow + 0.6 * edge + 0.7 * ridge + 0.8 * rune * pulse + fres * 0.4;
		ALPHA = clamp(a, 0.0, 1.0) * fade + front;
	}
}
"""

const TRAIL_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
void fragment() {
	float age = clamp(UV.x, 0.0, 1.0);
	float r = clamp(UV.y, 0.0, 1.0);
	float life = (1.0 - age) * (1.0 - age);
	float edge = smoothstep(0.0, 0.85, r) * (1.0 - smoothstep(0.93, 1.0, r) * 0.6);
	ALBEDO = mix(vec3(0.45, 0.22, 1.0), vec3(1.0, 0.92, 1.0), pow(r, 3.0) * (1.0 - age));
	ALPHA = life * edge * 0.85;
}
"""


static func raise(into: Node, by: Node3D, clip_name: StringName) -> SpiritSword:
	if into == null or by == null:
		return null
	var s := SpiritSword.new()
	s.caster = by
	s.clip = clip_name
	into.add_child(s)
	return s


func _ready() -> void:
	top_level = true
	_tip_len = 0.6 + LENGTH
	_down = PI - acos(clampf(HEIGHT / _tip_len, -1.0, 1.0))
	while _first_back < LEAN.size() and LEAN[_first_back] >= 0.0:
		_first_back += 1
	_pivot = Node3D.new()
	add_child(_pivot)
	_sword = Node3D.new()
	_pivot.add_child(_sword)
	var turn := Node3D.new()
	# edge first into the cut: the flat faces the sides
	turn.rotation.y = PI * 0.5
	_sword.add_child(turn)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = Color(0.55, 0.35, 1.0, 0.7)
	var core := mat.duplicate() as StandardMaterial3D
	core.albedo_color = Color(1.0, 0.95, 1.0, 0.95)
	var sh := Shader.new()
	sh.code = BLADE_SHADER
	_bmat = ShaderMaterial.new()
	_bmat.shader = sh
	_amat = ShaderMaterial.new()
	_amat.shader = sh
	_amat.set_shader_parameter("aura", 1.0)
	var add := func(mesh: Mesh, m2: Material, pos: Vector3, rot: Vector3 = Vector3.ZERO, sc: Vector3 = Vector3.ONE) -> void:
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = m2
		mi.position = pos
		mi.rotation = rot
		mi.scale = sc
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		turn.add_child(mi)
	add.call(blade_mesh(LENGTH, 0.5, 0.08), _bmat, Vector3(0, 0.6, 0))
	add.call(blade_mesh(LENGTH * 1.02, 0.72, 0.2), _amat, Vector3(0, 0.5, 0))
	# the guard: wings sweeping up and out, a stone at the heart
	for side: float in [-1.0, 1.0]:
		var prev := Vector3(0, 0.55, 0)
		for k in 6:
			var u := float(k + 1) / 6.0
			var p := Vector3(side * (0.16 + 0.62 * u), 0.55 + 0.32 * u * u, 0)
			var d := p - prev
			var bm := BoxMesh.new()
			var thick := 0.16 * (1.0 - u * 0.6)
			bm.size = Vector3(d.length() + 0.04, thick, thick * 0.9)
			add.call(bm, mat, (prev + p) * 0.5, Vector3(0, 0, atan2(d.y, d.x)))
			prev = p
		var tipg := SphereMesh.new()
		tipg.radius = 0.07
		tipg.height = 0.14
		add.call(tipg, core, prev)
	var gem := SphereMesh.new()
	gem.radius = 0.15
	gem.height = 0.3
	add.call(gem, core, Vector3(0, 0.56, 0), Vector3.ZERO, Vector3(1, 1.3, 0.7))
	var grip := CylinderMesh.new()
	grip.top_radius = 0.07
	grip.bottom_radius = 0.08
	grip.height = 0.6
	add.call(grip, mat, Vector3(0, 0.22, 0))
	var ring := TorusMesh.new()
	ring.inner_radius = 0.07
	ring.outer_radius = 0.17
	add.call(ring, mat, Vector3(0, -0.15, 0), Vector3(PI * 0.5, 0, 0))
	var pom := SphereMesh.new()
	pom.radius = 0.07
	pom.height = 0.14
	add.call(pom, core, Vector3(0, -0.15, 0))
	_light = OmniLight3D.new()
	_light.light_color = Color(0.7, 0.5, 1.0)
	_light.omni_range = 7.0
	_light.position = Vector3(0, LENGTH * 0.5, 0)
	_sword.add_child(_light)
	var trail := MeshInstance3D.new()
	_im = ImmediateMesh.new()
	trail.mesh = _im
	var tsh := Shader.new()
	tsh.code = TRAIL_SHADER
	var tm := ShaderMaterial.new()
	tm.shader = tsh
	trail.material_override = tm
	trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(trail)
	_flash = MeshInstance3D.new()
	_flash.mesh = SphereMesh.new()
	_flash_mat = mat.duplicate() as StandardMaterial3D
	_flash.material_override = _flash_mat
	_flash.visible = false
	add_child(_flash)
	_burst = OmniLight3D.new()
	_burst.light_color = Color(0.75, 0.55, 1.0)
	_burst.omni_range = 9.0
	_burst.light_energy = 0.0
	add_child(_burst)
	_place(0.0)
	_pivot.visible = false


## Where it hangs over the caster, and the caster's front and side.
func _frame() -> Array:
	var fwd := Vector3.FORWARD
	if caster.has_method(&"_forward"):
		fwd = caster.call(&"_forward") as Vector3
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length_squared() > 0.0001 else Vector3.FORWARD
	return [caster.global_position + Vector3.UP * HEIGHT + fwd * AHEAD, fwd]


func _angle(t: float) -> float:
	var hi := clampi(int(HIT / 0.1), 0, LEAN.size() - 1)
	var x := clampf(t / 0.1, 0.0, float(hi))
	var i := int(x)
	var v := lerpf(LEAN[i], LEAN[mini(i + 1, hi)], x - i)
	var ang := 0.0
	if i < _first_back:
		ang = 0.0
	elif v > 0.0:
		ang = deg_to_rad(v) * _down / maxf(deg_to_rad(LEAN[hi]), 0.3)
	else:
		ang = deg_to_rad(v)
	return clampf(ang, deg_to_rad(BACK_MOST), _down)


func _place(ang: float) -> void:
	var fr := _frame()
	var fwd: Vector3 = fr[1]
	var axis := Vector3.UP.cross(fwd).normalized()
	var face := Basis(Vector3.UP, atan2(fwd.x, fwd.z))
	_pivot.global_transform = Transform3D(Basis(axis, ang) * face, fr[0])


func _process(delta: float) -> void:
	_age += delta
	var alive := is_instance_valid(caster) and not bool(caster.get("is_dead"))
	var t := _last_t
	if alive and _gone_at < 0.0:
		var anim: Variant = caster.get("_anim")
		if anim != null and StringName(anim.call(&"current_clip")) == clip:
			t = float(anim.call(&"clip_position"))
		elif _hit_at < 0.0:
			_gone_at = _age
	elif _gone_at < 0.0:
		_gone_at = _age
	_last_t = maxf(t, _last_t)
	t = _last_t
	if _hit_at >= 0.0 and _gone_at < 0.0 and _age - _hit_at > 0.4:
		_gone_at = _age
	var g := clampf((t - APPEAR) / 0.4, 0.0, 1.0)
	var gone := clampf((_age - _gone_at) / 0.45, 0.0, 1.0) if _gone_at >= 0.0 else 0.0
	_pivot.visible = g > 0.0 and gone < 1.0
	var grow := 1.0 - pow(1.0 - clampf(g * 2.0, 0.0, 1.0), 3.0)
	_sword.scale = Vector3.ONE * maxf(grow, 0.01)
	var rv := clampf((t - APPEAR - 0.15) / 0.55, 0.0, 1.0)
	rv = 1.0 - pow(1.0 - rv, 2.0)
	for m: ShaderMaterial in [_bmat, _amat]:
		m.set_shader_parameter("reveal", rv)
		m.set_shader_parameter("fade", 1.0 - gone)
	_bmat.set_shader_parameter("clock", _age)
	var ang := _angle(t)
	if alive:
		_place(ang)
	_light.light_energy = 2.0 * grow * (1.0 - gone)
	# the sweep behind it: an arc drawn from its last angles, fine-stepped
	if _pivot.visible and _hit_at < 0.0:
		_hist.push_front([_age, ang, grow])
	while _hist.size() > 0 and _age - float(_hist[-1][0]) > TRAIL_LIFE:
		_hist.pop_back()
	_im.clear_surfaces()
	if _hist.size() >= 2:
		var fr := _frame()
		var fwd: Vector3 = fr[1]
		var axis := Vector3.UP.cross(fwd).normalized()
		var r_in := 0.6 + LENGTH * 0.3
		_im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
		for k in _hist.size() - 1:
			var h0: Array = _hist[k]
			var h1: Array = _hist[k + 1]
			var steps := maxi(int(absf(float(h1[1]) - float(h0[1])) / deg_to_rad(1.5)), 1)
			for q in steps:
				var f := float(q) / steps
				var aa := lerpf(float(h0[1]), float(h1[1]), f)
				var age := (_age - lerpf(float(h0[0]), float(h1[0]), f)) / TRAIL_LIFE
				var sz := lerpf(float(h0[2]), float(h1[2]), f)
				var up := Basis(axis, aa) * Vector3.UP
				_im.surface_set_uv(Vector2(age, 0.0))
				_im.surface_add_vertex(fr[0] + up * r_in * sz)
				_im.surface_set_uv(Vector2(age, 1.0))
				_im.surface_add_vertex(fr[0] + up * _tip_len * sz)
		_im.surface_end()
	if t >= HIT and _hit_at < 0.0 and _gone_at < 0.0:
		_hit_at = _age
		var tip := _pivot.global_transform * Vector3(0, _tip_len, 0)
		_flash.global_position = Vector3(tip.x, caster.global_position.y + 0.1, tip.z)
		_burst.global_position = _flash.global_position + Vector3.UP
	if _hit_at >= 0.0:
		var u := clampf((_age - _hit_at) / 0.55, 0.0, 1.0)
		_flash.visible = u < 1.0
		_flash.scale = Vector3(1.0, 0.45, 1.0) * (0.2 + u * 1.3)
		_flash_mat.albedo_color = Color(0.85, 0.7, 1.0, 0.75 * (1.0 - u) * (1.0 - u))
		_burst.light_energy = 8.0 * (1.0 - u)
	if _gone_at >= 0.0 and _age - _gone_at > 0.7:
		queue_free()


## Where the blade lies at the blow, along the ground ahead of the caster:
## [from, to] of the stretch of it low enough to strike a man (m ahead).
static func strike_span() -> Vector2:
	var tip_len := 0.6 + LENGTH
	var reach := sqrt(maxf(tip_len * tip_len - HEIGHT * HEIGHT, 0.0))
	var low_from := (HEIGHT - 1.9) / HEIGHT
	return Vector2(AHEAD + reach * low_from, AHEAD + reach + 0.3)


## A long blade along +Y from y=0: six-sided, a ridge down it, a leaf-shaped
## point; UV x across (-1..1), y along (0..1).
static func blade_mesh(length: float, w0: float, t0: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array = []
	var n := 28
	var across := [1.0, 0.3, -0.3, -1.0, -0.3, 0.3]
	for k in n + 1:
		var u := float(k) / n
		var w := w0 * (1.0 + 0.12 * sin(u * PI * 0.9) - 0.3 * u)
		if u > 0.7:
			var v := (u - 0.7) / 0.3
			w *= sqrt(maxf(1.0 - v * v, 0.0)) * (1.0 - v * 0.3)
		w = maxf(w, 0.002)
		var t := t0 * (w / w0)
		var y := length * u
		var ring: Array = []
		for sd in 6:
			var ax: float = across[sd]
			var z := 0.0 if absf(ax) > 0.9 else (t if sd < 3 else -t)
			ring.append([Vector3(w * ax, y, z), Vector2(ax, u)])
		rings.append(ring)
	for k in n:
		for sd in 6:
			var a0: Array = rings[k][sd]
			var a1: Array = rings[k][(sd + 1) % 6]
			var b0: Array = rings[k + 1][sd]
			var b1: Array = rings[k + 1][(sd + 1) % 6]
			for v: Array in [a0, b0, a1, a1, b0, b1]:
				st.set_uv(v[1])
				st.add_vertex(v[0])
	st.generate_normals()
	return st.commit()
