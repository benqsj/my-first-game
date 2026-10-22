class_name OrcSpoils
extends RefCounted

## The orcs' palace as the orcs keep it (the user's word, 2026-10-21: one
## should see that the orcs have taken it): a fine palace the barbarians have
## made a mess of. Their own rough banners hung over the old ones, tents of
## hide pitched in its halls, a boar turning on a spit over a fire, cages with
## what is left of their prisoners, barricades of sharpened stakes, heaps of
## bones, blood on the floor, the palace's goods heaped up as loot.
##
## Built by [Dungeon] into its palace places ([method dress]), with its own
## helpers (`_deco`, `_blocker`, `_flame`, `_bones`, `_stake`...). Everything
## keeps off the aisle down the middle, the far end where the portals open and
## the near end he comes in by.

const TOWN_KIT := "res://assets/town/town_kit.glb"

const BANNER_SHADER := """
shader_type spatial;
render_mode cull_disabled;
// An orc's war banner: a hide dyed blood red, black at its edges, the clan's
// three claws daubed on it in bone-white, torn ragged at the foot, holed,
// stirring in the draught.
uniform vec4 hide : source_color = vec4(0.42, 0.06, 0.04, 1.0);
uniform vec4 paint : source_color = vec4(0.86, 0.80, 0.68, 1.0);
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}
varying vec3 wpos;
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float down = UV.y;
	VERTEX.z += sin(TIME * 1.3 + wpos.x * 0.7 + wpos.z * 0.5 + down * 2.0) * 0.12 * down * down;
}
void fragment() {
	vec2 uv = UV;
	float seed = floor(wpos.x * 0.37 + wpos.z * 0.61);
	float ragged = noise(vec2(uv.x * 7.0 + seed, 0.0)) * 0.16 + noise(vec2(uv.x * 19.0, seed)) * 0.06;
	if (uv.y > 0.9 - ragged) { discard; }
	if (noise(uv * vec2(6.0, 10.0) + seed) > 0.86 && uv.y > 0.3) { discard; }
	float side = min(uv.x, 1.0 - uv.x);
	vec3 c = hide.rgb * (0.7 + 0.45 * noise(uv * 18.0 + seed));
	c = mix(c, vec3(0.04, 0.02, 0.02), smoothstep(0.12, 0.0, side) * 0.8);
	c = mix(c, vec3(0.05, 0.03, 0.02), smoothstep(0.55, 0.85, uv.y + ragged * 0.6) * 0.75);
	// the three claws, drawn down from a bar
	float claws = 0.0;
	for (int k = 0; k < 3; k++) {
		float x = 0.36 + float(k) * 0.14 + (uv.y - 0.25) * (float(k) - 1.0) * 0.18;
		float w = 0.035 * (1.0 - smoothstep(0.25, 0.62, uv.y));
		claws = max(claws, (1.0 - smoothstep(w * 0.6, w, abs(uv.x - x))) * step(0.22, uv.y) * step(uv.y, 0.6));
	}
	float bar = (1.0 - smoothstep(0.03, 0.05, abs(uv.y - 0.18))) * step(0.3, uv.x) * step(uv.x, 0.7);
	float daub = max(claws, bar) * (0.75 + 0.25 * noise(uv * 40.0));
	ALBEDO = mix(c, paint.rgb, daub);
	ROUGHNESS = 0.96;
}
"""

const HIDE_SHADER := """
shader_type spatial;
render_mode cull_disabled;
// Hides sewn together for a tent: patches of brown and grey, the seams dark.
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}
varying vec3 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 p = vec2(wpos.x + wpos.z, wpos.y) * 0.9;
	vec2 cell = floor(p + vec2(noise(p * 0.7) * 0.6, 0.0));
	float shade = hash(cell);
	vec3 a = vec3(0.13, 0.08, 0.05);
	vec3 b = vec3(0.10, 0.09, 0.08);
	vec3 c = mix(a, b, shade) * (0.75 + 0.4 * noise(p * 9.0));
	// a band daubed in old blood round it, and the clan's marks
	float band = smoothstep(0.08, 0.0, abs(wpos.y - 1.6 - noise(p * 2.0) * 0.25));
	c = mix(c, vec3(0.32, 0.03, 0.02), band * 0.85);
	vec2 f = fract(p + vec2(noise(p * 0.7) * 0.6, 0.0));
	float seam = 1.0 - smoothstep(0.0, 0.04, min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y)));
	c *= 1.0 - seam * 0.6;
	ALBEDO = c;
	ROUGHNESS = 0.9;
}
"""

static var _banner_mat: ShaderMaterial
static var _hide_mat: ShaderMaterial
static var _meat_mat: StandardMaterial3D
static var _fat_mat: StandardMaterial3D
static var _blood_tex: Texture2D
static var _socket_mat: StandardMaterial3D
static var _kit: Dictionary = {}


