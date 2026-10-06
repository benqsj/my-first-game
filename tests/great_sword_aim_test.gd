extends SceneTree
## The knight's blows reach what they are thrown at (the user, 2026-10-06: the
## blade went past the side of it): an orc held 2.5 m off, every blow of both
## strings thrown at it, the blade's closest pass to its chest measured.
## StrikeAim read the mannequin's skeleton as facing its -Z, which is his
## back: every aimed cut was turned 29 degrees to one side.
##   Godot --headless --path . --script res://tests/great_sword_aim_test.gd
var _failures := 0
var _passes: Dictionary = {}


func _check(what: String, ok: bool, detail: String = "") -> void:
	print("  %s - %s %s" % ["ok  " if ok else "FAIL", what, detail])
	if not ok:
		_failures += 1

var player: Player
var rig: SkinnedRig

func _tap(action: String) -> void:
	Input.action_press(action)
	await physics_frame
	Input.action_release(action)

func _initialize() -> void:
	var game := root.get_node_or_null("Game")
	if game != null:
		game.call("choose", &"warrior")
	var world: World = load("res://scenes/world/greybox_world.tscn").instantiate()
	root.add_child(world)
	for i in 2:
		await physics_frame
	player = world.player()
	player.immortal = true
	var foe: Node3D = null
	for e in world.get_node("Enemies").get_children():
		if foe == null and e is CharacterBody3D and String(e.name).to_lower().contains("orc"):
			foe = e
			continue
		e.queue_free()
	if foe == null:
		for e in world.get_node("Enemies").get_children():
			if e is CharacterBody3D and not e.is_queued_for_deletion():
				foe = e
				break
	print("FOE ", foe.name if foe else "none")
	rig = player.rig as SkinnedRig
	player.set_look(PolysplitLook.default_look(&"warrior", "m"))
	player.set_face(rig.faces.find(SkinnedRig.CUSTOM))
	player.global_position = Vector3(0.0, 0.5, 26.0)
	for i in 40:
		await physics_frame
	foe.global_position = player.global_position + Vector3(0.6, 0.0, -2.4)
	foe.process_mode = Node.PROCESS_MODE_DISABLED
	foe.set(&"immortal", true)
	rig._mode = 0
	rig._main_string = GreatSword.MODES[0]["strings"][0]
	rig._wear_string(rig._main_string)
	for action in ["attack", "block"]:
		for i in 200:
			await physics_frame
		for b in 4:
			for i in 120:
				if not player.is_committed():
					break
				await physics_frame
			player.stamina = player.max_stamina
			rig._last_attack_at = Time.get_ticks_msec() / 1000.0
			await _tap(action)
			var clip := rig.current_swing()
			for i in 10:
				if clip != &"":
					break
				await physics_frame
				clip = rig.current_swing()
			var rows: Array = []
			var best := 99.0
			var was := PackedVector3Array()
			while rig.current_swing() == clip:
				var e := rig.get_cutting_edge()
				if not e.is_empty():
					var aim := foe.global_position + Vector3(0, 1.1, 0)
					# along the blade, and (a fast sweep is past it between two
					# ticks) along the ways its tip and middle went since the last
					var segs: Array = [[e[0], e[1]]]
					if not was.is_empty():
						segs.append([was[1], e[1]])
						segs.append([was[0].lerp(was[1], 0.5), e[0].lerp(e[1], 0.5)])
					for seg: Array in segs:
						var near := Geometry3D.get_closest_point_to_segment(aim, seg[0], seg[1])
						best = minf(best, Vector2(near.x - aim.x, near.z - aim.z).length())
					was = e
					var fwd := -player.global_basis.z
					fwd.y = 0
					var o := player.global_position
					var tip := e[1] - o
					var mid := e[0].lerp(e[1], 0.66) - o
					var th := Vector3(tip.x, 0, tip.z)
					var mh := Vector3(mid.x, 0, mid.z)
					rows.append("%.0f/%.2f/%.2f(m%.0f)" % [rad_to_deg(fwd.signed_angle_to(th, Vector3.UP)), th.length(), tip.y, rad_to_deg(fwd.signed_angle_to(mh, Vector3.UP))])
				await physics_frame
			print("    %s: closest %.2f m" % [clip, best])
			_passes[clip] = best
			for i in 30:
				await physics_frame
	for clip: StringName in _passes:
		var most := 0.3 if clip in [&"KV_Attack1H01_R", &"KV_Attack2H02", &"KV_Attack2H04"] else 0.55
		_check("%s reaches it" % clip, float(_passes[clip]) < most, "%.2f m" % float(_passes[clip]))
	_check("all eight thrown", _passes.size() == 8, str(_passes.size()))
	print("ALL PASSED" if _failures == 0 else "%d FAILED" % _failures)
	quit(1 if _failures > 0 else 0)
