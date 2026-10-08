class_name PackBrute
extends Brawler

## What the big ones of Polysplit's pack have in common (CREATURES_PACK.md;
## the user's picks, 2026-10-07): the orc, the ogre, the troll and the golem
## ([OrcFighter], [OgreFighter], [TrollFighter], [GolemFighter]) each take
## some of it.
##
## * **Rage** (`rage_at`): cut under that share of its health it stops and
##   roars (`rage_clip`), and from then on is quicker on its feet and in its
##   swings (`rage_pace`), hardly a breath between them, and hits harder
##   (`rage_harder`); a red glow on it. Its kin within `rage_call` come.
## * **The leap** (`leap_clip`): from `leap_from` to `leap_to` off, now and
##   then (`leap_cooldown`), it springs at him and comes down on him — a blow
##   that throws him down — sized to the gap. With `leap_quake` it shakes the
##   ground where it lands too ([method _quake]).
## * **The quake** ([method _quake]): a shock along the ground out from a
##   slam ([QuakeRing]); whoever is on the ground when it passes under him is
##   thrown down. A jump clears it, a roll too; no shield takes it.
## * **A slow blow** (`_windups`): a move whose wind-up is drawn out, so he
##   sees it coming, its weapon glowing hotter as it rises.
## * **Kinds of blow** (`_kinds`, [method ClipFighter._blow_kind]): "guard"
##   a kick through the shield, "crush" a blow no shield holds, "ground",
##   "stomp".
## * **Stance** (`stance`; the user's word, 2026-10-08: Elden Ring's, not a
##   hit-stop): blows do not stop it nor push it about (`bite_hold`,
##   `shove_share`, `flinch_share`), but each fills a hidden stance, a heavy
##   blow far more than a light cut; full, it goes down on a knee
##   (`stance_clip`), open, and the first blow on it then is a critical
##   (`stance_crit`). Left alone `stance_rest` s, it is whole again.
## * **A delayed blow** (`_holds`): now and then a swing held at the top of
##   its wind-up a moment before it comes down (Elden Ring's delayed swings).

@export_group("Rage")
## 0: it does not rage.
@export_range(0.0, 1.0) var rage_at: float = 0.0
@export var rage_clip: StringName = &"CR_Transform"
@export var rage_part: Vector3 = Vector3(1.15, 0.0, 0.85)
@export var rage_pace: float = 1.22
@export var rage_harder: float = 1.25
@export var rage_glow: Color = Color(1.0, 0.16, 0.05)
## Its own kind within this far are roused by the roar.
@export var rage_call: float = 0.0

@export_group("Leap")
## Empty: it does not leap.
@export var leap_clip: StringName = &""
## [rate, from, to] of the leap clip, and the share of the clip it lands at.
@export var leap_part: Vector3 = Vector3(1.15, 0.1, 0.62)
@export var leap_land: float = 0.44
@export var leap_from: float = 4.5
@export var leap_to: float = 10.0
@export var leap_cooldown: float = 7.0
## What lands (as `attack_limbs`).
@export var leap_limbs: String = "pelvis_joint>head_joint:0.34"
## Share of `hit_damage`.
@export var leap_share: float = 1.2
## How far short of him it means to come down.
@export var leap_short: float = 0.25
## A quake where it lands, this wide (0: none), worth this share.
@export var leap_quake: float = 0.0
@export var leap_quake_share: float = 0.7

@export_group("Stance")
## What its hidden stance takes before it breaks (0: it has none). A blow
## fills it by its damage (before defence) times the hero's swing weight
## twice over (a light cut 1, a heavy blow 1.5 and more: 2.25+); a shot 0.5,
## a spell 0.75 of its damage.
@export var stance: float = 0.0
## Seconds with nothing landing before its stance is whole again.
@export var stance_rest: float = 10.0
## How long it stays down on its knee, open.
@export var stance_down: float = 2.6
## The first blow on it while it is down: this many times as hard.
@export var stance_crit: float = 3.0
## Going down on its knee: the clip, [rate, -, the share of it it kneels at].
## It comes back up the same way, slower.
@export var stance_clip: StringName = &"CR_LayDown"
@export var stance_part: Vector3 = Vector3(1.2, 0.0, 0.38)
## The share of a hero's hit-stop that holds it ([HitFeel]: 1 every bite,
## 0 none — a blade does not stop a big one's swing), and of the shove and the
## bend a blow gives it.
@export_range(0.0, 1.0) var bite_hold: float = 1.0
@export_range(0.0, 1.0) var shove_share: float = 1.0
@export_range(0.0, 1.0) var flinch_share: float = 1.0
## Heard as the critical goes in (empty: the thud only).
@export_file("*.wav", "*.ogg") var crit_sound: String = ""