static func _materials() -> void:
	if _banner_mat != null:
		return
	var bs := Shader.new()
	bs.code = BANNER_SHADER
	_banner_mat = ShaderMaterial.new()
	_banner_mat.shader = bs
	var hs := Shader.new()
	hs.code = HIDE_SHADER
	_hide_mat = ShaderMaterial.new()
	_hide_mat.shader = hs
	_meat_mat = StandardMaterial3D.new()
	_meat_mat.albedo_color = Color(0.34, 0.13, 0.06)
	_meat_mat.roughness = 0.35
	_meat_mat.metallic_specular = 0.7
	_fat_mat = StandardMaterial3D.new()
	_fat_mat.albedo_color = Color(0.55, 0.33, 0.16)
	_fat_mat.roughness = 0.4
	_blood_tex = _blood_texture()


## A splash of old blood: a dark heart, drops and runs round it, drawn once.
static func _blood_texture() -> Texture2D:
	var size := 128
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var blobs: Array = []
	blobs.append([Vector2(64, 64), 26.0])
	for k in 22:
		var a := rng.randf() * TAU
		var r := rng.randf_range(10.0, 52.0)
		blobs.append([Vector2(64, 64) + Vector2(cos(a), sin(a)) * r, rng.randf_range(2.0, 10.0) * (1.0 - r / 70.0) + 1.5])
	for y in size:
		for x in size:
			var p := Vector2(x, y)
			var v := 0.0
			for b: Array in blobs:
				var d := p.distance_to(b[0])
				v = maxf(v, 1.0 - smoothstep(float(b[1]) * 0.75, float(b[1]), d))
			if v <= 0.0:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			var dark := 0.6 + 0.4 * sin(float(x) * 0.31 + float(y) * 0.17)
			img.set_pixel(x, y, Color(0.22 * dark, 0.02, 0.015, v * 0.88))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


static func _kit_mesh(name: String) -> Mesh:
	if _kit.is_empty():
		var scene := load(TOWN_KIT) as PackedScene
		if scene != null:
			var models := scene.instantiate()
			for node in models.find_children("*", "MeshInstance3D", true, false):
				_kit[String(node.name)] = (node as MeshInstance3D).mesh
			models.free()
	return _kit.get(name) as Mesh


## The orcs' mark on palace place `kind` (w × l, walls `h` high) in `room`.
static func dress(d: Dungeon, room: Node3D, kind: String, w: float, l: float, h: float, has_roof: bool) -> void:
	_materials()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(kind) + int(w * 13.0 + l)
	match kind:
		"hall":
			# (the user's word, 2026-10-23: the tents, the fires, the wooden
			# spikes and the pig on the spit gone; the blood and the arrows kept)
			_banners_on_columns(d, room, w, l, h)
			_gate_banners(d, room, l, h)
			_blood(d, room, w, l, 12, rng)
		"court":
			_wall_banners(d, room, w, l, h)
			_tent(d, room, Vector3(-13.0, 0.0, l * 0.05), 0.9, rng)
			_tent(d, room, Vector3(14.0, 0.0, -l * 0.12), -2.0, rng)
			_tent(d, room, Vector3(-15.0, 0.0, -l * 0.22), 1.6, rng)
			_roast(d, room, Vector3(9.0, 0.0, l * 0.14), rng)
			_cage(d, room, Vector3(-19.0, 0.0, l * 0.3), rng)
			_cage(d, room, Vector3(19.0, 0.0, l * 0.26), rng)
			_barricade(d, room, Vector3(0.0, 0.0, l * 0.36), 0.0, 12, rng, 6.0)
			_loot(d, room, Vector3(18.0, 0.0, -l * 0.3), rng)
			_rack(d, room, Vector3(-20.0, 0.0, -l * 0.05), PI * 0.5)
			_campfire(d, room, Vector3(-8.0, 0.0, -l * 0.12), rng)
			_bone_heap(d, room, Vector3(-9.0, 0.0, -l * 0.34), rng)
			_bone_heap(d, room, Vector3(6.0, 0.0, l * 0.3), rng)
			_blood(d, room, w, l, 10, rng)
		"terrace":
			_wall_banners(d, room, w, l, h, true)
			_tent(d, room, Vector3(-17.0, 0.0, l * 0.18), 1.2, rng)
			_roast(d, room, Vector3(-12.0, 0.0, -l * 0.08), rng)
			_gibbets(d, room, w, l)
			_barricade(d, room, Vector3(-18.0, 0.0, -l * 0.3), PI * 0.5, 4, rng)
			_bone_heap(d, room, Vector3(10.0, 0.0, l * 0.3), rng)
			_loot(d, room, Vector3(-20.0, 0.0, -l * 0.12), rng)
			_rack(d, room, Vector3(-24.0, 0.0, l * 0.32), PI * 0.5)
			_blood(d, room, w, l, 9, rng)
		"throne":
			_throne_banners(d, room, l)
			# stakes with skulls up both sides of the way to the lord
			for k in 7:
				for side: float in [-1.0, 1.0]:
					d._stake(room, Vector3(side * rng.randf_range(7.5, 9.0), 0.0, l * 0.36 - float(k) * l * 0.1), true)
			_cage(d, room, Vector3(-22.0, 0.0, -l * 0.2), rng)
			_cage(d, room, Vector3(22.0, 0.0, -l * 0.26), rng)
			_bone_heap(d, room, Vector3(-14.0, 0.0, l * 0.12), rng)
			_bone_heap(d, room, Vector3(15.0, 0.0, -l * 0.02), rng)
			_bone_heap(d, room, Vector3(5.0, 0.0, -l * 0.33), rng)
			_blood(d, room, w, l, 14, rng)


