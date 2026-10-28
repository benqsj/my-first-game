class_name GolemFighter
extends PackBrute

## The golem (Polysplit's Biped Creatures, CREATURES_PACK.md): stone, slow,
## and not to be put off (the user's picks, 2026-10-07).
##
## * **It does not reel.** A blow does not push it back or bend it over, nor
##   stop what it is doing. Only a heavy one (`poise_heavy` and more) or a
##   string of them close together (`poise`, worn away again at
##   `poise_mend` a second) staggers it: it reels (its hit clip), and is open.
## * **Stone out of the ground.** It strikes the ground (`CR_GroundPound`) and
##   a run of stone spikes comes up from it towards him, row after row
##   ([GroundFx] wave, slower than Arkdeva's): whoever it comes up under is
##   thrown down. No shield takes it; get out of its line.
## * **It comes back together.** Cut down the first time it falls to pieces
##   of stone and, after a while, the pieces gather back into it and it stands
##   again ([Brawler] `reform_chance`).
##
## **Its way of fighting** (2026-10-15, the user's word: the troll and the
## golem must fight each their own way, nothing alike) — a fortress that
## walks, everything the troll is not:
## * it never runs; the ground shakes under its steps near it;
## * few blows, slow and long seen coming (its fists glowing hotter,
##   [PackBrute] `_windups`), every one of them breaking the ground;
## * both fists down into the ground, a shoulder rammed into him, its arms
##   swept like a door, a leap that comes down as a quake;
## * stone walls up round him (`CR_MG_Raise`): its way of keeping him in;
## * its stone hardens under blows (cracks glowing, `harden_take` of each)
##   until its poise gives — then the shell bursts and it is open, taking
##   `open_take` more, for `open_for` s.
##
## **Round 2** (2026-10-15, the user's word: more of its own moves, never the
## same thing over and over, and now and then quick strings, so it is not
## easily killed):
## * three paces mixed: slow (fists glowing, both fists brought down like a
##   hammer, a leap that comes down on him), middling (sweeps and rams, now
##   and then held at the top — a delayed blow) and quick (arm swats, a chop,
##   a stamping kick, no wind-up);
## * quick strings ("rockslide": four blows ~0.45 s apart) and strings that
##   change pace under him (quick, quick, then the slow hammer);
## * pressed — `counter_hits` of his blows inside `counter_window` s — it
##   answers at once: a shove through his guard and two swats;
## * from off it rams him (a lunge, `CR_Polearm4`, sliding the gap) or leaps;
## * its shell bursting it stands dazed (`CR_Stun`), and as its stone closes
##   again it flexes it back on (`CR_PowerUp`, a glow);
## * its combos picked away from the last two it made.
##
## **Round 3** (2026-10-15, the user's list):
## * its leaps and its fists into the ground quick again (no long glow);
## * thorns, not rocks, where its fists come down, all round and far out
##   ([method GroundFx.spike_burst], `burst_radius`), hurting who stands in
##   them (`burst_share`); its kick runs a line of them out from its foot;
## * **its fist thrown** (`fist_from`–`fist_to` m): the fist flies off its arm
##   on a glowing tether, catches him ([Player] `grab_by`, a roll's untouchable
##   frames slip it), drags him back to it and the combo is on him at once;
## * **thorn field**: the ground under him glows, then bursts — three times,
##   following him;
## * more combos ("quarry", "landslide", "reel_in");
## * **its maul**: risen again after it fell to pieces, the stone of the
##   ground flies into its hand as a great maul and it fights with that —
##   its own two-handed strings (`_arm_maul`).
##
## **Round 4** (2026-10-26, the user's word: it must not fight as the troll
## does; its moves shown first in films, then put in as they were seen — the
## walls, the boulder, the thrown fist and the rest taken out):
## * **up close, fists and feet** (Mixamo, CR_GM_*): a jab and cross then a
##   roundhouse; a hook, an uppercut, its foot driven into him; a low kick, a
##   front kick, a cross; a side kick, then the thorns. Each blow lands where
##   he stands ([PackBrute] `_hand_move`, its moments from the films);
## * **thorns all round** (`ring_radius`): both hands down, thorns burst up
##   round it out to 7.5 m, behind it as well — and so it answers him when he
##   gets round behind it, or presses it;
## * **stones stamped up** (`stone_count`): a stamp, stones out of the
##   ground all round, drawn in circling it and hurled every way; some crumble
##   in the air (fewer to draw);
## * **its fists' air** (`volley_from`–`volley_to` m): its fists swell and
##   glow, four slow punches, each hurling a lens of air from the fist that
##   struck — the world bent through it, a tail of bent air behind — slow,
##   turning after him; a roll at the last slips it.

@export_group("Steady")
## Damage (before its defence) that staggers it by itself.
@export var poise_heavy: float = 45.0
## Damage taken close together that staggers it, and how fast that wears off
## (a second, after `poise_rest` s with nothing landing).
@export var poise: float = 90.0
@export var poise_mend: float = 30.0
@export var poise_rest: float = 0.8

@export_group("Stone shell")
## Past this share of its poise its stone hardens (it takes `harden_take`
## of each blow); its poise gone, the shell bursts and for `open_for` s it
## takes `open_take`.
@export var harden_at: float = 0.45
@export var harden_take: float = 0.5
@export var open_take: float = 1.5
@export var open_for: float = 3.0
@export var shell_glow: Color = Color(1.0, 0.5, 0.15)
@export_group("Walls")
## Now and then, him 4–12 m off, stone walls up round him on the side away
## from it: `wall_count` of them `wall_radius` m about him, for `wall_for` s.
@export var wall_from: float = 4.0
@export var wall_to: float = 12.0
@export var wall_cooldown: Vector2 = Vector2(14.0, 20.0)
@export var wall_count: int = 5
@export var wall_radius: float = 3.4
@export var wall_for: float = 6.0
@export_group("Counter")
## Pressed: this many of his blows inside `counter_window` s and it answers
## at once (no wind-up), him within `counter_reach` m; then not again for a
## while.
@export var counter_hits: int = 3
@export var counter_window: float = 2.5
@export var counter_reach: float = 4.5
@export var counter_cooldown: Vector2 = Vector2(6.0, 9.0)
@export_group("From off")
## Him `far_from`–`far_to` m off: now and then it rams him or leaps on him.
@export var far_from: float = 4.5
@export var far_to: float = 10.0
@export var far_cooldown: Vector2 = Vector2(7.0, 11.0)
## The ram's slide over the gap, at most this fast (m/s).
@export var ram_speed: float = 13.0
## The slide is over the last this many seconds before its blow.
@export var ram_burst: float = 0.55
@export_group("Thorns")
## Where its fists come down: thorns out to this far all round (big blows
## `burst_big`), rising outward at `burst_pace` m/s; standing in them (and
## not under its fist itself) costs `burst_share` of a blow.
@export var burst_radius: float = 4.6
@export var burst_big: float = 7.0
@export var burst_pace: float = 14.0
@export var burst_share: float = 0.45
## Its kick: a line of thorns out from its foot.
@export var kick_spikes: float = 7.0
@export_group("Fist")
## Him `fist_from`–`fist_to` m off: its fist thrown at him, flying at
## `fist_speed` out to `fist_range`, back at `fist_back` m/s.
@export var fist_from: float = 6.0
@export var fist_to: float = 17.0
@export var fist_cooldown: Vector2 = Vector2(10.0, 14.0)
@export var fist_speed: float = 30.0
@export var fist_back: float = 22.0
@export var fist_range: float = 19.0
@export_group("Thorn field")
## Him `field_from`–`field_to` m off: the ground under him three times.
@export var field_from: float = 3.0
@export var field_to: float = 14.0
@export var field_cooldown: Vector2 = Vector2(12.0, 16.0)
@export var field_tell: float = 0.65
@export var field_radius: float = 2.6
@export var field_share: float = 0.7
@export_group("Spikes")
@export var spikes_clip: StringName = &"CR_GroundPound"
@export var spikes_part: Vector3 = Vector3(1.25, 0.0, 0.92)
@export var spikes_from: float = 3.5
@export var spikes_to: float = 13.0
@export var spikes_length: float = 14.0
@export var spikes_pace: float = 11.0
@export var spikes_size: float = 1.1
@export var spikes_share: float = 0.9
@export var spikes_cooldown: Vector2 = Vector2(9.0, 13.0)

@export_group("Thorns all round")
## Thorns up all round it out to this far (behind it too), worth this share;
## it raises them when he gets round behind it (within `ring_behind` m) now
## and then.
@export var ring_radius: float = 7.5
@export var ring_share: float = 0.8
@export var ring_behind: float = 5.5
@export var ring_cooldown: Vector2 = Vector2(7.0, 10.0)
@export_group("Stones")
## Stamped up all round it out to `stone_spread` m, drawn in and hurled every
## way; each that meets him costs `stone_share` of a blow.
@export var stone_count: int = 60
@export var stone_spread: float = 6.0
@export var stone_share: float = 0.35
@export var stone_to: float = 12.0
@export var stone_cooldown: Vector2 = Vector2(13.0, 18.0)
@export_group("Air")
## Him this far off: four punches hurling air at him, flying `air_speed`,
## turning after him at most `air_turn` degrees a second, for `air_life` s.
@export var volley_from: float = 6.0
@export var volley_to: float = 18.0
@export var volley_cooldown: Vector2 = Vector2(9.0, 13.0)
@export var air_speed: float = 11.0
@export var air_turn: float = 65.0
@export var air_life: float = 2.6
@export var air_share: float = 0.5

const SPIKES := 118
const WALL := 117
## Its combos' moves (2026-10-10; made its own 2026-10-15 — no ogre's, none
## the troll's): both fists down, shoulder rams, its arms swept, the quake leap.
const G_SLAM := 185
const G_BASH := 186
const G_BASH2 := 187
const G_SWEEP := 188
const G_SWEEP2 := 189
const G_QUAKE := 190
## Round 2: both fists brought down like a hammer, a leap down onto him, a
## low smash, a side swing, a quick chop; arm swats, a kick, a shove; the ram.
const G_HAMMER := 191
const G_LEAPHAM := 192
const G_LOW := 193
const G_SIDE := 194
const G_CHOP := 195
const G_SWAT := 196
const G_SWAT_L := 197
const G_KICK := 198
const G_SHOVE := 199
const G_RAM := 200
## Not blows: dazed as its shell bursts, flexing it back on.
const G_DAZE := 201
const G_ARMOUR := 202
## Round 3: the fist thrown, the thorn field.
const G_FIST := 203
const G_FIELD := 204
## Round 3, with its maul (risen again).
const W_H1 := 210
const W_H2 := 211
const W_H3 := 212
const W_H4 := 213
const W_COMBO := 214
const W_LOW := 215
const W_HIGH := 216
const W_SPIN := 217
## Round 4: its own fists and feet, the thorns all round, the stones, the air.
const G_JABCROSS := 220
const G_ROUNDHOUSE := 221
const G_HOOK := 222
const G_UPPER := 223
const G_DRIVE := 224
const G_LOWKICK := 225
const G_FRONTKICK := 226
const G_CROSS := 227
const G_SIDEKICK := 228
const G_RING := 229
const G_STOMP := 230
const G_HURL := 231
const G_VOLLEY := 232
## Its new clips' frames (30 a second), for their lengths before its player is
## up ([method _gm_len]).
const GM_FRAMES := {&"CR_GM_JabCross": 68, &"CR_GM_Roundhouse": 46, &"CR_GM_Hook": 69, &"CR_GM_Uppercut": 41,
		&"CR_GM_DriveKick": 106, &"CR_GM_LowKick": 46, &"CR_GM_FrontKick": 66, &"CR_GM_Cross": 61,
		&"CR_GM_SideKick": 49, &"CR_GM_Thorns": 90, &"CR_GM_Stomp": 57, &"CR_GM_Hurl": 99, &"CR_GM_QuadPunch": 66}
