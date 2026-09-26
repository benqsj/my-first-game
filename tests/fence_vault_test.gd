extends SceneTree

## Over the village fence: a hero who runs at it and jumps goes over it and
## lands on the far side on his feet — not stood on its rail, not hung in the
## air past it, not hanging off it as off a wall. Each hero, from each side.
##
##     godot --path . --headless --script res://tests/fence_vault_test.gd

const HEROES := [&"tariel", &"rogue", &"avtandil", &"mage"]

var _failures := 0


func _initialize() -> void:
	for hero: StringName in HEROES:
		await _try(hero)
	_finish()


func _try(hero: StringName) -> void:
	var game := root.get_node_or_null("Game")
	if game != null:
		game.call("choose", hero)
	var world: World = load("res://scenes/world/greybox_world.tscn").instantiate()
	root.add_child(world)
	await _wait(3)
	var player := world.player()
	player.immortal = true
	for node in world.get_node("Enemies").get_children():
		(node as Node).set_physics_process(false)
		(node as Node3D).global_position += Vector3(0.0, -60.0, 0.0)
	# The north fence runs along z = VILLAGE.end.y; from inside, heading out.
	var fence_z := World.VILLAGE.end.y
	for side: float in [-1.0, 1.0]:
		var start := Vector3(64.0, 0.3, fence_z - side * 2.6)
		player.global_position = start + Vector3.UP * Terrain.height(start.x, start.z)
		player.velocity = Vector3.ZERO
		player.state = Player.State.GROUNDED
		# Facing the fence.
		player.rotation.y = PI if side > 0.0 else 0.0
		player.camera_rig.rotation.y = player.rotation.y
		await _wait(10)
		var stuck_on_top := 0
		var hung := false
		Input.action_press("move_forward")
		await _wait(6)
		Input.action_press("jump")
		await _wait(2)
		Input.action_release("jump")
		for i in 90:
			await physics_frame
			var past := (player.global_position.z - fence_z) * side
			if absf(player.global_position.z - fence_z) < 0.4 and player.state == Player.State.GROUNDED \
					and player.global_position.y > Terrain.height(64.0, fence_z) + 0.8:
				stuck_on_top += 1
			hung = hung or player.state == Player.State.WALLCLIMB
			if past > 1.2 and player.state == Player.State.GROUNDED and i > 30:
				break
		Input.action_release("move_forward")
		await _wait(20)
		var over := (player.global_position.z - fence_z) * side
		var ground := Terrain.height(player.global_position.x, player.global_position.z)
		_check("%s, from the %s: over the fence and on his feet" % [hero, "inside" if side > 0.0 else "outside"],
				over > 0.5 and player.state == Player.State.GROUNDED and player.global_position.y - ground < 0.3
				and stuck_on_top < 3 and not hung,
				"%.2f past it, state %d, %.2f over the ground, %d frames on its rail, hung %s" % [
					over, player.state, player.global_position.y - ground, stuck_on_top, hung])
	world.queue_free()
	await _wait(3)


func _wait(frames: int) -> void:
	for i in frames:
		await physics_frame


func _finish() -> void:
	print("\n%s" % ("All checks passed." if _failures == 0 else "%d check(s) failed." % _failures))
	quit(1 if _failures else 0)


func _check(label: String, condition: bool, detail: String = "") -> void:
	if condition:
		print("  ok   - %s" % label)
	else:
		_failures += 1
		print("  FAIL - %s %s" % [label, ("(%s)" % detail) if detail else ""])
