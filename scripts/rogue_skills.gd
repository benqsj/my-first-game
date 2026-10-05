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
##   set up. Nothing lands on him for `STEP_GUARD`. With nothing to step to,
##   `STEP_BLIND` metres ahead.
## * **Vanish** (slot 3) — a puff of smoke and he is gone for `VANISH_TIME`:
##   the creatures lose him ([method Player.is_hidden], read by
##   [method Brute.unseen] wherever they pick whom to go for), as does a
##   hostile hero's lock in PvP. His own eyes and his friends' still see a
##   ghost of him (`VANISH_SHOWN`); a foe in PvP sees nothing. A blow taken
##   ends it; so does a cut of his own, and the first cut out of it is a sure
##   critical (`AMBUSH_TIME`).
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

## Vanish: how long, how much of him is still drawn for his own eyes and his
## friends', and how long after it ends on a cut of his that cut is sure.
const VANISH_TIME := 6.0
const VANISH_SHOWN := 0.28
const AMBUSH_TIME := 1.0

const STEP_SOUND := "res://unverified/sounds/dodge/shadow.wav"
const VANISH_SOUND := "res://unverified/sounds/magic/use-skill-sound1.wav"
const BACKSTAB_SOUND := "res://unverified/sounds/sword-damage-sound/sword-slash-damage.wav"
const BOIL_SOUND := "res://unverified/sounds/magic/skill-shot-sound1.wav"
const SOUNDS := [STEP_SOUND, VANISH_SOUND, BACKSTAB_SOUND, BOIL_SOUND]

## The dark elf's venom and both peoples' smoke.
const DARK_VENOM := Color(0.74, 0.32, 1.0)
const ASH := Color(0.16, 0.15, 0.15)
const NIGHT := Color(0.2, 0.08, 0.3)
const CRIMSON := Color(1.0, 0.16, 0.12)

var hero: Player
## Gone from sight now (every peer, from `net_vanish`).
var hiding: bool = false
var _hiding_until: float = 0.0
var _ambush_until: float = 0.0
var _faded: Dictionary = {}


## His people's venom: the human's green, the dark elf's violet.
static func venom_of(who: Node) -> Color:
	return DARK_VENOM if _dark(who) else Afflictions.VENOM


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
	Sfx.warm(SOUNDS)
	if hero == null:
		return
	hero.attack_started.connect(_on_attack)
	hero.struck.connect(_on_struck)
	hero.died.connect(_on_died)


func _process(_delta: float) -> void:
	if hiding and hero != null and hero.is_multiplayer_authority() and _now() >= _hiding_until:
		hero.net_vanish.rpc(false, false)


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


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
	var from := hero.global_position
	hero.global_position = to
	hero.velocity = Vector3.ZERO
	face.y = 0.0
	if face.length_squared() > 0.0001:
		hero.rotation.y = atan2(-face.x, -face.z)
	hero._safe_until = maxf(hero._safe_until, hero._now() + STEP_GUARD)
	hero.net_shadow_step.rpc(from, to)
	return true


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


## Every peer: the smoke where he was and where he comes out.
func show_step(from: Vector3, to: Vector3) -> void:
	var into := Blood.world_of(hero)
	if into == null:
		return
	var smoke := smoke_of(hero)
	_puff(into, from, smoke, 1.0)
	_puff(into, to, smoke, 0.7)
	var rim := venom_of(hero) if _dark(hero) else CRIMSON
	SkillFx.ring(into, to + Vector3.UP * 0.05, Vector3.UP, rim, 0.2, 1.0, 0.25, 0.025, 1.4)
	ShadowTrail.start(hero, 0.18, 0.04)
	Sfx.play(hero, STEP_SOUND, null, from, 0.85, -3.0)
	Sfx.play(hero, STEP_SOUND, hero, Vector3.ZERO, 1.2, -6.0)
#endregion


#region Vanish
## The owner's: spends and sends it. True if it went.
func vanish(cost: float) -> bool:
	if hero == null or hiding:
		return false
	if not hero._spend(cost):
		return false
	hero.net_vanish.rpc(true, false)
	return true


## Every peer: gone (`on`) or back. Back on a cut of his own (`ambush`), that
## cut is sure.
func set_hiding(on: bool, ambush: bool) -> void:
	if on == hiding:
		return
	hiding = on
	var into := Blood.world_of(hero)
	if on:
		_hiding_until = _now() + VANISH_TIME
		if into != null:
			_puff(into, hero.global_position, smoke_of(hero), 1.4)
		Sfx.play(hero, VANISH_SOUND, hero, Vector3.ZERO, 0.62, -4.0)
		Sfx.play(hero, STEP_SOUND, hero, Vector3.ZERO, 0.7, -6.0)
	else:
		if ambush:
			_ambush_until = _now() + AMBUSH_TIME
		if into != null:
			_puff(into, hero.global_position, smoke_of(hero), 0.6)
		Sfx.play(hero, STEP_SOUND, hero, Vector3.ZERO, 1.3, -8.0)
	_fade(on)


