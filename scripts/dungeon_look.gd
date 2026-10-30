class_name DungeonLook
extends RefCounted

## A place's look: its light, air and sky ([method place_look] and the looks
## of each kind), the run's day going to night ([method _to_phase]), and the
## materials the places share. Taken out of dungeon.gd (2026-10-28); every
## function takes the dungeon as `dun`. [Dungeon] keeps a one-line function
## of the same name for each one called from outside this file.

static func _photo_tex(dun: Dungeon, key: String) -> Texture2D:
	if not dun._photo.has(key):
		var path: String = Dungeon.PHOTO[key]
		dun._photo[key] = load(path) as Texture2D if ResourceLoader.exists(path) else null
	return dun._photo[key]


## The forest's and the swamp's ground, the land's photographed one in it.
static func _ground_mat(dun: Dungeon) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = dun._ground_shader
	m.set_shader_parameter("photo", 1.0)
	m.set_shader_parameter("t_grass", DungeonLook._photo_tex(dun, "grass"))
	m.set_shader_parameter("n_grass", DungeonLook._photo_tex(dun, "grass_nor"))
	m.set_shader_parameter("t_earth", DungeonLook._photo_tex(dun, "earth"))
	m.set_shader_parameter("n_earth", DungeonLook._photo_tex(dun, "earth_nor"))
	m.set_shader_parameter("t_leaves", DungeonLook._photo_tex(dun, "leaves"))
	m.set_shader_parameter("t_mud", DungeonLook._photo_tex(dun, "mud"))
	m.set_shader_parameter("n_mud", DungeonLook._photo_tex(dun, "mud_nor"))
	return m


static func _materials(dun: Dungeon) -> void:
	dun._floor_shader = Shader.new()
	dun._floor_shader.code = Dungeon.FLOOR_SHADER
	dun._glass_shader = Shader.new()
	dun._glass_shader.code = Dungeon.GLASS_SHADER
	dun._beam_shader = Shader.new()
	dun._beam_shader.code = Dungeon.BEAM_SHADER
	var rock := Shader.new()
	rock.code = Dungeon.ROCK_SHADER
	dun._rock_mat = ShaderMaterial.new()
	dun._rock_mat.shader = rock
	dun._rock_mat.set_shader_parameter("scale", 0.08)
	dun._rock_mat.set_shader_parameter("rock_a", Color(0.48, 0.44, 0.40))
	dun._rock_mat.set_shader_parameter("rock_b", Color(0.30, 0.28, 0.27))
	dun._rock_mat.set_shader_parameter("band", Color(0.58, 0.48, 0.38))
	dun._rock_mat.set_shader_parameter("wet", 0.0)
	dun._rock_mat.set_shader_parameter("moss_amount", 0.6)
	dun._rock_mat.set_shader_parameter("photo", 1.0)
	dun._rock_mat.set_shader_parameter("photo_tex", DungeonLook._photo_tex(dun, "rock"))
	dun._cave_mat = ShaderMaterial.new()
	dun._cave_mat.shader = rock
	dun._cave_mat.set_shader_parameter("scale", 0.3)
	# under the earth as the Eternal Cities lie (the user's word, 2026-10-20:
	# Elden Ring's colours): blue-grey rock, flecked with points of starlight
	# (2026-10-23: the land's grey rock now, only a cold cast left)
	dun._cave_mat.set_shader_parameter("rock_a", Color(0.40, 0.40, 0.42))
	dun._cave_mat.set_shader_parameter("rock_b", Color(0.17, 0.17, 0.19))
	dun._cave_mat.set_shader_parameter("band", Color(0.46, 0.45, 0.47))
	dun._cave_mat.set_shader_parameter("moss", Color(0.08, 0.22, 0.26))
	dun._cave_mat.set_shader_parameter("fleck", Color(0.75, 0.88, 1.0))
	dun._cave_mat.set_shader_parameter("fleck_glow", 3.0)
	dun._cave_mat.set_shader_parameter("wet", 0.6)
	dun._cave_mat.set_shader_parameter("moss_amount", 0.35)
	dun._cave_mat.set_shader_parameter("photo", 0.8)
	dun._cave_mat.set_shader_parameter("photo_tex", DungeonLook._photo_tex(dun, "rock"))
	dun._ground_shader = Shader.new()
	dun._ground_shader.code = Dungeon.GROUND_SHADER
	dun._wall_mat = ShaderMaterial.new()
	var ws := Shader.new()
	ws.code = Dungeon.WALL_SHADER
	dun._wall_mat.shader = ws
	dun._wall_mat.set_shader_parameter("photo", 1.0)
	dun._wall_mat.set_shader_parameter("stone_tex", DungeonLook._photo_tex(dun, "rock"))
	dun._wall_mat.set_shader_parameter("stone_nor", DungeonLook._photo_tex(dun, "rock_nor"))
	# the dressed stone's colour the village's grey-brown, not the old beige;
	# the land's rock in its face
	dun._trim_mat = StandardMaterial3D.new()
	dun._trim_mat.albedo_color = Color(0.56, 0.53, 0.48)
	dun._trim_mat.roughness = 0.8
	dun._trim_mat.normal_enabled = true
	dun._trim_mat.normal_texture = DungeonLook._photo_tex(dun, "rock_nor")
	dun._trim_mat.normal_scale = 0.7
	dun._trim_mat.uv1_triplanar = true
	dun._trim_mat.uv1_world_triplanar = true
	dun._trim_mat.uv1_scale = Vector3(0.4, 0.4, 0.4)
	dun._iron_mat = StandardMaterial3D.new()
	dun._iron_mat.albedo_color = Color(0.09, 0.085, 0.08)
	dun._iron_mat.metallic = 0.85
	dun._iron_mat.roughness = 0.45
	dun._cloth_mat = StandardMaterial3D.new()
	dun._cloth_mat.albedo_color = Color(0.26, 0.07, 0.34)
	dun._cloth_mat.roughness = 0.95
	dun._gold_mat = StandardMaterial3D.new()
	dun._gold_mat.albedo_color = Color(0.78, 0.58, 0.22)
	dun._gold_mat.metallic = 0.9
	dun._gold_mat.roughness = 0.35
	dun._wood_mat = StandardMaterial3D.new()
	dun._wood_mat.albedo_color = Color(0.17, 0.11, 0.07)
	dun._wood_mat.roughness = 0.9


