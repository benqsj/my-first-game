class_name WolfClaw
extends RefCounted

## The wolf-man's claw wave, as its body does it: now and then — not always —
## from out of reach it rears up, a paw raised and held while its claws gather
## a red glow and its eyes flare and a growl comes out of it, and then the paw
## comes down and the air it cuts is thrown at you: three blades of it, the
## marks of three claws ([ClawWave]).
##
## The tell is the point. However quick the swipe is, the raised paw held
## trembling over its head, the claws burning brighter, is there long enough to
## be read, and the wave can be rolled through or stepped out of the way of.
##
## A clever wolf follows it with more: a **combo** of up to three, each its own
## swing and its own wave (see [WolfMind]):
##
## | blow | the swing (Mixamo) | the wave | how it is got out of |
## |---|---|---|---|
## | **rake** | a paw raised high, held, brought down across (Standing Melee Combo Attack Ver. 2) | slanting | step aside or roll |
## | **sweep** | arms thrown wide, raked across (Standing Melee Attack Horizontal) | flat, knee to head | roll through it |
## | **slam** | both paws overhead, held, brought down to the ground (Zombie Attack) | on end, bigger, furrowing the ground | step aside |
##
## The clips are cut and laid on the wolf's skeleton in `wolf/wolf_claw.blend`
## (vepxis-art, tools/wolf_claw.py) and come in from
## `assets/wolf/wolf_claw_anims.glb`, added to the wolf's AnimationPlayer as the
## library "claw".
##
## Each blow is four beats of its clip — the rise, the hold (the tell), the
## strike, the recovery — each played over its own time, so the hold can be
## stretched without the swing going slack. The clip is driven to where it
## should be each frame by its speed, so crossfades between blows still blend.

const CLIPS := "res://assets/wolf/wolf_claw_anims.glb"
const LIBRARY := &"claw"
const GROWL := "res://unverified/sounds/orc/roar_1.wav"

## The blows. `beats`: clip seconds at the end of the rise, the hold, the
## strike and the recovery. `times`: seconds each of those takes in the game
## (the hold is the tell). `release`: how far through the strike the wave
## leaves the paw. `roll`: how the wave lies, degrees. `height`: of its middle
## off the ground. `size`, `damage`.
const BLOWS := {
	&"rake": {"clip": &"WFC_Rake", "beats": [0.73, 0.93, 1.2, 1.6], "times": [0.42, 0.7, 0.2, 0.32],
		"release": 0.55, "roll": 62.0, "height": 1.2, "size": 1.0, "damage": 70.0},
	&"sweep": {"clip": &"WFC_Sweep", "beats": [0.33, 0.45, 0.75, 1.2], "times": [0.26, 0.3, 0.18, 0.3],
		"release": 0.67, "roll": 0.0, "height": 1.0, "size": 1.15, "damage": 70.0},
	&"slam": {"clip": &"WFC_Slam", "beats": [0.4, 0.73, 1.13, 1.73], "times": [0.3, 0.55, 0.26, 0.45],
		"release": 0.8, "roll": 90.0, "height": 1.0, "size": 1.35, "damage": 90.0, "ground": true},
}
## The first blow's hold is the long tell; this much is taken off it by a
## cunning wolf (intellect 1), none by a dull one.
const TELL_QUICKEN := 0.25

static var _library: AnimationLibrary

var rig: WolfRig
var _anim: AnimationPlayer
var _skeleton: Skeleton3D
## The blows to come, the one under way and how far into it.
var _queue: Array[StringName] = []
var _blow: StringName = &""
var _t: float = 0.0
var _released: bool = false
var _first_hold: float = 0.7
## Which paw each blow raises: "l", "r" or "both" (found from the clips).
var _paw: Dictionary = {}
## Called with the blow's name and its table when a wave leaves the paw.
var on_release: Callable
var _gather: GPUParticles3D
var _growled: bool = false
var _clock: float = 0.0


func _init(owner: WolfRig, anim: AnimationPlayer, skeleton: Skeleton3D) -> void:
	rig = owner
	_anim = anim
	_skeleton = skeleton
	var lib := library()
	if lib != null and _anim != null and not _anim.has_animation_library(LIBRARY):
		_anim.add_animation_library(LIBRARY, lib)
	_find_paws()


