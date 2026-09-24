extends Node

## The music: one track at a time, looped, crossfaded when the scene asks for
## another.
##
## An autoload, so a track carries on across a scene change instead of
## restarting — the menu's does not cut off when a game is joined, it fades into
## the world's. Scenes ask by name with [method play]; asking for the track that
## is already on does nothing.
##
## The files are MP3s, which Godot imports as they are (`AudioStreamMP3`); each
## is set to loop here rather than in its import settings, so dropping a new file
## in needs nothing else.

const TRACKS := {
	&"menu": "res://sounds/tower-music/safe_haven_mini.mp3",
	&"world": "res://sounds/tower-music/safe_haven.mp3",
}

## Loudness of the music, in decibels, under everything else.
@export var volume_db: float = -10.0
## Seconds a crossfade takes.
@export var fade_time: float = 2.0

var _players: Array[AudioStreamPlayer] = []
var _current: int = 0
var _track: StringName = &""
var _fade: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 2:
		var player := AudioStreamPlayer.new()
		player.name = "Deck%d" % i
		player.volume_db = -80.0
		add_child(player)
		_players.append(player)


## Fades over to a track from `TRACKS`. An unknown name, or the one already
## playing, is ignored.
func play(track: StringName) -> void:
	if track == _track or not TRACKS.has(track):
		return
	var path: String = TRACKS[track]
	if not ResourceLoader.exists(path):
		return
	var stream := load(path) as AudioStream
	if stream == null:
		return
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	_track = track
	var old := _players[_current]
	_current = 1 - _current
	var fresh := _players[_current]
	fresh.stream = stream
	fresh.volume_db = -80.0
	fresh.play()
	if _fade != null and _fade.is_valid():
		_fade.kill()
	_fade = create_tween().set_parallel(true)
	_fade.tween_property(fresh, "volume_db", volume_db, fade_time).set_trans(Tween.TRANS_SINE)
	if old.playing:
		_fade.tween_property(old, "volume_db", -80.0, fade_time).set_trans(Tween.TRANS_SINE)
		_fade.chain().tween_callback(old.stop)


## Fades the music out altogether.
func stop() -> void:
	_track = &""
	var old := _players[_current]
	if _fade != null and _fade.is_valid():
		_fade.kill()
	_fade = create_tween()
	_fade.tween_property(old, "volume_db", -80.0, fade_time)
	_fade.tween_callback(old.stop)


## The track on now, or empty.
func current_track() -> StringName:
	return _track
