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
@export_group("Spikes")
@export var spikes_clip: StringName = &"CR_GroundPound"
@export var spikes_part: Vector3 = Vector3(0.9, 0.0, 0.92)
@export var spikes_from: float = 3.5
@export var spikes_to: float = 13.0
@export var spikes_length: float = 14.0
@export var spikes_pace: float = 11.0
@export var spikes_size: float = 1.1
@export var spikes_share: float = 0.9
@export var spikes_cooldown: Vector2 = Vector2(6.0, 9.0)

const SPIKES := 118
const WALL := 119
## Its combos' moves (2026-10-10; made its own 2026-10-15 — no ogre's, none
## the troll's): both fists down, shoulder rams, its arms swept, the quake leap.
const G_SLAM := 185
const G_BASH := 186
const G_BASH2 := 187
const G_SWEEP := 188
const G_SWEEP2 := 189
const G_QUAKE := 190
## Its moves that break the ground where they land.
const GROUND_MOVES := [G_SLAM, G_QUAKE, G_SWEEP2]
const BOTH := "L_elbow_joint>L_midFinger_joint3:0.2|R_elbow_joint>R_midFinger_joint3:0.2"
const SHOULDERS := "L_shoulder_joint>L_elbow_joint:0.32|R_shoulder_joint>R_elbow_joint:0.32"

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


func _ready() -> void:
	# its plain blows its own too (none of the troll's fists)
	attacks = [&"CR_ShieldBash", &"CR_Staff1", &"CR_GroundPound"] as Array[StringName]
	attack_parts = [Vector3(0.85, 0.0, 0.9), Vector3(0.85, 0.0, 0.9), Vector3(0.9, 0.0, 0.92)] as Array[Vector3]
	attack_limbs = PackedStringArray([SHOULDERS, BOTH, BOTH])
	attack_blows = PackedInt32Array([1, 1, 1])
	attack_clip = &"CR_ShieldBash"
	# it never runs
	run_clip = &""
	chase_speed = minf(chase_speed, 2.6)
	run_above = 99.0
	super()
	_set_combos()
	_special(SPIKES, spikes_clip, spikes_part)
	_special(WALL, &"CR_MG_Raise", Vector3(1.0, 0.0, 0.85))
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
	_hand_move(G_SLAM, &"CR_GroundPound", Vector3(0.9, 0.0, 0.92), 1.5, BOTH)
	_hand_move(G_BASH, &"CR_ShieldBash", Vector3(0.85, 0.0, 0.9), 0.8, SHOULDERS)
	_hand_move(G_BASH2, &"CR_ShieldBash2", Vector3(0.85, 0.0, 0.9), 0.9, SHOULDERS)
	_hand_move(G_SWEEP, &"CR_Staff1", Vector3(0.85, 0.0, 0.9), 0.9, BOTH)
	_hand_move(G_SWEEP2, &"CR_Staff2", Vector3(0.85, 0.0, 0.9), 1.0, BOTH)
	_hand_move(G_QUAKE, &"CR_RunJumpSlam", Vector3(0.9, 0.0, 0.92), 1.6, BOTH)
	for what: int in [G_SLAM, G_BASH, G_BASH2, G_SWEEP, G_SWEEP2, G_QUAKE]:
		# slow up (and glowing), then all of it at once
		_windups[what] = [1.9, 0.22]
		_snap[what] = 1.4
	_kinds[G_SLAM] = &"crush"
	_kinds[G_QUAKE] = &"crush"
	_hand_combos = [
		{"name": &"crush", "moves": [G_BASH, G_SLAM], "fells": [1], "weight": 1.0},
		{"name": &"sweeps", "moves": [G_SWEEP, G_SWEEP2, G_SLAM], "fells": [2], "weight": 1.0},
		{"name": &"ram", "moves": [G_BASH2, G_SWEEP2], "fells": [1], "weight": 0.8},
		{"name": &"quake", "moves": [G_QUAKE], "fells": [0], "weight": 1.0, "far": true},
	]


