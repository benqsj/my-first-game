extends SceneTree

## A boss against 1, 2, 3 and 4 heroes (the user's word, 2026-10-28: two, three
## or four must not kill it easily, and it must move and strike as it does
## against one). Each fight: the heroes stand round it, each in his own slot
## (some at its back), and cut at it as fast as a sword goes; they cannot die
## (the blows on them are counted). Hardened as the dungeon hardens a boss for
## that many ([method Dungeon.harden_body], [method Dungeon.coop_factors]).
## Reported: how long it lasts, how many blows it lands on each hero a minute,
## its stance breaks. Checked: with more heroes it does not fall much sooner,
## and each of them is still struck about as often as one alone would be.
##
##     godot --headless --path . --script res://tests/boss_coop_test.gd [-- golem butcher ogre]

const BOSSES := {
	"golem": "res://scenes/enemies/pack/golem.tscn",
	"butcher": "res://scenes/enemies/pack/pig_butcher.tscn",
	"ogre": "res://scenes/enemies/pack/ogre.tscn",
	"troll": "res://scenes/enemies/pack/troll.tscn",
}
const SPOT := Vector3(10.0, 0.0, -190.0)
const MOST := 240.0
const RING := 2.3
const TEST_SHARE := 0.35
## A hero's cut, this often (s).
const SWING := 0.9

var _failures := 0
var _world: World


func _initialize() -> void:
	var game := root.get_node_or_null("Game")
	if game != null:
		game.call("choose", &"tariel")
	_world = load("res://scenes/world/greybox_world.tscn").instantiate()
	root.add_child(_world)
	await _wait(30)
	_world.creature_think_distance = 70.0
	var names: Array = []
	for word in OS.get_cmdline_user_args():
		if BOSSES.has(word):
			names.append(word)
	if names.is_empty():
		names = ["golem", "butcher", "ogre"]
	var report: PackedStringArray = []
	for boss: String in names:
		var rows: Array[Dictionary] = []
		for n in [1, 2, 3, 4]:
			var r := await _fight(boss, n)
			rows.append(r)
			print("ROW %s %d %.1f %s %.1f" % [boss, n, r["time"], r["dead"], r["each_min"]])
			report.append("%-8s %d heroes: %5.1f s%s, %4.1f blows on each a minute, %d stance breaks, health %.0f" % [
					boss, n, r["time"], "" if r["dead"] else " (alive)", r["each_min"], r["breaks"], r["health"]])
		var solo := rows[0]
		for k in range(1, rows.size()):
			var r := rows[k]
			var n := k + 1
			_check("%s, %d heroes: not felled much sooner than by one (%.0f s vs %.0f)" % [boss, n, r["time"], solo["time"]],
					float(r["time"]) >= 0.7 * float(solo["time"]))
			_check("%s, %d heroes: each still struck (%.1f a minute vs %.1f alone)" % [boss, n, r["each_min"], solo["each_min"]],
					float(r["each_min"]) >= 0.45 * float(solo["each_min"]))
	print("\n".join(report))
	print("boss_coop_test: %s" % ("All checks passed." if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)


func _fight(boss: String, n: int) -> Dictionary:
	var floor_y := _floor_at(SPOT)
	var body := (load(BOSSES[boss]) as PackedScene).instantiate() as Node3D
	body.name = "CoopBoss_%s_%d" % [boss, n]
	body.position = Vector3(SPOT.x, floor_y + 0.3, SPOT.z)
	if "camp_centre" in body:
		body.set("camp_centre", body.position)
	body.set_meta(&"boss", true)
	_world.get_node("Enemies").add_child(body)
	await _wait(3)
	var f := Dungeon.coop_factors(n)
	if OS.get_cmdline_user_args().has("--old"):
		# as it was before 2026-10-28's round: stance as a common one's, no pace
		f["boss_stance"] = f["stance"]
		f["pace"] = 1.0
	Dungeon.harden_body(body, f, true, false)
	# (all of them at this share of their health, so one hero alone fells it
	# inside the time: the shares between counts are what is measured)
	body.set(&"max_health", float(body.get(&"max_health")) * TEST_SHARE)
	body.set(&"health", body.get(&"max_health"))
	var heroes: Array[Player] = [_world.player()]
	for k in range(1, n):
		var extra := _world._build_player({"peer": 1, "character": "tariel", "point": 0}) as Player
		extra.name = "CoopHero%d" % k
		_world._players.add_child(extra)
		heroes.append(extra)
	await _wait(3)
	var struck: Array[int] = []
	for k in heroes.size():
		struck.append(0)
		var hero := heroes[k]
		hero.immortal = true
		hero.health = hero.max_health
		hero.struck.connect(func(_d: float, _b: bool) -> void: struck[k] += 1)
	var t := 0.0
	var next_cut: Array[float] = []
	for k in heroes.size():
		next_cut.append(0.2 + 0.25 * float(k))
	var dt := 1.0 / float(Engine.physics_ticks_per_second)
	var breaks_before := int(body.get(&"stance_breaks")) if "stance_breaks" in body else 0
	while t < MOST and is_instance_valid(body) and not bool(body.get(&"is_dead")):
		await physics_frame
		t += dt
		var at := body.global_position
		for k in heroes.size():
			var hero := heroes[k]
			# his own slot round it: the first in front, the others round to its back
			var ang := body.global_rotation.y + PI + TAU * float(k) / float(n)
			var slot := at + Vector3(-sin(ang), 0.0, -cos(ang)) * RING
			var flat := Vector2(hero.global_position.x - at.x, hero.global_position.z - at.z).length()
			if (flat > RING + 0.8 or flat < 1.2) and not hero.is_committed() and hero.state != Player.State.DOWNED:
				hero.global_position = Vector3(slot.x, _floor_at(slot) + 0.1, slot.z)
				hero.velocity = Vector3.ZERO
			var aim := at - hero.global_position
			if hero.state != Player.State.DOWNED and not hero.is_committed():
				hero.rotation.y = atan2(-aim.x, -aim.z)
			if t >= next_cut[k] and hero.rig != null and hero.state != Player.State.DOWNED:
				next_cut[k] = t + SWING
				hero.rig.attack()
	var dead := not is_instance_valid(body) or bool(body.get(&"is_dead"))
	var hits := 0
	for c in struck:
		hits += c
	var out := {"time": t, "dead": dead, "each_min": float(hits) / float(n) / maxf(t / 60.0, 0.01),
			"breaks": (int(body.get(&"stance_breaks")) - breaks_before) if is_instance_valid(body) and "stance_breaks" in body else 0,
			"health": float(body.get(&"health")) if is_instance_valid(body) else 0.0}
	if is_instance_valid(body):
		body.queue_free()
	for k in range(1, heroes.size()):
		heroes[k].queue_free()
	await _wait(20)
	return out


func _floor_at(p: Vector3) -> float:
	var space := _world.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 60.0, p + Vector3.DOWN * 60.0, 1)
	var hit := space.intersect_ray(q)
	return float((hit["position"] as Vector3).y) if not hit.is_empty() else p.y


func _wait(frames: int) -> void:
	for i in frames:
		await physics_frame


func _check(what: String, ok: bool) -> void:
	print("  %s - %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
