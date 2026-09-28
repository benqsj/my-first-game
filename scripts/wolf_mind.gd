class_name WolfMind
extends RefCounted

## How a wolf fights once it is close — and how well, by its `intellect`.
##
## A wolf in a fight is always doing one of five things (`Tactic`):
##
## * **CLOSE** — coming in to striking distance, straight at its quarry.
## * **STRIKE** — throwing a combo, one attack after another as each ends.
## * **CIRCLE** — side-stepping round its quarry at a ring's distance, looking
##   for an opening, drifting towards his back; a clever one circles more.
## * **RETREAT** — backing off, or hopping back, out of his reach…
## * **WAIT** — …and holding there a moment, watching, before it comes again —
##   often all at once, in a pounce from out of reach. It never runs away for
##   good: however hurt it is, it comes back.
## * **RUN_UP** — it draws off a way, face on, then comes at him at a run that
##   builds, striking out of it: a spinning rake of both claws, a leap into a
##   two-handed smash, or the pounce.
## * **SHOOT** — two of a pack on one man, now and then: one stands off at
##   range and throws the claws' cut at him while the other brawls, and after a
##   while they change places — the thrower comes in, the brawler draws off to
##   throw.
##
## Closing from further off than a step or two it runs rather than walks, and
## the run builds the longer it goes; fast enough, it strikes out of it.
##
## And whatever it is doing, it **watches his blade**: when he starts a swing and
## it is within reach, it may throw itself aside (a dodge, left or right) or hop
## back out of it — how soon it sees it coming and how often it gets away is its
## intellect. A clever one also **punishes a miss**: while he is still coming
## out of a swing that found nothing, it goes in.
##
## **Intellect**, 0 to 1 (each wolf its own, drawn when it is born):
##
## | | dull (0.2) | middling (0.5) | cunning (0.9) |
## |---|---|---|---|
## | sees a swing coming | 0.38 s | 0.26 s | 0.14 s |
## | gets out of one | 1 in 4 | 1 in 2 | 3 in 4 |
## | longest combo | 1 | 2 | 3 |
## | circles, feints, flanks | no | some | often |
## | backs off after a combo | 1 in 3 | 1 in 2 | 3 in 4 |
## | punishes a miss | no | yes | yes, at once |
## | waits its turn in a pack | no | yes | yes |
##
## Its **combos** are made from what it has left, and it fights hand to hand
## (the user asked for a wolf that brawls rather than one that mostly leaps):
##
## * both arms — chains of two to four blows from its swipes, a jab, a
##   zombie's rake, a two- and a three-blow combo and an overhead two-handed
##   smash (see `Wolf.MELEE`); now and then one blow held
##   at the top of its windup before it comes (the delayed blow), and now and
##   then the old *rake and leap*. Caught by every blow of a chain a man goes
##   down; the smash puts him down alone and cannot be turned on a shield;
## * one arm — a swipe, or a swipe and a bite;
## * no arms — the *bite*: a lunge with its jaws;
## * a leg gone — it is down on its belly, crawling at him, and its attack is
##   the *ground lunge*: it throws itself forward, claws and jaws together. It
##   cannot dodge or hop any more, and it does not stop coming.
##
## Hurt, it grows careful: it backs off more and dodges more — and comes back.

enum Tactic { CLOSE, STRIKE, CIRCLE, RETREAT, WAIT, RUN_UP, SHOOT }

## At most this many wolves go at one player together; the rest of the pack
## circles and waits its turn (only wolves with the wit to).
const PACK_ATTACKERS := 2
## Who holds a turn at whom: quarry's instance id -> the wolves going in at him.
static var _turns: Dictionary = {}
## The one wolf standing off to throw at whom: quarry's instance id -> Wolf.
static var _shooters: Dictionary = {}
## The band it keeps while it throws, metres.
const SHOOT_NEAR := 6.0
const SHOOT_FAR := 8.5

var wolf: Wolf
var intellect: float = 0.5
var tactic: int = Tactic.CLOSE

var _rng := RandomNumberGenerator.new()
var _left: float = 0.0
var _combo: Array[StringName] = []
var _gap: float = 0.0
var _side: float = 1.0
## The quarry's swing as last seen: its serial, and when it began.
var _seen_serial: int = -2
var _swing_at: float = -100.0
var _swing_reacted: bool = true
## How careful it has grown from being hurt, 0 to 1; wears off.
var _caution: float = 0.0
var _clock: float = 0.0
var _quarry: Node3D
## The combo it is closing in to throw: chosen as it comes in, so it comes in
## to the distance that combo's first blow is thrown from.
var _next: Array[StringName] = []
## Standing off to throw: till the next throw.
var _shot_wait: float = 0.0
## Just done throwing: it brawls a while before it may throw again.
var _no_shot_until: float = 0.0


