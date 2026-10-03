class_name ImpactFx
extends RefCounted

## What says a blade went *in*, besides the blood (the gush out of the wound is
## [Blood]'s): the view knocked a few centimetres the way the blade was going,
## and a wet, heavy sound under the ring of the steel.

static var _thud: AudioStreamWAV
## The other things a blade can meet, made the same way (see [method strike]).
static var _made: Dictionary = {}
## The rush of air under a heavy swing (see [method rush]): made of noise only.
static var _rush: Dictionary = {}


## The rush of air under a string's last swing, or (`deep`) a heavy blow's:
## noise swelling and dying, its colour sweeping down, with no tone in it (the
## recorded rushes, `tariel/air_*`, hum: the user heard bells, 2026-10-04).
## Played on `on` (the sword's mount), so it goes with the blade.
static func rush(owner: Node, on: Node3D, deep: bool, volume_db: float) -> void:
	if owner == null or on == null or not on.is_inside_tree():
		return
	if not _rush.has(deep):
		_rush[deep] = _make_rush(deep)
	var player := AudioStreamPlayer3D.new()
	player.stream = _rush[deep]
	player.volume_db = volume_db
	player.pitch_scale = randf_range(0.93, 1.07)
	player.unit_size = 6.0
	player.max_distance = 60.0
	on.add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


