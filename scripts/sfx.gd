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
		pitch: float = 1.0, volume_db: float = 0.0, spread: float = 0.06) -> void:
	if owner == null or not owner.is_inside_tree():
		return
	var stream := _stream(path)
	if stream == null:
		return
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


## One of several, at random.
static func play_any(owner: Node, paths: Array, where: Node3D = null, pitch: float = 1.0,
		volume_db: float = 0.0) -> void:
	if paths.is_empty():
		return
	play(owner, String(paths[randi() % paths.size()]), where, Vector3.ZERO, pitch, volume_db)


static func _stream(path: String) -> AudioStream:
	if _cache.has(path):
		return _cache[path]
	var stream: AudioStream = load(path) as AudioStream if ResourceLoader.exists(path) else null
	_cache[path] = stream
	return stream