func _init(owner: Wolf, wit: float) -> void:
	wolf = owner
	intellect = clampf(wit, 0.0, 1.0)
	_rng.randomize()
	_side = 1.0 if _rng.randf() < 0.5 else -1.0


#region What intellect buys
func reaction() -> float:
	return lerpf(0.42, 0.12, intellect)


func dodge_chance() -> float:
	return clampf(0.06 + 0.42 * intellect + 0.15 * _caution, 0.0, 0.7)


func combo_max() -> int:
	return 1 + int(round(2.0 * intellect))


func ring() -> float:
	return lerpf(2.2, 3.0, intellect)


## How far it draws off before it comes back at a run: short of where it
## would give up the fight ([method Wolf.fight_from]). It draws off facing
## him, slantwise, never turning its back.
const RUN_UP_TO := 6.2


func run_up_chance() -> float:
	return 0.22 + 0.18 * intellect


func retreat_chance() -> float:
	return clampf(0.15 + 0.25 * intellect + 0.25 * _caution, 0.0, 0.6)
#endregion


## It was hurt: warier for a while, and a clever one gets out of reach at once.
func hurt() -> void:
	_caution = minf(_caution + 0.35, 1.0)
	if wolf.is_crippled() or wolf.is_busy():
		return
	if _rng.randf() < 0.1 + 0.25 * intellect:
		_begin(Tactic.RETREAT)


## Broken out of his combo with a hop back: straight back in with a leap as
## soon as it lands.
func come_back_leaping() -> void:
	tactic = Tactic.STRIKE
	_set_combo([&"pounce"])
	_gap = 0.25


## Cut again and again: it trades, straight back at him through it.
func counter() -> void:
	tactic = Tactic.STRIKE
	_set_combo([&"punch", &"rake"] if _rng.randf() < 0.5 else [&"punch", &"swipe"])
	_gap = 0.0


func _set_combo(moves: Array) -> void:
	_combo.assign(moves)
	var blows := 0
	for m: StringName in _combo:
		blows += Wolf.blows_in(m)
	wolf.begin_chain(blows)


## The fight begins (or begins again): in at him, if it is its turn.
func engage(quarry: Node3D) -> void:
	_quarry = quarry
	_begin(Tactic.CLOSE)


