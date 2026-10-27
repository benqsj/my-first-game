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
## * **The throws' turn** ([member Fighter.throw_gap]) shorter as it presses;
##   a shot at his back, while his hands are full, only rarely.
## * **With others**: each hero his own pressure and his own measure for
##   those after him; one that turns to another hero counts for that one.
## * **Tells**: as a creature begins a blow a glint at it, white for a light
##   one, red for a heavy one.
## * **From behind**: a creature striking at his back, or a shot coming at it,
##   shows as a mark at the screen's edge on its side.
## * **F7**: what it is doing, on the screen (for tuning).
## * (2026-10-28, the user's word: the rest of the plan) **Balance** on
##   elites and bosses ([Poise]); **the last-moment roll** gives back a
##   third of his stamina and shakes the one he rolled through; **the
##   flask**: drinking in the fight, those near rush him for a moment;
##   **a heavy blow** rings a tell as it begins; **his gold where he fell**:
##   dying in a portal he leaves what he carried there, and finds it again at
##   that step on his next way through, or loses it dying first.

## The budget at one hero: at the first steps, and how much it grows a step.
const BUDGET := 2.0
const BUDGET_PER_STEP := 0.12
const BUDGET_UNDER_FIRE := 1.0
## Holding out ([RoomGoal] "survive"): this much more at each hero, under fire
## or not (the user's word, 2026-10-28: there it has to be hard to live).
const BUDGET_HOLDING := 1.5
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
## His hands full: this many within [constant BUSY_NEAR] m of him; then a shot
## at his back only this rarely (the user's word, 2026-10-28).
const BUSY := 3
const BUSY_NEAR := 9.0
const BACK_SHOT := 0.12
## The edge marks: how near a striker or a shot is to be shown.
const MARK_STRIKER := 10.0
const MARK_SHOT := 16.0

## (for F7: the hero on this screen)
var pressure: float = 0.0
var budget_now: float = 0.0
var spent_now: float = 0.0
var extra_on: bool = false

var _d: Dungeon
## Each hero his own (with others, the user's word, 2026-10-28: the same for
## each of them; who they go at is theirs to choose, and it can change).
var _press: Dictionary = {}
var _hurts: Dictionary = {}
var _last_health: Dictionary = {}
var _budget_of: Dictionary = {}
var _extra_until := 0.0
var _extra_next := 0.0
var _clock := 0.0
var _serials: Dictionary = {}
var _marks: Control
var _debug: Label
var _show_debug := false
var _flasks: Dictionary = {}
var _punish_until: Dictionary = {}
var _stain_step := -2
var _stain: Node3D

## Drinking in the fight: for this long those near rush him, this much more
## at him at once.
const PUNISH_FOR := 2.2
const PUNISH_BUDGET := 2.0
## The last-moment roll: this share of his stamina back.
const DODGE_STAMINA := 0.3
## The heavy blow's tell.
const TELL_SOUND := "res://sounds/parry/clang.wav"


func setup(d: Dungeon) -> void:
	_d = d
	_extra_next = _now() + randf_range(EXTRA_EVERY.x, EXTRA_EVERY.y)
	Fighter.throw_judge = self


func _exit_tree() -> void:
	if Fighter.throw_judge == self:
		Fighter.throw_judge = null


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
		_hook_heroes()
		_balance_on()
		_watch_flasks()
		_lay_stain()
	_reach_stain()
	var me := _my_hero()
	pressure = pressure_of(me) if me != null else 0.0
	_tells()
	_edge_marks()
	if _show_debug:
		_write_debug()


func pressure_of(hero: Node) -> float:
	return float(_press.get(hero, 0.0)) if hero != null else 0.0


## What each has taken lately and how whole he is, and his pressure after it.
func _feel(dt: float) -> void:
	var now := _now()
	var fighting := false
	for body in _d._alive:
		if is_instance_valid(body) and not bool(body.get("is_dead")) and body.visible:
			fighting = true
			break
	for hero in _d._heroes():
		var p := pressure_of(hero)
		if hero.is_dead:
			_press[hero] = 0.0
			continue
		var was := float(_last_health.get(hero, hero.health))
		var list: Array = _hurts.get(hero, [])
		if hero.health < was - 0.01:
			list.append([now, (was - hero.health) / maxf(hero.max_health, 1.0)])
		_last_health[hero] = hero.health
		while not list.is_empty() and now - float(list[0][0]) > WINDOW:
			list.pop_front()
		_hurts[hero] = list
		if not fighting:
			continue
		var taken := 0.0
		for h: Array in list:
			taken += float(h[1])
		var share := hero.health / maxf(hero.max_health, 1.0)
		if share < LOW:
			# low: nothing on top of the room's own measure, at once
			p = 0.0
		elif taken >= HURT_ENOUGH:
			p = maxf(p - PRESS_DOWN * dt, 0.0)
		elif taken < HURT_ENOUGH * 0.4:
			p = minf(p + PRESS_UP * dt, 1.0)
		_press[hero] = p