## Room `i`'s floor: big slabs in the halls, smaller flags under the sky,
## cobbles along the walls (and up the throne room's aisle), its wear.
static func _floor_mat(dun: Dungeon, i: int) -> ShaderMaterial:
	var r := dun._room(i)
	var kind: String = r["kind"]
	var m := ShaderMaterial.new()
	m.shader = dun._floor_shader
	m.set_shader_parameter("photo", 1.0)
	m.set_shader_parameter("cob_tex", DungeonLook._photo_tex(dun, "cob"))
	m.set_shader_parameter("cob_nor", DungeonLook._photo_tex(dun, "cob_nor"))
	m.set_shader_parameter("stone_tex", DungeonLook._photo_tex(dun, "rock"))
	m.set_shader_parameter("stone_nor", DungeonLook._photo_tex(dun, "rock_nor"))
	var c := dun.centre(i)
	m.set_shader_parameter("centre", Vector2(c.x, c.z))
	m.set_shader_parameter("half_size", Vector2(float(r["w"]) * 0.5, float(r["l"]) * 0.5))
	if kind == "cave":
		m.set_shader_parameter("rocky", 1.0)
		m.set_shader_parameter("pebble", 0.9)
		m.set_shader_parameter("relief", 0.09)
		m.set_shader_parameter("cobble_a", Color(0.38, 0.38, 0.40))
		m.set_shader_parameter("cobble_b", Color(0.17, 0.17, 0.19))
		m.set_shader_parameter("wet", 0.8)
		m.set_shader_parameter("border", 0.0)
		return m
	if kind == "crypt":
		m.set_shader_parameter("slab", 2.0)
		m.set_shader_parameter("course", 1.4)
		m.set_shader_parameter("slab_a", Color(0.40, 0.39, 0.36))
		m.set_shader_parameter("slab_b", Color(0.26, 0.26, 0.25))
		m.set_shader_parameter("cobble_a", Color(0.34, 0.33, 0.31))
		m.set_shader_parameter("cobble_b", Color(0.16, 0.16, 0.16))
		m.set_shader_parameter("wear", 0.75)
		m.set_shader_parameter("border", 2.0)
		m.set_shader_parameter("aisle", 2.2)
		m.set_shader_parameter("wet", 0.4)
		return m
	if kind == "mountain":
		m.set_shader_parameter("rocky", 1.0)
		m.set_shader_parameter("pebble", 1.3)
		m.set_shader_parameter("relief", 0.1)
		m.set_shader_parameter("cobble_a", Color(0.44, 0.44, 0.46))
		m.set_shader_parameter("cobble_b", Color(0.24, 0.24, 0.27))
		m.set_shader_parameter("wet", 1.0)
		m.set_shader_parameter("snow", 1.0)
		m.set_shader_parameter("border", 0.0)
		return m
	if kind in ["court", "terrace", "sky", "rampart", "spring", "altar"]:
		m.set_shader_parameter("all_cob", 1.0)
	if kind == "prison":
		# big dark flags, cold, worn (the user's word, 2026-10-23: another floor)
		m.set_shader_parameter("slab", 1.9)
		m.set_shader_parameter("course", 1.3)
		m.set_shader_parameter("slab_a", Color(0.36, 0.36, 0.37))
		m.set_shader_parameter("slab_b", Color(0.25, 0.25, 0.27))
		m.set_shader_parameter("cobble_a", Color(0.34, 0.33, 0.33))
		m.set_shader_parameter("cobble_b", Color(0.18, 0.18, 0.19))
		m.set_shader_parameter("border", 1.2)
		m.set_shader_parameter("wear", 0.5)
		# Ashen's look (the user's word, 2026-10-25): even, quiet stone that
		# takes the soft light, little grain, no moss
		m.set_shader_parameter("photo", 0.35)
		m.set_shader_parameter("relief", 0.03)
		m.set_shader_parameter("moss_amt", 0.0)
		m.set_shader_parameter("slab_a", Color(0.47, 0.46, 0.45))
		m.set_shader_parameter("slab_b", Color(0.38, 0.37, 0.37))
		m.set_shader_parameter("cobble_a", Color(0.46, 0.45, 0.44))
		m.set_shader_parameter("cobble_b", Color(0.40, 0.39, 0.39))
		m.set_shader_parameter("grit", Color(0.24, 0.24, 0.25))
		return m
	if kind == "rampart":
		m.set_shader_parameter("slab", 1.6)
		m.set_shader_parameter("course", 1.1)
		m.set_shader_parameter("slab_a", Color(0.50, 0.49, 0.47))
		m.set_shader_parameter("slab_b", Color(0.34, 0.34, 0.34))
		m.set_shader_parameter("wear", 0.7)
		m.set_shader_parameter("border", 1.0)
		m.set_shader_parameter("wet", 0.5)
		return m
	if kind == "sky":
		m.set_shader_parameter("slab", 2.0)
		m.set_shader_parameter("course", 1.4)
		m.set_shader_parameter("slab_a", Color(0.56, 0.52, 0.48))
		m.set_shader_parameter("slab_b", Color(0.40, 0.38, 0.36))
		m.set_shader_parameter("wear", 0.4)
		m.set_shader_parameter("border", 2.0)
		return m
	if kind == "hall":
		m.set_shader_parameter("slab", 2.6)
		m.set_shader_parameter("course", 1.7)
		m.set_shader_parameter("slab_a", Color(0.50, 0.45, 0.38))
		m.set_shader_parameter("slab_b", Color(0.36, 0.32, 0.27))
		m.set_shader_parameter("wear", 0.45 if not r.has("hole") else 0.75)
		m.set_shader_parameter("border", 2.2)
		m.set_shader_parameter("aisle", 2.6)
	else:
		m.set_shader_parameter("slab", 1.8)
		m.set_shader_parameter("course", 1.25)
		m.set_shader_parameter("slab_a", Color(0.49, 0.44, 0.38))
		m.set_shader_parameter("slab_b", Color(0.35, 0.31, 0.27))
		m.set_shader_parameter("border", 3.2)
		m.set_shader_parameter("wear", 0.65)
		m.set_shader_parameter("wet", 1.0 if kind != "throne" else 0.6)
		if kind == "throne":
			m.set_shader_parameter("aisle", 3.0)
	return m


## The sky (a shader of its own: clouds, stars, the moon), the light and the
## haze, set to the first room's afternoon.
static func _sky(dun: Dungeon) -> void:
	var root: Node = dun.owner if dun.owner != null else dun.get_parent()
	var env_node := root.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if env_node == null or env_node.environment == null:
		return
	dun._env = env_node.environment
	var shader := Shader.new()
	shader.code = Dungeon.SKY_SHADER
	dun._sky_mat = ShaderMaterial.new()
	dun._sky_mat.shader = shader
	var sky := Sky.new()
	sky.sky_material = dun._sky_mat
	sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	dun._env.background_mode = Environment.BG_SKY
	dun._env.sky = sky
	dun._env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	dun._env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	dun._env.fog_density = 0.0007
	dun._env.fog_sky_affect = 0.2
	dun._env.adjustment_enabled = true
	dun._env.adjustment_saturation = 1.06
	dun._env.adjustment_contrast = 1.03
	dun._env.ssao_enabled = true
	dun._env.ssao_intensity = 1.1
	dun._sun = root.get_node_or_null("Sun") as DirectionalLight3D
	if dun._sun != null:
		dun._sun_yaw = dun._sun.rotation.y
		# the land's sun: its shadows as soft, as far
		dun._sun.shadow_opacity = 0.72
		dun._sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
		dun._sun.directional_shadow_split_1 = 0.26
		dun._sun.directional_shadow_blend_splits = true
		dun._sun.directional_shadow_max_distance = 95.0
	DungeonLook._apply_phase(dun, 0.0)


