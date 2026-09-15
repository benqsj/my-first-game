extends SceneTree

## Half of the live two-process check. See `tests/net_client.gd` and
## `tools/two_peers.sh`, which runs both and reads the two logs together.
##
##     godot --path . --headless --script res://tests/net_host.gd
##
## One process has one `multiplayer`, so the only honest way to test that two
## peers talk to each other is to *be* two peers. Each side runs, swings, and
## cuts **its own wolf** apart, and each reports both wolves at the end. Both
## directions on purpose: an earlier version of this only had the host attack,
## and what that missed was that a client's swing has to travel the other way
## and land on a body the host is simulating.
##
## Everything is timed rather than handshaken. A readiness protocol is out of
## scope for this phase (`MULTIPLAYER_PVE.md` §8), and for two processes on one
## machine a generous clock is enough.

const DEADLINE := 22.0
## A wolf each, well apart, so neither is in the other's swings.
const MINE_AT := Vector3(30.0, 0.5, 30.0)
const THEIRS_AT := Vector3(30.0, 0.5, 40.0)

var _net: Node
var _world: World
var _mine: Player
var _wolf: Wolf
var _their_wolf: Wolf

var _waited := 0.0
## Seconds since both bodies were standing in the level, so that this clock and
## the client's start together.
var _since := -1.0
var _opened := false
var _reported := false
var _swings := 0
var _started_at := Vector3.ZERO
## How many frames the *other* knight's blade was live here. Zero with a serial
## that is climbing means their swing arrived and cut nothing — which is what a
## character with no sword looks like from this side.
var _saw_edge := 0
var _own_edge := 0
var _own_gap := 99.0
var _saw_draw := 0


func _initialize() -> void:
	_net = root.get_node_or_null("Net")
	if _net == null:
		print("HOST FAIL no Net autoload")
		quit(1)
	else:
		print("HOST starting")


func _process(delta: float) -> bool:
	_waited += delta
	# Not in `_initialize()`: a script main loop has not put its root into the
	# tree yet, and `multiplayer` is null until it has.
	if not _opened:
		_opened = true
		if not bool(_net.call("host", &"tariel")):
			return _give_up("could not open the port")
		print("HOST listening")
		return false

	if _since < 0.0:
		_world = current_scene as World
		if _world == null:
			return _waited > DEADLINE and _give_up("never loaded the world")
		if _world.players().size() < 2:
			return _waited > DEADLINE and _give_up("nobody else arrived")
		_begin()
		return false

	_since += delta
	# Both wolves held on their marks. A hit shoves a wolf, and a wolf that has
	# been shoved out of reach makes the next swing miss — which is a fact about
	# knockback, not about whether a cut crossed the wire. Only the host may move
	# them; the other window is told where they are.
	if _since > 1.8:
		_wolf.global_position = MINE_AT
		_wolf.velocity = Vector3.ZERO
		_their_wolf.global_position = THEIRS_AT
		_their_wolf.velocity = Vector3.ZERO
	_act()
	_watch()
	if _since > 9.0 and not _reported:
		_reported = true
		_report()
	if _since > 12.0:
		quit(0)
		return true
	return false


## Both knights are here. Put a wolf in front of each of them.
func _begin() -> void:
	_since = 0.0
	_mine = _world.player()
	_started_at = _mine.global_position
	_wolf = _park("Enemies/Wolf1", MINE_AT)
	_their_wolf = _park("Enemies/Wolf2", THEIRS_AT)
	print("HOST roster %s" % [_net.get("roster")])
	var seen: Array[String] = []
	for body in _world.players():
		seen.append("%s=%s" % [body.name,
				body.profile.display_name if body.profile != null else "?"])
	seen.sort()
	print("HOST bodies %s" % ", ".join(seen))
	print("HOST mine=%s driven=%s" % [_mine.name, _mine.is_physics_processing()])
	for body in _world.players():
		if body != _mine:
			print("HOST theirs=%s driven=%s animated=%s"
					% [body.name, body.is_physics_processing(), body.is_processing()])


## Still, blind and where it was put. What is being tested is whether a cut
## reaches the other window, not whether a wolf can find anybody.
func _park(path: String, at: Vector3) -> Wolf:
	var wolf := _world.get_node(path) as Wolf
	wolf.sight_range = 0.0
	wolf.prowl_speed = 0.0
	wolf.corpse_linger = 1000.0
	wolf.global_position = at
	return wolf


## The schedule: a second and a half of running so the other window has
## something to interpolate, then cuts at the wolf, one every four fifths.
func _act() -> void:
	if _since < 1.6:
		_mine.velocity.x = 6.0
		return
	if _since < 2.0:
		_mine.global_position = MINE_AT + Vector3(0.0, 0.0, 1.3)
		_mine.velocity = Vector3.ZERO
		_mine.rotation.y = 0.0
		return
	# Held on the mark every frame, not only on the ones that swing: the window
	# the blade is live for opens a sixth of a second *after* the swing starts,
	# and a body still drifting by then is a body swinging at nothing.
	_mine.global_position = MINE_AT + Vector3(0.0, 0.0, 1.3)
	_mine.velocity = Vector3.ZERO
	_mine.rotation.y = 0.0
	var due := int((_since - 2.0) / 0.8) + 1
	if due > _swings and due <= 8:
		_swings = due
		_mine.global_position = MINE_AT + Vector3(0.0, 0.0, 1.3)
		# The replicated call, which is the whole of what combat needs over the
		# wire: every peer's copy of this knight throws the same swing, so the
		# blade the wolf reads is in a real place on the host.
		_mine.net_attack.rpc(CharacterRig.AttackStyle.SIDE)


## Was the other knight's blade ever live here? Sampled every frame: the window
## is open for a third of a second, and one snapshot says nothing about it.
func _watch() -> void:
	# Did the other archer visibly draw here? Without the replicated draw he
	# stands with his bow down and an arrow simply appears out of him.
	for body in _world.players():
		if body != _mine and body.get("net_draw") > 0.2:
			_saw_draw += 1
	if _mine.rig != null and not _mine.rig.get_cutting_edge().is_empty():
		_own_edge += 1
		_own_gap = minf(_own_gap, _mine.global_position.distance_to(_wolf.global_position))
	for body in _world.players():
		if body == _mine or body.rig == null:
			continue
		if not body.rig.get_cutting_edge().is_empty():
			_saw_edge += 1


func _report() -> void:
	print("HOST ran %.2f m" % _started_at.distance_to(_mine.global_position))
	print("HOST swings %d serial %d" % [_swings, _mine.rig.attack_serial])
	print("HOST mywolf health %.0f lost %d dead %s"
			% [_wolf.health, _wolf.rig.lost_parts(), _wolf.is_dead])
	print("HOST theirwolf health %.0f lost %d dead %s"
			% [_their_wolf.health, _their_wolf.rig.lost_parts(), _their_wolf.is_dead])
	print("HOST my blade live %d frame(s), closest gap %.2f m" % [_own_edge, _own_gap])
	print("HOST saw their blade live for %d frame(s)" % _saw_edge)
	print("HOST saw them drawing for %d frame(s)" % _saw_draw)
	print("HOST bodies_left %d" % _world.players().size())
	print("HOST OK")


func _give_up(why: String) -> bool:
	print("HOST FAIL %s" % why)
	quit(1)
	return true
