extends SceneTree
## TARIEL_POLISH.md 8, a blow on the shield felt, by how hard it was:
## - pushed back further by a heavy blow than a light one, less on the tower
##   shield;
## - the shield left where the guard holds it (no clip over it), his back
##   rocked over away from the blow instead (HitLean), his feet skidding (not
##   stepping) with dust off his heels; the hold (his rig and the one who
##   struck, held together), the sparks off the shield (smaller for a light
##   blow), the view knocked back and shaken;
## - the strength 0..1 from the damage.
##   Godot --headless --path . --script res://tests/block_feel_test.gd

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
	var game := root.get_node_or_null("Game")
	if game != null:
		game.call("choose", &"tariel")
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
	var rig := _player.rig as SkinnedRig
	_player.call(&"_set_weapons_stowed", false)
	await _wait(30)

	_check("strength: a light blow little, the heaviest 1", _player.block_strength(2.0) < 0.2
			and _player.block_strength(9.0) > 0.4 and _player.block_strength(9.0) < 0.6
			and _player.block_strength(40.0) == 1.0, "%.2f %.2f %.2f" % [_player.block_strength(2.0),
			_player.block_strength(9.0), _player.block_strength(40.0)])

	var light := await _block(imp, 2.0)
	var heavy := await _block(imp, 30.0)
	print("  light ", light)
	print("  heavy ", heavy)
	_check("pushed back, further by a heavy blow", float(light["shove"]) > 0.8
			and float(heavy["shove"]) > float(light["shove"]) * 2.0, "%.2f / %.2f m/s" % [light["shove"], heavy["shove"]])
	_check("the shield stays as the guard holds it: no clip over it", String(light["clip"]) == String(light["before"])
			and String(heavy["clip"]) == String(heavy["before"]), "%s / %s" % [light["clip"], heavy["clip"]])
	_check("his back rocked over away from the blow, harder for a heavy one", float(light["rock"]) > 0.02
			and float(heavy["rock"]) > float(light["rock"]), "%.3f / %.3f rad" % [light["rock"], heavy["rock"]])
	_check("his feet skid back, not stepping", bool(light["skid"]) and bool(heavy["skid"]))
	_check("dust off his heels", int(light["dust"]) >= 2 and int(heavy["dust"]) >= 2, "%d / %d" % [light["dust"], heavy["dust"]])
	_check("held, longer for a heavy blow", float(light["stop"]) > 0.02 and float(heavy["stop"]) > float(light["stop"]) + 0.04,
			"%.3f / %.3f s" % [light["stop"], heavy["stop"]])
	_check("the one who struck is held with him", bool(light["held"]) and bool(heavy["held"]))
	_check("sparks off the shield, bigger for a heavy blow", float(light["sparks"]) > 0.0
			and float(heavy["sparks"]) > float(light["sparks"]), "%.2f / %.2f" % [light["sparks"], heavy["sparks"]])
	_check("the view knocked back", bool(light["view"]) and bool(heavy["view"]))

	_player.set_shield(Inventory.Shields.TOWER)
	await _wait(10)
	var tower := await _block(imp, 30.0)
	_check("the tower shield gives way less", float(tower["shove"]) < float(heavy["shove"]) * 0.7,
			"%.2f vs %.2f m/s" % [tower["shove"], heavy["shove"]])
	_player.set_shield(Inventory.Shields.ROUND)

	if _failures == 0:
		print("All checks passed.")
	else:
		print("%d check(s) FAILED." % _failures)
	quit(1 if _failures > 0 else 0)


## A blow of `damage` from `imp` on his raised shield: what it did.
func _block(imp: Fighter, damage: float) -> Dictionary:
	await _wait(60)
	_player.stamina = _player.max_stamina
	_player.velocity = Vector3.ZERO
	# the shield up, held a while (not a parry: that is the first moments)
	Input.action_press("block")
	await _wait(40)
	imp.global_position = _player.global_position - _player.global_transform.basis.z * 1.5
	if imp.has_meta(&"bite_until"):
		imp.remove_meta(&"bite_until")
	await _wait(2)
	var flashes_before := root.find_children("*", "ParryFlash", true, false).size()
	var dust_before := root.find_children("*", "SkidDust", true, false).size()
	var before := (_player.rig as SkinnedRig)._anim.current_animation
	var cam := _player.camera
	if cam != null and cam.has_meta(&"nudge"):
		cam.remove_meta(&"nudge")
	var away := _player.global_position - imp.global_position
	away.y = 0.0
	_player.velocity = Vector3.ZERO
	_player.net_blow(damage, away.normalized(), imp.global_position, "%s#%d" % [imp.get_path(), randi()], 0, 3)
	var shove := Vector2(_player.velocity.x, _player.velocity.z).length()
	var rig := _player.rig as SkinnedRig
	var size := 0.0
	for f in root.find_children("*", "ParryFlash", true, false):
		size = maxf(size, (f as ParryFlash).size)
	var blocking := _player.is_blocking
	var got := {"blocking": blocking, "shove": shove, "clip": rig._anim.current_animation, "stop": rig._stop_left,
			"held": imp.has_meta(&"bite_until"),
			"sparks": size if root.find_children("*", "ParryFlash", true, false).size() > flashes_before else 0.0,
			"view": cam != null and cam.has_meta(&"nudge"), "feel": _player.last_block_feel.duplicate(),
			"before": before, "skid": rig.skidding(),
			"dust": root.find_children("*", "SkidDust", true, false).size() - dust_before}
	# a few frames on: how far his back is thrown over, away from the striker
	for i in 6:
		await physics_frame
	var lean := rig._mq.get("lean") as HitLean
	got["rock"] = lean.lean().dot(Vector3.UP.cross(away.normalized())) if lean != null else 0.0
	if not blocking:
		got["shove"] = -1.0  # the shield was not up
	Input.action_release("block")
	await _wait(60)
	return got