## Over `seconds`, to the light of room `to`.
static func _to_phase(dun: Dungeon, to: float, seconds: float) -> void:
	if dun._phase_tween != null and dun._phase_tween.is_valid():
		dun._phase_tween.kill()
	dun._phase_tween = dun.create_tween()
	dun._phase_tween.tween_method(func(v: float) -> void: DungeonLook._apply_phase(dun, v), dun._phase, to, seconds)


static func _apply_phase(dun: Dungeon, t: float) -> void:
	dun._phase = t
	var i := clampi(int(floorf(t)), 0, Dungeon.PHASES.size() - 1)
	var j := mini(i + 1, Dungeon.PHASES.size() - 1)
	var u := clampf(t - float(i), 0.0, 1.0)
	var a: Dictionary = Dungeon.PHASES[i]
	var b: Dictionary = Dungeon.PHASES[j]
	var top: Color = (a["top"] as Color).lerp(b["top"], u)
	var hor: Color = (a["hor"] as Color).lerp(b["hor"], u)
	var sun_c: Color = (a["sun"] as Color).lerp(b["sun"], u)
	var night := lerpf(float(a["night"]), float(b["night"]), u)
	var elev := lerpf(float(a["elev"]), float(b["elev"]), u)
	var sun_e := lerpf(float(a["sun_e"]), float(b["sun_e"]), u)
	var yaw := dun._sun_yaw
	# Into the night: the sun goes down, then the moon comes up, elsewhere.
	if float(b["night"]) > 0.9 and float(a["night"]) < 0.9:
		if u < 0.5:
			elev = lerpf(float(a["elev"]), -6.0, u * 2.0)
			sun_e = lerpf(float(a["sun_e"]), 0.0, u * 2.0)
			sun_c = a["sun"]
		else:
			elev = float(b["elev"])
			yaw = dun._sun_yaw + PI * 0.7
			sun_e = lerpf(0.0, float(b["sun_e"]), (u - 0.5) * 2.0)
			sun_c = b["sun"]
	elif float(a["night"]) > 0.9:
		yaw = dun._sun_yaw + PI * 0.7
	if dun._sky_mat != null:
		dun._sky_mat.set_shader_parameter("top_col", top)
		dun._sky_mat.set_shader_parameter("hor_col", hor)
		dun._sky_mat.set_shader_parameter("gnd_col", (a["gnd"] as Color).lerp(b["gnd"], u))
		dun._sky_mat.set_shader_parameter("sun_col", sun_c)
		dun._sky_mat.set_shader_parameter("night", night)
		dun._sky_mat.set_shader_parameter("cloud", lerpf(float(a["cloud"]), float(b["cloud"]), u))
	if dun._env != null:
		dun._env.ambient_light_color = (a["amb"] as Color).lerp(b["amb"], u)
		dun._env.ambient_light_energy = lerpf(float(a["amb_e"]), float(b["amb_e"]), u)
		dun._env.fog_light_color = (a["fog"] as Color).lerp(b["fog"], u)
	var lit := hor.lerp(Color(1, 1, 1), 0.5) * lerpf(1.0, 0.3, night)
	for m in dun._cloud_layer_mats:
		m.set_shader_parameter("top", lit.lerp(sun_c, 0.15))
		m.set_shader_parameter("low", lit.darkened(0.35).lerp(top, 0.25))
	if dun._sun != null:
		dun._sun.rotation = Vector3(-deg_to_rad(maxf(elev, -6.0)), yaw, 0.0)
		dun._sun.light_color = sun_c
		dun._sun.light_energy = maxf(sun_e, 0.0)
		dun._sun.visible = sun_e > 0.01
	DungeonLook._place_look(dun, night)


