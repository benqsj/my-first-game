class_name Graphics
extends Object

## The graphics settings, and what each one actually does.
##
## Three positions on one knob. **High** is the game as it was tuned; **Low** is
## the same game with everything that costs a lot and shows little turned off —
## and, where that is not enough, drawn smaller and sharpened back up, which is
## the honest way to buy frames on a machine that does not have them.
## **Medium** sits between: the sun still casts, but over a shorter reach and in
## one cascade, and the picture is drawn at 85% and brought up with FSR.
##
## Measured on an M1 over six places on the map, a frame costs about 11–16 ms
## on High, 8–11 on Medium and 4–8 on Low; `tests/perf_tour.gd` takes those
## readings, and README's "Performance, September 2026" has them.
##
## Everything here is applied to whatever scene is loaded at the time, so it can
## be changed from a menu before a level exists and again from inside one.

## The values are what `Game` writes to `user://settings.cfg`, so a new setting
## goes on the end rather than in the order it is shown; `ORDER` is that.
enum Level {
	LOW, ## Shadows off, half the pixels, blurred textures. For weak hardware.
	HIGH, ## As designed.
	MEDIUM, ## One short shadow cascade, 85% of the pixels, FSR.
}

## How the settings are offered, cheapest first.
const ORDER: Array[Level] = [Level.LOW, Level.MEDIUM, Level.HIGH]

## Per setting, how far out small things are still drawn, as a share of what the
## level asked for (the wood's plants and the meadows' flowers, which carry their
## own ranges) or in metres (the loose stones and the people, which do not).
const DETAIL_SCALE := {Level.LOW: 0.6, Level.MEDIUM: 0.8, Level.HIGH: 1.0}
const STONE_RANGE := {Level.LOW: 55.0, Level.MEDIUM: 80.0, Level.HIGH: 110.0}
const PEOPLE_RANGE := {Level.LOW: 45.0, Level.MEDIUM: 60.0, Level.HIGH: 80.0}
## How far anything that stands in the lands is drawn at all, per setting, in
## metres: the trees, the lands' places, the city. Past it the fog has the
## world (Looks thickened it to that end), and the ground, the water and the
## far mountains, which cost little, go on to the horizon. Before this the
## city and the villages were drawn right across the map: from the spawn,
## ~6 000 draw calls a frame.
const REACH := {Level.LOW: 130.0, Level.MEDIUM: 180.0, Level.HIGH: 240.0}
## The most pixels the 3D picture is drawn with, per setting. A window is under
## it; the full screen of a Retina Mac is 7 million pixels, five times the
## 1600×900 window every figure in README was measured in, and is drawn
## smaller and brought up with FSR rather than at five times the cost.
const PIXEL_BUDGET := {Level.LOW: 1.0e6, Level.MEDIUM: 1.6e6, Level.HIGH: 2.4e6}
## The sun's shadow filter per setting (the project's own is SOFT_MEDIUM): one
## step softer on High and two on Medium, ~1.5 ms over the wood and the hamlet
## for an edge that is hard to tell apart in play.
const SHADOW_FILTER := {
	Level.LOW: RenderingServer.SHADOW_QUALITY_HARD,
	Level.MEDIUM: RenderingServer.SHADOW_QUALITY_SOFT_VERY_LOW,
	Level.HIGH: RenderingServer.SHADOW_QUALITY_SOFT_LOW,
}


## The name a menu shows for `level`.
static func label(level: Level) -> String:
	match level:
		Level.LOW:
			return "LOW"
		Level.MEDIUM:
			return "MEDIUM"
	return "HIGH"


## Anything read back from a settings file, made into a setting that exists.
static func from_int(value: int) -> Level:
	return value as Level if value in Level.values() else Level.HIGH


## The setting last applied, for whatever reads it later ([Looks] grades Low
## apart from Medium and High).
static var current: Level = Level.HIGH
static var _watching := false


