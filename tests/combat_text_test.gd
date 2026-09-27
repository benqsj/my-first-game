extends SceneTree

## Over the creatures ([CombatText]): their level, coloured against yours, and
## what each blow took off them, a critical in gold with a "!". And the light
## of a new level ([LevelBeam]): he is lifted up in it and set down again.
##
##     godot --path . --headless --script res://tests/combat_text_test.gd

var _failures := 0


func _initialize() -> void:
	var game := root.get_node_or_null("Game")
	if game != null:
		game.call("choose", &"tariel")
	var world: World = load("res://scenes/world/greybox_world.tscn").instantiate()
	root.add_child(world)
	await _wait(3)
	var player := world.player()
	player.immortal = true
	var words := world.get_node_or_null(^"CombatText") as CombatText
	_check("the world has its combat text", words != null)
	if words == null:
		_finish()
		return
	var wolves: Array[Wolf] = []
	var imp: Node3D = null
	for node in world.get_node("Enemies").get_children():
		(node as Node).set_physics_process(false)
		if node is Wolf:
			wolves.append(node)
		elif imp == null and Leveling.kind_of(node) == &"imp":
			imp = node
	var cam := Camera3D.new()
	world.add_child(cam)
	cam.global_position = player.global_position + Vector3(0.0, 2.0, 6.0)
	cam.current = true
	var near := wolves[0]
	near.global_position = player.global_position + Vector3(0.0, 0.0, -3.0)
	var far := wolves[1]
	far.global_position = player.global_position + Vector3(80.0, 0.0, 0.0)
	if imp != null:
		imp.global_position = player.global_position + Vector3(3.0, 0.0, -3.0)
	# Frames drawn, not physics steps: the text is read off on `_process`.
	for i in 6:
		await process_frame

	var tag := _tag_on(near)
	_check("a wolf near shows its level", tag != null and tag.visible and tag.text == "Lv 3  Wolf",
			tag.text if tag != null else "none")
	_check("  yellow: two above a level-1 hero", tag != null and tag.modulate.is_equal_approx(CombatText._standing(2)))
	var far_tag := _tag_on(far)
	_check("a wolf far off shows nothing", far_tag == null or not far_tag.visible)
	if imp != null:
		var imp_tag := _tag_on(imp)
		_check("an imp is level 1, white against him", imp_tag != null and imp_tag.text == "Lv 1  Imp"
				and imp_tag.modulate.is_equal_approx(Color(1, 1, 1)), imp_tag.text if imp_tag != null else "none")

	var before := near.health
	near.take_hit(40.0, near.global_position + Vector3.UP, Vector3.FORWARD, false, false, player)
	await process_frame
	await process_frame
	var shown := _numbers(words)
	var took := roundi(before - near.health)
	_check("a blow puts up what it took", shown.has(str(took)), "%s, took %d" % [shown, took])
	before = near.health
	near.take_hit(40.0, near.global_position + Vector3.UP, Vector3.FORWARD, true, false, player)
	await process_frame
	await process_frame
	took = roundi(before - near.health)
	shown = _numbers(words)
	_check("a critical in gold, with a '!'", shown.has("%d!" % took), "%s, took %d" % [shown, took])
	await _seconds(CombatText.NUMBER_LIFE + 0.2)
	_check("and they are gone after a second", _numbers(words).is_empty(), str(_numbers(words)))

	# A new level: lifted up in the light, and put back down.
	var body := player.get_node(^"Visuals") as Node3D
	var ground := body.position.y
	LevelBeam.on(player)
	var highest := ground
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < int((LevelBeam.LIFE + 0.4) * 1000.0):
		await process_frame
		highest = maxf(highest, body.position.y)
	await _wait(5)
	_check("a new level lifts him up in the light", highest > ground + 0.5, "%.2f" % (highest - ground))
	_check("  and sets him down where he was", is_equal_approx(body.position.y, ground), "%.3f" % body.position.y)
	_check("  and the light is gone", player.get_node_or_null(^"LevelBeam") == null)
	_finish()


func _tag_on(creature: Node) -> Label3D:
	for child in creature.get_children():
		if child is Label3D:
			return child
	return null


func _numbers(words: CombatText) -> Array[String]:
	var out: Array[String] = []
	for child in words.get_children():
		if child is Label3D and not child.is_queued_for_deletion():
			out.append((child as Label3D).text)
	return out


func _seconds(span: float) -> void:
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < int(span * 1000.0):
		await process_frame


func _wait(frames: int) -> void:
	for i in frames:
		await physics_frame


func _finish() -> void:
	print("\n%s" % ("All checks passed." if _failures == 0 else "%d check(s) failed." % _failures))
	quit(1 if _failures else 0)


func _check(label: String, condition: bool, detail: String = "") -> void:
	if condition:
		print("  ok   - %s" % label)
	else:
		_failures += 1
		print("  FAIL - %s %s" % [label, ("(%s)" % detail) if detail else ""])
