class_name OrcWarrior
extends Brute

## The orc warrior: twice Tariel's height, an axe in his right fist, and his
## own clips for every move he makes.
##
## His clips are Mixamo's axe set, retargeted onto his rig in Blender
## (`tools/retarget_orc.py` in the art folder) and baked into
## `assets/orc/orc_axe.glb`: an axe idle, a walk and a run, a guard, six blows,
## three combos, a kick, a running leap, a battle cry and a death. He used to
## borrow the mannequin library's sword swings through [RigRetarget]; an axe
## swung like a sword never looked like an axe.
##
## * **Attacks.** Close in: a single blow (horizontal, backhand or overhead), a
##   combo of two or three blows, the kick, or the spin — the one that catches
##   anyone standing beside or behind him. The overhead blow is also his heavy:
##   it goes into the ground, and the earth splits ahead of it in a run of
##   stone spikes. Further off he runs and leaps, and lands with the same slam.
##   The blows land where his right hand moves fastest in each clip, measured
##   off it once. Only a combo that lands every blow knocks a player down.
## * **The battle cry.** The first time he sees someone he stops and roars.
## * **The guard.** Only an archer makes him cover his face: while a player
##   with a bow is drawing on him he raises his axe across himself (the guard
##   clip, laid over his upper body while his legs keep walking) and an arrow
##   does `guard_factor` of its damage.
## * **The axe** is the village's, set in his fist by a grip read off his own
##   mesh: where the fist's vertices gather, and the line their knuckles make.

enum Act {
	NONE = 0, SWING = 1, COMBO = 2, HEAVY = 3, KICK = 4, SPIN = 5, LEAP = 6, ROAR = 7,
	BACKHAND = 8, COMBO_THREE = 9, COMBO_SHORT = 10, DEAD = 99,
}

## The clips, by what they are for.
const IDLE := &"OR_Axe_Idle"
const CALM_IDLE := &"OR_Orc_Idle"
const CALM_WALK := &"OR_Orc_Walk"
const WALK := &"OR_Axe_Walk"
const RUN := &"OR_Axe_Run"
const GUARD := &"OR_Block_Idle"
const SWING_CLIP := &"OR_Attack_Horizontal"
const HEAVY_CLIP := &"OR_Attack_Downward"
const DEATH_CLIP := &"OR_Death"
## act -> [clip, how many blows it lands, rate]
const ACTS := {
	Act.SWING: [&"OR_Attack_Horizontal", 1, 1.15],
	Act.BACKHAND: [&"OR_Attack_Backhand", 1, 1.15],
	Act.HEAVY: [&"OR_Attack_Downward", 1, 1.05],
	Act.COMBO: [&"OR_Combo_1", 2, 1.1],
	Act.COMBO_THREE: [&"OR_Combo_2", 3, 1.1],
	Act.COMBO_SHORT: [&"OR_Combo_3", 2, 1.1],
	Act.KICK: [&"OR_Kick", 1, 1.2],
	Act.SPIN: [&"OR_Attack_360", 1, 1.15],
	Act.LEAP: [&"OR_Run_Jump_Attack", 1, 1.15],
	Act.ROAR: [&"OR_Battlecry", 0, 1.1],
	Act.DEAD: [&"OR_Death", 0, 1.0],
}
const LOOPS: Array[StringName] = [
	&"OR_Axe_Idle", &"OR_Orc_Idle", &"OR_Orc_Walk", &"OR_Axe_Walk", &"OR_Axe_Run", &"OR_Block_Idle",
]

## What the guard moves while his legs walk.
const GUARD_BONES: PackedStringArray = [
	"Spine01", "Spine", "neck", "Head", "LeftShoulder", "LeftArm", "LeftForeArm", "LeftHand",
	"RightShoulder", "RightArm", "RightForeArm", "RightHand",
]
## The grip in his right hand's own frame: the middle of the fist, and the turn
## that runs the haft along the knuckles with the blade out. Read off the mesh
## once, in the bestiary.
const FIST_LOCAL := Vector3(-0.65376, 13.47461, 0.47799)
const GRIP := Quaternion(-0.48301, -0.78505, 0.31603, 0.22476)
## Held a little way up the haft, so the fist closes round wood.
const AXE_DROP := 0.18
## The head of the axe, in the axe's own frame: where the slam lands.
const AXE_HEAD := Vector3(0.12, 0.62, 0.0)
const AXE_SCENE := "res://assets/area/HighLandsFantasyBuildings/MiscProps/SM_Axe.fbx"
const AXE_TEXTURES := "res://assets/area/HighLandsFantasyBuildings/MiscProps/TextureMaps"