const KICK_L := "L_knee_joint>L_toe_joint:0.22"
## The volley's punches (s of its clip) and its fists' swelling (from, to).
const VOLLEY_PUNCHES := [0.45, 0.65, 0.92, 1.15]
const VOLLEY_SWELL := Vector2(0.0, 1.55)
const WEAPON_MOVES := [W_H1, W_H2, W_H3, W_H4, W_COMBO, W_LOW, W_HIGH, W_SPIN]
## Its moves that break the ground where they land (the big ones).
const GROUND_MOVES := [G_SLAM, G_QUAKE, G_SWEEP2, G_HAMMER, G_LEAPHAM, G_LOW, W_H2, W_H4, W_LOW]
const BIG_GROUND := [G_QUAKE, G_LEAPHAM, W_H4]
## Its paces (the leaps quick: round 3).
const SLOW_MOVES := [G_SLAM, G_HAMMER, W_H2]
const MID_MOVES := [G_BASH, G_BASH2, G_SWEEP, G_SWEEP2, G_SIDE, G_LOW, W_LOW, W_HIGH]
const QUICK_MOVES := [G_SWAT, G_SWAT_L, G_CHOP, G_KICK, G_SHOVE, G_RAM]
const COUNTER_COMBO := &"counter"
const QUAKE_COMBO := &"quake"
const RAM_COMBO := &"ram_far"
const REEL_COMBO := &"reel_in"
## The fist's flight.
enum Fist { NONE, OUT, BACK, HOLDING }
const BOTH := "L_elbow_joint>L_midFinger_joint3:0.2|R_elbow_joint>R_midFinger_joint3:0.2"
const SHOULDERS := "L_shoulder_joint>L_elbow_joint:0.32|R_shoulder_joint>R_elbow_joint:0.32"
const RIGHT := "R_elbow_joint>R_midFinger_joint3:0.24"
const LEFT := "L_elbow_joint>L_midFinger_joint3:0.24"
const KICK_LEG := "R_knee_joint>R_toe_joint:0.22"
const RAMMED := "L_shoulder_joint>L_elbow_joint:0.36|R_shoulder_joint>R_elbow_joint:0.36|pelvis_joint>head_joint:0.45"

var _poise_taken: float = 0.0
var _since_hit: float = 99.0
var _spikes_wait: float = 2.0
var _spiked: bool = false
var _spikes_at: float = 0.5
## Host: spike runs going out ([method _run_spikes]).
var _runs: Array[Dictionary] = []
var _wall_wait: float = 6.0
var _walled: bool = false
var _wall_at: float = 0.6
## Host: shell open till then (s of `_since_hit`'s clock); hardened now.
var _open_left: float = 0.0
var hardened: bool = false
var shells_burst: int = 0
var walls_raised: int = 0
## Every peer: the act its ground blows were last broken for; a step's clock.
var _ground_serial: int = -1
var _ground_clock: float = 0.0
var _ground_done: int = 0
var _step_clock: float = 0.0
var _shell_mat: StandardMaterial3D
var _shell_shown: float = 0.0
## Host: when his blows landed (its own clock), the counter's and the far
## moves' waits; how often it answered.
var _clock: float = 0.0
var _hit_times: Array[float] = []
var _counter_wait: float = 3.0
var _far_wait: float = 4.0
var counters_made: int = 0
var rams_made: int = 0
var dazes: int = 0
var armours: int = 0
var _was_open: bool = false
## Round 3. Host: the fist's and the field's waits, the thorn bursts and the
## field's spots hurting; every peer: the fist where it is, its looks; armed.
var _fist_wait: float = 6.0
var _field_wait: float = 8.0
var _fist_at: float = 0.6
var _fist_thrown: bool = false
var _fist_state: int = Fist.NONE
var _fist_pos: Vector3 = Vector3.ZERO
var _fist_dir: Vector3 = Vector3.FORWARD
var _fist_went: float = 0.0
var _fist_held: Node3D = null
var _fist_mesh: Node3D
var _tether: MeshInstance3D
var _hide_hand: BoneHide
var _field_at: float = 0.9
var _fielded: bool = false
var _fields: Array[Dictionary] = []
var _bursts: Array[Dictionary] = []
var fists_thrown: int = 0
var fists_caught: int = 0
var fields_cast: int = 0
var bursts_hurt: int = 0
var armed: bool = false
var _maul: Node3D
var _grip_local: Vector3 = Vector3.ZERO
var _grip_learnt: bool = false
var _kick_serial: int = -1
## Round 4. Host: the waits, the volley's punches thrown, the moments passed;
## every peer: the stones up (and the shots of air) as they fly.
var _ring_wait: float = 4.0
var _volley_wait: float = 5.0
var _stones_wait: float = 6.0
var _gm_done: int = 0
var _gm_serial: int = -1
var _stones: Array[Dictionary] = []
## 0 none, 1 up round it, 2 flying.
var _stone_state: int = 0
var _stone_caught: Dictionary = {}
var _stone_id: int = 0
var _stone_hot: StandardMaterial3D
var _shots: Array[Dictionary] = []
var _swell: Dictionary = {}
var _swell_lights: Dictionary = {}
var rings_raised: int = 0
var stones_hurled: int = 0
var stones_hurt: int = 0
var air_shots: int = 0
var air_hurt: int = 0


func _ready() -> void:
	# its plain blows its own too (none of the troll's fists)
	# (round 2: its plain blows are the quick ones, not its combos' over again)
	# (round 4: a hook, a cross, a low kick — its own, from Mixamo)
	attacks = [&"CR_GM_Hook", &"CR_GM_Cross", &"CR_GM_LowKick"] as Array[StringName]
	attack_parts = [_gm_part(&"CR_GM_Hook", 0.3, 1.0, 0.95), _gm_part(&"CR_GM_Cross", 0.7, 1.6, 0.9),
			_gm_part(&"CR_GM_LowKick", 0.2, 0.95, 0.9)] as Array[Vector3]
	attack_limbs = PackedStringArray([LEFT, RIGHT, KICK_LEG])
	attack_blows = PackedInt32Array([1, 1, 1])
	attack_clip = &"CR_GM_Cross"
	# its heavy stand and walk (round 4)
	idle_clip = &"CR_GM_Idle"
	walk_clip = &"CR_GM_Walk"
	# its maul's stance and walk, for when it has one (round 3)
	var loops := Array(loop_clips)
	for c in ["CR_HeavyIdle", "CR_HeavyWalk", "CR_HeavyBack", "CR_HeavyL", "CR_HeavyR", "CR_GM_Idle", "CR_GM_Walk"]:
		if not loops.has(c):
			loops.append(c)
	loop_clips = PackedStringArray(loops)
	# it never runs
	run_clip = &""
	chase_speed = minf(chase_speed, 2.6)
	run_above = 99.0
	super()
	_set_combos()
	_special(SPIKES, spikes_clip, spikes_part)
	_special(WALL, &"CR_MG_Raise", Vector3(1.0, 0.0, 0.85))
	_special(G_DAZE, &"CR_Stun", Vector3(1.0, 0.0, 0.92))
	_special(G_ARMOUR, &"CR_PowerUp", Vector3(1.5, 0.05, 0.6))
	_far_wait = _rng.randf_range(3.0, far_cooldown.x)
	_special(G_FIST, &"CR_MG_Throw", Vector3(1.3, 0.0, 0.9))
	_special(G_FIELD, &"CR_MG_Ground", Vector3(1.6, 0.0, 0.8))
	_fist_wait = _rng.randf_range(4.0, fist_cooldown.x)
	_field_wait = _rng.randf_range(6.0, field_cooldown.x)
	if _anim != null:
		var best := -1.0
		for pk in _anim.measure_peaks(&"CR_MG_Throw", PackedStringArray(["R_wrist_joint"]), 0.5, 0.08):
			if pk > 0.2 and pk < 0.85 and best < 0.0:
				best = pk
		if best < 0.0:
			best = 0.5
		_fist_at = best * _anim.clip_length(&"CR_MG_Throw") / 1.3
		_field_at = 0.5 * _anim.clip_length(&"CR_MG_Ground") / 1.6
	if _skeleton != null:
		_hide_hand = BoneHide.new()
		_hide_hand.bone_name = "R_wrist_joint"
		_skeleton.add_child(_hide_hand)
	if _anim != null:
		_wall_at = _anim.clip_length(&"CR_MG_Raise") * 0.55
	_wall_wait = _rng.randf_range(5.0, wall_cooldown.x)
	if _anim != null:
		var m: Array = _moves_table[SPIKES]
		var at := _anim.measure_reach(m[0], "R_wrist_joint", Vector3(0.12, 0, 0), reach_forward, float(m[2]), float(m[3]))
		if at < 0.0:
			at = lerpf(float(m[2]), float(m[3]), 0.5)
		_spikes_at = (at - float(m[2])) * _anim.clip_length(m[0]) / maxf(float(m[1]), 0.01)
	_spikes_wait = _rng.randf_range(2.0, spikes_cooldown.x)
	_ring_wait = _rng.randf_range(2.0, ring_cooldown.x)
	_volley_wait = _rng.randf_range(3.0, volley_cooldown.x)
	_stones_wait = _rng.randf_range(5.0, stone_cooldown.x)
	if _skeleton != null:
		for side in ["L", "R"]:
			var g := BoneHide.new()
			g.bone_name = side + "_wrist_joint"
			_skeleton.add_child(g)
			_swell[side] = g


func _shatter_matter() -> StringName:
	return &"stone"


#region Steady
func _receive(damage: float, at: Vector3, blow: Vector3, from: Node3D, magic: bool = false) -> bool:
	var was := velocity
	# its poise counts the blow as struck, its health as its stone lets it in
	var raw := damage
	if _open_left > 0.0:
		damage *= open_take
	elif hardened:
		damage *= harden_take
	var bled := super(damage, at, blow, from, magic)
	if not bled or is_dead or act == PIECES:
		return bled
	# Not pushed about by it.
	velocity.x = was.x
	velocity.z = was.z
	_since_hit = 0.0
	_hit_times.append(_clock)
	_poise_taken += raw
	if raw >= poise_heavy or _poise_taken >= poise:
		_stagger()
	return bled


## Staggered at last: its shell bursts, it reels, open.
func _stagger() -> void:
	_poise_taken = 0.0
	if hardened or _open_left <= 0.0:
		shells_burst += 1
		_open_left = open_for
		if is_inside_tree() and multiplayer.has_multiplayer_peer():
			net_shell_burst.rpc()
		else:
			net_shell_burst()
	if act == PIECES or act == REFORM:
		return
	_sweeps.clear()
	# dazed through the time its shell is open (round 2)
	if _moves_table.has(G_DAZE):
		dazes += 1
		_begin(G_DAZE)
	else:
		_start(Act.REACT_KNOCK)


## A skill that would throw it about counts as a heavy blow, no more.
func react(kind: StringName, from: Node3D = null, push: Vector3 = Vector3.ZERO) -> void:
	if kind == &"knock" or kind == &"stun":
		if is_dead or not _decides():
			return
		if from != null and is_instance_valid(from):
			_rouse(from)
		_since_hit = 0.0
		_poise_taken += poise_heavy * 0.6
		if _poise_taken >= poise:
			_stagger()
		return
	super(kind, from, push)


## The blow seen on it is a shudder, not a bend.
func _flinch_body(blow: Vector3) -> void:
	_last_blow = blow
	if is_dead or body == null:
		return
	if _hit_react == null:
		_hit_react = HitReact.on_body(body)
	_hit_react.strike(blow, FLINCH_THROW * 0.18)


## A parry does not set it reeling either; it only counts.
func parried(_by: Node3D) -> void:
	if is_dead or not _decides():
		return
	_poise_taken += poise * 0.5
	if _poise_taken >= poise:
		_stagger()
#endregion


