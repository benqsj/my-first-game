class_name VillageFire
extends Node3D

## What the dragon left of the village, and how it comes back.
##
## Six of the twelve buildings burn ([const BURNT]): their walls go black
## (a multiplying overlay of soot, thicker up under the roof, in patches),
## fire stands on their roofs, embers go up and a column of smoke climbs high
## enough to be seen from the meadows to the south — the way to the village.
## [method ignite] sets one alight (the dragon's fireball does it in the
## film), [method burn_all] the lot at once (a skipped film).
##
## A while after the hero has come (see [method smoulder]) the flames die
## down to a glow and thin smoke. Each burnt building belongs to one of the
## jobs in the [QuestBook]: when that job is rewarded its buildings are put
## back — the soot washes off, the fire and smoke go — and [signal restored]
## names them.

signal restored(kinds: Array[StringName], job: StringName)

## Burnt building -> the job whose reward rebuilds it.
const BURNT := {
	&"House6": &"wolves", &"House7": &"wolves",
	&"House2": &"imps", &"House3": &"imps",
	&"Marani": &"arkdeva", &"House8": &"arkdeva",
}
## Georgian names for what is rebuilt.
const NAMES := {
	&"House2": "სახლი", &"House3": "სახლი", &"House6": "სახლი", &"House7": "სახლი",
	&"House8": "სახლი", &"Marani": "მარანი",
}

const SOOT_CODE := """
shader_type spatial;
render_mode blend_mul, unshaded, cull_back, depth_draw_never, shadows_disabled, fog_disabled;
uniform float soot : hint_range(0.0, 1.0) = 0.0;
uniform float base_y = 0.0;
uniform float top_y = 8.0;
varying vec3 wpos;
float hash(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }
float noise(vec3 p) {
	vec3 i = floor(p); vec3 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1,0,0)), f.x), mix(hash(i + vec3(0,1,0)), hash(i + vec3(1,1,0)), f.x), f.y),
		mix(mix(hash(i + vec3(0,0,1)), hash(i + vec3(1,0,1)), f.x), mix(hash(i + vec3(0,1,1)), hash(i + vec3(1,1,1)), f.x), f.y), f.z);
}
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float up = clamp((wpos.y - base_y) / max(top_y - base_y, 0.1), 0.0, 1.0);
	float n = noise(wpos * 0.55) * 0.6 + noise(wpos * 2.1) * 0.4;
	float s = clamp(soot * (0.2 + up * 0.85 + (n - 0.5) * 1.5), 0.0, 1.0);
	ALBEDO = mix(vec3(1.0), vec3(0.09, 0.075, 0.065), s);
}
"""

static var _soot_shader: Shader

## kind -> {"mesh": MeshInstance3D, "mat": ShaderMaterial, "fx": [GPUParticles3D],
## "smoke": GPUParticles3D, "lights": [OmniLight3D], "heat": float, "want": float, "job": StringName}
var _burning: Dictionary = {}
var _book: QuestBook
var _clock: float = 0.0
var _smouldering: bool = false


## Finds the buildings under `houses` ([VillageHouses]) and makes them ready
## to burn; nothing burns yet.
func dress(houses: Node3D) -> void:
	if _soot_shader == null:
		_soot_shader = Shader.new()
		_soot_shader.code = SOOT_CODE
	for kind: StringName in BURNT:
		var mesh := houses.get_node_or_null(NodePath(String(kind))) as MeshInstance3D
		if mesh == null or mesh.mesh == null:
			continue
		var box := mesh.global_transform * mesh.mesh.get_aabb()
		var mat := ShaderMaterial.new()
		mat.shader = _soot_shader
		mat.set_shader_parameter(&"soot", 0.0)
		mat.set_shader_parameter(&"base_y", box.position.y)
		mat.set_shader_parameter(&"top_y", box.end.y)
		_burning[kind] = {"mesh": mesh, "mat": mat, "box": box, "fx": [], "lights": [],
				"heat": 0.0, "want": 0.0, "job": BURNT[kind], "lit": false}


## Sets `kind` alight; the fire grows over `seconds`.
func ignite(kind: StringName, seconds: float = 3.0) -> void:
	var b: Dictionary = _burning.get(kind, {})
	if b.is_empty() or b["lit"]:
		return
	b["lit"] = true
	b["want"] = 1.0
	b["rate"] = 1.0 / maxf(seconds, 0.01)
	(b["mesh"] as MeshInstance3D).material_overlay = b["mat"]
	_light_up(b)


