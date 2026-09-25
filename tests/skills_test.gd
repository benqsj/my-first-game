extends SceneTree

## The skills: the keys (the evade on Command on a Mac and Control elsewhere,
## the skills on 1 to 5), the bar's slots, and Avtandil's Rain of Arrows — a
## ring where he is facing, a volley over it that hurts what stands in it, the
## stamina it costs and the cooldown after it.
##
##     godot --path . --headless --script res://tests/skills_test.gd

const WORLD := "res://scenes/world/greybox_world.tscn"

var _failures := 0
var _world: Node3D
var _player: Player
var _dummy_script: GDScript


func _initialize() -> void:
	await process_frame
	_check_keys()
	await _spawn(&"tariel")
	_check("Tariel has no skill in the first slot yet", _player.skill_in(0) == &"")
	_check("and pressing 1 does nothing", not _player.use_skill(0))
	await _spawn(&"avtandil")
	await _check_rain()
	print("")
	if _failures == 0:
		print("All checks passed.")
	else:
		print("%d check(s) FAILED." % _failures)
	quit(1 if _failures > 0 else 0)


func _check_keys() -> void:
	var dodge := Controls.dodge_key()
	_check("the evade is on %s" % Controls.dodge_name(), _has_key(&"dash", dodge))
	_check("and on nothing else on the keyboard", _key_count(&"dash") == 1)
	_check("walking is off the evade's key", not _has_key(&"walk", dodge) and _has_key(&"walk", Controls.walk_key()))
	_check("there are five skill slots", Player.SKILL_SLOTS == 5 and Controls.SKILL_KEYS.size() == 5)
	for i in 5:
		_check("skill %d is on key %d" % [i + 1, i + 1], _has_key(StringName("skill_%d" % (i + 1)), Controls.SKILL_KEYS[i]))
	_check("the gamepad still evades", _pad_count(&"dash") > 0)


func _check_rain() -> void:
	_check("Avtandil's first skill is the Rain of Arrows", _player.skill_in(0) == &"arrow_rain")
	_check("the other four slots are empty", _player.skill_in(1) == &"" and _player.skill_in(4) == &"")
	await _wait(30)
	var fwd := -_player.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var side := fwd.cross(Vector3.UP)
	_player.stamina = _player.max_stamina
	var used := [0]
	var on_used := func(_s: int, _id: StringName) -> void: used[0] += 1
	_player.skill_used.connect(on_used)
	Input.action_press("skill_1")
	await physics_frame
	await physics_frame
	Input.action_release("skill_1")
	_check("pressing 1 lets it go", used[0] == 1, "%d" % used[0])
	_check("it costs stamina", _player.stamina < _player.max_stamina - 20.0, "%.0f" % _player.stamina)
	_check("and it has to come back", _player.skill_cooldown_left(0) > 11.0, "%.1f s" % _player.skill_cooldown_left(0))
	_check("he shoots into the sky first", String(_player.rig._act_clip) == "AV_Sky_Shot",
			String(_player.rig._act_clip))
	var rain := await _find_rain(200)
	_check("when the string goes, the rain comes, ahead of him", rain != null)
	_check("and nothing is drawn on the ground for it", rain == null or rain.find_children("*", "MeshInstance3D", true, false).is_empty())
	if rain != null:
		var off := rain.global_position - _player.global_position
		off.y = 0.0
		_check("where he is facing", off.dot(fwd) > _player.rain_ahead - 1.0 and absf(off.dot(side)) < 1.0,
				"%.1f ahead, %.1f aside" % [off.dot(fwd), off.dot(side)])
	# Bodies in the ring (and one well outside it), before the arrows fall.
	var centre := rain.global_position if rain != null else _player.global_position + fwd * 9.0
	var dummies: Array = []
	for off2: Vector3 in [Vector3.ZERO, side * 1.6, -side * 1.8, fwd * 1.5]:
		var d := _dummy()
		_world.add_child(d)
		d.global_position = centre + off2
		dummies.append(d)
	var far := _dummy()
	_world.add_child(far)
	far.global_position = centre + side * 9.0
	await _wait(150)
	if rain != null and is_instance_valid(rain):
		_check("a volley comes down", rain.arrows.size() == rain.count, "%d arrows" % rain.arrows.size())
	var hits := 0
	for d in dummies:
		hits += int(d.get("hits"))
	_check("and hurts what stands under it", hits >= 3, "%d hits on four bodies" % hits)
	_check("but not what stands well outside it", int(far.get("hits")) == 0, "%d" % int(far.get("hits")))
	Input.action_press("skill_1")
	await physics_frame
	await physics_frame
	Input.action_release("skill_1")
	_check("pressed again while it comes back, nothing", used[0] == 1)
	_player._skill_ready_at.clear()
	_player.stamina = _player.max_stamina
	_check("ready again, it goes", _player.use_skill(0))
	_player.skill_used.disconnect(on_used)
	await _wait(300)
	# Locked on something in reach, the rain goes to it and follows it.
	var quarry := _dummy()
	_world.add_child(quarry)
	quarry.global_position = _player.global_position + fwd * 13.0 + side * 3.0
	await _wait(3)
	_player.call("_hold_target", quarry)
	_player._skill_ready_at.clear()
	_player.stamina = _player.max_stamina
	_check("locked, it goes", _player.use_skill(0))
	var locked_rain := await _find_rain(200)
	quarry.global_position += side * 2.5
	await _wait(20)
	if locked_rain != null and is_instance_valid(locked_rain):
		var gap := locked_rain.global_position - quarry.global_position
		gap.y = 0.0
		_check("it falls on what he has locked, and follows it", gap.length() < 0.5, "%.2f m off" % gap.length())
	await _wait(150)
	_check("and hurts it", int(quarry.get("hits")) >= 2, "%d hits" % int(quarry.get("hits")))


func _find_rain(frames: int) -> ArrowRain:
	for i in frames:
		for n in _world.find_children("*", "ArrowRain", true, false):
			if not (n as ArrowRain).is_queued_for_deletion() and (n as ArrowRain)._sent == 0:
				return n as ArrowRain
		await physics_frame
	return null


func _has_key(action: StringName, key: Key) -> bool:
	for e in InputMap.action_get_events(action):
		if e is InputEventKey and ((e as InputEventKey).physical_keycode == key or (e as InputEventKey).keycode == key):
			return true
	return false


func _key_count(action: StringName) -> int:
	var n := 0
	for e in InputMap.action_get_events(action):
		if e is InputEventKey:
			n += 1
	return n


func _pad_count(action: StringName) -> int:
	var n := 0
	for e in InputMap.action_get_events(action):
		if e is InputEventJoypadButton:
			n += 1
	return n


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


func _dummy() -> CharacterBody3D:
	if _dummy_script == null:
		_dummy_script = GDScript.new()
		_dummy_script.source_code = "extends CharacterBody3D\nvar hits := 0\n" \
				+ "func take_hit(_d: float, _at: Vector3, _b: Vector3, _c: bool = false, _h: bool = false, _f: Node3D = null) -> void:\n\thits += 1\n"
		_dummy_script.reload()
	var body := CharacterBody3D.new()
	body.set_script(_dummy_script)
	body.collision_layer = 4
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.8
	shape.shape = capsule
	shape.position = Vector3(0.0, 0.9, 0.0)
	body.add_child(shape)
	return body


func _wait(n: int) -> void:
	for i in n:
		await physics_frame


func _check(what: String, ok: bool, detail: String = "") -> void:
	if not ok:
		_failures += 1
	print("  %s - %s %s" % ["ok  " if ok else "FAIL", what, detail])