const RAGE := 110
const LEAP := 111
const STANCE := 119

## Replicated by [method net_rage].
var raging: bool = false
## act -> the kind of blow it lands ([method ClipFighter._blow_kind]).
var _kinds: Dictionary = {}
## act -> [how many times slower its wind-up is played, seconds before its
## blow the wind-up ends] ([method _clip_time]).
var _windups: Dictionary = {}
var _leap_wait: float = 2.0
var _leap_speed: float = 0.0
var _glow: StandardMaterial3D
var _glow_light: OmniLight3D
## Host: how many quakes it has made, and those running out ([method _quake]).
var quakes_made: int = 0
var _quakes: Array[Dictionary] = []
var _in_lin: bool = false
## Every peer: the serial and clock of the move it shows, for the looks of a
## slow blow.
var _shown_serial: int = -1
var _shown_clock: float = 0.0
var _charge: OmniLight3D
var _ember: MeshInstance3D
var _ember_mat: StandardMaterial3D
## act -> [chance, shortest, longest, seconds before the blow it holds at]: a
## delayed swing ([method _hold_of]).
var _holds: Dictionary = {}
## Host: the stance it has taken, how long since a blow last landed, and
## whether the critical is still to come in this break.
var stance_taken: float = 0.0
var stance_breaks: int = 0
var crits_taken: int = 0
var _stance_quiet: float = 99.0
var _crit_open: bool = false
var _by_blade: bool = false
## Every peer: the clock of the stance break shown (its clip set by hand).
var _stance_clock: float = 0.0
var _stance_serial: int = -1


func _ready() -> void:
	super()
	if not rage_clip.is_empty():
		_moves_table[RAGE] = [rage_clip, rage_part.x, rage_part.y, rage_part.z]
	if not leap_clip.is_empty():
		_moves_table[LEAP] = [leap_clip, leap_part.x, leap_part.y, leap_part.z]
		_own_limb(LEAP, leap_limbs)
		var s: Array = _strikes_table[LEAP]
		# One blow that throws him down, at the landing.
		_strikes_table[LEAP] = [s[0], s[1], leap_share, 1, 0.6, PackedFloat32Array([leap_land])]
	_leap_wait = _rng.randf_range(1.0, leap_cooldown * 0.5)
	if stance > 0.0:
		_moves_table[STANCE] = [stance_clip, stance_part.x, 0.0, stance_part.z]


## A move of its own beyond its attacks: [clip, rate, from, to].
func _special(what: int, clip: StringName, part: Vector3) -> void:
	_moves_table[what] = [clip, part.x, part.y, part.z]


## A move of its own that lands blows: its striking ends (as `attack_limbs`),
## its worth (share of `hit_damage`) and how many of its blows fell him.
func _special_strike(what: int, limbs: String, share: float, fells: int = 1) -> void:
	if limbs.is_empty():
		var bones := strike_bones if not strike_bones.is_empty() else PackedStringArray([String(weapon_bone)])
		_strikes_table[what] = [bones, ["weapon"], share, fells]
	else:
		_own_limb(what, limbs)
		var s: Array = _strikes_table[what]
		_strikes_table[what] = [s[0], s[1], share, fells]
	if strike_at_reach:
		_moment_at_reach(what)


func _leaps() -> Array:
	return [LEAP]


#region Thinking
## Host. Before anything else: the rage, if it is due. Then a leap, if he is
## at the right gap.
func _think(delta: float) -> void:
	_leap_wait = maxf(_leap_wait - delta, 0.0)
	if is_dead or act != Act.NONE or mode == Mode.GUARD or mode == Mode.RETURN:
		super(delta)
		return
	if rage_at > 0.0 and not raging and _moves_table.has(RAGE) and health <= max_health * rage_at:
		velocity.x = 0.0
		velocity.z = 0.0
		_begin(RAGE)
		return
	_quarry = _pick_quarry()
	if _quarry == null:
		super(delta)
		return
	if _own_move(delta):
		return
	super(delta)


