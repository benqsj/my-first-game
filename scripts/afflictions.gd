class_name Afflictions
extends Node3D

## What the heroes' skills leave on a creature: the hunter's mark, fire, and
## poison.
##
## One of these hangs under a creature (named "Afflictions"), made the first
## time something lands on it, on every peer — the skills send who was
## afflicted to everyone ([method Player.net_afflict]), so each peer draws the
## same thing. **The host decides** what it costs: only there do the burn and
## the poison tick health away ([method take_dot] on the creature, which does
## not bleed or shove), and only there does the mark make blows bite deeper
## ([method factor], read where each kind takes its hits, with who struck).
##
## * **The mark** — a sigil over the head, turning, always facing the camera,
##   and nothing else: the body and the ground are left as they are. It sits
##   on the head bone of whatever wears it. For its time a bow's blows on it
##   (arrows, the skill shots, the fire they leave) do `MARK_BOW` of
##   themselves; anyone else's do `MARK_OTHER`.
## * **Burning** — flames licking up off the body, embers, a light that
##   flickers, the skin charring with glowing cracks. `burn_dps` a second.
## * **Poison** — stacks, up to `POISON_MAX`, each on its own clock; drops over
##   the head count them. Veins of green run under the skin, bubbles rise.
##   Every stack is `poison_dps` a second. The fifth **boils** it (the user's
##   word, 2026-10-06): the stacks burst at once for `BOIL_SECONDS` of all
##   five, in a gout of venom, and are gone; not again on the same creature
##   for `BOIL_COOLDOWN` (the fifth then only renews the oldest). Drawn in the
##   poisoner's colour ([method RogueSkills.venom_of]: the dark elf's violet).
##
## Everything it draws goes when its time is up or the creature dies.

## What the mark adds: to a bow's blows, and to everyone else's.
const MARK_BOW := 1.05
const MARK_OTHER := 1.02
const POISON_MAX := 5
const BOIL_SECONDS := 2.0
const BOIL_COOLDOWN := 8.0
const TICK := 0.5

const GOLD := Color(1.0, 0.72, 0.25)
const CRIMSON := Color(1.0, 0.12, 0.06)
const FIRE := Color(1.0, 0.45, 0.08)
const VENOM := Color(0.38, 1.0, 0.16)

var mark_left: float = 0.0
var burn_left: float = 0.0
var burn_dps: float = 0.0
var poison: PackedFloat32Array = PackedFloat32Array()
var poison_dps: float = 0.0
## The poison's colour: the poisoner's people's.
var venom_color: Color = VENOM
var _boil_ready: float = 0.0

var _creature: Node3D
var _by: Dictionary = {}           # kind -> the player who put it there
var _tick: float = 0.0
var _clock: float = 0.0

# Drawing.
var _meshes: Array[MeshInstance3D] = []
var _old_overlays: Dictionary = {}
var _skin: ShaderMaterial
var _overhead: Node3D              # top level, over the head, facing the camera
var _sigil: Node3D
var _icons: Array[MeshInstance3D] = []
var _fire: GPUParticles3D
var _embers: GPUParticles3D
var _fire_light: OmniLight3D
var _bubbles: GPUParticles3D
var _shown: int = -1

static var _skin_shader: Shader = null
static var _noise: NoiseTexture2D = null


## The afflictions on `creature`, made if there are none yet and `make`.
static func of(creature: Node, make: bool = true) -> Afflictions:
	if creature == null or not is_instance_valid(creature):
		return null
	var a := creature.get_node_or_null(^"Afflictions") as Afflictions
	if a == null and make:
		a = Afflictions.new()
		a.name = "Afflictions"
		creature.add_child(a)
	return a


## How much harder a blow from `from` on `creature` lands right now: nothing
## unless it is marked; marked, more for a bow than for anything else.
static func factor(creature: Node, from: Node = null) -> float:
	var a := of(creature, false)
	if a == null or a.mark_left <= 0.0:
		return 1.0
	return MARK_BOW if is_bow(from) else MARK_OTHER


## Whether `who` fights with a bow (its profile says so).
static func is_bow(who: Node) -> bool:
	if who == null or not is_instance_valid(who):
		return false
	var prof: Variant = who.get(&"profile")
	if prof is CharacterProfile:
		return (prof as CharacterProfile).weapon == CharacterProfile.Weapon.BOW
	return false