## One war banner: a rough pole, a cross-bar lashed on, the hide hanging from
## it, a skull on the pole's top. `long` tall, facing `yaw`.
static func _banner(d: Dungeon, room: Node3D, top: Vector3, yaw: float, wide: float, long: float,
		with_pole: bool = true) -> void:
	var holder := Node3D.new()
	holder.position = top
	holder.rotation.y = yaw
	room.add_child(holder)
	var cloth := QuadMesh.new()
	cloth.size = Vector2(wide, long)
	cloth.subdivide_depth = 8
	cloth.subdivide_width = 2
	var cm := MeshInstance3D.new()
	cm.mesh = cloth
	cm.material_override = _banner_mat
	cm.position = Vector3(0.0, -long * 0.5 - 0.1, 0.06)
	cm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(cm)
	var bar := CylinderMesh.new()
	bar.top_radius = 0.06
	bar.bottom_radius = 0.07
	bar.height = wide + 0.6
	bar.radial_segments = 6
	var bm := MeshInstance3D.new()
	bm.mesh = bar
	bm.material_override = d._wood_mat
	bm.rotation.z = PI * 0.5
	holder.add_child(bm)
	# horns at the bar's ends
	for side: float in [-1.0, 1.0]:
		var horn := CylinderMesh.new()
		horn.top_radius = 0.0
		horn.bottom_radius = 0.07
		horn.height = 0.45
		horn.radial_segments = 6
		var hm := MeshInstance3D.new()
		hm.mesh = horn
		hm.material_override = d._bone_mat if d._bone_mat != null else d._trim_mat
		hm.position = Vector3(side * (wide * 0.5 + 0.35), 0.12, 0.0)
		hm.rotation.z = -side * 0.9
		holder.add_child(hm)
	if with_pole:
		var pole := CylinderMesh.new()
		pole.top_radius = 0.08
		pole.bottom_radius = 0.1
		pole.height = top.y + 0.6
		pole.radial_segments = 6
		var pm := MeshInstance3D.new()
		pm.mesh = pole
		pm.material_override = d._wood_mat
		pm.position = Vector3(0.0, -top.y * 0.5 + 0.3, -0.08)
		holder.add_child(pm)
		_skull(d, holder, Vector3(0.0, 0.75, -0.08), 1.2)


static func _skull(d: Dungeon, parent: Node3D, at: Vector3, size: float = 1.0) -> void:
	if d._bone_mat == null:
		d._bone_mat = StandardMaterial3D.new()
		d._bone_mat.albedo_color = Color(0.78, 0.74, 0.64)
		d._bone_mat.roughness = 0.8
	var head := SphereMesh.new()
	head.radius = 0.15 * size
	head.height = 0.3 * size
	head.radial_segments = 10
	head.rings = 6
	var hm := MeshInstance3D.new()
	hm.mesh = head
	hm.material_override = d._bone_mat
	hm.position = at
	hm.scale = Vector3(1.0, 0.9, 1.15)
	parent.add_child(hm)
	var jaw := BoxMesh.new()
	jaw.size = Vector3(0.18, 0.08, 0.14) * size
	var jm := MeshInstance3D.new()
	jm.mesh = jaw
	jm.material_override = d._bone_mat
	jm.position = at + Vector3(0.0, -0.15, 0.06) * size
	parent.add_child(jm)
	# the eyes' and the nose's holes, dark
	if _socket_mat == null:
		_socket_mat = StandardMaterial3D.new()
		_socket_mat.albedo_color = Color(0.03, 0.02, 0.02)
		_socket_mat.roughness = 1.0
	for side: float in [-1.0, 1.0]:
		var eye := SphereMesh.new()
		eye.radius = 0.045 * size
		eye.height = 0.07 * size
		eye.radial_segments = 6
		eye.rings = 3
		var em := MeshInstance3D.new()
		em.mesh = eye
		em.material_override = _socket_mat
		em.position = at + Vector3(side * 0.055, 0.0, 0.155) * size
		parent.add_child(em)
	var nose := BoxMesh.new()
	nose.size = Vector3(0.03, 0.05, 0.02) * size
	var nm := MeshInstance3D.new()
	nm.mesh = nose
	nm.material_override = _socket_mat
	nm.position = at + Vector3(0.0, -0.07, 0.165) * size
	parent.add_child(nm)