## One think of the fight, host side. `quarry` is who it is after.
func fight(delta: float, quarry: Node3D, to_quarry: Vector3, gap: float) -> void:
	_quarry = quarry
	_clock += delta
	_left -= delta
	_gap = maxf(_gap - delta, 0.0)
	_caution = maxf(_caution - delta * 0.04, 0.0)
	var towards := to_quarry.normalized() if gap > 0.01 else -wolf.global_transform.basis.z

	if wolf.is_crippled():
		_crawl_fight(delta, towards, gap)
		return
	_watch_blade(quarry, gap)
	if wolf.is_busy():
		# It turns after him through the windup, not once the blow is coming:
		# from there the blow goes where it was aimed.
		if wolf.tracking():
			wolf.face(towards, delta)
		return

	if tactic != Tactic.CLOSE and tactic != Tactic.STRIKE:
		_release()
	if tactic != Tactic.SHOOT:
		_release_shot()
		# Two on him: now and then, out of closing, circling or waiting, this
		# one draws off to throw while the other brawls.
		if (tactic == Tactic.CLOSE or tactic == Tactic.CIRCLE or tactic == Tactic.WAIT) and gap > 2.5 \
				and _rng.randf() < delta * (0.1 + 0.2 * intellect) and _may_shoot():
			_begin(Tactic.SHOOT)
	match tactic:
		Tactic.CLOSE:
			if not _take_turn(quarry):
				_begin(Tactic.CIRCLE)
			elif gap <= _opening_reach():
				_begin(Tactic.STRIKE)
			elif wolf.try_run_attack(gap):
				_begin(Tactic.WAIT)
			elif gap > wolf.strike_range() + 1.8 or wolf.is_running():
				wolf.charge_at(towards, delta)
			else:
				wolf.run_at(towards, delta)
		Tactic.STRIKE:
			wolf.face(towards, delta)
			wolf.hold(delta)
			if _combo.is_empty():
				_after_combo()
			elif _gap <= 0.0:
				var move: StringName = _combo.pop_front()
				if move != &"pounce" and move != &"hop" and move != &"claw_wave" and gap > wolf.reach_of(move) + 0.8:
					# He got away between blows: after him.
					_combo.push_front(move)
					_begin(Tactic.CLOSE)
				else:
					wolf.attack(move, Vector3.ZERO, _delay_for(move))
					# Blow after blow: a chain, not a string of single moves.
					_gap = lerpf(0.16, 0.03, intellect)
		Tactic.CIRCLE:
			var round_him := towards.cross(Vector3.UP) * _side
			# In or out towards the ring as it goes round.
			var drift := towards * clampf(gap - ring(), -1.0, 1.0)
			wolf.strafe((round_him + drift).normalized(), towards, delta)
			if _left <= 0.0:
				_next_from_range(gap)
		Tactic.RETREAT:
			if gap < ring() + 0.9 and _left > 0.0:
				wolf.back_off(towards, delta)
			else:
				_begin(Tactic.WAIT)
		Tactic.WAIT:
			wolf.face(towards, delta)
			wolf.hold(delta)
			if _left <= 0.0:
				_next_from_range(gap)
		Tactic.SHOOT:
			_shot_wait = maxf(_shot_wait - delta, 0.0)
			var round_him := towards.cross(Vector3.UP) * _side
			if gap < SHOOT_NEAR:
				wolf.withdraw(towards, round_him, delta)
			elif gap > SHOOT_FAR:
				wolf.run_at(towards, delta)
			else:
				wolf.strafe(round_him, towards, delta)
			if _shot_wait <= 0.0 and wolf.can_claw(gap):
				wolf.attack(&"claw_wave")
				# Throwing is its part now: sooner again than a claw wave thrown
				# out of a brawl.
				wolf.hurry_claw(_rng.randf_range(2.6, 3.8))
				_shot_wait = _rng.randf_range(2.6, 3.8)
			if _left <= 0.0 or wolf.arms_left() < 2:
				_swap_shot(quarry)
		Tactic.RUN_UP:
			# Drawing off a way, slantwise and face on, watching him; then at
			# him at a run that builds.
			if gap < RUN_UP_TO and _left > 0.0:
				wolf.withdraw(towards, towards.cross(Vector3.UP) * _side, delta)
			else:
				_begin(Tactic.CLOSE)


## How close it closes before it throws what it means to: the reach of the
## first blow of the combo it has in mind ([method Wolf.reach_of]).
func _opening_reach() -> float:
	if _next.is_empty():
		_next = _choose_combo()
	return wolf.reach_of(_next[0])


## With a leg gone: down on its belly, dragging itself at him, and when it is
## close the ground lunge. It does not back off.
func _crawl_fight(delta: float, towards: Vector3, gap: float) -> void:
	if wolf.is_busy():
		wolf.face(towards, delta)
		return
	if gap <= wolf.lunge_range() and _gap <= 0.0:
		wolf.attack(&"ground_lunge")
		_gap = lerpf(1.1, 0.5, intellect)
	else:
		wolf.crawl_at(towards, delta)


#region Deciding
func _begin(what: int) -> void:
	if what == Tactic.CLOSE and not _take_turn(_quarry):
		what = Tactic.CIRCLE
	if what != Tactic.CLOSE and what != Tactic.STRIKE:
		_release()
	tactic = what
	match what:
		Tactic.CLOSE:
			_next = _choose_combo()
			# Two on him: now and then this one stands off to throw instead.
			if _may_shoot() and _rng.randf() < 0.25 + 0.2 * intellect and wolf.global_position.distance_to(
					_quarry.global_position) > 3.0:
				_release()
				tactic = Tactic.SHOOT
				_left = _rng.randf_range(6.0, 9.0)
				_shot_wait = _rng.randf_range(0.2, 0.8)
				_shooters[_quarry.get_instance_id()] = wolf
		Tactic.STRIKE:
			_set_combo(_next if not _next.is_empty() else _choose_combo())
			_next = []
			_gap = 0.0
		Tactic.CIRCLE:
			_left = _rng.randf_range(0.5, 0.9 + 0.8 * intellect)
			if _rng.randf() < 0.3:
				_side = -_side
		Tactic.RETREAT:
			_left = 1.4
			# A clever one hops out of reach before backing further.
			if intellect > 0.5 and _rng.randf() < 0.15 + 0.25 * intellect and wolf.can_leap():
				wolf.attack(&"hop")
		Tactic.WAIT:
			_left = _rng.randf_range(0.3, 1.0) * lerpf(1.0, 0.6, intellect)
		Tactic.SHOOT:
			_left = _rng.randf_range(6.0, 9.0)
			_shot_wait = _rng.randf_range(0.2, 0.8)
			if _quarry != null:
				_shooters[_quarry.get_instance_id()] = wolf
		Tactic.RUN_UP:
			_left = _rng.randf_range(1.0, 1.8)
			if _rng.randf() < 0.5:
				_side = -_side


