extends SceneTree
## What one player does, the other sees (the user's word, 2026-10-24: in
## co-op every skill, climb, block, fall and get-up, dodge must show on the
## other machine — effect, animation, state).
##
## Two games, a host and one who joins (ENet on this machine), both playing
## the same hero. The host does everything in turn while the other watches,
## then the other way round. Each game writes down, every frame, what each
## hero's body shows (its clip, its state, guard, down, on a wall, crouched,
## seen) and every effect that comes up near him; afterwards the doer's own
## record is set against the watcher's, action by action: what the doer saw
## and the watcher did not is a FAIL.
##
##   Godot --headless --path . --script res://tests/coop_seen_test.gd [-- hero ...]
## (no heroes named: every hero there is). The two games are started by this
## one (`--cs-role host|join`); the records are in /tmp/coop_seen/<hero>/.

const GAME := preload("res://scripts/game.gd")
const DIR := "/tmp/coop_seen"
const ME := "res://tests/coop_seen_test.gd"
## A pair's whole run may take this long before it is called stuck (s).
const PAIR_MOST := 260.0
## How much later the watcher may show it (s), and how much longer.
const LAG := 0.12
const TAIL := 0.8
## What the doer showed for less than this (ms) is not asked of the watcher.
const BLINK := 120
## Effects counted: within this of a hero.
const NEAR := 25.0
const EFFECTS := ["GPUParticles3D", "CPUParticles3D", "MeshInstance3D", "Decal", "OmniLight3D", "SpotLight3D",
		"Area3D", "RigidBody3D", "Label3D", "Sprite3D", "FogVolume", "AudioStreamPlayer3D", "MultiMeshInstance3D"]

var _role := ""
var _dir := ""
var _hero := &"tariel"
var _t0 := 0
var _events: Array = []
var _pos: Array = []
var _vfx: Array = []
var _shown: Dictionary = {}
var _windows: Array = []
var _pos_at := 0.0
var _world: World
var _boxes_built: Dictionary = {}
var _cast := 0
var _struck_by: Array[String] = []
var _clean := RegEx.new()


func _initialize() -> void:
	_clean.compile("(@\\d+)$|\\d+$")
	var args := OS.get_cmdline_user_args()
	var at := args.find("--cs-role")
	if at >= 0:
		_role = args[at + 1]
		_dir = args[args.find("--cs-dir") + 1]
		for word in args:
			if GAME.CHARACTERS.has(StringName(word)):
				_hero = StringName(word)
		_child.call_deferred()
	else:
		_master.call_deferred()


func _ms() -> int:
	return int(Time.get_unix_time_from_system() * 1000.0)


func _say(s: String) -> void:
	print("[%s %s] %s" % [_role.to_upper(), _hero, s])


#region The one that starts the pairs and reads their records
func _master() -> void:
	var heroes: Array[StringName] = []
	for word in OS.get_cmdline_user_args():
		if GAME.CHARACTERS.has(StringName(word)):
			heroes.append(StringName(word))
	if heroes.is_empty():
		for id: StringName in GAME.CHARACTERS:
			heroes.append(id)
	DirAccess.make_dir_recursive_absolute(DIR)
	var failures := 0
	var report: PackedStringArray = []
	for hero in heroes:
		var lines := await _pair(hero)
		for line in lines:
			if line.begins_with("  FAIL"):
				failures += 1
		report.append_array(lines)
	print("\n".join(report))
	var f := FileAccess.open(DIR + "/report.txt", FileAccess.WRITE)
	f.store_string("\n".join(report))
	f.close()
	print("coop_seen_test: %s" % ("All checks passed." if failures == 0 else "%d FAILED" % failures))
	quit(1 if failures > 0 else 0)