## Banners hung on the hall's columns, facing the aisle (over the palace's
## own on the walls).
static func _banners_on_columns(d: Dungeon, room: Node3D, w: float, l: float, h: float) -> void:
	var n := maxi(3, int(l / 9.0))
	for k in n:
		if k % 2 == 1:
			continue
		var z := l * 0.5 - (float(k) + 0.5) * l / float(n)
		for side: float in [-1.0, 1.0]:
			var x := side * (w * 0.5 - 4.5)
			var top := minf(h - 3.0, 9.5)
			_banner(d, room, Vector3(x - side * 1.0, top, z), -side * PI * 0.5, 1.6, minf(top - 2.5, 6.0), false)


## Two great banners either side of the far gate.
static func _gate_banners(d: Dungeon, room: Node3D, l: float, h: float) -> void:
	for side: float in [-1.0, 1.0]:
		_banner(d, room, Vector3(side * 7.5, minf(h - 2.0, 12.0), -l * 0.5 + 0.35), 0.0, 3.2, minf(h - 4.5, 9.0), false)


## Banners on a court's or terrace's walls, between its columns.
static func _wall_banners(d: Dungeon, room: Node3D, w: float, l: float, h: float, one_side: bool = false) -> void:
	var n := maxi(3, int(l / 10.0))
	for k in n - 1:
		var z := l * 0.5 - float(k + 1) * l / float(n)
		for side: float in [-1.0, 1.0]:
			if one_side and side > 0.0:
				continue
			_banner(d, room, Vector3(side * (w * 0.5 - 0.5), minf(h - 1.5, 8.0), z), -side * PI * 0.5, 2.0,
					minf(h - 3.0, 5.5), false)


## The lord's: banners on poles round his dais, tall and close.
static func _throne_banners(d: Dungeon, room: Node3D, l: float) -> void:
	for k in 4:
		var side := -1.0 if k % 2 == 0 else 1.0
		var x := side * (9.0 + floorf(float(k) / 2.0) * 5.0)
		_banner(d, room, Vector3(x, 7.5, -l * 0.5 + 6.0 + floorf(float(k) / 2.0) * 2.0), 0.0, 2.2, 4.8)
		d._blocker(room, Vector3(0.4, 4.0, 0.4), Vector3(x, 2.0, -l * 0.5 + 5.9 + floorf(float(k) / 2.0) * 2.0))


## A tent of sewn hides on poles: their ends crossing out of its top, its
## mouth propped open, a skull on a stake before it.
static func _tent(d: Dungeon, room: Node3D, at: Vector3, yaw: float, rng: RandomNumberGenerator) -> void:
	var holder := Node3D.new()
	holder.position = at
	holder.rotation.y = yaw
	room.add_child(holder)
	var tall := rng.randf_range(3.6, 4.4)
	var wide := rng.randf_range(2.6, 3.1)
	var cone := CylinderMesh.new()
	cone.top_radius = 0.18
	cone.bottom_radius = wide
	cone.height = tall
	cone.radial_segments = 7
	cone.cap_top = false
	cone.cap_bottom = false
	var tm := MeshInstance3D.new()
	tm.mesh = cone
	tm.material_override = _hide_mat
	tm.position = Vector3(0.0, tall * 0.5, 0.0)
	holder.add_child(tm)
	# the poles, crossing out of the top
	for k in 5:
		var a := TAU * float(k) / 5.0 + 0.3
		var pole := CylinderMesh.new()
		pole.top_radius = 0.05
		pole.bottom_radius = 0.06
		pole.height = tall + 1.6
		pole.radial_segments = 5
		var pm := MeshInstance3D.new()
		pm.mesh = pole
		pm.material_override = d._wood_mat
		var lean := atan2(wide, tall)
		pm.position = Vector3(sin(a) * wide * 0.5, tall * 0.5 + 0.35, cos(a) * wide * 0.5) * 1.0
		pm.rotation = Vector3(-cos(a) * lean, 0.0, sin(a) * lean)
		holder.add_child(pm)
	# its mouth: a dark flap open at the front
	var mouth := QuadMesh.new()
	mouth.size = Vector2(1.2, 1.9)
	var mm := MeshInstance3D.new()
	mm.mesh = mouth
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.03, 0.025, 0.02)
	dark.roughness = 1.0
	mm.material_override = dark
	mm.position = Vector3(0.0, 0.95, wide * 0.72)
	mm.rotation.x = -0.32
	holder.add_child(mm)
	d._stake(room, at + Vector3(sin(yaw) * (wide + 1.2) + cos(yaw) * 1.1, 0.0, cos(yaw) * (wide + 1.2) - sin(yaw) * 1.1), true)
	d._blocker(room, Vector3(wide * 1.5, tall, wide * 1.5), at + Vector3(0.0, tall * 0.5, 0.0))