## Host: whether the cut landing now is the one out of hiding (once).
func take_ambush() -> bool:
	if _now() < _ambush_until:
		_ambush_until = 0.0
		return true
	return false


## Drawn as a ghost for his own eyes and his friends'; not at all for a foe
## in PvP. His meshes are cut out with an alpha scissor, which a node's
## `transparency` only thins to nothing (below the scissor every pixel goes):
## so each surface wears a blended copy of its material for the while.
func _fade(on: bool) -> void:
	if not on:
		for g: Variant in _faded:
			if not is_instance_valid(g):
				continue
			var was: Array = _faded[g]
			var gi := g as GeometryInstance3D
			gi.transparency = float(was[0])
			var mi := gi as MeshInstance3D
			if mi != null:
				for k in mi.get_surface_override_material_count():
					mi.set_surface_override_material(k, was[1][k] if k < (was[1] as Array).size() else null)
		_faded.clear()
		return
	var gone := Player.pvp_mode and not hero.is_multiplayer_authority()
	for node in hero.find_children("*", "GeometryInstance3D", true, false):
		var g := node as GeometryInstance3D
		if g == null or _faded.has(g):
			continue
		var overrides: Array = []
		var mi := g as MeshInstance3D
		if gone:
			_faded[g] = [g.transparency, overrides]
			g.transparency = 1.0
			continue
		if mi != null and mi.mesh != null and mi.material_override == null:
			for k in mi.get_surface_override_material_count():
				overrides.append(mi.get_surface_override_material(k))
				var base := mi.get_active_material(k) as BaseMaterial3D
				if base == null:
					continue
				var ghost := base.duplicate() as BaseMaterial3D
				ghost.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				ghost.albedo_color.a = base.albedo_color.a * VANISH_SHOWN
				mi.set_surface_override_material(k, ghost)
			_faded[g] = [g.transparency, overrides]
		else:
			_faded[g] = [g.transparency, overrides]
			g.transparency = 1.0 - VANISH_SHOWN


func _on_attack() -> void:
	if hiding and hero.is_multiplayer_authority():
		hero.net_vanish.rpc(false, true)


func _on_struck(_damage: float, _blocked: bool) -> void:
	if hiding and hero.is_multiplayer_authority():
		hero.net_vanish.rpc(false, false)


func _on_died() -> void:
	if hiding and hero.is_multiplayer_authority():
		hero.net_vanish.rpc(false, false)
#endregion


## Every peer: a backstab landed at `at` — a crimson (violet) flash and the
## blade's bite, deeper.
func show_backstab(at: Vector3) -> void:
	var into := Blood.world_of(hero)
	if into == null:
		return
	var rim := venom_of(hero) if _dark(hero) else CRIMSON
	SkillFx.flash(into, at, rim, 0.25, 0.12, 3.0)
	SkillFx.burst(into, at, rim, 26, Vector2(2.0, 5.0), (at - hero.global_position).normalized(), 40.0,
			Vector2(0.02, 0.05), Vector3(0, -6, 0), 0.4)
	Sfx.play(hero, BACKSTAB_SOUND, null, at, 0.82, -3.0)


## A puff of smoke `big` across at `at`: thick at the feet, rolling up and out.
static func _puff(into: Node, at: Vector3, smoke: Color, big: float) -> void:
	SkillFx.particles(into, at + Vector3.UP * 0.9, {
		"amount": int(40 * big), "life": 0.9, "one_shot": true, "explosiveness": 0.95,
		"speed": Vector2(0.8, 2.4) * big, "spread": 180.0, "dir": Vector3.UP, "damping": 3.0,
		"gravity": Vector3(0, 0.6, 0), "size": Vector2(0.35, 0.7) * big, "box": Vector3(0.3, 0.8, 0.3),
		"add": false, "grow": 0.5,
		"colors": [Color(smoke, 0.0), Color(smoke, 0.85), Color(smoke.lightened(0.15), 0.0)],
	})
	SkillFx.particles(into, at + Vector3.UP * 0.1, {
		"amount": int(24 * big), "life": 0.7, "one_shot": true, "explosiveness": 1.0,
		"speed": Vector2(2.0, 3.5) * big, "spread": 10.0, "dir": Vector3.UP, "damping": 4.0,
		"ring": Vector2(0.2, 0.4), "size": Vector2(0.25, 0.45) * big, "add": false, "grow": 0.4,
		"colors": [Color(smoke, 0.0), Color(smoke, 0.7), Color(smoke, 0.0)],
	})
