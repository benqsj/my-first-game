class_name Sfx
extends RefCounted

## One-shot sounds in the world: a player made for the sound, placed where it
## happens, freed when it has played. Nothing to set up and nothing to pool —
## a swing or a bowstring is a handful of these a second at most.
##
## Streams are loaded once and kept, so the first swing does not stall on a
## disk read.

static var _cache: Dictionary = {}


## Plays `path` at `where` (a node it follows, or a point if `where` is null
## and `at` is given). `pitch` is scaled by a small random amount so a sound
## heard again is not heard as a recording.
static func play(owner: Node, path: String, where: Node3D = null, at: Vector3 = Vector3.ZERO,
		pitch: float = 1.0, volume_db: float = 0.0, spread: float = 0.06) -> AudioStreamPlayer3D:
	if owner == null or not owner.is_inside_tree():
		return null
	var stream := _stream(path)
	if stream == null:
		return null
	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = maxf(pitch * randf_range(1.0 - spread, 1.0 + spread), 0.05)
	player.unit_size = 6.0
	player.max_distance = 60.0
	player.bus = &"Master"
	if where != null:
		where.add_child(player)
	else:
		var world: Node = owner.get_tree().current_scene if owner.get_tree().current_scene != null else owner.get_tree().root
		world.add_child(player)
		player.global_position = at
	player.finished.connect(player.queue_free)
	player.play()
	return player


## A sound not in the world but in the ear of whoever hears it (a hit felt by
## the archer who made it): no place, no falloff.
static func play_flat(owner: Node, path: String, pitch: float = 1.0, volume_db: float = 0.0) -> void:
	if owner == null or not owner.is_inside_tree():
		return
	var stream := _stream(path)
	if stream == null:
		return
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = maxf(pitch * randf_range(0.97, 1.03), 0.05)
	player.bus = &"Master"
	owner.add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


## Fades a sound out over `time` and frees it (for one cut short: a draw let
## go before it was done).
static func stop(player: AudioStreamPlayer3D, time: float = 0.06) -> void:
	if player == null or not is_instance_valid(player) or not player.is_inside_tree():
		return
	var tw := player.create_tween()
	tw.tween_property(player, "volume_db", -60.0, time)
	tw.tween_callback(player.queue_free)


## One of several, at random.
static func play_any(owner: Node, paths: Array, where: Node3D = null, pitch: float = 1.0,
		volume_db: float = 0.0) -> void:
	if paths.is_empty():
		return
	play(owner, String(paths[randi() % paths.size()]), where, Vector3.ZERO, pitch, volume_db)


## Loads `paths` into the cache now, so the first swing or twang plays from
## memory rather than stalling on a disk read in the middle of a fight.
static func warm(paths: Array) -> void:
	for path in paths:
		_stream(String(path))


static func _stream(path: String) -> AudioStream:
	if _cache.has(path):
		return _cache[path]
	var stream: AudioStream = load(path) as AudioStream if ResourceLoader.exists(path) else null
	_cache[path] = stream
	return stream
