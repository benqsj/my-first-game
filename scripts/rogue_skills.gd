class_name RogueSkills
extends Node

## The assassin's skills past the Poisoned Blade (the plan:
## `claude/assassin_buff_plan.md`, the user's word 2026-10-06):
##
## * **Backstab** — passive. A cut from behind (within `BACKSTAB_CONE` of
##   straight behind what it lands on) is a critical worth `profile.backstab`
##   (2.2), on a boss ([Brute]: the orcs' warriors, Arkdeva) `BACKSTAB_BOSS`.
##   Read where a cut's worth is decided ([method Player.cut_worth]).
## * **Shadow Step** (slot 2) — gone in smoke and out of it again behind what
##   is locked or ahead of him (`STEP_SEEK`), facing its back: the backstab
##   set up — and he puts the knife into it as he comes out (the user's word,
##   2026-10-06): a thrust (DG_Thrust_Slash's) that lands `STEP_STAB_DELAY`
##   after, worth a cut of his (from behind, so a backstab) times
##   `STEP_STRIKE`. Nothing lands on him for `STEP_GUARD`. With nothing to
##   step to, `STEP_BLIND` metres ahead and no blow.
## * **Vanish** (slot 3) — a puff of smoke and he is gone for `VANISH_TIME`:
##   the creatures lose him ([method Player.is_hidden], read by
##   [method Brute.unseen] wherever they pick whom to go for), as does a
##   hostile hero's lock in PvP. His own eyes and his friends' see only a
##   shimmer where he is: the world behind him bent a little through his
##   shape, and a faint rim of his people's colour at its edges
##   (`CLOAK_SHADER`); nothing of his front or his inside shows. A foe in
##   PvP sees nothing at all. A blow taken ends it; so does a cut of his own
##   (or the Shadow Step's thrust), and the first cut out of it is a sure
##   critical (`AMBUSH_TIME`). 10 s, 40 s to come back (the user's word,
##   2026-10-06).
##
## Human or dark elf, one set of skills, each in his people's colour
## ([method venom_of], [method smoke_of]): the human's venom green and his
## smoke ash-grey, the dark elf's venom violet and his smoke a purple night.
##
## Hangs under the [Player] as "RogueSkills" ([method Player.rogue]). What is
## sent between peers is the Player's own (`net_shadow_step`, `net_vanish`);
## this keeps the state and draws it.

const BACKSTAB_BOSS := 1.5
const BACKSTAB_CONE := 60.0

## Shadow Step: how far off it picks what to step behind, how far behind its
## body he comes out, how far ahead with nothing to step to, and how long
## nothing lands on him.
const STEP_SEEK := 12.0
const STEP_GAP := 0.75
const STEP_BLIND := 6.0
const STEP_GUARD := 0.35
## The thrust he comes out of the step with: its clip and the stretch of it
## played, its pace, when the point goes in, and what it is worth.
## (Mixamo's "Stabbing", the knife driven in in a reverse grip, the user's
## pick K2, 2026-10-06: its first thrust, frames 9-33 of 80, the point in at
## frame 25; tools/dg18_extra.py, h2m.gd rogue_extra.)
const STEP_STAB := &"DG_Stab_Back"
const STEP_STAB_PART := Vector2(0.11, 0.41)
const STEP_STAB_RATE := 1.5
const STEP_STAB_DELAY := 0.36
const STEP_STRIKE := 1.0
## For this long after the step whoever had him (a creature, a boss, a hero's
## lock in PvP) has lost him ([method Player.is_hidden]); and the view's glide.
const STEP_LOST := 1.5
const STEP_GLIDE := 0.55