## The clips, taken once from their glb and shared by every wolf.
static func library() -> AnimationLibrary:
	if _library != null:
		return _library
	if not ResourceLoader.exists(CLIPS):
		return null
	var scene := (load(CLIPS) as PackedScene).instantiate()
	var player := scene.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if player != null:
		_library = AnimationLibrary.new()
		for n in player.get_animation_list():
			_library.add_animation(n, player.get_animation(n).duplicate())
	scene.free()
	return _library


func has_clips() -> bool:
	return _anim != null and _anim.has_animation(_clip_name(&"rake"))


func _clip_name(blow: StringName) -> StringName:
	return StringName("%s/%s" % [LIBRARY, BLOWS[blow].clip])


## Which paw is up in each blow's hold: the one higher over the ground there.
func _find_paws() -> void:
	if not has_clips():
		return
	var hl := _skeleton.find_bone("hand_l")
	var hr := _skeleton.find_bone("hand_r")
	for blow: StringName in BLOWS:
		var beats: Array = BLOWS[blow].beats
		_anim.play(_clip_name(blow))
		_anim.seek((float(beats[0]) + float(beats[1])) * 0.5, true)
		var l := _skeleton.get_bone_global_pose(hl).origin.y
		var r := _skeleton.get_bone_global_pose(hr).origin.y
		_paw[blow] = "both" if absf(l - r) < 0.25 else ("l" if l > r else "r")
	_anim.stop()


#region Driving it
## Starts the blows, one after another. `tell`: how long the first is held
## before it comes down.
func begin(moves: Array[StringName], tell: float = -1.0) -> void:
	if not has_clips() or moves.is_empty():
		return
	_queue = moves.duplicate()
	_first_hold = tell if tell > 0.0 else float(BLOWS[_queue[0]].times[1])
	_next(true)


func _next(first: bool) -> void:
	if _queue.is_empty():
		_blow = &""
		return
	_blow = _queue.pop_front()
	_t = 0.0
	_released = false
	_growled = not first
	_anim.play(_clip_name(_blow), 0.1 if first else 0.18)
	_anim.seek(0.0, true)
	_anim.speed_scale = 1.0
	if not first:
		# Straight on out of the last one: its hold is only a beat.
		_first_hold = float(BLOWS[_blow].times[1])


func active() -> bool:
	return _blow != &""


func cancel() -> void:
	_blow = &""
	_queue.clear()
	_stop_gather()


## How long the blows `moves` take, with `tell` for the first hold.
static func duration(moves: Array[StringName], tell: float) -> float:
	var total := 0.0
	for i in moves.size():
		var times: Array = BLOWS[moves[i]].times
		total += float(times[0]) + (tell if i == 0 else float(times[1])) + float(times[2]) + float(times[3])
	return total


## The four beats of the blow under way, in game seconds.
func _times() -> Array:
	var times: Array = (BLOWS[_blow].times as Array).duplicate()
	times[1] = _first_hold
	return times


## Which beat `t` is in (0 rise, 1 hold, 2 strike, 3 recovery, 4 done) and how
## far through it.
func _beat(t: float) -> Vector2:
	var times := _times()
	var start := 0.0
	for i in 4:
		var len_i := float(times[i])
		if t < start + len_i:
			return Vector2(i, (t - start) / maxf(len_i, 0.001))
		start += len_i
	return Vector2(4, 1.0)


## Where in the clip `t` seconds into the blow should be.
func _clip_at(t: float) -> float:
	var beats: Array = BLOWS[_blow].beats
	var b := _beat(t)
	if b.x >= 4:
		return float(beats[3])
	var i := int(b.x)
	var from := 0.0 if i == 0 else float(beats[i - 1])
	var to := float(beats[i])
	var k := b.y
	if i == 2:
		# The strike accelerates into the blow.
		k = k * k * (3.0 - 2.0 * k) * 0.35 + k * 0.65
	return lerpf(from, to, k)


