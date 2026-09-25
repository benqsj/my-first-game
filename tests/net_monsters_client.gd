extends SceneTree

## Client half of tools/two_peers_monsters.sh — see net_monsters_host.gd.
##
## Prints what this window actually showed: the wolf's swipes, the wolf falling
## over and sinking, and each other monster's body going down.

const DEADLINE := 25.0
const WATCH_FOR := 18.0

var _net: Node
var _world: World
var _since := -1.0
var _waited := 0.0
var _knocked := false
var _wolf: Wolf
var _swipes := 0
var _was_swiping := false
var _wolf_dead_at := -1.0
var _wolf_fell := 0.0
var _wolf_sank := 0.0
var _wolf_gone := false
var _others := {}


func _initialize() -> void:
	_net = root.get_node_or_null("Net")
	print("CLIENT starting")


func _process(delta: float) -> bool:
	_waited += delta
	if not _knocked:
		_knocked = true
		_net.call("join", "127.0.0.1", &"avtandil")
		return false
	if _since < 0.0:
		_world = current_scene as World
		if _world == null or _world.players().size() < 2:
			if _waited > DEADLINE:
				print("CLIENT FAIL never got in")
				return true
			return false
		_since = 0.0
		_wolf = _world.get_node("Enemies/Wolf1") as Wolf
		print("CLIENT wolf thinks here: %s" % _wolf.is_physics_processing())
		return false
	_since += delta
	_watch_wolf()
	_watch_others()
	if _since > WATCH_FOR:
		_report()
		return true
	return false


func _watch_wolf() -> void:
	if _wolf == null or not is_instance_valid(_wolf):
		_wolf_gone = true
		return
	var swiping := _wolf.rig.is_swiping()
	if swiping and not _was_swiping and not _wolf.is_dead:
		_swipes += 1
	_was_swiping = swiping
	if _wolf.is_dead:
		if _wolf_dead_at < 0.0:
			_wolf_dead_at = _since
		# Its fall is the rig's death clip: -1 once that is playing here.
		_wolf_fell = minf(_wolf_fell, -1.0 if _wolf.rig._dead else 0.0)
		_wolf_sank = minf(_wolf_sank, _wolf.rig.position.y)


func _watch_others() -> void:
	for e in _world.get_tree().get_nodes_in_group("enemy"):
		if e is Wolf or e is Golem:
			continue
		if e.get("is_dead") != true:
			continue
		var body := e.get("body") as Node3D
		var row: Dictionary = _others.get(e.name, {"dead": true, "sank": 0.0, "start": INF})
		if body != null:
			if row["start"] == INF:
				row["start"] = body.position.y
			row["sank"] = minf(row["sank"], body.position.y - row["start"])
		_others[e.name] = row


func _report() -> void:
	print("CLIENT wolf swipes seen %d" % _swipes)
	print("CLIENT wolf died %s fell %.0f sank %.2f m gone %s" % [_wolf_dead_at >= 0.0, _wolf_fell, _wolf_sank, _wolf_gone])
	for n in _others:
		print("CLIENT other %s dead sank %.2f m" % [n, _others[n]["sank"]])
	print("CLIENT done")