## Puts `kind` on: &"mark" for `seconds`; &"burn" for `seconds` at `amount` a
## second; &"poison" one more stack for `seconds`, each at `amount` a second.
func apply(kind: StringName, seconds: float, source: Node3D = null, amount: float = 0.0) -> void:
	if _dead():
		return
	if source != null:
		_by[kind] = source
	match kind:
		&"mark":
			var fresh := mark_left <= 0.0
			mark_left = maxf(mark_left, seconds)
			if fresh:
				_pop_sigil()
		&"burn":
			burn_left = maxf(burn_left, seconds)
			burn_dps = maxf(burn_dps, amount)
		&"poison":
			poison_dps = maxf(poison_dps, amount)
			if source != null:
				venom_color = RogueSkills.venom_of(source)
			if poison.size() < POISON_MAX:
				poison.append(seconds)
			else:
				# Full: the oldest is renewed.
				var oldest := 0
				for i in poison.size():
					if poison[i] < poison[oldest]:
						oldest = i
				poison[oldest] = seconds
			_pop_icon(poison.size() - 1)
			if poison.size() >= POISON_MAX and _clock >= _boil_ready:
				_boil()
	_refresh()


## The fifth stack: the poison boils over. Every peer draws it; the host takes
## the health.
func _boil() -> void:
	_boil_ready = _clock + BOIL_COOLDOWN
	var harm := poison_dps * float(POISON_MAX) * BOIL_SECONDS
	poison.clear()
	var into := Blood.world_of(_creature)
	var mid := _creature.global_position + Vector3.UP * _height() * 0.55
	if into != null:
		var big := clampf(_height() / 1.6, 0.8, 2.2)
		SkillFx.burst(into, mid, venom_color, int(70 * big), Vector2(2.0, 6.5) * big, Vector3.UP, 180.0,
				Vector2(0.03, 0.07) * big, Vector3(0, -8, 0), 0.7)
		SkillFx.flash(into, mid, venom_color, 0.3 * big, 0.14, 2.5)
		SkillFx.light(into, mid, venom_color, 4.0, 5.0 * big, 0.45)
		SkillFx.particles(into, mid, {
			"amount": int(30 * big), "life": 1.4, "one_shot": true, "explosiveness": 0.9,
			"speed": Vector2(0.4, 1.4) * big, "spread": 180.0, "gravity": Vector3(0, 0.5, 0), "damping": 1.5,
			"size": Vector2(0.25, 0.5) * big, "box": Vector3(0.3, 0.5, 0.3) * big, "add": false, "grow": 0.5,
			"colors": [Color(venom_color, 0.0), Color(venom_color.darkened(0.4), 0.5), Color(venom_color.darkened(0.7), 0.0)],
		})
	if _decides() and harm > 0.0 and _creature.has_method(&"take_dot"):
		_creature.call(&"take_dot", harm, _source(&"poison"))


func is_marked() -> bool:
	return mark_left > 0.0


func is_burning() -> bool:
	return burn_left > 0.0


func poison_stacks() -> int:
	return poison.size()


func _ready() -> void:
	_creature = get_parent() as Node3D
	_gather_meshes()


func _process(delta: float) -> void:
	_clock += delta
	if _dead():
		_clear_all()
		queue_free()
		return
	var was := _state()
	mark_left = maxf(mark_left - delta, 0.0)
	burn_left = maxf(burn_left - delta, 0.0)
	for i in range(poison.size() - 1, -1, -1):
		poison[i] -= delta
		if poison[i] <= 0.0:
			poison.remove_at(i)
	if _state() != was:
		_refresh()
	_hurt(delta)
	_draw(delta)
	if _state() == 0:
		_clear_all()
		queue_free()


## The host's share: the fire and the poison take their toll every `TICK`.
func _hurt(delta: float) -> void:
	if not _decides():
		return
	_tick += delta
	if _tick < TICK:
		return
	_tick -= TICK
	var amount := 0.0
	var by: Node3D = null
	if burn_left > 0.0:
		amount += burn_dps * TICK
		by = _source(&"burn")
	if not poison.is_empty():
		amount += poison_dps * TICK * poison.size()
		if by == null:
			by = _source(&"poison")
	if amount > 0.0 and _creature.has_method(&"take_dot"):
		_creature.call(&"take_dot", amount, by)