@export_group("Attack")
@export var reach: float = 2.7
@export var swing_damage: float = 14.0
@export var combo_damage: float = 12.0
@export var heavy_damage: float = 15.0
@export var slam_damage: float = 22.0
@export var kick_damage: float = 8.0
@export var spin_damage: float = 16.0
@export var leap_damage: float = 24.0
## How fast he covers the ground in the leap, metres a second.
@export var leap_speed: float = 7.0
## The run of spikes out of the ground after the slam: its length, how much
## wider and taller than the bestiary's it is drawn, and what it does.
@export var wave_length: float = 9.0
@export var wave_size: float = 1.25
@export var wave_damage: float = 20.0
## How far off he may open with the leap, for it to land on somebody.
@export var slam_range: float = 9.0

@export_group("Guard")
@export_range(0.0, 1.0) var guard_factor: float = 0.35
@export var threat_range: float = 45.0
@export var threat_cone: float = 20.0
## How long the axe stays up after the draw ends — the arrow is in the air.
@export var guard_linger: float = 0.6
## Share of his chase pace while he comes on behind his guard.
@export var guard_pace: float = 0.6

## Replicated.
var guarding: bool = false

var _skeleton: Skeleton3D
var _own: AnimationPlayer
var _hand: int = -1
var _hips: int = -1
var _hips_rest := Vector3.ZERO
var _axe: Node3D
## Own clip -> ground covered a second at rate 1.
var _natural: Dictionary = {}
## act -> when its blows land, as shares of the clip.
var _blows: Dictionary = {}
var _slam_at: float = -1.0
var _blows_done: int = 0
var _slammed: bool = false
## Where the last slam came down, for anything checking it.
var _slam_point := Vector3.ZERO
var _threat: float = 0.0
var _ranged_try: float = 0.0
var _roared: bool = false
## The guard clip's rotation tracks for the upper body: [track, bone].
var _guard_tracks: Array[Vector2i] = []
var _guard_time: float = 0.0


func _ready() -> void:
	super()
	_skeleton = body.find_child("Skeleton3D", true, false) as Skeleton3D
	_own = body.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _skeleton == null or _own == null:
		push_warning("Orc '%s': no skeleton or no clips." % name)
		return
	_hand = _skeleton.find_bone("RightHand")
	_hips = _skeleton.find_bone("Hips")
	if _hips >= 0:
		_hips_rest = _skeleton.get_bone_rest(_hips).origin
	_own.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for clip in LOOPS:
		if _own.has_animation(clip):
			_own.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	for clip in [CALM_WALK, WALK, RUN]:
		if _own.has_animation(clip):
			_natural[clip] = _measure_pace(clip)
	for what: int in ACTS:
		var spec: Array = ACTS[what]
		if int(spec[1]) > 0:
			_blows[what] = _measure_blows(spec[0], int(spec[1]))
	_slam_at = (_blows[Act.HEAVY] as PackedFloat32Array)[0] if _blows.has(Act.HEAVY) else 0.5
	_find_guard_tracks()
	_own.play(CALM_IDLE if _own.has_animation(CALM_IDLE) else IDLE)
	_own.advance(0.0)
	_make_axe()


## Metres a second one of his own cycles would carry him at rate 1: two
## steps, a step being as far apart as his feet get.
func _measure_pace(clip: StringName) -> float:
	var anim := _own.get_animation(clip)
	var left := _skeleton.find_bone("LeftFoot")
	var right := _skeleton.find_bone("RightFoot")
	if anim == null or anim.length <= 0.0 or left < 0 or right < 0:
		return 1.5
	var widest := 0.0
	_own.play(clip)
	for i in 24:
		_own.seek(anim.length * float(i) / 24.0, true)
		var gap := _skeleton.get_bone_global_pose(left).origin - _skeleton.get_bone_global_pose(right).origin
		gap.y = 0.0
		widest = maxf(widest, gap.length())
	_own.stop()
	# The skeleton is in centimetres under the armature's 0.01.
	var metres := widest * 2.0 * 0.01 * visual_scale
	return maxf(metres / anim.length, 0.3)