## A boar turning on a spit over a fire, between two forked posts.
static func _roast(d: Dungeon, room: Node3D, at: Vector3, rng: RandomNumberGenerator) -> void:
	var holder := Node3D.new()
	holder.position = at
	holder.rotation.y = rng.randf_range(-0.4, 0.4)
	room.add_child(holder)
	# the fire: logs, its flame and light, its crackle
	for k in 4:
		var wood := CylinderMesh.new()
		wood.top_radius = 0.1
		wood.bottom_radius = 0.12
		wood.height = 1.3
		wood.radial_segments = 6
		var lm := MeshInstance3D.new()
		lm.mesh = wood
		lm.material_override = d._wood_mat
		lm.position = Vector3(0.0, 0.25, 0.0)
		lm.rotation = Vector3(0.0, TAU * float(k) / 4.0, 1.1)
		holder.add_child(lm)
	var ash := CylinderMesh.new()
	ash.top_radius = 0.75
	ash.bottom_radius = 0.8
	ash.height = 0.06
	var am := MeshInstance3D.new()
	am.mesh = ash
	am.material_override = d._coals_mat if d._coals_mat != null else d._iron_mat
	am.position = Vector3(0.0, 0.03, 0.0)
	holder.add_child(am)
	holder.add_child(d._flame(Vector3(0.0, 0.15, 0.0), 1.8, 26))
	d._crackle(holder, Vector3(0.0, 0.6, 0.0))
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.58, 0.28)
	light.light_energy = 2.4
	light.omni_range = 11.0
	light.position = Vector3(0.0, 1.4, 0.0)
	holder.add_child(d._fire_light(light))
	# the forked posts
	for side: float in [-1.0, 1.0]:
		var post := CylinderMesh.new()
		post.top_radius = 0.07
		post.bottom_radius = 0.09
		post.height = 1.9
		post.radial_segments = 6
		var pm := MeshInstance3D.new()
		pm.mesh = post
		pm.material_override = d._wood_mat
		pm.position = Vector3(side * 1.25, 0.95, 0.0)
		holder.add_child(pm)
		for fork: float in [-1.0, 1.0]:
			var prong := CylinderMesh.new()
			prong.top_radius = 0.04
			prong.bottom_radius = 0.06
			prong.height = 0.4
			prong.radial_segments = 5
			var fm := MeshInstance3D.new()
			fm.mesh = prong
			fm.material_override = d._wood_mat
			fm.position = Vector3(side * 1.25, 1.95, fork * 0.08)
			fm.rotation.x = fork * 0.45
			holder.add_child(fm)
	# the spit and the boar on it, turning
	var turn := Node3D.new()
	turn.position = Vector3(0.0, 1.85, 0.0)
	holder.add_child(turn)
	var spit := CylinderMesh.new()
	spit.top_radius = 0.035
	spit.bottom_radius = 0.035
	spit.height = 3.0
	var sm := MeshInstance3D.new()
	sm.mesh = spit
	sm.material_override = d._iron_mat
	sm.rotation.z = PI * 0.5
	turn.add_child(sm)
	var body := SphereMesh.new()
	body.radius = 0.5
	body.height = 1.0
	var bm := MeshInstance3D.new()
	bm.mesh = body
	bm.material_override = _meat_mat
	bm.scale = Vector3(1.55, 0.78, 0.82)
	turn.add_child(bm)
	var head := SphereMesh.new()
	head.radius = 0.26
	head.height = 0.5
	var hm := MeshInstance3D.new()
	hm.mesh = head
	hm.material_override = _meat_mat
	hm.position = Vector3(0.88, 0.02, 0.0)
	hm.scale = Vector3(1.3, 0.9, 0.85)
	turn.add_child(hm)
	var snout := CylinderMesh.new()
	snout.top_radius = 0.1
	snout.bottom_radius = 0.14
	snout.height = 0.3
	var nm := MeshInstance3D.new()
	nm.mesh = snout
	nm.material_override = _fat_mat
	nm.position = Vector3(1.18, -0.02, 0.0)
	nm.rotation.z = -PI * 0.5
	turn.add_child(nm)
	for k in 4:
		var leg := CylinderMesh.new()
		leg.top_radius = 0.07
		leg.bottom_radius = 0.045
		leg.height = 0.5
		leg.radial_segments = 6
		var gm := MeshInstance3D.new()
		gm.mesh = leg
		gm.material_override = _fat_mat
		var front := 1.0 if k < 2 else -1.0
		var side := 1.0 if k % 2 == 0 else -1.0
		gm.position = Vector3(front * 0.5 + front * 0.22, -0.32, side * 0.22)
		gm.rotation.z = front * 1.2
		turn.add_child(gm)
	var tw := turn.create_tween().set_loops()
	tw.tween_property(turn, "rotation:x", TAU, 9.0).from(0.0)
	d._blocker(room, Vector3(2.8, 2.0, 1.4), at + Vector3(0.0, 1.0, 0.0))


