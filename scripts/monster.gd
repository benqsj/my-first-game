class_name Monster
extends CharacterBody3D

## A creature out of the Bestiary kit, wandering its patch of the forest.
##
## The kit ships rigged but with no clips of its own, and it is built to the
## Unreal mannequin's bone names — which is also what the Quaternius library the
## rest of the game animates from uses. So there is nothing to author: the
## skeleton is handed to a [SkeletonAnim] layer and the shamble, the idle and the
## occasional scratch are the library's, retargeted onto whatever proportions the
## creature happens to have.
##
## The wander itself is the golem's: pick a spot, walk to it, wait, pick another,
## out and back along a line so it reads as patrolling rather than as drifting.
## What is new is that the legs are real, so the playback rate is tied to the
## ground speed — a stride is measured off the clip at load and the cycle is
## retimed every frame, which is what keeps the feet from skating.
##
## **The host decides.** `_physics_process` only runs on the peer that owns the
## level; everyone else animates the body from the position and velocity the
## [MultiplayerSynchronizer] brings in, which is the same split the wolf and the
## golem use.

@export_group("Movement")
@export var speed: float = 1.6
@export var acceleration: float = 6.0
@export var turn_speed: float = 6.0
## How far from where it started it will wander.
@export var roam_radius: float = 7.0
## Seconds it stands still between walks.
@export var rest_time: float = 2.2
## How much the rest is allowed to vary, so a pair of creatures does not fall
## into step with each other.
@export var rest_spread: float = 1.6

## Tallest step it walks up rather than into.
@export var step_height: float = 0.4
@export var step_probe: float = 0.6

@export_group("Animation")
## The forward cycle. `Zombie_Walk_Fwd` is the library's only monstrous one; the
## knight's `Walk_Carry` reads as a man carrying a crate.
@export var walk_clip: StringName = &"Zombie_Walk_Fwd"
@export var idle_clip: StringName = &"Zombie_Idle"
## Played now and then while standing, so an idle creature is not a statue.
@export var fidget_clip: StringName = &"Zombie_Scratch"
## Seconds between fidgets, on average. Zero turns them off.
@export var fidget_interval: float = 7.0
## Ceiling on how far the walk cycle is sped up or slowed down to match the
## ground. Beyond this the feet slide a little rather than the clip running at a
## rate it was never authored for.
@export var retime_range: Vector2 = Vector2(0.55, 1.8)
## Where the clips come from: empty for the shared library, or a file of the
## creature's own made on its own rig (the imp's, `imp_anims.glb`).
@export_file("*.glb") var clip_source: String = ""
## Clips in `clip_source` that are cycles (a file out of Blender carries no
## loop flag).
@export var loop_clips: PackedStringArray = PackedStringArray()
## For a skeleton of its own rather than the mannequin's: the bone whose
## travel is played (the hips), and the two feet a stride is measured between.
## Whether the body is lifted so its lowest point stands on the ground. Off
## for a model already standing on its feet at the origin, whose weapon hangs
## below them at rest (vepxis-art tools/mon_build.py).
@export var settle_on_ground: bool = true
@export var hips_bone: String = "pelvis"
@export var foot_bones: PackedStringArray = PackedStringArray(["foot_l", "foot_r"])

@export_group("Appearance")
## Size the creature is drawn at, on top of whatever the `Visuals` node already
## carries. The collider is sized by hand in the scene to match, so the two are
## meant to be changed together.
@export var visual_scale: float = 1.0
## Which of the kit's colourways to wear, 1 to 3.
##
## The Bestiary ships three base-colour maps per creature and one mesh. That is
## the cheapest variety there is: a green imp and a grey one are two creatures as
## far as anybody looking at them is concerned, and one mesh and one skeleton as
## far as the engine is concerned. Skin 1 is what the model arrives wearing and
## costs nothing; the others are one material swap at load.
@export_range(1, 3) var skin: int = 1
## Where those maps live. Worked out from the model when this is left empty.
@export var skin_dir: String = ""