## Applies `level` to the viewport and to whatever is in the tree right now.
static func apply(tree: SceneTree, level: Level) -> void:
	if tree == null:
		return
	current = level
	_apply_viewport(tree.root, level)
	# The pixel budget depends on the window's size: a new size (full screen,
	# F11, the display setting) is a new scale.
	if not _watching:
		_watching = true
		var window := tree.root
		window.size_changed.connect(func() -> void: _apply_viewport(window, current))

	var scene := tree.current_scene
	if scene == null:
		return
	_apply_lights(scene, level)
	_apply_environment(scene, level)
	_apply_grass(scene, level)
	_apply_detail(scene, level)
	for looks in scene.find_children("*", "Looks", true, false):
		(looks as Looks).regrade()


## The viewport itself: how many pixels are drawn and how they are filtered.
##
## `scaling_3d_scale` is the big one — rendering at 70% is roughly half the
## pixels — and FSR is what brings a smaller picture back up to the window
## without it going soft. The mipmap bias is what Low means by *worse
## textures*: a positive bias picks a smaller mip than the distance calls for,
## so surfaces go soft and the texture cache stops being the thing that stalls.
static func _apply_viewport(window: Window, level: Level) -> void:
	var scale := 1.0
	match level:
		Level.LOW:
			scale = 0.7
		Level.MEDIUM:
			scale = 0.85
	var pixels := float(window.size.x) * float(window.size.y)
	if pixels > 0.0:
		scale = minf(scale, sqrt(float(PIXEL_BUDGET[level]) / pixels))
	# Edges: SMAA on High, FXAA on Medium (ahead of FSR, which wants a clean
	# picture to scale), nothing on Low. High used to be 2x MSAA, which cost
	# 3.5–4 ms a frame on an M1 over the wood and the pier — most of the gap to
	# 60 fps — for edges SMAA gets nearly as clean for a fraction of a ms.
	window.msaa_3d = Viewport.MSAA_DISABLED
	match level:
		Level.HIGH:
			window.screen_space_aa = Viewport.SCREEN_SPACE_AA_SMAA
		Level.MEDIUM:
			window.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
		_:
			window.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	window.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if scale < 0.999 else Viewport.SCALING_3D_MODE_BILINEAR
	window.scaling_3d_scale = scale
	window.fsr_sharpness = 0.2
	window.texture_mipmap_bias = 1.0 if level == Level.LOW else 0.0
	window.use_debanding = level != Level.LOW


## Shadows are the single most expensive thing in the scene and the first to
## go. Medium keeps the sun's shadow but in one cascade over a shorter reach:
## the shadow pass redraws every caster in reach once per cascade, so that is
## most of its cost gone for shadows that are still there at your feet.
static func _apply_lights(scene: Node, level: Level) -> void:
	RenderingServer.directional_soft_shadow_filter_set_quality(SHADOW_FILTER[level])
	RenderingServer.positional_soft_shadow_filter_set_quality(SHADOW_FILTER[level])
	# Medium's one cascade has the whole shadow map to itself, so a 2048 map
	# gives it what each of High's two cascades gets out of 4096, for a
	# quarter of the pixels to fill (~0.5 ms over the wood and the orc camp).
	RenderingServer.directional_shadow_atlas_set_size(2048 if level == Level.MEDIUM else 4096, true)
	for node in scene.find_children("*", "Light3D", true, false):
		var light := node as Light3D
		light.shadow_enabled = level != Level.LOW
		var sun := light as DirectionalLight3D
		if sun == null:
			continue
		# What the level set, kept so High can put it back.
		if not sun.has_meta(&"designed_mode"):
			sun.set_meta(&"designed_mode", sun.directional_shadow_mode)
			sun.set_meta(&"designed_reach", sun.directional_shadow_max_distance)
		if level == Level.MEDIUM:
			sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
			sun.directional_shadow_max_distance = 55.0
		else:
			sun.directional_shadow_mode = sun.get_meta(&"designed_mode") as DirectionalLight3D.ShadowMode
			sun.directional_shadow_max_distance = float(sun.get_meta(&"designed_reach"))


