class_name OrcFighter
extends PackBrute

## The orc (Polysplit's Biped Creatures, CREATURES_PACK.md): a falchion and
## a temper (the user's picks, 2026-10-07).
##
## * **The leap** ([PackBrute]): from off, it springs at him, falchion and
##   body, and comes down on him — down he goes.
## * **A boot through his shield.** He crouches behind his shield in front of
##   it (`kick_after` s of it): it kicks the shield aside (`CR_Kick`, a "guard"
##   blow: caught on the shield it beats his guard down, [method
##   Player._crumple]) and goes straight in after it with the falchion while
##   he is open.
## * **Rage** ([PackBrute]): cut to half its health it roars, glows red, comes
##   on quicker and hits harder, and the orcs about come at the roar.

@export_group("Kick")
@export var kick_clip: StringName = &"CR_Kick"
@export var kick_part: Vector3 = Vector3(1.25, 0.0, 0.9)
@export var kick_limbs: String = "R_knee_joint>R_toe_joint:0.14"
## How long he must hold his shield up in front of it before it kicks.
@export var kick_after: float = 0.35
@export var kick_cooldown: float = 3.0
@export var kick_share: float = 0.6

const KICK := 112

var _shield_for: float = 0.0
var _kick_wait: float = 0.0
## The falchion goes in straight after the kick, for this long more.
var _follow_up: float = 0.0


func _ready() -> void:
	super()
	_special(KICK, kick_clip, kick_part)
	# Not a blow that fells him by itself.
	_special_strike(KICK, kick_limbs, kick_share, 3)
	_kinds[KICK] = &"guard"


func _own_move(delta: float) -> bool:
	_kick_wait = maxf(_kick_wait - delta, 0.0)
	if _shielded(_quarry):
		_shield_for += delta
	else:
		_shield_for = 0.0
	var gap := _distance_to(_quarry)
	if _shield_for >= kick_after and _kick_wait <= 0.0 and gap <= reach + 0.3 and stamina >= attack_cost:
		mode = Mode.FIGHT
		_face(_quarry.global_position - global_position, 1.0, 50.0)
		_begin(KICK)
		return true
	_follow_up = maxf(_follow_up - delta, 0.0)
	if _follow_up > 0.0 and gap <= reach + 1.2 and _cooldown <= 0.0:
		# In after it at once, before he has his guard back.
		mode = Mode.FIGHT
		_face(_quarry.global_position - global_position, 1.0, 50.0)
		_begin_attack()
		if act != Act.NONE:
			_follow_up = 0.0
		return true
	return super(delta)


## His shield up, and facing it.
func _shielded(who: Node3D) -> bool:
	if who == null or not (bool(who.get("net_blocking")) or bool(who.get("is_blocking"))):
		return false
	var his := -who.global_transform.basis.z
	his.y = 0.0
	var to_me := global_position - who.global_position
	to_me.y = 0.0
	return his.normalized().dot(to_me.normalized()) > 0.3


func _after(what: int) -> void:
	if what == KICK:
		_kick_wait = kick_cooldown * (0.6 if raging else 1.0)
		_shield_for = 0.0
		_follow_up = 1.6
	super(what)
	if what == KICK:
		_cooldown = 0.0
