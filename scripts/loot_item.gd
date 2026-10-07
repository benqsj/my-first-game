class_name LootItem
extends Node3D

## A thing on the ground for one hero ([LootDrop]): a soft glowing mote low
## over the grass with a faint thread of light above it, so it is seen from
## afar, as the things on the ground are in Elden Ring. It drifts down out of
## the body that dropped it; when the hero walks over it, it is his
## ([method Player.gain]), flies into him, and the HUD says what it was
## ([method PlayerHud.found]). Only his own peer has it.

const GLOW := Color(1.0, 0.84, 0.5)
const PICK_UP := 1.5
## How soon it can be taken (it is still coming down).
const SETTLE := 0.7
const LIFE := 900.0
const FLY := 0.35
const HOVER := 0.32
const BEAM := 1.7
const SOUND := "res://unverified/sounds/all/loot_1.wav"

var item: Dictionary = {}
var hero: Player = null
var picture: Texture2D = null
var age: float = 0.0

var _floor: float = 0.0
var _mote: MeshInstance3D
var _halo: MeshInstance3D
var _beam: MeshInstance3D
var _light: OmniLight3D
var _fly_t: float = -1.0
var _from: Vector3

static var _beam_mat: StandardMaterial3D
static var _mote_mat: StandardMaterial3D
static var _halo_mat: StandardMaterial3D


## `found` laid on the ground at `at` (in `into`) for `by`.
static func lay(into: Node, at: Vector3, found: Dictionary, by: Player, pic: Texture2D = null) -> LootItem:
	var thing := LootItem.new()
	thing.name = "Loot"
	thing.item = found
	thing.hero = by
	thing.picture = pic
	into.add_child(thing)
	thing.global_position = at
	thing._build()
	return thing


static func _materials() -> void:
	if _beam_mat != null:
		return
	# a thread of light: brightest at the ground, gone at the top
	var fade := Gradient.new()
	fade.set_color(0, Color(GLOW, 0.0))
	fade.set_color(1, Color(GLOW, 0.8))
	var tex := GradientTexture2D.new()
	tex.gradient = fade
	tex.fill_from = Vector2(0.0, 0.0)
	tex.fill_to = Vector2(0.0, 1.0)
	tex.width = 4
	tex.height = 64
	_beam_mat = StandardMaterial3D.new()
	_beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_beam_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_beam_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_beam_mat.albedo_texture = tex
	_beam_mat.no_depth_test = false
	_mote_mat = StandardMaterial3D.new()
	_mote_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mote_mat.albedo_color = Color(1.0, 0.97, 0.88)
	# a soft round glow about it, always facing the eye
	var ring := Gradient.new()
	ring.set_color(0, Color(GLOW, 0.9))
	ring.set_color(1, Color(GLOW, 0.0))
	var halo := GradientTexture2D.new()
	halo.gradient = ring
	halo.fill = GradientTexture2D.FILL_RADIAL
	halo.fill_from = Vector2(0.5, 0.5)
	halo.fill_to = Vector2(0.5, 0.0)
	halo.width = 64
	halo.height = 64
	_halo_mat = StandardMaterial3D.new()
	_halo_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_halo_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_halo_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_halo_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_halo_mat.albedo_texture = halo


func _build() -> void:
	_materials()
	_floor = global_position.y
	var space := get_world_3d().direct_space_state if is_inside_tree() else null
	if space != null:
		var q := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 1.5,
				global_position + Vector3.DOWN * 4.0, 1)
		var hit := space.intersect_ray(q)
		if not hit.is_empty():
			_floor = (hit["position"] as Vector3).y
	global_position.y = _floor
	var sphere := SphereMesh.new()
	sphere.radius = 0.045
	sphere.height = 0.09
	sphere.radial_segments = 12
	sphere.rings = 6
	sphere.material = _mote_mat
	_mote = MeshInstance3D.new()
	_mote.mesh = sphere
	_mote.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mote)
	var quad := QuadMesh.new()
	quad.size = Vector2(0.8, 0.8)
	quad.material = _halo_mat
	_halo = MeshInstance3D.new()
	_halo.mesh = quad
	_halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mote.add_child(_halo)
	var thread := CylinderMesh.new()
	thread.top_radius = 0.006
	thread.bottom_radius = 0.022
	thread.height = BEAM
	thread.radial_segments = 8
	thread.rings = 1
	thread.cap_top = false
	thread.cap_bottom = false
	thread.material = _beam_mat
	_beam = MeshInstance3D.new()
	_beam.mesh = thread
	_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_beam)
	_beam.position = Vector3.UP * (HOVER + BEAM * 0.5)
	_light = OmniLight3D.new()
	_light.light_color = GLOW
	_light.light_energy = 0.0
	_light.omni_range = 2.2
	_light.shadow_enabled = false
	add_child(_light)
	_light.position = Vector3.UP * 0.4
	_mote.position = Vector3.UP * 1.1


func _process(delta: float) -> void:
	age += delta
	if _fly_t >= 0.0:
		_fly(delta)
		return
	if age > LIFE or hero == null or not is_instance_valid(hero):
		queue_free()
		return
	# down out of the body, then a slow rise and fall
	var k := clampf(age / SETTLE, 0.0, 1.0)
	var e := 1.0 - (1.0 - k) * (1.0 - k)
	var bob := sin(age * 2.2) * 0.035 * k
	_mote.position = Vector3.UP * (lerpf(1.1, HOVER, e) + bob)
	var pulse := 0.8 + 0.2 * sin(age * 3.3)
	_beam.scale = Vector3(1.0, maxf(k, 0.01), 1.0)
	_beam.position = Vector3.UP * (HOVER + BEAM * 0.5 * k)
	_halo.scale = Vector3.ONE * (0.85 + 0.15 * pulse)
	_light.light_energy = 0.9 * k * pulse
	if age >= SETTLE and not hero.is_dead:
		var gap := hero.global_position - (global_position + Vector3.UP * HOVER)
		gap.y *= 0.5
		if gap.length() < PICK_UP:
			_take()


func _take() -> void:
	hero.gain(String(item.get("loot_key", Inventory.key_of(item))))
	var hud := hero.get_node_or_null(^"Hud")
	if hud != null and hud.has_method(&"found"):
		hud.call(&"found", String(item.get("name", "")), picture)
	Sfx.play(self, SOUND, null, global_position + Vector3.UP * 0.4, 1.15, -12.0)
	_fly_t = 0.0
	_from = _mote.global_position


func _fly(delta: float) -> void:
	_fly_t += delta
	var t := clampf(_fly_t / FLY, 0.0, 1.0)
	var e := t * t * (3.0 - 2.0 * t)
	var target := _from
	if hero != null and is_instance_valid(hero):
		target = hero.global_position + Vector3.UP * 1.1
	_mote.global_position = _from.lerp(target, e) + Vector3.UP * sin(e * PI) * 0.4
	_mote.scale = Vector3.ONE * (1.0 - 0.7 * e)
	_beam.scale = Vector3(1.0 - e, maxf(1.0 - e, 0.01), 1.0 - e)
	_light.light_energy = 1.2 * (1.0 - t)
	if t >= 1.0:
		queue_free()
