extends SceneTree

## The skills after the Rain of Arrows — Avtandil's Hunter's Mark, Piercing
## Arrow and Fire Arrow, the Assassin's Poisoned Blade — and the creatures
## taking them: marked blows biting deeper (5% for a bow, 2% for the rest), bodies thrown back by the
## piercing shot, burning in the fire, poison stacking and ticking, and the
## orcs' own reactions (RX_* clips) in both their glbs.
##
##     godot --path . --headless --script res://tests/new_skills_test.gd

const WORLD := "res://scenes/world/greybox_world.tscn"
const IMP := "res://scenes/enemies/imp.tscn"
const ORC := "res://scenes/enemies/orc.tscn"
const GREAT := "res://scenes/enemies/orc_greataxe.tscn"

var _failures := 0
var _world: Node3D
var _player: Player


func _initialize() -> void:
	await process_frame
	await _spawn(&"avtandil")
	_check("Avtandil's slots: mark, fire, rain, piercing",
			_player.skill_in(0) == &"hunters_mark" and _player.skill_in(1) == &"fire_arrow"
			and _player.skill_in(2) == &"arrow_rain" and _player.skill_in(3) == &"piercing_arrow")
	await _check_mark()
	await _check_pierce()
	await _check_fire()
	await _check_interrupt()
	await _check_bow_dodge()
	await _spawn(&"rogue")
	_check("the Assassin's first slot is the poisoned blade", _player.skill_in(0) == &"poison_blade")
	await _check_poison()
	await _check_orc(ORC, "the axe orc")
	await _check_orc(GREAT, "the great-axe orc")
	print("")
	if _failures == 0:
		print("All checks passed.")
	else:
		print("%d check(s) FAILED." % _failures)
	quit(1 if _failures > 0 else 0)


func _check_mark() -> void:
	var imp := _creature(IMP, _ahead(8.0)) as Fighter
	await _wait(20)
	await _ready_up()
	_player.call("_hold_target", imp)
	var why := "state %d committed %s stamina %.0f cd %.1f quarry %s target %s imp %s tgt %s d %.1f" % [_player.state,
			_player.is_committed(), _player.stamina, _player.skill_cooldown_left(0), _player._skill_quarry(32.0),
			_player.target, imp, _player._targetable(imp), _player.global_position.distance_to(imp.global_position)]
	_check("the mark goes on something in front", _player.use_skill(0), why)
	await _wait(6)
	_check("he flings his free arm out at it, no lunge", _player.rig._bow_mod.point > 0.5
			and String(_player.rig._act_clip) != "AV_Point_Charge",
			"point %.2f clip %s" % [_player.rig._bow_mod.point, _player.rig._act_clip])
	_check("and is not held up by it", not _player.is_committed())
	await _wait(94)
	var marks := Afflictions.of(imp, false)
	_check("the prey is marked", marks != null and marks.is_marked())
	_check("a bow's blows on it bite 5% deeper", is_equal_approx(Afflictions.factor(imp, _player), 1.05),
			"%.3f" % Afflictions.factor(imp, _player))
	_check("anyone else's 2%", is_equal_approx(Afflictions.factor(imp, null), 1.02),
			"%.3f" % Afflictions.factor(imp, null))
	var before: float = imp.health
	imp.take_dot(10.0, _player)
	_check("so 10 from the archer costs it 10.5", absf(before - float(imp.health) - 10.5) < 0.01,
			"%.2f" % (before - float(imp.health)))
	before = imp.health
	imp.take_dot(10.0, null)
	_check("and 10 from anyone else 10.2", absf(before - float(imp.health) - 10.2) < 0.01,
			"%.2f" % (before - float(imp.health)))
	_check("the body is left as it was: no outline", not _overlaid(imp))
	_check("nothing on the ground under it", marks != null
			and marks.find_children("*", "MeshInstance3D", true, false).all(
				func(m: Node) -> bool: return m.is_inside_tree() and (m as Node3D).global_position.y > imp.global_position.y + 0.8))
	_check("and the sigil hangs over its head", marks != null and not marks.find_children("Sigil", "", true, false).is_empty())
	var sig := marks.find_children("Sigil", "", true, false)[0] as Node3D if marks != null else null
	var above := sig.global_position.y - imp.global_position.y if sig != null else 0.0
	_check("just over the head, not floating off", above > 1.2 and above < 3.0, "%.2f m over its feet" % above)
	imp.queue_free()
	await _wait(5)
	var none := _creature(IMP, _ahead(60.0))
	await _wait(3)
	_player.target = null
	await _ready_up()
	_check("with nothing in reach the mark does not go (and costs nothing)", not _player.use_skill(0)
			and _player.stamina >= _player.max_stamina - 0.01)
	none.queue_free()
	await _wait(60)


