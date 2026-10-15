class_name TrollFighter
extends PackBrute

## The troll (Polysplit's Biped Creatures, CREATURES_PACK.md): big, bare
## fists, and hard to keep down (the user's picks, 2026-10-07).
##
## * **A boulder.** From `hurl_from` to `hurl_to` off, now and then, it tears
##   a boulder out of the ground (`CR_Harvest`) and hurls it at him
##   (`CR_Throw`, [GoblinShot] BOULDER): it throws down whoever it meets, and
##   bursts into rubble where it lands. A shield takes it, at a cost.
## * **The leap** ([PackBrute]): it springs at him from off and comes down
##   with both fists, and the ground shakes where it lands (`leap_quake`).
## * **Its wounds close.** It wins back `regen` of its health a second, the
##   wounds seen closing (green motes rising off it); fire or frost on it
##   (burning or chilled, [Afflictions]) stops that for `regen_stopped` s.
##
## **Its way of fighting** (2026-10-15, the user's word: the troll and the
## golem must fight each their own way, nothing alike) — a feral pouncer,
## quick and never still, everything the golem is not:
## * on all fours from off (`CR_CrawlRun`), fast, and springing at him;
## * long, quick strings — claws, a bite, knee, kicks, fists — 4–6 blows;
## * a hop aside from his swings (`dash_chance`);
## * its bite closes its wounds (`bite_heal` of its health);
## * badly hurt it goes berserk (`rage_at`): quicker still, harder;
## * easily jolted, but straight back at him.

@export_group("Boulder")
@export var pick_clip: StringName = &"CR_Harvest"
@export var pick_part: Vector3 = Vector3(1.5, 0.12, 0.5)
@export var hurl_clip: StringName = &"CR_Throw"
@export var hurl_part: Vector3 = Vector3(1.1, 0.0, 0.85)
@export var hurl_from: float = 6.0
@export var hurl_to: float = 20.0
@export var hurl_cooldown: Vector2 = Vector2(6.0, 10.0)
@export var boulder_share: float = 1.1

@export_group("Feral")
## Its bite closes this share of its wounds.
@export var bite_heal: float = 0.05
## On all fours past this pace (m/s).
@export var crawl_clip: StringName = &"CR_CrawlRun"
@export_group("Regeneration")
## Share of its health won back a second.
@export var regen: float = 0.012
@export var regen_stopped: float = 6.0
@export var regen_tint: Color = Color(0.45, 1.0, 0.35)

const PICK := 116
const HURL := 117
## Its combos' moves (2026-10-10; made its own 2026-10-15 — no ogre's, none
## the golem's).
const T_PUNCH := 180
const T_PUNCH_L := 181
const T_UPPER := 182
const T_SCRATCH := 187
const T_BITE := 188
const T_KNEE := 189
const T_KICK := 190
const T_SPARTA := 191
const T_PCOMBO := 192
const T_JUMPUP := 193
const CLAWS := "L_elbow_joint>L_midFinger_joint3:0.16|R_elbow_joint>R_midFinger_joint3:0.16"
const MOUTH := "head_joint>head_joint@0.11,0.13,0:0.3"
const KNEES := "L_thigh_joint>L_knee_joint:0.22|R_thigh_joint>R_knee_joint:0.22"
const SHINS := "L_knee_joint>L_toe_joint:0.15|R_knee_joint>R_toe_joint:0.15"

var _hurl_wait: float = 3.0
var _hurled: bool = false
var _hurl_at: float = 0.5
var _hand: int = -1
## Every peer: the boulder in its hands, from the pick until it is thrown.
var _held: MeshInstance3D
var _held_serial: int = -1
var _held_clock: float = 0.0
## Host: seconds its wounds are still kept from closing.
var _stopped_for: float = 0.0
## Replicated (net_regen): its wounds closing now.
var healing: bool = false
var _mote_clock: float = 0.0
var _heal_glow: StandardMaterial3D
var _heal_shown: bool = false
## Host: bites that closed its wounds (the tests).
var bites_healed: int = 0


