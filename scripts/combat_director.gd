class_name CombatDirector
extends Node

## How hard the portal's fight presses him, from moment to moment (the user's
## word, 2026-10-27: a souls-like, hard but never impossible, and never made
## easier than it is). One under each [Dungeon], on every peer.
##
## * **Pressure** (0..1): it rises while he fights untouched and whole, and
##   falls back the moment he is hurt, low or down. It only ever adds to the
##   room's own measure: at 0 the fight is as it was made, never easier.
## * **Turns at him by weight** ([method choose]): instead of "two at once" a
##   budget, the small ones (imps, puglins, goblins, wolves) costing less than
##   the rest, one behind his back costing more; the budget grows with the
##   steps and with the pressure, and now and then one more comes in.
## * **The throws' turn** ([member Fighter.throw_gap]) shorter as it presses.
## * **Tells**: as a creature begins a blow a glint at it, white for a light
##   one, red for a heavy one.
## * **From behind**: a creature striking at his back, or a shot coming at it,
##   shows as a mark at the screen's edge on its side.
## * **F7**: what it is doing, on the screen (for tuning).

## The budget at one hero: at the first steps, and how much it grows a step.
const BUDGET := 2.0
const BUDGET_PER_STEP := 0.12
const BUDGET_UNDER_FIRE := 1.0
## What pressure adds to the budget at its most, and takes off the throws' gap.
const PRESS_BUDGET := 1.0
const PRESS_THROWS := 0.3
## How fast pressure comes (per second, while he is untouched) and goes.
const PRESS_UP := 0.03
const PRESS_DOWN := 0.4
## Hurt this share of his life within [constant WINDOW] s: no more pressure.
const WINDOW := 12.0
const HURT_ENOUGH := 0.25
## Under this share of his life: the fight as it was made, nothing on top.
const LOW := 0.3
## A small one's cost, one at his back's extra.
const SMALL := 0.75
const BEHIND := 0.5
const SMALL_KINDS := ["imp.tscn", "puglin.tscn", "goblin.tscn", "wolf.tscn"]
## Now and then one more for a while: for how long, how long between (the
## latter shorter as it presses).
const EXTRA_FOR := Vector2(3.5, 6.0)
const EXTRA_EVERY := Vector2(9.0, 16.0)
## Nearer than this to a hero, a held one has its turn at once (he walked up).
const CLOSE_IN := 3.2
## The edge marks: how near a striker or a shot is to be shown.
const MARK_STRIKER := 10.0
const MARK_SHOT := 16.0

var pressure: float = 0.0
var budget_now: float = 0.0
var spent_now: float = 0.0
var extra_on: bool = false

var _d: Dungeon
var _hurts: Array = []
var _last_health: Dictionary = {}
var _extra_until := 0.0
var _extra_next := 0.0
var _clock := 0.0
var _serials: Dictionary = {}
var _marks: Control
var _debug: Label
var _show_debug := false


func setup(d: Dungeon) -> void:
	_d = d
	_extra_next = _now() + randf_range(EXTRA_EVERY.x, EXTRA_EVERY.y)


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


#region Pressure
func _process(delta: float) -> void:
	if _d == null:
		return
	_clock -= delta
	if _clock <= 0.0:
		_clock = 0.25
		_feel(0.25)
		if _d.decides() and Fighter.throw_gap > 0.0:
			Fighter.throw_gap = Dungeon.THROW_GAP * (1.0 - PRESS_THROWS * pressure)
	_tells()
	_edge_marks()
	if _show_debug:
		_write_debug()


## What he has taken lately and how whole he is, and the pressure after it.
func _feel(dt: float) -> void:
	var now := _now()
	var worst := 1.0
	var fighting := false
	for hero in _d._heroes():
		if hero.is_dead:
			worst = 0.0
			continue
		var was := float(_last_health.get(hero, hero.health))
		if hero.health < was - 0.01:
			_hurts.append([now, (was - hero.health) / maxf(hero.max_health, 1.0)])
		_last_health[hero] = hero.health
		worst = minf(worst, hero.health / maxf(hero.max_health, 1.0))
	while not _hurts.is_empty() and now - float(_hurts[0][0]) > WINDOW:
		_hurts.pop_front()
	var taken := 0.0
	for h: Array in _hurts:
		taken += float(h[1])
	for body in _d._alive:
		if is_instance_valid(body) and not bool(body.get("is_dead")) and body.visible:
			fighting = true
			break
	if not fighting:
		return
	if worst < LOW or taken >= HURT_ENOUGH:
		pressure = maxf(pressure - PRESS_DOWN * dt, 0.0)
	elif taken < HURT_ENOUGH * 0.4:
		pressure = minf(pressure + PRESS_UP * dt, 1.0)
	# low: nothing on top of the room's own measure, at once
	if worst < LOW:
		pressure = 0.0