func _source(kind: StringName) -> Node3D:
	var who: Variant = _by.get(kind)
	return who as Node3D if is_instance_valid(who) else null


func _decides() -> bool:
	var net := get_node_or_null(^"/root/Net")
	return net == null or bool(net.call(&"is_host"))


func _dead() -> bool:
	return _creature == null or not is_instance_valid(_creature) or _creature.get(&"is_dead") == true


## A number that changes whenever what should be drawn does.
func _state() -> int:
	# (kept while a boil cools, so the next five stacks on it do not boil it
	# again before its time)
	return (1 if mark_left > 0.0 else 0) | (2 if burn_left > 0.0 else 0) | (poison.size() << 2) \
			| (32 if _clock < _boil_ready else 0)


#region Sizes
var _skel: Skeleton3D
var _head_bone: int = -2


## Just over the top of the head: over the head bone when the creature has one
## (so it rides a stooping orc or a spider's rider where the head is), else
## over its bar height.
func _over_head() -> Vector3:
	var lift := Vector3.UP * (0.45 * _size())
	if _head_bone == -2:
		_find_head()
	if _head_bone >= 0 and is_instance_valid(_skel):
		var head := _skel.global_transform * _skel.get_bone_global_pose(_head_bone).origin
		# The bone sits at the base of the skull; the crown is a head's height on.
		return head + Vector3.UP * (0.3 * _scale_of() * _skel.global_transform.basis.get_scale().y) + lift
	return _creature.global_position + Vector3.UP * _top() + lift


func _find_head() -> void:
	_head_bone = -1
	_skel = _first_skeleton(_creature)
	if _skel == null:
		return
	var best := -1
	for i in _skel.get_bone_count():
		var n := _skel.get_bone_name(i).to_lower()
		if n.ends_with("headtop_end") or n.ends_with("head_end"):
			continue
		if n == "head" or n.ends_with(":head") or n.ends_with("_head") or n.ends_with(".head") or n == "mixamorig_head":
			best = i
			break
		if best < 0 and n.contains("head"):
			best = i
	_head_bone = best


static func _first_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for c in node.get_children():
		if c is Afflictions:
			continue
		var s := _first_skeleton(c)
		if s != null:
			return s
	return null

func _scale_of() -> float:
	var s := 1.0
	if _creature is Fighter:
		s = maxf(float(_creature.get(&"visual_scale")), 0.01)
	return s


## Top of the head, above the creature's feet.
func _top() -> float:
	var h: Variant = _creature.get(&"bar_height")
	return (float(h) if h != null else 2.0) * _scale_of()


func _radius() -> float:
	var r: Variant = _creature.get(&"body_radius")
	return (float(r) if r != null else 0.5) * _scale_of()


func _height() -> float:
	var h: Variant = _creature.get(&"body_height")
	return (float(h) if h != null else _top() * 0.8) * (_scale_of() if h != null else 1.0)
#endregion


#region Drawing
func _gather_meshes() -> void:
	_meshes.clear()
	var visuals := _creature.get_node_or_null(^"Visuals")
	var root: Node = visuals if visuals != null else _creature
	_collect(root)


func _collect(node: Node) -> void:
	if node == self or node is HealthBar:
		return
	var mi := node as MeshInstance3D
	if mi != null and mi.mesh != null and mi.visible:
		_meshes.append(mi)
	for c in node.get_children():
		_collect(c)


## Puts on and takes off what shows, by what is on it now.
func _refresh() -> void:
	var st := _state()
	if st == _shown:
		return
	_shown = st
	var marked := mark_left > 0.0
	var burning := burn_left > 0.0
	var poisoned := not poison.is_empty()

	# The body: a skin effect for fire or poison. The mark leaves it alone.
	var skin: ShaderMaterial = null
	if burning or poisoned:
		skin = _skin_material()
		skin.set_shader_parameter(&"glow_color", FIRE if burning else venom_color)
		skin.set_shader_parameter(&"dark_color",
				Color(0.05, 0.03, 0.02, 0.55) if burning else Color(venom_color.darkened(0.75), 0.3))
	var top_mat: Material = skin
	for mi in _meshes:
		if not is_instance_valid(mi):
			continue
		if not _old_overlays.has(mi):
			_old_overlays[mi] = mi.material_overlay
		if top_mat != null:
			mi.material_overlay = top_mat
		else:
			mi.material_overlay = _old_overlays[mi] as Material

	_show_overhead(marked or poisoned)
	if _sigil != null:
		_sigil.visible = marked
	_show_fire(burning)
	_show_bubbles(poisoned)
	for i in _icons.size():
		_icons[i].visible = i < poison.size()