## Every burnt building alight at once, at full heat.
func burn_all() -> void:
	for kind: StringName in _burning:
		ignite(kind, 0.01)
		var b: Dictionary = _burning[kind]
		b["heat"] = 1.0
		_apply(b)
		# The smoke already up in its column, not only starting.
		for p: GPUParticles3D in b["fx"]:
			if p.get_meta(&"smoke", false):
				p.preprocess = 12.0
				p.restart()


## The nearest burnt building to `at` that is not alight yet (or &"").
func nearest_unlit(at: Vector3) -> StringName:
	var best := &""
	var best_d := INF
	for kind: StringName in _burning:
		var b: Dictionary = _burning[kind]
		if b["lit"]:
			continue
		var d := ((b["box"] as AABB).get_center() - at).length()
		if d < best_d:
			best_d = d
			best = kind
	return best


## Where to throw fire to set `kind` alight: on its roof.
func roof_of(kind: StringName) -> Vector3:
	var b: Dictionary = _burning.get(kind, {})
	if b.is_empty():
		return Vector3.ZERO
	var box: AABB = b["box"]
	return Vector3(box.get_center().x, box.end.y - 1.0, box.get_center().z)


## The middle of the burning, high up: where the smoke is seen from afar.
func smoke_point() -> Vector3:
	var sum := Vector3.ZERO
	for kind: StringName in _burning:
		sum += (_burning[kind]["box"] as AABB).get_center()
	return sum / maxf(_burning.size(), 1.0)


func kinds() -> Array[StringName]:
	var out: Array[StringName] = []
	out.assign(_burning.keys())
	return out


## The flames die down to a glow; the smoke thins.
func smoulder() -> void:
	_smouldering = true
	for kind: StringName in _burning:
		var b: Dictionary = _burning[kind]
		if b["lit"] and float(b["want"]) > 0.4:
			b["want"] = 0.4
			b["rate"] = 1.0 / 20.0


## Puts the buildings of `job` back as they were.
func restore_job(job: StringName) -> void:
	var done: Array[StringName] = []
	for kind: StringName in _burning:
		var b: Dictionary = _burning[kind]
		if b["job"] == job and b["lit"]:
			b["want"] = 0.0
			b["rate"] = 1.0 / 2.5
			b["lit"] = false
			done.append(kind)
	if not done.is_empty():
		restored.emit(done, job)


func is_burnt(kind: StringName) -> bool:
	return _burning.has(kind) and bool(_burning[kind]["lit"])


func _process(delta: float) -> void:
	_clock += delta
	if _book == null:
		_book = get_tree().get_first_node_in_group(&"quest_book") as QuestBook
		if _book != null:
			_book.changed.connect(_on_book)
	for kind: StringName in _burning:
		var b: Dictionary = _burning[kind]
		var heat: float = b["heat"]
		var want: float = b["want"]
		if heat != want:
			heat = move_toward(heat, want, float(b.get("rate", 0.5)) * delta)
			b["heat"] = heat
			_apply(b)
		if heat > 0.0:
			var i := 0
			for light: OmniLight3D in b["lights"]:
				light.light_energy = heat * (3.2 + 0.8 * sin(_clock * (11.0 + i) + i) + 0.5 * sin(_clock * 6.3 + i * 2.0))
				i += 1


func _on_book() -> void:
	if _book == null:
		return
	for job: StringName in [&"wolves", &"imps", &"arkdeva"]:
		if int(_book.state.get(job, QuestBook.State.OFFERED)) == QuestBook.State.REWARDED:
			restore_job(job)


func _apply(b: Dictionary) -> void:
	var heat: float = b["heat"]
	var flame := clampf(heat, 0.0, 1.0)
	# Black within the first moments of the fire, and black while it smoulders;
	# washed off as it is rebuilt.
	var soot := clampf(heat * 3.0, 0.0, 1.0) if b["lit"] else heat
	(b["mat"] as ShaderMaterial).set_shader_parameter(&"soot", soot)
	for p: GPUParticles3D in b["fx"]:
		var full: float = p.get_meta(&"full", 1.0)
		var smoke: bool = p.get_meta(&"smoke", false)
		# Smoke keeps going while there is anything left burning.
		var k := clampf(heat * 2.5, 0.0, 1.0) if smoke else clampf((flame - 0.2) / 0.8, 0.0, 1.0)
		p.amount_ratio = k * full
		p.emitting = k > 0.01
	if heat <= 0.0 and not b["lit"]:
		var mesh := b["mesh"] as MeshInstance3D
		if mesh.material_overlay == b["mat"]:
			mesh.material_overlay = null
		for light: OmniLight3D in b["lights"]:
			light.light_energy = 0.0


