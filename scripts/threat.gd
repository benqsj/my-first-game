class_name Threat
extends RefCounted

## Who a boss is angriest at (the user's word, 2026-10-25: a raid boss must
## know who hurts it most, not stand on one hero for good nor spin to every
## blow). Kept by the host for every boss and elite ([method of]); before this
## a struck creature turned on whoever had struck it last, at once and mid-
## swing, so two heroes taking turns had it spinning between them.
##
## * **What angers it**: a blow (its worth, half again from behind, half as
##   much if guarded or slipped), a skill laid on it, a hero healed near it
##   (a flask, the Moonwell), and simply standing close in its face. It all
##   fades: half gone in `HALF` seconds.
## * **When it turns**: only when another's anger is well over its quarry's
##   (`OVER` times and `MARGIN` more), not sooner than `HOLD` seconds since
##   its last turn, and only between its acts, never mid-swing.
## * **How it is seen**: on every peer its eyes flare red as it turns
##   ([method show_turn], from the creature's `net_aggro`), and it waits a
##   beat (`BEAT`) before it swings at the new one, so he can see it coming.
## * Tariel's Challenge still holds it on him whatever the anger says.

const HALF := 8.0
const OVER := 1.15
const MARGIN := 30.0
const HOLD := 4.0
const BEAT := 0.7
## From behind its shoulders (its forward and his way from it more than
## ~110° apart), a blow angers it this much more.
const BEHIND := 1.5
const BEHIND_DOT := -0.35
## A blow it took no hurt from (guarded, slipped, an armour's clang).
const NO_HURT := 0.5
## A skill laid on it (a knock, a stun, a burn, poison), apart from its damage.
const SKILL := 30.0
## Health got back near it, this share of it.
const HEAL := 0.6
const HEAL_REACH := 25.0
## Standing in its face: this much a second, within `NEAR_REACH`.
const NEAR := 6.0
const NEAR_REACH := 3.5
const GROUP := &"threat_kept"

var _anger: Dictionary = {}
var _frame: int = -1
var _turned_frame: int = -1000000
var _engaged: bool = false
## The hero it last turned on (for [method turned]).
var last_turn: Node3D = null


## Whether `body` is one whose anger is kept: a boss (F1's, the dungeon's) or
## an elite.
static func kept(body: Node) -> bool:
	return body != null and (body.has_meta(&"boss") or body.has_meta(&"boss_name") \
			or body.has_meta(&"gift") or body.has_meta(&"elite"))


## `body`'s anger, made the first time it is asked for; null for the others.
static func of(body: Node) -> Threat:
	if not kept(body):
		return null
	if body.has_meta(&"threat"):
		return body.get_meta(&"threat") as Threat
	var t := Threat.new()
	body.set_meta(&"threat", t)
	body.add_to_group(GROUP)
	return t


static func _is_hero(who: Node) -> bool:
	return who != null and is_instance_valid(who) and who.is_in_group(&"player")


## Host: `hit` came to `body` ([HurtboxComponent.take]); `drew`: it hurt.
static func on_hit(body: Node3D, hit: HitInfo, drew: bool) -> void:
	var who := hit.attacker()
	if not _is_hero(who):
		return
	var t := of(body)
	if t == null:
		return
	var worth := maxf(hit.damage, 1.0) * (1.0 if drew else NO_HURT)
	var ahead := -body.global_transform.basis.z
	ahead.y = 0.0
	var to_him := who.global_position - body.global_position
	to_him.y = 0.0
	if ahead.length_squared() > 0.0001 and to_him.length_squared() > 0.0001 \
			and ahead.normalized().dot(to_him.normalized()) < BEHIND_DOT:
		worth *= BEHIND
	t.add(who, worth)


## Host: a skill of `who`'s laid on `body` (its `react`), or a burn's tick.
static func on_skill(body: Node3D, who: Node3D, worth: float = SKILL) -> void:
	if not _is_hero(who):
		return
	var t := of(body)
	if t != null:
		t.add(who, worth)


## Host: `hero` got `amount` back; every kept creature near that is already
## fighting someone hears of it.
static func on_heal(hero: Node3D, amount: float) -> void:
	if hero == null or not hero.is_inside_tree() or amount <= 0.0:
		return
	for node in hero.get_tree().get_nodes_in_group(GROUP):
		var body := node as Node3D
		if body == null or not body.has_meta(&"threat") or body.get(&"is_dead") == true:
			continue
		if body.global_position.distance_to(hero.global_position) > HEAL_REACH:
			continue
		var t := body.get_meta(&"threat") as Threat
		if not t._anger.is_empty():
			t.add(hero, amount * HEAL)


## Host: `hero` strikes a fallen friend up ([Player.net_revive]): every kept
## creature near that is fighting hears of it, and the last blow most (the
## user's word, 2026-10-28: raising a friend mid-fight is a risk, not a gift).
static func on_revive(hero: Node3D, last: bool) -> void:
	if hero == null or not hero.is_inside_tree():
		return
	for node in hero.get_tree().get_nodes_in_group(GROUP):
		var body := node as Node3D
		if body == null or not body.has_meta(&"threat") or body.get(&"is_dead") == true:
			continue
		if body.global_position.distance_to(hero.global_position) > HEAL_REACH:
			continue
		var t := body.get_meta(&"threat") as Threat
		if not t._anger.is_empty():
			t.add(hero, REVIVE_LAST if last else REVIVE_BLOW)


## What each blow of a raising angers it, and the one that raises him.
const REVIVE_BLOW := 45.0
const REVIVE_LAST := 140.0


func add(who: Node3D, worth: float) -> void:
	var id := who.get_instance_id()
	_anger[id] = float(_anger.get(id, 0.0)) + worth