## An iron cage on the floor, what is left of a prisoner slumped in it.
static func _cage(d: Dungeon, room: Node3D, at: Vector3, rng: RandomNumberGenerator) -> void:
	var holder := Node3D.new()
	holder.position = at
	holder.rotation.y = rng.randf_range(0.0, TAU)
	room.add_child(holder)
	_cage_body(d, holder, 1.1, 2.4)
	d._bones(holder, Vector3(0.1, 0.0, 0.1))
	_skull(d, holder, Vector3(-0.3, 0.14, 0.25))
	d._blocker(room, Vector3(2.3, 2.6, 2.3), at + Vector3(0.0, 1.3, 0.0))


## Bars round in a ring, a ring at the foot and at the top, a dome of bars.
static func _cage_body(d: Dungeon, holder: Node3D, radius: float, tall: float) -> void:
	for y: float in [0.06, tall]:
		var ring := TorusMesh.new()
		ring.inner_radius = radius - 0.05
		ring.outer_radius = radius + 0.05
		ring.rings = 18
		ring.ring_segments = 6
		var rm := MeshInstance3D.new()
		rm.mesh = ring
		rm.material_override = d._iron_mat
		rm.position = Vector3(0.0, y, 0.0)
		holder.add_child(rm)
	var n := 12
	for k in n:
		var a := TAU * float(k) / float(n)
		var bar := CylinderMesh.new()
		bar.top_radius = 0.025
		bar.bottom_radius = 0.025
		bar.height = tall
		bar.radial_segments = 5
		var bm := MeshInstance3D.new()
		bm.mesh = bar
		bm.material_override = d._iron_mat
		bm.position = Vector3(sin(a) * radius, tall * 0.5, cos(a) * radius)
		holder.add_child(bm)
	for k in 2:
		var arch := TorusMesh.new()
		arch.inner_radius = radius - 0.04
		arch.outer_radius = radius + 0.04
		arch.rings = 16
		arch.ring_segments = 5
		var am := MeshInstance3D.new()
		am.mesh = arch
		am.material_override = d._iron_mat
		am.position = Vector3(0.0, tall, 0.0)
		am.rotation = Vector3(PI * 0.5, float(k) * PI * 0.5, 0.0)
		am.scale = Vector3(1.0, 1.0, 0.6)
		holder.add_child(am)


## A cage hanging on a chain from the roof, swaying a little, bones in it.
static func _hanging_cage(d: Dungeon, room: Node3D, at: Vector3, top: float, drop: float) -> void:
	var swing := Node3D.new()
	swing.position = Vector3(at.x, top, at.z)
	room.add_child(swing)
	var chain := CylinderMesh.new()
	chain.top_radius = 0.035
	chain.bottom_radius = 0.035
	chain.height = drop
	var cm := MeshInstance3D.new()
	cm.mesh = chain
	cm.material_override = d._iron_mat
	cm.position = Vector3(0.0, -drop * 0.5, 0.0)
	swing.add_child(cm)
	var holder := Node3D.new()
	holder.position = Vector3(0.0, -drop - 2.0, 0.0)
	swing.add_child(holder)
	_cage_body(d, holder, 0.7, 2.0)
	d._bones(holder, Vector3(0.0, 0.05, 0.0))
	_skull(d, holder, Vector3(0.15, 0.16, -0.1))
	var tw := swing.create_tween().set_loops()
	tw.tween_property(swing, "rotation:z", 0.035, 2.6).from(-0.035).set_trans(Tween.TRANS_SINE)
	tw.tween_property(swing, "rotation:z", -0.035, 2.6).set_trans(Tween.TRANS_SINE)
	d._creaks.append(room.position + Vector3(at.x, top - drop, at.z))


## Gibbets on the terrace: cages hung out over the drop from poles.
static func _gibbets(d: Dungeon, room: Node3D, w: float, l: float) -> void:
	for k in 3:
		var z := l * 0.3 - float(k) * l * 0.3
		var x := w * 0.5 - 1.2
		var pole := CylinderMesh.new()
		pole.top_radius = 0.1
		pole.bottom_radius = 0.13
		pole.height = 7.0
		pole.radial_segments = 6
		d._deco(room, d._wood_mat, pole, Vector3(x, 3.5, z))
		var arm := CylinderMesh.new()
		arm.top_radius = 0.08
		arm.bottom_radius = 0.08
		arm.height = 3.2
		arm.radial_segments = 6
		var am := d._deco(room, d._wood_mat, arm, Vector3(x + 1.5, 6.8, z))
		am.rotation.z = PI * 0.5
		d._blocker(room, Vector3(0.5, 7.0, 0.5), Vector3(x, 3.5, z))
		_hanging_cage(d, room, Vector3(x + 2.9, 0.0, z), 6.8, 1.0)