static func _make_rush(deep: bool) -> AudioStreamWAV:
	var rate := 22050
	var long := 0.42 if deep else 0.3
	var count := int(rate * long)
	var data := PackedByteArray()
	data.resize(count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242 if deep else 2424
	var lp := 0.0
	var lp2 := 0.0
	var hp := 0.0
	for i in count:
		var t := float(i) / float(rate)
		var k := t / long
		# swelling to its loudest a fifth of the way in, then dying
		var env := smoothstep(0.0, 0.2, k) * pow(1.0 - k, 1.6)
		# the colour: from bright to dull as the blade passes
		var bright := lerpf(0.32, 0.06, k) * (0.55 if deep else 1.0)
		var n := rng.randf_range(-1.0, 1.0)
		lp += (n - lp) * bright
		lp2 += (lp - lp2) * bright
		hp += (lp2 - hp) * 0.02  # a little low cut, no rumble
		var s := (lp2 - hp) * env * (3.2 if deep else 2.6)
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 30000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	return wav


## A blade caught on a guard: the recording of a blow on a shield (the one the
## hero's block plays, `Player.BLOCK_SOUND`), the made thunk under it.
const GUARD_BLOCK := "res://unverified/sounds/all/block_1.wav"


## Builds the sound now rather than on the first blow.
static func warm() -> void:
	Sfx.warm([GUARD_BLOCK])
	if _thud == null:
		_thud = _make_thud()
	for what: StringName in [&"bone", &"stone", &"wood", &"guard"]:
		if not _made.has(what):
			_made[what] = _make(what)


## What `node` is made of, as a blade hears it: &"flesh", &"bone" (the
## skeletons), &"stone" (a golem, a wall, a rock) or &"wood" (a trunk, a
## fence, the pier). Its own (or a parent's) meta "matter" says so if set;
## otherwise its scene or name does.
static func matter_of(node: Node) -> StringName:
	var at := node
	var depth := 0
	while at != null and depth < 4:
		if at.has_meta(&"matter"):
			return StringName(at.get_meta(&"matter"))
		var said := (at.scene_file_path + " " + String(at.name)).to_lower()
		for word: String in ["skeleton", "bone", "skull"]:
			if word in said:
				return &"bone"
		for word: String in ["golem", "stone", "rock", "wall"]:
			if word in said:
				return &"stone"
		for word: String in ["trunk", "tree", "wood", "fence", "pier", "plank", "log", "crate", "barrel"]:
			if word in said:
				return &"wood"
		if at is CharacterBody3D:
			return &"flesh"
		at = at.get_parent()
		depth += 1
	return &"stone" if node is StaticBody3D else &"flesh"


## A blade meeting `what` (see [method matter_of]; &"guard" for a blade caught
## on a guard or shield), heard at `at`: bone cracking, stone crunching, a
## dull knock in wood, a blow on a shield. `heft` (a blow's weight, 1 a
## plain cut) makes it louder and deeper. Flesh is [method thud]'s.
static func strike(owner: Node, at: Vector3, what: StringName, heft: float = 1.0) -> void:
	if owner == null or not owner.is_inside_tree():
		return
	if what == &"flesh":
		thud(owner, at, heft >= 1.45)
		return
	warm()
	var stream: AudioStreamWAV = _made.get(what, null)
	if stream == null:
		return
	if what == &"guard":
		# the block the hero's own shield makes, over the thunk
		Sfx.play(owner, GUARD_BLOCK, null, at, randf_range(0.9, 1.05) * (1.0 - 0.1 * clampf(heft - 1.0, 0.0, 1.0)),
				-13.0 + 2.0 * clampf(heft - 1.0, -0.4, 1.0))
	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	var k := clampf(heft - 1.0, -0.4, 1.0)
	player.volume_db = float({&"bone": -7.0, &"stone": -9.0, &"wood": -6.0, &"guard": -8.0}.get(what, -8.0)) + 3.0 * k
	player.pitch_scale = randf_range(0.94, 1.06) * (1.0 - 0.12 * maxf(k, 0.0))
	player.unit_size = 7.0
	player.max_distance = 55.0
	var world: Node = owner.get_tree().current_scene if owner.get_tree().current_scene != null else owner.get_tree().root
	world.add_child(player)
	player.global_position = at
	player.finished.connect(player.queue_free)
	player.play()


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


## The view knocked `amount` metres along `along` (as [method nudge]) and then
## shaken, `shake` metres at first, dying away over `time` seconds, and settled
## back. One tween for both, so the knock and the shake never fight over the
## camera's offsets.
static func knock(cam: Camera3D, along: Vector3, amount: float, shake: float, time: float) -> void:
	if cam == null or not cam.is_inside_tree():
		return
	var flat := Vector2(along.dot(cam.global_basis.x), along.dot(cam.global_basis.y))
	if flat.length_squared() < 0.0001:
		flat = Vector2(0.0, -1.0)
	flat = flat.normalized() * amount
	var old: Variant = cam.get_meta(&"nudge") if cam.has_meta(&"nudge") else null
	if old is Tween and (old as Tween).is_valid():
		(old as Tween).kill()
	var tw := cam.create_tween()
	tw.tween_property(cam, "h_offset", flat.x, 0.03).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(cam, "v_offset", flat.y, 0.03).set_ease(Tween.EASE_OUT)
	var steps := 5
	var step := time / float(steps + 1)
	for i in steps:
		var k := shake * (1.0 - float(i) / float(steps))
		var at := flat * (1.0 - float(i + 1) / float(steps + 1))
		tw.tween_property(cam, "h_offset", at.x + randf_range(-k, k), step)
		tw.parallel().tween_property(cam, "v_offset", at.y + randf_range(-k, k) * 0.7, step)
	tw.tween_property(cam, "h_offset", 0.0, step).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(cam, "v_offset", 0.0, step).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
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


## The sounds of [method strike], made rather than recorded, as the thud is:
## - bone: a dry crack, three snaps close together over a short knock;
## - stone: a dull knock with grit breaking over it, nothing that rings;
## - wood: a hollow knock, low partials dying quickly, and a click;
## - guard: a dull thunk, under the recorded block (`GUARD_BLOCK`).
static func _make(what: StringName) -> AudioStreamWAV:
	var rate := 22050
	var long := {&"bone": 0.22, &"stone": 0.4, &"wood": 0.28, &"guard": 0.32}
	var count := int(rate * float(long.get(what, 0.3)))
	var data := PackedByteArray()
	data.resize(count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 909 + what.hash() % 1000
	# partials [Hz, decay /s, level]
	var ring: Array = []
	match what:
		&"guard":
			ring = [[150.0, 34.0, 0.7]]
		&"wood":
			ring = [[190.0, 26.0, 0.55], [415.0, 34.0, 0.35], [760.0, 48.0, 0.2]]
		&"bone":
			ring = [[310.0, 60.0, 0.4], [1250.0, 90.0, 0.15]]
	var phases := []
	phases.resize(ring.size())
	phases.fill(0.0)
	var low := 0.0
	var band := 0.0
	var deep := 0.0
	var thump := 0.0
	var snaps := [0.0, 0.011, 0.027]
	# stone breaking: grains of grit, close together and dying away
	var grains := [[0.0, 1.0], [0.009, 0.7], [0.017, 0.8], [0.03, 0.5], [0.044, 0.4], [0.061, 0.25]]
	for i in count:
		var t := float(i) / float(rate)
		var s := 0.0
		for j in ring.size():
			var p: Array = ring[j]
			phases[j] = float(phases[j]) + TAU * float(p[0]) / float(rate)
			s += sin(float(phases[j])) * float(p[2]) * exp(-t * float(p[1]))
		s *= minf(t * 2000.0, 1.0)
		var n := rng.randf_range(-1.0, 1.0)
		low += (n - low) * 0.5
		band += (low - band) * 0.15
		var hiss := low - band  # noise, roughly 1-4 kHz
		deep += (band - deep) * 0.03
		match what:
			&"bone":
				for at: float in snaps:
					if t >= at:
						s += hiss * exp(-(t - at) * 260.0) * 1.6
			&"stone":
				# no ring (the user heard bells, 2026-10-04): a dull knock
				# falling from 100 to 45 Hz, and grit breaking over it
				thump += TAU * (45.0 + 55.0 * exp(-t * 25.0)) / float(rate)
				s += sin(thump) * exp(-t * 26.0) * 0.9 * minf(t * 2000.0, 1.0)
				var grit := (band - deep) * 1.6 + hiss * 0.5
				for g: Array in grains:
					if t >= float(g[0]):
						s += grit * float(g[1]) * exp(-(t - float(g[0])) * 110.0)
				s += band * exp(-t * 14.0) * 0.12
			&"wood":
				s += hiss * exp(-t * 180.0) * 0.9
			&"guard":
				# a dull thunk under the recorded block (see [method strike])
				s += band * exp(-t * 45.0) * 1.2 + hiss * exp(-t * 120.0) * 0.5
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 30000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	return wav
