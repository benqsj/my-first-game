extends SceneTree

## Health, stamina, the parry and falling: what the player's body can take,
## what it costs, and what a blow thrown back off the shield does to whoever
## threw it.
##
##     godot --path . --headless --script res://tests/vitals_test.gd

var _failures := 0
var _player: Player


func _initialize() -> void:
	var game := root.get_node_or_null("Game")
	if game != null:
		game.call("choose", &"tariel")
	var world: World = load("res://scenes/world/greybox_world.tscn").instantiate()
	root.add_child(world)
	await _wait(2)
	world.creature_think_distance = 0.0
	_player = world.player()
	var enemies := world.get_node("Enemies")
	var imp: Fighter = null
	var orc: OrcWarrior = null
	var ark: Arkdeva = null
	for node in enemies.get_children():
		(node as Node).set_physics_process(false)
		(node as Node3D).global_position += Vector3(0.0, -50.0, 0.0)
		if node is Fighter and imp == null:
			imp = node
		elif node is OrcWarrior and orc == null:
			orc = node
		elif node is Arkdeva:
			ark = node
	await _wait(40)

	# --- The pools ---------------------------------------------------------------
	var profile := _player.profile
	_check("health comes from the character", _player.max_health == profile.max_health
			and _player.health == _player.max_health, "%.0f of %.0f" % [_player.health, _player.max_health])
	_check("and so does stamina", _player.stamina == _player.max_stamina and _player.max_stamina > 0.0)
	_check("his own bars are drawn", _player.get_node_or_null("Hud") is PlayerHud)
	_check("he knows where he started", _player._spawn_known)
	var spawn := _player._spawn_point

	# --- Stamina -----------------------------------------------------------------
	_player._dash_cooldown_timer = 0.0
	_player._try_dash()
	_check("a roll costs stamina", is_equal_approx(_player.stamina, _player.max_stamina - profile.roll_stamina),
			"%.1f" % _player.stamina)
	await _wait(120)
	_check("and it comes back", _player.stamina >= _player.max_stamina - 0.01, "%.1f" % _player.stamina)
	_player.stamina = 0.0
	_player._winded = true
	_player._dash_cooldown_timer = 0.0
	var was := _player.state
	_player._try_dash()
	_check("with none left there is no rolling", _player.state == was)
	_player.stamina = _player.max_stamina
	_player._winded = false

	# --- Blows -------------------------------------------------------------------
	imp.global_position = _player.global_position - _player.global_transform.basis.z * 1.5
	var away := _player.global_transform.basis.z
	var path := String(imp.get_path())
	_player.net_blow(10.0, away, imp.global_position, "%s#1" % path, 0, 3)
	_check("an unguarded blow takes health", is_equal_approx(_player.health, _player.max_health - 10.0),
			"%.1f" % _player.health)
	await _wait(30)

	_player.is_blocking = true
	_player._guard_raised_at = _player._now()
	_player._last_parry_move = _player._now() - 5.0
	var before := _player.health
	_in_front(imp)
	_player.net_blow(10.0, away, imp.global_position, "%s#2" % path, 0, 3)
	_check("one caught on the shield takes none", _player.health == before)
	_check("but holding it costs stamina", is_equal_approx(_player.stamina, _player.max_stamina - 10.0 * _player.block_stamina),
			"%.1f" % _player.stamina)

	# --- The parry ---------------------------------------------------------------
	var thrown_back: Array = []
	_player.parried.connect(func(who: Node3D) -> void: thrown_back.append(who))
	_player.stamina = _player.max_stamina
	_player._guard_raised_at = _player._now()
	_player._last_parry_move = _player._now()
	_in_front(imp)
	_player.net_blow(10.0, away, imp.global_position, "%s#3" % path, 0, 3)
	_check("met as the shield comes up, it is parried", thrown_back.size() == 1 and thrown_back[0] == imp,
			str(thrown_back))
	_check("which costs nothing", _player.health == before and _player.stamina == _player.max_stamina)
	_check("and the imp reels", imp.act == Fighter.Act.REEL, "act %d" % imp.act)
	var hp := imp.health
	imp._receive(20.0, imp.global_position, Vector3.UP, _player)
	_check("open, a riposte bites deeper", is_equal_approx(hp - imp.health, 20.0 * Recoil.RIPOSTE),
			"%.1f" % (hp - imp.health))
	# Its arm is thrown back: the reel is laid over whatever the clip says.
	var arm: int = imp._reel_bones.get("arm_r", -1)
	_check("the imp has an arm to throw back", arm >= 0)
	await _wait(10)
	_check("the reel runs on every frame", imp._reel_clock > 0.1, "%.2f" % imp._reel_clock)

	thrown_back.clear()
	# (The shield is only up while the button is held; ticks have gone by.)
	_player.is_blocking = true
	_player._guard_raised_at = _player._now()
	_player._last_parry_move = _player._now()
	_in_front(imp)
	_player.net_blow(10.0, away, imp.global_position, "%s#4" % path, 0, 1)
	_check("a slam (a combo of one) is only ever blocked", thrown_back.is_empty())

	_player.is_blocking = false
	_player._guard_raised_at = -100.0
	_player._last_parry_move = -100.0

	orc.parried(_player)
	_check("a parried orc reels", orc.act == Brute.ACT_REEL and orc.is_reeling())
	await _wait(5)
	_check("his axe going back the way it came", orc._own.speed_scale < 0.0, "%.1f" % orc._own.speed_scale)
	await _wait(30)
	_check("and then stands reeling", orc._own.speed_scale > 0.0 and orc._reel_clock > Recoil.REBOUND)
	ark.parried(_player)
	_check("a parried Arkdeva rears back", ark.act == Arkdeva.Act.PARRIED and ark.is_reeling())
	hp = ark.health
	ark._receive(20.0, ark.global_position, Vector3.UP, _player)
	_check("and takes a riposte deeper too", is_equal_approx(hp - ark.health, 20.0 * Recoil.RIPOSTE * (1.0 - ark.armour)),
			"%.1f" % (hp - ark.health))

	# --- The tower shield --------------------------------------------------------
	await _wait(30)
	_player.set_shield(Inventory.Shields.TOWER)
	var skinned := _player.rig as SkinnedRig
	_check("the tower shield goes on his arm, the round one off it", skinned != null
			and skinned._shield_meshes.size() == 2 and skinned._shield_meshes[1] != null
			and skinned._shield_meshes[1].visible and not skinned._shield_meshes[0].visible)
	thrown_back.clear()
	_player.stamina = _player.max_stamina
	_player.is_blocking = true
	_player._guard_raised_at = _player._now()
	_player._last_parry_move = _player._now()
	_in_front(imp)
	before = _player.health
	_player.net_blow(10.0, away, imp.global_position, "%s#t1" % path, 0, 3)
	_check("it cannot parry", thrown_back.is_empty() and _player.health == before)
	_check("but a blow on it costs little more than half the stamina", is_equal_approx(_player.stamina,
			_player.max_stamina - 10.0 * _player.block_stamina * _player.tower_block_share), "%.1f" % _player.stamina)
	_player.set_shield(Inventory.Shields.ROUND)
	_player.is_blocking = false

	# --- A perfect dodge -------------------------------------------------------
	await _wait(20)
	var perfect := [false]
	_player.perfect_dodged.connect(func() -> void: perfect[0] = true)
	_player.stamina = 50.0
	_player._dash_cooldown_timer = 0.0
	_player._try_dash()
	before = _player.health
	_player.net_blow(10.0, away, imp.global_position, "%s#pd" % path, 0, 3)
	_check("a blow in the first moments of a roll is dodged perfectly", perfect[0] and _player.health == before)
	_check("and the roll's stamina comes back", _player.stamina >= 50.0 - 0.01, "%.1f" % _player.stamina)
	await _wait(3)
	_check("the knight leaves no shadow: that is the light-footed ones' own",
			_player.get_node_or_null("ShadowTrail") == null)
	await _wait(80)

	# --- The inventory and the map ----------------------------------------------
	var bag := _player.get_node_or_null("Inventory") as Inventory
	_check("he has an inventory", bag != null)
	_check("and a map", _player.get_node_or_null("Map") is WorldMap)
	if bag != null:
		bag.toggle()
		_check("open, it holds him still", _player.menu_open and bag.is_open())
		bag.equip(Inventory.Shields.TOWER)
		_check("and a shield chosen in it goes on", _player.shield_kind == Inventory.Shields.TOWER)
		bag.equip(Inventory.Shields.ROUND)
		bag.toggle()
		_check("closed, he is free again", not _player.menu_open)

	# --- A wolf --------------------------------------------------------------------
	var wolf: Wolf = null
	for node in enemies.get_children():
		if node is Wolf:
			wolf = node
			break
	_check("wolves notice a player close, not across the field", wolf != null and wolf.sight_range <= 12.0)
	if wolf != null:
		# Close enough that its claws come through him (they land only where
		# they actually go — WeaponSweep).
		wolf.set_physics_process(false)
		wolf.global_position = _player.global_position - _player.global_transform.basis.z * 0.9
		var at_him := _player.global_position - wolf.global_position
		wolf.rotation.y = atan2(-at_him.x, -at_him.z)
		before = _player.health
		wolf.state = Wolf.State.FIGHT
		wolf._swipe_count += 1
		wolf.rig.swipe()
		wolf._arm_claws(Wolf.SWIPE_LIVE, false)
		for i in 90:
			await physics_frame
			if _player.health < before:
				break
		_check("and a wolf's claws hurt", is_equal_approx(_player.health, before - wolf.swipe_damage),
				"%.0f -> %.0f" % [before, _player.health])
		wolf.global_position += Vector3(0.0, -50.0, 0.0)
	var den := Vector3.ZERO
	var wolves := 0
	var closest := INF
	for node in enemies.get_children():
		if node is Wolf and node != wolf:
			den += (node as Node3D).global_position
			wolves += 1
	if wolves > 0:
		den /= float(wolves)
		var all_near := true
		var ws: Array[Vector3] = []
		for node in enemies.get_children():
			if node is Wolf and node != wolf:
				ws.append((node as Node3D).global_position)
				all_near = all_near and (node as Node3D).global_position.distance_to(den) < 24.0
		for i in ws.size():
			for j in range(i + 1, ws.size()):
				closest = minf(closest, ws[i].distance_to(ws[j]))
		_check("the wolves keep to one den", all_near)
		_check("but not on top of each other", closest > 3.0, "%.1f m" % closest)

	# --- Falling -----------------------------------------------------------------
	await _wait(30)
	var fell := [false]
	_player.died.connect(func() -> void: fell[0] = true)
	_player.net_blow(9999.0, away, imp.global_position, "%s#5" % path, 0, 3)
	_check("a blow worth more than he has left kills him", _player.is_dead and fell[0]
			and _player.state == Player.State.DOWNED and _player.health == 0.0)
	await _wait(3)
	_check("which every peer is told", _player.net_dead)
	_check("and the creatures leave him be", Brute._fallen(_player))
	imp.global_position = _player.global_position + Vector3(1.5, 0.0, 0.0)
	imp.mode = Fighter.Mode.GUARD
	imp._quarry = null
	_check("nothing picks a fallen player to fight", imp._pick_quarry() != _player)
	before = _player.health
	_player.net_blow(10.0, away, imp.global_position, "%s#6" % path, 0, 3)
	_check("nor can he be hurt any more", _player.health == before)

	_player.global_position = spawn + Vector3(6.0, 1.0, 0.0)
	var back := [false]
	_player.respawned.connect(func() -> void: back[0] = true)
	await _wait(int(_player.respawn_time * 60.0) + 20)
	_check("after a while he is back", back[0] and not _player.is_dead and not _player.net_dead)
	_check("whole", _player.health == _player.max_health and _player.stamina == _player.max_stamina)
	_check("where he started", _player.global_position.distance_to(spawn) < 1.0,
			"%.2f m off" % _player.global_position.distance_to(spawn))

	print("\n%s" % ("All checks passed." if _failures == 0 else "%d check(s) FAILED." % _failures))
	quit(1 if _failures else 0)


## Puts `who` a pace in front of him, so a raised shield faces it.
func _in_front(who: Node3D) -> void:
	who.global_position = _player.global_position - _player.global_transform.basis.z * 1.5


func _wait(n: int) -> void:
	for i in n:
		await physics_frame


func _check(what: String, ok: bool, detail: String = "") -> void:
	print("  %s - %s %s" % ["ok  " if ok else "FAIL", what, detail])
	if not ok:
		_failures += 1