func _ready() -> void:
	# never still: on all fours when it runs, and a hop aside from his swings
	if crawl_clip != &"":
		run_clip = crawl_clip
		if not Array(loop_clips).has(String(crawl_clip)):
			loop_clips = PackedStringArray(Array(loop_clips) + [String(crawl_clip)])
	chase_speed = maxf(chase_speed, 6.2)
	close_speed = maxf(close_speed, 5.0)
	dash_chance = maxf(dash_chance, 0.35)
	dash_clip = &"CR_Dodge"
	# badly hurt, berserk: quicker still and harder (a howl, CR_Surprise)
	if rage_at <= 0.0:
		rage_at = 0.35
		rage_clip = &"CR_Surprise"
		rage_part = Vector3(1.4, 0.0, 0.6)
		rage_pace = 1.3
	hand_tail = minf(hand_tail, 0.2)
	super()
	_set_combos()
	_special(PICK, pick_clip, pick_part)
	_special(HURL, hurl_clip, hurl_part)
	if _skeleton != null:
		_hand = _skeleton.find_bone("R_wrist_joint")
	if _anim != null:
		var m: Array = _moves_table[HURL]
		var length := _anim.clip_length(m[0])
		var best := -1.0
		for p in _anim.measure_peaks(m[0], PackedStringArray(["R_wrist_joint"]), 0.5, 0.08):
			if p >= float(m[2]) and p <= float(m[3]):
				best = p
		if best < 0.0:
			best = lerpf(float(m[2]), float(m[3]), 0.5)
		_hurl_at = (best - float(m[2])) * length / maxf(float(m[1]), 0.01)
	_hurl_wait = _rng.randf_range(2.0, hurl_cooldown.x)


## Its combos made by hand ([PackBrute] `_hand_combos`): long and quick —
## claws raking, the bite, a jumping uppercut; fists, a knee, the kick that
## throws him; fists, claws, a kick and the uppercut (enraged, more claws).
func _set_combos() -> void:
	var both := (FIST_L + "|" + FIST_R) % ["0.14", "0.14"]
	_hand_move(T_PUNCH, &"CR_Punch1", Vector3(1.1, 0.0, 0.85), 0.4, FIST_R % "0.14")
	_hand_move(T_PUNCH_L, &"CR_PunchL", Vector3(1.1, 0.0, 0.85), 0.4, FIST_L % "0.14")
	_hand_move(T_UPPER, &"CR_Uppercut", Vector3(1.0, 0.0, 0.9), 1.0, both)
	_peaks_hand(T_SCRATCH, &"CR_ZombieScratch", Vector3(1.15, 0.05, 0.9), 0.35, CLAWS, 3,
			["L_wrist_joint", "R_wrist_joint"])
	_hand_move(T_BITE, &"CR_ZombieBite", Vector3(1.15, 0.05, 0.85), 0.5, MOUTH)
	_hand_move(T_KNEE, &"CR_Knee", Vector3(1.0, 0.0, 0.9), 0.45, KNEES)
	_hand_move(T_KICK, &"CR_Kick2", Vector3(1.05, 0.0, 0.9), 0.5, SHINS)
	_hand_move(T_SPARTA, &"CR_SpartaKick", Vector3(1.0, 0.1, 0.85), 0.9, SHINS)
	_kinds[T_SPARTA] = &"guard"
	# (its fists close in a flurry, a wider reach so none slips past him)
	_peaks_hand(T_PCOMBO, &"CR_PunchCombo", Vector3(1.1, 0.02, 0.92), 0.35,
			(FIST_L + "|" + FIST_R) % ["0.22", "0.22"], 3,
			["L_wrist_joint", "R_wrist_joint"])
	_hand_move(T_JUMPUP, &"CR_Punch2", Vector3(1.0, 0.05, 0.9), 1.0, both)
	_hand_combos = [
		{"name": &"frenzy_claws", "moves": [T_SCRATCH, T_BITE, T_JUMPUP], "fells": [2], "weight": 1.2,
				"rage": [T_SCRATCH]},
		{"name": &"brawl", "moves": [T_PCOMBO, T_KNEE, T_SPARTA], "fells": [2], "weight": 1.0},
		{"name": &"hounding", "moves": [T_PUNCH, T_PUNCH_L, T_SCRATCH, T_KICK, T_UPPER], "fells": [4],
				"weight": 1.0},
		{"name": &"maul", "moves": [T_BITE, T_SCRATCH, T_PUNCH, T_PUNCH_L, T_SPARTA], "fells": [4], "weight": 0.8,
				"rage_only": true},
	]


