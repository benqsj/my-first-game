extends SceneTree

## A spell bolt is shaken off only by an evade begun while it is on its way and
## near ([member SpellBolt.dodge_window]): a roll already going when it was let
## go, or spent long before it arrives, leaves it after its quarry (the user's
## word, 2026-10-06: rolled as the skeleton mage cast, and its bolt went on the
## old way and never came after him).
##
##     godot --path . --headless --script res://tests/bolt_dodge_test.gd

var _failures := 0
var _world: Node3D
var _dummy_script: GDScript


func _initialize() -> void:
	_world = Node3D.new()
	root.add_child(_world)
	await _wait(2)
	# Rolling as it is let go, up after a third of a second and walking on
	# across its line: still followed, and hit.
	var early := await _case(0.0, 0.3)
	_check("a roll already going at the throw does not shake it off", early["hits"] == 1 and not early["let_go"], str(early))
	# A roll long before it is near, then walking on: still hit.
	var far := await _case(20.0, 0.25)
	_check("a roll spent while it is far off does not shake it off", far["hits"] == 1 and not far["let_go"], str(far))
	# A roll begun as it closes in: shaken off, and it misses.
	var timed := await _case(7.0, 0.6)
	_check("a roll begun as it closes in shakes it off", timed["hits"] == 0 and timed["let_go"], str(timed))
	# Walking only: followed and hit (as ever).
	var walked := await _case(-1.0, 0.0)
	_check("a body walking across is followed and hit", walked["hits"] == 1, str(walked))
	print("bolt_dodge_test: %s" % ("All checks passed." if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)


## A bolt thrown at a body 24 m off that walks across its line at 4 m/s. It
## rolls (says it is evading, and stands) for `roll_for` seconds once the bolt
## is within `roll_at` metres (0: from the throw; below 0: never).
func _case(roll_at: float, roll_for: float) -> Dictionary:
	var dummy := _dummy()
	dummy.position = Vector3(24.0, 20.0, 0.0)
	_world.add_child(dummy)
	await _wait(2)
	var bolt: SpellBolt = (load("res://scenes/fx/spell_bolt.tscn") as PackedScene).instantiate()
	_world.add_child(bolt)
	bolt.global_position = Vector3(0.0, 20.8, 0.0)
	bolt.launch(Vector3(30.0, 0.0, 0.0), 10.0, false, 0.0, _world)
	bolt.hunt(dummy)
	var out := {"hits": 0, "let_go": false}
	var rolled := -1.0
	var walk := Vector3(0.0, 0.0, 4.0)
	for i in 180:
		if is_instance_valid(bolt) and rolled < 0.0 and roll_at >= 0.0:
			var gap := (dummy.global_position + Vector3.UP - bolt.global_position).length()
			if roll_at == 0.0 or gap < roll_at:
				rolled = 0.0
		var rolling := rolled >= 0.0 and rolled < roll_for
		dummy.set("evading", rolling)
		if rolled >= 0.0:
			rolled += 1.0 / 60.0
		if not rolling:
			dummy.global_position += walk / 60.0
		await physics_frame
		if not is_instance_valid(bolt):
			break
		out["let_go"] = out["let_go"] or (not bolt.is_hunting() and not bolt.is_fading())
	out["hits"] = int(dummy.get("hits"))
	dummy.queue_free()
	if is_instance_valid(bolt):
		bolt.queue_free()
	await _wait(2)
	return out


func _dummy() -> CharacterBody3D:
	if _dummy_script == null:
		_dummy_script = GDScript.new()
		_dummy_script.source_code = "extends CharacterBody3D\nvar hits := 0\nvar evading := false\n" \
				+ "func take_hit(_d: float, _at: Vector3, _b: Vector3, _c: bool = false, _h: bool = false, _f: Node3D = null, _g: Variant = null) -> void:\n\thits += 1\n" \
				+ "func is_evading() -> bool:\n\treturn evading\n"
		_dummy_script.reload()
	var body := CharacterBody3D.new()
	body.set_script(_dummy_script)
	body.collision_layer = 4
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.8
	shape.shape = capsule
	shape.position = Vector3(0.0, 0.9, 0.0)
	body.add_child(shape)
	return body


func _wait(n: int) -> void:
	for i in n:
		await physics_frame


func _check(what: String, ok: bool, detail: String = "") -> void:
	print("  %s - %s %s" % ["ok  " if ok else "FAIL", what, detail])
	if not ok:
		_failures += 1