@onready var body: Node3D = $Visuals

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var _anim: SkeletonAnim
var _skeleton: Skeleton3D
## Metres of ground one cycle of `walk_clip` covers on this creature.
var _stride: float = 1.0
## Seconds one cycle lasts at rate 1.
var _cycle: float = 1.0

var _home: Vector3
var _target: Vector3
var _wait: float = 0.0
var _fidget_in: float = 0.0
var _rng := RandomNumberGenerator.new()
## The line this creature walks along, as an offset from home.
var _beat: Vector3 = Vector3.ZERO
var _body_rest_y: float = 0.0


func _ready() -> void:
	add_to_group(&"enemy")
	_home = global_position
	_rng.randomize()

	if body != null:
		body.scale = Vector3.ONE * visual_scale
		_body_rest_y = body.position.y
		_wear_skin()
		if settle_on_ground:
			_settle_on_ground()
		_start_animation()

	_fidget_in = _rng.randf_range(2.0, maxf(fidget_interval, 2.0))
	_pick_target()
	# Only the host walks it. `_process` stays on everywhere: that is what
	# animates the body from the replicated position and velocity.
	set_physics_process(_decides())


## True when this peer is the one that decides things. Offline that is everyone,
## which is what keeps a solo game a single code path.
func _decides() -> bool:
	var net := get_node_or_null("/root/Net")
	return net == null or bool(net.call("is_host"))


## Puts the chosen colourway on. The material name says which creature this is —
## `MI_Imp` wants `T_Imp_BaseColor_2.png` — so nothing has to be wired per scene,
## and a skin the kit does not have leaves the model as it came.
##
## One material per skin per creature *type*, shared: two imps in the same
## colourway are two draws of one material, not two materials.
static var _skins: Dictionary = {}

func _wear_skin() -> void:
	if skin <= 1:
		return
	for node in body.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.mesh == null:
			continue
		for s in mesh.mesh.get_surface_count():
			var source := mesh.mesh.surface_get_material(s) as BaseMaterial3D
			# Only the kit's own materials have colourways (not a sword added to it).
			if source == null or not source.resource_name.begins_with("MI_"):
				continue
			var material := _skin_for(source, source.resource_name.trim_prefix("MI_"))
			if material != null:
				mesh.set_surface_override_material(s, material)


func _skin_for(source: BaseMaterial3D, stem: String) -> BaseMaterial3D:
	var key := "%s/%d" % [stem, skin]
	if _skins.has(key):
		return _skins[key]

	var base := skin_dir if not skin_dir.is_empty() else _guess_skin_dir()
	var path := base.path_join("T_%s_BaseColor_%d.png" % [stem, skin])
	var made: BaseMaterial3D = null
	if ResourceLoader.exists(path):
		made = source.duplicate() as BaseMaterial3D
		made.resource_name = "%s_%d" % [stem, skin]
		made.albedo_texture = load(path) as Texture2D
	else:
		push_warning("Monster '%s': no skin %d at %s." % [name, skin, path])
	_skins[key] = made
	return made


## `.../Exports/GLB (Godot-Unreal)/Imp.glb` -> `.../Textures`, which is where the
## kit keeps the colourways its exports do not carry.
func _guess_skin_dir() -> String:
	for child in body.get_children():
		var node := child as Node3D
		if node != null and not node.scene_file_path.is_empty():
			return node.scene_file_path.get_base_dir() \
					.get_base_dir().get_base_dir().path_join("Textures")
	return ""