## A barricade of sharpened stakes on crossed frames, `n` frames long.
static func _barricade(d: Dungeon, room: Node3D, at: Vector3, yaw: float, n: int, rng: RandomNumberGenerator,
		gap: float = 0.0) -> void:
	var holder := Node3D.new()
	holder.position = at
	holder.rotation.y = yaw
	room.add_child(holder)
	var long := float(n) * 1.6
	for k in n:
		var x := -long * 0.5 + (float(k) + 0.5) * 1.6
		if gap > 0.0 and absf(x) < gap * 0.5:
			continue
		for lean: float in [-1.0, 1.0]:
			var stake := CylinderMesh.new()
			stake.top_radius = 0.0
			stake.bottom_radius = 0.08
			stake.height = 2.3
			stake.radial_segments = 5
			var sm := MeshInstance3D.new()
			sm.mesh = stake
			sm.material_override = d._wood_mat
			sm.position = Vector3(x, 0.75, 0.0)
			sm.rotation = Vector3(lean * 0.7, 0.0, rng.randf_range(-0.1, 0.1))
			holder.add_child(sm)
	var beam := CylinderMesh.new()
	beam.top_radius = 0.08
	beam.bottom_radius = 0.08
	beam.height = long
	beam.radial_segments = 6
	var bm := MeshInstance3D.new()
	bm.mesh = beam
	bm.material_override = d._wood_mat
	bm.position = Vector3(0.0, 0.75, 0.0)
	bm.rotation.z = PI * 0.5
	holder.add_child(bm)
	var shape_at := at
	var across := Vector3(cos(yaw), 0.0, -sin(yaw))
	if gap > 0.0:
		for side: float in [-1.0, 1.0]:
			var piece := (long - gap) * 0.5
			var mid := shape_at + across * side * (gap * 0.5 + piece * 0.5)
			var b := d._blocker(room, Vector3(piece, 1.6, 1.2), mid + Vector3(0.0, 0.8, 0.0))
			b.rotation.y = yaw
	else:
		var b := d._blocker(room, Vector3(long, 1.6, 1.2), at + Vector3(0.0, 0.8, 0.0))
		b.rotation.y = yaw


## The palace's goods heaped up as loot: barrels, crates, a broken chest.
static func _loot(d: Dungeon, room: Node3D, at: Vector3, rng: RandomNumberGenerator) -> void:
	for name: String in ["Barrels", "Crates"]:
		var mesh := _kit_mesh(name)
		if mesh == null:
			continue
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.position = at + Vector3(rng.randf_range(-1.4, 1.4), 0.0, rng.randf_range(-1.4, 1.4))
		mi.rotation.y = rng.randf_range(0.0, TAU)
		room.add_child(mi)
	d._blocker(room, Vector3(3.0, 1.6, 3.0), at + Vector3(0.0, 0.8, 0.0))
	# a gold cup or two spilt on the floor
	for k in 3:
		var cup := CylinderMesh.new()
		cup.top_radius = 0.09
		cup.bottom_radius = 0.05
		cup.height = 0.18
		cup.radial_segments = 8
		var m := d._deco(room, d._gold_mat, cup, at + Vector3(rng.randf_range(-2.2, 2.2), 0.06, rng.randf_range(-2.2, 2.2)))
		m.rotation = Vector3(PI * 0.5, rng.randf_range(0.0, TAU), 0.0)


## A heap of bones, skulls on it.
static func _bone_heap(d: Dungeon, room: Node3D, at: Vector3, rng: RandomNumberGenerator) -> void:
	for k in 4:
		d._bones(room, at + Vector3(rng.randf_range(-0.8, 0.8), 0.0, rng.randf_range(-0.8, 0.8)))
	for k in 3:
		_skull(d, room, at + Vector3(rng.randf_range(-0.7, 0.7), 0.15 + float(k) * 0.08, rng.randf_range(-0.7, 0.7)))


## Old blood on the floor in `n` places, off the aisle.
static func _blood(d: Dungeon, room: Node3D, w: float, l: float, n: int, rng: RandomNumberGenerator) -> void:
	for k in n:
		var x := rng.randf_range(-w * 0.42, w * 0.42)
		if absf(x) < 2.0:
			x = 3.0 * signf(x + 0.01)
		var decal := Decal.new()
		decal.texture_albedo = _blood_tex
		var s := rng.randf_range(1.4, 3.2)
		decal.size = Vector3(s, 0.6, s)
		decal.position = Vector3(x, 0.05, rng.randf_range(-l * 0.42, l * 0.42))
		decal.rotation.y = rng.randf_range(0.0, TAU)
		decal.upper_fade = 0.3
		decal.lower_fade = 0.3
		room.add_child(decal)


