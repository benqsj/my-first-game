extends SceneTree

## The other half of the late-join check. Finds the host the way a player on the
## same Wi-Fi would — by listening for its call on the network, not by being
## told an address — joins it, and reports what it sees of the two wolves.

var _net: Node
var _world: World
var _t := 0.0
var _stage := 0


func _process(delta: float) -> bool:
	_t += delta
	match _stage:
		0:
			_net = root.get_node("Net")
			_net.call("start_looking")
			_stage = 1
		1:
			var games: Dictionary = _net.get("games")
			if games.is_empty():
				if _t > 25.0:
					print("LCLIENT FAIL heard no game on the network")
					quit(1)
					return true
				return false
			print("LCLIENT heard %s" % [games.keys()])
			_net.call("join", games.keys()[0], &"avtandil")
			_stage = 2
			_t = 0.0
		2:
			_world = current_scene as World
			if _world == null or _world.players().size() < 2:
				if _t > 25.0:
					print("LCLIENT FAIL never got in")
					quit(1)
					return true
				return false
			_stage = 3
			_t = 0.0
		_:
			if _t > 3.0:
				var wolf := _world.get_node_or_null("Enemies/Wolf2") as Wolf
				var lost: Array = wolf.rig.lost_list() if wolf != null else []
				lost.sort()
				print("LCLIENT wolf1 %s" % ("still there" if _world.has_node("Enemies/Wolf1") else "gone"))
				print("LCLIENT wolf2 lost %s health %.0f" % [lost, wolf.health if wolf != null else -1.0])
				quit(0)
				return true
	return false
