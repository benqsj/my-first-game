class_name DarkSkills
extends Node

## The dark elf mage's skills (the plan: `claude/dark_elves_plan.md`, the
## user's word 2026-10-07: no draining of life; her hands and falling comets).
##
## * **Dark Hands** ([ShadowGrasp]): where she points — her lock if it is in
##   reach, else ahead of her — a circle of violet runes opens on the ground,
##   and after `ShadowGrasp.WARN` long black hands burst up out of it. Two
##   close on each foe still in it and hold it where it stands
##   ([ShadowHold]); it takes a spell's blow. Her hand thrust down at the
##   ground as she casts it.
## * **Black Comets** ([DarkRift], [DarkComet]): she throws her hand up and a
##   rift tears open in the sky over where she points; out of it come `COMETS`
##   rocks of black stone burning in black fire, one after another, the first
##   where she pointed and the rest scattered round it (every peer the same,
##   from one seed), each striking the ground with a spell's blow round it.
## * **Black Sun** ([BlackSun]): a black sphere over where she points draws
##   everything round it in for two seconds (a boss only held back), then
##   bursts.
##
## Hangs under the [Player] as "DarkSkills" ([method Player.dark]). Her own
## peer decides where and sends it ([method Player.net_dark_grasp],
## [method Player.net_dark_comets]); every peer draws it; the host hurts and
## says who is held ([method Player.net_dark_held]).

## How far off she may point either one (her lock), and where it goes with
## nothing locked.
const REACH := 20.0
const AHEAD := 9.0

## Dark Hands: its worth, of a full bolt's (before the full charge's bonus).
const GRASP_SHARE := 0.9
## Her hand thrust at the ground.
const GRASP_CLIP := &"MG_Cast_Ground"
const GRASP_RATE := 1.4
const GRASP_PART := Vector2(0.0, 1.0)

## Black Comets.
const COMETS := 6
## When each leaves the rift, after it has opened (seconds).
const LAUNCH: Array[float] = [0.0, 0.26, 0.5, 0.78, 0.98, 1.22]
## Which of them go at what she has locked (the user's word, 2026-10-07: one
## or two at him, the rest scattered for the others round him): they follow it
## as they fall until `DarkComet.HOME` of the way, so only a late dodge
## escapes them.
const AIMED: Array[int] = [0, 3]
const RIFT_OPEN := 0.45
## How long a comet is in the air.
const FLIGHT := 0.75
## How far round the first the others fall, and how near one another at most.
const SCATTER := 4.6
const APART := 1.7
## How high the rift, and how far beyond where she points (so it is seen in
## front of her, and the comets come down at her foes from the far side).
const RIFT_HIGH := 9.0
const RIFT_BEYOND := 15.0
## Each comet's worth, of a full bolt's.
const COMET_SHARE := 0.62
## Her hand thrown up to the sky.
const CALL_CLIP := &"KV_MagicAttackCall1H01_L"
const CALL_RATE := 1.25

var hero: Player


func _ready() -> void:
	hero = get_parent() as Player


## Built once where the renderer sees it before it is needed: the hand, the
## rock, the fire and the marks, so the first cast does not stall the frame.
static func warm(at: Node3D) -> void:
	var here := at.global_position
	var hand := ShadowHand.rise(at, here, here + Vector3.FORWARD, 0.2, 0.05)
	hand.position = Vector3.ZERO
	var rock := MeshInstance3D.new()
	rock.mesh = DarkFx.rock_mesh(0)
	rock.material_override = DarkFx.rock_material()
	rock.scale = Vector3.ONE * 0.05
	at.add_child(rock)
	rock.get_tree().create_timer(0.5, false).timeout.connect(rock.queue_free)
	DarkFx.black_fire(at, here, 0.0, 0.1)
	DarkFx.smoke(at, here, 2, 0.1, 0.3)
	DarkFx.embers(at, here, 2, Vector2(0.1, 0.2), 0.3)


## Where she points: her lock if it is within `REACH`, else `AHEAD` of her; on
## the ground under that.
func _spot() -> Vector3:
	var forward := -hero.global_basis.z
	forward.y = 0.0
	forward = forward.normalized() if forward.length_squared() > 0.0001 else Vector3.FORWARD
	var at := hero.global_position + forward * AHEAD
	if hero.target != null and hero._targetable(hero.target):
		var off := hero.target.global_position - hero.global_position
		off.y = 0.0
		at = hero.global_position + off.limit_length(REACH)
	return _ground(hero, at)