#region Spikes
## Its combos made by hand ([PackBrute] `_hand_combos`), few and slow, each
## blow seen coming a long way off (its fists glowing up, `_windups`): a
## shoulder rammed into him and both fists down; its arms swept one way, the
## other, and both fists down; a ram and a sweep; from off, the quake leap.
func _set_combos() -> void:
	hand_pace = 1.0
	hand_combo_chance = Vector2(0.7, 0.8)
	_hand_move(G_SLAM, &"CR_GroundPound", Vector3(1.2, 0.0, 0.92), 1.5, BOTH)
	_hand_move(G_BASH, &"CR_ShieldBash", Vector3(0.85, 0.0, 0.9), 0.8, SHOULDERS)
	_hand_move(G_BASH2, &"CR_ShieldBash2", Vector3(0.85, 0.0, 0.9), 0.9, SHOULDERS)
	_hand_move(G_SWEEP, &"CR_Staff1", Vector3(0.85, 0.0, 0.9), 0.9, BOTH)
	_hand_move(G_SWEEP2, &"CR_Staff2", Vector3(0.85, 0.0, 0.9), 1.0, BOTH)
	_hand_move(G_QUAKE, &"CR_RunJumpSlam", Vector3(1.55, 0.0, 0.92), 1.6, BOTH)
	# round 2
	_hand_move(G_HAMMER, &"CR_Heavy2", Vector3(1.05, 0.0, 0.88), 1.5, BOTH)
	_hand_move(G_LEAPHAM, &"CR_Heavy4", Vector3(1.35, 0.0, 0.9), 1.5, BOTH)
	_hand_move(G_LOW, &"CR_HeavyA", Vector3(0.95, 0.0, 0.92), 1.1, BOTH)
	_hand_move(G_SIDE, &"CR_Heavy3", Vector3(0.95, 0.0, 0.88), 1.0, BOTH)
	_hand_move(G_CHOP, &"CR_Heavy1", Vector3(1.35, 0.0, 0.8), 0.6, BOTH)
	_hand_move(G_SWAT, &"CR_Slash1", Vector3(1.35, 0.0, 0.78), 0.45, RIGHT)
	_hand_move(G_SWAT_L, &"CR_SlashL1", Vector3(1.35, 0.0, 0.78), 0.45, LEFT)
	_hand_move(G_KICK, &"CR_Kick", Vector3(1.3, 0.0, 0.8), 0.55, KICK_LEG)
	_hand_move(G_SHOVE, &"CR_ShieldBash", Vector3(1.4, 0.0, 0.8), 0.4, SHOULDERS)
	# (a long lunge, shoulder first: its blow late enough to slide the gap)
	_hand_move(G_RAM, &"CR_Polearm4", Vector3(1.0, 0.0, 0.8), 1.1, BOTH + "|" + RAMMED)
	for what: int in SLOW_MOVES:
		# up (and glowing), then all of it at once — not long (round 3)
		_windups[what] = [1.3, 0.2]
		_snap[what] = 1.5
	for what: int in QUICK_MOVES:
		# quick, but not past seeing: its wind-up at least so long
		_slow_to[what] = 0.42
	_windups[G_HAMMER] = [1.5, 0.2]
	# quick, but its fists down seen coming (their clips strike early)
	_windups.erase(G_SLAM)
	_slow_to[G_SLAM] = 0.55
	_slow_to[G_LEAPHAM] = 0.6
	# the ram: its lunge drawn out over the slide, so it covers the gap
	_slow_to[G_RAM] = 0.85
	for what: int in MID_MOVES:
		# a little drawn out; now and then held at the top (a delayed blow)
		_windups[what] = [1.3, 0.2]
		_snap[what] = 1.3
		_holds[what] = [0.35, 0.35, 0.8, 0.25]
	_kinds[G_SLAM] = &"crush"
	_kinds[G_QUAKE] = &"crush"
	_kinds[G_HAMMER] = &"crush"
	_kinds[G_LEAPHAM] = &"crush"
	_kinds[G_KICK] = &"guard"
	_kinds[G_SHOVE] = &"guard"
	_gm_moves()
	_maul_moves()


func _combo_index(name: StringName) -> int:
	for i in _hand_combos.size():
		if StringName((_hand_combos[i] as Dictionary)["name"]) == name:
			return i
	return -1


func _own_move(delta: float) -> bool:
	_spikes_wait = maxf(_spikes_wait - delta, 0.0)
	_wall_wait = maxf(_wall_wait - delta, 0.0)
	_counter_wait = maxf(_counter_wait - delta, 0.0)
	_far_wait = maxf(_far_wait - delta, 0.0)
	_fist_wait = maxf(_fist_wait - delta, 0.0)
	_field_wait = maxf(_field_wait - delta, 0.0)
	var gap := _distance_to(_quarry)
	# its fist away: it stands and waits for it, turned to him
	if _fist_state != Fist.NONE:
		mode = Mode.FIGHT
		velocity.x = move_toward(velocity.x, 0.0, acceleration * delta)
		velocity.z = move_toward(velocity.z, 0.0, acceleration * delta)
		_face(_quarry.global_position - global_position, delta, turn_speed)
		return true
	_ring_wait = maxf(_ring_wait - delta, 0.0)
	_volley_wait = maxf(_volley_wait - delta, 0.0)
	_stones_wait = maxf(_stones_wait - delta, 0.0)
	# pressed, it answers at once (round 4: the thorns all round)
	if _counter_wait <= 0.0 and gap <= counter_reach and not _quarry_down() and drill_combo < 0:
		var recent := 0
		for t in _hit_times:
			if _clock - t <= counter_window:
				recent += 1
		if recent >= counter_hits:
			var c := _combo_index(COUNTER_COMBO)
			if c >= 0:
				counters_made += 1
				_hit_times.clear()
				_counter_wait = _rng.randf_range(counter_cooldown.x, counter_cooldown.y)
				_ring_wait = maxf(_ring_wait, 3.0)
				start_hand_combo(c)
				return true
	if drill_combo >= 0 or _quarry_down() or stamina < attack_cost:
		return super(delta)
	var to := _quarry.global_position - global_position
	to.y = 0.0
	# him round behind it: the thorns all round
	if _ring_wait <= 0.0 and gap <= ring_behind and to.length_squared() > 0.01 \
			and rad_to_deg(_forward().angle_to(to.normalized())) > 110.0:
		mode = Mode.FIGHT
		_ring_wait = _rng.randf_range(ring_cooldown.x, ring_cooldown.y)
		_begin(G_RING)
		return true
	# from off: its fists' air (not with the maul in its hands)
	if not armed and _volley_wait <= 0.0 and gap >= volley_from and gap <= volley_to:
		mode = Mode.FIGHT
		_face(to, 1.0, 50.0)
		_volley_wait = _rng.randf_range(volley_cooldown.x, volley_cooldown.y)
		_begin(G_VOLLEY)
		return true
	# the stones, near or off
	if _stones_wait <= 0.0 and gap <= stone_to and _stone_state == 0:
		mode = Mode.FIGHT
		_face(to, 1.0, 50.0)
		_stones_wait = _rng.randf_range(stone_cooldown.x, stone_cooldown.y)
		_begin(G_STOMP)
		return true
	return super(delta)


func _run_act(delta: float) -> void:
	super(delta)
	if is_dead or not _decides():
		return
	_gm_run_act(delta)
	# the ram: it slides the gap so its shoulder lands on him
	if act == G_RAM and _quarry != null:
		var ms := _blow_moments(G_RAM)
		if not ms.is_empty() and _act_time < ms[0]:
			var to := _quarry.global_position - global_position
			to.y = 0.0
			var off := maxf(to.length() - reach * 0.75, 0.0)
			var left := maxf(ms[0] - _act_time, 0.08)
			_face(to, delta, turn_speed * 2.0)
			# gathered, then all at once over the last of it
			var v := Vector3.ZERO
			if left <= ram_burst:
				v = _forward() * minf(off / left, ram_speed)
			velocity.x = v.x
			velocity.z = v.z
	if act == G_FIST:
		if _quarry != null and _act_time < _fist_at:
			_face(_quarry.global_position - global_position, delta, turn_speed * 1.5)
		if not _fist_thrown and _act_time >= _fist_at:
			_fist_thrown = true
			_throw_fist()
	if act == G_FIELD:
		if _quarry != null and _act_time < _field_at:
			_face(_quarry.global_position - global_position, delta, turn_speed)
		if not _fielded and _act_time >= _field_at:
			_fielded = true
			fields_cast += 1
			for k in 3:
				_fields.append({"t": -0.62 * float(k), "marked": false, "at": Vector3.ZERO,
						"id": act_serial * 1000 + 300 + k})
	if act == WALL and not _walled and _act_time >= _wall_at:
		_walled = true
		_raise_walls()
	if act == SPIKES:
		if _quarry != null and _act_time < _spikes_at:
			_face(_quarry.global_position - global_position, delta, turn_speed)
		if not _spiked and _act_time >= _spikes_at:
			_spiked = true
			var from := global_position + _forward() * 1.0 * visual_scale
			var way := _forward()
			if _quarry != null:
				way = _quarry.global_position - from
				way.y = 0.0
				way = way.normalized() if way.length_squared() > 0.01 else _forward()
			_spike_run(from, way)


func _after(what: int) -> void:
	if what == SPIKES:
		_spikes_wait = _rng.randf_range(spikes_cooldown.x, spikes_cooldown.y)
	super(what)
	# stamped up, then drawn in and hurled
	if what == G_STOMP and _decides() and not is_dead and act == Act.NONE and _stone_state == 1:
		_begin(G_HURL)


## Host: a run of spikes from `from` along `way`, seen everywhere.
func _spike_run(from: Vector3, way: Vector3, length: float = -1.0) -> void:
	if length <= 0.0:
		length = spikes_length
	_runs.append({"from": from, "dir": way, "t": 0.0, "caught": {}, "id": act_serial * 1000 + 95, "length": length})
	if is_inside_tree() and multiplayer.has_multiplayer_peer():
		net_spikes.rpc(from, way, length)
	else:
		net_spikes(from, way, length)


@rpc("authority", "call_local", "reliable")
func net_spikes(from: Vector3, way: Vector3, length: float = 14.0) -> void:
	var world := Blood.world_of(self)
	GroundFx.shards(world, from, way, length, spikes_size, spikes_pace, reform_glow)
	GroundFx.eruption(world, from, 0.8, false)
	ImpactFx.thud(self, from, true)


func _physics_process(delta: float) -> void:
	super(delta)
	_since_hit += delta
	if _since_hit > poise_rest:
		_poise_taken = maxf(_poise_taken - poise_mend * delta, 0.0)
	_clock += delta
	while not _hit_times.is_empty() and _clock - _hit_times[0] > counter_window:
		_hit_times.remove_at(0)
	if _decides() and not is_dead:
		_open_left = maxf(_open_left - delta, 0.0)
		# its stone closing again: it flexes it back on, if it is free to
		var open := _open_left > 0.0
		if _was_open and not open and act == Act.NONE and _moves_table.has(G_ARMOUR):
			armours += 1
			_begin(G_ARMOUR)
			if is_inside_tree() and multiplayer.has_multiplayer_peer():
				net_armour.rpc()
			else:
				net_armour()
		_was_open = open
		var hard := _open_left <= 0.0 and _poise_taken >= poise * harden_at
		if hard != hardened:
			if is_inside_tree() and multiplayer.has_multiplayer_peer():
				net_harden.rpc(hard)
			else:
				net_harden(hard)
	if _decides() and not is_dead:
		_fly_fist(delta)
		_run_fields(delta)
		_run_bursts(delta)
	if _runs.is_empty() or not _decides():
		return
	for i in range(_runs.size() - 1, -1, -1):
		var run := _runs[i]
		run.t = float(run.t) + delta
		var front := float(run.t) * spikes_pace
		var ahead: Vector3 = run.dir
		var side := Vector3(-ahead.z, 0.0, ahead.x)
		var caught: Dictionary = run.caught
		for node in get_tree().get_nodes_in_group(&"player"):
			var who := node as Node3D
			if who == null or caught.has(who) or not who.has_method(&"receive_blow") or bool(who.get("is_dead")):
				continue
			var rel := who.global_position - (run.from as Vector3)
			if absf(rel.y) > 2.0:
				continue
			var d := rel.dot(ahead)
			# Under him as that row comes up (a moment after the front passes).
			if d < 0.4 or d > minf(front - 0.3, float(run.get("length", spikes_length))):
				continue
			if absf(rel.dot(side)) > GroundFx.wave_width(d, spikes_size) * 0.5 + 0.35:
				continue
			caught[who] = true
			who.call(&"receive_blow", hit_damage * spikes_share * _blow_worth(SPIKES), self, 0, 1, int(run.id),
					false, &"spike")
		if front > float(run.get("length", spikes_length)) + 1.0:
			_runs.remove_at(i)
#endregion