func _own_move(delta: float) -> bool:
	_spikes_wait = maxf(_spikes_wait - delta, 0.0)
	_wall_wait = maxf(_wall_wait - delta, 0.0)
	var gap := _distance_to(_quarry)
	if _wall_wait <= 0.0 and gap >= wall_from and gap <= wall_to and not _quarry_down() and stamina >= attack_cost:
		mode = Mode.FIGHT
		_face(_quarry.global_position - global_position, 1.0, 50.0)
		_walled = false
		_wall_wait = _rng.randf_range(wall_cooldown.x, wall_cooldown.y)
		_begin(WALL)
		return true
	if _spikes_wait <= 0.0 and gap >= spikes_from and gap <= spikes_to and not _quarry_down() \
			and stamina >= attack_cost:
		mode = Mode.FIGHT
		_face(_quarry.global_position - global_position, 1.0, 50.0)
		_spiked = false
		_begin(SPIKES)
		return true
	return super(delta)


func _run_act(delta: float) -> void:
	super(delta)
	if is_dead or not _decides():
		return
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


## Host: a run of spikes from `from` along `way`, seen everywhere.
func _spike_run(from: Vector3, way: Vector3) -> void:
	_runs.append({"from": from, "dir": way, "t": 0.0, "caught": {}, "id": act_serial * 1000 + 95})
	if is_inside_tree() and multiplayer.has_multiplayer_peer():
		net_spikes.rpc(from, way)
	else:
		net_spikes(from, way)


@rpc("authority", "call_local", "reliable")
func net_spikes(from: Vector3, way: Vector3) -> void:
	var world := Blood.world_of(self)
	GroundFx.shards(world, from, way, spikes_length, spikes_size, spikes_pace, reform_glow)
	GroundFx.eruption(world, from, 0.8, false)
	ImpactFx.thud(self, from, true)


func _physics_process(delta: float) -> void:
	super(delta)
	_since_hit += delta
	if _since_hit > poise_rest:
		_poise_taken = maxf(_poise_taken - poise_mend * delta, 0.0)
	if _decides() and not is_dead:
		_open_left = maxf(_open_left - delta, 0.0)
		var hard := _open_left <= 0.0 and _poise_taken >= poise * harden_at
		if hard != hardened:
			if is_inside_tree() and multiplayer.has_multiplayer_peer():
				net_harden.rpc(hard)
			else:
				net_harden(hard)
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
			if d < 0.4 or d > minf(front - 0.3, spikes_length):
				continue
			if absf(rel.dot(side)) > GroundFx.wave_width(d, spikes_size) * 0.5 + 0.35:
				continue
			caught[who] = true
			who.call(&"receive_blow", hit_damage * spikes_share * _blow_worth(SPIKES), self, 0, 1, int(run.id),
					false, &"spike")
		if front > spikes_length + 1.0:
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
			_break_ground(act == G_QUAKE)
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


## Every peer: its fists into the ground — the ground breaks round them.
func _break_ground(quake: bool) -> void:
	var world := Blood.world_of(self)
	var at := global_position + _forward() * 1.6 * visual_scale / 1.8
	at.y = global_position.y
	var s := visual_scale / 1.8
	RockWave.spawn(world, at, (5.0 if quake else 2.8) * s, (0.9 if quake else 0.7) * s, 15.0, act_serial * 17 + _ground_done)
	var crack := DarkFx.decal(world, at, DarkFx.CRACK, (5.0 if quake else 3.2) * s, Color(0.09, 0.07, 0.05, 1.0), 0.0, 0.9)
	crack.rotation.y = randf() * TAU
	var tw := crack.create_tween()
	tw.tween_interval(3.0)
	tw.tween_property(crack, "modulate:a", 0.0, 2.5).set_ease(Tween.EASE_IN)
	tw.tween_callback(crack.queue_free)
	SkillFx.burst(world, at + Vector3.UP * 0.2, Color(0.45, 0.39, 0.31, 0.65), 40, Vector2(1.5, 5.0), Vector3.UP, 80.0,
			Vector2(0.1, 0.25), Vector3(0, -1.5, 0), 1.2)
	Sfx.play_any(self, ["res://sounds/ogre/club_ground_1.wav", "res://sounds/ogre/club_ground_3.wav"], null, 0.7, 4.0)
	ImpactFx.thud(self, at, true)
	WindBlast.shake(self, 0.16 if quake else 0.1, 0.45, 18.0)


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