func _check_pierce() -> void:
	var near := _creature(IMP, _ahead(7.0)) as Fighter
	var far := _creature(IMP, _ahead(12.0)) as Fighter
	# Enough health to live through a critical piercing shot, which would
	# otherwise kill them before they could be seen thrown down.
	for c: Fighter in [near, far]:
		c.max_health = 500.0
		c.health = 500.0
	await _wait(10)
	var was_near := _along(near)
	var was_far := _along(far)
	await _ready_up()
	_player.call("_hold_target", near)
	_check("the piercing arrow goes", _player.use_skill(3))
	# Held forward through the draw: he stays where he is.
	var stood := _player.global_position
	Input.action_press("move_forward")
	var knocked := [false, false]
	for i in 160:
		await physics_frame
		if i == 70:
			var moved := Vector2(_player.global_position.x - stood.x, _player.global_position.z - stood.z).length()
			Input.action_release("move_forward")
			_check("drawing the skill shot he does not walk", moved < 0.05, "%.2f m" % moved)
			_check("the string is drawn, the arrow on it", _player.rig._bow_mod.draw > 0.9
					and _player.rig._bow_mod.arrow.visible, "draw %.2f" % _player.rig._bow_mod.draw)
		if is_instance_valid(near) and int(near.act) == Fighter.Act.REACT_KNOCK:
			knocked[0] = true
		if is_instance_valid(far) and int(far.act) == Fighter.Act.REACT_KNOCK:
			knocked[1] = true
	_check("it goes through the first", is_instance_valid(near) and float(near.health) < float(near.max_health))
	_check("and on into the second", is_instance_valid(far) and float(far.health) < float(far.max_health))
	_check("both are thrown down", knocked[0] and knocked[1], "%s near %s far %s" % [str(knocked),
			"%.0f/%.0f dead %s" % [near.health, near.max_health, near.is_dead] if is_instance_valid(near) else "gone",
			"%.0f/%.0f dead %s" % [far.health, far.max_health, far.is_dead] if is_instance_valid(far) else "gone"])
	if is_instance_valid(near):
		_check("and back", _along(near) > was_near + 0.4, "%.2f -> %.2f" % [was_near, _along(near)])
	if is_instance_valid(far):
		_check("the far one too", _along(far) > was_far + 0.3, "%.2f -> %.2f" % [was_far, _along(far)])
	for c in [near, far]:
		if is_instance_valid(c):
			(c as Node).queue_free()
	await _wait(60)


## The hunter's evades: locked on and going left or right, the long dodge at
## once; any other way, a roll; and no double tap.
func _check_bow_dodge() -> void:
	var imp := _creature(IMP, _ahead(9.0)) as Fighter
	await _wait(10)
	await _ready_up()
	_player.call("_hold_target", imp)
	Input.action_press("move_right")
	await _wait(2)
	_player.call("_press_dash")
	await _wait(2)
	_check("locked, going right: the dodge at once", _player.state == Player.State.DODGING, "state %d" % _player.state)
	Input.action_release("move_right")
	await _wait(80)
	await _ready_up()
	_player.set("_dash_cooldown_timer", 0.0)
	Input.action_press("move_back")
	await _wait(2)
	_player.call("_press_dash")
	await _wait(2)
	_check("locked, going back: a roll", _player.state == Player.State.DASHING, "state %d" % _player.state)
	_player.call("_press_dash")
	await _wait(2)
	_check("and a second tap does not make it a dodge", _player.state != Player.State.DODGING,
			"state %d" % _player.state)
	Input.action_release("move_back")
	await _wait(80)
	_player.target = null
	await _ready_up()
	_player.set("_dash_cooldown_timer", 0.0)
	Input.action_press("move_left")
	await _wait(2)
	_player.call("_press_dash")
	await _wait(2)
	_check("not locked, going left: a roll", _player.state == Player.State.DASHING, "state %d" % _player.state)
	Input.action_release("move_left")
	imp.queue_free()
	await _wait(80)


