class_name ElfSkills
extends Node

## The elf mage's skills beyond the Frost Spears and the Frost Step
## ([MageSkills]), the user's picks 2026-10-07 (the plan:
## `claude/mage_polish_plan.md`):
##
## * **Frost Nova**: her staff struck down, the cold bursting out round her in
##   a ring of ice `NOVA_RADIUS` wide; whatever it reaches is hurt a little and
##   **frozen** ([FrostShell]) for `NOVA_FREEZE`, twice as long if it was
##   already chilled (her Frost Step's trail), half as long a boss. A frozen
##   foe struck by her spells shatters for half as much again.
## * **Moonwell** ([MoonWell]): a circle of moonlight laid at her feet for
##   `MoonWell.SECONDS`: she and her friends in it are healed a quarter of
##   their health over its time; foes in it are chilled.
## * **Moonfall** ([MoonFall]): where she points (her lock, else ahead) a
##   circle of runes marks the ground for `MoonFall.WARN`, then a column of
##   moonlight falls on it: a heavy spell's blow and a stun to all in it.
##
## Hangs under the [Player] as "ElfSkills" ([method Player.elf]). Her own peer
## decides and sends; every peer draws; the host hurts, freezes and heals.

const REACH := 20.0
const AHEAD := 9.0

const NOVA_RADIUS := 4.5
const NOVA_FREEZE := 1.5
const NOVA_MOST := 3.0
const NOVA_SHARE := 0.35
## When the ring reaches its edge (it runs out from her).
const NOVA_RUN := 0.28
const NOVA_CLIP := &"KV_MagicAttackOmni01"
const NOVA_RATE := 1.5

const FALL_SHARE := 1.6
const CALL_CLIP := &"KV_MagicAttackCall1H01_L"
const CALL_RATE := 1.3

const WELL_CLIP := &"MG_Heal"
const WELL_RATE := 1.4

const ICE := Color(0.62, 0.9, 1.0)
const ICE_HOT := Color(0.9, 0.98, 1.0)

var hero: Player


func _ready() -> void:
	hero = get_parent() as Player


#region Common
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
	return DarkSkills._ground(hero, at)


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


## Her arms in a gesture while her legs go on under it ([method MageSkills._gesture]).
func _gesture(clip: StringName, rate: float, blend: float = 0.1) -> void:
	if hero == null or hero.rig == null or not hero.rig.has_method(&"play_part"):
		return
	var anim := hero.rig.get(&"_anim") as AnimationPlayer
	if anim != null and not anim.has_animation(clip):
		return
	var lasts := float(hero.rig.call(&"play_part", clip, rate, 0.0, 1.0, blend))
	if lasts <= 0.0:
		return
	if &"walk_under" in hero.rig:
		hero.rig.set(&"walk_under", true)
	hero.cast_walk_until = maxf(hero.cast_walk_until, hero._now() + lasts)


## Her foes: the creatures, and in PvP the heroes she is hostile to.
static func foes_of(caster: Node) -> Array[Node3D]:
	var out: Array[Node3D] = []
	if caster == null or not caster.is_inside_tree():
		return out
	for node in caster.get_tree().get_nodes_in_group(&"enemy"):
		var who := node as Node3D
		if who != null and who.get(&"is_dead") != true:
			out.append(who)
	if caster is Player and Player.pvp_mode:
		for node in caster.get_tree().get_nodes_in_group(&"player"):
			if (caster as Player).is_hostile_to(node):
				out.append(node as Node3D)
	return out


## Whether `who` stands within `radius` of `at` (its own breadth counted).
static func within(who: Node3D, at: Vector3, radius: float, high: float = 2.5) -> bool:
	var off := who.global_position - at
	if absf(off.y) > high:
		return false
	off.y = 0.0
	var br: Variant = who.get(&"body_radius")
	return off.length() <= radius + (float(br) if br != null else 0.4) * 0.6


## The host: `who` hurt by her spell, worth `damage` (more, frozen: it shatters).
static func hurt(who: Node3D, damage: float, critical: bool, caster: Node3D, at: Vector3) -> void:
	damage *= FrostShell.shatter(who)
	if who is Player:
		if who.get("net_dead") != true and caster != null:
			who.call(&"receive_blow", damage, caster, 0, 2, caster.get_instance_id() % 100000, true)
	elif who.has_method(&"take_hit"):
		who.call(&"take_hit", damage, at, Vector3.UP * 0.5, critical, false, caster, true)
