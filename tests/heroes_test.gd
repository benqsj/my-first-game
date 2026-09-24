extends SceneTree

## The mage and the rogue: each spawns on his own rig and clips, the mage's
## charged cast throws a bolt and his held jump floats, the rogue's stabs cut
## with a blade in each hand.
##
##     godot --path . --headless --script res://tests/heroes_test.gd

const WORLD := "res://scenes/world/greybox_world.tscn"

var _failures := 0
var _world: Node3D
var _player: Player


func _initialize() -> void:
	await _spawn(&"mage")
	await _check_mage()
	await _spawn(&"rogue")
	await _check_rogue()
	print("")
	if _failures == 0:
		print("All checks passed.")
	else:
		print("%d check(s) FAILED." % _failures)
	quit(1 if _failures > 0 else 0)


func _spawn(id: StringName) -> void:
	if _world != null:
		_world.queue_free()
		await _wait(2)
	var game := root.get_node_or_null("Game")
	if game != null:
		game.call("choose", id)
	_world = load(WORLD).instantiate()
	root.add_child(_world)
	await _wait(2)
	_player = (_world as World).player()
	for body in _world.find_children("*", "CharacterBody3D", true, false):
		if body != _player:
			body.queue_free()
	await _wait(30)


func _check_mage() -> void:
	var rig := _player.rig as SkinnedMageRig
	_check("the mage stands on his own rig", rig != null, str(_player.rig))
	if rig == null:
		return
	_check("with his clips", rig.clip_names().has("MG_Cast_1H") and rig.clip_names().has("MG_Float"),
			"%d clips" % rig.clip_names().size())
	_check("and fights from afar", _player.has_bow())
	_check("standing still he stands", String(rig._anim.current_animation) == "MG_Idle",
			String(rig._anim.current_animation))

	# Charge and throw.
	Input.action_press("attack")
	await _wait(50)
	_check("charging holds the gathering cast", String(rig._anim.current_animation) == SkinnedMageRig.CHARGE_CLIP,
			String(rig._anim.current_animation))
	Input.action_release("attack")
	var bolt: SpellBolt = null
	for i in 10:
		await physics_frame
		for node in _world.find_children("*", "Node3D", true, false):
			if node is SpellBolt:
				bolt = node
	_check("letting go throws a bolt", bolt != null)
	if bolt != null:
		var from := bolt.global_position
		await _wait(10)
		if is_instance_valid(bolt):
			var went := bolt.global_position - from
			# Straight: no drop beyond the aim's own slope.
			_check("and it flies straight", went.length() > 3.0 and absf(went.y) < went.length() * 0.12,
					"%.1f m, %.2f m up" % [went.length(), went.y])
	await _wait(40)

	# The jump, and the float down.
	var ground := _player.global_position.y
	Input.action_press("jump")
	var peak := ground
	var slowest_fall := 0.0
	var floated := false
	for i in 200:
		await physics_frame
		peak = maxf(peak, _player.global_position.y)
		if _player.is_levitating():
			floated = true
			slowest_fall = minf(slowest_fall, _player.velocity.y)
		if _player.is_on_floor() and i > 20:
			break
	Input.action_release("jump")
	_check("he jumps high", peak - ground > 2.6, "%.2f m" % (peak - ground))
	_check("and, the jump held, floats down", floated and slowest_fall > -_player.profile.levitate_fall - 0.05,
			"falling at %.2f m/s at most while floating" % -slowest_fall)
	await _wait(30)


func _check_rogue() -> void:
	var rig := _player.rig as SkinnedRogueRig
	_check("the rogue stands on his own rig", rig != null, str(_player.rig))
	if rig == null:
		return
	_check("and swings rather than shoots", not _player.has_bow())
	_check("he is the quickest on his feet", _player.run_speed > 6.5, "%.1f m/s" % _player.run_speed)
	Input.action_press("attack")
	await physics_frame
	await physics_frame
	Input.action_release("attack")
	_check("a click is a stab", String(rig.current_swing()).begins_with("DG_Stab"), String(rig.current_swing()))
	var cut := false
	var both := false
	for i in 60:
		await physics_frame
		if not rig.get_cutting_edge().is_empty():
			cut = true
			both = both or (rig._arc_l != null and rig._arc_l.emitting)
	_check("the dagger cuts", cut)
	_check("and the other hand's cuts the air with it", both)


func _wait(n: int) -> void:
	for i in n:
		await physics_frame


func _check(what: String, ok: bool, detail: String = "") -> void:
	print("  %s - %s %s" % ["ok  " if ok else "FAIL", what, detail])
	if not ok:
		_failures += 1