## When the `count` blows of a clip land, as shares of its length: the moments
## his right hand moves fastest, the strongest `count` of them, in order.
func _measure_blows(clip: StringName, count: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var anim := _own.get_animation(clip) if _own.has_animation(clip) else null
	if anim == null or _hand < 0:
		for i in count:
			out.append((i + 1.0) / (count + 1.0))
		return out
	var samples := 90
	var at: Array[Vector3] = []
	_own.play(clip)
	for i in samples + 1:
		_own.seek(anim.length * float(i) / samples, true)
		at.append(_skeleton.get_bone_global_pose(_hand).origin)
	_own.stop()
	var speed := PackedFloat32Array()
	for i in samples:
		speed.append(at[i + 1].distance_to(at[i]))
	# Local maxima, strongest first, at least a sixth of a second apart.
	var peaks: Array[Vector2] = []
	for i in range(1, samples - 1):
		if speed[i] >= speed[i - 1] and speed[i] >= speed[i + 1]:
			peaks.append(Vector2((float(i) + 0.5) / samples, speed[i]))
	peaks.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.y > b.y)
	var gap := (1.0 / 6.0) / maxf(anim.length, 0.01)
	var chosen: Array[float] = []
	for p in peaks:
		var clear := true
		for c in chosen:
			if absf(c - p.x) < gap:
				clear = false
				break
		if clear:
			chosen.append(p.x)
		if chosen.size() == count:
			break
	chosen.sort()
	for c in chosen:
		out.append(c)
	while out.size() < count:
		out.append((out.size() + 1.0) / (count + 1.0))
	return out


func _find_guard_tracks() -> void:
	if not _own.has_animation(GUARD):
		return
	var anim := _own.get_animation(GUARD)
	for t in anim.get_track_count():
		if anim.track_get_type(t) != Animation.TYPE_ROTATION_3D:
			continue
		var bone_name := String(anim.track_get_path(t).get_concatenated_subnames())
		if bone_name in GUARD_BONES:
			var bone := _skeleton.find_bone(bone_name)
			if bone >= 0:
				_guard_tracks.append(Vector2i(t, bone))


func _make_axe() -> void:
	if not ResourceLoader.exists(AXE_SCENE):
		return
	_axe = Node3D.new()
	_axe.name = "Axe"
	_axe.top_level = true
	var model := (load(AXE_SCENE) as PackedScene).instantiate() as Node3D
	model.position = Vector3.DOWN * AXE_DROP
	_axe.add_child(model)
	var material := Building._material_for(AXE_TEXTURES, "Props")
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if material != null and mesh.mesh != null:
			for s in mesh.mesh.get_surface_count():
				mesh.set_surface_override_material(s, material)
	var head := Marker3D.new()
	head.name = "Head"
	head.position = AXE_HEAD + Vector3.DOWN * AXE_DROP
	_axe.add_child(head)
	add_child(_axe)
	_place_axe()


func _place_axe() -> void:
	if _axe == null or _skeleton == null or _hand < 0:
		return
	var hand := _skeleton.get_bone_global_pose(_hand)
	var frame := _skeleton.global_transform
	var fist := frame * (hand * FIST_LOCAL)
	var turn := frame.basis.get_rotation_quaternion() * hand.basis.get_rotation_quaternion() * GRIP
	_axe.global_transform = Transform3D(Basis(turn.normalized()).scaled(Vector3.ONE * visual_scale), fist)


## Where the slam lands, on the ground.
func axe_head() -> Vector3:
	var head := _axe.get_node_or_null("Head") as Node3D if _axe != null else null
	var at := head.global_position if head != null else global_position + _forward() * reach
	at.y = global_position.y + 0.03
	return at