func _pair(hero: StringName) -> PackedStringArray:
	var dir := "%s/%s" % [DIR, hero]
	DirAccess.make_dir_recursive_absolute(dir)
	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)
	var exe := OS.get_executable_path()
	var base := ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", ME, "--"]
	var host := OS.create_process(exe, base + ["--host", String(hero), "--cs-role", "host", "--cs-dir", dir])
	var join := -1
	var t := 0.0
	var out: PackedStringArray = ["", "== %s" % hero]
	while t < PAIR_MOST:
		await create_timer(0.5).timeout
		t += 0.5
		if join < 0 and FileAccess.file_exists(dir + "/host_up"):
			join = OS.create_process(exe, base + ["--join", "127.0.0.1", String(hero), "--cs-role", "join", "--cs-dir", dir])
		if FileAccess.file_exists(dir + "/host.json") and FileAccess.file_exists(dir + "/join.json"):
			break
	for pid in [host, join]:
		if pid > 0 and OS.is_process_running(pid):
			await create_timer(3.0).timeout
			if OS.is_process_running(pid):
				OS.kill(pid)
	if not (FileAccess.file_exists(dir + "/host.json") and FileAccess.file_exists(dir + "/join.json")):
		out.append("  FAIL - the two games did not finish (%.0f s): host_up=%s" % [t, FileAccess.file_exists(dir + "/host_up")])
		return out
	var h: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(dir + "/host.json"))
	var j: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(dir + "/join.json"))
	out.append("  (host does, the other watches)")
	out.append_array(_compare(h, j))
	out.append("  (the one who joined does, the host watches)")
	out.append_array(_compare(j, h))
	return out


