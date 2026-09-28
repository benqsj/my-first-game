class_name ClawWave
extends Node3D

## The wolf-man's claw wave: a swipe that cuts the air and throws the cut.
## Three sickle blades of torn air side by side — the marks of three claws —
## fly from the paw at whoever it swiped at, and leave the air they tore
## hanging behind them for a moment, a trail of fraying slashes.
##
## The blades are modelled (`assets/fx/claw_wave.glb`, from `wolf/wolf_claw.blend`
## in the art folder, tools/wolf_claw.py) and drawn by `claw_wave.gdshader`: a
## white-hot edge leading, a red sheet behind it, streaks racing back along it,
## the air behind bent.
##
## How it lies is the blow that threw it (`roll`): a raking paw throws it
## slanting, a sweep lays it flat — the three blades one over another, from the
## knees to the head, so it has to be rolled through — and a slam stands it on
## end, three furrows torn in the ground under it, so it has to be stepped
## out of the way of.
##
## It strikes by where the blades themselves go ([WeaponSweep]), each player
## once. A shield held towards it catches it; a roll or a dodge goes through it.
## A raking or sweeping wave staggers whoever it catches; the slam's knocks him
## down. A round shield met with it at the last moment (a parry) shatters it.
## It breaks on walls. Only the host's wave (`live`) hurts anyone; the others
## are its likeness on the other peers.

const MODEL := "res://assets/fx/claw_wave.glb"
const SHADER := "res://assets/fx/claw_wave.gdshader"
const TEAR_SOUND := "res://unverified/sounds/tariel/air_3.wav"

## The blades as modelled: the arc's radius, how far round it the middle blade
## goes (radians, each way), and where each blade lies across the wave, with how
## much of the arc it takes.
const ARC_R := 1.25
const ARC_SPAN := 1.082
const BLADES := [[-0.34, 0.86], [0.0, 1.0], [0.34, 0.86]]

## Metres a second, and how far it goes before it has spent itself.
@export var speed: float = 15.0
@export var reach: float = 17.0
## The first moment: it tears out of the swipe small and opens to its size.
@export var open_time: float = 0.14
## How often the air it tore is left behind it, metres.
@export var tear_every: float = 0.4

static var _mesh: Mesh
static var _material: ShaderMaterial
static var _furrow_mat: StandardMaterial3D

var live: bool = false
var damage: float = 30.0
var thrower: Node3D
## Stands on end over the ground and tears furrows in it (the slam's).
var ground: bool = false
var size: float = 1.0

var _dir := Vector3.FORWARD
var _roll: float = 0.0
var _travelled: float = 0.0
var _t: float = 0.0
var _since_tear: float = 0.0
var _since_furrow: float = 0.0
var _ending: float = -1.0
var _body: MeshInstance3D
var _sparks: GPUParticles3D
var _sweep: WeaponSweep
var _serial: int = 0
static var _count: int = 0


## A wave from `at`, flying along `dir` (a slam's level, the others pitched up
## or down as thrown), lying at `roll` radians round
## its line (0: the blades one over another; PI/2: side by side, on end).
static func throw(into: Node, at: Vector3, dir: Vector3, roll: float, grow: float = 1.0,
		on_ground: bool = false, hurts: bool = false, from: Node3D = null, blow: float = 30.0) -> ClawWave:
	if into == null:
		return null
	var wave := ClawWave.new()
	wave.name = "ClawWave"
	var level := Vector3(dir.x, 0.0, dir.z).normalized() if Vector3(dir.x, 0.0, dir.z).length_squared() > 0.0001 \
			else Vector3.FORWARD
	# Along the ground a slam's wave; any other flies where it was thrown, up at
	# a man on a ledge or down at one below — though never steeper than ~35°.
	wave._dir = level if on_ground else (level + Vector3.UP * clampf(dir.y / maxf(Vector3(dir.x, 0.0, dir.z).length(), 0.05),
			-0.7, 0.7)).normalized()
	wave._roll = roll
	wave.size = grow
	wave.ground = on_ground
	wave.live = hurts
	wave.thrower = from
	wave.damage = blow
	wave.top_level = true
	# Placed before it enters the world, so its first frame is already where it is.
	wave.position = at
	into.add_child(wave)
	return wave