## The throws' gap at `hero`: shorter as the fight presses him.
func throw_gap_for(hero: Node) -> float:
	return Fighter.throw_gap * (1.0 - PRESS_THROWS * pressure_of(hero))
#endregion


#region Turns
static func cost_of(body: Node3D) -> float:
	var path := String(body.scene_file_path)
	for k: String in SMALL_KINDS:
		if path.ends_with(k):
			return SMALL
	return 1.0


## Those near `hero` fighting him (not `but`): their middle's bearing from him,
## and how many (in the frame of the fight, not of any one screen: the same
## for each hero, here or with others).
func _front_of(hero: Node3D, but: Node3D = null) -> Array:
	var sum := Vector3.ZERO
	var n := 0
	for body in _d._alive:
		if body == but or not is_instance_valid(body) or bool(body.get("is_dead")) or not body.visible:
			continue
		var off := body.global_position - hero.global_position
		off.y = 0.0
		if off.length() > BUSY_NEAR or off.length() < 0.05:
			continue
		sum += off.normalized()
		n += 1
	return [sum.normalized() if sum.length() > 0.05 else Vector3.ZERO, n]


## Whether `at` is at `hero`'s back: across from where the rest of the fight
## is on him.
func _at_back(hero: Node3D, at: Node3D) -> bool:
	var front: Array = _front_of(hero, at)
	var dir: Vector3 = front[0]
	if int(front[1]) < 2 or dir == Vector3.ZERO:
		return false
	var off := at.global_position - hero.global_position
	off.y = 0.0
	return off.length() > 0.05 and dir.dot(off.normalized()) < -0.3


## A throw at `hero` from `from`: with his hands full in front and at his
## sides, one at his back only rarely.
func allows_throw(hero: Node3D, from: Node3D) -> bool:
	if hero == null or from == null:
		return true
	var front: Array = _front_of(hero, from)
	if int(front[1]) < BUSY:
		return true
	if not _at_back(hero, from):
		return true
	return randf() < BACK_SHOT


## Who it is after: the hero it has chosen, if one of `standing`; else the
## nearest.
func _whose(body: Node3D, standing: Array[Player]) -> Player:
	var q: Variant = body.get("_quarry")
	if q is Player and standing.has(q):
		return q
	var best: Player = null
	for hero in standing:
		if best == null or hero.global_position.distance_squared_to(body.global_position) \
				< best.global_position.distance_squared_to(body.global_position):
			best = hero
	return best


func _holding_out() -> bool:
	return String(_d._room(_d.current).get("goal", "")) == "survive"