## A kind's own choice of move, before the Brawler's (true if it took one).
func _own_move(_delta: float) -> bool:
	return _try_leap()


func _try_leap() -> bool:
	if not _moves_table.has(LEAP) or _leap_wait > 0.0 or _quarry_down() or stamina < attack_cost:
		return false
	var gap := _distance_to(_quarry)
	if gap < leap_from or gap > leap_to:
		return false
	mode = Mode.FIGHT
	_face(_quarry.global_position - global_position, 1.0, 50.0)
	_begin(LEAP)
	var until := _blow_moments(LEAP)[0]
	_leap_speed = maxf(gap - leap_short - 0.4 * visual_scale, 0.0) / maxf(until, 0.2)
	return true


func _extra_velocity(delta: float) -> Vector3:
	if act == LEAP:
		if _act_time <= _blow_moments(LEAP)[0]:
			return _forward() * _leap_speed
		return Vector3.ZERO
	if act == RAGE:
		return Vector3.ZERO
	return super(delta)


func _after(what: int) -> void:
	if what == STANCE:
		_crit_open = false
		stance_taken = 0.0
		_stance_quiet = 99.0
	if what == LEAP:
		_leap_wait = leap_cooldown * (0.6 if raging else 1.0)
	if what == RAGE and not raging:
		_send_rage()
	super(what)


func _run_act(delta: float) -> void:
	var was := act
	var t0 := _act_time - delta
	super(delta)
	if is_dead or not _decides():
		return
	# Down on him out of the leap: the ground shakes where it lands.
	if was == LEAP and act == LEAP and leap_quake > 0.0:
		var land := _blow_moments(LEAP)[0]
		if t0 < land and _act_time >= land:
			_quake(global_position + _forward() * 0.6 * visual_scale, leap_quake, hit_damage * leap_quake_share)
#endregion


#region Blows
func _blow_kind(what: int) -> StringName:
	return _kinds.get(what, &"")


func _blow_worth(_what: int) -> float:
	return rage_harder if raging else 1.0
#endregion


#region The quake
## Host: a shock out along the ground from `at`, `radius` wide, worth `worth`
## to whoever is on the ground as it passes under him.
func _quake(at: Vector3, radius: float, worth: float) -> void:
	quakes_made += 1
	_quakes.append({"at": at, "t": 0.0, "r": radius, "worth": worth * _blow_worth(0),
			"id": act_serial * 1000 + 90 + _quakes.size(), "caught": {}})
	if is_inside_tree() and multiplayer.has_multiplayer_peer():
		net_quake.rpc(at, radius)
	else:
		net_quake(at, radius)


@rpc("authority", "call_local", "reliable")
func net_quake(at: Vector3, radius: float) -> void:
	QuakeRing.spawn(Blood.world_of(self), at, radius)


func _physics_process(delta: float) -> void:
	super(delta)
	if stance > 0.0 and _decides():
		_stance_quiet += delta
		if _stance_quiet > stance_rest:
			stance_taken = 0.0
	if _quakes.is_empty() or not _decides():
		return
	for i in range(_quakes.size() - 1, -1, -1):
		var q := _quakes[i]
		q.t = float(q.t) + delta
		var front := QuakeRing.front(q.t)
		var caught: Dictionary = q.caught
		for node in get_tree().get_nodes_in_group(&"player"):
			var who := node as Node3D
			if who == null or caught.has(who) or not who.has_method(&"receive_blow") or bool(who.get("is_dead")):
				continue
			var rel := who.global_position - (q.at as Vector3)
			if absf(rel.y) > 2.5:
				continue
			var d := Vector2(rel.x, rel.z).length()
			if d > float(q.r) + 0.4 or d > front:
				continue
			caught[who] = true
			# The ground jumping under him puts him down — if he is on it.
			who.call(&"receive_blow", float(q.worth) * lerpf(1.0, 0.6, d / maxf(float(q.r), 0.1)), self, 0, 1,
					int(q.id), false, &"ground")
		if front > float(q.r) + 1.0:
			_quakes.remove_at(i)
#endregion