## Vanish: how long, how much of him is still drawn for his own eyes and his
## friends', and how long after it ends on a cut of his that cut is sure.
const VANISH_TIME := 7.0
## Before he is gone: a pellet thrown down at his feet (UAL's OverhandThrow,
## the stretch played, its pace) and when the smoke comes up out of it.
## (Mixamo's "Crouching", the user's pick V3: frames 24-84 of 123, from
## standing to the right hand on the ground, played quick; he is gone as his
## hand touches it.)
const VANISH_CAST := &"DG_Crouch_Down"
const VANISH_CAST_PART := Vector2(0.19, 0.68)
const VANISH_CAST_RATE := 4.0
const VANISH_CAST_DELAY := 0.48
## Before the Shadow Step: he gathers low and throws himself forward (UAL 2's
## Sword_Dash, its start), and goes into the smoke as he does.
## The step the same way (the user's word): down on his heels, a hand on the
## ground, and he sinks into it (the body drawn down `SINK` metres over
## `SINK_TIME`) to come up out of the ground behind it, smoke round his feet,
## and the knife in.
const STEP_WIND := &"DG_Crouch_Down"
const STEP_WIND_PART := Vector2(0.19, 0.68)
const STEP_WIND_RATE := 4.5
const STEP_WIND_DELAY := 0.52
const SINK := 1.3
const SINK_TIME := 0.12
const RISE_TIME := 0.22
## A cut of his out of hiding keeps him unseen until it lands (the user's
## word, 2026-10-06: the creature saw him as the swing began and the first
## blow was not the free one it should be); if it lands nothing, he is seen
## this long after it began.
const STRIKE_GRACE := 0.8
const AMBUSH_TIME := 1.0

## No sounds of their own yet (the user's word, 2026-10-06: the pitched
## recordings were not liked); the knife's own bite is heard where it lands.

## The venoms and the smoke, dull and dark as Elden Ring's (the user's word,
## 2026-10-06: a mix of Lineage 2's skills and Elden Ring's look — nothing
## neon, no glow, no rings): the human's a sickly yellow-green, the dark
## elf's a bruised violet; smoke nearly black.
const HUMAN_VENOM := Color(0.42, 0.52, 0.1)
const DARK_VENOM := Color(0.36, 0.16, 0.46)
const ASH := Color(0.05, 0.05, 0.055)
const NIGHT := Color(0.07, 0.03, 0.09)
const CRIMSON := Color(0.45, 0.04, 0.03)

var hero: Player
## Gone from sight now (every peer, from `net_vanish`).
var hiding: bool = false
var _hiding_until: float = 0.0
var _ambush_until: float = 0.0
var _lost_until: float = 0.0
var _strike_until: float = 0.0
var _casting: bool = false
var _faded: Dictionary = {}


## His people's venom: the human's green, the dark elf's violet.
static func venom_of(who: Node) -> Color:
	return DARK_VENOM if _dark(who) else HUMAN_VENOM


## His people's smoke.
static func smoke_of(who: Node) -> Color:
	return NIGHT if _dark(who) else ASH


static func _dark(who: Node) -> bool:
	var hero_ := who as Player
	return hero_ != null and hero_.profile != null and hero_.profile.people == &"dark"


## Whether `attacker` stands behind `target`: within `BACKSTAB_CONE` of the
## way its back faces (every body here faces -Z).
static func behind(attacker: Node3D, target: Node3D) -> bool:
	if attacker == null or target == null:
		return false
	var ahead := -target.global_basis.z
	ahead.y = 0.0
	var to := attacker.global_position - target.global_position
	to.y = 0.0
	if ahead.length_squared() < 0.0001 or to.length_squared() < 0.0001:
		return false
	return ahead.normalized().dot(to.normalized()) <= -cos(deg_to_rad(BACKSTAB_CONE))


## What a backstab multiplies a cut on `target` by: the profile's, on a boss
## less.
static func backstab_of(profile: CharacterProfile, target: Node3D) -> float:
	if profile == null or profile.backstab <= 1.0:
		return 1.0
	return minf(BACKSTAB_BOSS, profile.backstab) if target is Brute else profile.backstab


func _ready() -> void:
	hero = get_parent() as Player
	if hero == null:
		return
	hero.attack_started.connect(_on_attack)
	hero.struck.connect(_on_struck)
	hero.died.connect(_on_died)


func _process(_delta: float) -> void:
	if not hiding or hero == null or not hero.is_multiplayer_authority():
		return
	if _now() >= _hiding_until or (_strike_until > 0.0 and _now() >= _strike_until):
		_strike_until = 0.0
		hero.net_vanish.rpc(false, false)


