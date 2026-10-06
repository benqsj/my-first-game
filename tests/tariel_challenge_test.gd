extends SceneTree

## Tariel (the user's word, 2026-10-06): the least blow and the longest stand
## with his shield; without it, its p.def gone and his cuts worth more. His
## fourth skill, the Challenge ([TarielChallenge]): every
## creature within reach comes for him alone for a while, a creature further
## off does not, and his p.def stands higher meanwhile.
##
##     godot --path . --headless --script res://tests/tariel_challenge_test.gd

const WORLD := "res://scenes/world/greybox_world.tscn"
const IMP := "res://scenes/enemies/imp.tscn"

var _failures := 0
var _world: Node3D
var _player: Player


func _initialize() -> void:
	await process_frame
	var game := root.get_node_or_null("Game")
	if game != null:
		game.call("choose", &"tariel")
	_world = load(WORLD).instantiate()
	root.add_child(_world)
	await _wait(40)
	_player = (_world as World).player()
	for body in _world.find_children("*", "CharacterBody3D", true, false):
		if body != _player:
			body.queue_free()
	await _wait(30)
	for i in 300:
		if _player.state == Player.State.GROUNDED and not _player.is_committed():
			break
		await physics_frame

	var tariel := load("res://scenes/player/tariel.tres") as CharacterProfile
	var knight := load("res://scenes/player/warrior.tres") as CharacterProfile
	_check("his blow the least of the swords", tariel.damage < knight.damage, "%.0f" % tariel.damage)
	_check("his p.def above the knight's", tariel.p_def > knight.p_def, "%.0f vs %.0f" % [tariel.p_def, knight.p_def])
	# a wolf's swipe (the user's word, 2026-10-06): Tariel with his shield
	# stands four, just, and falls to the fifth; without it, and the knight,
	# the third is on the edge
	var swipe := 110.0
	var shielded := Defence.taken(swipe, tariel.p_def)
	_check("a wolf: four swipes leave him standing, the fifth is the end",
			shielded * 4.0 < tariel.max_health and shielded * 5.0 >= tariel.max_health,
			"%.1f a swipe, %.0f health" % [shielded, tariel.max_health])
	var unshielded := Defence.taken(swipe, tariel.p_def - tariel.shield_p_def)
	_check("without his shield the third is the end", unshielded * 2.0 < tariel.max_health
			and unshielded * 3.0 >= tariel.max_health, "%.1f a swipe" % unshielded)
	var knights := Defence.taken(swipe, knight.p_def)
	_check("the knight stands three, only just", knights * 3.0 < knight.max_health
			and knights * 3.0 > knight.max_health - 10.0, "%.1f a swipe, %.0f health" % [knights, knight.max_health])

	_check("with his shield: all his p.def", is_equal_approx(_player.shield_def_off(), 0.0))
	var dressed := _player.look.duplicate(true)
	var bare := dressed.duplicate(true)
	bare["o"] = "none"
	_player.set_look(bare)
	await _wait(10)
	_check("without it: the shield's p.def gone", is_equal_approx(_player.shield_def_off(), tariel.shield_p_def)
			and tariel.shield_p_def > 0.0, "%.0f" % _player.shield_def_off())
	_check("and his cut worth more", tariel.bare_damage > 1.0)
	_player.set_look(dressed)
	await _wait(10)

	_check("the Challenge on his fourth", _player.skill_in(3) == &"challenge")
	var near := _creature(_ahead(6.0) + _side() * 2.0)
	var far := _creature(_ahead(16.0))
	await _wait(10)
	near.set_physics_process(false)
	far.set_physics_process(false)
	var other := Node3D.new()
	other.add_to_group(&"player")
	_world.add_child(other)
	other.global_position = near.global_position + _side() * 1.0
	near.set("_quarry", other)
	_check("before it: the near one is after someone else", near.call(&"_pick_quarry") == other)
	_player._skill_ready_at.clear()
	_player.stamina = _player.max_stamina
	var had := _player.stamina
	_check("it goes", _player.use_skill(3))
	_check("for 20 stamina", absf(had - _player.stamina - 20.0) < 0.5)
	_check("20 s before the next", absf(_player.skill_cooldown_left(3) - 20.0) < 0.5)
	await _wait(int((TarielChallenge.RING_AT + 0.1) * 60.0))
	_check("the near one turns on him", near.call(&"_pick_quarry") == _player)
	_check("the far one does not", TarielChallenge.dared(far) == null)
	_check("his p.def stands higher", is_equal_approx(TarielChallenge.guard(_player), TarielChallenge.GUARD))
	var hurt_before := _player.health
	_player.net_blow(30.0, Vector3.FORWARD, near.global_position, "t#1", 0, 1, false)
	var took := hurt_before - _player.health
	var plain := Defence.taken(30.0, _player.p_def)
	_check("a blow on him takes less", took > 0.0 and took < plain - 0.5, "%.1f vs %.1f" % [took, plain])
	await _wait(int(TarielChallenge.TIME * 60.0))
	_check("it runs out: dared no more", TarielChallenge.dared(near) == null)
	_check("and his p.def as it was", is_equal_approx(TarielChallenge.guard(_player), 1.0))
	other.queue_free()
	print("")
	if _failures == 0:
		print("All checks passed.")
	else:
		print("%d check(s) FAILED." % _failures)
	quit(1 if _failures > 0 else 0)


func _creature(at: Vector3) -> Node3D:
	var ground := at
	var hit := _player.get_world_3d().direct_space_state.intersect_ray(
			PhysicsRayQueryParameters3D.create(at + Vector3.UP * 20.0, at + Vector3.DOWN * 40.0, 1))
	if not hit.is_empty():
		ground = hit["position"]
	var c: Node3D = (load(IMP) as PackedScene).instantiate()
	c.position = _world.to_local(ground + Vector3.UP * 0.05)
	_world.add_child(c)
	for k in ["speed", "chase_speed", "dash_chance"]:
		c.set(k, 0.0)
	c.set("camp_centre", c.global_position)
	return c


func _fwd() -> Vector3:
	var f := -_player.global_basis.z
	f.y = 0.0
	return f.normalized()


func _side() -> Vector3:
	return _fwd().cross(Vector3.UP)


func _ahead(d: float) -> Vector3:
	return _player.global_position + _fwd() * d


func _wait(n: int) -> void:
	for i in n:
		await physics_frame


func _check(what: String, ok: bool, detail: String = "") -> void:
	if not ok:
		_failures += 1
	print("  %s - %s %s" % ["ok  " if ok else "FAIL", what, detail])
