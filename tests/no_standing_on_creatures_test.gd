extends SceneTree
## No hero stands on a creature or climbs it (the user's word, 2026-10-06):
## dropped on an orc's head he slides off it to the ground, and a jump at it
## does not pull him up onto it. Killing a target locks on only to what is
## after him (`Player._hunting_me`).
##   Godot --headless --path . --script res://tests/no_standing_on_creatures_test.gd
var _failures := 0


func _check(what: String, ok: bool, detail: String = "") -> void:
	print("  %s - %s %s" % ["ok  " if ok else "FAIL", what, detail])
	if not ok:
		_failures += 1


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _initialize() -> void:
	var game := root.get_node_or_null("Game")
	if game != null:
		game.call("choose", &"tariel")
	var world: World = load("res://scenes/world/greybox_world.tscn").instantiate()
	root.add_child(world)
	await _frames(2)
	var player: Player = world.player()
	player.immortal = true
	var foe: Node3D = null
	for e in world.get_node("Enemies").get_children():
		if foe == null and e is CharacterBody3D and String(e.name).to_lower().contains("orc"):
			foe = e
			continue
		e.queue_free()
	await _frames(10)
	player.global_position = Vector3(0.0, 0.5, 26.0)
	await _frames(20)
	foe.global_position = Vector3(0.0, player.global_position.y, 18.0)
	foe.set_physics_process(false)
	await _frames(30)
	print("    the orc: layer %d at %s" % [(foe as CollisionObject3D).collision_layer, foe.global_position])
	# dropped on its head
	player.global_position = foe.global_position + Vector3(0.05, 4.5, 0.0)
	player.velocity = Vector3.ZERO
	var top := -INF
	for i in 120:
		await physics_frame
		if i > 60:
			top = maxf(top, player.global_position.y)
		if i % 10 == 0:
			print("      t%d y %.2f off %.2f floor %s" % [i, player.global_position.y - foe.global_position.y,
					Vector2(player.global_position.x - foe.global_position.x, player.global_position.z - foe.global_position.z).length(),
					player.is_on_floor()])
	print("    over it: %s" % [player.global_position])
	var off := Vector2(player.global_position.x - foe.global_position.x, player.global_position.z - foe.global_position.z).length()
	print("    dropped on its head: %.2f m off its middle, feet %.2f m over its feet" % [off, top - foe.global_position.y])
	_check("dropped on a creature, he is off it, on the ground", top - foe.global_position.y < 0.6,
			"%.2f m up" % (top - foe.global_position.y))
	# run and jump at it: no pull up onto it
	player.global_position = foe.global_position + Vector3(0.0, 0.2, 4.0)
	player.rotation.y = 0.0
	player.camera_rig.rotation.y = 0.0
	await _frames(20)
	Input.action_press("move_forward")
	var highest := -INF
	for i in 120:
		if i == 15:
			Input.action_press("jump")
		if i == 18:
			Input.action_release("jump")
		await physics_frame
		highest = maxf(highest, player.global_position.y)
		_check_climb_state(player)
	Input.action_release("move_forward")
	await _frames(40)
	_check("jumping at it, he does not end up on it", player.global_position.y - foe.global_position.y < 0.6,
			"%.2f m up" % (player.global_position.y - foe.global_position.y))
	_check("nor takes hold of it to climb", not _climbed, "")
	# a creature not after him is not locked on after a kill
	_check("a creature minding its own ground is not after him", not player._hunting_me(foe), str(foe.get("mode")))
	print("ALL PASSED" if _failures == 0 else "%d FAILED" % _failures)
	quit(1 if _failures > 0 else 0)


var _climbed := false


func _check_climb_state(player: Player) -> void:
	if player.state == Player.State.CLIMBING or player.state == Player.State.WALLCLIMB:
		_climbed = true
