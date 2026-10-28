class_name OrcTotem
extends StaticBody3D

## An orcs' totem (the user's word, 2026-10-21: break three orc totems): a
## post of black wood, skulls lashed up it, horns at its top round a red light
## that beats like a heart. While it stands the place's creatures are warded
## ([RoomGoal] "totems"). Three blows of a blade, or the hero's skills, break
## it: it splits and its light goes out.
##
## In the group "enemy" so the heroes can lock on to it and their cuts land on
## it ([HurtboxComponent]); it thinks on the host.

signal broken

const BLOWS := 3
const PULSE := Color(1.0, 0.12, 0.06)

var is_dead: bool = false
var hits_left: int = BLOWS
var _core: StandardMaterial3D
var _light: OmniLight3D
var _parts: Array[MeshInstance3D] = []
var _clock: float = 0.0
var _last_hit: float = -1.0


func _ready() -> void:
	add_to_group(&"enemy")
	set_meta(&"matter", &"wood")
	var box := HurtboxComponent.of(self)
	box.set_capsule(0.45, 3.2, 0.25)
	# a body on the creatures' layer, so arrows and bolts strike it too (the
	# user's word, 2026-10-28: the archer could not break one): they find what
	# they hit by rays on bodies, and take_hit counts as one of its three
	collision_layer = 4
	collision_mask = 0
	var solid := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.45
	cap.height = 3.2
	solid.shape = cap
	solid.position.y = 1.6
	add_child(solid)
	_build()


func hurtbox() -> HurtboxComponent:
	return HurtboxComponent.of(self)


func take_hit(damage: float, at: Vector3, blow: Vector3, critical: bool = false,
		spill: bool = true, from: Node = null, magic: bool = false) -> void:
	hurtbox().take_hit(damage, at, blow, critical, spill, from, magic)


func _decides() -> bool:
	if is_dead:
		return false
	var net := get_node_or_null(^"/root/Net")
	return net == null or bool(net.call(&"is_host"))


## A blow on it: one of its three, whatever it was worth (a quick string of
## cuts in one swing counts once).
func receive_hit(hit: HitInfo) -> bool:
	if is_dead:
		return false
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_hit < 0.25:
		return false
	_last_hit = now
	hits_left -= 1
	ImpactFx.strike(self, hit.at, &"wood")
	var world := Blood.world_of(self)
	if world != null:
		SkillFx.burst(world, hit.at, Color(0.35, 0.22, 0.12), 18, Vector2(2.0, 5.0), Vector3.UP, 120.0,
				Vector2(0.04, 0.09), Vector3(0, -9.0, 0), 0.6)
		SkillFx.burst(world, global_position + Vector3.UP * 3.1, PULSE, 20, Vector2(1.0, 3.0), Vector3.UP, 180.0,
				Vector2(0.04, 0.1), Vector3.ZERO, 0.5)
	var shake := create_tween()
	shake.tween_property(self, "rotation:z", 0.08, 0.05)
	shake.tween_property(self, "rotation:z", -0.05, 0.08)
	shake.tween_property(self, "rotation:z", 0.0, 0.1)
	if hits_left <= 0:
		_break()
	return true


func _physics_process(_delta: float) -> void:
	if not is_dead and _decides():
		hurtbox().scan()


func _process(delta: float) -> void:
	if is_dead or _core == null:
		return
	_clock += delta
	# a heart's beat: two quick, a rest
	var t := fmod(_clock, 1.2)
	var beat := exp(-pow((t - 0.1) * 18.0, 2.0)) + 0.7 * exp(-pow((t - 0.32) * 18.0, 2.0))
	_core.emission_energy_multiplier = 2.0 + 6.0 * beat
	_light.light_energy = 1.2 + 2.5 * beat


