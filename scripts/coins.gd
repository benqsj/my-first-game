class_name Coins
extends Node3D

## A scatter of gold coins on the ground ([CoinBank]): thrown up out of where
## a creature fell, they spin, come down, bounce and lie glinting; taken, they
## fly up into the hero who took them and are gone. All looks, on every peer.

const GOLD := Color(1.0, 0.76, 0.28)
const RADIUS := 0.045
const THICK := 0.009
const GRAVITY := 9.8
const LIFE := 120.0
const FLY := 0.32

static var _mesh: CylinderMesh
static var _material: StandardMaterial3D

var amount: int = 0
var id: int = 0
var age: float = 0.0

var _coins: Array[MeshInstance3D] = []
var _vel: Array[Vector3] = []
var _spin: Array[Vector3] = []
var _floor: float = 0.0
var _light: OmniLight3D
var _into: Node3D = null
var _fly_t: float = -1.0
var _from: Array[Vector3] = []


## `amount` gold thrown out at `at` (into `into`).
static func scatter(into: Node, at: Vector3, gold: int, pile_id: int) -> Coins:
	var pile := Coins.new()
	pile.name = "Coins_%d" % pile_id
	pile.amount = gold
	pile.id = pile_id
	into.add_child(pile)
	pile.global_position = at
	pile._throw()
	return pile


static func _coin_mesh() -> CylinderMesh:
	if _mesh == null:
		_mesh = CylinderMesh.new()
		_mesh.top_radius = RADIUS
		_mesh.bottom_radius = RADIUS
		_mesh.height = THICK
		_mesh.radial_segments = 14
		_mesh.rings = 1
		_material = StandardMaterial3D.new()
		_material.albedo_color = GOLD
		_material.metallic = 1.0
		_material.roughness = 0.28
		_material.emission_enabled = true
		_material.emission = GOLD
		_material.emission_energy_multiplier = 0.25
		_mesh.material = _material
	return _mesh


func _throw() -> void:
	# The ground under it.
	_floor = global_position.y
	var space := get_world_3d().direct_space_state if is_inside_tree() else null
	if space != null:
		var q := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 1.5,
				global_position + Vector3.DOWN * 4.0, 1)
		var hit := space.intersect_ray(q)
		if not hit.is_empty():
			_floor = (hit["position"] as Vector3).y
	var count := clampi(int(ceil(float(amount) / 2.0)), 3, 16)
	var rng := RandomNumberGenerator.new()
	rng.seed = id * 7919 + amount
	for i in count:
		var coin := MeshInstance3D.new()
		coin.mesh = _coin_mesh()
		coin.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(coin)
		coin.position = Vector3(rng.randf_range(-0.12, 0.12), 0.9, rng.randf_range(-0.12, 0.12))
		coin.rotation = Vector3(rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU)
		var a := rng.randf() * TAU
		var out := rng.randf_range(0.6, 1.9)
		_vel.append(Vector3(cos(a) * out, rng.randf_range(2.6, 4.2), sin(a) * out))
		_spin.append(Vector3(rng.randf_range(-14, 14), rng.randf_range(-6, 6), rng.randf_range(-14, 14)))
		_coins.append(coin)
	_light = OmniLight3D.new()
	_light.light_color = GOLD
	_light.light_energy = 0.0
	_light.omni_range = 1.6
	_light.shadow_enabled = false
	add_child(_light)
	_light.position = Vector3.UP * 0.25


## Taken: up into `hero`'s chest, then gone.
func fly_into(hero: Node3D) -> void:
	_into = hero
	_fly_t = 0.0
	_from.clear()
	for c in _coins:
		_from.append(c.global_position)
	if hero == null:
		queue_free()


func _process(delta: float) -> void:
	age += delta
	if _fly_t >= 0.0:
		_fly(delta)
		return
	if age > LIFE:
		queue_free()
		return
	var ground := _floor - global_position.y + THICK * 0.5
	for i in _coins.size():
		var c := _coins[i]
		var v := _vel[i]
		if v == Vector3.ZERO:
			continue
		v.y -= GRAVITY * delta
		c.position += v * delta
		c.rotation += _spin[i] * delta
		if c.position.y <= ground and v.y < 0.0:
			c.position.y = ground
			if v.y < -1.6:
				# A bounce, losing most of it.
				v = Vector3(v.x * 0.45, -v.y * 0.32, v.z * 0.45)
				_spin[i] *= 0.5
			else:
				# Down: flat on the ground, a turn of its own.
				v = Vector3.ZERO
				c.rotation = Vector3(0.0, c.rotation.y, 0.0) if randf() < 0.8 \
						else Vector3(PI * 0.5, c.rotation.y, 0.0)
		_vel[i] = v
	# The glint: a slow, soft pulse once they are down.
	_light.light_energy = clampf(age - 0.5, 0.0, 1.0) * (0.35 + 0.25 * sin(age * 3.1))


func _fly(delta: float) -> void:
	_fly_t += delta
	var t := clampf(_fly_t / FLY, 0.0, 1.0)
	var target := global_position
	if _into != null and is_instance_valid(_into):
		target = _into.global_position + Vector3.UP * 1.1
	for i in _coins.size():
		var c := _coins[i]
		var k := clampf(t * 1.25 - float(i) / float(_coins.size()) * 0.25, 0.0, 1.0)
		var e := k * k * (3.0 - 2.0 * k)
		var lift := Vector3.UP * sin(e * PI) * 0.6
		c.global_position = _from[i].lerp(target, e) + lift
		c.rotation += Vector3(12.0, 4.0, 9.0) * delta
		c.scale = Vector3.ONE * (1.0 - 0.6 * e)
	_light.light_energy = 0.8 * (1.0 - t)
	if t >= 1.0:
		queue_free()