static func _ground(near: Node3D, at: Vector3) -> Vector3:
	var space := near.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 12.0, at + Vector3.DOWN * 20.0, 1)
	var hit := space.intersect_ray(q)
	return (hit["position"] as Vector3) if not hit.is_empty() else at


func _face(at: Vector3) -> void:
	var to := at - hero.global_position
	to.y = 0.0
	if to.length_squared() > 0.01:
		hero.rotation.y = atan2(-to.x, -to.z)


## One blow's worth, `share` of a full bolt, and whether it is a critical.
func _worth(share: float) -> Array:
	var profile := hero.profile
	var critical := randf() < (profile.crit_chance if profile != null else 0.1)
	var damage := (profile.shot_power() if profile != null else 40.0) * BowKinds.atk(hero) * share
	if critical and profile != null:
		damage *= profile.crit_damage
	return [damage, critical]


#region Dark Hands
## Her own peer: the skill.
func grasp(cost: float) -> bool:
	if hero == null or hero.is_dead:
		return false
	if not hero._spend(cost):
		return false
	var at := _spot()
	_face(at)
	var worth := _worth(GRASP_SHARE)
	hero.net_dark_grasp.rpc(at, float(worth[0]), bool(worth[1]), randi())
	return true


## Every peer: her hand at the ground and the circle opening.
func show_grasp(at: Vector3, damage: float, critical: bool, grasp_seed: int) -> void:
	_gesture(GRASP_CLIP, GRASP_RATE, GRASP_PART.x, GRASP_PART.y, 0.1)
	var into := Blood.world_of(hero)
	ShadowGrasp.open(into, at, hero, damage, critical, grasp_seed)
	var hand := _hand()
	DarkFx.black_fire(into, hand, 0.0, 0.35, {"box": Vector3(0.08, 0.08, 0.08), "rate": 0.6})


## Every peer: these were caught, each for its own time (the host says).
func show_held(paths: Array, times: Array) -> void:
	for i in paths.size():
		var body := hero.get_node_or_null(paths[i] as NodePath) as Node3D
		if body != null:
			ShadowGrasp.clutch(body, float(times[i]) if i < times.size() else ShadowGrasp.HOLD)
#endregion


#region Black Sun
## Black Sun: its burst's worth, of a full bolt's.
const SUN_SHARE := 1.3
## Both her hands thrown forward.
const SUN_CLIP := &"KV_MagicAttackDirect2H01"
const SUN_RATE := 1.3


## Her own peer: the skill.
func sun(cost: float) -> bool:
	if hero == null or hero.is_dead:
		return false
	if not hero._spend(cost):
		return false
	var at := _spot()
	_face(at)
	var worth := _worth(SUN_SHARE)
	hero.net_dark_sun.rpc(at, float(worth[0]), bool(worth[1]))
	return true


## Every peer: her hands thrown forward and the black sun over `at`.
func show_sun(at: Vector3, damage: float, critical: bool) -> void:
	_gesture(SUN_CLIP, SUN_RATE, 0.0, 1.0, 0.1)
	var into := Blood.world_of(hero)
	BlackSun.rise(into, at, hero, damage, critical)
	DarkFx.black_fire(into, _hand(), 0.0, 0.4, {"box": Vector3(0.08, 0.08, 0.08), "rate": 0.7})
#endregion


#region Black Comets
## Her own peer: the skill.
func comets(cost: float) -> bool:
	if hero == null or hero.is_dead:
		return false
	if not hero._spend(cost):
		return false
	var at := _spot()
	_face(at)
	var quarry := NodePath()
	if hero.target != null and hero._targetable(hero.target) \
			and hero.target.global_position.distance_to(hero.global_position) <= REACH + 2.0:
		quarry = hero.target.get_path()
	var damages := PackedFloat32Array()
	var crits := PackedByteArray()
	for i in COMETS:
		var worth := _worth(COMET_SHARE)
		damages.append(float(worth[0]))
		crits.append(1 if bool(worth[1]) else 0)
	hero.net_dark_comets.rpc(at, hero.global_position, randi(), damages, crits, quarry)
	return true