## The doer's record against the watcher's, window by window.
func _compare(doer: Dictionary, watcher: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = []
	var key := String(doer["me"])
	if (doer["windows"] as Array).is_empty():
		out.append("  FAIL - nothing was done (%s)" % str(doer.get("note", "")))
	for w: Array in doer["windows"]:
		var name := String(w[0])
		var a := int(w[1])
		var b := int(w[2])
		var note := String(w[3])
		if note.begins_with("skip"):
			out.append("  info - %s: %s" % [name, note])
			continue
		var lag := int(LAG * 1000.0)
		var tail := int(TAIL * 1000.0)
		var problems: PackedStringArray = []
		for field in ["clip", "st", "blk", "down", "wall", "crouch", "vis"]:
			var seen := _values(doer, key, field, a, b, BLINK)
			var there := _values(watcher, key, field, a - lag, b + tail)
			var missing: Array = []
			for v: Variant in seen:
				if not there.has(v):
					missing.append(_named(field, v))
			if not missing.is_empty():
				var shown: Array = []
				for v: Variant in there:
					shown.append(_named(field, v))
				problems.append("%s %s not shown (shown: %s)" % [field, str(missing), str(shown)])
		var fx := _effects(doer, key, a, b)
		var fx_there := _effects(watcher, key, a - lag, b + tail)
		# (an effect is asked to be there at all, not as many times: a trail of
		# shadows drops a copy every few frames, and the frames differ)
		var fx_missing: Array = []
		var fx_noise: Array = []
		for sig: String in fx:
			if fx_there.has(sig) or HIS_OWN.has(sig):
				continue
			if _of_motion(sig):
				fx_noise.append(sig)
			else:
				fx_missing.append(sig)
		if not fx_missing.is_empty():
			problems.append("effects %s not shown" % str(fx_missing))
		if not fx_noise.is_empty():
			note = ("%s (not seen, of each game's own reading of his motion: %s)" % [note, str(fx_noise)]).strip_edges()
		var moved := _moved(doer, key, a, b)
		var moved_there := _moved(watcher, key, a - lag, b + tail)
		# (a copy that is caught up over the wire overshoots a little on a
		# quick skill's dash)
		if absf(moved - moved_there) > maxf(1.0, 0.3 * moved):
			problems.append("moved %.1f m, seen to move %.1f m" % [moved, moved_there])
		if problems.is_empty():
			out.append("  ok   - %s %s" % [name, note])
		else:
			out.append("  FAIL - %s %s: %s" % [name, note, "; ".join(problems)])
	return out


## The values `field` of body `key` took between `a` and `b` (and the one it
## had coming in); with `least`, only those it held at least that long (ms):
## a blink of three frames is not something to send.
## What each game makes of a body's motion by itself, every frame (the
## footfalls, the dust of pulling up short): one more or less on either
## side is not something sent or missed.
func _of_motion(sig: String) -> bool:
	return sig.begins_with("AudioStreamPlayer3D:step") or sig.begins_with("DustRing:")


## Shown to the one who does it alone, on purpose: the glint on the arrow's
## head at the moment to let go is the archer's own cue
## ([method SkinnedArcherRig._glint]), not something the others are to see.
const HIS_OWN := ["MeshInstance3D:bow_arrow/MeshInstance3D"]


func _values(rec: Dictionary, key: String, field: String, a: int, b: int, least: int = 0) -> Array:
	var mine: Array = []
	for e: Array in rec["events"]:
		if String(e[1]) == key and String(e[2]) == field:
			mine.append(e)
	var out: Array = []
	for k in mine.size():
		var e: Array = mine[k]
		var t := int(e[0])
		var until := int(mine[k + 1][0]) if k + 1 < mine.size() else 1 << 62
		if until <= a or t > b:
			continue
		if least > 0 and until - t < least:
			continue
		if not out.has(e[3]):
			out.append(e[3])
	# the dull ones say nothing: no clip at all
	if field == "clip":
		out = out.filter(func(v: Variant) -> bool: return String(v) != "")
	return out


func _named(field: String, v: Variant) -> String:
	if field == "st":
		var k: Variant = Player.State.find_key(int(v))
		return String(k) if k != null else str(v)
	return str(v)


func _effects(rec: Dictionary, key: String, a: int, b: int) -> Dictionary:
	var out := {}
	for e: Array in rec["vfx"]:
		var t := int(e[0])
		if t >= a and t <= b and String(e[2]) == key:
			out[String(e[1])] = int(out.get(String(e[1]), 0)) + 1
	return out


func _moved(rec: Dictionary, key: String, a: int, b: int) -> float:
	var start: Variant = null
	var most := 0.0
	for p: Array in rec["pos"]:
		if String(p[1]) != key:
			continue
		var t := int(p[0])
		if t < a or t > b:
			continue
		var at := Vector3(float(p[2]), float(p[3]), float(p[4]))
		if start == null:
			start = at
		most = maxf(most, at.distance_to(start as Vector3))
	return most
#endregion


#region One of the two games
func _child() -> void:
	node_added.connect(_on_added)
	var t := 0.0
	var ready_at := -1.0
	var phase := "wait"
	var note := ""
	while t < PAIR_MOST - 20.0:
		await physics_frame
		t += 1.0 / float(Engine.physics_ticks_per_second)
		_world = current_scene as World
		if _world == null or _world._players == null:
			continue
		if _role == "host" and not FileAccess.file_exists(_dir + "/host_up") and _world.player() != null:
			_mark("host_up")
		_record(t)
		_build_boxes()
		if _world.players().size() < 2:
			continue
		if ready_at < 0.0:
			ready_at = t
			_mark(_role + "_ready")
		if t - ready_at < 4.0:
			continue
		var both := FileAccess.file_exists(_dir + "/host_ready") and FileAccess.file_exists(_dir + "/join_ready")
		match phase:
			"wait":
				if both and (_role == "host" or FileAccess.file_exists(_dir + "/A_done")):
					phase = "act"
					if _role == "join":
						await _hold(1.5, t)
					note = await _act()
					_mark("A_done" if _role == "host" else "B_done")
					phase = "watch"
			"watch":
				if _role == "join" or FileAccess.file_exists(_dir + "/B_done"):
					await _hold(2.0, t)
					break
	_write(note)
	quit(0)


func _mark(file: String) -> void:
	var f := FileAccess.open(_dir + "/" + file, FileAccess.WRITE)
	f.store_string(str(_ms()))
	f.close()


## Physics frames for `seconds`, recording all the while.
func _hold(seconds: float, _t: float = 0.0) -> void:
	var n := int(seconds * float(Engine.physics_ticks_per_second))
	for i in n:
		await physics_frame
		_record(0.0)
		_build_boxes()


func _write(note: String) -> void:
	var me := _world.player() if _world != null else null
	var data := {"me": String(me.name) if me != null else "", "windows": _windows, "events": _events,
			"pos": _pos, "vfx": _vfx, "note": note}
	var f := FileAccess.open("%s/%s.json" % [_dir, _role], FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()
	_say("written: %d windows, %d events, %d effects" % [_windows.size(), _events.size(), _vfx.size()])


## What each body shows now, written down when it changes.
func _record(_t: float) -> void:
	if _world == null or _world._players == null:
		return
	var now := _ms()
	var sample := float(now) / 1000.0 - _pos_at >= 0.1
	if sample:
		_pos_at = float(now) / 1000.0
	for body in _world.players():
		var key := String(body.name)
		var local := body.is_multiplayer_authority()
		var rig: Node = body.rig
		var clip := ""
		if rig != null and "_anim" in rig and rig.get("_anim") != null:
			clip = String((rig.get("_anim") as AnimationPlayer).current_animation)
		var row := {
			"clip": clip,
			"st": int(body.state) if local else int(body.net_state),
			"blk": body.is_blocking if local else body.net_blocking,
			"down": rig != null and rig.has_method(&"is_down") and bool(rig.call(&"is_down")),
			"wall": rig != null and rig.has_method(&"is_wall_climbing") and bool(rig.call(&"is_wall_climbing")),
			"crouch": rig != null and rig.has_method(&"is_crouched") and bool(rig.call(&"is_crouched")),
			"vis": body.is_visible_in_tree() and (rig == null or (rig as Node3D).is_visible_in_tree()),
		}
		var was: Dictionary = _shown.get(key, {})
		for field: String in row:
			if not was.has(field) or was[field] != row[field]:
				_events.append([now, key, field, row[field]])
		_shown[key] = row
		if sample:
			var p := body.global_position
			_pos.append([now, key, snappedf(p.x, 0.01), snappedf(p.y, 0.01), snappedf(p.z, 0.01)])


func _on_added(node: Node) -> void:
	if not (node is Node3D) or _world == null:
		return
	var cls := node.get_class()
	if not EFFECTS.has(cls) and node.get_script() == null:
		return
	_note_effect.call_deferred(node, _ms())


func _note_effect(node: Node, at: int) -> void:
	if not is_instance_valid(node) or not node.is_inside_tree() or _world == null or _world._players == null:
		return
	var n := node as Node3D
	# not the bodies themselves being put together
	for body in _world.players():
		if body == n or (body.rig != null and (body.rig as Node).is_ancestor_of(n) and n is MeshInstance3D
				and (n as MeshInstance3D).skeleton != NodePath()):
			return
	var best := ""
	var near := NEAR
	for body in _world.players():
		var d := body.global_position.distance_to(n.global_position)
		if d < near:
			near = d
			best = String(body.name)
	if best == "":
		return
	var script := n.get_script() as Script
	var kind := script.get_global_name() if script != null and script.get_global_name() != &"" else StringName(n.get_class())
	var name := _clean.sub(String(n.name).trim_prefix("@"), "", true).trim_suffix("_").trim_suffix("@")
	if n is AudioStreamPlayer3D and (n as AudioStreamPlayer3D).stream != null:
		# (a sound's take is picked at random on each peer: step_3 here,
		# step_5 there is the same footfall)
		var stream := (n as AudioStreamPlayer3D).stream
		name = _clean.sub(stream.resource_path.get_file().get_basename(), "", true).trim_suffix("_") \
				if stream.resource_path != "" else stream.get_class()
	elif name == n.get_class() and n.get_parent() != null:
		# a bare mesh says nothing: what it hangs under does
		name = "%s/%s" % [_clean.sub(String(n.get_parent().name).trim_prefix("@"), "", true).trim_suffix("@"), name]
	_vfx.append([at, "%s:%s" % [kind, name], best])
#endregion


#region The doer
## Where he does it all: a ledge to pull up onto and a wall to climb, on flat
## ground by where he came in; the other game builds the same from the file.
func _spot_and_boxes(me: Player) -> Vector3:
	var spot := me.global_position
	var space := root.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(spot + Vector3.UP * 3.0, spot + Vector3.DOWN * 10.0, 1)
	var hit := space.intersect_ray(q)
	if not hit.is_empty():
		spot.y = (hit["position"] as Vector3).y
	if _role == "host":
		var quarry_at := spot + Vector3(-3.0, 0.0, -9.0)
		var fq := FileAccess.open("%s/quarry.json" % _dir, FileAccess.WRITE)
		fq.store_string(JSON.stringify([quarry_at.x, quarry_at.y, quarry_at.z]))
		fq.close()
	var boxes := [
		[spot + Vector3(0.0, 0.65, -1.3), Vector3(2.6, 1.3, 1.2)],
		[spot + Vector3(7.0, 4.0, -1.0), Vector3(4.0, 8.0, 1.0)],
	]
	var wire: Array = []
	for b: Array in boxes:
		var at: Vector3 = b[0]
		var size: Vector3 = b[1]
		wire.append([at.x, at.y, at.z, size.x, size.y, size.z])
	var f := FileAccess.open("%s/%s_boxes.json" % [_dir, _role], FileAccess.WRITE)
	f.store_string(JSON.stringify(wire))
	f.close()
	return spot


func _build_boxes() -> void:
	if _world == null:
		return
	_make_quarry()
	var quarry := _world.get_node_or_null("Enemies/CoopSeenQuarry")
	if quarry != null and quarry.is_inside_tree() and quarry.process_mode != Node.PROCESS_MODE_DISABLED:
		quarry.process_mode = Node.PROCESS_MODE_DISABLED
	for who in ["host", "join"]:
		var file := "%s/%s_boxes.json" % [_dir, who]
		if _boxes_built.has(who) or not FileAccess.file_exists(file):
			continue
		var wire: Variant = JSON.parse_string(FileAccess.get_file_as_string(file))
		if not (wire is Array):
			continue
		_boxes_built[who] = true
		for b: Array in wire:
			var body := StaticBody3D.new()
			body.collision_layer = 1
			var shape := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = Vector3(float(b[3]), float(b[4]), float(b[5]))
			shape.shape = box
			body.add_child(shape)
			var look := MeshInstance3D.new()
			var mesh := BoxMesh.new()
			mesh.size = box.size
			look.mesh = mesh
			body.add_child(look)
			body.name = "CoopSeenBox"
			_world.add_child(body)
			body.global_position = Vector3(float(b[0]), float(b[1]), float(b[2]))


## Something for the skills that want a creature to go at (the Hunter's
## Mark): a goblin that sees no one, made on both games under the same name
## so a skill's path to it means it on both.
func _make_quarry() -> void:
	var file := "%s/quarry.json" % _dir
	if _boxes_built.has("quarry") or not FileAccess.file_exists(file):
		return
	var at: Variant = JSON.parse_string(FileAccess.get_file_as_string(file))
	var enemies := _world.get_node_or_null("Enemies")
	if not (at is Array) or enemies == null:
		return
	_boxes_built["quarry"] = true
	var body := (load("res://scenes/enemies/pack/goblin.tscn") as PackedScene).instantiate() as Node3D
	body.name = "CoopSeenQuarry"
	if "sight_range" in body:
		body.set("sight_range", 0.0)
	# (it stands through both turns: the arrows of the first do not kill it)
	if "max_health" in body:
		body.set("max_health", 1.0e7)
	body.position = Vector3(float(at[0]), float(at[1]) + 0.2, float(at[2]))
	if "camp_centre" in body:
		body.set("camp_centre", body.position)
	enemies.add_child(body)
	# still as a post: struck by the skills it would rouse and come at him
	# (the falls it dealt muddled the skills' windows)
	body.set_deferred(&"process_mode", Node.PROCESS_MODE_DISABLED)


func _act() -> String:
	var me := _world.player()
	if me == null:
		return "no hero"
	me.immortal = true
	me.skill_used.connect(func(_slot: int, _id: StringName) -> void: _cast += 1)
	me.struck.connect(func(_damage: float, _blocked: bool) -> void:
		_struck_by.append("%s from %s" % [String(me.get(&"_blow_name")), str(me.get(&"_blow_source"))]))
	var spot := _spot_and_boxes(me)
	await _hold(0.6)
	await _place(me, spot)
	await _window("stand", func() -> String: return "", 1.0)
	await _window("attack", func() -> String:
		_tap(&"attack")
		return "", 1.6)
	await _place(me, spot)
	await _window("block", func() -> String:
		Input.action_press(&"block")
		return "", 1.4)
	Input.action_release(&"block")
	await _hold(0.6)
	await _place(me, spot)
	await _window("dodge", func() -> String:
		Input.action_press(&"move_forward")
		_tap(&"dash")
		return "", 1.4)
	Input.action_release(&"move_forward")
	await _place(me, spot + Vector3(0.0, 0.0, 3.0))
	await _window("jump", func() -> String:
		_tap(&"jump")
		return "", 1.4)
	await _place(me, spot)
	await _window("climb (ledge)", func() -> String:
		_tap(&"jump")
		return "", 2.4)
	if me.profile != null and not me.profile.can_climb:
		_windows.append(["climb (wall)", _ms(), _ms(), "skip: this hero does not climb walls"])
	else:
		await _place(me, spot + Vector3(7.0, 0.0, 0.0))
		await _window("climb (wall)", func() -> String:
			_tap(&"jump")
			return "", 2.4)
		await _window("let go of the wall", func() -> String:
			_tap(&"crouch")
			return "", 1.6)
	await _place(me, spot + Vector3(0.0, 0.0, 3.0))
	await _window("knocked down, gets up", func() -> String:
		me.net_blow(30.0, Vector3(0.0, 0.0, 2.5), me.global_position + Vector3(0.0, 0.0, -1.5), "cs#1", 0, 2)
		me.net_blow(30.0, Vector3(0.0, 0.0, 2.5), me.global_position + Vector3(0.0, 0.0, -1.5), "cs#1", 1, 2)
		return "state=%s" % str(Player.State.find_key(me.state)), 6.5)
	for slot in Player.SKILL_SLOTS:
		var id := me.skill_in(slot)
		if id == &"":
			continue
		await _place(me, spot + Vector3(0.0, 0.0, 3.0))
		me.stamina = me.max_stamina
		var before := _cast
		var action := StringName("skill_%d" % (slot + 1))
		await _window("skill %d %s" % [slot + 1, id], func() -> String:
			_tap(action)
			return "", 3.6)
		var w: Array = _windows.back()
		if _cast == before:
			w[3] = "skip: did not go off (needs a creature?)"
		await _hold(0.5)
	return ""


## Stood at `at`, facing −Z, still, on his feet.
func _place(me: Player, at: Vector3) -> void:
	for i in 40:
		if me.state == Player.State.GROUNDED and not me.is_committed():
			break
		await _hold(0.1)
	me.global_position = at + Vector3.UP * 0.2
	me.velocity = Vector3.ZERO
	me.rotation.y = 0.0
	await _hold(0.5)


func _tap(action: StringName) -> void:
	Input.action_press(action)
	await physics_frame
	await physics_frame
	await physics_frame
	Input.action_release(action)


## Does `what` and records `seconds` of it as one window.
func _window(name: String, what: Callable, seconds: float) -> void:
	var a := _ms()
	_struck_by.clear()
	var note := String(what.call())
	await _hold(seconds)
	var states: Array = []
	for v: Variant in _values({"events": _events}, String(_world.player().name), "st", a, _ms(), BLINK):
		states.append(_named("st", v))
	note = ("%s [%s]" % [note, ",".join(states)]).strip_edges()
	if not _struck_by.is_empty() and not name.begins_with("knocked"):
		note += " struck: %s" % str(_struck_by)
	_windows.append([name, a, _ms(), note])
	_say("%s %s" % [name, note])
	# a gap before the next is set up, longer than the watcher's tail
	await _hold(TAIL + 0.4)
#endregion