#region A slow blow, a delayed one
## Act seconds of the move at its own pace up to `lead` s before its first
## blow (where a slow wind-up ends, or a delayed swing is held).
func _windup_end(what: int, lead: float = -1.0) -> float:
	if _in_lin:
		return 0.0
	_in_lin = true
	var ms := super._blow_moments(what)
	_in_lin = false
	if lead < 0.0:
		lead = float((_windups[what] as Array)[1]) if _windups.has(what) else 0.15
	return maxf(ms[0] - lead, 0.0) if not ms.is_empty() else 0.0


## How long this swing is held at the top of its wind-up (0: not this time).
## Picked from the swing's serial, so every peer holds it alike.
func _hold_of(what: int) -> float:
	if what != act or not _holds.has(what):
		return 0.0
	var h: Array = _holds[what]
	var r := fposmod(sin(float(act_serial) * 12.9898 + float(what) * 78.233) * 43758.5453, 1.0)
	if r >= float(h[0]):
		return 0.0
	return lerpf(float(h[1]), float(h[2]), fposmod(r * 9.137, 1.0))


## [where the wind-up ends at its own pace, how much slower it is played up to
## there, how long it is held there] for a move, or [] if it is played plain.
func _shape(what: int) -> Array:
	if _in_lin:
		return []
	var slow := float((_windups[what] as Array)[0]) if _windups.has(what) else 1.0
	var hold := _hold_of(what)
	if slow == 1.0 and hold <= 0.0:
		return []
	var lead := float((_holds[what] as Array)[3]) if hold > 0.0 else -1.0
	return [_windup_end(what, lead), slow, hold]


func _clip_time(what: int, t: float) -> float:
	if what == STANCE and _moves_table.has(STANCE):
		return _stance_clip_time(t)
	var sh := _shape(what)
	if not sh.is_empty():
		var k := float(sh[0])
		var slow := float(sh[1])
		var hold := float(sh[2])
		if t < k * slow:
			t = t / slow
		elif t < k * slow + hold:
			t = k
		else:
			t = t - k * (slow - 1.0) - hold
	return super(what, t)


func _move_length(what: int) -> float:
	if what == STANCE and _moves_table.has(STANCE):
		return _stance_spans().x + _stance_spans().y + _stance_spans().z
	var length := super(what)
	var sh := _shape(what)
	if not sh.is_empty():
		length += float(sh[0]) * (float(sh[1]) - 1.0) + float(sh[2])
	return length


func _blow_moments(what: int) -> PackedFloat32Array:
	var ms := super(what)
	var sh := _shape(what)
	if sh.is_empty():
		return ms
	var k := float(sh[0])
	var slow := float(sh[1])
	var hold := float(sh[2])
	var out := PackedFloat32Array()
	for m in ms:
		out.append(m * slow if m <= k else m + k * (slow - 1.0) + hold)
	return out


## Every peer: the weapon glowing hotter through a slow blow's wind-up.
func _show_windup(delta: float) -> void:
	if act_serial != _shown_serial:
		_shown_serial = act_serial
		_shown_clock = 0.0
	else:
		_shown_clock += delta
	var winding := _windups.has(act) and not is_dead
	if not winding:
		if _charge != null:
			_charge.light_energy = move_toward(_charge.light_energy, 0.0, 12.0 * delta)
			_ember.visible = false
		return
	var w: Array = _windups[act]
	var until := _windup_end(act) * float(w[0])
	var share := clampf(_shown_clock / maxf(until, 0.05), 0.0, 1.0)
	var tip := _weapon_tip_at()
	if _charge == null:
		_charge = OmniLight3D.new()
		_charge.light_color = Color(1.0, 0.45, 0.12)
		_charge.omni_range = 2.6 * visual_scale
		_charge.shadow_enabled = false
		_charge.top_level = true
		add_child(_charge)
	_charge.global_position = tip
	_charge.light_energy = 0.4 + 3.2 * share * share if share < 1.0 else move_toward(_charge.light_energy, 0.0, 10.0 * delta)
	# A coal at the weapon's end, swelling and brightening as it rises.
	if _ember == null:
		_ember = MeshInstance3D.new()
		var ball := SphereMesh.new()
		ball.radius = 1.0
		ball.height = 2.0
		ball.radial_segments = 12
		ball.rings = 6
		_ember.mesh = ball
		_ember_mat = SkillFx.glow(Color(1.0, 0.5, 0.15), 3.0)
		_ember.material_override = _ember_mat
		_ember.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_ember.top_level = true
		add_child(_ember)
	_ember.visible = share < 1.0
	_ember.global_position = tip
	var flick := 0.85 + 0.15 * sin(Time.get_ticks_msec() / 1000.0 * 30.0)
	_ember.scale = Vector3.ONE * (0.08 + 0.22 * share) * visual_scale * flick
	_ember_mat.albedo_color.a = 0.35 + 0.6 * share
	if share < 1.0 and randf() < delta * 22.0 * (0.3 + share):
		SkillFx.burst(Blood.world_of(self), tip, Color(1.0, 0.55, 0.15), 3, Vector2(0.5, 1.5), Vector3.UP, 70.0,
				Vector2(0.02, 0.04), Vector3(0, 1.5, 0), 0.4)