func _break() -> void:
	is_dead = true
	collision_layer = 0
	remove_from_group(&"enemy")
	var world := Blood.world_of(self)
	if world != null:
		SkillFx.burst(world, global_position + Vector3.UP * 3.0, PULSE, 90, Vector2(3.0, 8.0), Vector3.UP, 180.0,
				Vector2(0.06, 0.16), Vector3(0, -5.0, 0), 0.9)
		SkillFx.burst(world, global_position + Vector3.UP * 1.5, Color(0.3, 0.2, 0.12), 40, Vector2(2.0, 6.0),
				Vector3.UP, 140.0, Vector2(0.05, 0.12), Vector3(0, -9.0, 0), 0.8)
	ImpactFx.thud(self, global_position + Vector3.UP, true)
	_core.emission_energy_multiplier = 0.0
	_core.albedo_color = Color(0.08, 0.05, 0.04)
	var dim := create_tween()
	dim.tween_property(_light, "light_energy", 0.0, 0.6)
	# split: its top half falls over
	var top := get_node_or_null(^"Top") as Node3D
	if top != null:
		var fall := create_tween()
		fall.tween_property(top, "rotation:z", 1.4, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		fall.parallel().tween_property(top, "position:y", 0.3, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	broken.emit()


func _build() -> void:
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.09, 0.06, 0.04)
	wood.roughness = 0.9
	var bone := StandardMaterial3D.new()
	bone.albedo_color = Color(0.78, 0.74, 0.64)
	_core = StandardMaterial3D.new()
	_core.albedo_color = Color(0.5, 0.05, 0.02)
	_core.emission_enabled = true
	_core.emission = PULSE
	_core.emission_energy_multiplier = 3.0
	var foot := CylinderMesh.new()
	foot.top_radius = 0.22
	foot.bottom_radius = 0.32
	foot.height = 1.6
	foot.radial_segments = 6
	_add(self, foot, wood, Vector3(0.0, 0.8, 0.0))
	var top := Node3D.new()
	top.name = "Top"
	top.position = Vector3(0.0, 1.6, 0.0)
	add_child(top)
	var post := CylinderMesh.new()
	post.top_radius = 0.17
	post.bottom_radius = 0.22
	post.height = 1.5
	post.radial_segments = 6
	_add(top, post, wood, Vector3(0.0, 0.75, 0.0))
	# skulls lashed up it
	for k in 3:
		var a := float(k) * 2.1
		var skull := SphereMesh.new()
		skull.radius = 0.16
		skull.height = 0.3
		skull.radial_segments = 8
		skull.rings = 5
		var at := Vector3(sin(a) * 0.24, -0.6 + float(k) * 0.55, cos(a) * 0.24)
		_add(top if k > 0 else self, skull, bone, at + (Vector3.ZERO if k > 0 else Vector3(0.0, 1.6, 0.0)))
	# horns round the heart at its top
	for side: float in [-1.0, 1.0]:
		var horn := CylinderMesh.new()
		horn.top_radius = 0.0
		horn.bottom_radius = 0.09
		horn.height = 0.9
		horn.radial_segments = 6
		var h := _add(top, horn, bone, Vector3(side * 0.3, 1.75, 0.0))
		h.rotation.z = -side * 0.55
	var heart := SphereMesh.new()
	heart.radius = 0.2
	heart.height = 0.4
	_add(top, heart, _core, Vector3(0.0, 1.6, 0.0))
	_light = OmniLight3D.new()
	_light.light_color = PULSE
	_light.light_energy = 2.0
	_light.omni_range = 7.0
	_light.position = Vector3(0.0, 3.3, 0.0)
	add_child(_light)
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.35
	cyl.height = 3.2
	shape.shape = cyl
	shape.position = Vector3(0.0, 1.6, 0.0)
	body.add_child(shape)
	add_child(body)


func _add(parent: Node3D, mesh: Mesh, mat: Material, at: Vector3) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = mat
	m.position = at
	parent.add_child(m)
	_parts.append(m)
	return m
