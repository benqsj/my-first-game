class_name HurtboxComponent
extends Node

## The one door a blow comes through, shared by heroes and creatures alike.
##
## It does two things that the wolf, the [Fighter] and the [Brute] used to do
## each in a copy of their own:
##
## * **[method scan]** — watches every attacker's blade (a line segment, see
##   [method Player.cutting_edge_for]) once a tick, and turns a blade that has
##   passed through the body into a [HitInfo]: once per swing per attacker
##   (`attack_serial`), worth the attacker's own cut ([method Player.cut_worth]).
## * **[method take_hit]** — the door for everything else (an arrow, a bolt, a
##   skill), with the old `take_hit(damage, at, blow, critical, spill, from,
##   magic)` signature, so every caller that already knew it still works.
##
## Both end in **[method take]**, which marks a critical and hands the hit to
## the owner's `receive_hit(hit: HitInfo) -> bool` — what the hit *does* (armour,
## poise, a flinch, blood) stays the owner's, because a wolf, an orc and a
## hero take a blow differently. A blade that drew blood is then felt on the
## attacker's side (blood on his blade, the jolt, venom).
##
## Only the host decides: the owner's `_decides()` (or, without one, the
## [Net] host check) gates every hit.
##
## Where the body is, for the blade, is a capsule ([method set_capsule]) unless
## the owner gives its own test in [member contact] (the wolf: its limbs, cut
## off along the edge).

## A new swing seen from `attacker` (whether or not it will reach): a chance
## to answer it (a [Fighter] raises its guard, a [Brute] wakes).
signal swing_seen(attacker: Node3D)
## A hit got through and drew blood.
signal struck(hit: HitInfo)

## The group whose members' blades are watched.
@export var attacker_group: StringName = &"player"
## A swing already running when an attacker is first seen is not a cut on this
## body (it was thrown before this one was there).
@export var skip_first_swing: bool = true
## How far up the blade's line a cut throws the body (the way it is thrown).
@export var blow_lift: float = 0.3
## Whether a blade that drew blood is felt on the attacker's side through
## [method Player.blade_hit] (the bite, venom). Off for a hero struck by a hero.
@export var blade_feedback: bool = true

## The body, as a capsule up from its feet (metres, before `size`).
var body_radius: float = 0.5
var body_height: float = 2.0
var hit_tolerance: float = 0.3
var size: float = 1.0

## The owner's own test, instead of the capsule: `(attacker: Player, edge:
## PackedVector3Array) -> HitInfo` (null: not reached). It fills `at` and
## `blow`, and may fill `damage` (otherwise the attacker's cut is used).
var contact: Callable = Callable()
## Which attackers may cut this body at all: `(attacker: Node3D) -> bool`.
var may_strike: Callable = Callable()

var _seen_swing: Dictionary = {}
var _last_cut: Dictionary = {}


## The body's hurtbox, made the first time it is asked for.
static func of(body: Node3D) -> HurtboxComponent:
	var box := body.get_node_or_null(^"Hurtbox") as HurtboxComponent
	if box == null:
		box = HurtboxComponent.new()
		box.name = &"Hurtbox"
		body.add_child(box)
	return box


func set_capsule(radius: float, height: float, tolerance: float, scale: float = 1.0) -> void:
	body_radius = radius
	body_height = height
	hit_tolerance = tolerance
	size = maxf(scale, 0.01)


func _body() -> Node3D:
	return get_parent() as Node3D


func _decides() -> bool:
	var body := _body()
	if body == null or body.get(&"is_dead") == true:
		return false
	if body.has_method(&"_decides"):
		return bool(body.call(&"_decides"))
	var net := get_node_or_null(^"/root/Net")
	return net == null or bool(net.call(&"is_host"))


## Once a tick, from the owner's physics (host): every attacker's blade
## against this body.
func scan() -> void:
	var body := _body()
	if body == null:
		return
	for node in get_tree().get_nodes_in_group(attacker_group):
		var knight := node as Player
		if knight == null or knight == body or knight.rig == null:
			continue
		if may_strike.is_valid() and not bool(may_strike.call(knight)):
			continue
		var key := knight.name
		var serial: int = knight.rig.attack_serial
		if not _seen_swing.has(key):
			_seen_swing[key] = serial
			if skip_first_swing:
				_last_cut[key] = serial
				continue
		if serial != _seen_swing[key]:
			_seen_swing[key] = serial
			swing_seen.emit(knight)
		if serial == _last_cut.get(key, -1):
			continue
		var edge := knight.cutting_edge_for(body)
		if edge.is_empty():
			continue
		var hit: HitInfo = contact.call(knight, edge) if contact.is_valid() \
				else _capsule_contact(knight, edge)
		if hit == null:
			continue
		_last_cut[key] = serial
		hit.from = knight
		hit.by_blade = true
		hit.serial = serial
		if hit.damage <= 0.0:
			var worth: Array = body.call(&"_blade_damage", knight) \
					if body.has_method(&"_blade_damage") else knight.cut_worth(body)
			hit.damage = float(worth[0])
			hit.critical = bool(worth[1])
		if take(hit):
			knight.rig.bloody()
			knight.net_blade_landed.rpc(ImpactFx.matter_of(body))
			if blade_feedback:
				knight.blade_hit(body, hit.at)
		if body.get(&"is_dead") == true:
			return


## Whether the blade's edge passes through the capsule; the hit if it does.
func _capsule_contact(knight: Player, edge: PackedVector3Array) -> HitInfo:
	var body := _body()
	var low := body.global_position + Vector3.UP * body_radius * size
	var high := body.global_position + Vector3.UP * maxf(body_height - body_radius, body_radius) * size
	var near := Geometry3D.get_closest_points_between_segments(edge[0], edge[1], low, high)
	if near[0].distance_to(near[1]) > body_radius * size + hit_tolerance:
		return null
	# Thrown the way the blade was going: cut from its right, it goes left.
	var blow := knight.rig.swing_direction((edge[1] - edge[0]).normalized() + Vector3.UP * blow_lift)
	return HitInfo.make(0.0, near[1], blow)


## The door for a shot, a bolt or a skill (host), in the old signature.
func take_hit(damage: float, at: Vector3, blow: Vector3, critical: bool = false,
		spill: bool = true, from: Node = null, magic: bool = false) -> void:
	take(HitInfo.make(damage, at, blow, critical, spill, from, magic))


## Hands `hit` to the owner's `receive_hit`. True when it drew blood.
func take(hit: HitInfo) -> bool:
	if hit == null or not _decides():
		return false
	var body := _body()
	# A critical is already in `damage`: the attacker made it one.
	if hit.critical:
		CombatText.mark_critical(body)
	var drew := bool(body.call(&"receive_hit", hit))
	if drew:
		struck.emit(hit)
	return drew