func _start_animation() -> void:
	_skeleton = body.find_child("Skeleton3D", true, false) as Skeleton3D
	if _skeleton == null:
		push_warning("Monster '%s': no skeleton, it will slide instead of walk." % name)
		return
	_anim = SkeletonAnim.new()
	_anim.name = "Anim"
	add_child(_anim)
	_anim.hips_name = hips_bone
	_anim.feet = foot_bones
	if not _anim.setup(_skeleton, clip_source):
		_anim.queue_free()
		_anim = null
		return
	_anim.set_loops(Array(loop_clips))

	_cycle = maxf(_anim.clip_length(walk_clip), 0.01)
	# A cycle that covers no ground would divide by nothing later; fall back to
	# something plausible for a creature of this size rather than to zero.
	_stride = maxf(_anim.measure_stride(walk_clip), 0.3)
	_anim.play(idle_clip, 0.0)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta

	if _wait > 0.0:
		_wait -= delta
		velocity.x = move_toward(velocity.x, 0.0, acceleration * delta)
		velocity.z = move_toward(velocity.z, 0.0, acceleration * delta)
	else:
		var to_target := _target - global_position
		to_target.y = 0.0
		if to_target.length() < 1.0:
			_wait = rest_time + _rng.randf_range(-rest_spread, rest_spread) * 0.5
			_pick_target()
		else:
			var direction := to_target.normalized()
			rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z),
					1.0 - exp(-turn_speed * delta))
			# Walk where it is looking rather than where it is aiming: moving and
			# turning at once otherwise reads as skidding sideways.
			var facing := -global_transform.basis.z
			facing.y = 0.0
			var alignment := clampf(facing.normalized().dot(direction), 0.0, 1.0)
			velocity.x = move_toward(velocity.x, direction.x * speed * alignment, acceleration * delta)
			velocity.z = move_toward(velocity.z, direction.z * speed * alignment, acceleration * delta)

	StepUp.climb(self, delta, step_height, step_probe)
	move_and_slide()


func _process(delta: float) -> void:
	if _anim == null:
		return

	var planar := Vector3(velocity.x, 0.0, velocity.z).length()
	if planar > 0.12:
		_fidget_in = maxf(_fidget_in, 1.0)
		# One cycle carries the body `_stride` metres, so the rate that keeps the
		# feet planted is however many cycles a second the ground demands.
		var wanted := planar * _cycle / _stride
		_anim.play(walk_clip, 0.25, clampf(wanted, retime_range.x, retime_range.y))
	else:
		_fidget_in -= delta
		if fidget_interval > 0.0 and _fidget_in <= 0.0 and _anim.has_clip(fidget_clip):
			_anim.play(fidget_clip, 0.3, 1.0)
			_fidget_in = fidget_interval + _rng.randf_range(-2.0, 4.0)
		# Back to the idle once the scratch has played out: a one-shot now holds
		# its last frame rather than starting over.
		elif _anim.current_clip() != fidget_clip or not _anim.has_clip(fidget_clip) \
				or _anim.clip_progress() >= 1.0:
			_anim.play(idle_clip, 0.3, 1.0)

	_anim.advance(delta * HitFeel.pace(self))


## Drops the model so its feet rest on the ground rather than sinking into it.
func _settle_on_ground() -> void:
	var lowest := INF
	for m in body.find_children("*", "MeshInstance3D", true, false):
		var mesh := m as MeshInstance3D
		var in_body := body.global_transform.affine_inverse() * mesh.global_transform
		lowest = minf(lowest, (in_body * mesh.get_aabb()).position.y)
	if not is_inf(lowest):
		_body_rest_y -= lowest
		body.position.y = _body_rest_y


## Walks a beat: out to one end, turn, back to the other.
func _pick_target() -> void:
	if _beat == Vector3.ZERO:
		var angle := _rng.randf() * TAU
		_beat = Vector3(cos(angle), 0.0, sin(angle)) * roam_radius
		_target = _home + _beat
	else:
		# Nudged a little each time, so the creature does not wear a groove.
		var drift := Vector3(_rng.randf_range(-1.2, 1.2), 0.0, _rng.randf_range(-1.2, 1.2))
		_target = (_home + _beat + drift) if _target.distance_to(_home + _beat) > roam_radius * 0.5 \
				else (_home - _beat + drift)
