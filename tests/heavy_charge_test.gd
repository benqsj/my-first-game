extends SceneTree
## The charged heavy and the guard counter (gameplay_plan.md, 2026-10-22):
## - Tariel's heavy blow out of his guard, thrown within the window after a
##   blow taken on the shield, is a counter: heavier by its weight, once;
##   thrown late, it is not;
## - its button held, the heavy blow stops near the top of its wind-up, the
##   gathering seen on the blade and his commitment held with it; let go
##   full, it is heavier by the bonus; tapped, no heavier at all;
## - the same for a hero whose heavy blow is on the block button.
##   Godot --headless --path . --script res://tests/heavy_charge_test.gd [-- <hero>]

var _failures := 0
var _player: Player


func _check(what: String, ok: bool, detail: String = "") -> void:
	print("  %s - %s %s" % ["ok  " if ok else "FAIL", what, detail])
	if not ok:
		_failures += 1


func _wait(n: int) -> void:
	for i in n:
		await physics_frame


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var hero := StringName(args[0]) if args.size() > 0 else &"tariel"
	var game := root.get_node_or_null("Game")
	if game != null:
		game.call("choose", hero)
	var world: World = load("res://scenes/world/greybox_world.tscn").instantiate()
	root.add_child(world)
	await _wait(2)
	world.creature_think_distance = 0.0
	_player = world.player()
	_player.immortal = true
	var imp: Fighter = null
	for node in world.get_node("Enemies").get_children():
		(node as Node).set_physics_process(false)
		if node is Fighter and imp == null:
			imp = node
		else:
			(node as Node3D).global_position += Vector3(0.0, -50.0, 0.0)
	await _wait(40)
	_player.call(&"_set_weapons_stowed", false)
	await _wait(30)
	var rig := _player.rig as SkinnedRig
	var guard := _player._guard_heavy()
	var button := "attack" if guard else "block"
	print("  hero %s, heavy on %s" % [hero, button])
	_check("a heavy blow to throw", guard or _player._has_heavy())

	if guard:
		# a blow on the shield, then the heavy at once: a counter
		var base := await _heavy_weight(false, 0)
		_check("a heavy blow out of the guard, untouched", base > 1.0 and _player.counters_thrown == 0, "%.2f" % base)
		var countered := await _heavy_weight(true, 6, imp)
		_check("thrown just after a blow on the shield: a counter, heavier", _player.counters_thrown == 1
				and absf(countered - base * _player.guard_counter_weight) < 0.05, "%.2f vs %.2f" % [countered, base])
		var late := await _heavy_weight(true, 90, imp)
		_check("thrown late: no counter", _player.counters_thrown == 1 and absf(late - base) < 0.05, "%.2f" % late)

	# the charge: held all the way
	await _ready_to_swing()
	if guard:
		Input.action_press("block")
		await _wait(20)
	Input.action_press(button)
	await _wait(2)
	var weight0 := rig.cut_weight
	var held_seen := false
	var gather_seen := false
	var progress_at := -1.0
	var progress_later := -1.0
	var committed_through := true
	for i in 120:
		await physics_frame
		if rig.heavy_charge_held():
			if not held_seen:
				progress_at = rig._progress()
			held_seen = true
			progress_later = rig._progress()
			committed_through = committed_through and _player.is_committed()
		if not root.find_children("*", "HeavyGather", true, false).is_empty():
			gather_seen = true
	Input.action_release(button)
	Input.action_release("block")
	await _wait(3)
	_check("held: the blow stops near the top of its wind-up", held_seen and progress_later - progress_at < 0.06,
			"%.3f -> %.3f" % [progress_at, progress_later])
	_check("the gathering seen on the blade", gather_seen)
	_check("his commitment held with it", committed_through)
	_check("let go full: heavier by the bonus", _player.charges_let_go == 1 and _player.last_charge > 0.99
			and absf(rig.cut_weight - weight0 * (1.0 + _player.heavy_charge_bonus)) < 0.05,
			"%.2f -> %.2f" % [weight0, rig.cut_weight])
	await _wait(5)
	_check("the gathering gone once let go", root.find_children("*", "HeavyGather", true, false).is_empty())
	# and it lands: the swing goes on to its end
	var ends := false
	for i in 150:
		await physics_frame
		if not _player.is_committed():
			ends = true
			break
	_check("the blow plays out after it", ends)

	# tapped: no charge
	await _ready_to_swing()
	if guard:
		Input.action_press("block")
		await _wait(20)
	Input.action_press(button)
	await _wait(2)
	var tap0 := rig.cut_weight
	Input.action_release(button)
	Input.action_release("block")
	await _wait(40)
	_check("tapped: not held, no heavier", _player.charges_let_go == 1 and absf(rig.cut_weight - tap0) < 0.01
			and not rig.heavy_charge_held(), "%.2f -> %.2f" % [tap0, rig.cut_weight])

	if _failures == 0:
		print("All checks passed.")
	else:
		print("%d check(s) FAILED." % _failures)
	quit(1 if _failures > 0 else 0)


func _ready_to_swing() -> void:
	for i in 200:
		if not _player.is_committed():
			break
		await physics_frame
	await _wait(30)
	_player.stamina = _player.max_stamina
	_player.velocity = Vector3.ZERO


## Tariel's heavy blow out of his guard, after a blow on the shield `after`
## ticks before (or none): its weight, thrown and let go at once.
func _heavy_weight(blocked: bool, after: int, imp: Fighter = null) -> float:
	await _ready_to_swing()
	Input.action_press("block")
	await _wait(40)
	if blocked:
		imp.global_position = _player.global_position - _player.global_transform.basis.z * 1.5
		var away := _player.global_position - imp.global_position
		away.y = 0.0
		_player.net_blow(6.0, away.normalized(), imp.global_position, "%s#%d" % [imp.get_path(), randi()], 0, 3)
		imp.global_position += Vector3(0, -50, 0)
		await _wait(after)
	_player.stamina = _player.max_stamina
	Input.action_press("attack")
	await _wait(1)
	Input.action_release("attack")
	await _wait(1)
	var w := (_player.rig as SkinnedRig).cut_weight
	Input.action_release("block")
	return w