## Of `small` ([gap, body] near the heroes, nearest first), those that have
## their turn now, each hero's own measure for those after him; `holders` those
## that had it; `brutes` and `shooters` the big ones and those shooting.
func choose(small: Array, holders: Array[Node3D], standing: Array[Player], shooters: Array,
		brutes: Array) -> Array[Node3D]:
	var now := _now()
	if now >= _extra_next:
		_extra_until = now + randf_range(EXTRA_FOR.x, EXTRA_FOR.y)
		var every := randf_range(EXTRA_EVERY.x, EXTRA_EVERY.y) / (1.0 + pressure)
		_extra_next = _extra_until + every
	var extra := now < _extra_until
	var holding := _holding_out()
	var step_add := BUDGET_PER_STEP * float(maxi(_d.stage_of(_d.current) - 1, 0))
	var out: Array[Node3D] = []
	for hero in standing:
		var mine: Array = []
		for pair: Array in small:
			if _whose(pair[1], standing) == hero:
				mine.append([(pair[1] as Node3D).global_position.distance_to(hero.global_position), pair[1]])
		mine.sort_custom(func(x: Array, y: Array) -> bool: return float(x[0]) < float(y[0]))
		var fire := 0
		for b: Node3D in shooters:
			if is_instance_valid(b) and _whose(b, standing) == hero:
				fire += 1
		var big := 0
		for b: Node3D in brutes:
			if is_instance_valid(b) and _whose(b, standing) == hero:
				big += 1
		var low := hero.health < hero.max_health * LOW
		var base := BUDGET_UNDER_FIRE if fire >= Dungeon.SHOOTERS_MANY and not holding else BUDGET + step_add
		if holding:
			base += BUDGET_HOLDING
		var budget := base + PRESS_BUDGET * pressure_of(hero) + (1.0 if extra and not low else 0.0)
		if now < float(_punish_until.get(hero, 0.0)):
			budget += PUNISH_BUDGET
		budget = maxf(budget - float(big), 0.0)
		_budget_of[hero] = budget
		_keep = []
		_spent = 0.0
		_budget = budget
		# he walked up to it: its turn at once
		for pair: Array in mine:
			if float(pair[0]) < CLOSE_IN:
				_take(hero, pair[1])
		for h in holders:
			for pair: Array in mine:
				if pair[1] == h and float(pair[0]) < 11.0:
					_take(hero, h)
		for pair: Array in mine:
			_take(hero, pair[1])
		out.append_array(_keep)
		if hero == _my_hero():
			budget_now = budget
			spent_now = _spent
			extra_on = extra and not low
	return out


var _keep: Array[Node3D] = []
var _spent := 0.0
var _budget := 0.0


## One more given its turn at `hero`, if its weight fits what is left (the
## first always).
func _take(hero: Node3D, body: Node3D) -> void:
	if _keep.has(body) or _budget <= 0.0:
		return
	var c := cost_of(body) + (BEHIND if _at_back(hero, body) else 0.0)
	if not _keep.is_empty() and _spent + c > _budget + 0.01:
		return
	_keep.append(body)
	_spent += c
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
	if red:
		Sfx.play(f, TELL_SOUND, null, at, 1.75, -9.0)
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
		if not _behind_cam(f.global_position):
			continue
		shown.append([f.global_position, Color(1.0, 0.2, 0.12, 0.95) if heavy(f) else Color(1.0, 0.92, 0.75, 0.9)])
	for node in get_tree().get_nodes_in_group(&"missile"):
		var m := node as Node3D
		if m == null or not bool(m.get(&"against_heroes")):
			continue
		if m.global_position.distance_to(hero.global_position) > MARK_SHOT or not _behind_cam(m.global_position):
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


## Behind the eye of this screen (for the marks at its edge).
func _behind_cam(at: Vector3) -> bool:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam == null:
		return false
	var to := at - cam.global_position
	to.y = 0.0
	var fwd := -cam.global_transform.basis.z
	fwd.y = 0.0
	return to.length() > 0.1 and fwd.normalized().dot(to.normalized()) < -0.2


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



#region The rest of the plan (2026-10-28)
func _hook_heroes() -> void:
	for hero in _d._heroes():
		if hero.has_meta(&"director_hooked"):
			continue
		hero.set_meta(&"director_hooked", true)
		if hero.has_signal(&"perfect_dodged"):
			hero.perfect_dodged.connect(_on_perfect.bind(hero))
		if hero.has_signal(&"struck"):
			hero.struck.connect(_on_struck.bind(hero))
		if hero.has_signal(&"died"):
			hero.died.connect(_on_hero_died.bind(hero))


## The one of them nearest `hero`, in the middle of a blow, within `reach`.
func _striker_near(hero: Node3D, reach: float) -> Fighter:
	var best: Fighter = null
	var gap := reach
	for body in _d._alive:
		var f := body as Fighter
		if f == null or not is_instance_valid(f) or f.is_dead or not striking(f):
			continue
		var d := f.global_position.distance_to(hero.global_position)
		if d < gap:
			gap = d
			best = f
	return best


func _on_perfect(hero: Player) -> void:
	if not is_instance_valid(hero):
		return
	hero.stamina = minf(hero.stamina + hero.max_stamina * DODGE_STAMINA, hero.max_stamina)
	var f := _striker_near(hero, 5.0)
	if f != null and _d.decides():
		var p := f.get_node_or_null(^"Poise") as Poise
		if p != null:
			p.shake(Poise.DODGED, hero)