## Each place's own air over the day's (the user's word, 2026-10-20: the
## palace's and the cave's colours as Elden Ring's): the palace's halls in a
## golden haze, the light through them thick enough to see, Leyndell's warm
## pale stone; the cave a deep blue under the earth, its own mist, its
## crystals and flecks bright in it like the underground cities' starlight.
static func _place_look(dun: Dungeon, night: float = 0.0) -> void:
	if dun._env == null or dun.rooms.is_empty() or dun.current < 0 or dun.current >= dun.rooms.size():
		return
	var kind := String(dun._room(dun.current).get("kind", ""))
	# the lands' far mountains: not round the island in the sky, which is
	# all cloud below (the user's word, 2026-10-23)
	var lands := dun.get_node_or_null(^"Vista") as Node3D
	if lands != null:
		lands.visible = not kind in ["sky", "forest", "lake", "fort", "falls", "clouds", "gold_hall", "flood_crypt", "cell_cave", "lord_court", "war_camp", "twin_cave", "holy_spring", "altar", "fog_sea"]
	dun._env.glow_enabled = true
	dun._env.glow_intensity = 0.9
	dun._env.glow_bloom = 0.08
	dun._env.glow_hdr_threshold = 1.0
	dun._env.volumetric_fog_enabled = false
	if dun._sun != null:
		dun._sun.light_volumetric_fog_energy = 1.0
	dun._env.ssr_enabled = false
	dun._env.fog_density = 0.0021
	dun._env.fog_height_density = 0.0
	dun._env.adjustment_contrast = 1.03
	dun._env.adjustment_saturation = 1.06
	dun._env.adjustment_brightness = 1.0
	dun._env.fog_sky_affect = 0.2
	# what the prisoners' room's Ashen look turns ([method _ashen_look]), back
	# to the game's own for every other place
	dun._env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	dun._env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	dun._env.tonemap_exposure = 1.0
	dun._env.tonemap_white = 1.0
	dun._env.adjustment_color_correction = null
	dun._env.fog_sun_scatter = 0.0
	dun._env.fog_aerial_perspective = 0.0
	dun._env.volumetric_fog_anisotropy = 0.2
	dun._env.ssao_radius = 1.0
	dun._env.ssao_intensity = 1.1
	dun._env.ssao_power = 1.5
	dun._env.ssao_detail = 0.5
	dun._env.ssao_light_affect = 0.0
	if dun._sun != null:
		dun._sun.light_angular_distance = 0.0
		dun._sun.shadow_opacity = 0.72
		dun._sun.shadow_blur = 1.0
	match kind:
		"hall", "court", "terrace", "throne":
			# the gold is the day's: by night only the torches' warmth is left
			var day := 1.0 - clampf(night, 0.0, 1.0)
			var gold := Color(0.92, 0.72, 0.42)
			# the land's own air (the user's word, 2026-10-23: inside the
			# portal, the colours of the world he left), no gold haze
			dun._env.fog_light_color = dun._env.fog_light_color.lerp(gold, 0.05 * day)
		"sky":
			# a golden afternoon over the clouds, the colours kept (the
			# user's word, 2026-10-23: everything too white, the colours lost)
			dun._env.fog_density = 0.0009
			dun._env.fog_light_color = dun._env.fog_light_color.lerp(Color(1.0, 0.86, 0.66), 0.35)
			dun._env.adjustment_saturation = 1.18
			dun._env.adjustment_contrast = 1.07
			if dun._sun != null:
				dun._sun.light_color = dun._sun.light_color.lerp(Color(1.0, 0.82, 0.58), 0.5)
				dun._sun.light_energy *= 1.12
		"flood_crypt":
			# the flooded crypt: dark blue-grey stone, the sun down in shafts
			# through the broken vaults, whatever hour it is outside
			dun._env.ambient_light_color = Color(0.34, 0.42, 0.50)
			dun._env.ambient_light_energy = 0.7
			dun._env.fog_light_color = Color(0.20, 0.26, 0.32)
			dun._env.fog_density = 0.003
			dun._env.glow_intensity = 1.2
			dun._env.glow_bloom = 0.14
			dun._env.glow_hdr_threshold = 0.85
			dun._env.volumetric_fog_enabled = true
			dun._env.volumetric_fog_density = 0.004
			dun._env.volumetric_fog_albedo = Color(0.80, 0.86, 0.92)
			dun._env.volumetric_fog_emission = Color(0.0, 0.0, 0.0)
			dun._env.volumetric_fog_ambient_inject = 0.02
			if dun._sun != null:
				dun._sun.visible = true
				dun._sun.light_color = Color(1.0, 0.95, 0.84)
				dun._sun.light_energy = 1.5
				dun._sun.rotation.x = -deg_to_rad(74.0)
				dun._sun.light_volumetric_fog_energy = 4.0
		"crypt":
			# the catacombs: cold grey stone, the candles' warmth in it, but
			# a man still seen as he is (2026-10-23)
			dun._env.ambient_light_color = Color(0.52, 0.56, 0.58)
			dun._env.ambient_light_energy = 1.45
			dun._env.fog_light_color = Color(0.30, 0.32, 0.33)
			dun._env.fog_density = 0.004
			dun._env.glow_intensity = 1.2
			dun._env.glow_bloom = 0.16
			dun._env.glow_hdr_threshold = 0.85
			dun._env.volumetric_fog_enabled = true
			dun._env.volumetric_fog_density = 0.0025
			dun._env.volumetric_fog_albedo = Color(0.75, 0.78, 0.75)
			dun._env.volumetric_fog_emission = Color(0.0, 0.0, 0.0)
			dun._env.volumetric_fog_length = 50.0
			dun._env.volumetric_fog_ambient_inject = 0.1
		"swamp":
			# a dim overcast wood over the mere (the user's word, 2026-10-23:
			# everything too bright, a little darker), the village's colours kept
			dun._env.fog_light_color = dun._env.fog_light_color.lerp(Color(0.46, 0.52, 0.47), 0.55)
			dun._env.ambient_light_color = dun._env.ambient_light_color.lerp(Color(0.44, 0.52, 0.45), 0.45)
			dun._env.ambient_light_energy *= 0.78
			dun._env.fog_density = 0.004
			dun._env.adjustment_saturation = 0.98
			if dun._sky_mat != null:
				dun._sky_mat.set_shader_parameter("cloud", 0.8)
				dun._sky_mat.set_shader_parameter("top_col", Color(0.30, 0.36, 0.40))
				dun._sky_mat.set_shader_parameter("hor_col", Color(0.52, 0.57, 0.58))
			if dun._sun != null:
				dun._sun.light_energy *= 0.6
				dun._sun.light_color = dun._sun.light_color.lerp(Color(0.80, 0.86, 0.90), 0.4)
			# the low poly swamp less bright and gay (the user's word,
			# 2026-10-25): a heavier, damper air, the greens dulled
			dun._env.adjustment_saturation = 0.82
			dun._env.adjustment_contrast = 1.08
			dun._env.tonemap_exposure = 0.88
			dun._env.fog_light_color = dun._env.fog_light_color.lerp(Color(0.38, 0.43, 0.38), 0.5)
			dun._env.fog_density = 0.0055
			dun._env.ambient_light_energy *= 0.85
			if dun._sun != null:
				dun._sun.light_energy *= 0.85
		"mountain":
			# the storm: dark, cold, the clouds down on the peaks
			dun._env.ambient_light_color = dun._env.ambient_light_color.lerp(Color(0.48, 0.52, 0.58), 0.4)
			dun._env.ambient_light_energy *= 0.9
			dun._env.fog_light_color = Color(0.32, 0.35, 0.42).lerp(dun._env.fog_light_color, 0.3)
			dun._env.fog_density = 0.006
			if dun._sky_mat != null:
				dun._sky_mat.set_shader_parameter("cloud", 0.92)
				dun._sky_mat.set_shader_parameter("top_col", Color(0.16, 0.18, 0.24))
				dun._sky_mat.set_shader_parameter("hor_col", Color(0.36, 0.38, 0.44))
			if dun._sun != null:
				dun._sun.light_energy *= 0.7
		"rampart":
			# Stormveil's grey over the gold
			dun._env.fog_light_color = dun._env.fog_light_color.lerp(Color(0.6, 0.62, 0.66), 0.4)
			dun._env.adjustment_contrast = 1.1
		"forest":
			# the deep old oak wood, low poly lit richly (the user's pick, 2026-10-23,
			# concept "real 3"): dim and green under the leaves, the clearing
			# in the sun, a white haze over it lit by the sun
			dun._env.ambient_light_color = Color(0.56, 0.63, 0.52)
			dun._env.ambient_light_energy *= 1.05
			dun._env.fog_light_color = Color(0.32, 0.40, 0.33)
			dun._env.fog_density = 0.009
			dun._env.fog_height = dun.centre(dun.current).y + 1.2
			dun._env.fog_height_density = 0.006
			dun._env.fog_sky_affect = 0.6
			dun._env.adjustment_contrast = 1.08
			dun._env.adjustment_saturation = 1.1
			if dun._sky_mat != null:
				dun._sky_mat.set_shader_parameter("top_col", Color(0.16, 0.22, 0.15))
				dun._sky_mat.set_shader_parameter("hor_col", Color(0.20, 0.27, 0.19))
			# the haze over the clearing is a fog volume ([ForestGlade]); the
			# volumetric fog itself thin everywhere else, so the wood keeps its
			# colours (the user, 2026-10-24); off on Low
			dun._env.volumetric_fog_enabled = Graphics.current != Graphics.Level.LOW
			dun._env.volumetric_fog_density = 0.0005
			dun._env.volumetric_fog_albedo = Color(0.94, 0.95, 0.93)
			dun._env.volumetric_fog_emission = Color(0.0, 0.0, 0.0)
			dun._env.volumetric_fog_anisotropy = 0.65
			dun._env.volumetric_fog_length = 70.0
			dun._env.volumetric_fog_ambient_inject = 0.0
			# the trees in the puddles (Ultra)
			dun._env.ssr_enabled = Graphics.current == Graphics.Level.ULTRA
			dun._env.ssr_max_steps = 48
			dun._env.ssr_fade_in = 0.15
			dun._env.ssr_fade_out = 2.0
			if dun._sun != null:
				dun._sun.light_energy *= 1.15
				dun._sun.light_color = dun._sun.light_color.lerp(Color(1.0, 0.95, 0.84), 0.35)
				dun._sun.light_volumetric_fog_energy = 2.5
				# high over the glade, so it comes down into the clearing
				# between the crowns rather than in under them from the side
				if dun._sun.rotation.x > -deg_to_rad(60.0):
					dun._sun.rotation.x = -deg_to_rad(60.0)
		"holy_spring":
			DungeonLook._holy_spring_look(dun)
		"altar":
			DungeonLook._altar_look(dun)
		"lake", "fort", "falls", "clouds", "gold_hall", "fog_sea":
			DungeonLook._terrace_look(dun, kind)
		"prison", "cell_cave":
			DungeonLook._ashen_look(dun, kind == "cell_cave")
		"twin_cave":
			DungeonLook._twin_cave_look(dun)
		"lord_court":
			# its look (F2's board): the misty court, the camp, the royal court
			var which := ThroneCourt.current()
			if which != "b":
				DungeonLook._ashen_look(dun)
			DungeonLook._court_look(dun, which)
		"war_camp":
			DungeonLook._ashen_look(dun)
			DungeonLook._court_look(dun, "a")
		"cave":
			# (2026-10-23: the land's grey under the earth, a cold cast only)
			dun._env.ambient_light_color = Color(0.54, 0.56, 0.59)
			dun._env.ambient_light_energy = 1.5
			dun._env.fog_light_color = Color(0.26, 0.30, 0.36)
			dun._env.fog_density = 0.005
			dun._env.glow_intensity = 1.25
			dun._env.glow_bloom = 0.18
			dun._env.glow_hdr_threshold = 0.8
			dun._env.volumetric_fog_enabled = true
			dun._env.volumetric_fog_density = 0.004
			dun._env.volumetric_fog_albedo = Color(0.7, 0.76, 0.85)
			dun._env.volumetric_fog_emission = Color(0.0, 0.0, 0.0)
			dun._env.volumetric_fog_length = 60.0
			dun._env.volumetric_fog_ambient_inject = 0.2
	# a cursed place: blood in its air ([method _curse])
	if bool(dun._room(dun.current).get("cursed", false)):
		dun._env.fog_light_color = dun._env.fog_light_color.lerp(Color(0.45, 0.03, 0.04), 0.75)
		dun._env.fog_density = maxf(dun._env.fog_density, 0.004)
		dun._env.ambient_light_color = dun._env.ambient_light_color.lerp(Color(0.95, 0.3, 0.28), 0.45)
		dun._env.volumetric_fog_albedo = dun._env.volumetric_fog_albedo.lerp(Color(0.9, 0.15, 0.12), 0.7)
		dun._env.adjustment_saturation *= 0.9
	# Low has neither (the graphics setting's word, [Graphics]): the plain fog
	# a little thicker in the volumetric's place.
	if Graphics.current == Graphics.Level.LOW:
		dun._env.glow_enabled = false
		if dun._env.volumetric_fog_enabled:
			dun._env.volumetric_fog_enabled = false
			dun._env.fog_density *= 1.6


