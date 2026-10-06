extends SceneTree

## Skeletons and golems let no blood (the user, 2026-10-06): cut, shot or
## struck through, each of them throws off chips of what it is made of and
## takes no wound on its body, while an orc still bleeds.
##
##   godot --headless --path . --script res://tests/bloodless_test.gd

const DRY := ["skeleton", "skeleton_warrior", "skeleton_archer", "skeleton_mage", "golem"]

var _failed := 0


func _check(what: String, ok: bool, detail: String = "") -> void:
	print("%s  %s  %s" % ["ok  " if ok else "FAIL", what, detail])
	if not ok:
		_failed += 1


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var world: World = load("res://scenes/world/test_arena.tscn").instantiate()
	root.add_child(world)
	for i in 30:
		await physics_frame
	var panel := world.get_node("ArenaPanel") as ArenaPanel
	panel._clear()
	panel._frozen = true
	var hero := world.player()
	var fwd := -hero.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var kinds: Array = DRY.duplicate()
	kinds.append("orc")
	var side := 0.0
	for kind: String in kinds:
		side += 3.0
		var at := hero.global_position + fwd * 4.0 + fwd.cross(Vector3.UP) * (side - 9.0)
		var body := panel.call_up("res://scenes/enemies/pack/%s.tscn" % kind, false, at) as Node3D
		await physics_frame
		await physics_frame
		body.set("max_health", 9999.0)
		body.set("health", 9999.0)
		var into := Blood.world_of(body)
		var fx_before := _count_fx(into)
		var point := body.global_position + Vector3.UP * 1.0
		# struck from behind, so no shield catches it
		var blow := -body.global_transform.basis.z
		body.call("take_hit", 20.0, point, blow, false, true, null)
		# and as an arrow or a gust through it lets it
		Blood.spill(into, point, blow, body)
		await physics_frame
		var wounded := body.has_meta(&"wounds") and not (body.get_meta(&"wounds") as Array).is_empty()
		var chips := _count_fx(into) - fx_before
		if kind == "orc":
			_check("an orc still bleeds", wounded, "wounds %s" % wounded)
		else:
			_check("%s: no blood, no wound" % kind, not wounded and Blood.bleeds(body) == false,
					"matter %s" % ImpactFx.matter_of(body))
			_check("%s: chips of it instead" % kind, chips >= 2, "%d" % chips)
	print("bloodless_test: %s" % ("all passed" if _failed == 0 else "%d FAILED" % _failed))
	quit(1 if _failed > 0 else 0)


func _count_fx(into: Node) -> int:
	var n := 0
	for c in into.get_children():
		if c is HitFx:
			n += 1
	return n