func clip_length(clip: StringName) -> float:
	return _own.get_animation(clip).length if _own != null and _own.has_animation(clip) else 1.0


#region Deciding
func _physics_process(delta: float) -> void:
	_watch_archers(delta)
	super(delta)


## Is anybody drawing a bow on him?
func _watch_archers(delta: float) -> void:
	_threat = maxf(_threat - delta, 0.0)
	if is_dead:
		guarding = false
		return
	var cone := cos(deg_to_rad(threat_cone))
	for node in get_tree().get_nodes_in_group("player"):
		var archer := node as Player
		if archer == null or not archer.has_bow():
			continue
		if not (archer.is_drawing() or archer.net_draw > 0.0):
			continue
		var to_me := global_position - archer.global_position
		to_me.y = 0.0
		var gap := to_me.length()
		if gap > threat_range or gap < 0.3:
			continue
		var aimed := archer.target == self
		if not aimed:
			var facing := -archer.global_transform.basis.z
			facing.y = 0.0
			aimed = facing.normalized().dot(to_me / gap) >= cone
		if aimed:
			_threat = guard_linger
	guarding = _threat > 0.0 and act == ACT_NONE


func _arrow_factor(_from: Node3D) -> float:
	return guard_factor if guarding else 1.0


func _move_towards(point: Vector3, pace: float, delta: float) -> void:
	super(point, pace * (guard_pace if guarding else 1.0), delta)


func _stand_off() -> float:
	return reach * 0.8


## The first sight of somebody: a roar before the chase.
func _rouse(who: Node3D) -> void:
	var was_idle := mode == Mode.GUARD
	super(who)
	if was_idle and not _roared and not is_dead and act == ACT_NONE and _decides() \
			and _own != null and _own.has_animation(&"OR_Battlecry"):
		_roared = true
		_begin(Act.ROAR, &"OR_Battlecry", float(ACTS[Act.ROAR][2]))


func _choose_attack(gap: float) -> void:
	if _own == null:
		return
	if gap <= reach:
		var roll := _rng.randf()
		var behind := _someone_behind()
		if behind and roll < 0.6:
			_open(Act.SPIN)
		elif gap < reach * 0.45 and roll < 0.2:
			_open(Act.KICK)
		elif roll < 0.4:
			_open([Act.SWING, Act.BACKHAND][_rng.randi() % 2])
		elif roll < 0.75:
			_open([Act.COMBO, Act.COMBO_THREE, Act.COMBO_SHORT][_rng.randi() % 3])
		else:
			_open(Act.HEAVY)
		return
	# Further off, now and then, the running leap.
	_ranged_try -= get_physics_process_delta_time()
	if gap < slam_range and gap > reach + 1.5 and _ranged_try <= 0.0:
		_ranged_try = 2.5
		if _rng.randf() < 0.4:
			_open(Act.LEAP)


## Anyone near enough to hit but not in front of him.
func _someone_behind() -> bool:
	var ahead := _players_ahead(reach + 0.6, 0.3)
	for who in _players_near(global_position, reach + 0.6):
		if not ahead.has(who):
			return true
	return false


func _open(what: int) -> void:
	var spec: Array = ACTS[what]
	_begin(what, spec[0], float(spec[2]))


func _begin(what: int, clip: StringName, rate: float) -> void:
	_blows_done = 0
	_slammed = false
	_start(what, clip_length(clip) / maxf(rate, 0.05))


func _turn_while_acting() -> float:
	return 0.9 if act == Act.LEAP else 0.3


func _run_act(delta: float) -> bool:
	if act == Act.LEAP:
		# Runs and leaps until the blow comes down, then plants.
		var blows: PackedFloat32Array = _blows.get(Act.LEAP, PackedFloat32Array([0.6]))
		var through := _act_time / maxf(_act_length, 0.001)
		if through < blows[0] and _quarry != null and _distance_to(_quarry) > reach * 0.6:
			var ahead := _forward() * leap_speed
			velocity.x = ahead.x
			velocity.z = ahead.z
		else:
			_slow(delta, 4.0)
	else:
		_slow(delta, 2.0)
	if _blows.has(act):
		var blows: PackedFloat32Array = _blows[act]
		var through := _act_time / maxf(_act_length, 0.001)
		while _blows_done < blows.size() and through >= blows[_blows_done]:
			_blows_done += 1
			_land(_blows_done - 1, blows.size())
	return _act_time < _act_length