## Where its weapon's end is now (its right fist where it has none).
func _weapon_tip_at() -> Vector3:
	if _skeleton != null and _weapon >= 0:
		return _skeleton.global_transform * (_skeleton.get_bone_global_pose(_weapon) * weapon_tip)
	return global_position + Vector3.UP * 1.5 * visual_scale


func _process(delta: float) -> void:
	super(delta)
	_show_stance(delta)
	if not _windups.is_empty():
		_show_windup(delta)
	if _glow != null:
		var beat := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * 6.0)
		_glow.albedo_color.a = 0.0 if is_dead else 0.1 + 0.12 * beat
		if _glow_light != null:
			_glow_light.light_energy = 0.0 if is_dead else 0.5 + 0.6 * beat
#endregion


#region Rage
func _send_rage() -> void:
	if is_inside_tree() and multiplayer.has_multiplayer_peer():
		net_rage.rpc()
	else:
		net_rage()
	if rage_call > 0.0 and _quarry != null:
		for node in get_tree().get_nodes_in_group(&"enemy"):
			var f := node as Fighter
			if f == null or f == self or f.is_dead or f.scene_file_path != scene_file_path:
				continue
			if f.global_position.distance_to(global_position) <= rage_call:
				f._rouse(_quarry)


## Every peer: enraged from now on.
@rpc("authority", "call_local", "reliable")
func net_rage() -> void:
	if raging:
		return
	raging = true
	speed *= rage_pace
	chase_speed *= rage_pace
	close_speed *= rage_pace
	attack_cooldown *= 0.4
	stamina_regen *= 1.6
	for what: int in _moves_table:
		if what != RAGE and what != ROAR and what != PIECES and what != REFORM:
			var m: Array = (_moves_table[what] as Array).duplicate()
			m[1] = float(m[1]) * rage_pace
			_moves_table[what] = m
	_glow_on()


func _glow_on() -> void:
	if body == null:
		return
	_glow = StandardMaterial3D.new()
	_glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_glow.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_glow.albedo_color = Color(rage_glow, 0.2)
	for mi: MeshInstance3D in body.find_children("*", "MeshInstance3D", true, false):
		mi.material_overlay = _glow
	_glow_light = OmniLight3D.new()
	_glow_light.light_color = rage_glow
	_glow_light.light_energy = 0.9
	_glow_light.omni_range = 2.4 * visual_scale
	_glow_light.shadow_enabled = false
	add_child(_glow_light)
	_glow_light.position = Vector3.UP * 1.3 * visual_scale
	# No rings at its feet (the user's word, 2026-10-08): red embers and hot
	# breath going up off it, and the roar shakes the view.
	var into := Blood.world_of(self)
	SkillFx.particles(into, global_position + Vector3.UP * 1.1 * visual_scale, {
		"amount": 46, "life": 1.3, "one_shot": true, "explosiveness": 0.85,
		"speed": Vector2(0.6, 2.2), "dir": Vector3.UP, "spread": 55.0, "gravity": Vector3(0, 1.2, 0),
		"damping": 1.2, "size": Vector2(0.03, 0.07), "box": Vector3(0.45, 0.8, 0.45) * visual_scale,
		"colors": [Color(1.0, 0.8, 0.5, 1.0), rage_glow, Color(rage_glow.r, rage_glow.g, rage_glow.b, 0.0)],
	})
	SkillFx.particles(into, global_position + Vector3.UP * 1.75 * visual_scale, {
		"amount": 14, "life": 1.6, "one_shot": true, "explosiveness": 0.7, "add": false,
		"speed": Vector2(0.4, 1.1), "dir": Vector3.UP, "spread": 35.0, "gravity": Vector3(0, 0.6, 0),
		"damping": 0.8, "size": Vector2(0.35, 0.7), "sphere": 0.25 * visual_scale, "grow": 0.3,
		"colors": [Color(0.55, 0.5, 0.48, 0.0), Color(0.5, 0.45, 0.42, 0.28), Color(0.45, 0.42, 0.4, 0.0)],
	})
	for node in get_tree().get_nodes_in_group(&"player"):
		var hero := node as Player
		if hero != null and hero.is_multiplayer_authority() and hero.global_position.distance_to(global_position) < 14.0:
			var cam := hero.get_viewport().get_camera_3d()
			if cam != null:
				ImpactFx.knock(cam, Vector3.DOWN, 0.06, 0.12, 0.6)