## Hit while drawing the Piercing Arrow: the shot never goes.
func _check_interrupt() -> void:
	var imp := _creature(IMP, _ahead(9.0)) as Fighter
	await _wait(10)
	await _ready_up()
	_player.call("_hold_target", imp)
	_check("the piercing arrow is drawn", _player.use_skill(3))
	await _wait(30)
	_player.net_react(Player.Reaction.FLINCH, _player.global_position + Vector3.UP, Vector3.BACK)
	var shots := 0
	for i in 150:
		await physics_frame
		shots += _world.find_children("*", "", true, false).filter(
				func(n: Node) -> bool: return n is PiercingShot).size()
	_check("hit mid-draw, the shot never goes", shots == 0, "%d frames with a shot" % shots)
	_check("and the string is let down", _player.rig._bow_mod.draw < 0.05, "%.2f" % _player.rig._bow_mod.draw)
	imp.queue_free()
	await _wait(10)


func _check_fire() -> void:
	var imp := _creature(IMP, _ahead(10.0)) as Fighter
	await _wait(10)
	await _ready_up()
	_player.call("_hold_target", imp)
	_check("the fire arrow goes", _player.use_skill(1))
	var zone: Node = null
	var burnt := false
	var reacted := false
	var was: float = imp.health
	for i in 240:
		await physics_frame
		if zone == null:
			var found := _world.find_children("FireZone", "", true, false)
			if not found.is_empty():
				zone = found[0]
		if is_instance_valid(imp):
			var marks := Afflictions.of(imp, false)
			if marks != null and marks.is_burning():
				burnt = true
			if int(imp.act) == Fighter.Act.REACT_BURN:
				reacted = true
	_check("it comes down and the ground burns", zone != null)
	if zone != null and is_instance_valid(zone):
		var off := (zone as Node3D).global_position - imp.global_position
		off.y = 0.0
		_check("where it was aimed", off.length() < 2.0, "%.1f m off" % off.length())
	_check("what stands in it catches fire", burnt)
	_check("and flails", reacted)
	_check("and burns", is_instance_valid(imp) and float(imp.health) < was - 10.0,
			"%.0f -> %.0f" % [was, float(imp.health) if is_instance_valid(imp) else -1.0])
	if is_instance_valid(imp):
		imp.queue_free()
	await _wait(30)


func _check_poison() -> void:
	var imp := _creature(IMP, _ahead(1.8)) as Fighter
	imp.set("sight_range", 0.0)
	await _wait(10)
	await _ready_up()
	_check("the blade is coated", _player.use_skill(0))
	_check("from a vial (DG_Poison_Coat)", String(_player.rig._act_clip) == "DG_Poison_Coat",
			String(_player.rig._act_clip))
	await _wait(20)
	_check("the venom is drawn on it", not _world.find_children("VenomBlade", "", true, false).is_empty())
	await _wait(40)
	_check("and it poisons", _player.is_venomous())
	var was: float = imp.health
	for i in 4:
		_player.blade_hit(imp, imp.global_position + Vector3.UP)
		await _wait(6)
	var marks := Afflictions.of(imp, false)
	_check("cuts put stacks on, three at most", marks != null and marks.poison_stacks() == 3,
			str(marks.poison_stacks() if marks != null else -1))
	await _wait(75)
	_check("and they tick", is_instance_valid(imp) and float(imp.health) < was - 20.0,
			"%.0f -> %.0f" % [was, float(imp.health) if is_instance_valid(imp) else -1.0])
	_check("its veins go green", is_instance_valid(imp) and _overlaid(imp))
	_player._venom_until = 0.0
	var clean := _creature(IMP, _ahead(3.0))
	await _wait(3)
	_player.blade_hit(clean, clean.global_position)
	await _wait(3)
	_check("a clean blade poisons nothing", Afflictions.of(clean, false) == null)
	for c in [imp, clean]:
		if is_instance_valid(c):
			(c as Node).queue_free()
	await _wait(10)