#endregion


#region Turns
static func cost_of(body: Node3D) -> float:
	var path := String(body.scene_file_path)
	for k: String in SMALL_KINDS:
		if path.ends_with(k):
			return SMALL
	return 1.0


## Whether `at` is behind the eye looking at `hero` (his back, as he sees it).
func _behind(at: Vector3) -> bool:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam == null:
		return false
	var to := at - cam.global_position
	to.y = 0.0
	var fwd := -cam.global_transform.basis.z
	fwd.y = 0.0
	return to.length() > 0.1 and fwd.normalized().dot(to.normalized()) < -0.2


## Of `small` ([gap, body] near the heroes, nearest first), those that have
## their turn at him now; `holders` those that had it.
func choose(small: Array, holders: Array[Node3D], heroes: int, shooters: int, brutes: int) -> Array[Node3D]:
	var now := _now()
	if now >= _extra_next:
		_extra_until = now + randf_range(EXTRA_FOR.x, EXTRA_FOR.y)
		var every := randf_range(EXTRA_EVERY.x, EXTRA_EVERY.y) / (1.0 + pressure)
		_extra_next = _extra_until + every
	# (low, the room as it was made: no one more on top)
	extra_on = now < _extra_until and not _low()
	var under_fire := shooters >= Dungeon.SHOOTERS_MANY
	var base := BUDGET_UNDER_FIRE if under_fire else BUDGET + BUDGET_PER_STEP * float(maxi(_d.stage_of(_d.current) - 1, 0))
	var per := base + PRESS_BUDGET * pressure + (1.0 if extra_on else 0.0)
	budget_now = maxf(per * float(heroes) - float(brutes), 0.0)
	var keep: Array[Node3D] = []
	# (in an array: a lambda keeps its own copy of a plain number)
	var spent := [0.0]
	var take := func(body: Node3D) -> void:
		var c := cost_of(body) + (BEHIND if _behind(body.global_position) else 0.0)
		# the first always fits; then while there is budget
		if keep.has(body) or budget_now <= 0.0 or (not keep.is_empty() and float(spent[0]) + c > budget_now + 0.01):
			return
		keep.append(body)
		spent[0] = float(spent[0]) + c
	# he walked up to it: its turn at once
	for pair: Array in small:
		if float(pair[0]) < CLOSE_IN:
			take.call(pair[1])
	for h in holders:
		for pair: Array in small:
			if pair[1] == h and float(pair[0]) < 11.0:
				take.call(h)
	for pair: Array in small:
		take.call(pair[1])
	spent_now = float(spent[0])
	return keep


func _low() -> bool:
	for hero in _d._heroes():
		if not hero.is_dead and hero.health < hero.max_health * LOW:
			return true
	return false
#endregion


#region Tells
## A glint at each creature as it begins a blow: white light, red heavy.
func _tells() -> void:
	for body in _d._alive:
		var f := body as Fighter
		if f == null or not is_instance_valid(f) or f.is_dead or not f.visible:
			continue
		var serial := int(f.act_serial)
		if int(_serials.get(f, -1)) == serial:
			continue
		_serials[f] = serial
		if not striking(f):
			continue
		_glint(f, heavy(f))


static func striking(f: Fighter) -> bool:
	if f.act == Fighter.Act.NONE:
		return false
	if f.has_method(&"_strikes"):
		var all: Variant = f.call(&"_strikes")
		if all is Array or all is Dictionary:
			return all.has(f.act)
	return f.act == Fighter.Act.ATTACK


static func heavy(f: Fighter) -> bool:
	return f is PackBrute or f.has_meta(&"elite") or f.has_meta(&"boss") or f.hit_damage >= 24.0


func _glint(f: Fighter, red: bool) -> void:
	var world := Blood.world_of(f)
	if world == null:
		return
	var s := maxf(f.visual_scale, 0.3)
	var at := f.global_position + Vector3.UP * clampf(f.bar_height * s * 0.8, 1.0, 4.5)
	var star := Node3D.new()
	world.add_child(star)
	star.global_position = at
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.no_depth_test = true
	mat.albedo_texture = SkillFx.dot()
	mat.albedo_color = Color(1.0, 0.18, 0.1) if red else Color(1.0, 0.97, 0.88)
	for k in 2:
		var q := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(1.6, 0.16) if k == 0 else Vector2(0.16, 1.6)
		q.mesh = quad
		q.material_override = mat
		q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		star.add_child(q)
	var core := MeshInstance3D.new()
	var dot := QuadMesh.new()
	dot.size = Vector2(0.55, 0.55)
	core.mesh = dot
	core.material_override = mat
	star.add_child(core)
	star.scale = Vector3.ONE * 0.05
	var big := (1.25 if red else 0.9) * clampf(s, 0.8, 1.6)
	var tw := star.create_tween()
	tw.tween_property(star, "scale", Vector3.ONE * big, 0.09).set_ease(Tween.EASE_OUT)
	tw.tween_property(star, "scale", Vector3.ONE * 0.05, 0.3).set_ease(Tween.EASE_IN)
	tw.tween_callback(star.queue_free)