## The altar's pine wood at dusk ([AltarCircle]): the sun gone, a cool blue
## light from the whole sky, a pale moon low, the blue mist on the ground;
## the warm light only the lanterns', the candles' and the altars' own.
static func _altar_look(dun: Dungeon) -> void:
	dun._env.ambient_light_color = Color(0.50, 0.60, 0.82)
	dun._env.ambient_light_energy *= 1.1
	dun._env.fog_light_color = Color(0.20, 0.27, 0.40)
	dun._env.fog_density = 0.011
	dun._env.fog_height = dun.centre(dun.current).y + 1.0
	dun._env.fog_height_density = 0.004
	dun._env.fog_sky_affect = 0.7
	dun._env.adjustment_contrast = 1.06
	dun._env.adjustment_saturation = 1.04
	if dun._sky_mat != null:
		dun._sky_mat.set_shader_parameter("top_col", Color(0.08, 0.11, 0.21))
		dun._sky_mat.set_shader_parameter("hor_col", Color(0.20, 0.27, 0.40))
	dun._env.volumetric_fog_enabled = Graphics.current != Graphics.Level.LOW
	dun._env.volumetric_fog_density = 0.0008
	dun._env.volumetric_fog_albedo = Color(0.62, 0.70, 0.86)
	dun._env.volumetric_fog_emission = Color(0.0, 0.0, 0.0)
	dun._env.volumetric_fog_anisotropy = 0.3
	dun._env.volumetric_fog_length = 60.0
	dun._env.volumetric_fog_ambient_inject = 0.15
	if dun._sun != null:
		dun._sun.light_energy *= 0.35
		dun._sun.light_color = Color(0.62, 0.72, 1.0)
		dun._sun.light_volumetric_fog_energy = 0.6
		if dun._sun.rotation.x > -deg_to_rad(40.0):
			dun._sun.rotation.x = -deg_to_rad(40.0)


## The holy spring's glade ([HolySpring]): a warm autumn afternoon, the sun
## high and golden through the maples, a light haze over the glade lit by it,
## the wood round it in a warm, dim brown shade.
static func _holy_spring_look(dun: Dungeon) -> void:
	dun._env.ambient_light_color = Color(0.70, 0.60, 0.48)
	dun._env.ambient_light_energy *= 1.05
	dun._env.fog_light_color = Color(0.30, 0.28, 0.20)
	dun._env.fog_density = 0.008
	dun._env.fog_height = dun.centre(dun.current).y + 1.2
	dun._env.fog_height_density = 0.005
	dun._env.fog_sky_affect = 0.6
	dun._env.adjustment_contrast = 1.07
	dun._env.adjustment_saturation = 1.08
	if dun._sky_mat != null:
		dun._sky_mat.set_shader_parameter("top_col", Color(0.20, 0.21, 0.16))
		dun._sky_mat.set_shader_parameter("hor_col", Color(0.27, 0.25, 0.18))
	dun._env.volumetric_fog_enabled = Graphics.current != Graphics.Level.LOW
	dun._env.volumetric_fog_density = 0.0005
	dun._env.volumetric_fog_albedo = Color(0.96, 0.92, 0.84)
	dun._env.volumetric_fog_emission = Color(0.0, 0.0, 0.0)
	dun._env.volumetric_fog_anisotropy = 0.65
	dun._env.volumetric_fog_length = 70.0
	dun._env.volumetric_fog_ambient_inject = 0.0
	if dun._sun != null:
		dun._sun.light_energy *= 1.15
		dun._sun.light_color = dun._sun.light_color.lerp(Color(1.0, 0.86, 0.64), 0.45)
		dun._sun.light_volumetric_fog_energy = 2.5
		if dun._sun.rotation.x > -deg_to_rad(58.0):
			dun._sun.rotation.x = -deg_to_rad(58.0)