## One blow of the act under way landing.
func _land(index: int, count: int) -> void:
	match act:
		Act.HEAVY, Act.LEAP:
			_slam(leap_damage if act == Act.LEAP else slam_damage)
		Act.SPIN:
			for who in _players_near(global_position, reach + 0.6):
				_hit(who, spin_damage, 0, 2)
		Act.KICK:
			for who in _players_ahead(reach * 0.7, 0.4):
				_hit(who, kick_damage, 0, 2)
		_:
			var combo := act == Act.COMBO or act == Act.COMBO_THREE or act == Act.COMBO_SHORT
			var damage := combo_damage if combo else swing_damage
			# A single blow is sent as the first of two: it never floors.
			var blows := count if combo else 2
			for who in _players_ahead(reach + 0.6, 0.3):
				_hit(who, damage, index, blows)


## The overhead blow into the ground: whoever is under it, and the spikes.
func _slam(damage: float) -> void:
	_slammed = true
	var at := axe_head()
	_slam_point = at
	for who in _players_near(at, 1.8):
		_hit(who, damage, 1, 2)
	for who in _players_ahead(reach + 0.4, 0.5):
		if who.global_position.distance_to(at) > 1.8:
			_hit(who, damage, 1, 2)
	_launch_wave(at, _forward(), wave_length, wave_size, wave_damage)
	net_slam.rpc(at, _forward())
#endregion


#region Looks
@rpc("authority", "call_local", "reliable")
func net_slam(at: Vector3, direction: Vector3) -> void:
	var world := Blood.world_of(self)
	GroundFx.eruption(world, at, 1.2)
	GroundFx.wave(world, at, direction, wave_length, false, wave_size)


func _show_act() -> void:
	if _own == null or not ACTS.has(act):
		return
	var spec: Array = ACTS[act]
	var clip: StringName = spec[0]
	if not _own.has_animation(clip):
		return
	# Every peer starts the clip from the top, at the rate the host's act length
	# was worked out for, so the blow is seen when it lands.
	var again := _own.current_animation == String(clip)
	_own.play(clip, 0.12, float(spec[2]))
	if again:
		_own.seek(0.0, true)


func _animate(delta: float) -> void:
	if _skeleton == null or _own == null:
		return
	var planar := Vector3(velocity.x, 0.0, velocity.z).length()
	var moving := planar > 0.2
	if is_dead:
		if _own.current_animation != String(DEATH_CLIP) and _own.has_animation(DEATH_CLIP):
			_own.play(DEATH_CLIP, 0.1)
	elif act == ACT_NONE:
		var roused := mode != Mode.GUARD
		var clip: StringName
		if moving:
			if planar > 2.6:
				clip = RUN
			elif roused or guarding:
				clip = WALK
			else:
				clip = CALM_WALK
		elif guarding:
			clip = GUARD
		else:
			clip = IDLE if roused else CALM_IDLE
		if not _own.has_animation(clip):
			clip = IDLE
		if _own.current_animation != String(clip):
			_own.play(clip, 0.25)
		_own.speed_scale = clampf(planar / float(_natural.get(clip, 1.5)), 0.6, 1.8) if moving else 1.0
	else:
		_own.speed_scale = 1.0
	_own.advance(delta)
	# His clips are kept on the spot; the body is what moves him.
	if _hips >= 0:
		var at := _skeleton.get_bone_pose_position(_hips)
		_skeleton.set_bone_pose_position(_hips, Vector3(_hips_rest.x, at.y, _hips_rest.z))
	# The guard over a walking lower body.
	if guarding and moving and act == ACT_NONE and not _guard_tracks.is_empty():
		var anim := _own.get_animation(GUARD)
		_guard_time = fmod(_guard_time + delta, maxf(anim.length, 0.01))
		for tb in _guard_tracks:
			_skeleton.set_bone_pose_rotation(tb.y, anim.rotation_track_interpolate(tb.x, _guard_time))
	_place_axe()
#endregion