## A rack of the orcs' axes and spears: a rough frame, the arms leaning on it.
static func _rack(d: Dungeon, room: Node3D, at: Vector3, yaw: float) -> void:
	var holder := Node3D.new()
	holder.position = at
	holder.rotation.y = yaw
	room.add_child(holder)
	for y: float in [0.25, 1.25]:
		var bar := BoxMesh.new()
		bar.size = Vector3(2.6, 0.1, 0.12)
		var bm := MeshInstance3D.new()
		bm.mesh = bar
		bm.material_override = d._wood_mat
		bm.position = Vector3(0.0, y, -0.3)
		holder.add_child(bm)
	for side: float in [-1.0, 1.0]:
		var leg := BoxMesh.new()
		leg.size = Vector3(0.12, 1.5, 0.12)
		var lm := MeshInstance3D.new()
		lm.mesh = leg
		lm.material_override = d._wood_mat
		lm.position = Vector3(side * 1.25, 0.75, -0.3)
		holder.add_child(lm)
	# axes and spears leaning back on the top bar: an iron head on a haft
	for k in 5:
		var arm := Node3D.new()
		arm.position = Vector3(-1.0 + float(k) * 0.5, 0.0, 0.0)
		arm.rotation = Vector3(-0.22, 0.0, (float(k) - 2.0) * 0.04)
		holder.add_child(arm)
		var spear := k % 2 == 1
		var long := 2.1 if spear else 1.5
		var haft := CylinderMesh.new()
		haft.top_radius = 0.03
		haft.bottom_radius = 0.035
		haft.height = long
		haft.radial_segments = 5
		var hm := MeshInstance3D.new()
		hm.mesh = haft
		hm.material_override = d._wood_mat
		hm.position = Vector3(0.0, long * 0.5, 0.0)
		arm.add_child(hm)
		var head: Mesh
		if spear:
			var tip := CylinderMesh.new()
			tip.top_radius = 0.0
			tip.bottom_radius = 0.06
			tip.height = 0.38
			tip.radial_segments = 4
			head = tip
		else:
			var blade := PrismMesh.new()
			blade.size = Vector3(0.42, 0.34, 0.03)
			blade.left_to_right = 0.0
			head = blade
		var em := MeshInstance3D.new()
		em.mesh = head
		em.material_override = d._iron_mat
		em.position = Vector3(0.0 if spear else 0.2, long + (0.17 if spear else -0.18), 0.0)
		em.rotation.z = 0.0 if spear else -PI * 0.5
		arm.add_child(em)
	d._blocker(room, Vector3(2.8, 1.5, 0.8), at + Vector3(0.0, 0.75, 0.0))


## A small fire on the floor the orcs sit round: stones, a pot over it.
static func _campfire(d: Dungeon, room: Node3D, at: Vector3, rng: RandomNumberGenerator) -> void:
	var holder := Node3D.new()
	holder.position = at
	room.add_child(holder)
	for k in 8:
		var a := TAU * float(k) / 8.0
		var stone := SphereMesh.new()
		stone.radius = 0.2
		stone.height = 0.28
		stone.radial_segments = 7
		stone.rings = 4
		var sm := MeshInstance3D.new()
		sm.mesh = stone
		sm.material_override = d._trim_mat
		sm.position = Vector3(sin(a) * 0.75, 0.08, cos(a) * 0.75)
		sm.scale = Vector3(1.0, 0.8, 1.0) * rng.randf_range(0.8, 1.2)
		holder.add_child(sm)
	holder.add_child(d._flame(Vector3(0.0, 0.05, 0.0), 1.3, 18))
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.56, 0.26)
	light.light_energy = 1.8
	light.omni_range = 8.0
	light.position = Vector3(0.0, 1.0, 0.0)
	holder.add_child(d._fire_light(light))
	# a black pot on three sticks over it
	for k in 3:
		var a := TAU * float(k) / 3.0
		var stick := CylinderMesh.new()
		stick.top_radius = 0.03
		stick.bottom_radius = 0.04
		stick.height = 1.7
		stick.radial_segments = 5
		var st := MeshInstance3D.new()
		st.mesh = stick
		st.material_override = d._wood_mat
		st.position = Vector3(sin(a) * 0.45, 0.78, cos(a) * 0.45)
		st.rotation = Vector3(cos(a) * 0.28, 0.0, -sin(a) * 0.28)
		holder.add_child(st)
	var pot := SphereMesh.new()
	pot.radius = 0.3
	pot.height = 0.5
	var pm := MeshInstance3D.new()
	pm.mesh = pot
	pm.material_override = d._iron_mat
	pm.position = Vector3(0.0, 0.95, 0.0)
	holder.add_child(pm)
	d._blocker(room, Vector3(1.6, 1.0, 1.6), at + Vector3(0.0, 0.5, 0.0))
