class_name SwampWade
extends Node3D

## The swamp's water under a hero's feet (the user's word, 2026-10-23: running
## through it felt like dry ground; then: the pond shallow, run over it, a
## wave going off behind, and no stutter on stepping in). In the pond he is
## held back a little ([member Player.wade]), each footfall splashes (its own
## sound, droplets), and while he runs the ripples spread behind him
## through the water itself (its surface bent by rings of small crests that run
## out and die; [SwampMere]'s water shader draws them). On the wet ground: a
## lighter splash. The pools are in this node's (the room's) frame.
##
## Cheap on purpose: the heroes come from the [World]'s list, the droplets
## from a few particle systems made once and moved, the ripples 32 numbers
## handed to the water each frame.

const WADE: Array[String] = [
	"res://sounds/water/wade_1.wav", "res://sounds/water/wade_2.wav", "res://sounds/water/wade_3.wav",
	"res://sounds/water/wade_4.wav", "res://sounds/water/wade_5.wav", "res://sounds/water/wade_6.wav",
]
const WET: Array[String] = [
	"res://sounds/water/wet_1.wav", "res://sounds/water/wet_2.wav", "res://sounds/water/wet_3.wav",
	"res://sounds/water/wet_4.wav", "res://sounds/water/wet_5.wav", "res://sounds/water/wet_6.wav",
]
const DROPS := 32
const SPLASHES := 4

var pools: Array[Dictionary] = []
var noise: FastNoiseLite

var _world: World
var _heroes: Array[Player] = []
var _seek: float = 0.0
var _steps := {}
var _wake := {}
## The pond's water material: its `drops` are the ripples.
var water: ShaderMaterial
var _drops := PackedVector4Array()
var _next_drop: int = 0
var _live := PackedVector4Array()
var _rolling := {}
var _arcs_bright := {}
var _arcs := {}
var _roll_drop := {}
var _splashes: Array[GPUParticles3D] = []
var _next_splash: int = 0


func _ready() -> void:
	var n: Node = self
	while n != null and not (n is World):
		n = n.get_parent()
	_world = n as World
	_drops.resize(DROPS)
	for i in DROPS:
		_drops[i] = Vector4(0.0, 0.0, 99.0, 0.0)
	for i in SPLASHES:
		var p := SkillFx.particles(self, Vector3(0.0, -50.0, 0.0), {
			"amount": 12, "life": 0.5, "one_shot": true, "explosiveness": 0.95, "add": false, "free_after": 0.0,
			"speed": Vector2(1.0, 2.4), "dir": Vector3.UP, "spread": 35.0, "gravity": Vector3(0, -9.0, 0),
			"damping": 0.5, "size": Vector2(0.03, 0.06), "grow": 0.0, "sphere": 0.12,
			"colors": [Color(0.85, 0.9, 0.92, 0.0), Color(0.85, 0.9, 0.92, 0.55), Color(0.85, 0.9, 0.92, 0.0)],
		})
		# fired once now, out of sight under the ground, so its shaders are
		# built at the room's making and not at the first step in the water
		p.emitting = true
		_splashes.append(p)
	# the step sounds read now, not at the first step
	for path in WADE + WET:
		Sfx._stream(path)


func _physics_process(delta: float) -> void:
	_seek -= delta
	if _seek <= 0.0:
		_seek = 1.0
		if _world != null:
			_heroes = _world.players()
	for hero in _heroes:
		if is_instance_valid(hero):
			_hero(hero, delta)
	_age(delta)


