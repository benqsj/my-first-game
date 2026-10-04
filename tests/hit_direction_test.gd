extends SceneTree
## TARIEL_POLISH.md 9, a blow that gets through shown by where it came from:
## - struck from in front, behind, his left and his right: each side its own
##   flinch (on the mannequin), and his back thrown over away from the blow
##   (HitLean);
## - a heavy blow a bigger clip than a light one from the same side.
##   Godot --headless --path . --script res://tests/hit_direction_test.gd

var _failures := 0


func _check(what: String, ok: bool, detail: String = "") -> void:
	print("  %s - %s %s" % ["ok  " if ok else "FAIL", what, detail])
	if not ok:
		_failures += 1


func _wait(n: int) -> void:
	for i in n:
		await physics_frame


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var world: World = load("res://scenes/world/test_arena.tscn").instantiate()
	root.add_child(world)
	await _wait(30)
	(world.get_node("ArenaPanel") as ArenaPanel)._clear()
	var hero := world.player()
	hero.immortal = true
	hero.call(&"_set_weapons_stowed", false)
	await _wait(40)
	var rig := hero.rig as SkinnedRig
	_check("on the mannequin", rig._on_mq)
	var lean := rig._mq.get("lean") as HitLean
	_check("his back can be thrown over (HitLean on the mannequin)", lean != null)
	var found := []
	for b: StringName in HitLean.CHAIN:
		if rig._skel.find_bone(b) >= 0:
			found.append(b)
	_check("every bone of the back is there, the head too", found.size() == 5, str(found))
	var foe := Node3D.new()
	foe.name = "Foe"
	world.add_child(foe)
	var start := hero.global_position
	var ahead := -hero.global_basis.z
	var right := hero.global_basis.x
	var sides := {SkinnedRig.From.FRONT: ahead, SkinnedRig.From.BACK: -ahead,
			SkinnedRig.From.LEFT: -right, SkinnedRig.From.RIGHT: right}
	var names := {SkinnedRig.From.FRONT: "in front", SkinnedRig.From.BACK: "behind",
			SkinnedRig.From.LEFT: "his left", SkinnedRig.From.RIGHT: "his right"}
	var light_clips := {}
	for from: int in sides:
		var got := {}
		for damage: float in [6.0, 30.0]:
			await _wait(100)
			hero.global_position = start
			hero.velocity = Vector3.ZERO
			hero.health = hero.max_health
			foe.global_position = start + (sides[from] as Vector3) * 1.5
			var away := hero.global_position - foe.global_position
			away.y = 0.0
			away = away.normalized()
			rig.last_flinch = {}
			# straight past his armour: the damage is what lands
			hero.net_blow(damage, away, foe.global_position, "%s#%d" % [foe.get_path(), randi()], 0, 3)
			await _wait(8)
			var tipped := lean.lean() if lean != null else Vector3.ZERO
			var toward := Vector3.UP.cross(away)
			got[damage] = {"from": rig.last_flinch.get("from", -1), "clip": rig.last_flinch.get("clip", &""),
					"heft": rig.last_flinch.get("heft", -1.0), "lean": tipped.dot(toward), "playing": rig._anim.current_animation}
		print("  %s %s" % [names[from], got])
		var light: Dictionary = got[6.0]
		var heavy: Dictionary = got[30.0]
		_check("struck from %s: known for that side" % names[from], light["from"] == from and heavy["from"] == from,
				"%s / %s" % [light["from"], heavy["from"]])
		if from == SkinnedRig.From.BACK:
			# from behind: no clip (he is not hunched over), only the lean
			_check("from behind: not hunched over (no clip over him)", light["clip"] == &"" and heavy["clip"] == &""
					and not String(light["playing"]).contains("Impact"), "%s" % light["playing"])
		else:
			_check("from %s: its flinch plays" % names[from], light["clip"] != &"" and light["playing"] == String(light["clip"]),
					"%s" % light["clip"])
		_check("from %s: thrown over away from the blow" % names[from], light["lean"] > 0.03 and heavy["lean"] > light["lean"],
				"%.3f / %.3f rad" % [light["lean"], heavy["lean"]])
		_check("from %s: a heavy blow a bigger flinch" % names[from],
				heavy["clip"] != light["clip"] or from == SkinnedRig.From.BACK, "%s / %s" % [light["clip"], heavy["clip"]])
		light_clips[from] = light["clip"]
	_check("in front and behind, different flinches",
			light_clips[SkinnedRig.From.FRONT] != light_clips[SkinnedRig.From.BACK])
	_check("a side, not the one from in front",
			light_clips[SkinnedRig.From.LEFT] != light_clips[SkinnedRig.From.FRONT])
	if _failures == 0:
		print("All checks passed.")
	else:
		print("%d check(s) FAILED." % _failures)
	quit(1 if _failures > 0 else 0)
