class_name MageSkills
extends Node

## The elf's and the dark elf's skills (the plan: `claude/mage_polish_plan.md`).
##
## * **Frost Spears** (the elf, the user's word 2026-10-06): she raises her
##   hand to the sky (Kevin's Call, its load) and ten spears of ice grow out of
##   the air one after another, five over her left shoulder and five over her
##   right, scattered high round her head, each turned on what she will throw
##   them at. They go where she goes. Once all are there, and as soon as there
##   is something to throw at — what she has locked, else the nearest foe
##   ahead of her (`SEEK`) — she brings her hand down and forward and they go,
##   from one side and then the other, in a rhythm: two at once, then three
##   one by one, then the last five quicker (`VOLLEY`). If it falls they go on
##   at the next. With nothing to throw at for `HOLD_MAX` they break.
##   She is not held while they hang or fly: her own bolts go on as ever.
##
## Hangs under the [Player] as "MageSkills" ([method Player.mage]). The
## spears are grown and thrown on every peer from the Player's own messages
## (`net_frost_spears`, `net_frost_spear`, `net_frost_end`); which goes when
## and at what is decided by her own peer, and only the host's copies hurt.

const SPEARS := 10
## One more every `FORM_EVERY`, each grown in `FORM_GROW`, left and right in
## turn.
const FORM_EVERY := 0.09
const FORM_GROW := 0.22
## Where they hang (her frame, -Z ahead): to her side `SIDE_FROM`..`SIDE_TO`,
## `HIGH_FROM`..`HIGH_TO` over her feet, `BACK_FROM`..`BACK_TO` behind her;
## each spear's own place in that is fixed by its number (every peer the same).
const SIDE_FROM := 0.75
const SIDE_TO := 2.1
const HIGH_FROM := 2.3
const HIGH_TO := 3.4
const BACK_FROM := -0.2
const BACK_TO := 0.9
## When each goes, from the first (seconds): two at once, three one by one,
## the last five quicker. Even numbers hang on her left, odd on her right, and
## they go in that order, so each comes from the other side.
const VOLLEY: Array[float] = [0.0, 0.14, 0.75, 1.15, 1.55, 2.15, 2.4, 2.65, 2.9, 3.15]
## From her hand coming down to the first going.
const GO_LEAD := 0.3
const SEEK := 28.0
const SPEED := 22.0
## Each spear's worth, as a share of a full bolt's (before the full charge's
## bonus): ten of them are worth some three and a half bolts.
const SHARE := 0.35
## How long the spears wait for something to throw at.
const HOLD_MAX := 6.0
## The hand raised to the sky as they grow (Kevin's Call, its load), and
## brought down and forward as they go (Mixamo's Heal, its rise, quick).
const RAISE_CLIP := &"KV_MagicAttackCall1H01_L_Load"
const RAISE_RATE := 1.0
const GO_CLIP := &"MG_Heal"
const GO_PART := Vector2(0.0, 0.45)
const GO_RATE := 1.8

var hero: Player
## The crescent (every peer): a node in the world that follows her, and the
## spears on it (null once thrown).
var _crown: Node3D
var _spears: Array = []
var _born: float = 0.0
## Her own peer: how many are thrown, when the next may go, since when they
## have been ready.
var _thrown: int = 0
var _next_at: float = 0.0
var _clock: float = 0.0
## Her own peer: when the volley began (-1 not yet).
var _go_at: float = -1.0


func _ready() -> void:
	hero = get_parent() as Player
	if hero != null:
		hero.died.connect(func() -> void: _break_all())


## Whether the spears are up (grown or growing, not all thrown).
func spears_up() -> bool:
	return _crown != null and is_instance_valid(_crown)


## Her own peer: the skill. False if the spears are already up.
func frost_spears(cost: float) -> bool:
	if hero == null or spears_up():
		return false
	if not hero._spend(cost):
		return false
	hero.net_frost_spears.rpc()
	_thrown = 0
	_go_at = -1.0
	_next_at = SPEARS * FORM_EVERY + FORM_GROW
	return true