## Enraged, a blow no longer throws it about; one with a stance is not thrown
## about at all, the knock goes to its stance.
func react(kind: StringName, from: Node3D = null, push: Vector3 = Vector3.ZERO) -> void:
	if stance > 0.0 and kind == &"knock" and act != STANCE:
		if is_dead or not _decides():
			return
		if from != null and is_instance_valid(from):
			_rouse(from)
		_add_stance(stance * 0.3)
		return
	if raging and kind == &"knock":
		if from != null and is_instance_valid(from) and _decides():
			_rouse(from)
		return
	super(kind, from, push)
#endregion


#region Stance
## [going down, down, getting up] in act seconds.
func _stance_spans() -> Vector3:
	var len_down := 0.6
	if _anim != null:
		len_down = _anim.clip_length(stance_clip) * stance_part.z / maxf(stance_part.x, 0.01)
	return Vector3(len_down, stance_down, len_down * 1.4)


## The clip's own time through the break: down to the knee, held there (a
## breath of sway), and back up the same way, slower.
func _stance_clip_time(t: float) -> float:
	var sp := _stance_spans()
	var knee := _anim.clip_length(stance_clip) * stance_part.z if _anim != null else 0.0
	if t < sp.x:
		return t * stance_part.x
	if t < sp.x + sp.y:
		return knee - 0.06 * (0.5 + 0.5 * sin((t - sp.x) * 2.6))
	return maxf(knee - (t - sp.x - sp.y) * stance_part.x / 1.4, 0.0)


func receive_hit(hit: HitInfo) -> bool:
	_by_blade = hit.by_blade
	var bled := super(hit)
	_by_blade = false
	return bled


## How much of a blow's damage goes to its stance: a hero's swing by its
## weight (twice: the damage has it once already), a shot or a spell less.
func _stance_weight(from: Node3D, magic: bool) -> float:
	if not _by_blade or from == null:
		return 0.75 if magic else 0.5
	var w := 1.0
	var rig: Variant = from.get(&"rig")
	if rig is Object:
		var cw: Variant = (rig as Object).get(&"cut_weight")
		if cw is float:
			w = float(cw)
	return w * w


func _receive(damage: float, at: Vector3, blow: Vector3, from: Node3D, magic: bool = false) -> bool:
	var crit := false
	if act == STANCE and _crit_open and from != null and from.is_in_group(&"player"):
		damage *= stance_crit
		crit = true
	var was := velocity
	var bled := super(damage, at, blow, from, magic)
	if not bled or is_dead or act == PIECES:
		return bled
	if shove_share < 1.0:
		velocity.x = lerpf(was.x, velocity.x, shove_share)
		velocity.z = lerpf(was.z, velocity.z, shove_share)
	if crit:
		_crit_open = false
		crits_taken += 1
		_send_crit(at)
		# Struck down where it knelt: it gets up from there now.
		var sp := _stance_spans()
		_act_time = maxf(_act_time, sp.x + sp.y - 0.35)
	elif stance > 0.0 and act != STANCE:
		_add_stance(damage * _stance_weight(from, magic))
	return bled