## A move of several blows, its blows where `bones` move fastest (the last
## `most` of them in its part).
func _peaks_hand(what: int, clip: StringName, part: Vector3, share: float, limbs: String, most: int,
		bones: Array) -> void:
	var peaks: Array = []
	if _anim != null:
		for p in _anim.measure_peaks(clip, PackedStringArray(bones), 0.3, 0.1):
			if p >= part.y + 0.02 and p <= part.z - 0.02:
				peaks.append(p)
	while peaks.size() > most:
		peaks.remove_at(0)
	_hand_move(what, clip, part, share, limbs, peaks)


## Host: its teeth in him — its own wounds close by it.
func _blow_reached(who: Node3D, what: int) -> void:
	super(who, what)
	if what != T_BITE or is_dead:
		return
	health = minf(health + max_health * bite_heal, max_health)
	bites_healed += 1
	if is_inside_tree() and multiplayer.has_multiplayer_peer():
		net_bite.rpc()
	else:
		net_bite()


## Every peer: blood off its teeth, its wounds seen closing.
@rpc("authority", "call_local", "reliable")
func net_bite() -> void:
	var world := Blood.world_of(self)
	var mouth := global_position + Vector3.UP * 2.0 * visual_scale
	if _skeleton != null and _skeleton.find_bone("head_joint") >= 0:
		mouth = _skeleton.global_transform * _skeleton.get_bone_global_pose(_skeleton.find_bone("head_joint")).origin
	SkillFx.burst(world, mouth, Color(0.55, 0.03, 0.02), 14, Vector2(1.0, 3.0), Vector3.UP, 90.0,
			Vector2(0.03, 0.06), Vector3(0, -9.0, 0), 0.6)
	SkillFx.burst(world, global_position + Vector3.UP * 1.4 * visual_scale, regen_tint, 22, Vector2(0.4, 1.4),
			Vector3.UP, 60.0, Vector2(0.05, 0.1), Vector3(0, 1.6, 0), 1.0)


func _own_move(delta: float) -> bool:
	_hurl_wait = maxf(_hurl_wait - delta, 0.0)
	var gap := _distance_to(_quarry)
	if _hurl_wait <= 0.0 and gap >= hurl_from and gap <= hurl_to and not _quarry_down() \
			and stamina >= attack_cost:
		mode = Mode.FIGHT
		_face(_quarry.global_position - global_position, 1.0, 50.0)
		_begin(PICK)
		return true
	return super(delta)


func _after(what: int) -> void:
	if what == PICK:
		# Up with it, and at him.
		if _quarry != null:
			_face(_quarry.global_position - global_position, 1.0, 50.0)
		_hurled = false
		_begin(HURL)
		return
	if what == HURL:
		_hurl_wait = _rng.randf_range(hurl_cooldown.x, hurl_cooldown.y)
	super(what)


func _run_act(delta: float) -> void:
	super(delta)
	if is_dead or not _decides():
		return
	if act == HURL:
		if _quarry != null and _act_time < _hurl_at:
			_face(_quarry.global_position - global_position, delta, turn_speed * 2.0)
		if not _hurled and _act_time >= _hurl_at:
			_hurled = true
			_release()


## Host: the boulder out of its hands, on an arc onto where he will be.
func _release() -> void:
	if _quarry == null:
		return
	var from := _hand_at() + Vector3.UP * 0.2
	var target := _quarry.global_position + Vector3.UP * 0.9
	var gap := Vector3(target.x - from.x, 0.0, target.z - from.z).length()
	var flight := clampf(gap / 16.0, 0.4, 1.2)
	if _quarry is CharacterBody3D:
		var v := (_quarry as CharacterBody3D).velocity
		target += Vector3(v.x, 0.0, v.z) * flight * 0.5
	var throw_v := (target - from) / flight + Vector3.UP * 0.5 * GoblinShot.GRAVITY * flight
	var worth := hit_damage * boulder_share * _blow_worth(HURL)
	if is_inside_tree() and multiplayer.has_multiplayer_peer():
		net_hurl.rpc(from, throw_v, worth, act_serial)
	else:
		net_hurl(from, throw_v, worth, act_serial)