#region Its own (2026-10-15): the shell, the ground broken, the steps, the walls
@rpc("authority", "call_local", "reliable")
func net_harden(on: bool) -> void:
	hardened = on
	if on:
		Sfx.play(self, "res://sounds/ogre/club_ground_2.wav", self, Vector3.UP * 2.0 * visual_scale, 1.4, -6.0)


## Every peer: the shell bursting — stone chips off it all round, a crack.
@rpc("authority", "call_local", "reliable")
func net_shell_burst() -> void:
	hardened = false
	var world := Blood.world_of(self)
	var mid := global_position + Vector3.UP * 1.7 * visual_scale
	SkillFx.burst(world, mid, Color(0.42, 0.4, 0.38), 40, Vector2(3.0, 8.0), Vector3.UP, 180.0,
			Vector2(0.06, 0.16), Vector3(0, -14.0, 0), 1.0)
	SkillFx.burst(world, mid, shell_glow, 24, Vector2(2.0, 5.0), Vector3.UP, 180.0,
			Vector2(0.03, 0.06), Vector3.ZERO, 0.5)
	ImpactFx.strike(self, mid, &"stone", 2.2)
	WindBlast.shake(self, 0.1, 0.35, 14.0)


func _process(delta: float) -> void:
	super(delta)
	_show_shell(delta)
	_run_stones(delta)
	_run_shots(delta)
	_show_swell()
	if is_dead:
		return
	# its blows breaking the ground where they come down
	if act_serial != _ground_serial:
		_ground_serial = act_serial
		_ground_clock = 0.0
		_ground_done = 0
	else:
		_ground_clock += delta
	if act in GROUND_MOVES:
		var ms := _blow_moments(act)
		while _ground_done < ms.size() and _ground_clock >= ms[_ground_done]:
			_ground_done += 1
			_break_ground(act in BIG_GROUND)
	# its kick: thorns run out from its foot (host)
	# (not mid-string: they would put him down before its next blow)
	if _decides() and _is_kick(act) and _kick_serial != act_serial \
			and (_hand_combo < 0 or _hand_step >= _hand_moves.size() - 1):
		var km := _blow_moments(act)
		if not km.is_empty() and _ground_clock >= km[0]:
			_kick_serial = act_serial
			var foot := global_position + _forward() * 1.4 * visual_scale / 1.8
			foot.y = global_position.y
			_spike_run(foot, _forward(), kick_spikes)
	_show_fist(delta)
	_show_maul(delta)
	_gm_fx()
	# the ground shaking under its steps
	var pace := Vector2(velocity.x, velocity.z).length()
	if act == Act.NONE and pace > 0.4 and is_on_floor():
		_step_clock += delta * pace
		if _step_clock >= 1.15 * visual_scale / 1.8:
			_step_clock = 0.0
			Sfx.play_any(self, ["res://sounds/ogre/step_1.wav", "res://sounds/ogre/step_2.wav",
					"res://sounds/ogre/step_3.wav"], self, 0.6, -4.0)
			WindBlast.shake(self, 0.025, 0.18, 11.0)
			SkillFx.burst(Blood.world_of(self), global_position + Vector3.UP * 0.1, Color(0.45, 0.4, 0.33, 0.5), 5,
					Vector2(0.4, 1.2), Vector3.UP, 70.0, Vector2(0.08, 0.16), Vector3(0, -1.0, 0), 0.6)


## Every peer: its stone closing over it again — a glow run over it, grit.
@rpc("authority", "call_local", "reliable")
func net_armour() -> void:
	var world := Blood.world_of(self)
	var mid := global_position + Vector3.UP * 1.7 * visual_scale / 1.8
	SkillFx.burst(world, mid, shell_glow, 30, Vector2(1.0, 3.0), Vector3.UP, 180.0,
			Vector2(0.03, 0.07), Vector3(0, 2.0, 0), 0.8)
	SkillFx.burst(world, mid, Color(0.42, 0.4, 0.38), 16, Vector2(0.5, 2.0), Vector3.UP, 180.0,
			Vector2(0.05, 0.12), Vector3(0, -9.0, 0), 0.8)
	Sfx.play(self, "res://sounds/ogre/club_ground_2.wav", self, Vector3.UP * 2.0 * visual_scale, 0.8, -4.0)
	_shell_shown = 1.0


## Every peer: its fists into the ground — thorns burst up all round,
## outward (round 3: thorns, not rocks, and far out); the host hurts by the
## same numbers ([method _run_bursts]).
func _break_ground(quake: bool) -> void:
	var world := Blood.world_of(self)
	var at := global_position + _forward() * 1.6 * visual_scale / 1.8
	at.y = global_position.y
	var s := visual_scale / 1.8
	var r := (burst_big if quake else burst_radius) * s
	GroundFx.spike_burst(world, at, r, (1.25 if quake else 1.0) * s, burst_pace, shell_glow, act_serial * 17 + _ground_done)
	var crack := DarkFx.decal(world, at, DarkFx.CRACK, (5.0 if quake else 3.2) * s, Color(0.09, 0.07, 0.05, 1.0), 0.0, 0.9)
	crack.rotation.y = randf() * TAU
	var tw := crack.create_tween()
	tw.tween_interval(3.0)
	tw.tween_property(crack, "modulate:a", 0.0, 2.5).set_ease(Tween.EASE_IN)
	tw.tween_callback(crack.queue_free)
	SkillFx.burst(world, at + Vector3.UP * 0.2, Color(0.45, 0.39, 0.31, 0.65), 30, Vector2(1.5, 5.0), Vector3.UP, 80.0,
			Vector2(0.1, 0.25), Vector3(0, -1.5, 0), 1.2)
	Sfx.play_any(self, ["res://sounds/ogre/club_ground_1.wav", "res://sounds/ogre/club_ground_3.wav"], null, 0.7, 4.0)
	ImpactFx.thud(self, at, true)
	WindBlast.shake(self, 0.16 if quake else 0.1, 0.45, 18.0)
	if _decides():
		_bursts.append({"at": at, "r": r, "t": 0.0, "caught": {}, "id": act_serial * 1000 + 200 + _ground_done})


## Host: who stands in a burst's thorns as they reach him (on the ground; not
## right under its fist, which its blow itself has).
func _run_bursts(delta: float) -> void:
	for i in range(_bursts.size() - 1, -1, -1):
		var b := _bursts[i]
		b.t = float(b.t) + delta
		var front := float(b.t) * burst_pace
		var caught: Dictionary = b.caught
		for node in get_tree().get_nodes_in_group(&"player"):
			var who := node as Node3D
			if who == null or caught.has(who) or not who.has_method(&"receive_blow") or bool(who.get("is_dead")):
				continue
			var rel := who.global_position - (b.at as Vector3)
			if absf(rel.y) > 0.9:
				continue
			rel.y = 0.0
			var d := rel.length()
			if d < float(b.get("inner", 1.5)) or d > float(b.r) or d > front - 0.2:
				continue
			caught[who] = true
			bursts_hurt += 1
			who.call(&"receive_blow", hit_damage * float(b.get("share", burst_share)), self, 0, 1, int(b.id), false,
					&"spike")
		if front > float(b.r) + 1.0:
			_bursts.remove_at(i)


func _is_kick(what: int) -> bool:
	if what == G_KICK:
		return true
	if what == Act.NONE or not _moves_table.has(what):
		return false
	if (_moves_table[what] as Array)[0] == &"CR_Kick":
		return true
	return false


## Every peer: its cracks glowing as its stone hardens; dark when open.
func _show_shell(delta: float) -> void:
	if body == null:
		return
	var want := 1.0 if hardened and not is_dead else 0.0
	_shell_shown = move_toward(_shell_shown, want, delta * 3.0)
	if _shell_mat == null:
		if _shell_shown <= 0.0:
			return
		_shell_mat = StandardMaterial3D.new()
		_shell_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_shell_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_shell_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_shell_mat.albedo_color = Color(shell_glow, 0.0)
	var on := _shell_shown > 0.0
	for mi: MeshInstance3D in body.find_children("*", "MeshInstance3D", true, false):
		if mi.material_overlay == null or mi.material_overlay == _shell_mat:
			mi.material_overlay = _shell_mat if on else null
	_shell_mat.albedo_color.a = _shell_shown * (0.14 + 0.06 * sin(Time.get_ticks_msec() / 1000.0 * 5.0))


## Host: stone walls up round him, on the side away from it.
func _raise_walls() -> void:
	if _quarry == null:
		return
	walls_raised += 1
	var him := _quarry.global_position
	var away := him - global_position
	away.y = 0.0
	away = away.normalized() if away.length_squared() > 0.01 else _forward()
	var spots := PackedVector3Array()
	for i in wall_count:
		# a half ring behind him and to his sides, open towards it
		var a := lerpf(-PI * 0.62, PI * 0.62, float(i) / maxf(float(wall_count - 1), 1.0))
		spots.append(him + away.rotated(Vector3.UP, a) * wall_radius)
	if is_inside_tree() and multiplayer.has_multiplayer_peer():
		net_walls.rpc(spots, him)
	else:
		net_walls(spots, him)


## Every peer: the walls come up out of the ground, stand a while, sink.
@rpc("authority", "call_local", "reliable")
func net_walls(spots: PackedVector3Array, centre: Vector3) -> void:
	var world := Blood.world_of(self)
	if world == null:
		return
	ImpactFx.thud(self, centre, true)
	WindBlast.shake(self, 0.12, 0.5, 20.0)
	for i in spots.size():
		var at := spots[i]
		at.y = global_position.y
		var wall := StaticBody3D.new()
		wall.name = "GolemWall_%d_%d" % [walls_raised, i]
		wall.collision_layer = 1
		wall.collision_mask = 0
		var shape := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = 0.75
		cyl.height = 3.6
		shape.shape = cyl
		shape.position = Vector3.UP * 1.8
		wall.add_child(shape)
		var mi := MeshInstance3D.new()
		mi.mesh = RockWave._crag_mesh(i % RockWave.SHAPES)
		mi.material_override = RockWave._crag_material()
		mi.scale = Vector3(1.5, 3.8, 1.5)
		mi.rotation.y = randf() * TAU
		wall.add_child(mi)
		world.add_child(wall)
		wall.global_position = at - Vector3.UP * 3.8
		var tw := wall.create_tween()
		tw.tween_interval(0.05 * i)
		tw.tween_property(wall, "global_position", at, 0.22).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		tw.tween_interval(wall_for)
		tw.tween_property(wall, "global_position", at - Vector3.UP * 3.8, 0.6).set_ease(Tween.EASE_IN)
		tw.tween_callback(wall.queue_free)
		SkillFx.burst(world, at + Vector3.UP * 0.3, Color(0.45, 0.39, 0.31, 0.65), 18, Vector2(1.0, 4.0), Vector3.UP, 70.0,
				Vector2(0.1, 0.22), Vector3(0, -2.0, 0), 1.0)
#endregion


#region Round 4: fists and feet, thorns all round, the stones, the air
## A clip's length (s): its player's, or by its frames before that is up.
func _gm_len(clip: StringName) -> float:
	if _anim != null:
		var l := _anim.clip_length(clip)
		if l > 0.0:
			return l
	return (float(GM_FRAMES.get(clip, 31)) - 1.0) / 30.0


## [rate, from, to] of `clip` from seconds (`to_s` below 0: its end).
func _gm_part(clip: StringName, from_s: float, to_s: float, rate: float) -> Vector3:
	var l := _gm_len(clip)
	return Vector3(rate, clampf(from_s / l, 0.0, 1.0), 1.0 if to_s < 0.0 else clampf(to_s / l, 0.0, 1.0))


## A move of its combos by the films' numbers: `clip` from `from_s` to `to_s`
## at `rate`, its blows at `hits` (s of the clip) with `limbs`; its fist or
## foot out `z` ahead of it there (on a body of 1), so it opens from that gap
## and its blow meets him rather than the air before him or his own body.
func _gm(what: int, clip: StringName, from_s: float, to_s: float, rate: float, share: float, limbs: String,
		hits: Array, z: float) -> void:
	var l := _gm_len(clip)
	var ms: Array = []
	for h in hits:
		ms.append(clampf(float(h) / l, 0.0, 1.0))
	_hand_move(what, clip, _gm_part(clip, from_s, to_s, rate), share, limbs, ms)
	_strike_from[what] = z * visual_scale + (0.4 if limbs.contains("Finger") else 0.45)


