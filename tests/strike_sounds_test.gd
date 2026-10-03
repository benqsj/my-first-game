extends SceneTree
## TARIEL_POLISH.md 7, the weight of a blow heard:
## - what a blade meets is told apart ([method ImpactFx.matter_of]): flesh,
##   bone (the skeletons), stone (a golem, a wall), wood (a trunk, a fence);
## - each has a sound of its own, and none of them is silence;
## - a string is heard getting heavier: its first cut, the next, its last
##   with a rush of air under it, a heavy blow with a deep one;
## - a cut that runs into a wall rings off stone, one into a trunk knocks in
##   wood, once a swing; the ground under it does not;
## - his blade going into a skeleton cracks bone; caught on a guard, it rings.
##   Godot --headless --path . --script res://tests/strike_sounds_test.gd
const WORLD := "res://scenes/world/greybox_world.tscn"

var _failures := 0
var _world: Node3D
var player: Player
var rig: SkinnedRig


func _check(what: String, ok: bool, detail: String = "") -> void:
	print("  %s - %s %s" % ["ok  " if ok else "FAIL", what, detail])
	if not ok:
		_failures += 1


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _initialize() -> void:
	var game := root.get_node_or_null("Game")
	if game != null:
		game.call("choose", &"tariel")
	_world = load(WORLD).instantiate()
	root.add_child(_world)
	await _frames(2)
	player = (_world as World).player()
	player.immortal = true
	for body in _world.find_children("*", "CharacterBody3D", true, false):
		if body != player:
			body.queue_free()
	rig = player.rig as SkinnedRig
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	player.velocity = Vector3.ZERO
	player.global_position = Vector3(0.0, 0.5, 26.0)
	player.rotation.y = 0.0
	await _frames(60)
	player.call(&"_set_weapons_stowed", false)
	await _frames(40)

	_check_matter()
	_check_made()
	await _check_hefts()
	await _check_world()
	await _check_landed()

	if _failures == 0:
		print("All checks passed.")
	else:
		print("%d check(s) FAILED." % _failures)
	quit(1 if _failures > 0 else 0)


func _check_matter() -> void:
	var said := {}
	for kind: String in ["skeleton", "skeleton_warrior", "imp", "orc", "wolf", "golem"]:
		# the Biped Creatures' Brawlers moved into pack/ (2026-10-04)
		var path := "res://scenes/enemies/pack/%s.tscn" % kind
		if not ResourceLoader.exists(path):
			path = "res://scenes/enemies/%s.tscn" % kind
		var n: Node = load(path).instantiate()
		said[kind] = ImpactFx.matter_of(n)
		n.free()
	_check("the skeletons are bone", said["skeleton"] == &"bone" and said["skeleton_warrior"] == &"bone", str(said))
	_check("an imp, an orc, a wolf are flesh", said["imp"] == &"flesh" and said["orc"] == &"flesh" and said["wolf"] == &"flesh")
	_check("a golem is stone", said["golem"] == &"stone")
	var trunk := StaticBody3D.new()
	trunk.name = "Trunks_3_4"
	var solid := StaticBody3D.new()
	solid.name = "Solid_1_2"
	var fence := StaticBody3D.new()
	fence.name = "FenceBody"
	_check("the forest's trunks and the fence are wood, the lands' solids stone",
			ImpactFx.matter_of(trunk) == &"wood" and ImpactFx.matter_of(fence) == &"wood"
			and ImpactFx.matter_of(solid) == &"stone")
	solid.set_meta(&"matter", &"wood")
	_check("a meta says otherwise when set", ImpactFx.matter_of(solid) == &"wood")
	for n: Node in [trunk, solid, fence]:
		n.free()


func _check_made() -> void:
	ImpactFx.warm()
	for what: StringName in [&"bone", &"stone", &"wood", &"guard"]:
		var wav: AudioStreamWAV = ImpactFx._made.get(what, null)
		var peak := 0
		if wav != null:
			for i in range(0, wav.data.size(), 2):
				peak = maxi(peak, absi(wav.data.decode_s16(i)))
		_check("%s has a sound, not silence" % what, wav != null and peak > 6000,
				"(%.2f s, peak %d)" % [wav.get_length() if wav != null else 0.0, peak])


