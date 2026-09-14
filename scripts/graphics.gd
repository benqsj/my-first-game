class_name Graphics
extends Object

## The two graphics settings, and what each one actually does.
##
## One knob, because a greybox does not need twelve. **High** is the game as it
## was tuned; **Low** is the same game with everything that costs a lot and
## shows little turned off — and, where that is not enough, drawn smaller and
## sharpened back up, which is the honest way to buy frames on a machine that
## does not have them.
##
## Everything here is applied to whatever scene is loaded at the time, so it can
## be changed from a menu before a level exists and again from inside one.

enum Level {
	LOW, ## Shadows off, half the pixels, blurred textures. For weak hardware.
	HIGH, ## As designed.
}


## Applies `level` to the viewport and to whatever is in the tree right now.
static func apply(tree: SceneTree, level: Level) -> void:
	if tree == null:
		return
	var low := level == Level.LOW
	_apply_viewport(tree.root, low)

	var scene := tree.current_scene
	if scene == null:
		return
	_apply_lights(scene, low)
	_apply_environment(scene, low)
	_apply_grass(scene, low)


## The viewport itself: how many pixels are drawn and how they are filtered.
##
## `scaling_3d_scale` is the big one — rendering at 70% is roughly half the
## pixels — and the mipmap bias is what the setting means by *worse textures*:
## a positive bias picks a smaller mip than the distance calls for, so surfaces
## go soft and the texture cache stops being the thing that stalls.
static func _apply_viewport(window: Window, low: bool) -> void:
	window.msaa_3d = Viewport.MSAA_DISABLED if low else Viewport.MSAA_2X
	window.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	window.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	window.scaling_3d_scale = 0.7 if low else 1.0
	window.texture_mipmap_bias = 1.0 if low else 0.0
	window.use_debanding = not low


## Shadows are the single most expensive thing in the scene and the first to go.
static func _apply_lights(scene: Node, low: bool) -> void:
	for node in scene.find_children("*", "Light3D", true, false):
		var light := node as Light3D
		light.shadow_enabled = not low
		if light is DirectionalLight3D and not low:
			(light as DirectionalLight3D).directional_shadow_max_distance = 140.0


## Screen-space effects: worth having, never worth a frame on a machine that is
## already short of them.
static func _apply_environment(scene: Node, low: bool) -> void:
	for node in scene.find_children("*", "WorldEnvironment", true, false):
		var env := (node as WorldEnvironment).environment
		if env == null:
			continue
		env.ssao_enabled = not low
		env.ssil_enabled = false
		env.glow_enabled = not low
		env.fog_enabled = not low


## The grass is most of the cost of the world, and it already has the three
## knobs that matter. This just turns them.
static func _apply_grass(scene: Node, low: bool) -> void:
	for node in scene.find_children("*", "Node3D", true, false):
		var field := node as GrassField
		if field == null:
			continue
		field.casts_shadows = false
		field.lod_bias = 0.02 if low else 0.06
		field.draw_distance = 60.0 if low else 130.0
		# The field reads these once as it is built, so they have to be pushed
		# back down when they change afterwards.
		field.refresh_meshes()