## Once a frame before the clips advance: sets the clip's speed so this frame
## takes it to where the blow is, and lets the wave go at its moment.
func drive(delta: float) -> void:
	if _blow == &"":
		return
	_clock += delta
	_t += delta
	var b := _beat(_t)
	if b.x >= 4:
		_next(false)
		if _blow == &"":
			_stop_gather()
			return
		b = _beat(_t)
	var want := _clip_at(_t)
	var now := _anim.current_animation_position if _anim.current_animation == String(_clip_name(_blow)) else 0.0
	_anim.speed_scale = maxf((want - now) / maxf(delta, 0.0001), 0.0)
	if not _released and b.x >= 2 and (b.x > 2 or b.y >= float(BLOWS[_blow].release)):
		_released = true
		_stop_gather()
		if on_release.is_valid():
			on_release.call(_blow, BLOWS[_blow])
#endregion


#region The tell
## After the rig's own overlay: the claws of the raised paw burning brighter
## through the rise and the hold, the eyes flaring, the jaws open on a growl,
## the body trembling as it holds.
func overlay(_delta: float) -> void:
	if _blow == &"":
		return
	var b := _beat(_t)
	var charge := 0.0
	if b.x == 0:
		charge = 0.35 * b.y
	elif b.x == 1:
		charge = 0.35 + 0.65 * b.y
		if _gather == null:
			_start_gather()
		if not _growled:
			_growled = true
			var body := rig.get_parent() as Node3D
			if body != null and ResourceLoader.exists(GROWL):
				Sfx.play(body, GROWL, null, body.global_position + Vector3.UP * 1.4, 1.35, -6.0)
	elif b.x == 2 and not _released:
		charge = 1.0
	var paw: String = _paw.get(_blow, "r")
	rig._glint(charge * 1.25, 2.0 if paw == "both" else (-1.0 if paw == "l" else 1.0))
	if rig._eye_mat != null:
		rig._eye_mat.emission_energy_multiplier = rig._eye_base * (1.0 + 4.0 * charge)
	# Jaws open on the growl.
	if rig._jaw >= 0 and not rig.has_lost("head") and charge > 0.0:
		var rot := _skeleton.get_bone_pose_rotation(rig._jaw)
		_skeleton.set_bone_pose_rotation(rig._jaw, rot * Quaternion(Vector3.RIGHT, 0.45 * charge))
	# Trembling with it as it holds.
	if b.x == 1 and rig._root_bone >= 0:
		var shiver := Vector3(sin(_clock * 67.0), sin(_clock * 41.0) * 0.4, cos(_clock * 53.0)) * 0.014 * b.y
		var local := _skeleton.global_transform.basis.inverse() * shiver
		_skeleton.set_bone_pose_position(rig._root_bone, _skeleton.get_bone_pose_position(rig._root_bone) + local)
	if _gather != null:
		_gather.global_position = _paw_point()


## Where the raised paw's claws are (between both, for a two-handed blow).
func _paw_point() -> Vector3:
	var paw: String = _paw.get(_blow, "r")
	var tips: Dictionary = rig._claw_tips
	if paw == "both" and tips.has("l") and tips.has("r"):
		return ((tips["l"] as Node3D).global_position + (tips["r"] as Node3D).global_position) * 0.5
	if tips.has(paw):
		return (tips[paw] as Node3D).global_position
	return rig.global_position + Vector3.UP * 2.0


## Red embers drawn in to the raised claws while it holds.
func _start_gather() -> void:
	var world := Blood.world_of(rig)
	if world == null:
		return
	_gather = SkillFx.particles(world, _paw_point(), {
		"amount": 36, "life": 0.4, "speed": Vector2(0.2, 0.5), "sphere": 0.9, "orbit": -9.0,
		"tangent": 3.0, "size": Vector2(0.025, 0.06), "local": true,
		"colors": [Color(1.0, 0.3, 0.1, 0.0), Color(1.0, 0.25, 0.08, 0.9), Color(1.0, 0.9, 0.8, 1.0)],
	})
	SkillFx.ring(world, rig.global_position + Vector3.UP * 0.06, Vector3.UP, Color(1.0, 0.25, 0.1, 0.5))


func _stop_gather() -> void:
	if _gather != null and is_instance_valid(_gather):
		var g := _gather
		g.emitting = false
		g.get_tree().create_timer(0.5, false).timeout.connect(g.queue_free)
	_gather = null


## The paw coming through with the wave (for its trail): "l", "r".
func slashing(side: String) -> bool:
	if _blow == &"":
		return false
	var b := _beat(_t)
	var paw: String = _paw.get(_blow, "r")
	return b.x == 2 and (paw == side or paw == "both")
#endregion