func anger(who: Node3D) -> float:
	return float(_anger.get(who.get_instance_id(), 0.0)) if who != null else 0.0


## Host, as the creature picks its quarry: the hero it should now be on, or
## null to leave the choice as it was. `current` is its quarry, `ok` whether a
## hero may be gone for (on its ground, not fallen nor hidden), `idle` whether
## it is between acts. When it turns, [member last_turn] is set and
## [method turned] is true this frame.
func choose(body: Node3D, current: Node3D, ok: Callable, idle: bool) -> Node3D:
	var now := Engine.get_physics_frames()
	var tick := 1.0 / float(maxi(Engine.physics_ticks_per_second, 1))
	var dt := 0.0 if _frame < 0 else float(now - _frame) * tick
	_frame = now
	if dt > 0.0:
		var keep := pow(0.5, dt / HALF)
		for id: int in _anger.keys():
			_anger[id] = float(_anger[id]) * keep
	var have_current := current != null and is_instance_valid(current) and current.is_inside_tree() \
			and bool(ok.call(current))
	var top: Node3D = null
	var top_anger := 0.0
	var nearest: Node3D = null
	var nearest_gap := NEAR_REACH * NEAR_REACH
	for node in body.get_tree().get_nodes_in_group(&"player"):
		var who := node as Node3D
		if who == null or not bool(ok.call(who)):
			continue
		var gap := body.global_position.distance_squared_to(who.global_position)
		if gap < nearest_gap:
			nearest_gap = gap
			nearest = who
		var a := anger(who)
		if a > top_anger:
			top_anger = a
			top = who
	# only once it is in the fight does standing in its face count
	if nearest != null and dt > 0.0 and not _anger.is_empty():
		add(nearest, NEAR * dt)
	if top == null:
		return null
	if not have_current:
		# its quarry gone (fallen, hidden, off its ground): the angriest next
		return _turn(top, now) if top != current else top
	if not _engaged:
		# the fight's start: its first quarry is held a while too
		_engaged = true
		_turned_frame = now
	if top == current or not idle:
		return null
	if float(now - _turned_frame) * tick < HOLD:
		return null
	if top_anger <= anger(current) * OVER + MARGIN:
		return null
	return _turn(top, now)


func _turn(who: Node3D, now: int) -> Node3D:
	_turned_frame = now
	last_turn = who
	return who


## Host: `body` turned on `who` by a move of its own (a blow from behind
## answered, one far off gone for, a string's next blow swung onto another;
## the user's word, 2026-10-28: a boss must strike them all): angered at him
## by `worth` and held on him as after any turn (`HOLD`), its eyes flaring on
## every peer. Also for a body whose anger is not kept (its eyes only).
static func turn_to(body: Node3D, who: Node3D, worth: float) -> void:
	if body == null or who == null or not is_instance_valid(who):
		return
	var t := of(body)
	if t != null:
		t.add(who, worth)
		t._engaged = true
		t._turn(who, Engine.get_physics_frames())
	if not body.has_method(&"net_aggro") or not body.is_inside_tree():
		return
	if body.multiplayer.has_multiplayer_peer():
		body.rpc(&"net_aggro", body.get_path_to(who))
	else:
		body.call(&"net_aggro", body.get_path_to(who))


## Whether it turned on [member last_turn] in this physics frame.
func turned() -> bool:
	return _turned_frame == Engine.get_physics_frames()


## Whether a blow from `who` should leave its quarry as it is: a kept
## creature already fighting someone else turns only by [method choose].
static func holds(body: Node3D, quarry: Node3D, who: Node3D) -> bool:
	if not kept(body) or quarry == null or not is_instance_valid(quarry) or quarry == who:
		return false
	var mode: Variant = body.get(&"mode")
	# both kinds' Mode: GUARD 0, CHASE 1, FIGHT 2, RETURN 3
	return mode is int and (int(mode) == 1 or int(mode) == 2) and not Brute.unseen(quarry)


## Host: after `body` picked `who`; when it was a turn, its beat and the sign
## of it on every peer (the creature's own `net_aggro` rpc).
static func after_pick(body: Node3D, who: Node3D) -> void:
	if who == null or not body.has_meta(&"threat"):
		return
	var t := body.get_meta(&"threat") as Threat
	if not t.turned() or t.last_turn != who:
		return
	if "_cooldown" in body:
		body.set(&"_cooldown", maxf(float(body.get(&"_cooldown")), BEAT))
	if body.is_inside_tree() and body.multiplayer.has_multiplayer_peer():
		body.rpc(&"net_aggro", body.get_path_to(who))
	else:
		body.call(&"net_aggro", body.get_path_to(who))


## Every peer: its eyes flare red as it turns on `who`.
static func show_turn(body: Node3D, who: Node3D, head: float) -> void:
	if body == null or not body.is_inside_tree():
		return
	var into := body.get_parent()
	var ahead := -body.global_transform.basis.z
	ahead.y = 0.0
	ahead = ahead.normalized() if ahead.length_squared() > 0.0001 else Vector3.FORWARD
	if who != null and is_instance_valid(who):
		var to_him := who.global_position - body.global_position
		to_him.y = 0.0
		if to_him.length_squared() > 0.0001:
			ahead = to_him.normalized()
	var at := body.global_position + Vector3.UP * head + ahead * 0.25
	var side := ahead.cross(Vector3.UP).normalized() * 0.09 * maxf(head / 2.0, 1.0)
	for s: float in [-1.0, 1.0]:
		var eye := SkillFx.flash(into, at + side * s, Color(1.0, 0.12, 0.05), 0.16, 0.55, 6.0)
		if eye != null:
			eye.reparent(body)
	SkillFx.light(into, at, Color(1.0, 0.2, 0.08), 2.5, 3.0)
