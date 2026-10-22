class_name HubLife
extends Node3D

## The village alive between the fights (release_polish_plan §4, 2026-10-22):
## the wind over it all, birds in the trees and a flock wheeling high over the
## square, now and then an eagle's cry far up, smoke from a few roofs and the
## smithy's forge, its fire heard close by. Only looks and sound: nothing here
## is in anyone's way, nothing is sent to the others (each peer has its own).
##
## Made by [World] in the peaceful open world ([method World._peaceful_world]).

const SND := "res://assets/sounds/dungeon/"
## The village square, what the flock wheels over.
const SQUARE := Vector3(72.0, 0.0, 30.0)
## Roofs that smoke: each building's chimneys, where its maker put them
## (`vepxis-art/village/houses/village.py`: x, and y which is -z here), in its
## own frame; the chimney's top is found in its mesh above that spot.
const CHIMNEYS := {
	"House1": [Vector2(1.2, 2.0)], "House3": [Vector2(2.0, 1.0)], "House5": [Vector2(-1.2, 1.5)],
	"House7": [Vector2(1.4, -2.0)], "House9": [Vector2(0.6, 2.4)], "Marani": [Vector2(2.0, -4.0)],
	"Smithy": [Vector2(1.4, 2.6), Vector2(1.4, -2.6)],
}
## Birds in the trees round about: where, in the level's frame.
const TREES: Array[Vector3] = [Vector3(20.0, 6.0, 44.0), Vector3(96.0, 6.0, 74.0), Vector3(60.0, 6.0, 8.0)]

## The flock: how many, how high, how far round.
@export var flock: int = 9
@export var flock_height: Vector2 = Vector2(18.0, 28.0)
@export var flock_radius: Vector2 = Vector2(18.0, 36.0)
## Seconds between the eagle's cries.
@export var eagle_every: Vector2 = Vector2(28.0, 60.0)

var _birds: MultiMeshInstance3D
var _bird_phase: PackedFloat32Array = PackedFloat32Array()
var _bird_radius: PackedFloat32Array = PackedFloat32Array()
var _bird_height: PackedFloat32Array = PackedFloat32Array()
var _bird_speed: PackedFloat32Array = PackedFloat32Array()
var _t: float = 0.0
var _eagle_in: float = 12.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 7123
	_wind()
	for at in TREES:
		_sound_at("birds_loop.wav", at, -13.0, 9.0, 60.0)
	# the houses are put up after this is made ([method World._dress_village])
	_smoke.call_deferred()
	_make_flock()
	_eagle_in = _rng.randf_range(8.0, 20.0)


func _process(delta: float) -> void:
	_t += delta
	_fly()
	_eagle_in -= delta
	if _eagle_in <= 0.0:
		_eagle_in = _rng.randf_range(eagle_every.x, eagle_every.y)
		_cry()


#region Sound
static func _loop(file: String) -> AudioStream:
	var path := SND + file
	if not ResourceLoader.exists(path):
		return null
	var stream := load(path) as AudioStream
	var wav := stream as AudioStreamWAV
	if wav != null and wav.loop_mode == AudioStreamWAV.LOOP_DISABLED:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = int(wav.get_length() * float(wav.mix_rate))
	return stream


## The wind over everything, low: heard everywhere, from nowhere.
func _wind() -> void:
	var stream := _loop("wind_loop.wav")
	if stream == null:
		return
	var player := AudioStreamPlayer.new()
	player.name = "Wind"
	player.stream = stream
	player.volume_db = -27.0
	add_child(player)
	player.play(_rng.randf() * 4.0)


func _sound_at(file: String, at: Vector3, db: float, unit: float, reach: float) -> AudioStreamPlayer3D:
	var stream := _loop(file)
	if stream == null:
		return null
	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	player.volume_db = db
	player.unit_size = unit
	player.max_distance = reach
	add_child(player)
	player.position = at
	player.play(_rng.randf() * 4.0)
	return player


## An eagle, far up and off to one side of whoever hears it.
func _cry() -> void:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam == null or not ResourceLoader.exists(SND + "eagle.wav"):
		return
	var a := _rng.randf() * TAU
	var at := cam.global_position + Vector3(cos(a) * 45.0, 38.0, sin(a) * 45.0)
	Sfx.play(self, SND + "eagle.wav", null, at, _rng.randf_range(0.92, 1.05), -6.0)
#endregion


#region Smoke
## Soft grey smoke from a few roofs and the smithy, drifting off with the wind;
## the forge's fire heard beside it.
func _smoke() -> void:
	var level := get_parent()
	for kind: String in CHIMNEYS:
		var house := level.find_child(kind, true, false) as MeshInstance3D
		if house == null or house.mesh == null:
			continue
		var forge := kind == "Smithy"
		for spot: Vector2 in CHIMNEYS[kind]:
			var top := _chimney_top(house, Vector3(spot.x, 0.0, -spot.y))
			if top != Vector3.INF:
				_plume(top, forge, kind)
		if forge:
			_sound_at("fire_loop.wav", house.global_position + Vector3.UP * 1.0, -16.0, 3.0, 22.0)