func _hero(hero: Player, delta: float) -> void:
	var at := to_local(hero.global_position)
	var deep := 0.0
	var wet := false
	var y := 0.0
	var depth := 0.0
	for pl in pools:
		if SwampMere._into(pl, at.x, at.z, noise) >= 0.97:
			continue
		var floor_y := SwampMere._height(at.x, at.z, pools, noise)
		var water_y: float = pl["water"]
		if water_y <= floor_y:
			continue
		y = water_y
		depth = maxf(depth, water_y - floor_y)
		if float(pl["depth"]) < 0.3:
			wet = true
		else:
			deep = maxf(deep, clampf((water_y - floor_y) / 0.25, 0.0, 1.0))
	_bright_arcs(hero, at)
	var was: float = hero.wade
	hero.wade = deep
	var fs := hero.footsteps
	if fs != null:
		if deep > 0.02:
			fs.sounds = WADE
		elif wet:
			fs.sounds = WET
		elif was > 0.02 or fs.sounds == WET:
			fs.sounds = []
		var n: int = fs.steps_played
		var id := hero.get_instance_id()
		var last: int = int(_steps.get(id, n))
		_steps[id] = n
		if n != last and (deep > 0.02 or wet):
			_splash(Vector3(at.x, y + 0.02, at.z), 1.0 if deep > 0.02 else 0.45)
			_drop(hero.global_position, 1.0 if deep > 0.02 else 0.6)
	# the wake: a wave now and then while he runs in the pond
	var vel := Vector3(hero.velocity.x, 0.0, hero.velocity.z)
	var planar := vel.length()
	# a roll through the water (the user's word, 2026-10-24): a big ring as he
	# goes down into it, more along the roll, a bigger splash
	var id3 := hero.get_instance_id()
	var rolling := hero.state == Player.State.DASHING or hero.state == Player.State.DODGING \
			or hero.net_state == Player.State.DASHING or hero.net_state == Player.State.DODGING
	if rolling and depth > 0.008:
		if not bool(_rolling.get(id3, false)):
			_drop(hero.global_position, 2.6)
			_splash(Vector3(at.x, y + 0.02, at.z), 1.0)
			_roll_drop[id3] = 0.07
		var rt: float = float(_roll_drop.get(id3, 0.07)) - delta
		if rt <= 0.0:
			rt = 0.07
			_drop(hero.global_position, 1.7)
		_roll_drop[id3] = rt
	_rolling[id3] = rolling
	# anywhere there is water to stir, the pond and the wet ground alike
	if depth > 0.008 and planar > 1.0:
		var id2 := hero.get_instance_id()
		var t: float = float(_wake.get(id2, 0.0)) - delta
		if t <= 0.0:
			t = lerpf(0.22, 0.10, clampf(planar / 6.0, 0.0, 1.0))
			_drop(hero.global_position, clampf(0.35 + depth * 3.0, 0.35, 1.0) * lerpf(0.6, 1.0, clampf(planar / 6.0, 0.0, 1.0)))
		_wake[id2] = t


func _splash(at: Vector3, k: float) -> void:
	var p := _splashes[_next_splash]
	_next_splash = (_next_splash + 1) % _splashes.size()
	p.position = at
	p.amount_ratio = k
	p.restart()


## A ripple starting where a foot went in (world position).
func _drop(at: Vector3, strength: float) -> void:
	_drops[_next_drop] = Vector4(at.x, at.z, 0.0, strength)
	_next_drop = (_next_drop + 1) % DROPS


func _age(delta: float) -> void:
	for i in DROPS:
		var d := _drops[i]
		if d.z < 99.0:
			d.z += delta
			if d.z > 3.0:
				d = Vector4(0.0, 0.0, 99.0, 0.0)
			_drops[i] = d
	if water != null:
		# only the live ones, packed at the front: the water loops over just those
		_live.clear()
		for i in DROPS:
			if _drops[i].z < 99.0:
				_live.append(_drops[i])
		var n := _live.size()
		_live.resize(DROPS)
		water.set_shader_parameter(&"drops", _live)
		water.set_shader_parameter(&"drop_count", n)


## The heroes' cut is bent air, made from the picture as it was before the
## water was drawn: over the pond it bent the mud under it, the same colour
## as the muddy water, and the cut was lost (the user's word, 2026-10-24).
## Near the water its light edge, glow and tint are put up so it still reads;
## away from it, back as they were.
func _bright_arcs(hero: Player, at: Vector3) -> void:
	var near := false
	for pl in pools:
		if SwampMere._into(pl, at.x, at.z, noise) < 1.35:
			near = true
			break
	var id := hero.get_instance_id()
	if bool(_arcs_bright.get(id, false)) == near:
		return
	var all_worn := true
	if not _arcs.has(id):
		_arcs[id] = hero.find_children("*", "BladeArc", true, false)
	for n in _arcs[id]:
		if not is_instance_valid(n):
			continue
		var arc := n as BladeArc
		var m := arc.get(&"_air_material") as ShaderMaterial
		if m == null:
			# not worn yet (put on at its first swing): try again next frame
			all_worn = false
			continue
		m.set_shader_parameter(&"rim", 0.7 if near else float(BladeArc.AIR_LOOK[2]))
		m.set_shader_parameter(&"brighten", 0.35 if near else 0.04)
		m.set_shader_parameter(&"tint_amount", 0.45 if near else 0.06)
	if all_worn:
		_arcs_bright[id] = near