#endregion


#region Frost Nova
## Her own peer: the skill.
func nova(cost: float) -> bool:
	if hero == null or hero.is_dead or not hero._spend(cost):
		return false
	var worth := _worth(NOVA_SHARE)
	var at := DarkSkills._ground(hero, hero.global_position)
	hero.net_elf_nova.rpc(at, float(worth[0]), bool(worth[1]))
	return true


## Every peer: her staff struck down and the ring of ice running out from her;
## the host, as it reaches them, hurts and freezes what is in it.
func show_nova(at: Vector3, damage: float, critical: bool) -> void:
	_gesture(NOVA_CLIP, NOVA_RATE, 0.08)
	var into := Blood.world_of(hero)
	if into == null:
		return
	var lead := 0.18
	var hero_id := hero.get_instance_id()
	get_tree().create_timer(lead, false).timeout.connect(func() -> void:
		var h := instance_from_id(hero_id) as Player
		if h == null:
			return
		FrostNova.burst(into, at, NOVA_RADIUS, NOVA_RUN)
		if h.multiplayer.is_server():
			h.get_tree().create_timer(NOVA_RUN * 0.6, false).timeout.connect(func() -> void:
				var h2 := instance_from_id(hero_id) as Player
				if h2 != null:
					h2.elf()._nova_catch(at, damage, critical)))


## The host: who the ring reached is hurt and frozen, and everyone is told.
func _nova_catch(at: Vector3, damage: float, critical: bool) -> void:
	var paths: Array = []
	var times: Array = []
	for who in foes_of(hero):
		if not within(who, at, NOVA_RADIUS):
			continue
		var marks := Afflictions.of(who, false)
		var chilled := marks != null and marks.is_chilled()
		hurt(who, damage, critical, hero, who.global_position + Vector3.UP * 0.8)
		if who.get(&"is_dead") == true:
			continue
		var seconds := minf(NOVA_FREEZE * (2.0 if chilled else 1.0), NOVA_MOST)
		if ShadowGrasp.is_boss(who):
			seconds *= 0.5
		if who.has_method(&"react"):
			who.call(&"react", &"stun", hero, Vector3.ZERO)
		paths.append(who.get_path())
		times.append(seconds)
	if not paths.is_empty():
		hero.net_elf_frozen.rpc(paths, times)


## Every peer: these are frozen, each for its own time (the host says).
func show_frozen(paths: Array, times: Array) -> void:
	for i in paths.size():
		var body := hero.get_node_or_null(paths[i] as NodePath) as Node3D
		if body != null:
			FrostShell.encase(body, float(times[i]) if i < times.size() else NOVA_FREEZE)
#endregion


#region Moonwell
## Her own peer: the skill.
func moonwell(cost: float) -> bool:
	if hero == null or hero.is_dead or not hero._spend(cost):
		return false
	hero.net_elf_moonwell.rpc(DarkSkills._ground(hero, hero.global_position))
	return true


## Every peer: her hand raised and the well of moonlight opening at `at`.
func show_moonwell(at: Vector3) -> void:
	_gesture(WELL_CLIP, WELL_RATE, 0.1)
	var into := Blood.world_of(hero)
	if into != null:
		MoonWell.open(into, at, hero)
#endregion


#region Moonfall
## Her own peer: the skill.
func moonfall(cost: float) -> bool:
	if hero == null or hero.is_dead or not hero._spend(cost):
		return false
	var at := _spot()
	_face(at)
	var worth := _worth(FALL_SHARE)
	hero.net_elf_moonfall.rpc(at, float(worth[0]), bool(worth[1]))
	return true


## Every peer: her hand to the sky, the runes at `at`, and the moon's light.
func show_moonfall(at: Vector3, damage: float, critical: bool) -> void:
	_gesture(CALL_CLIP, CALL_RATE, 0.12)
	var into := Blood.world_of(hero)
	if into != null:
		MoonFall.drop(into, at, hero, damage, critical)
#endregion
