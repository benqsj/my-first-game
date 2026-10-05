extends SceneTree

## The assassin's skills ([RogueSkills], claude/assassin_buff_plan.md S1-S2):
## the Poisoned Blade's five stacks and the boil, one knife of two poisoned,
## the dark elf's violet; the backstab (x2.2, a boss x1.5); the Shadow Step
## behind what is locked, and ahead with nothing; Vanish — the creatures lose
## him, his cut ends it and is a sure critical, a blow ends it, it runs out.
##
##     godot --path . --headless --script res://tests/rogue_skills_test.gd

const WORLD := "res://scenes/world/greybox_world.tscn"
const IMP := "res://scenes/enemies/imp.tscn"
const ORC := "res://scenes/enemies/orc.tscn"

var _failures := 0
var _world: Node3D
var _player: Player


func _initialize() -> void:
	await process_frame
	await _spawn(&"rogue")
	_check("his bar: the poisoned blade, the shadow step, vanish",
			_player.skill_in(0) == &"poison_blade" and _player.skill_in(1) == &"shadow_step"
			and _player.skill_in(2) == &"vanish" and _player.skill_in(3) == &"")
	_check("the backstab is his", is_equal_approx(_player.profile.backstab, 2.2))
	await _check_poison()
	await _check_backstab()
	await _check_step()
	await _check_vanish()
	await _spawn(&"dark_rogue")
	_check("the dark elf has the same bar", _player.skill_in(1) == &"shadow_step" and _player.skill_in(2) == &"vanish")
	await _check_dark()
	print("")
	if _failures == 0:
		print("All checks passed.")
	else:
		print("%d check(s) FAILED." % _failures)
	quit(1 if _failures > 0 else 0)


func _check_poison() -> void:
	var imp := _creature(IMP, _ahead(1.8)) as Fighter
	imp.max_health = 2000.0
	imp.health = 2000.0
	await _wait(10)
	await _ready_up()
	_check("the blade is coated", _player.use_skill(0))
	await _wait(60)
	_check("and it poisons", _player.is_venomous())
	for i in 4:
		_player.blade_hit(imp, imp.global_position + Vector3.UP)
		await _wait(3)
	var marks := Afflictions.of(imp, false)
	_check("four cuts, four stacks", marks != null and marks.poison_stacks() == 4,
			str(marks.poison_stacks() if marks != null else -1))
	var was: float = imp.health
	_player.blade_hit(imp, imp.global_position + Vector3.UP)
	await _wait(2)
	var took := was - float(imp.health)
	marks = Afflictions.of(imp, false)
	_check("the fifth boils it: the stacks gone", marks != null and marks.poison_stacks() == 0,
			str(marks.poison_stacks() if marks != null else -1))
	_check("and 50 off it at once (5 a stack, five stacks, two seconds; its m.def takes some)", took >= 40.0 and took < 60.0,
			"%.1f" % took)
	for i in 5:
		_player.blade_hit(imp, imp.global_position + Vector3.UP)
		await _wait(3)
	_check("not again so soon: five stacks held", marks != null and marks.poison_stacks() == 5,
			str(marks.poison_stacks() if marks != null else -1))
	was = imp.health
	await _wait(60)
	var ticked := was - float(imp.health)
	_check("five stacks are 25 a second (less its m.def)", ticked > 18.0 and ticked < 30.0, "%.1f in 1 s" % ticked)
	_check("green", marks != null and marks.venom_color.is_equal_approx(RogueSkills.HUMAN_VENOM))
	var rig := _player.rig as SkinnedRogueRig
	_check("one knife: every cut is the coated one's", rig != null and not rig.cut_by_off_hand())
	if rig != null and rig.two_blades():
		rig._left_edge = true
		var fresh := _creature(IMP, _ahead(3.0))
		await _wait(3)
		_player.blade_hit(fresh, fresh.global_position)
		_check("two knives: the left one's cut does not poison", Afflictions.of(fresh, false) == null)
		rig._left_edge = false
		fresh.queue_free()
	_player._venom_until = 0.0
	imp.queue_free()
	await _wait(10)