func _plume(top: Vector3, forge: bool, kind: String) -> void:
	var plume := SkillFx.particles(self, top, {
		"amount": 18 if forge else 14, "life": 8.0, "one_shot": false, "add": false,
		"speed": Vector2(0.5, 0.9), "dir": Vector3.UP, "spread": 10.0,
		"gravity": Vector3(0.22, 0.28, 0.08), "damping": 0.15,
		"size": Vector2(1.6, 2.8) * (1.2 if forge else 1.0), "grow": 0.5, "sphere": 0.25,
		"colors": [Color(0.36, 0.36, 0.38, 0.0), Color(0.34, 0.34, 0.36, 0.28 if forge else 0.2),
				Color(0.42, 0.42, 0.44, 0.0)],
	})
	plume.name = "Smoke_%s" % kind
	plume.visibility_aabb = AABB(Vector3(-8.0, -2.0, -8.0), Vector3(16.0, 30.0, 16.0))
	plume.preprocess = 6.0


## The top of the chimney standing over `at` (the building's own frame,
## ground level), in the world: the highest of its mesh's points within a
## step of it. INF if there is none.
static func _chimney_top(house: MeshInstance3D, at: Vector3) -> Vector3:
	var best := -INF
	for si in house.mesh.get_surface_count():
		var arrays := house.mesh.surface_get_arrays(si)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for v in verts:
			if absf(v.x - at.x) < 0.45 and absf(v.z - at.z) < 0.45 and v.y > best:
				best = v.y
	if best == -INF:
		return Vector3.INF
	return house.global_transform * Vector3(at.x, best + 0.15, at.z)
#endregion


#region The flock
## A bird: a body and two wings, dark against the sky; its wings beat in the
## shader, each bird at its own time.
const BIRD_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
uniform vec4 colour : source_color = vec4(0.06, 0.06, 0.07, 1.0);
void vertex() {
	float wing = abs(VERTEX.x);
	float beat = sin(TIME * (7.0 + INSTANCE_CUSTOM.y * 3.0) + INSTANCE_CUSTOM.x * 6.2831);
	// now and then gliding, wings out and still
	float glide = smoothstep(0.55, 0.75, sin(TIME * 0.35 + INSTANCE_CUSTOM.x * 9.0));
	VERTEX.y += wing * beat * 0.55 * (1.0 - glide);
}
void fragment() {
	ALBEDO = colour.rgb;
}
"""


func _make_flock() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var front := Vector3(0.0, 0.0, -0.32)
	var back := Vector3(0.0, 0.0, 0.26)
	var left := Vector3(-0.75, 0.04, 0.1)
	var right := Vector3(0.75, 0.04, 0.1)
	var tail_l := Vector3(-0.12, 0.0, 0.42)
	var tail_r := Vector3(0.12, 0.0, 0.42)
	for tri: Array in [[front, left, back], [front, back, right], [back, tail_l, tail_r]]:
		for v: Vector3 in tri:
			st.set_normal(Vector3.UP)
			st.add_vertex(v)
	var mesh := st.commit()
	var mat := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = BIRD_SHADER
	mat.shader = shader
	mesh.surface_set_material(0, mat)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.instance_count = flock
	mm.mesh = mesh
	for i in flock:
		_bird_phase.append(_rng.randf() * TAU)
		_bird_radius.append(_rng.randf_range(flock_radius.x, flock_radius.y))
		_bird_height.append(_rng.randf_range(flock_height.x, flock_height.y))
		_bird_speed.append(_rng.randf_range(0.10, 0.16))
		mm.set_instance_custom_data(i, Color(_rng.randf(), _rng.randf(), 0.0, 0.0))
	_birds = MultiMeshInstance3D.new()
	_birds.name = "Flock"
	_birds.multimesh = mm
	_birds.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_birds)
	_birds.position = SQUARE
	_fly()
	# drawn wherever it has gone in its circle
	_birds.custom_aabb = AABB(Vector3(-60.0, 20.0, -60.0), Vector3(120.0, 40.0, 120.0))


## Each bird round its own circle over the square, rising and falling a
## little, facing the way it flies, banked into the turn.
func _fly() -> void:
	if _birds == null:
		return
	var mm := _birds.multimesh
	for i in mm.instance_count:
		var a := _bird_phase[i] + _t * _bird_speed[i] * (1.0 if i % 3 != 0 else -1.0)
		var r := _bird_radius[i] + sin(_t * 0.2 + float(i)) * 4.0
		var at := Vector3(cos(a) * r, _bird_height[i] + sin(_t * 0.5 + float(i) * 1.3) * 2.0, sin(a) * r)
		var way := Vector3(-sin(a), 0.0, cos(a)) * (1.0 if i % 3 != 0 else -1.0)
		var basis := Basis.looking_at(way, Vector3.UP).rotated(way.normalized(), 0.35 * (1.0 if i % 3 != 0 else -1.0))
		mm.set_instance_transform(i, Transform3D(basis.scaled(Vector3.ONE * 1.8), at))
#endregion
