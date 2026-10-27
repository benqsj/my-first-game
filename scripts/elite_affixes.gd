class_name EliteAffixes
extends Node

## What makes one elite unlike another (the user's word, 2026-10-27: each
## run its own; [CombatDirector]'s plan): on top of an elite's three times
## the health and its gathered fire ([FoeRoles]), one thing of its own (two
## from the sixth step on), named in a line over it:
##
## * **swift** ("სწრაფი") — a third quicker on its feet and in its turns.
## * **shielded** ("ფარიანი") — a ward of light round it that takes the first
##   blows (a share of its life) before any reach it; it rings and breaks.
## * **explosive** ("ფეთქებადი") — falling, it leaves a ring of fire on the
##   ground that bursts a moment later: step out of it.
## * **mending** ("აღდგენადი") — let be a few seconds, it closes its wounds.
##
## Which, from its name (the same on every peer); what they do, on the host.

const ALL := {
	"swift": {"name": "სწრაფი", "tint": Color(0.55, 0.85, 1.0)},
	"shielded": {"name": "ფარიანი", "tint": Color(0.75, 0.8, 1.0)},
	"explosive": {"name": "ფეთქებადი", "tint": Color(1.0, 0.35, 0.15)},
	"mending": {"name": "აღდგენადი", "tint": Color(0.45, 1.0, 0.5)},
}
const SWIFT := 1.33
## The ward: this share of its life.
const WARD := 0.35
## The burst: the ring's reach, how long it gathers, its share of the elite's
## blow.
const BLAST_R := 3.6
const BLAST_TELL := 1.3
const BLAST_HURT := 1.6
## Mending: let be this long, then this share of its life a second.
const MEND_AFTER := 3.0
const MEND_RATE := 0.03

var kinds: Array[String] = []
var _body: Fighter
var _d: Dungeon
var _ward := 0.0
var _ward_mesh: MeshInstance3D
var _ward_mat: StandardMaterial3D
var _last_health := -1.0
var _calm := 0.0


## Gives `body` (an elite, in the tree) its own: one, or two from step 6.
static func give(body: Fighter, d: Dungeon) -> EliteAffixes:
	if body == null or d == null:
		return null
	var a := EliteAffixes.new()
	a.name = "Affixes"
	a._body = body
	a._d = d
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(String(body.name)) + 7919 * d.id
	var pool: Array = ALL.keys()
	for i in pool.size():
		var j := rng.randi_range(i, pool.size() - 1)
		var t: Variant = pool[i]
		pool[i] = pool[j]
		pool[j] = t
	var n := 2 if d.stage_of(maxi(d.current, 0)) >= 6 else 1
	for k in n:
		a.kinds.append(String(pool[k]))
	body.add_child(a)
	return a


func _ready() -> void:
	if kinds.has("swift"):
		_body.speed *= SWIFT
		_body.chase_speed *= SWIFT
		_body.acceleration *= SWIFT
		_body.turn_speed *= SWIFT
	if kinds.has("shielded"):
		_ward = _body.max_health * WARD
		_make_ward()
	if kinds.has("explosive") and _body.has_signal(&"died"):
		_body.died.connect(_on_died)
	_label()
	var title := String(_body.get_meta(&"title", ""))
	var names: Array[String] = []
	for k in kinds:
		names.append(String(ALL[k]["name"]))
	_body.set_meta(&"title", title + " · " + ", ".join(names))


func _process(delta: float) -> void:
	if not is_instance_valid(_body) or _body.is_dead:
		if _ward_mesh != null:
			_ward_mesh.visible = false
		return
	if not _d.decides():
		if _ward_mesh != null:
			_ward_mesh.visible = bool(_body.get_meta(&"warded", _ward > 0.0))
		return
	var h := _body.health
	if _last_health < 0.0:
		_last_health = h
	var lost := _last_health - h
	if lost > 0.01:
		_calm = 0.0
		if _ward > 0.0:
			var back := minf(lost, _ward)
			_ward -= back
			_body.health = h + back
			_ring_ward(_ward <= 0.0)
	else:
		_calm += delta
		if kinds.has("mending") and _calm >= MEND_AFTER and h < _body.max_health:
			_body.health = minf(h + _body.max_health * MEND_RATE * delta, _body.max_health)
	_last_health = _body.health
	_body.set_meta(&"warded", _ward > 0.0)