## The prisoners' room in Ashen's light (the user's word, 2026-10-25, a
## shot of Ashen to go by): a high white overcast, no hard sun; the light
## soft and even from the whole sky, shadows only as a faint pool under
## things; a pale blue-grey air that thickens with distance until the far
## wall is half gone, a low mist on the floor; colours muted, the blacks
## lifted into a cool grey, the whites a little warm; a soft wide bloom.
## Every hour of the run looks the same here.
## `cave`: the cells' cave under its roof (2026-10-25): the sky only through
## the holes in it, the sun down through them in shafts, the rest lit by a
## cool soft fill and the torches; the air closer and greyer.
## The two-hall cave's own light ([TwinCave]): dark round the edges; the
## moon's shaft down through the den's sinkhole, the temple hall's own
## soft lights and its crystals' glow.
static func _twin_cave_look(dun: Dungeon) -> void:
	# the ghouls' cave (2026-10-27): the moon's cold shaft down the den's
	# sinkhole, the den dark round it; the temple hall's own soft lights
	if dun._sky_mat != null:
		dun._sky_mat.set_shader_parameter("cloud", 0.6)
		dun._sky_mat.set_shader_parameter("night", 0.0)
		dun._sky_mat.set_shader_parameter("top_col", Color(0.34, 0.42, 0.56))
		dun._sky_mat.set_shader_parameter("hor_col", Color(0.56, 0.60, 0.68))
		dun._sky_mat.set_shader_parameter("gnd_col", Color(0.22, 0.23, 0.26))
		dun._sky_mat.set_shader_parameter("sun_col", Color(1.0, 0.92, 0.80))
	dun._env.ambient_light_color = Color(0.62, 0.63, 0.64)
	dun._env.ambient_light_energy = 2.0
	dun._env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	dun._env.fog_light_color = Color(0.12, 0.12, 0.11)
	dun._env.fog_density = 0.012
	dun._env.fog_sky_affect = 0.0
	dun._env.fog_height_density = 0.0
	dun._env.volumetric_fog_enabled = true
	dun._env.volumetric_fog_density = 0.0003
	dun._env.volumetric_fog_albedo = Color(0.95, 0.96, 0.90)
	dun._env.volumetric_fog_emission = Color(0.0, 0.0, 0.0)
	dun._env.volumetric_fog_anisotropy = 0.6
	dun._env.volumetric_fog_length = 64.0
	dun._env.volumetric_fog_ambient_inject = 0.0
	dun._env.glow_intensity = 0.8
	dun._env.glow_bloom = 0.1
	dun._env.glow_hdr_threshold = 1.0
	dun._env.tonemap_mode = Environment.TONE_MAPPER_AGX
	dun._env.tonemap_exposure = 1.6
	dun._env.tonemap_white = 6.0
	dun._env.adjustment_contrast = 1.05
	dun._env.adjustment_saturation = 1.0
	dun._env.ssao_radius = 2.0
	dun._env.ssao_intensity = 1.8
	dun._env.ssao_power = 1.4
	if dun._sun != null:
		dun._sun.visible = true
		dun._sun.light_color = Color(1.0, 1.0, 0.97)
		dun._sun.light_energy = 1.8
		dun._sun.rotation.x = -deg_to_rad(84.0)
		dun._sun.light_angular_distance = 1.0
		dun._sun.shadow_opacity = 1.0
		dun._sun.shadow_blur = 1.2
		dun._sun.light_volumetric_fog_energy = 2.2