## The fire, embers, smoke and light on one building (once).
func _light_up(b: Dictionary) -> void:
	if not (b["fx"] as Array).is_empty():
		return
	var box: AABB = b["box"]
	var mid := box.get_center()
	var half := Vector2(box.size.x, box.size.z) * 0.5
	var roof := box.end.y - box.size.y * 0.28
	var spots: Array[Vector3] = [
		Vector3(mid.x, roof, mid.z),
		Vector3(mid.x + half.x * 0.45, roof - 0.6, mid.z - half.y * 0.35),
		Vector3(mid.x - half.x * 0.4, roof - 0.9, mid.z + half.y * 0.4),
	]
	var fx: Array = b["fx"]
	for i in spots.size():
		var at := spots[i]
		var big := 1.0 - i * 0.2
		var flames := SkillFx.particles(self, at, {
			"amount": int(70 * big), "life": 1.1, "speed": Vector2(0.8, 2.2), "spread": 12.0,
			"gravity": Vector3(0.3, 2.6, 0), "size": Vector2(1.2, 2.6), "box": Vector3(half.x * 0.35, 0.4, half.y * 0.35),
			"tex": SkillFx.flame(), "quad": Vector2(0.6, 1.0), "add": false, "grow": 0.3,
			"colors": [Color(1.0, 0.62, 0.18, 0.0), Color(1.0, 0.52, 0.1, 0.95), Color(0.95, 0.22, 0.03, 0.85),
					Color(0.25, 0.03, 0.0, 0.0)],
		})
		fx.append(flames)
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.5, 0.16)
		light.omni_range = 16.0
		light.light_energy = 0.0
		light.shadow_enabled = false
		add_child(light)
		light.global_position = at + Vector3.UP * 0.8
		(b["lights"] as Array).append(light)
	var embers := SkillFx.particles(self, Vector3(mid.x, roof + 1.0, mid.z), {
		"amount": 60, "life": 3.0, "speed": Vector2(1.5, 4.0), "spread": 25.0,
		"gravity": Vector3(0.6, 0.8, 0), "damping": 0.3, "size": Vector2(0.05, 0.12),
		"box": Vector3(half.x * 0.5, 0.5, half.y * 0.5),
		"colors": [Color(1.0, 0.85, 0.4, 1.0), Color(1.0, 0.35, 0.05, 1.0), Color(0.6, 0.1, 0.0, 0.0)],
	})
	fx.append(embers)
	# The column: dark, big, slow, carried a little east by the wind, and high
	# enough to stand over the trees from the meadows.
	var smoke := SkillFx.particles(self, Vector3(mid.x, roof + 2.0, mid.z), {
		"amount": 80, "life": 13.0, "speed": Vector2(3.4, 5.0), "spread": 8.0,
		"gravity": Vector3(0.55, 0.3, 0.12), "damping": 0.05, "size": Vector2(5.0, 9.5),
		"box": Vector3(half.x * 0.3, 0.5, half.y * 0.3), "add": false, "grow": 0.12, "spin": true,
		# Dark at once over the roof (a fire's smoke), greying and thinning as it climbs.
		"colors": [Color(0.05, 0.045, 0.04, 0.3), Color(0.07, 0.06, 0.055, 0.88), Color(0.1, 0.09, 0.085, 0.8),
				Color(0.16, 0.15, 0.14, 0.62), Color(0.24, 0.23, 0.22, 0.42), Color(0.3, 0.3, 0.3, 0.2),
				Color(0.36, 0.36, 0.36, 0.0)],
	})
	smoke.set_meta(&"smoke", true)
	smoke.visibility_aabb = AABB(Vector3(-60, -10, -60), Vector3(120, 110, 120))
	smoke.preprocess = 0.0
	fx.append(smoke)
	for p: GPUParticles3D in fx:
		p.amount_ratio = 0.0
		p.emitting = false
