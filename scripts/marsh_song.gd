class_name MarshSong
extends Node

## The song of the misty mere: two short passages of a woman's voice, heard
## when this peer's player walks into the marsh round the misty village.
##
## The first plays as he comes in; the second a few seconds after it ends
## (`gap_min`..`gap_max`, picked at random each time); then nothing more until
## he has left the marsh for a while and comes back. It sits under everything
## else — quieter than the music — so it is noticed rather than announced.
##
## "In the marsh" is the mere's ellipse widened by `enter_margin`; he has left
## when he is past it by `leave_margin`, so walking the rim does not start and
## stop it. Leaving mid-song fades it out. The orcs' fight music, if it starts,
## fades it out as well.
##
## Only local: nothing here is networked, each peer hears his own.

const PASSAGES: Array[String] = [
	"res://sounds/moments/short-women-voice-1.mp3",
	"res://sounds/moments/short-women-voice-2.mp3",
]
## Per-passage loudness, dB. The second is recorded ~2 dB louder than the first.
const TRIM: Array[float] = [1.0, -1.0]

enum Step { WAITING, FIRST, GAP, SECOND, DONE }

## The marsh whose mere this belongs to.
@export var marsh: Marsh
## How loud, in dB. The music plays at -10.
@export var volume_db: float = -16.0
@export var gap_min: float = 5.0
@export var gap_max: float = 10.0
## Metres beyond the mere's rim that already count as in the marsh.
@export var enter_margin: float = 8.0
## Metres beyond the rim at which he has left it.
@export var leave_margin: float = 20.0
## Seconds he must be away before it can play again.
@export var rearm_after: float = 30.0
@export var fade_time: float = 1.5

var step: Step = Step.WAITING
var _player: AudioStreamPlayer
var _fade: Tween
var _gap_left: float = 0.0
var _away_for: float = 0.0
var _inside: bool = false
var _tick: float = 0.0


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.name = "Voice"
	_player.bus = &"Master"
	add_child(_player)
	_player.finished.connect(_on_finished)


func _process(delta: float) -> void:
	if step == Step.GAP:
		_gap_left -= delta
		if _gap_left <= 0.0:
			_start(1)
	_tick += delta
	if _tick < 0.25:
		return
	var dt := _tick
	_tick = 0.0
	var at: Variant = _where_am_i()
	if at == null or marsh == null:
		return
	var pos := at as Vector2
	if not _inside and _reach(pos, enter_margin) < 1.0:
		_inside = true
		_away_for = 0.0
	elif _inside and _reach(pos, leave_margin) >= 1.0:
		_inside = false
		_hush()
	if not _inside:
		_away_for += dt
		if step != Step.WAITING and _away_for >= rearm_after:
			step = Step.WAITING
	elif step == Step.WAITING and not _fighting():
		_start(0)
	elif _fighting() and (step == Step.FIRST or step == Step.SECOND or step == Step.GAP):
		_hush()


## Whether this peer's player is in the marsh as far as the song cares.
func is_inside() -> bool:
	return _inside


func _reach(at: Vector2, margin: float) -> float:
	var r := marsh.mere_radii + Vector2(margin, margin)
	return ((at - marsh.mere_centre) / r).length()


func _where_am_i() -> Variant:
	var world := get_parent()
	if world == null or not world.has_method("player"):
		return null
	var me := world.call("player") as Node3D
	if me == null or not me.is_inside_tree():
		return null
	var local := marsh.to_local(me.global_position)
	return Vector2(local.x, local.z)


func _fighting() -> bool:
	var music := get_node_or_null("/root/Music")
	return music != null and music.call("current_track") == &"orc_fight"


func _start(which: int) -> void:
	var stream := load(PASSAGES[which]) as AudioStream
	if stream == null:
		step = Step.DONE
		return
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = false
	step = Step.FIRST if which == 0 else Step.SECOND
	if _fade != null and _fade.is_valid():
		_fade.kill()
	_player.stream = stream
	_player.volume_db = volume_db + TRIM[which]
	_player.play()


func _on_finished() -> void:
	if step == Step.FIRST:
		step = Step.GAP
		_gap_left = randf_range(gap_min, gap_max)
	elif step == Step.SECOND:
		step = Step.DONE


## Fades out whatever is on, and the song is over for this visit.
func _hush() -> void:
	if step == Step.GAP:
		step = Step.DONE
	if not _player.playing:
		return
	step = Step.DONE
	if _fade != null and _fade.is_valid():
		_fade.kill()
	_fade = create_tween()
	_fade.tween_property(_player, "volume_db", -60.0, fade_time)
	_fade.tween_callback(_player.stop)