## Every peer: the hand raised and the spears grown.
func grow_spears() -> void:
	_break_all()
	if hero == null:
		return
	if hero.rig != null and hero.rig.has_method(&"play_part"):
		hero.rig.call(&"play_part", RAISE_CLIP, RAISE_RATE, 0.0, 1.0, 0.15)
	var into := Blood.world_of(hero)
	if into == null:
		return
	_crown = Node3D.new()
	_crown.name = "FrostSpears"
	into.add_child(_crown)
	_crown.global_transform = _crown_at()
	_spears.clear()
	_clock = 0.0
	_born = 0.0
	for i in SPEARS:
		var spear := IceShard.spike(IceShard.LENGTH, IceShard.RADIUS, 1.2)
		spear.visible = false
		spear.scale = Vector3.ONE * 0.01
		_crown.add_child(spear)
		spear.position = _slot(i)
		_spears.append(spear)


## Every peer: her hand down and forward, the volley about to go.
func send_spears() -> void:
	if hero != null and hero.rig != null and hero.rig.has_method(&"play_part"):
		hero.rig.call(&"play_part", GO_CLIP, GO_RATE, GO_PART.x, GO_PART.y, 0.1)


## Every peer: spear `i` goes, from `from` at `flight`.
func throw_spear(i: int, from: Vector3, flight: Vector3, damage: float, critical: bool, quarry: Node3D) -> void:
	if i >= 0 and i < _spears.size() and _spears[i] != null and is_instance_valid(_spears[i]):
		(_spears[i] as Node3D).queue_free()
		_spears[i] = null
	var into := Blood.world_of(hero)
	if into == null:
		return
	var shard := IceShard.new()
	into.add_child(shard)
	shard.global_position = from
	shard.launch(flight, damage, critical, 0.0, hero)
	if quarry != null:
		shard.hunt(quarry)
	SkillFx.flash(into, from, IceShard.ICE_HOT, 0.12, 0.08, 1.5)
	var left := false
	for s: Variant in _spears:
		left = left or (s != null and is_instance_valid(s))
	if not left:
		_end_crown()


## Every peer: whatever spears are left break into frost.
func break_spears() -> void:
	_break_all()


func _break_all() -> void:
	if _crown == null or not is_instance_valid(_crown):
		_crown = null
		return
	var into := _crown.get_parent()
	for s: Variant in _spears:
		if s != null and is_instance_valid(s):
			var at := (s as Node3D).global_position
			SkillFx.particles(into, at, {"amount": 6, "one_shot": true, "explosiveness": 1.0, "life": 0.6,
					"speed": Vector2(0.5, 2.0), "spread": 180.0, "gravity": Vector3(0, -8, 0),
					"size": Vector2(0.03, 0.07), "colors": [Color(IceShard.ICE_HOT, 1.0), Color(IceShard.ICE, 0.0)]})
	_end_crown()


func _end_crown() -> void:
	if _crown != null and is_instance_valid(_crown):
		_crown.queue_free()
	_crown = null
	_spears.clear()


## Where she is, turned the way she faces: the crescent's frame.
func _crown_at() -> Transform3D:
	var yaw := hero.global_rotation.y
	return Transform3D(Basis(Vector3.UP, yaw), hero.global_position)


## Spear `i`'s place over her shoulder, in the crown's frame (-Z ahead of
## her): even on her left, odd on her right, scattered by its number.
func _slot(i: int) -> Vector3:
	var side := -1.0 if i % 2 == 0 else 1.0
	var k := floori(i / 2.0)
	var a := fposmod(sin(float(i) * 12.9898 + 1.7) * 43758.5453, 1.0)
	var b := fposmod(sin(float(i) * 78.233 + 4.1) * 24634.6345, 1.0)
	var c := fposmod(sin(float(i) * 39.425 + 2.9) * 11251.2291, 1.0)
	# fanned out by its place in the five, then shaken a little
	var across := lerpf(SIDE_FROM, SIDE_TO, (float(k) + a * 0.8) / 5.0)
	var up := lerpf(HIGH_FROM, HIGH_TO, fposmod(float(k) * 0.41 + b * 0.5, 1.0))
	var back := lerpf(BACK_FROM, BACK_TO, c)
	return Vector3(side * across, up, back)