func _check_backstab() -> void:
	var imp := _creature(IMP, _ahead(1.5)) as Fighter
	await _wait(5)
	imp.set_physics_process(false)
	imp.set_process(false)
	var crit := _player.profile.crit_chance
	_player.profile.crit_chance = 0.0
	var face_on: Array = _player.cut_worth(imp)
	_check("face to face no backstab", not bool(face_on[1]) and not RogueSkills.behind(_player, imp))
	imp.look_at(imp.global_position + (imp.global_position - _player.global_position), Vector3.UP)
	var stab: Array = _player.cut_worth(imp)
	_check("from behind a critical", bool(stab[1]) and RogueSkills.behind(_player, imp))
	_check("worth 2.2 times", absf(float(stab[0]) / float(face_on[0]) - 2.2) < 0.01,
			"%.2f" % (float(stab[0]) / float(face_on[0])))
	# 50 degrees off straight behind still is; 80 is not
	imp.rotate_y(deg_to_rad(50.0))
	_check("50 degrees off behind still", RogueSkills.behind(_player, imp))
	imp.rotate_y(deg_to_rad(30.0))
	_check("80 not", not RogueSkills.behind(_player, imp))
	_check("the kick and the bash (no target) are no backstab", not bool(_player.cut_worth()[1]))
	imp.queue_free()
	var orc := _creature(ORC, _ahead(2.0))
	await _wait(5)
	orc.set_physics_process(false)
	orc.look_at(orc.global_position + (orc.global_position - _player.global_position), Vector3.UP)
	var boss: Array = _player.cut_worth(orc)
	_check("a boss from behind only 1.5 times", absf(float(boss[0]) / float(face_on[0]) - 1.5) < 0.01,
			"%.2f" % (float(boss[0]) / float(face_on[0])))
	_player.profile.crit_chance = crit
	orc.queue_free()
	await _wait(10)


func _check_step() -> void:
	var imp := _creature(IMP, _ahead(8.0)) as Fighter
	await _wait(10)
	imp.set_physics_process(false)
	await _ready_up()
	_player.call("_hold_target", imp)
	var had := _player.stamina
	var whole: float = imp.health
	_check("the shadow step goes", _player.use_skill(1))
	await _wait(2)
	var gap := _player.global_position.distance_to(imp.global_position)
	_check("he is behind it", RogueSkills.behind(_player, imp), "gap %.2f" % gap)
	_check("close", gap < 2.0, "%.2f" % gap)
	var to := imp.global_position - _player.global_position
	to.y = 0.0
	_check("facing it", (-_player.global_basis.z).dot(to.normalized()) > 0.95)
	_check("for 20 stamina", absf(had - _player.stamina - 20.0) < 1.0, "%.1f" % (had - _player.stamina))
	_check("9 s before the next", absf(_player.skill_cooldown_left(1) - 9.0) < 0.2)
	await _wait(20)
	_check("and he puts the knife in its back", is_instance_valid(imp) and float(imp.health) < whole,
			"%.0f -> %.0f" % [whole, float(imp.health) if is_instance_valid(imp) else -1.0])
	_player.target = null
	imp.queue_free()
	await _wait(10)
	await _ready_up()
	var from := _player.global_position
	var fwd := _fwd()
	_check("with nothing there, a step ahead", _player.use_skill(1))
	await _wait(2)
	var went := _player.global_position - from
	went.y = 0.0
	# six metres, or short of whatever stands in the way
	_check("up to six metres the way he faces", went.length() > 1.4 and went.length() < 6.5
			and went.normalized().dot(fwd) > 0.9, "%.2f" % went.length())
	_check("whoever had him has lost him for a moment", _player.is_hidden() and Brute.unseen(_player))
	await _wait(100)
	_check("then he is there again", not _player.is_hidden())