## When (s into the act) `clip_s` of its clip comes.
func _gm_at(what: int, clip_s: float) -> float:
	var m: Array = _moves_table[what]
	var l := _gm_len(m[0])
	return (clip_s - float(m[2]) * l) / maxf(float(m[1]), 0.01)


## Its fists and feet (the films' moments: `_shots_tmp/golem/gprobe3.gd`),
## its combos of them, the thorns, the stones, the air.
func _gm_moves() -> void:
	_gm(G_JABCROSS, &"CR_GM_JabCross", 0.0, 0.85, 0.9, 0.5, BOTH, [0.3, 0.62], 0.7)
	_gm(G_ROUNDHOUSE, &"CR_GM_Roundhouse", 0.2, -1.0, 0.85, 1.1, KICK_LEG, [0.68], 0.92)
	_gm(G_HOOK, &"CR_GM_Hook", 0.3, 1.0, 0.95, 0.7, LEFT, [0.62], 0.74)
	_gm(G_UPPER, &"CR_GM_Uppercut", 0.25, 0.8, 0.9, 0.7, LEFT, [0.5], 0.65)
	_gm(G_DRIVE, &"CR_GM_DriveKick", 0.6, 2.0, 1.0, 1.1, KICK_LEG, [1.22], 0.83)
	_gm(G_LOWKICK, &"CR_GM_LowKick", 0.2, 0.95, 0.9, 0.6, KICK_LEG, [0.68], 0.72)
	_gm(G_FRONTKICK, &"CR_GM_FrontKick", 0.7, 1.6, 1.0, 0.8, KICK_L, [1.28], 1.0)
	_gm(G_CROSS, &"CR_GM_Cross", 0.7, 1.6, 0.9, 1.0, RIGHT, [1.07], 0.88)
	_gm(G_SIDEKICK, &"CR_GM_SideKick", 0.2, 1.1, 0.9, 0.8, KICK_L, [0.62], 0.97)
	_special(G_RING, &"CR_GM_Thorns", _gm_part(&"CR_GM_Thorns", 0.15, -1.0, 1.15))
	_special(G_STOMP, &"CR_GM_Stomp", _gm_part(&"CR_GM_Stomp", 0.0, 1.35, 1.0))
	_special(G_HURL, &"CR_GM_Hurl", _gm_part(&"CR_GM_Hurl", 0.3, -1.0, 1.0))
	_special(G_VOLLEY, &"CR_GM_QuadPunch", _gm_part(&"CR_GM_QuadPunch", 0.0, 2.0, 0.55))
	# its kicks go through a shield
	for what: int in [G_ROUNDHOUSE, G_DRIVE, G_FRONTKICK, G_SIDEKICK]:
		_kinds[what] = &"guard"
	_hand_combos = [
		{"name": &"fists_kick", "moves": [G_JABCROSS, G_ROUNDHOUSE], "fells": [1], "weight": 1.0},
		{"name": &"hook_drive", "moves": [G_HOOK, G_UPPER, G_DRIVE], "fells": [2], "weight": 1.0},
		{"name": &"low_high", "moves": [G_LOWKICK, G_FRONTKICK, G_CROSS], "fells": [2], "weight": 1.0},
		{"name": &"side_thorns", "moves": [G_SIDEKICK, G_RING], "fells": [], "weight": 0.8},
		{"name": COUNTER_COMBO, "moves": [G_RING], "fells": [], "weight": 0.0, "far": true},
	]


## Host: its own acts' moments as they come.
func _gm_run_act(delta: float) -> void:
	if act_serial != _gm_serial:
		_gm_serial = act_serial
		_gm_done = 0
	if act == G_VOLLEY and _quarry != null:
		_face(_quarry.global_position - global_position, delta, turn_speed)
	if act == G_RING and _gm_done == 0 and _act_time >= _gm_at(G_RING, 1.32):
		_gm_done = 1
		_raise_ring()
	elif act == G_STOMP and _gm_done == 0 and _act_time >= _gm_at(G_STOMP, 0.74):
		_gm_done = 1
		stones_hurled += 1
		var foot := _bone_at("R_ankle_joint")
		foot.y = global_position.y
		var key := _rng.randi()
		if is_inside_tree() and multiplayer.has_multiplayer_peer():
			net_stones_up.rpc(key, global_position, foot)
		else:
			net_stones_up(key, global_position, foot)
	elif act == G_HURL and _gm_done == 0 and _act_time >= _gm_at(G_HURL, 1.8):
		_gm_done = 1
		_stone_caught = {}
		if is_inside_tree() and multiplayer.has_multiplayer_peer():
			net_stones_hurl.rpc()
		else:
			net_stones_hurl()
	elif act == G_VOLLEY:
		while _gm_done < VOLLEY_PUNCHES.size() and _act_time >= _gm_at(G_VOLLEY, float(VOLLEY_PUNCHES[_gm_done])):
			_gm_done += 1
			_volley_shot()


## Every peer: the light gathering at its hands before the thorns, and in
## its hands before the stones are hurled.
var _lit_serial: int = -1
func _gm_fx() -> void:
	if _lit_serial == act_serial:
		return
	var world := Blood.world_of(self)
	if world == null:
		return
	if act == G_RING and _ground_clock >= _gm_at(G_RING, 1.32) - 0.45:
		_lit_serial = act_serial
		SkillFx.light(world, _hands_at(), shell_glow, 3.0, 6.0, 0.6)
	elif act == G_HURL and _ground_clock >= _gm_at(G_HURL, 0.6):
		_lit_serial = act_serial
		SkillFx.light(world, global_position + Vector3.UP * 2.2 * visual_scale / 1.8, shell_glow, 3.0, 9.0, 1.2)


func _bone_at(bone: String) -> Vector3:
	if _skeleton == null:
		return global_position + Vector3.UP * 1.5
	var b := _skeleton.find_bone(bone)
	if b < 0:
		return global_position + Vector3.UP * 1.5
	return _skeleton.global_transform * _skeleton.get_bone_global_pose(b).origin


func _hands_at() -> Vector3:
	return (_bone_at("L_wrist_joint") + _bone_at("R_wrist_joint")) * 0.5


## Host: thorns up all round it, hurting whoever stands in them (behind it too).
func _raise_ring() -> void:
	rings_raised += 1
	var at := global_position
	var id := act_serial * 1000 + 250
	var r := ring_radius * visual_scale / 1.8
	if is_inside_tree() and multiplayer.has_multiplayer_peer():
		net_ring.rpc(at, r, id)
	else:
		net_ring(at, r, id)
	_bursts.append({"at": at, "r": r, "t": 0.0, "caught": {}, "id": id, "inner": 0.0, "share": ring_share})


@rpc("authority", "call_local", "reliable")
func net_ring(at: Vector3, r: float, id: int) -> void:
	var world := Blood.world_of(self)
	if world == null:
		return
	var s := visual_scale / 1.8
	SkillFx.flash(world, _hands_at(), shell_glow, 1.2, 0.3, 4.0)
	GroundFx.spike_burst(world, at, r, 1.35 * s, 13.0, shell_glow, id)
	GroundFx.weapon_dust(world, at + _forward() * 1.5 * s, 2.0)
	var spin := randf() * TAU
	for k in 8:
		GroundCrack.show(self, at, Vector3.FORWARD.rotated(Vector3.UP, spin + TAU * k / 8.0), 9.0 * s, 16.0,
				Color(0.5, 0.3, 0.18))
	ImpactFx.thud(self, at, true)
	WindBlast.shake(self, 0.25, 0.45, 40.0)


