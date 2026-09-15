extends SceneTree

## The other half of the live two-process check. See `tests/net_host.gd`.
##
##     godot --path . --headless --script res://tests/net_client.gd
##
## Joins, then does the same as the host from the other end: runs, swings, and
## shoots **its own** wolf. Both directions are tested because they are not the
## same journey — a client's attack has to travel to the host and land on a body
## the host is simulating, and an earlier version of this test only ever had the
## host attack, which is exactly how a client that could not hurt anything got
## as far as somebody playing it.
##
## The client is the **archer** on purpose. The sword was the easy half; the bow
## is the one that needed the draw replicating and the arrow spawned on every
## peer, and it is the one somebody actually picked and found broken.

const ADDRESS := "127.0.0.1"
const DEADLINE := 22.0
## The wolf the host parked for this side.
const MINE_AT := Vector3(30.0, 0.5, 40.0)

var _net: Node
var _world: World
var _mine: Player
var _theirs: Player
var _wolf: Wolf
var _their_wolf: Wolf

var _waited := 0.0
var _since := -1.0
var _knocked := false
var _swings := 0
var _holding := false
## What was seen of the other knight while watching.
var _their_start := Vector3.ZERO
var _their_travel := 0.0
var _their_swings := 0


func _initialize() -> void:
	_net = root.get_node_or_null("Net")
	if _net == null:
		print("CLIENT FAIL no Net autoload")
		quit(1)
	else:
		print("CLIENT starting")


func _process(delta: float) -> bool:
	_waited += delta
	if not _knocked:
		_knocked = true
		_net.call("join", ADDRESS, &"avtandil")
		print("CLIENT knocking")
		return false

	if _since < 0.0:
		# Only until the watch starts. After that the level is held onto: the
		# host quits when it has done its part, and a client that went back to
		# reading `current_scene` would find the main menu there and call it a
		# failure.
		_world = current_scene as World
		if _world == null:
			return _waited > DEADLINE and _give_up("never got into the world")
		if _world.players().size() < 2:
			return _waited > DEADLINE and _give_up("only ever saw one body")
		_begin()
		return false

	_since += delta
	_act()
	_watch()
	if _since > 8.5:
		_report()
		quit(0)
		return true
	return false


func _begin() -> void:
	_since = 0.0
	_mine = _world.player()
	_wolf = _world.get_node("Enemies/Wolf2") as Wolf
	_their_wolf = _world.get_node("Enemies/Wolf1") as Wolf
	for body in _world.players():
		if body != _mine:
			_theirs = body
	_their_start = _theirs.global_position
	print("CLIENT roster %s" % [_net.get("roster")])
	var seen: Array[String] = []
	for body in _world.players():
		seen.append("%s=%s" % [body.name,
				body.profile.display_name if body.profile != null else "?"])
	seen.sort()
	print("CLIENT bodies %s" % ", ".join(seen))
	print("CLIENT mine=%s driven=%s" % [_mine.name, _mine.is_physics_processing()])
	print("CLIENT theirs=%s driven=%s animated=%s"
			% [_theirs.name, _theirs.is_physics_processing(), _theirs.is_processing()])
	# Nothing here thinks for the wolves. Two brains in one wolf is two wolves
	# disagreeing about where it is.
	print("CLIENT wolf_thinks=%s" % _wolf.is_physics_processing())


## Stood off and shooting. The bow wants room — an arrow that leaves inside the
## thing it is aimed at has nothing to fly through.
func _act() -> void:
	if _since < 2.0:
		return
	_mine.global_position = MINE_AT + Vector3(0.0, 0.0, 9.0)
	_mine.velocity = Vector3.ZERO
	_mine.rotation.y = 0.0
	_mine.camera_rig.rotation.y = 0.0
	# The button, not the internals. Held for two thirds of a second and let go,
	# which is the whole of how a bow is fired — and the only way the draw gets
	# published frame by frame for the other window to see.
	var slot := fmod(_since - 2.0, 1.0)
	if slot < 0.7:
		if not _holding:
			_holding = true
			Input.action_press("attack")
	elif _holding:
		_holding = false
		Input.action_release("attack")
		_swings += 1


func _watch() -> void:
	if not is_instance_valid(_theirs):
		return
	_their_travel = maxf(_their_travel, _their_start.distance_to(_theirs.global_position))
	if _theirs.rig != null:
		_their_swings = maxi(_their_swings, _theirs.rig.attack_serial)


func _report() -> void:
	print("CLIENT saw them run %.2f m" % _their_travel)
	print("CLIENT saw them swing %d time(s)" % _their_swings)
	print("CLIENT swings %d serial %d" % [_swings, _mine.rig.attack_serial])
	print("CLIENT mywolf health %.0f lost %d dead %s"
			% [_wolf.health, _wolf.rig.lost_parts(), _wolf.is_dead])
	print("CLIENT theirwolf health %.0f lost %d dead %s"
			% [_their_wolf.health, _their_wolf.rig.lost_parts(), _their_wolf.is_dead])
	print("CLIENT OK")


func _give_up(why: String) -> bool:
	print("CLIENT FAIL %s" % why)
	quit(1)
	return true
