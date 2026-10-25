class_name FoeRoles
extends Node

## A creature's part in a fight beyond what its kind does by itself (the
## user's word, 2026-10-21: each a new puzzle in the fight):
##
## * **shield** — an orc behind a tower shield: a blow from in front rings off
##   it while it is not swinging ([member Fighter.front_guard]); go round it, or
##   catch it after its swing. Every fourth blow on the shield knocks it aside.
## * **shaman** — a goblin with a staff that keeps back out of the fight and
##   every few seconds raises it: its kin about it burn red for a while,
##   quicker and harder, and some of their hurts close. Kill it first.
## * **elite** — one in a wave bigger than the rest, lit from inside, with
##   three times the health and one thing of its own: gathering fire into
##   itself (it glows and the flames draw in) and throwing it off all round.
## * **captain** — the one a place's goal is about ([RoomGoal]): a banner on
##   its back, a gold light on it.
##
## The [Dungeon] reads "role" from a creature's props: [method before] as it is
## made (its size and strength), [method after] once it is in the tree (what
## it carries and the light on it, and this node under it, which thinks on
## the host).

const SHAMAN_EVERY := Vector2(6.5, 8.5)
const SHAMAN_REACH := 22.0
const SHAMAN_RAISE := 0.9
const EMPOWER_TIME := 7.0
const EMPOWER_PACE := 1.25
const EMPOWER_HARDER := 1.3
const EMPOWER_HEAL := 0.15
const ELITE_EVERY := Vector2(7.0, 10.0)
const ELITE_NEAR := 6.0
const ELITE_GATHER := 1.1
const ELITE_RADIUS := 4.6
const RIM_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled;
// A light from inside it, strongest at its edges, breathing.
uniform vec4 tint : source_color = vec4(1.0, 0.6, 0.2, 1.0);
uniform float amount = 1.0;
void fragment() {
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.5);
	float breathe = 0.8 + 0.2 * sin(TIME * 3.0);
	ALBEDO = tint.rgb * amount * (0.03 + 1.5 * rim) * breathe;
}
"""

static var _rim_shader: Shader
static var _red: ShaderMaterial

var role: StringName = &""
var _body: Fighter
var _dungeon: Dungeon
var _rng := RandomNumberGenerator.new()
var _next: float = 0.0
var _gathering: float = -1.0
var _rim: ShaderMaterial
var _orb: MeshInstance3D
var _orb_mat: StandardMaterial3D
var _combo: int = 9000


## Its size and strength, before it is put in the tree (its level counts on top).
static func before(body: Node3D, what: String) -> void:
	match what:
		"elite":
			# its anger kept, as a boss's ([Threat])
			body.set_meta(&"elite", true)
			body.set(&"visual_scale", float(body.get(&"visual_scale")) * 1.35)
			_scale_stat(body, &"max_health", 3.2)
			_scale_stat(body, &"hit_damage", 1.45)
		"captain":
			body.set(&"visual_scale", float(body.get(&"visual_scale")) * 1.2)
			_scale_stat(body, &"max_health", 2.4)
			_scale_stat(body, &"hit_damage", 1.3)
		"shaman":
			_scale_stat(body, &"max_health", 1.5)


static func _scale_stat(body: Node3D, stat: StringName, by: float) -> void:
	var v: Variant = body.get(stat)
	if v is float:
		body.set(stat, float(v) * by)


## What it carries, the light on it, and the role's own mind, now it is up.
static func after(body: Node3D, what: String, dungeon: Dungeon) -> FoeRoles:
	var fighter := body as Fighter
	if fighter == null:
		return null
	var r := FoeRoles.new()
	r.name = "Role"
	r.role = StringName(what)
	r._body = fighter
	r._dungeon = dungeon
	r._rng.randomize()
	fighter.set_meta(&"role", what)
	fighter.add_child(r)
	r._dress.call_deferred()
	return r


static func role_of(body: Node) -> StringName:
	return StringName(String(body.get_meta(&"role", ""))) if body != null else &""


func _dress() -> void:
	if not is_instance_valid(_body):
		return
	var kind := String(Leveling.kind_of(_body)).capitalize()
	match role:
		&"shield":
			_body.front_guard = 0.3
			_body.set_meta(&"title", "Shield Orc")
		&"shaman":
			_body.set_meta(&"title", "Goblin Shaman")
			_staff()
			_set_rim(Color(0.35, 1.0, 0.45), 0.3)
			_next = _now() + _rng.randf_range(2.5, 4.0)
		&"elite":
			_body.set_meta(&"title", "Elite " + kind)
			_set_rim(Color(1.0, 0.42, 0.1), 0.35)
			_aura()
			_next = _now() + _rng.randf_range(3.0, 5.0)
		&"captain":
			_body.set_meta(&"title", kind + " Captain")
			_set_rim(Color(1.0, 0.82, 0.35), 0.35)
			_back_banner()


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


## A light from inside it, in `tint`.
func _set_rim(tint: Color, amount: float) -> void:
	if _rim_shader == null:
		_rim_shader = Shader.new()
		_rim_shader.code = RIM_SHADER
	_rim = ShaderMaterial.new()
	_rim.shader = _rim_shader
	_rim.set_shader_parameter(&"tint", tint)
	_rim.set_shader_parameter(&"amount", amount)
	_body.set_meta(&"rim", _rim)
	_overlay(_body, _rim)


static func _overlay(body: Node3D, mat: Material) -> void:
	var visuals := body.get_node_or_null(^"Visuals")
	for g in (visuals if visuals != null else body).find_children("*", "GeometryInstance3D", true, false):
		if g is Label3D or g is GPUParticles3D:
			continue
		(g as GeometryInstance3D).material_overlay = mat


func _hand() -> Node3D:
	var skel := _body.find_child("Skeleton3D", true, false) as Skeleton3D
	if skel == null:
		return null
	var bone := String(_body.get(&"weapon_bone")) if _body.get(&"weapon_bone") != null else ""
	if bone == "" or skel.find_bone(bone) < 0:
		return null
	var hold := BoneAttachment3D.new()
	hold.bone_name = bone
	skel.add_child(hold)
	return hold


## The shaman's staff: a crooked pole, a skull, a green light over it.
func _staff() -> void:
	var hold := _hand()
	var at: Node3D = hold if hold != null else _body
	var staff := Node3D.new()
	at.add_child(staff)
	var s := 1.0 / maxf(_body.visual_scale, 0.01)
	staff.scale = Vector3.ONE * s
	if hold == null:
		staff.position = Vector3(0.4, 0.0, 0.0)
	var pole := CylinderMesh.new()
	pole.top_radius = 0.03
	pole.bottom_radius = 0.04
	pole.height = 1.9
	pole.radial_segments = 5
	var pm := MeshInstance3D.new()
	pm.mesh = pole
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.2, 0.13, 0.08)
	pm.material_override = wood
	pm.position = Vector3(0.0, 0.35, 0.0)
	staff.add_child(pm)
	var bone := StandardMaterial3D.new()
	bone.albedo_color = Color(0.8, 0.76, 0.66)
	var skull := SphereMesh.new()
	skull.radius = 0.11
	skull.height = 0.2
	var sk := MeshInstance3D.new()
	sk.mesh = skull
	sk.material_override = bone
	sk.position = Vector3(0.0, 1.3, 0.0)
	staff.add_child(sk)
	var orb := SphereMesh.new()
	orb.radius = 0.09
	orb.height = 0.18
	_orb = MeshInstance3D.new()
	_orb.mesh = orb
	_orb_mat = StandardMaterial3D.new()
	_orb_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_orb_mat.albedo_color = Color(0.5, 1.6, 0.6)
	_orb.material_override = _orb_mat
	_orb.position = Vector3(0.0, 1.5, 0.0)
	staff.add_child(_orb)
	var light := OmniLight3D.new()
	light.light_color = Color(0.4, 1.0, 0.5)
	light.light_energy = 1.2
	light.omni_range = 4.0
	light.position = Vector3(0.0, 1.5, 0.0)
	staff.add_child(light)


## Embers rising off an elite all the time, from its chest.
func _aura() -> void:
	if _dungeon == null:
		return
	var sparks := _dungeon._embers(1.4 * _body.visual_scale, 10)
	sparks.position = Vector3(0.0, 1.0 * _body.visual_scale, 0.0)
	_body.add_child(sparks)


## A captain's banner on a pole at its back.
func _back_banner() -> void:
	var at := Node3D.new()
	var s := maxf(_body.visual_scale, 0.01)
	at.position = Vector3(0.0, 1.0 * s, 0.25 * s)
	_body.add_child(at)
	var pole := CylinderMesh.new()
	pole.top_radius = 0.03
	pole.bottom_radius = 0.035
	pole.height = 2.2 * s
	var pm := MeshInstance3D.new()
	pm.mesh = pole
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.2, 0.13, 0.08)
	pm.material_override = wood
	pm.position = Vector3(0.0, 0.8 * s, 0.0)
	at.add_child(pm)
	var flag := QuadMesh.new()
	flag.size = Vector2(0.6, 0.9) * s
	var fm := MeshInstance3D.new()
	fm.mesh = flag
	var cloth := StandardMaterial3D.new()
	cloth.albedo_color = Color(0.55, 0.05, 0.03)
	cloth.cull_mode = BaseMaterial3D.CULL_DISABLED
	fm.material_override = cloth
	fm.position = Vector3(0.32 * s, 1.5 * s, 0.0)
	fm.rotation.y = PI * 0.5
	at.add_child(fm)


func _process(delta: float) -> void:
	if not is_instance_valid(_body) or _body.is_dead:
		set_process(false)
		return
	if not _host():
		return
	match role:
		&"shaman":
			_think_shaman()
		&"elite":
			_think_elite(delta)


func _host() -> bool:
	var net := get_node_or_null(^"/root/Net")
	return net == null or bool(net.call(&"is_host"))


func _awake() -> bool:
	return _body.visible and _body.process_mode != Node.PROCESS_MODE_DISABLED \
			and _dungeon != null and _dungeon._woken


#region The shaman
func _think_shaman() -> void:
	# it keeps out of the fight, back on the far ring
	_body.held_back = true
	_body.held_radius = 13.0
	if not _awake() or _now() < _next:
		return
	_next = _now() + _rng.randf_range(SHAMAN_EVERY.x, SHAMAN_EVERY.y)
	var kin := _kin()
	if kin.is_empty():
		return
	# the staff up, its light flaring, the green drawn into it; then on them
	var world := Blood.world_of(_body)
	var top := _orb.global_position if is_instance_valid(_orb) else _body.global_position + Vector3.UP * 2.0
	if world != null:
		SkillFx.burst(world, top, Color(0.4, 1.0, 0.5), 30, Vector2(-3.0, -1.0), Vector3.UP, 180.0,
				Vector2(0.04, 0.1), Vector3.ZERO, SHAMAN_RAISE)
	if _orb_mat != null:
		var tw := create_tween()
		tw.tween_property(_orb_mat, "albedo_color", Color(1.5, 4.0, 1.6), SHAMAN_RAISE)
		tw.tween_property(_orb_mat, "albedo_color", Color(0.5, 1.6, 0.6), 0.6)
	if _body.has_method(&"react"):
		_body.velocity = Vector3.ZERO
	Sfx.play(_body, Dungeon.SND + "portal_open.wav", null, _body.global_position + Vector3.UP * 1.5, 1.5, 2.0)
	get_tree().create_timer(SHAMAN_RAISE).timeout.connect(_empower_all.bind(kin))


## The living near it that are not already burning red, nearest first, three.
func _kin() -> Array[Fighter]:
	var out: Array[Fighter] = []
	if _dungeon == null:
		return out
	for item: Variant in _dungeon._alive:
		if not is_instance_valid(item):
			continue
		var f := item as Fighter
		if f == null or f == _body or f.is_dead or not f.visible or f.has_meta(&"empowered_until"):
			continue
		if role_of(f) == &"shaman":
			continue
		if f.global_position.distance_to(_body.global_position) <= SHAMAN_REACH:
			out.append(f)
	out.sort_custom(func(a: Fighter, b: Fighter) -> bool:
		return a.global_position.distance_squared_to(_body.global_position) \
				< b.global_position.distance_squared_to(_body.global_position))
	return out.slice(0, mini(3, out.size()))


func _empower_all(kin: Array[Fighter]) -> void:
	if not is_instance_valid(_body) or _body.is_dead:
		return
	var from := _orb.global_position if is_instance_valid(_orb) else _body.global_position + Vector3.UP * 2.0
	for f in kin:
		if not is_instance_valid(f) or f.is_dead:
			continue
		FoeRoles.empower(f, from, _dungeon)


## `f` burns red for [constant EMPOWER_TIME]: quicker, harder, some hurt closed.
static func empower(f: Fighter, from: Vector3, dungeon: Dungeon) -> void:
	if f.has_meta(&"empowered_until"):
		return
	f.set_meta(&"empowered_until", Time.get_ticks_msec() / 1000.0 + EMPOWER_TIME)
	f.chase_speed *= EMPOWER_PACE
	f.hit_damage *= EMPOWER_HARDER
	f.attack_speed *= 1.15
	f.health = minf(f.health + f.max_health * EMPOWER_HEAL, f.max_health)
	f.hurt.emit(f.health)
	if _red == null:
		if _rim_shader == null:
			_rim_shader = Shader.new()
			_rim_shader.code = RIM_SHADER
		_red = ShaderMaterial.new()
		_red.shader = _rim_shader
		_red.set_shader_parameter(&"tint", Color(1.0, 0.12, 0.05))
		_red.set_shader_parameter(&"amount", 0.6)
	_overlay(f, _red)
	var to := f.global_position + Vector3.UP * 1.2
	if dungeon != null and dungeon.boons != null:
		dungeon.boons._bolt(from, to, Color(0.45, 1.3, 0.55))
	var world := Blood.world_of(f)
	if world != null:
		SkillFx.burst(world, to, Color(1.0, 0.25, 0.1), 30, Vector2(1.0, 3.0), Vector3.UP, 180.0,
				Vector2(0.05, 0.12), Vector3(0, 1.0, 0), 0.8)
	# by its id: it may be gone (its place taken down) when the time is up
	f.get_tree().create_timer(EMPOWER_TIME).timeout.connect(FoeRoles._unempower.bind(f.get_instance_id()))
#endregion


#region The elite
func _think_elite(delta: float) -> void:
	if _gathering >= 0.0:
		_gathering += delta
		if _rim != null:
			_rim.set_shader_parameter(&"amount", 0.35 + 2.2 * clampf(_gathering / ELITE_GATHER, 0.0, 1.0))
		if _gathering >= ELITE_GATHER:
			_gathering = -1.0
			_nova()
		return
	if not _awake() or _now() < _next or _body.act != Fighter.Act.NONE:
		return
	var hero := _dungeon._nearest_hero(_body.global_position)
	if hero == null or hero.global_position.distance_to(_body.global_position) > ELITE_NEAR:
		return
	_next = _now() + _rng.randf_range(ELITE_EVERY.x, ELITE_EVERY.y)
	_gathering = 0.0
	# the fire drawn in to it: flames falling inwards round it, a rising roar
	var world := Blood.world_of(_body)
	var mid := _body.global_position + Vector3.UP * 1.2 * _body.visual_scale
	if world != null:
		for k in 3:
			get_tree().create_timer(float(k) * ELITE_GATHER / 3.0).timeout.connect(_gather_burst)
	Sfx.play(_body, Dungeon.SND + "portal_whoosh.wav", null, mid, 0.55, 3.0)


## Flames falling in to the elite as it gathers its fire (on a timer).
func _gather_burst() -> void:
	if not is_instance_valid(_body):
		return
	var world := Blood.world_of(_body)
	if world != null:
		SkillFx.burst(world, _body.global_position + Vector3.UP * 1.2 * _body.visual_scale,
				Color(1.0, 0.45, 0.1), 40, Vector2(-5.0, -3.0), Vector3.UP, 180.0, Vector2(0.06, 0.14),
				Vector3.ZERO, 0.5)


## The shaman's call worn off the one it was on (`id`, if it is still about).
static func _unempower(id: int) -> void:
	var f := instance_from_id(id) as Fighter
	if f == null or not is_instance_valid(f):
		return
	f.remove_meta(&"empowered_until")
	f.chase_speed /= EMPOWER_PACE
	f.hit_damage /= EMPOWER_HARDER
	f.attack_speed /= 1.15
	if not f.is_dead:
		_overlay(f, f.get_meta(&"rim") as Material if f.has_meta(&"rim") else null)


func _nova() -> void:
	if _rim != null:
		_rim.set_shader_parameter(&"amount", 0.35)
	if not is_instance_valid(_body) or _body.is_dead:
		return
	var at := _body.global_position + Vector3.UP * 0.8
	var world := Blood.world_of(_body)
	if world != null:
		SkillFx.burst(world, at, Color(1.0, 0.5, 0.12), 120, Vector2(6.0, 12.0), Vector3.UP, 95.0,
				Vector2(0.08, 0.2), Vector3(0, -3.0, 0), 0.6)
		SkillFx.burst(world, at, Color(1.0, 0.85, 0.4), 60, Vector2(3.0, 7.0), Vector3.UP, 180.0,
				Vector2(0.05, 0.12), Vector3(0, -2.0, 0), 0.5)
	ImpactFx.thud(_body, at, true)
	_combo += 1
	for hero in _dungeon._heroes():
		if hero.is_dead:
			continue
		if hero.global_position.distance_to(_body.global_position) <= ELITE_RADIUS * _body.visual_scale / 1.35:
			hero.receive_blow(_body.hit_damage * 1.2, _body, 0, 1, _combo, true)
#endregion