func _check_orc(scene: String, who: String) -> void:
	var orc := _creature(scene, _ahead(9.0)) as OrcWarrior
	orc.set("sight_range", 0.0)
	await _wait(30)
	var own: AnimationPlayer = orc.get("_own")
	for clip in ["RX_Flinch", "RX_Falling_Down", "RX_Getting_Up", "RX_Swat_Bugs", "RX_Injured_Stumble"]:
		_check("%s has %s" % [who, clip], own != null and own.has_animation(clip))
	var was := _along(orc)
	orc.react(&"knock", _player, _fwd() * 6.0)
	_check("%s is thrown down" % who, int(orc.act) == OrcWarrior.Act.REACT_KNOCK)
	await _wait(3)
	_check("falling", own != null and own.current_animation == "RX_Falling_Down", own.current_animation if own else "")
	await _wait(40)
	_check("and back", _along(orc) > was + 0.5, "%.2f -> %.2f" % [was, _along(orc)])
	_check("open while down", orc.is_reeling())
	var gets_up := false
	for i in 400:
		await physics_frame
		if own.current_animation == "RX_Getting_Up":
			gets_up = true
		if int(orc.act) == 0:
			break
	_check("gets up and fights on", gets_up and int(orc.act) == 0, "%d" % int(orc.act))
	orc.react(&"burn", _player)
	await _wait(3)
	_check("on fire he swats at it", int(orc.act) == OrcWarrior.Act.REACT_BURN
			and own.current_animation == "RX_Swat_Bugs", own.current_animation)
	var marks := Afflictions.of(orc)
	marks.apply(&"mark", 5.0, _player)
	var before: float = orc.health
	orc.take_dot(10.0, _player)
	var armour: float = orc.get("armour")
	# 5% deeper from a bow, 2% from anyone else (this hero may be either).
	var deeper := 1.05 if Afflictions.is_bow(_player) else 1.02
	_check("marked, the fire bites through half his hide and a little deeper",
			absf(before - float(orc.health) - 10.0 * deeper * (1.0 - armour * 0.5)) < 0.01,
			"%.2f (want %.2f, armour %.2f)" % [before - float(orc.health), 10.0 * deeper * (1.0 - armour * 0.5), armour])
	orc.queue_free()
	await _wait(10)


# --------------------------------------------------------------------------
func _creature(path: String, at: Vector3) -> Node3D:
	var ground := at
	var hit := _player.get_world_3d().direct_space_state.intersect_ray(
			PhysicsRayQueryParameters3D.create(at + Vector3.UP * 20.0, at + Vector3.DOWN * 40.0, 1))
	if not hit.is_empty():
		ground = hit["position"]
	var c: Node3D = (load(path) as PackedScene).instantiate()
	# Placed before it enters the tree, so the ground it holds is here.
	c.position = _world.to_local(ground + Vector3.UP * 0.05)
	_world.add_child(c)
	# Kept where they are put: the test is of what the skills do to them.
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


## How far along the player's facing something is.
func _along(who: Node3D) -> float:
	return (who.global_position - _player.global_position).dot(_fwd())


func _ready_up() -> void:
	for i in 200:
		if _player.state == Player.State.GROUNDED and not _player.is_committed():
			break
		await physics_frame
	_player._skill_ready_at.clear()
	_player.stamina = _player.max_stamina
	_player.health = _player.max_health


func _overlaid(who: Node) -> bool:
	for mi in who.find_children("*", "MeshInstance3D", true, false):
		if (mi as MeshInstance3D).material_overlay != null:
			return true
	return false


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
	# On his feet before anything is asked of him.
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
