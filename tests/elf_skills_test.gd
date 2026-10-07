extends SceneTree

## The elf's Frost Nova, Moonwell and Moonfall ([ElfSkills]) and picking four
## of her five skills for the sockets ([SkillBook], [method Player.set_skill_slot]).
##
##     godot --path . --headless --script res://tests/elf_skills_test.gd

const ARENA := "res://scenes/world/test_arena.tscn"
const OGRE := "res://scenes/enemies/pack/ogre.tscn"
var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	printerr("elf_skills_test: start")
	root.get_node("Game").call(&"choose", &"elf_mage")
	var world: World = load(ARENA).instantiate()
	root.add_child(world)
	await _wait(30)
	var panel := world.get_node("ArenaPanel") as ArenaPanel
	panel._clear()
	var hero := world.player()
	hero.immortal = true
	await _wait(30)
	var kept := hero.skill_picks

	# Five skills, four sockets: the first four until she picks.
	hero.skill_picks = PackedStringArray()
	_check("she has five skills", hero.skill_choices().size() == 5, str(hero.skill_choices()))
	_check("the first four are in the sockets", hero.skill_in(3) == &"moonwell" and hero.skill_in(0) == &"frost_spears")
	hero.set_skill_slot(1, &"moonfall")
	_check("picked into a socket, it is there", hero.skill_in(1) == &"moonfall")
	_check("and what was there is out", not [hero.skill_in(0), hero.skill_in(1), hero.skill_in(2), hero.skill_in(3)].has(&"frost_step"))
	hero.set_skill_slot(3, &"moonfall")
	_check("a socketed skill moved swaps with what was there",
			hero.skill_in(3) == &"moonfall" and hero.skill_in(1) == &"moonwell")

	var ahead := -hero.global_basis.z
	ahead.y = 0.0
	ahead = ahead.normalized()
	var side := ahead.cross(Vector3.UP)

	# Frost Nova: a foe beside her is hurt and frozen; struck, the ice shatters.
	hero.set_skill_slot(0, &"frost_nova")
	var foe := panel.call_up(OGRE, false, hero.global_position + side * 2.5)
	await _wait(10)
	panel._hold(foe, true)
	foe.global_position = hero.global_position + side * 2.5
	await _wait(5)
	var hp0 := float(foe.get("health"))
	_check("the nova goes", hero.use_skill(0))
	await _wait(40)
	_check("the foe beside her is hurt", float(foe.get("health")) < hp0, "%.0f -> %.0f" % [hp0, float(foe.get("health"))])
	_check("and frozen", FrostShell.is_frozen(foe))
	await _wait(60 * 2)
	_check("and free again after its time", not FrostShell.is_frozen(foe))
	# chilled first, it is frozen twice as long
	Afflictions.of(foe).apply(&"chill", 5.0, hero)
	hero._skill_ready_at.clear()
	hero.stamina = hero.max_stamina
	hero.use_skill(0)
	await _wait(40 + 60 * 2)
	_check("chilled, it is frozen twice as long", FrostShell.is_frozen(foe))
	_check("struck while frozen the ice shatters for half as much again", is_equal_approx(FrostShell.shatter(foe), FrostShell.SHATTER))
	await _wait(2)
	_check("and it is gone", not FrostShell.is_frozen(foe))

	# Moonwell: she heals in it, the foe in it is chilled.
	hero.set_skill_slot(0, &"moonwell")
	hero._skill_ready_at.clear()
	hero.stamina = hero.max_stamina
	hero.immortal = false
	hero.health = hero.max_health * 0.5
	hero.mend_rate = 0.0
	panel._unhurt = false
	var h0 := hero.health
	foe.global_position = hero.global_position + side * 3.0
	_check("the well opens", hero.use_skill(0))
	await _wait(30)
	var marks := Afflictions.of(foe, false)
	_check("a foe in it is chilled", marks != null and marks.is_chilled())
	await _wait(60 * 6 + 30)
	var gained := (hero.health - h0) / hero.max_health
	_check("she has a quarter of her health back", gained > 0.2 and gained < 0.3, "%.0f %%" % (gained * 100.0))
	hero.immortal = true

	# Moonfall: on what she has locked; it is hurt and stunned.
	hero.set_skill_slot(0, &"moonfall")
	hero._skill_ready_at.clear()
	hero.stamina = hero.max_stamina
	foe.global_position = hero.global_position + ahead * 10.0
	await _wait(5)
	hero.call("_hold_target", foe)
	await _wait(5)
	var hp1 := float(foe.get("health"))
	_check("the moon falls", hero.use_skill(0))
	await _wait(int(60 * MoonFall.WARN) - 10)
	_check("not before the warning is through", is_equal_approx(float(foe.get("health")), hp1))
	await _wait(25)
	_check("then it is hurt", float(foe.get("health")) < hp1, "%.0f -> %.0f" % [hp1, float(foe.get("health"))])

	hero.skill_picks = kept
	hero._keep_picks()
	printerr("elf_skills_test: %s" % ("All checks passed." if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)


func _wait(n: int) -> void:
	for i in n:
		await physics_frame


func _check(what: String, ok: bool, detail: String = "") -> void:
	printerr("  %s - %s %s" % ["ok  " if ok else "FAIL", what, detail])
	if not ok:
		_failures += 1