#region The ward
func _make_ward() -> void:
	var s := maxf(_body.visual_scale, 0.5)
	var ball := SphereMesh.new()
	ball.radius = 1.0
	ball.height = 2.0
	ball.radial_segments = 20
	ball.rings = 10
	_ward_mat = StandardMaterial3D.new()
	_ward_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ward_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ward_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_ward_mat.cull_mode = BaseMaterial3D.CULL_BACK
	_ward_mat.albedo_color = Color(0.45, 0.6, 1.0, 0.16)
	_ward_mat.rim_enabled = false
	_ward_mesh = MeshInstance3D.new()
	_ward_mesh.mesh = ball
	_ward_mesh.material_override = _ward_mat
	_ward_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var r := clampf(_body.body_radius * s, 0.9, 3.0) * 1.15
	_ward_mesh.scale = Vector3(r, clampf(_body.bar_height * s * 0.55, 1.0, 3.0), r)
	_ward_mesh.position = Vector3.UP * _ward_mesh.scale.y * 0.9
	_body.add_child(_ward_mesh)


func _ring_ward(broken: bool) -> void:
	if _ward_mesh == null:
		return
	_ward_mat.albedo_color = Color(0.7, 0.85, 1.0, 0.5)
	var tw := _ward_mesh.create_tween()
	tw.tween_property(_ward_mat, "albedo_color", Color(0.45, 0.6, 1.0, 0.16), 0.25)
	if broken:
		tw.tween_property(_ward_mesh, "scale", _ward_mesh.scale * 1.4, 0.2)
		tw.parallel().tween_property(_ward_mat, "albedo_color", Color(0.45, 0.6, 1.0, 0.0), 0.2)
		tw.tween_callback(func() -> void: _ward_mesh.visible = false)
#endregion


#region The burst
func _on_died() -> void:
	var world := Blood.world_of(_body)
	if world == null:
		return
	var blast := Node3D.new()
	blast.name = "EliteBlast"
	world.add_child(blast)
	blast.global_position = _body.global_position + Vector3.UP * 0.05
	var disc := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = BLAST_R
	cyl.bottom_radius = BLAST_R
	cyl.height = 0.04
	cyl.radial_segments = 40
	disc.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(1.0, 0.3, 0.1, 0.12)
	disc.material_override = mat
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	blast.add_child(disc)
	# the inner ring growing out to the edge: when it gets there, it bursts
	var inner := MeshInstance3D.new()
	var cyl2 := cyl.duplicate() as CylinderMesh
	inner.mesh = cyl2
	var mat2 := mat.duplicate() as StandardMaterial3D
	mat2.albedo_color = Color(1.0, 0.45, 0.15, 0.35)
	inner.material_override = mat2
	inner.position.y = 0.02
	inner.scale = Vector3(0.05, 1.0, 0.05)
	blast.add_child(inner)
	var tw := blast.create_tween()
	tw.tween_property(inner, "scale", Vector3.ONE, BLAST_TELL)
	var hurt := _body.hit_damage * BLAST_HURT
	var decides := _d.decides()
	var heroes := _d._heroes()
	tw.tween_callback(func() -> void:
		var at := blast.global_position
		SkillFx.burst(blast.get_parent(), at + Vector3.UP * 0.4, Color(1.0, 0.5, 0.15), 70,
				Vector2(4.0, 9.0), Vector3.UP, 180.0, Vector2(0.08, 0.2), Vector3(0, -4.0, 0), 0.6)
		ImpactFx.thud(blast, at, true)
		if decides:
			for hero in heroes:
				if is_instance_valid(hero) and not hero.is_dead \
						and Vector2(hero.global_position.x - at.x, hero.global_position.z - at.z).length() <= BLAST_R:
					hero.receive_blow(hurt, blast, 0, 1, 77001, true)
		disc.visible = false
		inner.visible = false)
	tw.tween_interval(0.5)
	tw.tween_callback(blast.queue_free)
#endregion


func _label() -> void:
	var l := Label3D.new()
	var names: Array[String] = []
	for k in kinds:
		names.append(String(ALL[k]["name"]))
	l.text = " · ".join(names)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.font_size = 30
	l.outline_size = 8
	l.pixel_size = 0.006
	l.modulate = ALL[kinds[0]]["tint"]
	var s := maxf(_body.visual_scale, 0.3)
	l.position = Vector3.UP * (_body.bar_height * s + 0.45) / maxf(s, 0.01)
	l.scale = Vector3.ONE / maxf(s, 0.01)
	_body.add_child(l)
