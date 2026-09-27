class_name ImpactFx
extends RefCounted

## What says a blade went *in*, besides the blood: a streak of light at the
## point it bit, laid along the way it was going; the view knocked a few
## centimetres the same way; and a wet, heavy sound under the ring of the steel.

## The streak: how long it is (metres, before the creature's size), how long it
## lasts, and its colours — a hot white core in a red edge.
const SLASH_LENGTH := 0.95
const SLASH_LIFE := 0.16
const CORE := Color(1.0, 0.93, 0.86)
const EDGE := Color(0.85, 0.08, 0.04)

const SLASH_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 core : source_color;
uniform vec4 edge : source_color;
uniform float fade = 1.0;
uniform float sweep = 1.0;
void fragment() {
	// UV.x along the cut (0 behind, 1 at the leading end), UV.y across it.
	float across = abs(UV.y - 0.5) * 2.0;
	// Thin at both ends, thickest a little ahead of the middle.
	float body = pow(sin(clamp(UV.x, 0.0, 1.0) * 3.14159), 0.7);
	float width = mix(0.08, 1.0, body);
	float line = 1.0 - smoothstep(0.0, width, across);
	float hot = 1.0 - smoothstep(0.0, width * 0.28, across);
	// Drawn on from behind as `sweep` goes 0 -> 1.
	float drawn = 1.0 - smoothstep(sweep - 0.12, sweep, UV.x);
	vec3 c = mix(edge.rgb, core.rgb, hot);
	float a = line * drawn * fade;
	ALBEDO = c * 2.2;
	ALPHA = a;
}
"""

static var _slash_shader: Shader
static var _slash_mesh: QuadMesh
static var _thud: AudioStreamWAV


## Builds the shader, the mesh and the sound now rather than on the first blow.
static func warm() -> void:
	if _slash_shader == null:
		_slash_shader = Shader.new()
		_slash_shader.code = SLASH_SHADER
		_slash_mesh = QuadMesh.new()
		_slash_mesh.size = Vector2.ONE
	if _thud == null:
		_thud = _make_thud()


## A streak of light at `at` along `along`, turned to face the view, drawn on
## fast from behind and gone in `SLASH_LIFE`. `size`: the creature against a man.
static func slash(into: Node, at: Vector3, along: Vector3, size: float = 1.0, hard: bool = false) -> void:
	if into == null or not into.is_inside_tree():
		return
	warm()
	var cam := into.get_viewport().get_camera_3d() if into.get_viewport() != null else null
	var dir := along.normalized() if along.length_squared() > 0.0001 else Vector3.RIGHT
	var to_eye := (cam.global_position - at).normalized() if cam != null else Vector3.BACK
	# Across the cut, in the plane facing the eye.
	var across := to_eye.cross(dir)
	if across.length_squared() < 0.0001:
		across = Vector3.UP.cross(dir)
	across = across.normalized()
	var facing := dir.cross(across).normalized()
	var node := MeshInstance3D.new()
	node.mesh = _slash_mesh
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := ShaderMaterial.new()
	mat.shader = _slash_shader
	mat.set_shader_parameter("core", CORE)
	mat.set_shader_parameter("edge", EDGE)
	mat.set_shader_parameter("fade", 1.0)
	mat.set_shader_parameter("sweep", 0.0)
	node.material_override = mat
	into.add_child(node)
	var length := SLASH_LENGTH * size * (1.3 if hard else 1.0)
	var width := 0.07 * size * (1.4 if hard else 1.0)
	# A little ahead of the point it bit: the streak is where the edge went on to.
	node.global_transform = Transform3D(Basis(dir * length, across * width, facing),
			at + dir * length * 0.12 + to_eye * 0.12)
	var tw := node.create_tween()
	tw.tween_method(func(v: float) -> void: mat.set_shader_parameter("sweep", v), 0.0, 1.12, SLASH_LIFE * 0.35)
	tw.parallel().tween_method(func(v: float) -> void: mat.set_shader_parameter("fade", v), 1.0, 0.0, SLASH_LIFE) \
			.set_delay(SLASH_LIFE * 0.2).set_ease(Tween.EASE_IN)
	tw.tween_callback(node.queue_free)


## The view knocked `amount` metres along `along` as seen on the screen, and
## eased back: the weight of the blow felt in the hands.
static func nudge(cam: Camera3D, along: Vector3, amount: float = 0.035) -> void:
	if cam == null or not cam.is_inside_tree():
		return
	var right := cam.global_basis.x
	var up := cam.global_basis.y
	var h := along.dot(right)
	var v := along.dot(up)
	var flat := Vector2(h, v)
	if flat.length_squared() < 0.0001:
		flat = Vector2(0.0, -1.0)
	flat = flat.normalized() * amount
	var old: Variant = cam.get_meta(&"nudge") if cam.has_meta(&"nudge") else null
	if old is Tween and (old as Tween).is_valid():
		(old as Tween).kill()
	var tw := cam.create_tween()
	tw.tween_property(cam, "h_offset", flat.x, 0.035).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(cam, "v_offset", flat.y, 0.035).set_ease(Tween.EASE_OUT)
	tw.tween_property(cam, "h_offset", 0.0, 0.16).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(cam, "v_offset", 0.0, 0.16).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	cam.set_meta(&"nudge", tw)


## The blade going into flesh, heard: a short deep thump with a wet tear over it.
static func thud(owner: Node, at: Vector3, hard: bool = false) -> void:
	if owner == null or not owner.is_inside_tree():
		return
	warm()
	var player := AudioStreamPlayer3D.new()
	player.stream = _thud
	player.volume_db = -5.0 if hard else -8.0
	player.pitch_scale = randf_range(0.82, 0.92) if hard else randf_range(0.95, 1.08)
	player.unit_size = 7.0
	player.max_distance = 55.0
	var world: Node = owner.get_tree().current_scene if owner.get_tree().current_scene != null else owner.get_tree().root
	world.add_child(player)
	player.global_position = at
	player.finished.connect(player.queue_free)
	player.play()


static func _make_thud() -> AudioStreamWAV:
	var rate := 22050
	var count := int(rate * 0.34)
	var data := PackedByteArray()
	data.resize(count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 808
	var phase := 0.0
	var low := 0.0
	var band := 0.0
	var band2 := 0.0
	for i in count:
		var t := float(i) / float(rate)
		# The thump: a sine falling from 150 to 48 Hz, gone in a quarter second.
		var f := 48.0 + 102.0 * exp(-t * 22.0)
		phase += TAU * f / float(rate)
		var body := sin(phase) * exp(-t * 16.0) * minf(t * 900.0, 1.0)
		# The tear: noise, band-limited to somewhere round 1-2 kHz, very short.
		var n := rng.randf_range(-1.0, 1.0)
		low += (n - low) * 0.35
		band += (low - band) * 0.12
		var tear := (low - band) * exp(-t * 55.0) * 1.8
		# A second, duller wet slap a moment later.
		band2 += (n - band2) * 0.06
		var slap := band2 * exp(-maxf(t - 0.025, 0.0) * 40.0) * (1.0 if t > 0.025 else 0.0) * 1.4
		var s := clampf(body * 0.9 + tear + slap, -1.0, 1.0)
		data.encode_s16(i * 2, int(s * 30000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	return wav
