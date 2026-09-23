class_name NetSmooth
extends Node

## Makes a body that somebody *else* is driving move smoothly in this window.
##
## Without this, a remote knight or a host-driven wolf jumps: its position
## arrives thirty times a second and is written straight onto the body, while
## the screen draws sixty or more — so it stands still for a frame or two, then
## teleports to catch up. Over Wi-Fi the packets do not even arrive evenly, and
## the jumps become a stutter.
##
## The fix is the usual one: **draw the other body a little in the past**, and
## slide it between the two snapshots either side of that moment. The body is
## then always somewhere it really was, never ahead of what is known, and a late
## packet is absorbed by the buffer instead of shown.
##
## Sits as a child of the body, next to its [MultiplayerSynchronizer], which
## replicates `net_position`, `net_rotation` and — last, because its setter is
## what files the snapshot — `net_stamp`. The body's own `position` and
## `rotation` are no longer replicated directly.
##
## - On the peer that **drives** the body it only copies the body's transform
##   into those three, once per physics tick.
## - On **every other** peer it keeps a short buffer of snapshots and writes the
##   interpolated transform back onto the body each frame.
##
## How far behind is worked out as it goes: one and a half send intervals, plus
## however late packets have lately been arriving. On a quiet LAN that is about
## fifty milliseconds; on a busy one it grows, up to `max_delay`.

## Further than this between two snapshots is a teleport, not a walk: jump there.
@export var snap_distance: float = 6.0
## Never draw less far behind than this, in seconds.
@export var min_delay: float = 0.045
## Never draw further behind than this, in seconds, however bad the network is.
@export var max_delay: float = 0.25
## When no newer snapshot has arrived, carry on along the last velocity for at
## most this long rather than stopping dead.
@export var max_extrapolation: float = 0.12

## Replicated. Written by the driving peer, read by everyone else.
var net_position: Vector3 = Vector3.ZERO
var net_rotation: Vector3 = Vector3.ZERO
## When the snapshot was taken, in seconds on the *sender's* clock. Replicated
## last, so by the time this setter runs the position and rotation beside it
## are already the new ones.
var net_stamp: float = 0.0:
	set(value):
		net_stamp = value
		if _body != null and not _driving():
			_receive()

var _body: Node3D
## [time on the sender's clock, position, rotation], oldest first.
var _snaps: Array = []
## Our clock minus theirs, plus the quickest a packet has ever taken. Tracked as
## a minimum so it never includes a slow packet.
var _offset: float = INF
## How much later than the quickest the packets have lately been.
var _lateness: float = 0.0
## Seconds between snapshots, as measured.
var _interval: float = 0.033


func _ready() -> void:
	_body = get_parent() as Node3D
	# After the body's own physics, so what is published is where it ended up.
	process_physics_priority = 100
	# A body that has been told nothing yet stays where the level put it.
	if _body != null and net_stamp == 0.0:
		net_position = _body.position
		net_rotation = _body.rotation
	# Do not send anything to a peer that has not finished loading the level:
	# it has nowhere to put it. [Net] knows who has.
	for child in get_parent().get_children():
		var sync := child as MultiplayerSynchronizer
		if sync != null:
			_interval = maxf(sync.replication_interval, 0.016)
			NetSmooth.guard(sync)
	# Spawned with a snapshot already in hand: file it now that there is a body.
	if _body != null and net_stamp != 0.0 and not _driving():
		_receive()


## Adds the "only peers that are in the level" filter to a synchronizer, once.
## Also used by [World] on a freshly spawned player before it enters the tree.
static func guard(sync: MultiplayerSynchronizer) -> void:
	if sync == null or sync.has_meta(&"net_guarded"):
		return
	sync.set_meta(&"net_guarded", true)
	var tree := Engine.get_main_loop() as SceneTree
	var net: Node = tree.root.get_node_or_null("Net") if tree != null else null
	if net != null and net.has_method("sees"):
		sync.add_visibility_filter(Callable(net, "sees"))


func _physics_process(_delta: float) -> void:
	if _body == null or not _driving():
		return
	net_position = _body.position
	net_rotation = _body.rotation
	net_stamp = Time.get_ticks_usec() / 1000000.0


func _process(_delta: float) -> void:
	if _body == null or _snaps.is_empty() or _driving():
		return
	var delay := clampf(_interval * 1.5 + _lateness * 1.5, min_delay, max_delay)
	var render := _now() - _offset - delay

	# Keep exactly one snapshot at or before the moment being drawn.
	while _snaps.size() >= 2 and float(_snaps[1][0]) <= render:
		_snaps.pop_front()

	var a: Array = _snaps[0]
	if _snaps.size() >= 2:
		var b: Array = _snaps[1]
		var span := maxf(float(b[0]) - float(a[0]), 0.0001)
		var t := clampf((render - float(a[0])) / span, 0.0, 1.0)
		_body.position = (a[1] as Vector3).lerp(b[1] as Vector3, t)
		var ra := a[2] as Vector3
		var rb := b[2] as Vector3
		_body.rotation = Vector3(lerp_angle(ra.x, rb.x, t), lerp_angle(ra.y, rb.y, t),
				lerp_angle(ra.z, rb.z, t))
	else:
		# Ran out of news. Coast a little along the last known velocity, then
		# hold, rather than freezing the instant a packet is late.
		var ahead := clampf(render - float(a[0]), 0.0, max_extrapolation)
		var drift := Vector3.ZERO
		var moving := _body as CharacterBody3D
		if moving != null:
			drift = moving.velocity * ahead
		_body.position = (a[1] as Vector3) + drift
		_body.rotation = a[2] as Vector3


## Files the snapshot that has just arrived.
func _receive() -> void:
	var now := _now()
	var sample := now - net_stamp
	if sample < _offset:
		_offset = sample
	else:
		# Creep up very slowly, so two clocks that drift apart are followed.
		_offset += (sample - _offset) * 0.002
	var late := sample - _offset
	# Rises quickly when packets start arriving late, settles slowly after.
	_lateness = lerpf(_lateness, late, 0.25 if late > _lateness else 0.03)

	if not _snaps.is_empty():
		var last: Array = _snaps[_snaps.size() - 1]
		if net_stamp <= float(last[0]):
			return # out of order: older than what is already here
		_interval = lerpf(_interval, clampf(net_stamp - float(last[0]), 0.008, 0.25), 0.1)
		if (last[1] as Vector3).distance_to(net_position) > snap_distance:
			_snaps.clear()
	if _snaps.is_empty():
		# First word, or a teleport: be there now.
		_body.position = net_position
		_body.rotation = net_rotation
	_snaps.append([net_stamp, net_position, net_rotation])
	if _snaps.size() > 32:
		_snaps.pop_front()


func _driving() -> bool:
	return _body.is_inside_tree() and _body.is_multiplayer_authority()


static func _now() -> float:
	return Time.get_ticks_usec() / 1000000.0
