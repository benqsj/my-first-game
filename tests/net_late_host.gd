extends SceneTree

## Half of the late-join check. See `tools/late_join.sh`.
##
## Hosts, then — before anybody has arrived — kills Wolf1 and clears its body
## away, and takes a leg and the tail off Wolf2. Somebody who joins after that
## built every camp fresh, so unless the host tells them, they would see Wolf1
## standing there (a wolf nobody can hit) and Wolf2 whole.

var _net: Node
var _world: World
var _t := 0.0
var _stage := 0


func _process(delta: float) -> bool:
	_t += delta
	match _stage:
		0:
			_net = root.get_node("Net")
			_net.call("host", &"tariel")
			_stage = 1
		1:
			_world = current_scene as World
			if _world == null or _world.players().is_empty():
				return false
			(_world.get_node("Enemies/Wolf1") as Wolf).net_clear.rpc()
			var wolf := _world.get_node("Enemies/Wolf2") as Wolf
			wolf.rig.detach("left leg")
			wolf.rig.detach("tail")
			wolf.health = 42.0
			print("LHOST ready")
			_stage = 2
			_t = 0.0
		2:
			if _world.players().size() >= 2:
				_stage = 3
				_t = 0.0
			elif _t > 30.0:
				print("LHOST FAIL nobody came")
				quit(1)
				return true
		_:
			if _t > 6.0:
				print("LHOST OK")
				quit(0)
				return true
	return false
