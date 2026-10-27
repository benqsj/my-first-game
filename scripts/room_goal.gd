class_name RoomGoal
extends Node

## What a place asks of him besides killing all in it (the user's word,
## 2026-10-21: not every room "kill them all"). Written on the portal that
## leads there, and over the screen while he is in it.
##
## * **captain** — one of them is their captain ([FoeRoles] "captain": a
##   banner at its back, a gold light on it, harder). Kill it and the rest
##   break and run, and are gone.
## * **totems** — three orc totems ([OrcTotem]) stand in the place; while any
##   stands, its creatures are warded and take a third of what they would
##   (a dark red light on them). Break the totems; the place is not clear
##   till they are down.
## * **survive** — the rift stands open the whole time and they keep coming
##   out of it; last [constant SURVIVE_TIME] seconds, and those left run.
##
## The [Dungeon] makes one for a place with a goal ([method make]) after its
## creatures are made, and asks it each frame ([method tick]).

const KINDS := {
	"captain": {"name": "მოკალი მეთაური", "line": "მიზანი: მოკალი მეთაური — დანარჩენები გაიქცევიან"},
	"totems": {"name": "დაანგრიე ტოტემები", "line": "მიზანი: დაანგრიე 3 ტოტემი — სანამ დგანან, მტრები დაცულები არიან"},
	"survive": {"name": "გაუძელი 40 წამს", "line": "მიზანი: გაუძელი 40 წამს"},
}
const SURVIVE_TIME := 40.0
## What a warded creature takes of a blow.
const WARD := 0.35
## In "survive", one out of the rift this often while fewer than
## [constant SURVIVE_UP] are up.
const SURVIVE_EVERY := 1.3
const SURVIVE_UP := 9
const WARD_SHADER_TINT := Color(0.55, 0.0, 0.05)

var kind: String = ""
var _d: Dungeon
var _room: int = -1
var _captain: Fighter
var _totems: Array[OrcTotem] = []
var _left: float = 0.0
var _started: bool = false
var _done: bool = false
var _next_out: float = 0.0
var _timer: Label
var _ward_mat: ShaderMaterial


## A goal for a place at step `step` (none for the first hall, the orcs' or
## the lord's): "" for the plain one, most often.
static func pick(rng: RandomNumberGenerator, step: int, last_step: int) -> String:
	if step < 1 or step >= last_step - 1:
		return ""
	var roll := rng.randf()
	if roll < 0.4:
		return ""
	if roll < 0.6:
		return "captain"
	if roll < 0.8:
		return "totems"
	return "survive"


static func make(d: Dungeon, room: int, what: String) -> RoomGoal:
	var g := RoomGoal.new()
	g.name = "Goal"
	g.kind = what
	g._d = d
	g._room = room
	d.add_child(g)
	g._setup()
	return g


func _setup() -> void:
	match kind:
		"captain":
			for item: Variant in _d._room_foes[_room]:
				if is_instance_valid(item) and FoeRoles.role_of(item as Node) == &"captain":
					_captain = item as Fighter
			if _captain != null:
				_captain.died.connect(_on_captain_died)
		"totems":
			var r := _d._room(_room)
			var w: float = r["w"]
			var l: float = r["l"]
			var spots: Array[Vector3] = [Vector3(-w * 0.3, 0.0, -l * 0.05), Vector3(w * 0.3, 0.0, -l * 0.05),
					Vector3(0.0, 0.0, -l * 0.3)]
			for spot in spots:
				var t := OrcTotem.new()
				t.name = "Totem"
				_d.add_child(t)
				t.global_position = _d.centre(_room) + spot
				t.broken.connect(_on_totem_broken)
				_totems.append(t)
		"survive":
			_left = SURVIVE_TIME


## Once the place wakes.
func start() -> void:
	_started = true
	match kind:
		"totems":
			_ward_all(true)
		"survive":
			_show_timer()
			_d._open_rift()
			_next_out = Time.get_ticks_msec() / 1000.0 + Dungeon.RIFT_TIME
	_d._say(String(KINDS[kind]["line"]), 4.5)


## Whether the place's own waves are left to the [Dungeon] (no: "survive"
## brings them out itself).
func takes_waves() -> bool:
	return kind == "survive"


## Whether the place may be called clear (all its creatures are down).
func may_clear() -> bool:
	match kind:
		"totems":
			for t in _totems:
				if is_instance_valid(t) and not t.is_dead:
					return false
		"survive":
			return _done
	return true


func tick(delta: float) -> void:
	if not _started or _done:
		return
	match kind:
		"totems":
			# what comes out of the rift later is warded too
			_ward_all(_standing() > 0)
		"survive":
			_left -= delta
			if _timer != null:
				_timer.text = "გაუძელი: %d" % ceili(maxf(_left, 0.0))
			var now := Time.get_ticks_msec() / 1000.0
			if now >= _next_out and _up() < SURVIVE_UP and not _d._reserve.is_empty():
				_next_out = now + SURVIVE_EVERY
				_one_out()
			if _left <= 0.0:
				_done = true
				if _timer != null:
					_timer.queue_free()
					_timer = null
				_d._say("გაუძელი!", 3.0)
				_rout()


func _up() -> int:
	var n := 0
	for item: Variant in _d._alive:
		if is_instance_valid(item) and not bool((item as Node).get(&"is_dead")):
			n += 1
	return n