## A combo from what it has left, as long as its wit allows.
func _choose_combo() -> Array[StringName]:
	var arms := wolf.arms_left()
	var most := combo_max()
	var out: Array[StringName] = []
	if arms == 0:
		out.append(&"bite")
		if most >= 2 and _rng.randf() < 0.5:
			out.append(&"bite")
		return out
	if arms == 1:
		out.append(&"swipe")
		if most >= 2 and _rng.randf() < 0.6:
			out.append(&"bite")
		return out
	# Hand to hand. Every wolf throws chains; a cleverer one longer and more
	# varied ones, and holds a blow back to catch a man who rolls too soon.
	var chains: Array = [
		[&"swipe", &"swipe"],
		[&"punch", &"swipe"],
		[&"rake", &"combo2"],
		[&"combo2"],
		[&"combo3"],
		[&"slam"],
		[&"swipe", &"bite"],
	]
	if most >= 3:
		chains.append_array([
			[&"swipe", &"swipe", &"slam"],
			[&"punch", &"combo3"],
			[&"rake", &"swipe", &"swipe"],
			[&"swipe", &"combo2", &"slam"],
			[&"combo3", &"slam"],
			[&"swipe", &"swipe", &"pounce"],
		])
	out.assign(chains[_rng.randi() % chains.size()])
	return out


## Whether this blow is held back at the top of its windup, and how long: the
## opening blow of a chain now and then, the smash more often.
func _delay_for(move: StringName) -> float:
	if not Wolf.MELEE.has(move) and move != &"swipe":
		return 0.0
	if move == &"swipe":
		return 0.0
	var chance := 0.08 + 0.2 * intellect
	if move == &"slam":
		chance += 0.15
	return _rng.randf_range(0.15, 0.35) if _rng.randf() < chance else 0.0


func _after_combo() -> void:
	if intellect < 0.2:
		_begin(Tactic.CLOSE)
	elif _rng.randf() < retreat_chance():
		_begin(Tactic.RETREAT)
	elif _rng.randf() < intellect:
		_begin(Tactic.CIRCLE)
	else:
		_begin(Tactic.WAIT)


## Out of the circle or the wait: straight in, or — from out of reach, with
## both arms — the sudden leap.
func _next_from_range(gap: float) -> void:
	# Now and then, from where it stands: the claw wave.
	if wolf.can_claw(gap) and _rng.randf() < 0.18 + 0.18 * intellect:
		tactic = Tactic.STRIKE
		_set_combo([&"claw_wave"])
		_gap = 0.0
		return
	# Two of a pack on him: one stands off and throws, the other brawls.
	if _may_shoot() and _rng.randf() < 0.3 + 0.3 * intellect:
		_begin(Tactic.SHOOT)
		return
	# Off a way, to come back at a run.
	if wolf.arms_left() == 2 and wolf.can_leap() and _rng.randf() < run_up_chance():
		_begin(Tactic.RUN_UP)
		return
	if gap > wolf.strike_range() + 0.6 and gap < wolf.pounce_range() and wolf.arms_left() == 2 \
			and _rng.randf() < 0.15 + 0.2 * intellect:
		tactic = Tactic.STRIKE
		_set_combo([&"pounce"])
		_gap = 0.0
		return
	_begin(Tactic.CLOSE)


## Whether it may go in now, or must wait its turn behind the pack: a turn is
## held from closing in until it backs off or circles, and only so many wolves
## hold one at the same player. A dull wolf does not wait for anyone.
func _take_turn(quarry: Node3D) -> bool:
	if quarry == null:
		return true
	if intellect < 0.3:
		return true
	var key := quarry.get_instance_id()
	var holders: Array = _turns.get(key, [])
	# Only wolves still in it, near him, count.
	holders = holders.filter(func(w: Variant) -> bool:
		return is_instance_valid(w) and not (w as Wolf).is_dead and (w as Wolf).is_physics_processing() \
				and (w as Wolf).fighting() == quarry and (w as Wolf).global_position.distance_to(quarry.global_position) < 7.0 \
				and (w as Wolf).mind != null \
				and ((w as Wolf).mind.tactic == Tactic.CLOSE or (w as Wolf).mind.tactic == Tactic.STRIKE))
	_turns[key] = holders
	if holders.has(wolf):
		return true
	if holders.size() >= PACK_ATTACKERS:
		return false
	holders.append(wolf)
	return true