func _check_vanish() -> void:
	var imp := _creature(IMP, _ahead(4.0)) as Fighter
	imp.set("sight_range", 20.0)
	imp.set("camp_centre", imp.global_position)
	await _wait(10)
	await _ready_up()
	var seen: Node3D = imp.call("_pick_quarry")
	_check("the imp sees him", seen == _player)
	_check("40 s before vanish comes back", is_equal_approx(_player.skill_cooldown(2), 40.0))
	_check("vanish goes", _player.use_skill(2))
	await _wait(2)
	_check("he is gone", _player.is_hidden())
	_check("the imp does not go for him", imp.call("_pick_quarry") == null)
	_check("nor do the orcs or the wolves", Brute.unseen(_player))
	_check("a ghost of him drawn", _ghosts() > 0, str(_ghosts()))
	_player.attack_started.emit()
	await _wait(2)
	_check("his cut ends it", not _player.is_hidden())
	_check("drawn whole again", _ghosts() == 0, str(_ghosts()))
	var crit := _player.profile.crit_chance
	_player.profile.crit_chance = 0.0
	var out: Array = _player.cut_worth()
	var next: Array = _player.cut_worth()
	_check("the cut out of it is a critical", bool(out[1]))
	_check("only that one", not bool(next[1]))
	_player.profile.crit_chance = crit
	await _ready_up()
	_check("vanish again", _player.use_skill(2))
	await _wait(2)
	_player.struck.emit(5.0, false)
	await _wait(2)
	_check("a blow taken ends it", not _player.is_hidden())
	await _ready_up()
	_player.use_skill(2)
	await _wait(2)
	_player.rogue()._hiding_until = 0.0
	await _wait(3)
	_check("and it runs out", not _player.is_hidden())
	_check("the imp sees him again", imp.call("_pick_quarry") == _player)
	imp.queue_free()
	await _wait(10)


func _check_dark() -> void:
	var imp := _creature(IMP, _ahead(1.8)) as Fighter
	await _wait(10)
	await _ready_up()
	_check("the dark elf coats his blade", _player.use_skill(0))
	await _wait(60)
	_player.blade_hit(imp, imp.global_position + Vector3.UP)
	await _wait(2)
	var marks := Afflictions.of(imp, false)
	_check("his venom is violet", marks != null and marks.venom_color.is_equal_approx(RogueSkills.DARK_VENOM))
	var blade := _world.find_children("VenomBlade", "", true, false)
	_check("on the knife too", not blade.is_empty() and (blade[0] as VenomBlade).tint.is_equal_approx(RogueSkills.DARK_VENOM))
	imp.queue_free()
	await _wait(5)


## How many of his meshes are drawn thinned (a blended ghost material, or
## the node's own transparency).
func _ghosts() -> int:
	var n := 0
	# (his own meshes: not the shadow trail's copies, which fade on their own)
	for g in _player.find_children("*", "GeometryInstance3D", true, false):
		var gi := g as GeometryInstance3D
		if _player.rogue()._shed(gi):
			continue
		if gi.transparency > 0.3:
			n += 1
			continue
		var mi := gi as MeshInstance3D
		if mi == null:
			continue
		for k in mi.get_surface_override_material_count():
			var m := mi.get_surface_override_material(k)
			if m != null and m.has_meta(&"cloak"):
				n += 1
				break
	return n


func _creature(path: String, at: Vector3) -> Node3D:
	var ground := at
	var hit := _player.get_world_3d().direct_space_state.intersect_ray(
			PhysicsRayQueryParameters3D.create(at + Vector3.UP * 20.0, at + Vector3.DOWN * 40.0, 1))
	if not hit.is_empty():
		ground = hit["position"]
	var c: Node3D = (load(path) as PackedScene).instantiate()
	c.position = _world.to_local(ground + Vector3.UP * 0.05)
	_world.add_child(c)
	if c is Fighter:
		c.set("speed", 0.0)
		c.set("chase_speed", 0.0)
		c.set("dash_chance", 0.0)
		c.set("sight_range", 0.0)
	c.look_at(Vector3(_player.global_position.x, at.y, _player.global_position.z), Vector3.UP)
	return c


func _fwd() -> Vector3:
	var f := -_player.global_transform.basis.z
	f.y = 0.0
	return f.normalized()


func _ahead(d: float) -> Vector3:
	return _player.global_position + _fwd() * d


func _ready_up() -> void:
	for i in 200:
		if _player.state == Player.State.GROUNDED and not _player.is_committed():
			break
		await physics_frame
	_player._skill_ready_at.clear()
	_player.stamina = _player.max_stamina
	_player.health = _player.max_health


func _spawn(id: StringName) -> void:
	if _world != null:
		_world.queue_free()
		await _wait(2)
	var game := root.get_node_or_null("Game")
	if game != null:
		game.call("choose", id)
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


func _wait(n: int) -> void:
	for i in n:
		await physics_frame


func _check(what: String, ok: bool, detail: String = "") -> void:
	if not ok:
		_failures += 1
	print("  %s - %s %s" % ["ok  " if ok else "FAIL", what, detail])