func _on_struck(_damage: float, blocked: bool, hero: Player) -> void:
	if not blocked or not _d.decides() or not is_instance_valid(hero):
		return
	var f := _striker_near(hero, 5.0)
	if f != null:
		var p := f.get_node_or_null(^"Poise") as Poise
		if p != null:
			p.shake(Poise.BLOCKED, hero)


## Balance on each elite and boss as they come.
func _balance_on() -> void:
	for body in _d._alive:
		var f := body as Fighter
		if f == null or not is_instance_valid(f) or f.is_dead:
			continue
		if (f.has_meta(&"elite") or f.has_meta(&"boss")) and not f.has_node(^"Poise"):
			Poise.give(f)


## A flask drunk in the fight: those near rush him for a moment, and a throw
## may come at once.
func _watch_flasks() -> void:
	var now := _now()
	for hero in _d._heroes():
		var left := int(hero.flasks_left)
		var was := int(_flasks.get(hero, left))
		_flasks[hero] = left
		if left < was and not hero.is_dead:
			var near := false
			for body in _d._alive:
				if is_instance_valid(body) and not bool(body.get("is_dead")) and body.visible \
						and body.global_position.distance_to(hero.global_position) < 14.0:
					near = true
					break
			if near:
				_punish_until[hero] = now + PUNISH_FOR
				Fighter._throw_times.erase(hero.get_instance_id())


## Dying in the portal: what he carried is left where he fell.
func _on_hero_died(hero: Player) -> void:
	if not is_instance_valid(hero) or not hero.is_multiplayer_authority():
		return
	var game := get_node_or_null(^"/root/Game")
	var purse := Purse.of(hero)
	if game == null or purse == null or not game.has_method(&"set_stain"):
		return
	var carried := purse.gold
	# (one left before and not taken back is lost now)
	game.call(&"set_stain", {"portal": _d.id, "step": _d.current, "gold": carried} if carried > 0 else {})
	if carried <= 0:
		return
	if _d.decides():
		purse.take(carried)
	else:
		purse.gold = 0
		purse.changed.emit(0, -carried)


func _lay_stain() -> void:
	if _d.current == _stain_step:
		return
	_stain_step = _d.current
	if is_instance_valid(_stain):
		_stain.queue_free()
	_stain = null
	var game := get_node_or_null(^"/root/Game")
	if game == null or not ("stain" in game):
		return
	var st: Dictionary = game.get(&"stain")
	if st.is_empty() or int(st.get("portal", -1)) != _d.id or int(st.get("step", -1)) != _d.current:
		return
	var world := Blood.world_of(_d)
	if world == null:
		return
	_stain = Node3D.new()
	_stain.name = "GoldStain"
	world.add_child(_stain)
	_stain.global_position = _d.entry_point(0, _d.current) + Vector3(0.0, 0.05, -7.0)
	var glow := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.15
	cyl.bottom_radius = 0.55
	cyl.height = 2.4
	glow.mesh = cyl
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(1.0, 0.75, 0.25, 0.35)
	glow.material_override = m
	glow.position.y = 1.2
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_stain.add_child(glow)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.75, 0.3)
	light.light_energy = 1.6
	light.omni_range = 4.0
	light.position.y = 0.8
	_stain.add_child(light)
	var l := Label3D.new()
	l.text = "შენი ოქრო: %d" % int(st.get("gold", 0))
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.font_size = 34
	l.outline_size = 8
	l.pixel_size = 0.006
	l.modulate = Color(1.0, 0.85, 0.45)
	l.position.y = 2.7
	_stain.add_child(l)


func _reach_stain() -> void:
	if not is_instance_valid(_stain):
		return
	var hero := _my_hero()
	if hero == null:
		return
	var gap := hero.global_position - _stain.global_position
	gap.y = 0.0
	if gap.length() > 1.8:
		return
	var game := get_node_or_null(^"/root/Game")
	var purse := Purse.of(hero)
	if game == null or purse == null:
		return
	var st: Dictionary = game.get(&"stain")
	var g := int(st.get("gold", 0))
	game.call(&"set_stain", {})
	if g > 0:
		if _d.decides():
			purse.give(g)
		else:
			purse.gold += g
			purse.changed.emit(purse.gold, g)
		_d._say("ოქრო დაბრუნდა: +%d" % g, 2.5)
	_stain.queue_free()
	_stain = null
#endregion