@rpc("authority", "call_local", "reliable")
func net_hurl(from: Vector3, v: Vector3, worth: float, id: int) -> void:
	_show_held(false)
	GoblinShot.throw(Blood.world_of(self), from, v, GoblinShot.Kind.BOULDER, worth, self, _decides(), id * 100 + 7)


func _hand_at() -> Vector3:
	if _skeleton != null and _hand >= 0:
		return _skeleton.global_transform * _skeleton.get_bone_global_pose(_hand).origin
	return global_position + Vector3.UP * 2.0 * visual_scale


#region Every peer: the boulder in its hand, the wounds closing
func _process(delta: float) -> void:
	super(delta)
	if act_serial != _held_serial:
		_held_serial = act_serial
		_held_clock = 0.0
		if act == PICK:
			# Torn out of the ground in front of it.
			var at := global_position + _forward() * 0.9 * visual_scale
			GroundFx.eruption(Blood.world_of(self), at, 0.5)
		elif act != HURL:
			_show_held(false)
	else:
		_held_clock += delta
	if act == PICK and _held_clock >= 0.35 and not is_dead:
		_show_held(true)
	if _held != null and _held.visible:
		_held.global_position = _hand_at() + Vector3.UP * 0.18 * visual_scale
	if is_dead:
		_show_held(false)
	_show_healing(delta)


func _show_held(on: bool) -> void:
	if _held == null:
		if not on:
			return
		_held = MeshInstance3D.new()
		var m := SphereMesh.new()
		m.radius = 0.42
		m.height = 0.76
		m.radial_segments = 7
		m.rings = 4
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.4, 0.37, 0.33)
		mat.roughness = 1.0
		m.material = mat
		_held.mesh = m
		_held.top_level = true
		_held.scale = Vector3(1.1, 0.85, 1.0)
		add_child(_held)
	_held.visible = on


func _show_healing(delta: float) -> void:
	var on := healing and not is_dead and body != null and act != PIECES
	if on != _heal_shown:
		_heal_shown = on
		if body != null:
			if _heal_glow == null:
				_heal_glow = StandardMaterial3D.new()
				_heal_glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				_heal_glow.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
				_heal_glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				_heal_glow.albedo_color = Color(regen_tint, 0.0)
			for mi: MeshInstance3D in body.find_children("*", "MeshInstance3D", true, false):
				mi.material_overlay = _heal_glow if on else null
	if not on:
		return
	# A slow green pulse over it, and motes rising off its wounds.
	_heal_glow.albedo_color.a = 0.07 + 0.07 * (0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * 3.0))
	_mote_clock += delta
	if _mote_clock < 0.12:
		return
	_mote_clock = 0.0
	var at := global_position + Vector3.UP * randf_range(0.5, 1.7) * visual_scale \
			+ Vector3(randf_range(-0.35, 0.35), 0.0, randf_range(-0.35, 0.35)) * visual_scale
	SkillFx.burst(Blood.world_of(self), at, regen_tint, 8, Vector2(0.3, 0.9), Vector3.UP, 35.0,
			Vector2(0.045, 0.09), Vector3(0, 1.6, 0), 1.0)


#endregion


#region Regeneration (host)
func _physics_process(delta: float) -> void:
	super(delta)
	if is_dead or not _decides():
		return
	var aff := Afflictions.of(self, false)
	if aff != null and (aff.is_burning() or aff.is_chilled()):
		_stopped_for = regen_stopped
	_stopped_for = maxf(_stopped_for - delta, 0.0)
	var heal := _stopped_for <= 0.0 and health < max_health and act != PIECES
	if heal:
		health = minf(health + max_health * regen * delta, max_health)
	if heal != healing:
		if is_inside_tree() and multiplayer.has_multiplayer_peer():
			net_regen.rpc(heal)
		else:
			net_regen(heal)


@rpc("authority", "call_local", "reliable")
func net_regen(on: bool) -> void:
	healing = on


## Burnt or frozen by a skill: its wounds stop closing.
func react(kind: StringName, from: Node3D = null, push: Vector3 = Vector3.ZERO) -> void:
	if kind == &"burn" or kind == &"chill" or kind == &"freeze":
		_stopped_for = regen_stopped
	super(kind, from, push)
#endregion