func _ready() -> void:
	_count += 1
	_serial = _count
	_body = MeshInstance3D.new()
	_body.mesh = mesh()
	_body.material_override = material()
	_body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_body)
	_place(0.0)
	_sparks = SkillFx.particles(self, global_position, {
		"amount": 48, "life": 0.45, "speed": Vector2(0.3, 1.6), "dir": Vector3.UP, "spread": 180.0,
		"gravity": Vector3(0, -3.0, 0), "damping": 1.5, "size": Vector2(0.025, 0.06),
		"box": Vector3(1.0, 0.8, 0.15) * size,
		"colors": [Color(1.0, 0.95, 0.85, 1.0), Color(1.0, 0.25, 0.08, 0.9), Color(0.6, 0.05, 0.02, 0.0)],
	})
	if live:
		_sweep = WeaponSweep.new(_blades)
		_sweep.track()
	# Torn out of the swipe: a spray of red sparks thrown on ahead of it.
	SkillFx.burst(get_parent(), global_position, Color(1.0, 0.22, 0.08), 22, Vector2(3.0, 9.0), _dir, 35.0,
			Vector2(0.03, 0.07), Vector3(0, -4, 0), 0.35)
	Sfx.play(self, TEAR_SOUND, null, global_position, 0.62 if ground else 0.78, -2.0)


func _process(delta: float) -> void:
	_t += delta
	if _ending >= 0.0:
		_ending += delta
		var k := 1.0 - _ending / 0.18
		_body.set_instance_shader_parameter(&"fade", maxf(k, 0.0))
		if k <= 0.0:
			queue_free()
		return
	var step := speed * delta
	var from := global_position
	var to := from + _dir * step
	# Walls break it.
	var space := get_world_3d().direct_space_state
	var ray := PhysicsRayQueryParameters3D.create(from, to + _dir * 0.3, 1)
	var hit := space.intersect_ray(ray)
	# Walls break it, and so does the ground for one thrown up or down into it.
	if not hit.is_empty() and (absf((hit["normal"] as Vector3).y) < 0.6 or (not ground and absf(_dir.y) > 0.05)):
		global_position = hit["position"]
		_break(hit["position"])
		return
	global_position = to
	_travelled += step
	var spent := _travelled / reach
	_place(spent)
	_body.set_instance_shader_parameter(&"fade", clampf((1.0 - spent) / 0.25, 0.0, 1.0))
	_since_tear += step
	if _since_tear >= tear_every:
		_since_tear = 0.0
		_tear()
	if ground:
		_since_furrow += step
		if _since_furrow >= 0.45:
			_since_furrow = 0.0
			_furrow(from, to)
	if live and _sweep != null:
		for who in _sweep.step(get_tree(), delta):
			if who.has_method("receive_blow") and who.get("net_dead") != true:
				# One blow of two — a flinch, and a round shield met in time turns it —
				# but the slam's (a blow of its own) puts him down.
				# Torn air, not claws: through his m.def.
				who.call("receive_blow", damage, self, 0, 1 if ground else 2, _serial, true)
				SkillFx.burst(get_parent(), who.global_position + Vector3.UP * 1.1, Color(1.0, 0.2, 0.08),
						18, Vector2(2.0, 5.0), _dir, 60.0)
	if spent >= 1.0:
		_ending = 0.0
		if _sparks != null:
			_sparks.emitting = false


## Where it lies now: along its line, rolled, opened out from the swipe and
## spreading a little as it goes.
func _place(spent: float) -> void:
	var open := 1.0 - pow(1.0 - clampf(_t / open_time, 0.0, 1.0), 3.0)
	var s := size * lerpf(0.35, 1.0, open) * lerpf(1.0, 1.2, clampf(spent, 0.0, 1.0))
	var b := Basis.looking_at(_dir, Vector3.UP).rotated(_dir, _roll)
	global_basis = b.scaled(Vector3.ONE * s)


## The blades as capsules in the world, for its [WeaponSweep]: each from one
## point through the middle to the other, in three stretches.
func _blades() -> Array:
	var out := []
	var frame := global_transform
	var thick := 0.15 * size
	for blade: Array in BLADES:
		var across: float = blade[0]
		var span: float = ARC_SPAN * float(blade[1])
		var pts := []
		for k in 4:
			var th := -span + 2.0 * span * float(k) / 3.0
			pts.append(frame * Vector3(ARC_R * sin(th), across, 0.55 * ARC_R * (1.0 - cos(th))))
		for k in 3:
			out.append([pts[k], pts[k + 1], thick])
	return out


