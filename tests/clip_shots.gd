extends SceneTree

## Renders Tariel playing clips from the animation library, so the retarget can
## be eyeballed rather than trusted.
##
## The first shot is the library's own A_TPose: it is the pose the correction is
## solved against, so if the arms do not come out level and the legs straight,
## the mapping is wrong and nothing after it is worth looking at.
##
##   godot --headless --script res://tests/clip_shots.gd -- /abs/output/dir [clip ...]

const WORLD := "res://scenes/world/greybox_world.tscn"

## Clips worth a look by default: the check pose, then one of each thing the
## controller drives.
const DEFAULT_CLIPS: Array[StringName] = [
	&"A_TPose",
	&"Sword_Regular_A",
	&"Sword_Regular_B",
	&"Sword_Regular_C",
	&"NinjaJump_Start",
	&"NinjaJump_Idle",
	&"NinjaJump_Land",
	&"Slide_Start",
	&"Slide",
	&"ClimbUp_1m",
	&"Hit_Knockback",
	&"Idle_Shield",
	&"Walk_Carry",
	&"Sword_Block",
]

## Fractions of each clip to catch, so a swing is seen winding up, connecting
## and recovering rather than at one arbitrary instant.
const SAMPLES := [0.25, 0.55, 0.85]

## The calibration pose is shot from square on as well, because a shoulder or a
## hip that is out by a few degrees does not show from three-quarters.
const CHECK_CLIP := &"A_TPose"
const CHECK_ANGLES := {
	"front": Vector3(0.0, 0.4, -3.6),
	"side": Vector3(3.6, 0.4, 0.0),
	"quarter": Vector3(2.6, 0.6, -3.2),
}

var _player: Player
var _camera: Camera3D
var _dir := "res://"


func _initialize() -> void:
	var argv := OS.get_cmdline_user_args()
	if argv.size() > 0:
		_dir = argv[0]
	var clips: Array[StringName] = DEFAULT_CLIPS
	if argv.size() > 1:
		clips = []
		for i in range(1, argv.size()):
			clips.append(StringName(argv[i]))

	var world: Node3D = load(WORLD).instantiate()
	root.add_child(world)
	_player = (world as World).player()

	_camera = Camera3D.new()
	_camera.fov = 40.0
	world.add_child(_camera)

	await process_frame
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_player.global_position = Vector3(6.0, 0.2, 0.0)
	_player.velocity = Vector3.ZERO
	for i in 30:
		await physics_frame

	if not _player.rig.has_clips():
		printerr("the animation library did not load; nothing to shoot")
		quit(1)
		return
	print("clips available: ", _player.rig.clip_names().size())

	for clip in clips:
		await _shoot_clip(clip)

	print("done")
	quit()


## Catches one clip at each sample point.
##
## The clip is frozen on the wanted frame rather than played and caught on the
## way past: rendering a shot costs frames of its own, which on a half-second
## sword swing is enough to miss the moment entirely — or to arrive after the
## clip has ended and photograph the idle pose instead.
func _shoot_clip(clip: StringName) -> void:
	for i in SAMPLES.size():
		if not _player.rig.hold_clip(clip, SAMPLES[i]):
			printerr("no clip named ", clip)
			return
		if clip == CHECK_CLIP:
			for angle: String in CHECK_ANGLES:
				await _shot("%s_%d_%s" % [clip, i, angle], CHECK_ANGLES[angle])
		else:
			await _shot("%s_%d" % [clip, i])


func _shot(name: String, offset := Vector3(2.6, 0.6, -3.2)) -> void:
	var focus := _player.global_position + Vector3.UP * 1.0
	_camera.global_position = focus + offset
	_camera.look_at(focus, Vector3.UP)
	_camera.current = true

	for i in 2:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var path := "%s/%s.png" % [_dir, name]
	image.save_png(path)
	print("saved ", path)