## Host: stance taken; full, it breaks.
func _add_stance(amount: float) -> void:
	if stance <= 0.0 or is_dead or act == STANCE or act == PIECES or act == REFORM:
		return
	_stance_quiet = 0.0
	stance_taken += amount
	if stance_taken >= stance:
		_break_stance()


func _break_stance() -> void:
	stance_taken = 0.0
	stance_breaks += 1
	_crit_open = true
	_sweeps.clear()
	velocity.x = 0.0
	velocity.z = 0.0
	_begin(STANCE)
	if is_inside_tree() and multiplayer.has_multiplayer_peer():
		net_stance_broken.rpc()
	else:
		net_stance_broken()


## A parry counts towards its stance too.
func parried(by: Node3D) -> void:
	_add_stance(stance * 0.35)
	if act != STANCE:
		super(by)


## Every peer: it buckles — a heavy grunt of the ground taking its knee, dust
## kicked up off it (no ring), the view knocked for him close by.
@rpc("authority", "call_local", "reliable")
func net_stance_broken() -> void:
	var into := Blood.world_of(self)
	var knee := global_position + _forward() * 0.5 * visual_scale
	ImpactFx.thud(self, knee + Vector3.UP * 0.3, true)
	SkillFx.particles(into, knee + Vector3.UP * 0.15, {
		"amount": 22, "life": 0.9, "one_shot": true, "explosiveness": 0.9, "add": false,
		"speed": Vector2(0.8, 2.4), "dir": Vector3.UP, "spread": 70.0, "gravity": Vector3(0, -1.5, 0),
		"damping": 2.5, "size": Vector2(0.25, 0.55), "sphere": 0.4 * visual_scale, "grow": 0.25,
		"colors": [Color(0.62, 0.55, 0.45, 0.0), Color(0.6, 0.53, 0.44, 0.5), Color(0.58, 0.52, 0.44, 0.0)],
	})
	# Lit for a beat, white-gold: open now.
	HitFeel.flash(self, 0.5)
	WindBlast.shake(self, 0.08, 0.3, 14.0)


func _send_crit(at: Vector3) -> void:
	if is_inside_tree() and multiplayer.has_multiplayer_peer():
		net_crit.rpc(at)
	else:
		net_crit(at)


## Every peer: the critical on it down — a deep blow, blood and a burst of
## light where it went in, the view knocked hard.
@rpc("authority", "call_local", "reliable")
func net_crit(at: Vector3) -> void:
	var into := Blood.world_of(self)
	ImpactFx.thud(self, at, true)
	ImpactFx.strike(self, at, &"flesh", 2.2)
	if not crit_sound.is_empty():
		Sfx.play(self, crit_sound, null, at, 1.0, 1.0)
	SkillFx.burst(into, at, Color(1.0, 0.85, 0.55), 26, Vector2(2.0, 6.5), Vector3.UP, 120.0,
			Vector2(0.03, 0.07), Vector3(0, -7, 0), 0.45)
	HitFeel.flash(self, 0.8)
	for node in get_tree().get_nodes_in_group(&"player"):
		var hero := node as Player
		if hero != null and hero.is_multiplayer_authority() and hero.global_position.distance_to(global_position) < 10.0:
			var cam := hero.get_viewport().get_camera_3d()
			if cam != null:
				ImpactFx.knock(cam, (global_position - hero.global_position).normalized(), 0.09, 0.1, 0.4)


## Every peer: the break's clip kept where its clock is (down, held, back up:
## not a clip played straight through).
func _show_stance(delta: float) -> void:
	if act != STANCE or _anim == null or not _moves_table.has(STANCE):
		_stance_serial = -1
		return
	if act_serial != _stance_serial:
		_stance_serial = act_serial
		_stance_clock = 0.0
	else:
		_stance_clock += delta
	if _decides():
		return
	if _anim.current_clip() == stance_clip:
		_anim.seek(_stance_clip_time(_stance_clock))


## A blow bends it over only so far.
func _flinch_body(blow: Vector3) -> void:
	if flinch_share >= 1.0:
		super(blow)
		return
	_last_blow = blow
	if is_dead or body == null:
		return
	if _hit_react == null:
		_hit_react = HitReact.on_body(body)
	_hit_react.strike(blow, FLINCH_THROW * flinch_share)
#endregion