## The air it tore, left hanging behind it: its likeness, fraying away.
func _tear() -> void:
	var world := get_parent()
	if world == null:
		return
	var g := MeshInstance3D.new()
	g.mesh = mesh()
	g.material_override = material()
	g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	g.top_level = true
	world.add_child(g)
	g.global_transform = global_transform
	g.set_instance_shader_parameter(&"ghost", 1.0)
	g.set_instance_shader_parameter(&"fade", 1.0)
	var life := 0.5
	var tw := g.create_tween().set_parallel(true)
	tw.tween_method(func(f: float) -> void:
		if is_instance_valid(g):
			g.set_instance_shader_parameter(&"fade", f), 1.0, 0.0, life)
	tw.tween_property(g, "scale", g.scale * 1.12, life)
	tw.chain().tween_callback(g.queue_free)


## Three furrows torn in the ground under it, and the earth thrown up.
func _furrow(a: Vector3, b: Vector3) -> void:
	var world := get_parent()
	if world == null:
		return
	var space := get_world_3d().direct_space_state
	var mid := (a + b) * 0.5
	var ray := PhysicsRayQueryParameters3D.create(mid + Vector3.UP * 1.5, mid + Vector3.DOWN * 3.0, 1)
	var hit := space.intersect_ray(ray)
	if hit.is_empty():
		return
	var floor_at: Vector3 = hit["position"]
	var side := _dir.cross(Vector3.UP).normalized()
	for blade: Array in BLADES:
		var off := side * float(blade[0]) * size
		var mi := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(0.12 * size, 0.6)
		quad.orientation = PlaneMesh.FACE_Y
		mi.mesh = quad
		mi.material_override = _furrow_material().duplicate()
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		world.add_child(mi)
		mi.global_transform = Transform3D(Basis.looking_at(_dir, Vector3.UP), floor_at + off + Vector3.UP * 0.02)
		var mat := mi.material_override as StandardMaterial3D
		var tw := mi.create_tween()
		tw.tween_interval(1.6)
		tw.tween_property(mat, "albedo_color:a", 0.0, 1.2)
		tw.tween_callback(mi.queue_free)
	SkillFx.burst(world, floor_at + Vector3.UP * 0.1, Color(0.35, 0.28, 0.2), 10, Vector2(1.5, 4.0),
			Vector3.UP + _dir * 0.3, 35.0, Vector2(0.04, 0.09), Vector3(0, -12, 0), 0.6)


## Turned on a round shield at the last moment (the player's parry): it
## shatters there.
func parried(_by: Node3D = null) -> void:
	if _ending < 0.0:
		_break(global_position)


## Broken on something solid: a spray of sparks and it is gone.
func _break(at: Vector3) -> void:
	_ending = 0.0
	if _sparks != null:
		_sparks.emitting = false
	SkillFx.burst(get_parent(), at, Color(1.0, 0.25, 0.08), 26, Vector2(2.0, 6.0), -_dir, 70.0)


static func mesh() -> Mesh:
	if _mesh == null:
		if ResourceLoader.exists(MODEL):
			var scene := (load(MODEL) as PackedScene).instantiate()
			var m: MeshInstance3D = null
			for node in scene.find_children("*", "MeshInstance3D", true, false):
				m = node as MeshInstance3D
				break
			if m != null:
				_mesh = m.mesh
			scene.free()
		if _mesh == null:
			var q := QuadMesh.new()
			q.size = Vector2(2.4, 0.3)
			_mesh = q
	return _mesh


static func material() -> ShaderMaterial:
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = load(SHADER)
	return _material


static func _furrow_material() -> StandardMaterial3D:
	if _furrow_mat == null:
		_furrow_mat = StandardMaterial3D.new()
		_furrow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_furrow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_furrow_mat.albedo_color = Color(0.05, 0.03, 0.025, 0.75)
		_furrow_mat.albedo_texture = SkillFx.dot()
	return _furrow_mat