func _draw(_delta: float) -> void:
	if _overhead != null and _overhead.visible:
		_overhead.global_position = _over_head()
		var cam := get_viewport().get_camera_3d()
		if cam != null:
			var to := cam.global_position
			if to.distance_squared_to(_overhead.global_position) > 0.01:
				_overhead.look_at(to, Vector3.UP)
		if _sigil != null and _sigil.visible:
			_sigil.rotation.z = _clock * 0.9
			var breathe := (1.0 + 0.06 * sin(_clock * 3.2)) * SIGIL_SCALE
			_sigil.scale = _sigil.scale.lerp(Vector3.ONE * breathe, 0.12)
	if _fire_light != null and _fire_light.visible:
		_fire_light.light_energy = 2.2 + 0.6 * sin(_clock * 13.0) + 0.4 * sin(_clock * 7.3)
		_fire_light.position = Vector3.UP * _height() * 0.6
	if _skin != null:
		var burning := burn_left > 0.0
		var goal := 1.0 if burning else float(poison.size()) / float(POISON_MAX)
		var now := float(_skin.get_shader_parameter(&"amount"))
		_skin.set_shader_parameter(&"amount", move_toward(now, goal * 0.85, 0.6 * get_process_delta_time()))


## How big the overhead things are drawn, from how big the creature is.
func _size() -> float:
	return clampf(_top() / 2.2, 0.7, 2.2)


func _show_overhead(on: bool) -> void:
	if not on and _overhead == null:
		return
	if _overhead == null:
		_overhead = Node3D.new()
		_overhead.name = "Overhead"
		_overhead.top_level = true
		add_child(_overhead)
	_overhead.visible = on
	_overhead.scale = Vector3.ONE * _size() * 0.8


## The hunter's sigil against the rest of what hangs over the head: smaller, so
## it says *marked* without sitting over the creature like a hat.
const SIGIL_SCALE := 0.7


func _pop_sigil() -> void:
	_show_overhead(true)
	if _sigil == null:
		_sigil = _make_sigil()
		_overhead.add_child(_sigil)
	_sigil.visible = true
	_sigil.scale = Vector3.ONE * 0.05
	var tw := _sigil.create_tween()
	tw.tween_property(_sigil, "scale", Vector3.ONE * 1.3 * SIGIL_SCALE, 0.14).set_ease(Tween.EASE_OUT)
	tw.tween_property(_sigil, "scale", Vector3.ONE * 0.95 * SIGIL_SCALE, 0.12)
	tw.tween_property(_sigil, "scale", Vector3.ONE * SIGIL_SCALE, 0.1)
	var into := Blood.world_of(_creature)
	if into != null:
		var at := _over_head()
		SkillFx.ring(into, at, _overhead.global_basis.z, GOLD, 0.4 * _size() * SIGIL_SCALE, 1.6 * _size() * SIGIL_SCALE, 0.4, 0.04, 2.5)


