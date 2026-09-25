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
## Its **combos** are made from what it has left:
##
## * both arms — *rake* (a swipe), *double rake* (left, right), *rake and leap*
##   (left, right, pounce), *feint* (a hop back and the pounce straight after);
## * one arm — a swipe, or a swipe and a bite;
## * no arms — the *bite*: a lunge with its jaws;
## * a leg gone — it is down on its belly, crawling at him, and its attack is
##   the *ground lunge*: it throws itself forward, claws and jaws together. It
##   cannot dodge or hop any more, and it does not stop coming.
##
## Hurt, it grows careful: it backs off more and dodges more — and comes back.

enum Tactic { CLOSE, STRIKE, CIRCLE, RETREAT, WAIT }

## At most this many wolves go at one player together; the rest of the pack
## circles and waits its turn (only wolves with the wit to).
const PACK_ATTACKERS := 2
## Who holds a turn at whom: quarry's instance id -> the wolves going in at him.
static var _turns: Dictionary = {}

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


func _init(owner: Wolf, wit: float) -> void:
	wolf = owner
	intellect = clampf(wit, 0.0, 1.0)
	_rng.randomize()
	_side = 1.0 if _rng.randf() < 0.5 else -1.0


#region What intellect buys
func reaction() -> float:
	return lerpf(0.42, 0.12, intellect)


func dodge_chance() -> float:
	return clampf(0.12 + 0.68 * intellect + 0.2 * _caution, 0.0, 0.92)


func combo_max() -> int:
	return 1 + int(round(2.0 * intellect))


func ring() -> float:
	return lerpf(2.2, 3.0, intellect)


func retreat_chance() -> float:
	return clampf(0.3 + 0.45 * intellect + 0.35 * _caution, 0.0, 0.9)
#endregion


## It was hurt: warier for a while, and a clever one gets out of reach at once.
func hurt() -> void:
	_caution = minf(_caution + 0.35, 1.0)
	if wolf.is_crippled() or wolf.is_busy():
		return
	if _rng.randf() < 0.35 + 0.5 * intellect:
		_begin(Tactic.RETREAT)


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
		wolf.face(towards, delta)
		return

	if tactic != Tactic.CLOSE and tactic != Tactic.STRIKE:
		_release()
	match tactic:
		Tactic.CLOSE:
			if not _take_turn(quarry):
				_begin(Tactic.CIRCLE)
			elif gap <= wolf.strike_range():
				_begin(Tactic.STRIKE)
			else:
				wolf.run_at(towards, delta)
		Tactic.STRIKE:
			wolf.face(towards, delta)
			wolf.hold(delta)
			if _combo.is_empty():
				_after_combo()
			elif _gap <= 0.0:
				var move: StringName = _combo.pop_front()
				if move != &"pounce" and move != &"hop" and move != &"claw_wave" and gap > wolf.strike_range() + 0.8:
					# He got away between blows: after him.
					_combo.push_front(move)
					_begin(Tactic.CLOSE)
				else:
					wolf.attack(move)
					_gap = lerpf(0.35, 0.08, intellect)
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
		Tactic.STRIKE:
			_combo = _choose_combo()
			_gap = 0.0
		Tactic.CIRCLE:
			_left = _rng.randf_range(0.7, 1.4 + 1.4 * intellect)
			if _rng.randf() < 0.3:
				_side = -_side
		Tactic.RETREAT:
			_left = 1.4
			# A clever one hops out of reach before backing further.
			if intellect > 0.35 and _rng.randf() < 0.3 + 0.5 * intellect and wolf.can_leap():
				wolf.attack(&"hop")
		Tactic.WAIT:
			_left = _rng.randf_range(0.3, 1.0) * lerpf(1.0, 0.6, intellect)


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
	var roll := _rng.randf()
	if most >= 3 and roll < 0.35:
		out.assign([&"swipe", &"swipe", &"pounce"])
	elif most >= 2 and intellect > 0.45 and roll < 0.55:
		out.assign([&"hop", &"pounce"])
	elif most >= 2 and roll < 0.85:
		out.assign([&"swipe", &"swipe"])
	else:
		out.append(&"swipe")
	return out


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
	if wolf.can_claw(gap) and _rng.randf() < 0.3 + 0.3 * intellect:
		tactic = Tactic.STRIKE
		_combo.assign([&"claw_wave"])
		_gap = 0.0
		return
	if gap > wolf.strike_range() + 0.6 and gap < wolf.pounce_range() and wolf.arms_left() == 2 \
			and _rng.randf() < 0.35 + 0.4 * intellect:
		tactic = Tactic.STRIKE
		_combo.assign([&"pounce"])
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
			if _rng.randf() < 0.4:
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