## Every peer: stamped up — the ground split from its foot, stones out of the
## ground all round it, up into the air (by `key`, the same everywhere).
@rpc("authority", "call_local", "reliable")
func net_stones_up(key: int, at: Vector3, foot: Vector3) -> void:
	_clear_stones()
	var world := Blood.world_of(self)
	if world == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = key
	var s := visual_scale / 1.8
	_stone_state = 1
	_stone_off = 0.0
	_stone_id = key
	for k in 7:
		GroundCrack.show(self, foot, Vector3.FORWARD.rotated(Vector3.UP, TAU * k / 7.0), 3.5 * s, 14.0,
				Color(0.5, 0.3, 0.18))
	GroundFx.weapon_dust(world, foot, 2.0)
	WindBlast.shake(self, 0.28, 0.45, 40.0)
	if _stone_hot == null:
		_stone_hot = StandardMaterial3D.new()
		_stone_hot.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_stone_hot.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_stone_hot.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_stone_hot.albedo_color = Color(shell_glow, 0.07)
	for k in stone_count:
		var c := TrollRock.model(TrollRock.Kind.SMALL, k)
		world.add_child(c)
		var a := rng.randf() * TAU
		var r := rng.randf_range(1.4, stone_spread) * s
		var spot := at + Vector3(cos(a), 0.0, sin(a)) * r
		c.global_position = spot
		c.scale *= rng.randf_range(0.9, 1.35) * s
		c.material_overlay = _stone_hot
		var top := spot + Vector3.UP * rng.randf_range(0.8, 2.6) * s
		var tw := c.create_tween()
		tw.tween_interval(r / 14.0)
		if rng.randf() < 0.25:
			tw.tween_callback(func() -> void: GroundFx.weapon_dust(world, spot, 0.45))
		tw.tween_property(c, "global_position", top, 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		var ha := rng.randf() * TAU
		var vel := Vector3(cos(ha), rng.randf_range(0.02, 0.2), sin(ha)).normalized() * rng.randf_range(22.0, 30.0)
		# a trail on a third only, and some crumble in the air (fewer to draw)
		var trail := rng.randf() < 0.35
		var roll := rng.randf()
		var when := rng.randf_range(0.25, 0.55)
		_stones.append({"n": c, "tw": tw, "ph": rng.randf() * TAU, "k": rng.randf(), "v": vel, "trail": trail,
				"crumble": -1.0 if trail or roll < 0.45 else when, "t": 0.0, "live": true})


## Every peer: the stones hurled every way from round it.
@rpc("authority", "call_local", "reliable")
func net_stones_hurl() -> void:
	var world := Blood.world_of(self)
	if world == null:
		return
	var centre := global_position + Vector3.UP * 2.2 * visual_scale / 1.8
	SkillFx.flash(world, centre, shell_glow, 2.6, 0.35, 5.0)
	SkillFx.light(world, centre, shell_glow, 6.0, 12.0, 0.5)
	GroundFx.weapon_dust(world, Vector3(centre.x, global_position.y, centre.z), 2.0)
	WindBlast.shake(self, 0.35, 0.45, 40.0)
	Sfx.play_any(self, ["res://sounds/whoosh_heavy.wav"], self, 0.7, 4.0)
	_stone_state = 2
	for st in _stones:
		st.t = 0.0


var _stone_off: float = 0.0
var _hurl_serial: int = -1
var _hurl_clock: float = 0.0


## Every peer: the stones up round it (circling in as it draws them), flying,
## crumbling, falling; the host hurts whoever they meet.
func _run_stones(delta: float) -> void:
	if _stones.is_empty():
		_stone_state = 0
		return
	var world := Blood.world_of(self)
	var s := visual_scale / 1.8
	if _stone_state == 1:
		# it no longer stamps or hurls (struck reeling, cut down): they fall
		if (act != G_STOMP and act != G_HURL) or is_dead:
			_stone_off += delta
			if _stone_off > 0.3:
				for st in _stones:
					st.live = false
					st.v = Vector3(randf_range(-1.0, 1.0), 0.5, randf_range(-1.0, 1.0))
					st.crumble = randf_range(0.15, 0.45)
					st.t = 0.0
				_stone_state = 2
			return
		_stone_off = 0.0
		if act == G_HURL:
			if act_serial != _hurl_serial:
				_hurl_serial = act_serial
				_hurl_clock = 0.0
			else:
				_hurl_clock += delta
		var t := 0.3 + _hurl_clock if act == G_HURL else 0.0
		var centre := global_position + Vector3.UP * 2.2 * s
		var k := clampf((t - 0.35) / 1.35, 0.0, 1.0)
		for st in _stones:
			var c: Node3D = st.n as Node3D if is_instance_valid(st.n) else null
			if not is_instance_valid(c):
				continue
			if act != G_HURL or t < 0.35:
				c.rotate_y(0.05)
				c.rotate_x(0.03)
				continue
			if st.tw != null:
				(st.tw as Tween).kill()
				st.tw = null
			var ph := float(st.ph) + t * lerpf(1.5, 7.5, k)
			var radius := lerpf(2.8, 1.3 + float(st.k) * 0.9, k) * s
			var want := centre + Vector3(cos(ph), 0.6 * sin(ph * 1.7 + float(st.k) * 3.0), sin(ph)) * radius
			c.global_position = c.global_position.lerp(want, 1.0 - pow(1.0 - (0.04 + 0.2 * k), delta * 30.0))
			c.rotate_y(0.2)
		if act == G_HURL and t > 0.35 and Engine.get_process_frames() % 4 == 0 and world != null:
			SkillFx.burst(world, centre, shell_glow, 6, Vector2(0.5, 1.5), Vector3.UP, 180.0, Vector2(0.03, 0.05),
					Vector3.ZERO, 0.5)
		return
	if _stone_state != 2:
		return
	var host := _decides()
	var ground := global_position.y
	var frame := Engine.get_process_frames()
	for i in range(_stones.size() - 1, -1, -1):
		var st := _stones[i]
		var c: Node3D = st.n as Node3D if is_instance_valid(st.n) else null
		if not is_instance_valid(c):
			_stones.remove_at(i)
			continue
		if st.tw != null:
			(st.tw as Tween).kill()
			st.tw = null
		st.t = float(st.t) + delta
		var v: Vector3 = st.v
		v += Vector3.DOWN * 12.0 * delta
		st.v = v
		c.global_position += v * delta
		c.rotate_x(0.35)
		c.rotate_y(0.2)
		if float(st.crumble) > 0.0 and float(st.t) >= float(st.crumble):
			if world != null:
				SkillFx.burst(world, c.global_position, Color(0.6, 0.55, 0.48), 6, Vector2(0.5, 2.0), v.normalized(),
						60.0, Vector2(0.06, 0.12), Vector3(0, -3, 0), 0.5)
			c.queue_free()
			_stones.remove_at(i)
			continue
		var trail := bool(st.trail)
		if trail and world != null and (frame + i) % 4 == 0:
			SkillFx.burst(world, c.global_position, shell_glow, 3, Vector2(0.2, 0.8), -v.normalized(), 40.0,
					Vector2(0.03, 0.06), Vector3(0, 1, 0), 0.45)
			SkillFx.burst(world, c.global_position, Color(0.6, 0.55, 0.48), 2, Vector2(0.2, 0.6), -v.normalized(), 30.0,
					Vector2(0.08, 0.14), Vector3.ZERO, 0.5)
		var on_him := false
		if host and bool(st.live):
			for node in get_tree().get_nodes_in_group(&"player"):
				var who := node as Node3D
				if who == null or _stone_caught.has(who) or not who.has_method(&"receive_blow") or bool(who.get("is_dead")):
					continue
				var rel := c.global_position - who.global_position
				if rel.y < -0.2 or rel.y > 2.0 or Vector2(rel.x, rel.z).length() > 0.7:
					continue
				on_him = true
				_stone_caught[who] = true
				stones_hurt += 1
				who.call(&"receive_blow", hit_damage * stone_share * _blow_worth(G_HURL), self, 0, 3, _stone_id)
				break
		if on_him or c.global_position.y <= ground + 0.15 or float(st.t) > 2.0:
			if (trail or on_him) and world != null and float(st.t) <= 2.0:
				var at := Vector3(c.global_position.x, ground, c.global_position.z)
				GroundFx.weapon_dust(world, at, 0.8)
				SkillFx.flash(world, c.global_position, shell_glow, 0.5, 0.15, 2.5)
				TrollRock.scatter(world, at + Vector3.UP * 0.2, 3, Vector2(0.15, 0.3), Vector2(2, 5), Vector2(2, 4))
			c.queue_free()
			_stones.remove_at(i)
	if _stones.is_empty():
		_stone_state = 0


func _clear_stones() -> void:
	for st in _stones:
		if is_instance_valid(st.n):
			(st.n as Node).queue_free()
	_stones.clear()
	_stone_state = 0


## Host: a punch of the volley — air hurled from the fist that struck.
func _volley_shot() -> void:
	var f := _forward()
	var l := _bone_at("L_wrist_joint")
	var r := _bone_at("R_wrist_joint")
	var from := (l if l.dot(f) > r.dot(f) else r) + f * 0.3 * visual_scale / 1.8
	air_shots += 1
	var id := act_serial * 1000 + 400 + _gm_done
	var who := _quarry.get_path() if _quarry != null and is_instance_valid(_quarry) else NodePath()
	if is_inside_tree() and multiplayer.has_multiplayer_peer():
		net_air_shot.rpc(id, from, f, who)
	else:
		net_air_shot(id, from, f, who)


const LENS := """
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, shadows_disabled;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float strength = 0.08;
uniform float fade = 1.0;
// 0: a ball; 1: a tail, fading out to its far end (UV.y)
uniform float tail = 0.0;
void fragment() {
	float rim = clamp(1.0 - dot(NORMAL, VIEW), 0.0, 1.0);
	float along = mix(1.0, 1.0 - UV.y, tail);
	// the air churning: the bend wavers over the surface and in time
	float churn = 0.75 + 0.5 * sin(TIME * 14.0 + UV.y * 18.0 + UV.x * 25.0);
	vec2 off = NORMAL.xy * strength * (0.4 + rim) * churn * fade * along;
	// light split at the edge, as through glass
	float r = textureLod(screen_tex, SCREEN_UV - off * 1.18, 0.0).r;
	float g = textureLod(screen_tex, SCREEN_UV - off, 0.0).g;
	float b = textureLod(screen_tex, SCREEN_UV - off * 0.82, 0.0).b;
	vec3 edge = vec3(0.82, 0.93, 1.0) * pow(rim, 3.0) * 0.6 * fade * along;
	ALBEDO = vec3(r, g, b) * (1.0 + 0.18 * rim * along) + edge;
	ALPHA = clamp(fade * along * 1.3, 0.0, 1.0);
}
"""
static var _lens_shader: Shader


static func _lens_material(strength: float, tail: float) -> ShaderMaterial:
	if _lens_shader == null:
		_lens_shader = Shader.new()
		_lens_shader.code = LENS
	var m := ShaderMaterial.new()
	m.shader = _lens_shader
	m.set_shader_parameter("strength", strength)
	m.set_shader_parameter("tail", tail)
	return m


static func _along(dir: Vector3, side: float, length: float) -> Basis:
	var x := dir.cross(Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT).normalized()
	var z := x.cross(dir)
	return Basis(x * side, dir * length, z * side)


## A lens of air left where it was, swelling and fading.
func _lens_puff(world: Node, at: Vector3, dir: Vector3, from_r: float, to_r: float, life: float, power: float) -> void:
	var mi := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radial_segments = 20
	sph.rings = 10
	mi.mesh = sph
	var m := _lens_material(power, 0.0)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(mi)
	var place := func(u: float) -> void:
		var r := lerpf(from_r, to_r, 1.0 - pow(1.0 - u, 2.0)) * 2.0
		mi.global_transform = Transform3D(_along(dir, r, r * 0.7), at)
		m.set_shader_parameter("fade", 1.0 - u)
	place.call(0.0)
	var tw := mi.create_tween()
	tw.tween_method(place, 0.0, 1.0, life)
	tw.tween_callback(mi.queue_free)


## Every peer: a shot of air off its fist — a lens of air, the world bent
## through it, a tail of bent air behind; slow, turning after `who`.
@rpc("authority", "call_local", "reliable")
func net_air_shot(id: int, from: Vector3, dir: Vector3, who: NodePath) -> void:
	var world := Blood.world_of(self)
	if world == null:
		return
	var s := visual_scale / 1.8
	# the punch: stone chips off the fist, the air jolted, dust
	SkillFx.burst(world, from, Color(0.55, 0.48, 0.4), 12, Vector2(3, 6), dir, 40.0, Vector2(0.05, 0.1),
			Vector3(0, -8, 0), 0.5)
	WindBlast.kick(self, 1.8, 0.22, 40.0)
	GroundFx.weapon_dust(world, Vector3(from.x, global_position.y, from.z), 0.8)
	WindBlast.shake(self, 0.1, 0.3, 30.0)
	Sfx.play_any(self, ["res://sounds/whoosh_heavy.wav"], self, 0.9, -2.0)
	var lens := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 1.0
	sph.height = 2.0
	sph.radial_segments = 20
	sph.rings = 10
	lens.mesh = sph
	lens.material_override = _lens_material(0.11, 0.0)
	lens.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(lens)
	var tail := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.5
	cone.bottom_radius = 0.0
	cone.height = 1.0
	cone.radial_segments = 18
	cone.rings = 6
	cone.cap_top = false
	cone.cap_bottom = false
	tail.mesh = cone
	var tm := _lens_material(0.07, 1.0)
	tail.material_override = tm
	tail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(tail)
	_lens_puff(world, from, dir, 0.4 * s, 1.7 * s, 0.35, 0.1)
	WindBlast.mist(world, from, 5, 0.4, Vector2(0.6, 1.1), 0.7)
	lens.global_transform = Transform3D(_along(dir, 0.55 * s, 0.75 * s), from)
	tail.visible = false
	_shots.append({"id": id, "lens": lens, "tail": tail, "tm": tm, "p": from, "dir": dir, "t": 0.0,
			"grow": 0.0, "who": null if who.is_empty() else get_node_or_null(who), "step": 0})


## Every peer (from the host): a shot burst where it is.
@rpc("authority", "call_local", "reliable")
func net_air_end(id: int, at: Vector3) -> void:
	for i in _shots.size():
		if int(_shots[i].id) == id:
			_shots[i].p = at
			_end_shot(i)
			return


func _end_shot(i: int) -> void:
	var sh := _shots[i]
	_shots.remove_at(i)
	var world := Blood.world_of(self)
	var p: Vector3 = sh.p
	var dir: Vector3 = sh.dir
	var s := visual_scale / 1.8
	if world != null:
		_lens_puff(world, p, dir, 0.5 * s, 2.3 * s, 0.45, 0.12)
		WindBlast.mist(world, p, 8, 0.7, Vector2(0.9, 1.6), 0.8)
		GroundFx.weapon_dust(world, Vector3(p.x, global_position.y, p.z), 1.0)
	if is_instance_valid(sh.lens):
		(sh.lens as Node).queue_free()
	var tail: MeshInstance3D = sh.tail as MeshInstance3D if is_instance_valid(sh.tail) else null
	if is_instance_valid(tail):
		var tm := sh.tm as ShaderMaterial
		var tw := tail.create_tween()
		tw.tween_method(func(u: float) -> void: tm.set_shader_parameter("fade", 1.0 - u), 0.0, 1.0, 0.25)
		tw.tween_callback(tail.queue_free)


## Every peer: the shots flying, turning after him; the host hurts whoever
## one meets (a roll's untouchable frames slip it) and bursts it.
func _run_shots(delta: float) -> void:
	if _shots.is_empty():
		return
	var world := Blood.world_of(self)
	var host := _decides()
	var s := visual_scale / 1.8
	for i in range(_shots.size() - 1, -1, -1):
		var sh := _shots[i]
		sh.t = float(sh.t) + delta
		sh.step = int(sh.step) + 1
		var p: Vector3 = sh.p
		var dir: Vector3 = sh.dir
		var who: Node3D = sh.who as Node3D if is_instance_valid(sh.who) else null
		if who != null and is_instance_valid(who):
			var want := (who.global_position + Vector3.UP * 1.1 - p).normalized()
			var ang := dir.angle_to(want)
			var most := deg_to_rad(air_turn) * delta
			if ang > 0.0001:
				dir = dir.slerp(want, minf(most / ang, 1.0)).normalized()
		p += dir * air_speed * delta
		sh.p = p
		sh.dir = dir
		var beat := 1.0 + 0.06 * sin(float(sh.t) * 26.0)
		var lens: Node3D = sh.lens as Node3D if is_instance_valid(sh.lens) else null
		if is_instance_valid(lens):
			lens.global_transform = Transform3D(_along(dir, 0.55 * beat * s, 0.75 * beat * s), p)
		var grow := minf(float(sh.grow) + 4.2 * delta, 2.6) * s
		sh.grow = grow / s
		var tail: Node3D = sh.tail as Node3D if is_instance_valid(sh.tail) else null
		if is_instance_valid(tail):
			tail.visible = true
			tail.global_transform = Transform3D(_along(dir, s, grow), p - dir * (grow * 0.5 + 0.2 * s))
		if world != null and int(sh.step) % 2 == 0:
			SkillFx.particles(world, p - dir * 0.6 * s, {"amount": 5, "life": 0.6, "one_shot": true, "explosiveness": 1.0,
				"speed": Vector2(0.4, 1.4), "dir": -dir, "spread": 35.0, "size": Vector2(0.02, 0.04), "grow": 0.2,
				"sphere": 0.35, "tangent": 6.0,
				"colors": [Color(0.9, 0.96, 1.0, 0.0), Color(0.9, 0.96, 1.0, 0.8), Color(0.9, 0.96, 1.0, 0.0)]})
		if world != null and int(sh.step) % 4 == 0:
			GroundFx.weapon_dust(world, Vector3(p.x, global_position.y, p.z), 0.3)
		if not host:
			# (the host ends it; a safety if its word never comes)
			if float(sh.t) > air_life + 0.6:
				_end_shot(i)
			continue
		var hit: Node3D = null
		for node in get_tree().get_nodes_in_group(&"player"):
			var h := node as Node3D
			if h == null or not h.has_method(&"receive_blow") or bool(h.get("is_dead")):
				continue
			if (h.global_position + Vector3.UP * 1.1).distance_to(p) > 0.8 * s + 0.2:
				continue
			if h.has_method(&"is_evading") and bool(h.call(&"is_evading")):
				continue
			hit = h
			break
		if hit != null:
			air_hurt += 1
			hit.call(&"receive_blow", hit_damage * air_share * _blow_worth(G_VOLLEY), self, 0, 2, int(sh.id))
			WindBlast.shake(self, 0.12, 0.3, 30.0)
		if hit != null or float(sh.t) >= air_life:
			if is_inside_tree() and multiplayer.has_multiplayer_peer():
				net_air_end.rpc(int(sh.id), p)
			else:
				net_air_end(int(sh.id), p)


## Every peer: its fists swollen and glowing through the volley.
func _show_swell() -> void:
	if _swell.is_empty():
		return
	var k := 0.0
	if act == G_VOLLEY and not is_dead and _moves_table.has(G_VOLLEY):
		var t := _ground_clock * float(_moves_table[G_VOLLEY][1])
		k = clampf((t - VOLLEY_SWELL.x) / 0.3, 0.0, 1.0) * (1.0 - clampf((t - VOLLEY_SWELL.y) / 0.35, 0.0, 1.0))
	var world := Blood.world_of(self)
	for side: String in _swell:
		(_swell[side] as BoneHide).shown = lerpf(1.0, 1.7, k)
		var l := _swell_lights.get(side) as OmniLight3D
		if l == null:
			if k <= 0.0:
				continue
			l = OmniLight3D.new()
			l.light_color = shell_glow
			l.omni_range = 3.0
			l.top_level = true
			add_child(l)
			_swell_lights[side] = l
		l.visible = k > 0.01
		l.light_energy = 2.5 * k
		l.global_position = _bone_at(side + "_wrist_joint")
		if k > 0.5 and world != null and Engine.get_process_frames() % 3 == 0:
			SkillFx.burst(world, l.global_position, shell_glow, 3, Vector2(0.3, 1.0), Vector3.UP, 90.0,
					Vector2(0.025, 0.045), Vector3(0, 1.0, 0), 0.5)


func _exit_tree() -> void:
	_clear_stones()
	for sh in _shots:
		for n in [sh.lens, sh.tail]:
			if is_instance_valid(n):
				(n as Node).queue_free()
	_shots.clear()
#endregion


#region Round 3: the fist thrown
## Host: its fist off its arm at him, aimed at where he will be.
func _throw_fist() -> void:
	if _quarry == null:
		return
	fists_thrown += 1
	var from := _palm()
	var aim := _quarry.global_position + Vector3.UP * 1.2
	if _quarry is CharacterBody3D:
		var v := (_quarry as CharacterBody3D).velocity
		aim += Vector3(v.x, 0.0, v.z) * clampf(from.distance_to(aim) / fist_speed, 0.0, 0.6)
	var dir := (aim - from).normalized()
	if is_inside_tree() and multiplayer.has_multiplayer_peer():
		net_fist.rpc(Fist.OUT, from, dir)
	else:
		net_fist(Fist.OUT, from, dir)


## Every peer: the fist's flight begun, or turned about (`state`), from `at`.
@rpc("authority", "call_local", "reliable")
func net_fist(state: int, at: Vector3, dir: Vector3) -> void:
	var was := _fist_state
	_fist_state = state
	_fist_pos = at
	if state == Fist.OUT:
		_fist_dir = dir
		_fist_went = 0.0
		var world := Blood.world_of(self)
		Sfx.play_any(self, ["res://sounds/whoosh_heavy.wav"], self, 0.75, 2.0)
		WindBlast.speed_lines(world, at, dir, 6.0, 14)
		SkillFx.burst(world, at, shell_glow, 18, Vector2(1.0, 4.0), -dir, 50.0, Vector2(0.03, 0.06), Vector3.ZERO, 0.5)
	elif state == Fist.HOLDING:
		ImpactFx.strike(self, at, &"stone", 1.6)
		SkillFx.burst(Blood.world_of(self), at, Color(0.42, 0.4, 0.38), 20, Vector2(1.5, 5.0), Vector3.UP, 180.0,
				Vector2(0.05, 0.12), Vector3(0, -12.0, 0), 0.8)
	elif state == Fist.NONE and was != Fist.NONE:
		# back on its arm
		ImpactFx.thud(self, at, false)
		SkillFx.burst(Blood.world_of(self), at, shell_glow, 14, Vector2(0.5, 2.0), Vector3.UP, 180.0,
				Vector2(0.03, 0.06), Vector3.ZERO, 0.4)


## Host: the fist flying out, catching him, coming back with him or without.
func _fly_fist(delta: float) -> void:
	if _fist_state == Fist.NONE:
		return
	if _fist_state == Fist.OUT:
		var step := fist_speed * delta
		_fist_pos += _fist_dir * step
		_fist_went += step
		for node in get_tree().get_nodes_in_group(&"player"):
			var who := node as Player
			if who == null or who.is_dead:
				continue
			var chest := who.global_position + Vector3.UP * 1.1
			if chest.distance_to(_fist_pos) > 1.25:
				continue
			# a roll's untouchable frames slip it
			if who.is_evading():
				continue
			_fist_held = who
			fists_caught += 1
			who.grab_by(self, 4.0)
			_send_fist(Fist.HOLDING)
			return
		var ground := global_position.y
		if _fist_went >= fist_range or _fist_pos.y < ground + 0.3:
			_send_fist(Fist.BACK)
		return
	# back to its arm (with him, to just in front of it)
	var home := _palm()
	var to := home - _fist_pos
	var stop := 0.4
	if _fist_state == Fist.HOLDING:
		home = global_position + _forward() * 2.4 * visual_scale / 1.8 + Vector3.UP * 1.6
		to = home - _fist_pos
		stop = 0.3
	var d := to.length()
	var step := fist_back * delta
	if d <= maxf(stop, step):
		_fist_pos = home
		var held := _fist_held
		_fist_held = null
		_send_fist(Fist.NONE)
		if held != null and is_instance_valid(held):
			held.release_grab()
			# and the combo on him at once
			var c := _combo_index(REEL_COMBO)
			if c >= 0 and not is_dead:
				start_hand_combo(c)
		return
	_fist_pos += to / d * step


func _send_fist(state: int) -> void:
	if is_inside_tree() and multiplayer.has_multiplayer_peer():
		net_fist.rpc(state, _fist_pos, _fist_dir)
	else:
		net_fist(state, _fist_pos, _fist_dir)


## Where its palm is (its right hand's middle finger root).
func _palm() -> Vector3:
	if _skeleton == null:
		return global_position + Vector3.UP * 2.0 * visual_scale / 1.8
	var b := _skeleton.find_bone("R_midFinger_joint1")
	if b < 0:
		b = _skeleton.find_bone("R_wrist_joint")
	if b < 0:
		return global_position + Vector3.UP * 2.0 * visual_scale / 1.8
	return _skeleton.global_transform * _skeleton.get_bone_global_pose(b).origin


## [Player] `grab_by`: he hangs from its flying fist (kept up off the ground).
func grab_point() -> Vector3:
	var at := _fist_pos if _fist_state != Fist.NONE else _palm()
	at.y = maxf(at.y, global_position.y + 1.65)
	return at


## Every peer: the fist, its glowing tether to the arm, the hand gone from the arm.
func _show_fist(delta: float) -> void:
	if _hide_hand != null:
		_hide_hand.shown = move_toward(_hide_hand.shown, 0.0 if _fist_state != Fist.NONE else 1.0, delta * 12.0)
	if _fist_state == Fist.NONE:
		if _fist_mesh != null:
			_fist_mesh.visible = false
			_tether.visible = false
		return
	if not _decides():
		# the other peers fly it the same way
		if _fist_state == Fist.OUT:
			_fist_pos += _fist_dir * fist_speed * delta
		else:
			var home := _palm() if _fist_state == Fist.BACK else \
					global_position + _forward() * 2.4 * visual_scale / 1.8 + Vector3.UP * 1.6
			_fist_pos = _fist_pos.move_toward(home, fist_back * delta)
	var world := Blood.world_of(self)
	if world == null:
		return
	if _fist_mesh == null:
		_fist_mesh = Node3D.new()
		_fist_mesh.name = "GolemFist"
		_fist_mesh.top_level = true
		var rock := MeshInstance3D.new()
		rock.mesh = RockWave._crag_mesh(1)
		rock.material_override = RockWave._crag_material()
		var glow := StandardMaterial3D.new()
		glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		glow.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		glow.albedo_color = Color(shell_glow, 0.35)
		glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		rock.material_overlay = glow
		rock.scale = Vector3.ONE * 0.55 * visual_scale / 1.8
		_fist_mesh.add_child(rock)
		var light := OmniLight3D.new()
		light.light_color = shell_glow
		light.light_energy = 1.6
		light.omni_range = 3.0
		_fist_mesh.add_child(light)
		add_child(_fist_mesh)
		_tether = MeshInstance3D.new()
		_tether.name = "GolemTether"
		_tether.top_level = true
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.05
		cyl.bottom_radius = 0.05
		cyl.height = 1.0
		cyl.radial_segments = 6
		_tether.mesh = cyl
		var tm := StandardMaterial3D.new()
		tm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		tm.albedo_color = shell_glow
		_tether.material_override = tm
		add_child(_tether)
	_fist_mesh.visible = true
	_fist_mesh.global_position = _fist_pos
	_fist_mesh.rotate_y(delta * 9.0)
	var arm := _wrist()
	var span := _fist_pos - arm
	var len := span.length()
	_tether.visible = len > 0.3
	if len > 0.3:
		var up := span / len
		var side := up.cross(Vector3.UP if absf(up.y) < 0.95 else Vector3.RIGHT).normalized()
		var basis := Basis(side, up, side.cross(up)).orthonormalized()
		_tether.global_transform = Transform3D(basis.scaled(Vector3(1.0, len, 1.0)), arm + span * 0.5)
	if _fist_state == Fist.OUT and Engine.get_process_frames() % 3 == 0:
		SkillFx.burst(world, _fist_pos, shell_glow, 3, Vector2(0.2, 0.8), -_fist_dir, 40.0,
				Vector2(0.03, 0.05), Vector3.ZERO, 0.35)


func _wrist() -> Vector3:
	if _skeleton == null:
		return global_position + Vector3.UP * 2.0
	var b := _skeleton.find_bone("R_elbow_joint")
	var w := _skeleton.find_bone("R_wrist_joint")
	if b < 0 or w < 0:
		return _palm()
	# the stump: the wrist as the arm has it (the hand shrunk away)
	var e := _skeleton.global_transform * _skeleton.get_bone_global_pose(b).origin
	var r := _skeleton.global_transform * _skeleton.get_bone_global_pose(w).origin
	return e.lerp(r, 0.9)
#endregion


#region Round 3: the thorn field
## Host: each spot of the field: marked under him (glowing), then bursting.
func _run_fields(delta: float) -> void:
	for i in range(_fields.size() - 1, -1, -1):
		var f := _fields[i]
		f.t = float(f.t) + delta
		if float(f.t) < 0.0:
			continue
		if not bool(f.marked):
			f.marked = true
			var at := global_position
			if _quarry != null and is_instance_valid(_quarry):
				at = _quarry.global_position
			at.y = global_position.y if absf(at.y - global_position.y) > 3.0 else at.y
			f.at = at
			if is_inside_tree() and multiplayer.has_multiplayer_peer():
				net_field_mark.rpc(at)
			else:
				net_field_mark(at)
			continue
		if float(f.t) >= field_tell and not bool(f.get("burst", false)):
			f.burst = true
			if is_inside_tree() and multiplayer.has_multiplayer_peer():
				net_field_burst.rpc(f.at, int(f.id))
			else:
				net_field_burst(f.at, int(f.id))
			for node in get_tree().get_nodes_in_group(&"player"):
				var who := node as Node3D
				if who == null or not who.has_method(&"receive_blow") or bool(who.get("is_dead")):
					continue
				var rel := who.global_position - (f.at as Vector3)
				if absf(rel.y) > 0.9 or Vector2(rel.x, rel.z).length() > field_radius * 0.9:
					continue
				bursts_hurt += 1
				who.call(&"receive_blow", hit_damage * field_share, self, 0, 1, int(f.id), false, &"spike")
		if float(f.t) > field_tell + 0.3:
			_fields.remove_at(i)


## Every peer: the ground under him glowing, cracking — a moment to get off it.
@rpc("authority", "call_local", "reliable")
func net_field_mark(at: Vector3) -> void:
	var world := Blood.world_of(self)
	if world == null:
		return
	var crack := DarkFx.decal(world, at, DarkFx.CRACK, field_radius * 1.6, Color(0.09, 0.07, 0.05, 1.0), 0.0, 0.9)
	crack.rotation.y = randf() * TAU
	var tw := crack.create_tween()
	tw.tween_interval(field_tell + 1.5)
	tw.tween_property(crack, "modulate:a", 0.0, 1.0)
	tw.tween_callback(crack.queue_free)
	SkillFx.light(world, at + Vector3.UP * 0.3, shell_glow, 2.2, field_radius * 1.4, field_tell + 0.2)
	SkillFx.burst(world, at + Vector3.UP * 0.1, shell_glow, 16, Vector2(0.3, 1.6), Vector3.UP, 60.0,
			Vector2(0.03, 0.06), Vector3(0, 1.0, 0), field_tell)
	Sfx.play_any(self, ["res://sounds/ogre/club_ground_2.wav"], null, 0.6, -6.0)


@rpc("authority", "call_local", "reliable")
func net_field_burst(at: Vector3, id: int) -> void:
	var world := Blood.world_of(self)
	GroundFx.spike_burst(world, at, field_radius, 1.1, 22.0, shell_glow, id)
	ImpactFx.thud(self, at, true)
	WindBlast.shake(self, 0.08, 0.3, 14.0)
#endregion


#region Round 3: its maul, risen again
## Its maul's moves (every peer has them; used once it is armed).
func _maul_moves() -> void:
	var w := "R_wrist_joint>R_wrist_joint@0,0.9,0:0.5"
	_hand_move(W_H1, &"CR_Heavy1", Vector3(1.2, 0.0, 0.85), 0.9, w)
	_hand_move(W_H2, &"CR_Heavy2", Vector3(1.1, 0.0, 0.85), 1.4, w)
	_hand_move(W_H3, &"CR_Heavy3", Vector3(1.2, 0.0, 0.85), 1.0, w)
	_hand_move(W_H4, &"CR_Heavy4", Vector3(1.3, 0.0, 0.88), 1.5, w)
	_hand_move(W_LOW, &"CR_LowAttack", Vector3(1.2, 0.0, 0.85), 1.0, w)
	_hand_move(W_HIGH, &"CR_HighAttack", Vector3(1.2, 0.0, 0.85), 1.0, w)
	_hand_move(W_SPIN, &"CR_GS_HighSpin", Vector3(1.2, 0.0, 0.85), 1.1, w)
	var peaks: Array = []
	if _anim != null:
		for pk in _anim.measure_peaks(&"CR_HeavyCombo", PackedStringArray(["R_wrist_joint"]), 0.35, 0.12):
			if pk >= 0.04 and pk <= 0.9:
				peaks.append(pk)
	while peaks.size() > 4:
		peaks.remove_at(0)
	_hand_move(W_COMBO, &"CR_HeavyCombo", Vector3(1.2, 0.0, 0.92), 0.6, w, peaks)
	_kinds[W_H2] = &"crush"
	_kinds[W_H4] = &"crush"
	_windups[W_H2] = [1.3, 0.2]
	_snap[W_H2] = 1.5
	for what: int in [W_LOW, W_HIGH]:
		_holds[what] = [0.35, 0.35, 0.7, 0.25]


## Every peer: risen again, the stone of the ground flies into its hand as a
## maul; the host gives it the maul's strings.
func _arm_maul() -> void:
	armed = true
	idle_clip = &"CR_HeavyIdle"
	guard_idle_clip = &"CR_HeavyIdle"
	walk_clip = &"CR_HeavyWalk"
	back_clip = &"CR_HeavyBack"
	strafe_l_clip = &"CR_HeavyL"
	strafe_r_clip = &"CR_HeavyR"
	_forge_maul()
	if not _decides():
		return
	hand_combo_chance = Vector2(0.85, 0.9)
	_hand_last = -1
	_hand_combos = [
		{"name": &"maul_crush", "moves": [W_H1, W_H3, W_H2], "fells": [2], "weight": 1.0},
		{"name": &"maul_storm", "moves": [W_COMBO], "fells": [0], "weight": 0.9},
		{"name": &"maul_spin", "moves": [W_SPIN, W_H4], "fells": [1], "weight": 0.9},
		{"name": &"maul_low", "moves": [W_LOW, W_HIGH, W_H2], "fells": [2], "weight": 0.9},
		{"name": &"maul_quick", "moves": [W_H1, W_H3, W_H1], "fells": [2], "weight": 0.8},
		{"name": COUNTER_COMBO, "moves": [G_SHOVE, W_H3], "fells": [1], "weight": 0.0, "far": true},
		{"name": QUAKE_COMBO, "moves": [W_H4], "fells": [0], "weight": 1.0, "far": true},
		{"name": RAM_COMBO, "moves": [G_RAM, W_H1, W_H2], "fells": [2], "weight": 1.0, "far": true},
		{"name": REEL_COMBO, "moves": [W_H1, W_H2], "fells": [1], "weight": 0.0, "far": true},
	]


## Every peer: the maul made — chunks of the ground fly up into its hand.
func _forge_maul() -> void:
	var world := Blood.world_of(self)
	if world == null or _skeleton == null:
		return
	var hold := BoneAttachment3D.new()
	hold.name = "GolemMaulHold"
	hold.bone_name = "R_wrist_joint"
	_skeleton.add_child(hold)
	_maul = Node3D.new()
	_maul.name = "GolemMaul"
	hold.add_child(_maul)
	# (laid along its grip each frame; what is in it grows into its hand)
	var body := Node3D.new()
	body.name = "Body"
	_maul.add_child(body)
	# its own grey stone (the ground's crags are earth-brown)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.56, 0.6, 0.62)
	mat.roughness = 1.0
	var handle := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.07
	cyl.bottom_radius = 0.085
	cyl.height = 1.3
	cyl.radial_segments = 7
	handle.mesh = cyl
	handle.material_override = mat
	handle.position = Vector3(0.0, 0.2, 0.0)
	body.add_child(handle)
	var head := MeshInstance3D.new()
	head.mesh = RockWave._crag_mesh(2)
	head.material_override = mat
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow.albedo_color = Color(shell_glow, 0.07)
	head.material_overlay = glow
	head.scale = Vector3(0.7, 0.46, 0.46)
	head.position = Vector3(0.0, 0.92, 0.0)
	head.rotation = Vector3(0.0, 0.0, PI * 0.5)
	body.add_child(head)
	# a second stone bound on it: a rough head, not a block
	var lump := MeshInstance3D.new()
	lump.mesh = RockWave._crag_mesh(0)
	lump.material_override = mat
	lump.scale = Vector3(0.42, 0.36, 0.5)
	lump.position = Vector3(0.0, 0.98, 0.08)
	body.add_child(lump)
	body.scale = Vector3.ONE * 0.05
	# the chunks flying up into its hand
	var hand := _palm()
	for i in 9:
		var a := TAU * float(i) / 9.0 + randf_range(-0.2, 0.2)
		var from := global_position + Vector3(cos(a), 0.0, sin(a)) * randf_range(1.8, 3.2)
		var chunk := MeshInstance3D.new()
		chunk.mesh = RockWave._crag_mesh(i % RockWave.SHAPES)
		chunk.material_override = mat
		chunk.scale = Vector3.ONE * randf_range(0.18, 0.3)
		chunk.top_level = true
		add_child(chunk)
		chunk.global_position = from
		var tw := chunk.create_tween()
		tw.tween_interval(0.08 * i)
		var fly := func(k: float) -> void:
			var to := _palm()
			chunk.global_position = from.lerp(to, k * k) + Vector3.UP * sin(k * PI) * 1.4
			chunk.rotate_x(0.2)
		tw.tween_method(fly, 0.0, 1.0, 0.75)
		tw.tween_callback(chunk.queue_free)
		SkillFx.burst(world, from, Color(0.45, 0.39, 0.31, 0.65), 6, Vector2(0.8, 2.5), Vector3.UP, 60.0,
				Vector2(0.06, 0.14), Vector3(0, -6.0, 0), 0.7)
	var grow := body.create_tween()
	grow.tween_interval(1.45)
	grow.tween_property(body, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	grow.tween_callback(_maul_made)
	SkillFx.light(world, hand, shell_glow, 2.5, 5.0, 1.8)


func _maul_made() -> void:
	SkillFx.burst(Blood.world_of(self), _palm(), shell_glow, 30, Vector2(1.0, 4.0), Vector3.UP, 180.0,
			Vector2(0.03, 0.07), Vector3.ZERO, 0.6)
	ImpactFx.strike(self, _palm(), &"stone", 1.8)
	WindBlast.shake(self, 0.1, 0.35, 16.0)


## Every peer: the maul laid along its grip — the line from its left hand to
## its right while both hold it (learnt in its right hand's own frame), the
## head out past its right hand; its blows reach to the head.
func _show_maul(_delta: float) -> void:
	if not armed and act == REFORM and not is_dead:
		_arm_maul()
	if _maul == null or _skeleton == null:
		return
	var r := _skeleton.find_bone("R_wrist_joint")
	var l := _skeleton.find_bone("L_wrist_joint")
	if r < 0 or l < 0:
		return
	var rp := _skeleton.get_bone_global_pose(r)
	var lp := _skeleton.get_bone_global_pose(l)
	var span := rp.origin - lp.origin
	if span.length() < 0.42 and span.length() > 0.05:
		var local := (rp.basis.inverse() * span).normalized()
		_grip_local = local if not _grip_learnt else _grip_local.slerp(local, 0.08).normalized()
		if not _grip_learnt:
			_grip_learnt = true
			# its blows out to the maul's head
			for what: int in WEAPON_MOVES:
				for st: Array in _limbs_of.get(what, []):
					st[2] = _grip_local * 0.92
	if not _grip_learnt:
		return
	var up := _grip_local
	var side := up.cross(Vector3.FORWARD if absf(up.z) < 0.9 else Vector3.RIGHT).normalized()
	_maul.transform = Transform3D(Basis(side, up, side.cross(up)).orthonormalized(), Vector3.ZERO)
#endregion