func _standing() -> int:
	var n := 0
	for t in _totems:
		if is_instance_valid(t) and not t.is_dead:
			n += 1
	return n


#region Captain
func _on_captain_died() -> void:
	if _done:
		return
	_done = true
	_d._say("მეთაური მოკვდა — გარბიან!", 3.0)
	_rout()


## The rest break and run for the far end, and are gone (out of the count at
## once, so the place is clear).
func _rout() -> void:
	var r := _d._room(_room)
	var l: float = r["l"]
	var w: float = r["w"]
	var c := _d.centre(_room)
	for item: Variant in _d._reserve.duplicate():
		if is_instance_valid(item):
			(item as Node).queue_free()
	_d._reserve.clear()
	if is_instance_valid(_d._rift):
		var gone := _d._rift
		_d._rift = null
		var tw := _d.create_tween()
		tw.tween_property(gone, "scale", Vector3(0.02, 0.02, 0.02), 1.0)
		tw.tween_callback(gone.queue_free)
	_d._rift_at = -1.0
	_d._rift_due = -1.0
	var running: Array[Node3D] = []
	for item: Variant in _d._alive:
		if not is_instance_valid(item) or bool((item as Node).get(&"is_dead")):
			continue
		running.append(item as Node3D)
	_d._alive.clear()
	for k in running.size():
		var body := running[k]
		var away := c + Vector3(clampf(body.global_position.x - c.x, -w * 0.4, w * 0.4) + (-6.0 if k % 2 == 0 else 6.0),
				0.0, -l * 0.45)
		if "leash_radius" in body:
			body.set(&"leash_radius", 0.01)
		if "_home" in body:
			body.set(&"_home", away)
		body.set(&"camp_centre", away)
		body.set(&"held_back", false)
		if "mode" in body:
			body.set(&"mode", Fighter.Mode.RETURN)
		_d.get_tree().create_timer(2.6 + 0.15 * float(k)).timeout.connect(_vanish.bind(body))


func _vanish(body: Node3D) -> void:
	if not is_instance_valid(body):
		return
	var world := Blood.world_of(_d)
	if world != null:
		SkillFx.burst(world, body.global_position + Vector3.UP * 1.0, Color(0.85, 0.2, 0.25), 30, Vector2(1.0, 3.5),
				Vector3.UP, 180.0, Vector2(0.06, 0.16), Vector3(0, -1.0, 0), 0.8)
	Sfx.play(_d, Dungeon.SND + "portal_whoosh.wav", null, body.global_position + Vector3.UP, 1.2, -6.0)
	body.queue_free()
#endregion


#region Totems
func _on_totem_broken() -> void:
	var standing := _standing()
	if standing > 0:
		_d._say("ტოტემი დაინგრა — დარჩა %d" % standing, 2.5)
	else:
		_d._say("ტოტემები დაინგრა — დაცვა მოიხსნა!", 3.0)
		_ward_all(false)


## Every creature of the place warded (taking `WARD` of each blow, a dark red
## light on it), or not.
func _ward_all(on: bool) -> void:
	if _ward_mat == null:
		_ward_mat = ShaderMaterial.new()
		var sh := Shader.new()
		sh.code = FoeRoles.RIM_SHADER
		_ward_mat.shader = sh
		_ward_mat.set_shader_parameter(&"tint", WARD_SHADER_TINT)
		_ward_mat.set_shader_parameter(&"amount", 1.2)
	for item: Variant in _d._room_foes[_room]:
		if not is_instance_valid(item):
			continue
		var f := item as Fighter
		if f == null or f.is_dead:
			continue
		var was := f.ward < 1.0
		if on == was:
			continue
		f.ward = WARD if on else 1.0
		if f.has_meta(&"empowered_until"):
			continue
		FoeRoles._overlay(f, _ward_mat if on else (f.get_meta(&"rim") as Material if f.has_meta(&"rim") else null))
#endregion


#region Survive
func _show_timer() -> void:
	_timer = Label.new()
	_timer.anchor_left = 0.5
	_timer.anchor_right = 0.5
	_timer.offset_left = -200
	_timer.offset_right = 200
	_timer.offset_top = 150
	_timer.offset_bottom = 200
	_timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_timer.add_theme_font_size_override("font_size", 34)
	_timer.add_theme_color_override("font_color", Color(1.0, 0.82, 0.5))
	_timer.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_timer.add_theme_constant_override("outline_size", 8)
	_d._layer.add_child(_timer)


## One of those waiting out of the rift, at him.
func _one_out() -> void:
	var body: Node3D = null
	while not _d._reserve.is_empty() and body == null:
		var item: Variant = _d._reserve.pop_front()
		if is_instance_valid(item) and not bool((item as Node).get(&"is_dead")):
			body = item as Node3D
	if body == null:
		return
	var at: Vector3 = _d._rift.global_position if is_instance_valid(_d._rift) else _d.centre(_room)
	_d._alive.append(body)
	_d._spawned += 1
	_d._step_out(body, at + Vector3(randf_range(-2.0, 2.0), 0.3, 2.4), float(_d._room(_room)["l"]))
#endregion


func _exit_tree() -> void:
	if _timer != null and is_instance_valid(_timer):
		_timer.queue_free()
	for t in _totems:
		if is_instance_valid(t):
			t.queue_free()
