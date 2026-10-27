extends SceneTree
## How much gold one run through the portal brings (the user's word,
## 2026-10-27, [CombatDirector]'s plan: the trades' prices set by it, not by
## guess). Each fighting place at each step: what its creatures drop on
## average ([CoinBank.worth_of], without the spread); a run's least, average
## and most over the places one could choose; the trades' prices beside it.
## Not a test: a measure.
##   Godot --headless --path . --script tests/gold_probe.gd
func _initialize() -> void:
	_run.call_deferred()


func _wait(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	root.get_node("Game").set(&"dungeon_id", 0)
	var world: Node = load("res://scenes/world/dungeon.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	while root.find_child("PipelineWarmup", true, false) != null:
		await process_frame
	await _wait(10)
	var d := world.get_node("Level/Rooms") as Dungeon
	var run: Array = Dungeon.RUN[0]
	var least := 0.0
	var most := 0.0
	var mean := 0.0
	for i in run.size():
		var golds: Array[float] = []
		for place: String in run[i]["places"]:
			for k in 6:
				d._take_down(k)
			await _wait(3)
			var before := {}
			for f in root.find_children("*", "CharacterBody3D", true, false):
				before[f] = true
			d._arrive_at(i, place, "")
			await _wait(8)
			var gold := 0.0
			var n := 0
			for f in root.find_children("*", "CharacterBody3D", true, false):
				if before.has(f) or f is Player or not f.is_in_group(&"enemy"):
					continue
				gold += CoinBank.worth_of(f)
				n += 1
			golds.append(gold)
			print("GOLD step %d %s: %d creatures, %.0f gold" % [i + 1, place, n, gold])
		golds.sort()
		least += golds[0]
		most += golds[golds.size() - 1]
		var sum := 0.0
		for g in golds:
			sum += g
		mean += sum / float(golds.size())
	# a gold reward taken now and then (the room's gift, [Dungeon]): about one
	# in four steps
	var gifts := float(Dungeon.GOLD_GIFT) * float(run.size()) / 4.0
	print("GOLD run: least %.0f, average %.0f, most %.0f (+ ~%.0f from the rooms' gifts)" % [least, mean, most, gifts])
	for trade: String in Trades.ORDER:
		var costs: Array = Trades.ALL[trade]["costs"]
		var all := 0
		for c in costs:
			all += int(c)
		print("GOLD %s: %s, all %d = %.1f average runs" % [trade, str(costs), all, float(all) / maxf(mean + gifts, 1.0)])
	quit(0)