## Every peer: her hand to the sky, the rift torn open over and beyond `at`
## (away from where she stands, `from`), and the comets out of it one by one.
func show_comets(at: Vector3, from: Vector3, rain_seed: int, damages: PackedFloat32Array,
		crits: PackedByteArray, quarry_path: NodePath = NodePath()) -> void:
	var quarry: Node3D = null
	if not quarry_path.is_empty():
		quarry = hero.get_node_or_null(quarry_path) as Node3D
	_gesture(CALL_CLIP, CALL_RATE, 0.0, 1.0, 0.12)
	var into := Blood.world_of(hero)
	if into == null:
		return
	var back := from - at
	back.y = 0.0
	back = back.normalized() if back.length_squared() > 0.01 else Vector3.BACK
	var sky := at - back * RIFT_BEYOND + Vector3.UP * RIFT_HIGH
	var rift := DarkRift.tear(into, sky, RIFT_OPEN + LAUNCH[LAUNCH.size() - 1] + 0.4, at - sky)
	DarkFx.black_fire(into, _hand(), 0.0, 0.4, {"box": Vector3(0.08, 0.08, 0.08), "rate": 0.7})
	var rng := RandomNumberGenerator.new()
	rng.seed = rain_seed
	var spots := _scatter(at, rng)
	for i in spots.size():
		var leave := RIFT_OPEN + LAUNCH[mini(i, LAUNCH.size() - 1)]
		var out := sky + Vector3(rng.randf_range(-1.6, 1.6), rng.randf_range(-0.4, 0.4), rng.randf_range(-1.6, 1.6))
		var big := rng.randf_range(0.85, 1.2) * (1.15 if i == 0 else 1.0)
		var which := rng.randi() % 3
		var damage := damages[i] if i < damages.size() else 0.0
		var critical := i < crits.size() and crits[i] != 0
		var spot: Vector3 = spots[i]
		var rift_id := rift.get_instance_id()
		var aimed := AIMED.has(i) and quarry != null
		var quarry_id := quarry.get_instance_id() if quarry != null else 0
		get_tree().create_timer(leave, false).timeout.connect(func() -> void:
			if not is_instance_valid(hero):
				return
			var r := instance_from_id(rift_id) as DarkRift
			if r != null:
				r.pulse()
			var to := spot
			var q: Node3D = (instance_from_id(quarry_id) as Node3D) if aimed else null
			if q != null and (not q.is_inside_tree() or q.get(&"is_dead") == true):
				q = null
			if q != null:
				to = _ground(hero, q.global_position)
			var c := DarkComet.fall(into, out, to, FLIGHT, hero, damage, critical, which, big)
			if q != null and c != null:
				c.chase(q))


## Where they fall: the first where she pointed, the rest round it, never two
## too near; each on the ground.
func _scatter(at: Vector3, rng: RandomNumberGenerator) -> Array:
	var spots: Array = [at]
	for _i in range(1, COMETS):
		var best := at
		for tries in 12:
			var a := rng.randf() * TAU
			var r := SCATTER * sqrt(rng.randf_range(0.12, 1.0))
			var p := at + Vector3(cos(a) * r, 0.0, sin(a) * r)
			best = p
			var clear := true
			for s: Vector3 in spots:
				if Vector2(s.x - p.x, s.z - p.z).length() < APART:
					clear = false
					break
			if clear or tries == 11:
				break
		spots.append(_ground(hero, best))
	return spots
#endregion


## Her arms in a gesture while her legs go on walking under it (as the elf's,
## [method MageSkills._gesture]).
func _gesture(clip: StringName, rate: float, from: float, until: float, blend: float) -> void:
	if hero == null or hero.rig == null or not hero.rig.has_method(&"play_part"):
		return
	var anim := hero.rig.get(&"_anim") as AnimationPlayer
	if anim != null and not anim.has_animation(clip):
		return
	var lasts := float(hero.rig.call(&"play_part", clip, rate, from, until, blend))
	if lasts <= 0.0:
		return
	if &"walk_under" in hero.rig:
		hero.rig.set(&"walk_under", true)
	hero.cast_walk_until = maxf(hero.cast_walk_until, hero._now() + lasts)


## Her casting hand, where the spell leaves it.
func _hand() -> Vector3:
	if hero.rig != null and hero.rig.has_method(&"spell_origin"):
		return hero.rig.call(&"spell_origin")
	return hero.global_position + Vector3.UP * 1.4