#endregion


#region From behind
func _edge_marks() -> void:
	if _marks == null:
		if _d._layer == null:
			return
		_marks = Control.new()
		_marks.name = "EdgeMarks"
		_marks.set_anchors_preset(Control.PRESET_FULL_RECT)
		_marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_marks.draw.connect(_draw_marks)
		_d._layer.add_child(_marks)
	_marks.queue_redraw()


func _draw_marks() -> void:
	var cam := get_viewport().get_camera_3d()
	var hero := _my_hero()
	if cam == null or hero == null:
		return
	var size := _marks.size
	var mid := size * 0.5
	var fwd := -cam.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var right := cam.global_transform.basis.x
	right.y = 0.0
	right = right.normalized()
	var shown: Array = []
	for body in _d._alive:
		var f := body as Fighter
		if f == null or not is_instance_valid(f) or f.is_dead or not f.visible or not striking(f):
			continue
		if f.global_position.distance_to(hero.global_position) > MARK_STRIKER:
			continue
		if not _behind(f.global_position):
			continue
		shown.append([f.global_position, Color(1.0, 0.2, 0.12, 0.95) if heavy(f) else Color(1.0, 0.92, 0.75, 0.9)])
	for node in get_tree().get_nodes_in_group(&"missile"):
		var m := node as Node3D
		if m == null or not bool(m.get(&"against_heroes")):
			continue
		if m.global_position.distance_to(hero.global_position) > MARK_SHOT or not _behind(m.global_position):
			continue
		shown.append([m.global_position, Color(1.0, 0.75, 0.3, 0.9)])
	for one: Array in shown:
		var off: Vector3 = (one[0] as Vector3) - hero.global_position
		# on the screen: right is right, behind is down
		var dir := Vector2(off.dot(right), -off.dot(fwd)).normalized()
		var edge := mid + dir * Vector2(mid.x - 60.0, mid.y - 60.0)
		var c: Color = one[1]
		var tip := edge + dir * 26.0
		var side := Vector2(-dir.y, dir.x) * 22.0
		_marks.draw_colored_polygon(PackedVector2Array([tip, edge + side, edge - side]), c)
		_marks.draw_polyline(PackedVector2Array([edge + side, tip, edge - side]), Color(0, 0, 0, 0.7), 2.0)


func _my_hero() -> Player:
	for hero in _d._heroes():
		if hero.is_multiplayer_authority() and not hero.is_dead:
			return hero
	return null
#endregion


#region F7
func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or key.keycode != KEY_F7:
		return
	_show_debug = not _show_debug
	if _debug == null and _d._layer != null:
		_debug = Label.new()
		_debug.position = Vector2(24, 300)
		_debug.add_theme_font_size_override("font_size", 17)
		_debug.add_theme_color_override("font_outline_color", Color.BLACK)
		_debug.add_theme_constant_override("outline_size", 5)
		_debug.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_d._layer.add_child(_debug)
	if _debug != null:
		_debug.visible = _show_debug


func _write_debug() -> void:
	if _debug == null:
		return
	var held := 0
	var on := 0
	var slots := 0
	for body in _d._alive:
		if not is_instance_valid(body) or bool(body.get("is_dead")):
			continue
		if bool(body.get("held_back")):
			held += 1
		if bool(body.get("shoot_slot")):
			slots += 1
	on = _d._holders.size()
	var hero := _my_hero()
	var next_throw := 0.0
	if hero != null:
		next_throw = maxf(float(Fighter._throw_times.get(hero.get_instance_id(), 0.0)) - _now(), 0.0)
	_debug.text = "დაძაბულობა: %.2f\nბიუჯეტი: %.2f (დახარჯული %.2f)%s\nახლოს: %d   ელოდება: %d   მსროლელი: %d\nსროლის რიგი: %.1f წმ (შემდეგი %.1f)\nსაფეხური: %d" % [
			pressure, budget_now, spent_now, "  +1" if extra_on else "", on, held, slots,
			Fighter.throw_gap, next_throw, _d.stage_of(_d.current)]
#endregion