func _release() -> void:
	for key in _turns:
		(_turns[key] as Array).erase(wolf)


## Whether it may be the one to stand off and throw: a wolf with the wit for
## it and both arms, another of the pack going in at the same man, and nobody
## throwing at him already.
func _may_shoot() -> bool:
	if _quarry == null or intellect < 0.35 or wolf.arms_left() < 2 or wolf.is_crippled() or _clock < _no_shot_until:
		return false
	var key := _quarry.get_instance_id()
	var shooter: Variant = _shooters.get(key)
	# Somebody throwing at him already — still in the fight, still at it.
	if shooter != null and is_instance_valid(shooter) and shooter != wolf and not (shooter as Wolf).is_dead \
			and (shooter as Wolf).is_physics_processing() and (shooter as Wolf).fighting() == _quarry \
			and (shooter as Wolf).mind != null and (shooter as Wolf).mind.tactic == Tactic.SHOOT:
		return false
	return _partner() != null


## Another of the pack fighting the same man, near him.
func _partner() -> Wolf:
	if _quarry == null or not wolf.is_inside_tree():
		return null
	for node in wolf.get_tree().get_nodes_in_group(&"wolf"):
		var w := node as Wolf
		if w == null or w == wolf or w.is_dead or w.mind == null or w.fighting() != _quarry:
			continue
		if w.global_position.distance_to(_quarry.global_position) < 9.0:
			return w
	return null


func _release_shot() -> void:
	for key in _shooters.keys():
		if _shooters[key] == wolf:
			_shooters.erase(key)


## Its turn at throwing done: in at him itself, and the one that was brawling
## draws off to throw in its place.
func _swap_shot(quarry: Node3D) -> void:
	_release_shot()
	_quarry = quarry
	var partner := _partner()
	_no_shot_until = _clock + 6.0
	_begin(Tactic.CLOSE)
	if partner != null and partner.mind._may_take_shot():
		partner.mind.take_shot()


func _may_take_shot() -> bool:
	return intellect >= 0.35 and wolf.arms_left() == 2 and not wolf.is_crippled()


## Told by its partner to stand off and throw.
func take_shot() -> void:
	_release()
	_begin(Tactic.SHOOT)


#endregion


#region Reading him
## His blade: a new swing starting within reach is seen after `reaction()`, and
## then it is got out of — or not. A swing that has come and gone leaves him
## open, and a clever wolf goes in.
func _watch_blade(quarry: Node3D, gap: float) -> void:
	var serial := _swing_serial(quarry)
	if _seen_serial == -2:
		# The first look: whatever he did before it came is not a swing at it.
		_seen_serial = serial
	elif serial != _seen_serial:
		_seen_serial = serial
		_swing_at = _clock
		_swing_reacted = false
	var since := _clock - _swing_at
	if not _swing_reacted and since >= reaction():
		_swing_reacted = true
		# A cunning wolf will even break off its own windup to get out of the way.
		var free := not wolf.is_busy() or (intellect > 0.55 and wolf.winding_up())
		if gap < 3.4 and free and wolf.can_leap() and _rng.randf() < dodge_chance():
			if _rng.randf() < 0.2:
				wolf.attack(&"hop")
				_begin(Tactic.WAIT)
			else:
				wolf.attack(&"dodge_left" if _rng.randf() < 0.5 else &"dodge_right")
				_begin(Tactic.WAIT)
			return
	# The miss, punished.
	if intellect > 0.35 and since > 0.45 and since < 0.95 and gap < 3.0 \
			and (tactic == Tactic.WAIT or tactic == Tactic.CIRCLE) and not wolf.is_busy():
		_swing_at = -100.0
		_begin(Tactic.STRIKE)


static func _swing_serial(quarry: Node3D) -> int:
	var knight := quarry as Player
	if knight == null or knight.rig == null:
		return -1
	var serial: Variant = knight.rig.get("attack_serial")
	return int(serial) if serial != null else -1
#endregion
