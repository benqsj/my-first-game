extends SceneTree

## The village's people (the user's word, 2026-10-22): men, women and elves
## of the Polysplit parts and the knight on guard, there from the first, each
## on a [FolkBody] at ease (not a fighter's clips) and unarmed; the men he
## frees wear the look they had in the cage (the squire, the knight); the
## walkers walk; the release pack keeps what the game reads that is not a
## resource (the palace vista's height maps).
##
##     godot --headless --path . --script res://tests/village_folk_test.gd

var _failures := 0


func _initialize() -> void:
	var game := root.get_node("Game")
	game.set(&"peaceful", true)
	var freed: Array[String] = ["orc_palace:a", "orc_palace:b", "orc_palace:c", "orc_palace:d"]
	game.set(&"freed", freed)
	var world: World = load("res://scenes/world/greybox_world.tscn").instantiate()
	root.add_child(world)
	await _wait(10)
	var kinds := {}
	for who: Dictionary in World.FOLK:
		var man := world.get_node_or_null("Folk_%s" % who["name"]) as Villager
		_check("%s is in the village" % who["name"], man != null)
		if man == null:
			continue
		var body := man.get_node_or_null("Body") as FolkBody
		_check("%s has a body of the village's" % who["name"], body != null)
		if body == null:
			continue
		var shown := 0
		var arms := 0
		for m: MeshInstance3D in body.find_children("*", "MeshInstance3D", true, false):
			if m.is_visible_in_tree():
				shown += 1
				var n := String(m.name).to_lower()
				if n.contains("sword") or n.contains("shield") or n.begins_with("ps_w_") or n.begins_with("ps_o_"):
					arms += 1
		_check("%s is seen" % who["name"], shown > 0)
		_check("%s goes unarmed" % who["name"], arms == 0, "%d arms shown" % arms)
		var anim := body.find_children("*", "AnimationPlayer", true, false).front() as AnimationPlayer
		_check("%s stands at ease, not on guard" % who["name"], anim != null and String(anim.current_animation).begins_with("folk/"),
				String(anim.current_animation) if anim != null else "")
		kinds[String(man.ps_look.get("g", "m")) + String(man.ps_look.get("race", ""))] = true
	_check("men, women and elves among them", kinds.has("m") and kinds.has("f") and (kinds.has("melf") or kinds.has("felf")), str(kinds.keys()))
	_check("only the squire and the knight of the poly heroes", Villager.FREED == [&"squire", &"knight"])
	# the freed: their cage look, in order
	_check("the first freed is the squire", Villager.freed_look(0) == &"squire")
	var freed3 := world.get_node_or_null("Freed3") as Villager
	_check("the fourth freed walks the street in his look", freed3 != null and freed3.look == Villager.freed_look(3))
	var smith := world.get_node_or_null("Trade_smith") as VillageTrade
	_check("the smith at his stall in the first freed man's look", smith != null and (smith.get_node("Man") as Villager).look == Villager.freed_look(0))
	# the hooded man walks
	var hooded := world.get_node_or_null("Folk_Woman_Walker") as Villager
	if hooded != null:
		# (he stops to watch a hero who comes near: the hero stands off)
		world.player().global_position = Vector3(0.0, 0.5, -40.0)
		var from := hooded.global_position
		await _wait(60 * 9)
		_check("a woman walks the street", hooded.global_position.distance_to(from) > 1.0,
				"%.2f m" % hooded.global_position.distance_to(from))
	# what the export must carry besides resources
	var cfg := ConfigFile.new()
	cfg.load("res://export_presets.cfg")
	_check("the pack takes the palace vista's maps", String(cfg.get_value("preset.0", "include_filter", "")).contains("assets/world/v5/*.gz"))
	_finish()


func _wait(frames: int) -> void:
	for i in frames:
		await physics_frame


func _finish() -> void:
	print("")
	if _failures == 0:
		print("All checks passed.")
	else:
		print("%d check(s) FAILED." % _failures)
	quit(1 if _failures > 0 else 0)


func _check(label: String, condition: bool, detail: String = "") -> void:
	if condition:
		print("  ok   - %s" % label)
	else:
		_failures += 1
		print("  FAIL - %s %s" % [label, ("(%s)" % detail) if detail else ""])