## Every peer: the move he makes before a skill goes (`cue`: 0 the vanish's
## throw, 1 the step's gathering).
func play_cue(cue: int) -> void:
	if hero.rig == null or not hero.rig.has_method(&"play_part"):
		return
	if cue == 0:
		hero.rig.call(&"play_part", VANISH_CAST, VANISH_CAST_RATE, VANISH_CAST_PART.x, VANISH_CAST_PART.y, 0.08)
	else:
		hero.rig.call(&"play_part", STEP_WIND, STEP_WIND_RATE, STEP_WIND_PART.x, STEP_WIND_PART.y, 0.06)
		var into := Blood.world_of(hero)
		if into != null:
			# the shadows gather round him as he goes down
			_wisp(into, hero.global_position + Vector3.UP * 0.4, smoke_of(hero), 0.9)
		# and into the ground as his hand touches it
		get_tree().create_timer(maxf(STEP_WIND_DELAY - SINK_TIME, 0.0), false).timeout.connect(_sink)


## His body drawn down into the ground (the rig only: the body itself stays,
## to be moved by the step).
func _sink() -> void:
	var body := hero.rig as Node3D
	if body == null:
		return
	if not body.has_meta(&"rest_y"):
		body.set_meta(&"rest_y", body.position.y)
	var rest: float = body.get_meta(&"rest_y")
	var into := Blood.world_of(hero)
	if into != null:
		_puff(into, hero.global_position, smoke_of(hero), 0.8)
	var tw := body.create_tween()
	tw.tween_property(body, "position:y", rest - SINK, SINK_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


## Up out of the ground where he comes out.
func _rise() -> void:
	var body := hero.rig as Node3D
	if body == null:
		return
	if not body.has_meta(&"rest_y"):
		body.set_meta(&"rest_y", body.position.y)
	var rest: float = body.get_meta(&"rest_y")
	body.position.y = rest - SINK
	var tw := body.create_tween()
	tw.tween_property(body, "position:y", rest, RISE_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


## Just out of a Shadow Step: nothing that had him has him.
func lost() -> bool:
	return _now() < _lost_until


#region Shadow Step
## The owner's: steps him, if there is a place to step to, and sends it.
## True if he went.
func shadow_step(cost: float) -> bool:
	if hero == null or not hero.is_on_floor():
		return false
	var foe := hero._charge_target(STEP_SEEK)
	var to := Vector3.INF
	var face := Vector3.ZERO
	if foe != null:
		to = _behind_spot(foe)
		face = foe.global_position - to
	if to == Vector3.INF:
		foe = null
		to = _ahead_spot()
		face = -hero.global_basis.z
	if to == Vector3.INF:
		return false
	if not hero._spend(cost):
		return false
	# he gathers first, turned to it, and goes into the smoke after
	face.y = 0.0
	if foe != null:
		var at_it := foe.global_position - hero.global_position
		at_it.y = 0.0
		if at_it.length_squared() > 0.0001:
			hero.rotation.y = atan2(-at_it.x, -at_it.z)
	hero.velocity = Vector3.ZERO
	hero._commit(STEP_WIND_DELAY + (STEP_STAB_DELAY + 0.25 if foe != null else 0.1))
	hero.net_rogue_cue.rpc(1)
	var foe_path := foe.get_path() if foe != null else NodePath()
	get_tree().create_timer(STEP_WIND_DELAY, false).timeout.connect(_step_go.bind(foe_path, to, face))
	return true


## The owner's, after the gathering: out of sight and out again behind it
## (where it stands now, if it still can be), or where he meant to go.
func _step_go(foe_path: NodePath, to: Vector3, face: Vector3) -> void:
	if hero == null or hero.is_dead:
		return
	var foe := get_node_or_null(foe_path) as Node3D if not foe_path.is_empty() else null
	if foe != null and foe.is_inside_tree() and foe.get(&"is_dead") != true:
		var now_to := _behind_spot(foe)
		if now_to != Vector3.INF:
			to = now_to
		face = foe.global_position - to
	else:
		foe = null
	var from := hero.global_position
	# sent before he goes, so his own shadow is left where he stood
	hero.net_shadow_step.rpc(from, to, foe.get_path() if foe != null else NodePath())
	hero.global_position = to
	hero.velocity = Vector3.ZERO
	face.y = 0.0
	if face.length_squared() > 0.0001:
		hero.rotation.y = atan2(-face.x, -face.z)
	hero._safe_until = maxf(hero._safe_until, hero._now() + STEP_GUARD)
	if foe != null:
		hero._commit(STEP_STAB_DELAY + 0.25)
	hero.glide_camera(hero.rotation.y, STEP_GLIDE)


## Behind `foe`, on the ground and clear: straight behind if he fits there,
## else a little to either side. `Vector3.INF` when there is nowhere.
func _behind_spot(foe: Node3D) -> Vector3:
	var back := foe.global_basis.z
	back.y = 0.0
	if back.length_squared() < 0.0001:
		back = foe.global_position - hero.global_position
		back.y = 0.0
	back = back.normalized()
	var reach := Player._body_radius(foe) + STEP_GAP
	for turn: float in [0.0, 35.0, -35.0, 70.0, -70.0]:
		var way := back.rotated(Vector3.UP, deg_to_rad(turn))
		var spot := _ground_at(foe.global_position + way * reach, foe)
		if spot != Vector3.INF and _clear_line(foe.global_position, spot, foe):
			return spot
	return Vector3.INF


## `STEP_BLIND` ahead, short of whatever stands in the way.
func _ahead_spot() -> Vector3:
	var way := -hero.global_basis.z
	way.y = 0.0
	way = way.normalized()
	var space := hero.get_world_3d().direct_space_state
	var eye := hero.global_position + Vector3.UP * 1.0
	var q := PhysicsRayQueryParameters3D.create(eye, eye + way * STEP_BLIND, hero.collision_mask, [hero.get_rid()])
	var hit := space.intersect_ray(q)
	var go := STEP_BLIND
	if not hit.is_empty():
		go = eye.distance_to(hit["position"]) - 0.6
	if go < 1.5:
		return Vector3.INF
	return _ground_at(hero.global_position + way * go, null)


## The ground under `at` with room for him to stand, or `Vector3.INF`.
func _ground_at(at: Vector3, foe: Node3D) -> Vector3:
	var space := hero.get_world_3d().direct_space_state
	var skip: Array[RID] = [hero.get_rid()]
	if foe is CollisionObject3D:
		skip.append((foe as CollisionObject3D).get_rid())
	var q := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 1.6, at + Vector3.DOWN * 2.5, hero.collision_mask, skip)
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return Vector3.INF
	var ground: Vector3 = hit["position"]
	if absf(ground.y - hero.global_position.y) > 2.0:
		return Vector3.INF
	var body := CapsuleShape3D.new()
	body.radius = 0.38
	body.height = 1.7
	var shape := PhysicsShapeQueryParameters3D.new()
	shape.shape = body
	shape.transform = Transform3D(Basis.IDENTITY, ground + Vector3.UP * 0.95)
	shape.collision_mask = hero.collision_mask
	shape.exclude = skip
	if not space.intersect_shape(shape, 1).is_empty():
		return Vector3.INF
	return ground


## Nothing solid between the middle of `foe` and `spot`.
func _clear_line(from: Vector3, spot: Vector3, foe: Node3D) -> bool:
	var skip: Array[RID] = [hero.get_rid()]
	if foe is CollisionObject3D:
		skip.append((foe as CollisionObject3D).get_rid())
	var a := from + Vector3.UP * 1.0
	var b := spot + Vector3.UP * 1.0
	var q := PhysicsRayQueryParameters3D.create(a, b, hero.collision_mask, skip)
	return hero.get_world_3d().direct_space_state.intersect_ray(q).is_empty()


## Every peer: the smoke where he was and where he comes out, and the thrust
## into `foe` (its blow the host's).
func show_step(from: Vector3, to: Vector3, foe: Node3D = null) -> void:
	if foe != null and hero.rig != null and hero.rig.has_method(&"play_part"):
		hero.rig.call(&"play_part", STEP_STAB, STEP_STAB_RATE, STEP_STAB_PART.x, STEP_STAB_PART.y, 0.05)
		if hero._decides_here():
			get_tree().create_timer(STEP_STAB_DELAY, false).timeout.connect(_stab.bind(foe.get_path()))
	# whoever had him has lost him
	_lost_until = _now() + STEP_LOST
	_rise()
	var into := Blood.world_of(hero)
	if into == null:
		return
	var smoke := smoke_of(hero)
	_puff(into, from, smoke, 1.0)
	# a thin dark wake along the way he went, hanging a moment
	var way := to - from
	var steps := clampi(int(way.length() / 0.9), 2, 10)
	for k in steps:
		var t := (k + 0.5) / float(steps)
		_wisp(into, from + way * t + Vector3.UP * 1.0, smoke, lerpf(0.8, 0.5, t))
	_puff(into, to, smoke, 0.7)
#endregion


## Host: the step's thrust lands, if it is still there to land on.
func _stab(path: NodePath) -> void:
	var foe := get_node_or_null(path) as Node3D
	if hero == null or foe == null or not foe.is_inside_tree():
		return
	if foe.get(&"is_dead") == true or hero.is_dead:
		return
	var to := foe.global_position - hero.global_position
	to.y = 0.0
	if to.length() > Player._body_radius(foe) + 2.0:
		return
	var worth: Array = hero.cut_worth(foe)
	var damage := float(worth[0]) * STEP_STRIKE
	var way := to.normalized() if to.length_squared() > 0.0001 else -hero.global_basis.z
	var at := foe.global_position + Vector3.UP * 1.1 - way * Player._body_radius(foe)
	var foe_hero := foe as Player
	if foe_hero != null:
		foe_hero.hurtbox().take(HitInfo.make(damage, at, way, bool(worth[1]), true, hero))
	elif foe.has_method(&"take_hit"):
		foe.call(&"take_hit", damage, at, way, bool(worth[1]), true, hero)
		hero.blade_hit(foe, at)
	else:
		return
	hero.net_blade_landed.rpc(ImpactFx.matter_of(foe))
	if hiding:
		hero.net_vanish.rpc(false, false)


#region Vanish
## The owner's: spends and sends it. True if it went.
func vanish(cost: float) -> bool:
	if hero == null or hiding or _casting:
		return false
	if not hero._spend(cost):
		return false
	_casting = true
	hero._commit(VANISH_CAST_DELAY + 0.12)
	hero.net_rogue_cue.rpc(0)
	get_tree().create_timer(VANISH_CAST_DELAY, false).timeout.connect(_vanish_go)
	return true


func _vanish_go() -> void:
	_casting = false
	if hero != null and not hero.is_dead and not hiding:
		hero.net_vanish.rpc(true, false)


## Every peer: gone (`on`) or back. Back on a cut of his own (`ambush`), that
## cut is sure.
func set_hiding(on: bool, ambush: bool) -> void:
	if on == hiding:
		return
	hiding = on
	var into := Blood.world_of(hero)
	_strike_until = 0.0
	if on:
		_hiding_until = _now() + VANISH_TIME
		if into != null:
			_puff(into, hero.global_position, smoke_of(hero), 1.4)
	else:
		if ambush:
			_ambush_until = _now() + AMBUSH_TIME
		if into != null:
			_puff(into, hero.global_position, smoke_of(hero), 0.6)
	_fade(on)


## Host: whether the cut landing now is the one out of hiding (once).
func take_ambush() -> bool:
	if _now() < _ambush_until:
		_ambush_until = 0.0
		return true
	return false


## The cloak: what is behind him, read off the screen and bent a little
## through his shape, so where he stands only shimmers; a thin rim of his
## people's colour where his outline turns away. Written with its depth
## and as good as opaque, so only the nearest of his surfaces is drawn —
## nothing of his front seen through his back, no limb through another.
## His hair and cloth keep their cut-outs (`cut`, the albedo's alpha).
const CLOAK_SHADER := """
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_always, shadows_disabled;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D cut : source_color, hint_default_white;
uniform float use_cut = 0.0;
uniform vec4 rim_color : source_color = vec4(0.6, 0.6, 0.8, 1.0);
uniform float rim_power = 3.5;
uniform float rim_strength = 0.3;
uniform float bend = 0.018;
void fragment() {
	if (use_cut > 0.5 && texture(cut, UV).a < 0.5) {
		discard;
	}
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = pow(1.0 - facing, rim_power);
	float ripple = 0.6 + 0.4 * sin(TIME * 2.6 + VERTEX.y * 9.0 + VERTEX.x * 5.0);
	vec2 off = NORMAL.xy * bend * ripple * (0.4 + rim);
	vec3 behind = textureLod(screen_tex, SCREEN_UV - off, 0.0).rgb;
	ALBEDO = mix(behind * 0.94, rim_color.rgb, rim * rim_strength);
	ALPHA = 1.0;
}
"""
static var _cloak_shader: Shader = null
## The rim: the human's a cold steel, the dark elf's his violet.
const STEEL := Color(0.45, 0.5, 0.58)


## The cloak for his own eyes and his friends'; for a foe in PvP nothing.
## What each mesh wore and whether it cast a shadow is kept and given back.
func _fade(on: bool) -> void:
	if not on:
		for g: Variant in _faded:
			if not is_instance_valid(g):
				continue
			var was: Array = _faded[g]
			var gi := g as GeometryInstance3D
			gi.transparency = float(was[0])
			gi.cast_shadow = int(was[2]) as GeometryInstance3D.ShadowCastingSetting
			var mi := gi as MeshInstance3D
			if mi != null:
				var kept: Array = was[1]
				for k in mi.get_surface_override_material_count():
					mi.set_surface_override_material(k, kept[k] if k < kept.size() else null)
		_faded.clear()
		return
	var gone := Player.pvp_mode and not hero.is_multiplayer_authority()
	if _cloak_shader == null:
		_cloak_shader = Shader.new()
		_cloak_shader.code = CLOAK_SHADER
	var rim := DARK_VENOM if _dark(hero) else STEEL
	for node in hero.find_children("*", "GeometryInstance3D", true, false):
		var g := node as GeometryInstance3D
		if g == null or _faded.has(g) or _shed(g):
			continue
		var kept: Array = []
		var mi := g as MeshInstance3D
		_faded[g] = [g.transparency, kept, int(g.cast_shadow)]
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if gone or mi == null or mi.mesh == null or mi.material_override != null:
			g.transparency = 1.0
			continue
		for k in mi.get_surface_override_material_count():
			kept.append(mi.get_surface_override_material(k))
			var cloak := ShaderMaterial.new()
			cloak.shader = _cloak_shader
			cloak.set_shader_parameter(&"rim_color", rim)
			cloak.set_meta(&"cloak", true)
			var base := mi.get_active_material(k) as BaseMaterial3D
			if base != null and base.albedo_texture != null \
					and base.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
				cloak.set_shader_parameter(&"cut", base.albedo_texture)
				cloak.set_shader_parameter(&"use_cut", 1.0)
			mi.set_surface_override_material(k, cloak)


## A copy the shadow trail shed (it fades on its own), not his body.
func _shed(g: Node) -> bool:
	var up := g.get_parent()
	while up != null and up != hero:
		if up is ShadowTrail:
			return true
		up = up.get_parent()
	return false


func _on_attack() -> void:
	# not seen yet: only once the cut lands ([method Player.blade_hit]), or
	# STRIKE_GRACE after it began
	if hiding and hero.is_multiplayer_authority() and _strike_until <= 0.0:
		_strike_until = _now() + STRIKE_GRACE


func _on_struck(_damage: float, _blocked: bool) -> void:
	if hiding and hero.is_multiplayer_authority():
		hero.net_vanish.rpc(false, false)


func _on_died() -> void:
	if hiding and hero.is_multiplayer_authority():
		hero.net_vanish.rpc(false, false)
#endregion


## Every peer: a backstab landed at `at` — no flash: the blood it lets, a
## heavy gout of it the way the knife went in.
func show_backstab(at: Vector3) -> void:
	var into := Blood.world_of(hero)
	if into == null:
		return
	var way := at - hero.global_position
	way.y = 0.0
	Blood.splatter(into, at, way.normalized() if way.length_squared() > 0.0001 else Vector3.FORWARD,
			null, 1.8)


## A puff of smoke `big` across at `at`: thick at the feet, rolling up and out.
static func _puff(into: Node, at: Vector3, smoke: Color, big: float) -> void:
	SkillFx.particles(into, at + Vector3.UP * 0.9, {
		"amount": int(26 * big), "life": 1.1, "one_shot": true, "explosiveness": 0.9,
		"speed": Vector2(0.3, 1.2) * big, "spread": 180.0, "dir": Vector3.UP, "damping": 2.5,
		"gravity": Vector3(0, 0.35, 0), "size": Vector2(0.4, 0.8) * big, "box": Vector3(0.25, 0.75, 0.25),
		"add": false, "grow": 0.6,
		"colors": [Color(smoke, 0.0), Color(smoke, 0.75), Color(smoke, 0.0)],
	})


## One wisp of smoke hanging where he passed.
static func _wisp(into: Node, at: Vector3, smoke: Color, big: float) -> void:
	SkillFx.particles(into, at, {
		"amount": 6, "life": 0.8, "one_shot": true, "explosiveness": 0.8,
		"speed": Vector2(0.1, 0.4), "spread": 180.0, "damping": 2.0, "gravity": Vector3(0, 0.25, 0),
		"size": Vector2(0.25, 0.45) * big, "box": Vector3(0.1, 0.35, 0.1), "add": false, "grow": 0.6,
		"colors": [Color(smoke, 0.0), Color(smoke, 0.55), Color(smoke, 0.0)],
	})


## Drops of venom thrown off a cut or a boil: dull, falling, not glowing.
static func drops(into: Node, at: Vector3, venom: Color, count: int, big: float) -> void:
	SkillFx.particles(into, at, {
		"amount": count, "life": 0.6, "one_shot": true, "explosiveness": 0.95,
		"speed": Vector2(0.8, 2.6) * big, "spread": 70.0, "dir": Vector3.UP, "damping": 0.5,
		"gravity": Vector3(0, -9.0, 0), "size": Vector2(0.015, 0.035) * big, "box": Vector3(0.08, 0.08, 0.08),
		"add": false, "grow": 0.1,
		"colors": [Color(venom, 1.0), Color(venom.darkened(0.3), 1.0), Color(venom.darkened(0.6), 0.0)],
	})


## Built once behind the level's black warm-up screen ([PipelineWarmup]):
## the cloak, the smoke, the sparks, the column and the flash, so the first
## Vanish or Shadow Step does not stall the frame while the renderer builds
## them (the user's word: it hitched the first time). `at` is a node in
## front of the warm-up's camera.
static func warm(at: Node3D) -> void:
	if _cloak_shader == null:
		_cloak_shader = Shader.new()
		_cloak_shader.code = CLOAK_SHADER
	var ball := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.3
	sphere.height = 0.6
	ball.mesh = sphere
	var cloak := ShaderMaterial.new()
	cloak.shader = _cloak_shader
	ball.material_override = cloak
	at.add_child(ball)
	var cut_ball := ball.duplicate() as MeshInstance3D
	var cut_cloak := cloak.duplicate() as ShaderMaterial
	cut_cloak.set_shader_parameter(&"use_cut", 1.0)
	cut_ball.material_override = cut_cloak
	at.add_child(cut_ball)
	cut_ball.position = Vector3(0.7, 0.0, 0.0)
	var here := at.global_position
	_puff(at, here + Vector3.DOWN * 0.9, ASH, 0.4)
	_wisp(at, here, ASH, 0.4)
	drops(at, here, HUMAN_VENOM, 4, 0.5)
	Blood.splatter(at, here, Vector3.FORWARD, null, 0.3)