## Screen-space effects: worth having, never worth a frame on a machine that is
## already short of them. Ambient occlusion is the dear one and only High has
## it; glow and fog are cheap and most of the look, so Medium keeps them.
static func _apply_environment(scene: Node, level: Level) -> void:
	for node in scene.find_children("*", "WorldEnvironment", true, false):
		var env := (node as WorldEnvironment).environment
		if env == null:
			continue
		env.ssao_enabled = level == Level.HIGH
		env.ssil_enabled = false
		env.glow_enabled = level != Level.LOW
		# On every setting now: past the setting's reach nothing is drawn, and
		# the fog is what keeps that edge from being seen.
		env.fog_enabled = true


## The grass is most of the cost of the world, and it already has the three
## knobs that matter. This just turns them.
static func _apply_grass(scene: Node, level: Level) -> void:
	for node in scene.find_children("*", "Node3D", true, false):
		var field := node as GrassField
		if field == null:
			continue
		field.casts_shadows = false
		match level:
			Level.LOW:
				field.lod_bias = 0.02
				field.draw_distance = 60.0
			Level.MEDIUM:
				field.lod_bias = 0.04
				field.draw_distance = 95.0
			_:
				field.lod_bias = 0.06
				field.draw_distance = 130.0
		# The field reads these once as it is built, so they have to be pushed
		# back down when they change afterwards.
		field.refresh_meshes()


## How far out the small things are drawn.
##
## The wood's plants and the meadows' flowers already stop at a distance the
## level chose; that distance is scaled. The loose stones in the scatter and the
## people standing about had no distance at all and were drawn — and, the
## stones, shadowed — right across the map; they get one here. No fade: a fade
## draws the thing see-through for a while, which costs more than drawing it.
static func _apply_detail(scene: Node, level: Level) -> void:
	var scale: float = DETAIL_SCALE[level]
	var reach: float = REACH[level]
	for holder_path in ["Forest", "Meadows", "LandsPlaces"]:
		var holder := scene.get_node_or_null(holder_path)
		if holder == null:
			continue
		# The lands' places carry a reach on everything ([StaticBatch]); 0 is
		# "as far as anything", which is the setting's reach. The wood's
		# and the meadows' 0 is "always", the ground cover that is under you.
		var places: bool = holder_path == "LandsPlaces"
		for node in holder.find_children("*", "GeometryInstance3D", true, false):
			var geo := node as GeometryInstance3D
			if not geo.has_meta(&"designed_range"):
				if places:
					continue
				geo.set_meta(&"designed_range", geo.visibility_range_end)
			var designed := float(geo.get_meta(&"designed_range"))
			if designed > 0.0:
				geo.visibility_range_end = minf(designed * scale, reach)
			elif places:
				geo.visibility_range_end = reach
			else:
				continue
			if places:
				# the big ones fade into the fog rather than go at once
				geo.visibility_range_end_margin = geo.visibility_range_end * 0.12
				geo.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF \
						if geo.visibility_range_end >= reach * 0.99 \
						else GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED

	var scatter := scene.get_node_or_null("Level/Scatter")
	if scatter != null:
		for child in scatter.get_children():
			# The grass is the field's own chunks, handled above.
			if child is MultiMeshInstance3D or not child is Node3D:
				continue
			_range(child, STONE_RANGE[level])
	var people := scene.get_node_or_null("People")
	if people != null:
		_range(people, PEOPLE_RANGE[level])


static func _range(under: Node, reach: float) -> void:
	var nodes := under.find_children("*", "GeometryInstance3D", true, false)
	if under is GeometryInstance3D:
		nodes.append(under)
	for node in nodes:
		var geo := node as GeometryInstance3D
		geo.visibility_range_end = reach
		geo.visibility_range_end_margin = reach * 0.1
		geo.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
