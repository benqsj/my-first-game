extends SceneTree

## Host half of the "does the other window see the monsters fight and die" check.
##
##     sh tools/two_peers_monsters.sh
##
## Puts a wolf in front of the *client's* knight and lets it attack him, then
## kills it, an imp and an orc, and keeps the world running long enough for the
## bodies to fall, sink and be cleared. The client (net_monsters_client.gd)
## reports what it saw of all of that.

const DEADLINE := 25.0
const RUN_FOR := 17.0

var _net: Node
var _world: World
var _since := -1.0
var _waited := 0.0
var _opened := false
var _wolf: Wolf
var _killed := false
var _swipes := 0
var _was_swiping := false


func _initialize() -> void:
	_net = root.get_node_or_null("Net")
	print("HOST starting")


func _process(delta: float) -> bool:
	_waited += delta
	if not _opened:
		_opened = true
		if not bool(_net.call("host", &"tariel")):
			print("HOST FAIL could not open the port")
			return true
		return false
	if _since < 0.0:
		_world = current_scene as World
		if _world == null or _world.players().size() < 2:
			if _waited > DEADLINE:
				print("HOST FAIL nobody arrived")
				return true
			return false
		_begin()
		return false
	_since += delta
	if _wolf != null and is_instance_valid(_wolf):
		var swiping := _wolf.rig.is_swiping()
		if swiping and not _was_swiping:
			_swipes += 1
		_was_swiping = swiping
	if not _killed and _since > 4.0:
		_killed = true
		print("HOST wolf swipes before death %d" % _swipes)
		for who in _targets():
			who.call("take_hit", 9999.0, (who as Node3D).global_position + Vector3.UP, Vector3.UP, false, false, _world.player())
			print("HOST killed %s dead=%s" % [who.name, who.get("is_dead")])
	if _since > RUN_FOR:
		print("HOST done")
		return true
	return false


func _begin() -> void:
	_since = 0.0
	var mine := _world.player()
	var theirs: Player = null
	for p in _world.players():
		if p != mine:
			theirs = p
	# The host's own knight out of the way, so the wolf goes for the other one.
	mine.global_position = Vector3(-60.0, 0.5, -60.0)
	_wolf = _world.get_node("Enemies/Wolf1") as Wolf
	var ahead := -theirs.global_transform.basis.z
	ahead.y = 0.0
	_wolf.global_position = theirs.global_position + ahead.normalized() * 1.4 + Vector3.UP * 0.3
	_wolf.sight_range = 30.0
	for w in _world.get_node("Enemies").get_children():
		if w is Wolf and w != _wolf:
			(w as Wolf).sight_range = 0.0
	print("HOST wolf parked by %s" % theirs.name)


## A wolf, and the first imp-kind and orc-kind in the level, by name so both
## windows pick the same ones.
func _targets() -> Array[Node]:
	var out: Array[Node] = [_wolf]
	var enemies := _world.get_tree().get_nodes_in_group("enemy")
	enemies.sort_custom(func(a, b): return String(a.name) < String(b.name))
	for kind in ["Fighter", "OrcWarrior", "Arkdeva"]:
		for e in enemies:
			if e.get_script() != null and (e.get_script() as Script).get_global_name() == kind and e.get("is_dead") == false:
				out.append(e)
				break
	return out
