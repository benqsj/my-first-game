extends Node

## The music: one track at a time, crossfaded when the scene asks for another.
##
## An autoload, so a track carries on across a scene change instead of
## restarting — the menu's does not cut off when a game is joined, it fades into
## the world's. Scenes ask by name with [method play]; asking for what is
## already on does nothing.
##
## A name is one file, looped, or a list of files played one after another and
## round again — the world has two, so an evening's play is not one tune.
##
## The files are MP3s, which Godot imports as they are (`AudioStreamMP3`); the
## loop is set here rather than in their import settings, so dropping a new file
## in needs only a line below.

const TRACKS := {
	&"menu": ["res://unverified/sounds/tower-music/safe_haven_mini.mp3"],
	&"world": ["res://unverified/sounds/tower-music/safe_haven.mp3", "res://unverified/sounds/tower-music/kind-of-year.mp3"],
	## When the orcs come for you.
	&"orc_fight": ["res://unverified/sounds/fight/orc_fight.mp3"],
}

## Loudness of the music, in decibels, under everything else.
@export var volume_db: float = -10.0
## Seconds a crossfade takes.
@export var fade_time: float = 2.0

var _players: Array[AudioStreamPlayer] = []
var _current: int = 0
var _track: StringName = &""
var _list: Array = []
var _index: int = 0
var _fade: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 2:
		var player := AudioStreamPlayer.new()
		player.name = "Deck%d" % i
		player.volume_db = -80.0
		add_child(player)
		player.finished.connect(_on_finished.bind(i))
		_players.append(player)


## Fades over to a track from `TRACKS`. An unknown name, or the one already
## playing, is ignored.
func play(track: StringName) -> void:
	if track == _track or not TRACKS.has(track):
		return
	_track = track
	_list = TRACKS[track]
	_index = 0
	_fade_to(_list[0])


## Fades the music out altogether.
func stop() -> void:
	_track = &""
	_list = []
	var old := _players[_current]
	if _fade != null and _fade.is_valid():
		_fade.kill()
	_fade = create_tween()
	_fade.tween_property(old, "volume_db", -80.0, fade_time)
	_fade.tween_callback(old.stop)


## The track on now, or empty.
func current_track() -> StringName:
	return _track


func _fade_to(path: String) -> void:
	if not ResourceLoader.exists(path):
		return
	var stream := load(path) as AudioStream
	if stream == null:
		return
	if stream is AudioStreamMP3:
		# One file loops on its own; a list goes on to its next.
		(stream as AudioStreamMP3).loop = _list.size() <= 1
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


## A track of a list has ended: on to the next, round to the first.
func _on_finished(deck: int) -> void:
	if deck != _current or _list.size() <= 1:
		return
	_index = (_index + 1) % _list.size()
	_fade_to(_list[_index])