static func _ashen_look(dun: Dungeon, cave: bool = false) -> void:
	var air := Color(0.66, 0.69, 0.72)
	if dun._sky_mat != null:
		dun._sky_mat.set_shader_parameter("cloud", 1.0)
		dun._sky_mat.set_shader_parameter("night", 0.0)
		dun._sky_mat.set_shader_parameter("top_col", Color(0.60, 0.64, 0.68))
		dun._sky_mat.set_shader_parameter("hor_col", Color(0.80, 0.81, 0.80))
		dun._sky_mat.set_shader_parameter("gnd_col", Color(0.42, 0.43, 0.44))
		dun._sky_mat.set_shader_parameter("sun_col", Color(0.95, 0.92, 0.86))
	# the fill does most of the lighting: the whole white sky
	# (cool: what the sun does not reach goes blue-grey, what it does warm)
	dun._env.ambient_light_color = Color(0.62, 0.68, 0.77)
	dun._env.ambient_light_energy = 0.9
	# the air: clear at hand, thickening with distance (depth fog: none
	# nearer than 7 m, most of the way to grey at the far wall), the sky
	# lost in it, a thin mist low on the floor
	dun._env.fog_light_color = air
	dun._env.fog_mode = Environment.FOG_MODE_DEPTH
	dun._env.fog_density = 0.62
	dun._env.fog_depth_begin = 7.0
	dun._env.fog_depth_end = 75.0
	dun._env.fog_depth_curve = 1.25
	dun._env.fog_sky_affect = 0.7
	dun._env.fog_sun_scatter = 0.1
	dun._env.fog_height = dun.centre(dun.current).y + 0.8
	dun._env.fog_height_density = 0.015
	# a little light in the air you can see (High and Ultra), the shafts
	dun._env.volumetric_fog_enabled = true
	dun._env.volumetric_fog_density = 0.0025
	dun._env.volumetric_fog_albedo = Color(0.90, 0.92, 0.94)
	dun._env.volumetric_fog_emission = Color(0.0, 0.0, 0.0)
	dun._env.volumetric_fog_anisotropy = 0.55
	dun._env.volumetric_fog_length = 64.0
	dun._env.volumetric_fog_ambient_inject = 0.06
	# a soft, wide bloom on what is bright
	dun._env.glow_intensity = 0.75
	dun._env.glow_bloom = 0.14
	dun._env.glow_hdr_threshold = 0.9
	# the grade: AgX's gentle roll-off, low contrast, muted, the shadows a
	# cool lifted grey and the whites a little warm
	dun._env.tonemap_mode = Environment.TONE_MAPPER_AGX
	dun._env.tonemap_exposure = 1.05
	dun._env.tonemap_white = 6.0
	dun._env.adjustment_contrast = 0.98
	dun._env.adjustment_saturation = 0.82
	dun._env.adjustment_brightness = 1.02
	var grade := Gradient.new()
	grade.set_color(0, Color(0.09, 0.10, 0.13))
	grade.add_point(0.4, Color(0.40, 0.42, 0.45))
	grade.add_point(0.75, Color(0.77, 0.76, 0.74))
	grade.set_color(grade.get_point_count() - 1, Color(1.0, 0.97, 0.92))
	var lut := GradientTexture1D.new()
	lut.gradient = grade
	lut.width = 256
	dun._env.adjustment_color_correction = lut
	# soft, wide contact shade, as under an overcast sky
	dun._env.ssao_radius = 2.6
	dun._env.ssao_intensity = 1.5
	dun._env.ssao_power = 1.25
	dun._env.ssao_detail = 0.25
	dun._env.ssao_light_affect = 0.2
	if dun._sun != null:
		# the sun behind the cloud: weak, high, its shadows wide and faint
		dun._sun.visible = true
		dun._sun.light_color = Color(1.0, 0.93, 0.84)
		dun._sun.light_energy = 1.1
		dun._sun.rotation.x = -deg_to_rad(46.0)
		dun._sun.light_angular_distance = 4.0
		dun._sun.shadow_opacity = 0.7
		dun._sun.shadow_blur = 2.5
		dun._sun.light_volumetric_fog_energy = 1.6
	if not cave:
		return
	# under the roof: the fill cooler and lower, the air closer and greyer,
	# the sun high and strong enough to come down through the holes in
	# shafts with edges, the shafts seen in the air (the haze under each
	# hole is [CellCave]'s)
	dun._env.ambient_light_color = Color(0.62, 0.67, 0.75)
	dun._env.ambient_light_energy = 1.2
	dun._env.fog_light_color = Color(0.46, 0.50, 0.55)
	dun._env.fog_density = 0.34
	dun._env.fog_depth_begin = 8.0
	dun._env.fog_depth_end = 60.0
	dun._env.fog_height_density = 0.0
	dun._env.volumetric_fog_density = 0.0015
	dun._env.volumetric_fog_ambient_inject = 0.02
	dun._env.volumetric_fog_length = 48.0
	dun._env.tonemap_exposure = 1.35
	dun._env.glow_intensity = 0.85
	dun._env.glow_bloom = 0.16
	if dun._sun != null:
		dun._sun.light_energy = 1.8
		dun._sun.rotation.x = -deg_to_rad(70.0)
		dun._sun.light_angular_distance = 1.5
		dun._sun.shadow_opacity = 0.95
		dun._sun.shadow_blur = 1.5
		dun._sun.light_volumetric_fog_energy = 4.0


## The lord's court on its cliff in the mist ([ThroneCourt]), over Ashen's
## light ([method _ashen_look]): open, the air pale and white far off so the
## far pillars of rock fade into it, the cliff's foot lost in the cloud, the
## sun low and soft from the side behind the cloud.
## `which`: "c" that; "a" the warlord's camp at a grey dusk, the sun low and
## orange under the cloud; "b" the royal court's golden afternoon, clear.
static func _court_look(dun: Dungeon, which: String = "c") -> void:
	if which == "a":
		DungeonLook._camp_look(dun)
		return
	if which == "b":
		DungeonLook._royal_look(dun)
		return
	var air := Color(0.80, 0.82, 0.84)
	if dun._sky_mat != null:
		dun._sky_mat.set_shader_parameter("top_col", Color(0.70, 0.73, 0.77))
		dun._sky_mat.set_shader_parameter("hor_col", Color(0.88, 0.88, 0.87))
		dun._sky_mat.set_shader_parameter("gnd_col", Color(0.80, 0.81, 0.82))
		dun._sky_mat.set_shader_parameter("cloud", 0.9)
	dun._env.fog_light_color = air
	dun._env.fog_density = 0.72
	dun._env.fog_depth_begin = 28.0
	dun._env.fog_depth_end = 420.0
	dun._env.fog_depth_curve = 0.8
	dun._env.fog_sky_affect = 0.75
	dun._env.fog_height_density = 0.0
	dun._env.volumetric_fog_density = 0.0012
	dun._env.volumetric_fog_ambient_inject = 0.05
	dun._env.ambient_light_color = Color(0.70, 0.73, 0.79)
	dun._env.ambient_light_energy = 1.05
	dun._env.tonemap_exposure = 1.08
	for m in dun._cloud_layer_mats:
		m.set_shader_parameter("top", Color(0.92, 0.92, 0.92))
		m.set_shader_parameter("low", Color(0.70, 0.72, 0.75))
	if dun._sun != null:
		dun._sun.light_energy = 1.4
		dun._sun.light_color = Color(1.0, 0.93, 0.84)
		dun._sun.rotation.x = -deg_to_rad(38.0)
		dun._sun.light_angular_distance = 3.0
		dun._sun.shadow_opacity = 0.78


static func _camp_look(dun: Dungeon) -> void:
	if dun._sky_mat != null:
		dun._sky_mat.set_shader_parameter("top_col", Color(0.30, 0.32, 0.37))
		dun._sky_mat.set_shader_parameter("hor_col", Color(0.72, 0.60, 0.50))
		dun._sky_mat.set_shader_parameter("gnd_col", Color(0.50, 0.48, 0.47))
		dun._sky_mat.set_shader_parameter("sun_col", Color(1.0, 0.70, 0.45))
		dun._sky_mat.set_shader_parameter("cloud", 0.85)
	dun._env.fog_light_color = Color(0.58, 0.56, 0.55)
	dun._env.fog_density = 0.62
	dun._env.fog_depth_begin = 35.0
	dun._env.fog_depth_end = 520.0
	dun._env.fog_depth_curve = 0.9
	dun._env.fog_sky_affect = 0.5
	dun._env.fog_height_density = 0.0
	dun._env.volumetric_fog_density = 0.0015
	dun._env.volumetric_fog_ambient_inject = 0.04
	dun._env.ambient_light_color = Color(0.56, 0.57, 0.63)
	dun._env.ambient_light_energy = 0.85
	dun._env.tonemap_exposure = 1.0
	dun._env.adjustment_saturation = 0.86
	for m in dun._cloud_layer_mats:
		m.set_shader_parameter("top", Color(0.78, 0.70, 0.64))
		m.set_shader_parameter("low", Color(0.46, 0.46, 0.50))
	if dun._sun != null:
		dun._sun.light_energy = 1.15
		dun._sun.light_color = Color(1.0, 0.72, 0.48)
		dun._sun.rotation.x = -deg_to_rad(16.0)
		dun._sun.light_angular_distance = 2.5
		dun._sun.shadow_opacity = 0.75