func _process(delta: float) -> void:
	if not spears_up() or hero == null:
		return
	_clock += delta
	# the crown goes with her, and turns with her a little behind
	var want := _crown_at()
	_crown.global_position = want.origin
	_crown.global_basis = _crown.global_basis.slerp(want.basis, clampf(delta * 8.0, 0.0, 1.0))
	var foe := _foe()
	var aim := _aim_at(foe)
	for i in _spears.size():
		var s: Variant = _spears[i]
		if s == null or not is_instance_valid(s):
			continue
		var spear := s as Node3D
		var start := FORM_EVERY * i
		var grown := clampf((_clock - start) / FORM_GROW, 0.0, 1.0)
		if grown <= 0.0:
			continue
		if not spear.visible:
			spear.visible = true
			SkillFx.burst(_crown.get_parent(), spear.global_position, IceShard.ICE_HOT, 8, Vector2(0.3, 1.2),
					Vector3.UP, 180.0, Vector2(0.02, 0.05), Vector3(0, -2, 0), 0.4)
		var size := 1.0 - pow(1.0 - grown, 3.0)
		# hangs there, breathing a little, its point on what she will throw it at
		var bob := sin(_clock * 3.0 + float(i) * 0.7) * 0.04
		spear.position = _slot(i) + Vector3(0.0, bob, 0.0)
		var to := aim - spear.global_position
		if to.length_squared() > 0.01:
			var point := to.normalized()
			var side := point.cross(Vector3.UP)
			if side.length_squared() < 1e-4:
				side = point.cross(Vector3.RIGHT)
			side = side.normalized()
			var b := Basis(side, point, side.cross(point)).orthonormalized()
			var now := spear.global_basis.orthonormalized()
			spear.global_basis = now.slerp(b, clampf(delta * 10.0, 0.0, 1.0))
		spear.scale = Vector3.ONE * maxf(size, 0.01)
	if hero.is_multiplayer_authority():
		_decide(foe, aim)


## Her own peer: throws the next spear when it is time and there is something
## to throw at; breaks them when there has been nothing for too long.
func _decide(foe: Node3D, aim: Vector3) -> void:
	if hero.is_dead:
		hero.net_frost_end.rpc()
		return
	if _clock < _next_at:
		return
	if _go_at < 0.0:
		if foe == null:
			if _clock > SPEARS * FORM_EVERY + FORM_GROW + HOLD_MAX:
				hero.net_frost_end.rpc()
			return
		# her hand comes down and forward; the first goes a beat after
		hero.net_frost_go.rpc()
		_go_at = _clock + GO_LEAD
		_next_at = _go_at
		return
	if foe == null:
		# what it was at has fallen and nothing else is near: they wait
		if _clock > _go_at + HOLD_MAX:
			hero.net_frost_end.rpc()
		return
	var i := _thrown
	while i < _spears.size() and (_spears[i] == null or not is_instance_valid(_spears[i])):
		i += 1
	if i >= _spears.size():
		return
	var spear := _spears[i] as Node3D
	var from := spear.global_position
	var flight := (aim - from).normalized() * SPEED
	var profile := hero.profile
	var critical := randf() < (profile.crit_chance if profile != null else 0.1)
	var damage := (profile.shot_power() if profile != null else 40.0) * BowKinds.atk(hero) * SHARE
	if critical and profile != null:
		damage *= profile.crit_damage
	hero.net_frost_spear.rpc(i, from, flight, damage, critical, foe.get_path())
	_thrown = i + 1
	if _thrown < VOLLEY.size():
		_next_at = _go_at + VOLLEY[_thrown]


## What the spears go at: her lock, else the nearest foe ahead within `SEEK`.
func _foe() -> Node3D:
	if hero.target != null and hero._targetable(hero.target):
		return hero.target
	return hero._charge_target(SEEK)


## Where they point: the middle of it, or far ahead of her with nothing.
func _aim_at(foe: Node3D) -> Vector3:
	if foe != null:
		return hero._aim_point(foe)
	var ahead := -hero.global_basis.z
	ahead.y = 0.0
	return hero.global_position + Vector3.UP * 1.2 + ahead.normalized() * 20.0