## The hunter's mark: a ring, four arrowheads pointing in, a ring of ticks
## and a panther's eye, flat in the XY plane.
func _make_sigil() -> Node3D:
	var s := Node3D.new()
	s.name = "Sigil"
	var gold := SkillFx.glow(GOLD, 3.0, false)
	var red := SkillFx.glow(CRIMSON, 3.5, false)
	gold.no_depth_test = true
	red.no_depth_test = true
	gold.render_priority = 2
	red.render_priority = 3
	s.add_child(_torus(0.43, 0.5, gold))
	s.add_child(_torus(0.33, 0.36, red))
	for k in 4:
		var a := PI * 0.5 * k
		for big in [true, false]:
			var p := PrismMesh.new()
			p.size = Vector3(0.2, 0.2, 0.01) if big else Vector3(0.1, 0.1, 0.01)
			var mi := MeshInstance3D.new()
			mi.mesh = p
			mi.material_override = gold if big else red
			var r := 0.53 if big else 0.67
			mi.position = Vector3(sin(a) * r, cos(a) * r, 0.0)
			mi.rotation.z = -a + PI
			s.add_child(mi)
	for k in 8:
		var a := PI * 0.125 + PI * 0.25 * k
		var b := BoxMesh.new()
		b.size = Vector3(0.035, 0.08, 0.01)
		var mi := MeshInstance3D.new()
		mi.mesh = b
		mi.material_override = red
		mi.position = Vector3(sin(a) * 0.29, cos(a) * 0.29, 0.0)
		mi.rotation.z = -a
		s.add_child(mi)
	var eye := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.2
	sph.height = 0.4
	eye.mesh = sph
	eye.scale = Vector3(1.0, 0.42, 0.1)
	eye.material_override = gold
	s.add_child(eye)
	var pupil := MeshInstance3D.new()
	var slit := SphereMesh.new()
	slit.radius = 0.1
	slit.height = 0.2
	pupil.mesh = slit
	pupil.scale = Vector3(0.28, 0.75, 0.12)
	pupil.position = Vector3(0, 0, 0.03)
	pupil.material_override = red
	s.add_child(pupil)
	for c in s.get_children():
		(c as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return s


func _torus(inner: float, outer: float, mat: Material) -> MeshInstance3D:
	var t := TorusMesh.new()
	t.inner_radius = inner
	t.outer_radius = outer
	t.rings = 48
	t.ring_segments = 4
	var mi := MeshInstance3D.new()
	mi.mesh = t
	mi.rotation.x = PI * 0.5
	mi.scale = Vector3(1.0, 0.15, 1.0)
	mi.material_override = mat
	return mi




func _show_fire(on: bool) -> void:
	if not on and _fire == null:
		return
	if _fire == null:
		var r := _radius()
		var h := _height()
		var big := clampf(h / 1.6, 0.6, 2.5)
		_fire = SkillFx.particles(self, _creature.global_position + Vector3.UP * h * 0.5, {
			"amount": int(36 * clampf(big, 1.0, 2.0)), "life": 0.75, "speed": Vector2(0.6, 1.6),
			"dir": Vector3.UP, "spread": 12.0, "gravity": Vector3(0, 1.5, 0),
			"size": Vector2(0.3, 0.6) * big, "box": Vector3(r * 0.9, h * 0.42, r * 0.9),
			"colors": [Color(1.0, 0.62, 0.18, 0.0), Color(1.0, 0.5, 0.08, 0.95), Color(0.92, 0.2, 0.02, 0.85),
				Color(0.25, 0.03, 0.0, 0.0)],
			"tex": SkillFx.flame(), "quad": Vector2(0.5, 1.0), "add": false, "grow": 0.25,
		})
		_fire.position = Vector3.UP * h * 0.5
		_embers = SkillFx.particles(self, _creature.global_position + Vector3.UP * h * 0.6, {
			"amount": 24, "life": 1.4, "speed": Vector2(0.8, 2.2), "spread": 35.0,
			"gravity": Vector3(0, 0.6, 0), "damping": 0.5, "size": Vector2(0.03, 0.06),
			"box": Vector3(r, h * 0.4, r),
			"colors": [Color(1.0, 0.8, 0.4, 1.0), Color(1.0, 0.35, 0.05, 1.0), Color(0.6, 0.1, 0.0, 0.0)],
		})
		_embers.position = Vector3.UP * h * 0.6
		_fire_light = OmniLight3D.new()
		_fire_light.light_color = Color(1.0, 0.5, 0.15)
		_fire_light.omni_range = maxf(4.0, h * 2.0)
		_fire_light.shadow_enabled = false
		add_child(_fire_light)
	_fire.emitting = on
	_embers.emitting = on
	_fire_light.visible = on


func _show_bubbles(on: bool) -> void:
	if not on and _bubbles == null:
		return
	if _bubbles == null:
		var r := _radius()
		var h := _height()
		_bubbles = SkillFx.particles(self, _creature.global_position + Vector3.UP * h * 0.5, {
			"amount": 22, "life": 1.6, "speed": Vector2(0.3, 0.9), "spread": 20.0,
			"gravity": Vector3(0, 0.4, 0), "size": Vector2(0.04, 0.09) * clampf(h / 1.6, 0.8, 2.0),
			"box": Vector3(r, h * 0.45, r),
			"colors": [Color(venom_color.lightened(0.3), 0.0), Color(venom_color, 0.9),
				Color(venom_color.darkened(0.4), 0.0)],
		})
		_bubbles.position = Vector3.UP * h * 0.5
	_bubbles.emitting = on


func _pop_icon(index: int) -> void:
	_show_overhead(true)
	while _icons.size() < POISON_MAX:
		var mi := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = 0.1
		s.height = 0.2
		mi.mesh = s
		var mat := SkillFx.glow(venom_color, 2.6, false)
		mat.no_depth_test = true
		mat.render_priority = 2
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visible = false
		_overhead.add_child(mi)
		_icons.append(mi)
	for i in _icons.size():
		# A drop: pointed up. Five in a row under where the sigil would be.
		_icons[i].position = Vector3((i - (POISON_MAX - 1) * 0.5) * 0.24, -0.72, 0.0)
	var icon := _icons[clampi(index, 0, _icons.size() - 1)]
	icon.visible = true
	icon.scale = Vector3(0.1, 0.15, 0.1)
	var tw := icon.create_tween()
	tw.tween_property(icon, "scale", Vector3(1.5, 2.2, 1.0), 0.12)
	tw.tween_property(icon, "scale", Vector3(1.0, 1.45, 0.6), 0.15)


func _clear_all() -> void:
	for mi in _old_overlays:
		if is_instance_valid(mi):
			(mi as MeshInstance3D).material_overlay = _old_overlays[mi]
	_old_overlays.clear()
	if _overhead != null:
		_overhead.queue_free()
		_overhead = null




func _skin_material() -> ShaderMaterial:
	if _skin == null:
		if _skin_shader == null:
			_skin_shader = Shader.new()
			_skin_shader.code = SKIN_CODE
		if _noise == null:
			var n := FastNoiseLite.new()
			n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
			n.frequency = 0.02
			n.fractal_octaves = 3
			_noise = NoiseTexture2D.new()
			_noise.noise = n
			_noise.seamless = true
			_noise.width = 256
			_noise.height = 256
		_skin = ShaderMaterial.new()
		_skin.shader = _skin_shader
		_skin.set_shader_parameter(&"noise_tex", _noise)
		_skin.set_shader_parameter(&"amount", 0.0)
		_skin.set_shader_parameter(&"tile", 1.4 / clampf(_top() / 2.0, 0.8, 2.5))
	return _skin
#endregion


const SKIN_CODE := """
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, blend_mix;
uniform vec4 glow_color : source_color = vec4(1.0, 0.45, 0.08, 1.0);
uniform vec4 dark_color : source_color = vec4(0.05, 0.03, 0.02, 0.5);
uniform float amount = 0.0;
uniform float tile = 1.4;
uniform float lines = 0.08;
uniform sampler2D noise_tex : repeat_enable, filter_linear;
varying vec3 lpos;
varying vec3 lnor;
void vertex() {
	float s = length(MODEL_MATRIX[0].xyz);
	VERTEX += NORMAL * 0.004 / max(s, 0.0001);
	lpos = VERTEX * s;
	lnor = NORMAL;
}
float tri(vec3 p, vec3 n) {
	vec3 w = pow(abs(n), vec3(4.0));
	w /= (w.x + w.y + w.z + 0.0001);
	return texture(noise_tex, p.yz).r * w.x + texture(noise_tex, p.xz).r * w.y + texture(noise_tex, p.xy).r * w.z;
}
void fragment() {
	vec3 p = lpos * tile;
	float v = tri(p, lnor);
	float ridge = 1.0 - abs(v * 2.0 - 1.0);
	float vein = smoothstep(1.0 - lines, 1.0 - lines * 0.3, ridge);
	float spread = tri(p * 0.37 + vec3(7.1, 3.3, 5.7), lnor);
	float on = smoothstep(spread - 0.08, spread, amount);
	float pulse = 0.8 + 0.2 * sin(TIME * 6.0 + v * 20.0);
	float glow = vein * on;
	ALBEDO = mix(dark_color.rgb, glow_color.rgb * 2.4 * pulse, glow);
	ALPHA = clamp(max(glow, on * dark_color.a), 0.0, 1.0);
}
"""