## How many one-shot sounds are playing at `node` now.
func _voices(node: Node) -> int:
	var n := 0
	for c in node.get_children():
		if c is AudioStreamPlayer3D and not c.is_queued_for_deletion():
			n += 1
	return n


func _check_hefts() -> void:
	var heard: Array = []
	var voices: Array = []
	var at: Node = rig._sword_mount if rig._sword_mount != null else rig
	for i in rig.flurry.size():
		rig.attack(CharacterRig.AttackStyle.SIDE)
		heard.append(rig.swing_heft())
		var before := _voices(at)
		rig._whoosh_now()
		voices.append(_voices(at) - before)
		await _frames(4)
	var last := heard.size() - 1
	_check("a string: its first cut, the next, its last", heard[0] == &"first"
			and (last < 2 or heard[1] == &"second") and heard[last] == &"finisher", str(heard))
	_check("its last swing has a rush of air under the slash", voices[last] == 2 and voices[0] == 1, str(voices))
	await _frames(60)
	rig.attack(SkinnedRig.HEAVY)
	var before := _voices(at)
	rig._whoosh_now()
	_check("a heavy blow is heard heavy, with a deep rush", rig.swing_heft() == &"heavy" and _voices(at) - before == 2,
			"(%s)" % rig.swing_heft())
	await _frames(90)


func _wall(named: String, ahead: float) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = named
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(5.0, 3.0, 0.3)
	shape.shape = box
	body.add_child(shape)
	_world.add_child(body)
	body.global_position = player.global_position + Vector3(0.0, 1.5, -ahead)
	return body


func _swing_at(named: String, ahead: float, slot: int = 0) -> Dictionary:
	var wall := _wall(named, ahead)
	await _frames(3)
	player.velocity = Vector3.ZERO
	player.rotation.y = 0.0
	rig.last_world_strike = {}
	var serial0 := rig.attack_serial
	rig._flurry_slot = slot - 1
	rig.attack(CharacterRig.AttackStyle.SIDE)
	await _frames(70)
	var got := rig.last_world_strike.duplicate()
	got["once"] = rig._world_struck >= serial0
	wall.queue_free()
	await _frames(40)
	return got


func _check_world() -> void:
	var stone := await _swing_at("Wall", 0.75)
	_check("a cut into a wall rings off stone", stone.get("matter", &"") == &"stone", str(stone))
	var wood := await _swing_at("Trunks_0_0", 0.75)
	_check("a cut into a trunk knocks in wood", wood.get("matter", &"") == &"wood", str(wood))
	# the string's second cut, a backhand, starts with the blade through it
	var back := await _swing_at("Wall", 0.75, 1)
	_check("a backhand that starts in the wall still meets it", back.get("matter", &"") == &"stone", str(back))
	var none := await _swing_at("Wall", 4.0)
	_check("a cut that does not reach the wall is not heard on it, nor on the ground", none.is_empty() or not none.has("matter"),
			str(none))


func _count_stream(stream: AudioStream) -> int:
	var n := 0
	for p in root.find_children("*", "AudioStreamPlayer3D", true, false):
		if (p as AudioStreamPlayer3D).stream == stream and not p.is_queued_for_deletion():
			n += 1
	return n


func _check_landed() -> void:
	ImpactFx.warm()
	var bone := _count_stream(ImpactFx._made[&"bone"])
	player.net_blade_landed(&"bone")
	_check("his blade in a skeleton: bone cracks", _count_stream(ImpactFx._made[&"bone"]) == bone + 1)
	var thud := _count_stream(ImpactFx._thud)
	player.net_blade_landed()
	_check("in flesh: the wet thud, as before", _count_stream(ImpactFx._thud) == thud + 1)
	var guard := _count_stream(ImpactFx._made[&"guard"])
	var imp: Fighter = load("res://scenes/enemies/imp.tscn").instantiate()
	_world.add_child(imp)
	imp.global_position = player.global_position + Vector3(0.0, 0.0, -2.0)
	await _frames(2)
	imp.net_clash(imp.global_position + Vector3.UP)
	_check("caught on a guard: steel rings", _count_stream(ImpactFx._made[&"guard"]) == guard + 1)
	imp.queue_free()
	await _frames(2)
