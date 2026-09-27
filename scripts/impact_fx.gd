class_name ImpactFx
extends RefCounted

## What says a blade went *in*, besides the blood (the gush out of the wound is
## [Blood]'s): the view knocked a few centimetres the way the blade was going,
## and a wet, heavy sound under the ring of the steel.

static var _thud: AudioStreamWAV


## Builds the sound now rather than on the first blow.
static func warm() -> void:
	if _thud == null:
		_thud = _make_thud()


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