static func _royal_look(dun: Dungeon) -> void:
	if dun._sky_mat != null:
		dun._sky_mat.set_shader_parameter("night", 0.0)
		dun._sky_mat.set_shader_parameter("cloud", 0.35)
		dun._sky_mat.set_shader_parameter("top_col", Color(0.36, 0.54, 0.82))
		dun._sky_mat.set_shader_parameter("hor_col", Color(0.92, 0.84, 0.70))
		dun._sky_mat.set_shader_parameter("sun_col", Color(1.0, 0.88, 0.70))
	dun._env.fog_light_color = Color(0.92, 0.85, 0.74)
	dun._env.fog_density = 0.0008
	dun._env.fog_sky_affect = 0.3
	dun._env.volumetric_fog_enabled = false
	dun._env.ambient_light_color = Color(0.80, 0.74, 0.66)
	dun._env.ambient_light_energy = 1.0
	dun._env.adjustment_saturation = 1.08
	dun._env.adjustment_contrast = 1.06
	for m in dun._cloud_layer_mats:
		m.set_shader_parameter("top", Color(1.0, 0.93, 0.84))
		m.set_shader_parameter("low", Color(0.80, 0.72, 0.68))
	if dun._sun != null:
		dun._sun.visible = true
		dun._sun.light_energy = 1.15
		dun._sun.light_color = Color(1.0, 0.86, 0.66)
		dun._sun.rotation.x = -deg_to_rad(28.0)


## The four terraces' light ([TerracePlaces]): clear skies, real sun on the
## floor, each its own hour — the lake's late morning, the fortress's low
## gold afternoon, the falls' bright haze, the clouds' golden day.
static func _terrace_look(dun: Dungeon, kind: String) -> void:
	var looks := {
		"lake": {"sun": Color(1.0, 0.96, 0.88), "power": 1.12, "up": 46.0, "fog": Color(0.70, 0.82, 0.90),
				"thick": 0.0007, "top": Color(0.28, 0.50, 0.80), "hor": Color(0.72, 0.84, 0.92), "sat": 1.12},
		"fort": {"sun": Color(1.0, 0.88, 0.70), "power": 1.15, "up": 30.0, "fog": Color(0.90, 0.84, 0.74),
				"thick": 0.0008, "top": Color(0.36, 0.56, 0.82), "hor": Color(0.90, 0.84, 0.74), "sat": 1.0},
		"falls": {"sun": Color(1.0, 0.93, 0.80), "power": 1.15, "up": 52.0, "fog": Color(0.84, 0.88, 0.86),
				"thick": 0.0011, "top": Color(0.32, 0.54, 0.80), "hor": Color(0.80, 0.86, 0.88), "sat": 1.1},
		"clouds": {"sun": Color(1.0, 0.86, 0.64), "power": 1.15, "up": 40.0, "fog": Color(1.0, 0.88, 0.70),
				"thick": 0.0006, "top": Color(0.30, 0.54, 0.86), "hor": Color(0.86, 0.86, 0.84), "sat": 1.16},
		# the fog arena ([FogArena]): a warm, muted afternoon from the side,
		# a pale gold haze over the fog sea (as its concept)
		"fog_sea": {"sun": Color(1.0, 0.89, 0.72), "power": 1.12, "up": 30.0, "fog": Color(0.94, 0.89, 0.80),
				"thick": 0.0009, "top": Color(0.42, 0.57, 0.74), "hor": Color(0.93, 0.87, 0.75), "sat": 1.04},
		# the golden hall, open on one side, under a storm (the user's word,
		# 2026-10-24: the dark one is better; thunder, lightning in the clouds)
		"gold_hall": {"sun": Color(0.70, 0.76, 0.88), "power": 0.16, "up": 42.0, "fog": Color(0.34, 0.38, 0.44),
				"thick": 0.0024, "top": Color(0.12, 0.14, 0.18), "hor": Color(0.28, 0.31, 0.36), "sat": 0.84},
		# its bright afternoon (F2's board): the sun in over the fallen wall
		"gold_hall_sun": {"sun": Color(1.0, 0.92, 0.78), "power": 1.25, "up": 42.0, "fog": Color(0.86, 0.86, 0.84),
				"thick": 0.0005, "top": Color(0.34, 0.54, 0.82), "hor": Color(0.90, 0.84, 0.72), "sat": 1.08},
	}
	var storm := kind == "gold_hall" and TerracePlaces.hall_mood == "storm"
	var lk: Dictionary = looks["gold_hall_sun" if kind == "gold_hall" and not storm else kind]
	dun._env.fog_light_color = dun._env.fog_light_color.lerp(lk["fog"], 0.6)
	dun._env.fog_density = float(lk["thick"])
	dun._env.adjustment_saturation = float(lk["sat"])
	dun._env.adjustment_contrast = 1.07
	if dun._sky_mat != null:
		dun._sky_mat.set_shader_parameter("cloud", 0.35)
		dun._sky_mat.set_shader_parameter("top_col", lk["top"])
		dun._sky_mat.set_shader_parameter("hor_col", lk["hor"])
	if dun._sun != null:
		dun._sun.light_color = dun._sun.light_color.lerp(lk["sun"], 0.6)
		dun._sun.light_energy *= float(lk["power"])
		# the sun up where it lays real shadow on the floor
		dun._sun.rotation.x = -deg_to_rad(float(lk["up"]))
	if kind == "gold_hall" and storm:
		# the storm's light: cold and low, heavy cloud, a grey mist in the
		# valley; the flashes come from [method _lightning]
		if dun._sky_mat != null:
			dun._sky_mat.set_shader_parameter("cloud", 1.0)
		dun._env.ambient_light_color = Color(0.46, 0.50, 0.58)
		dun._env.ambient_light_energy = 0.5
		dun._env.adjustment_brightness = 0.8
		dun._env.adjustment_contrast = 1.12
	elif kind == "gold_hall":
		# the bright afternoon: warm shade under the roof, the shafts seen
		dun._env.ambient_light_color = Color(0.80, 0.72, 0.62)
		dun._env.ambient_light_energy = minf(dun._env.ambient_light_energy, 0.75)
	if kind == "gold_hall":
		dun._env.volumetric_fog_enabled = true
		dun._env.volumetric_fog_density = 0.005 if storm else 0.003
		dun._env.volumetric_fog_albedo = Color(0.70, 0.74, 0.80) if storm else Color(1.0, 0.90, 0.74)
		dun._env.volumetric_fog_emission = Color(0.0, 0.0, 0.0)
		dun._env.volumetric_fog_length = 70.0
		dun._env.volumetric_fog_ambient_inject = 0.05
		if dun._sun != null:
			dun._sun.light_volumetric_fog_energy = 1.0 if storm else 3.0
			# from the open side, over the fallen wall
			dun._sun.rotation.y = deg_to_rad(-120.0)
