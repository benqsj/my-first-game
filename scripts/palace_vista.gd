class_name PalaceVista
extends Node3D

## What is seen from the palace's open rooms (the user's word, 2026-10-20:
## the mountains of the v5 world): the v5 lands themselves, read from their
## height and tint maps (`assets/world/v5/`) and built once into one coarse
## mesh far below and round the palace, which stands on a crag of its own in
## the middle of them. The mountains ringing the v5 lands rise round the
## horizon; the sea lies in the low ground.
##
## Seen, not walked: no collision, no shadows; the fog does the distance.

const DIR := "res://assets/world/v5/"
## One vertex every `STEP` cells (cells are 2 m).
const STEP := 6
## How far below the palace's floor the lands' sea level lies.
const DROP := 140.0
## Snow from here up (the lands' own metres, before the drop).
const SNOW := 290.0

const GROUND_SHADER := """
shader_type spatial;
render_mode cull_back;
uniform vec4 rock : source_color = vec4(0.30, 0.27, 0.30, 1.0);
uniform vec4 snow : source_color = vec4(0.86, 0.84, 0.95, 1.0);
uniform float snow_from = 250.0;
uniform float base = -230.0;
varying vec3 wpos;
varying vec3 wnorm;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
void fragment() {
	float up = wnorm.y;
	float h = wpos.y - base;
	float n = noise(wpos.xz * 0.02) * 0.6 + noise(wpos.xz * 0.11) * 0.4;
	vec3 c = COLOR.rgb;
	// Steep ground is bare rock, striped a little.
	float steep = smoothstep(0.82, 0.6, up);
	vec3 r = rock.rgb * (0.75 + 0.45 * noise(vec2(wpos.y * 0.15, wpos.x * 0.01)));
	c = mix(c, r, steep);
	// Snow on the heights, thinning on the steep.
	float s = smoothstep(snow_from - 30.0, snow_from + 20.0, h + n * 40.0) * smoothstep(0.45, 0.75, up);
	c = mix(c, snow.rgb, s);
	ALBEDO = c;
	ROUGHNESS = mix(0.95, 0.6, s);
}
"""


func _ready() -> void:
	_build_lands()
	_build_sea()


func _read(file: String, size: int) -> PackedByteArray:
	var raw := FileAccess.get_file_as_bytes(DIR + file)
	if raw.is_empty():
		return PackedByteArray()
	return raw.decompress(size, FileAccess.COMPRESSION_GZIP)


func _build_lands() -> void:
	var info_text := FileAccess.get_file_as_string(DIR + "lands.json")
	var info: Variant = JSON.parse_string(info_text)
	if not info is Dictionary:
		push_warning("PalaceVista: no v5 lands.json")
		return
	var nx := int(info["nx"])
	var nz := int(info["nz"])
	var cell := float(info["cell"])
	var x0 := float(info["x0"])
	var z0 := float(info["z0"])
	var heights := _read("height.f32.gz", nx * nz * 4).to_float32_array()
	var tint := _read("tint.rgba8.gz", nx * nz * 4)
	if heights.size() != nx * nz:
		push_warning("PalaceVista: v5 heights missing")
		return
	var gx := int(float(nx - 1) / float(STEP)) + 1
	var gz := int(float(nz - 1) / float(STEP)) + 1
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	verts.resize(gx * gz)
	cols.resize(gx * gz)
	for j in gz:
		var iz := mini(j * STEP, nz - 1)
		for i in gx:
			var ix := mini(i * STEP, nx - 1)
			var k := iz * nx + ix
			var h := heights[k]
			verts[j * gx + i] = Vector3(x0 + float(ix) * cell, h - DROP, z0 + float(iz) * cell)
			if tint.size() == nx * nz * 4:
				cols[j * gx + i] = Color8(tint[k * 4], tint[k * 4 + 1], tint[k * 4 + 2])
			else:
				cols[j * gx + i] = Color(0.3, 0.36, 0.22)
	var norms := PackedVector3Array()
	norms.resize(gx * gz)
	for j in gz:
		for i in gx:
			var l := verts[j * gx + maxi(i - 1, 0)]
			var r := verts[j * gx + mini(i + 1, gx - 1)]
			var d := verts[maxi(j - 1, 0) * gx + i]
			var u := verts[mini(j + 1, gz - 1) * gx + i]
			norms[j * gx + i] = (u - d).cross(r - l).normalized()
	var idx := PackedInt32Array()
	idx.resize((gx - 1) * (gz - 1) * 6)
	var n := 0
	for j in gz - 1:
		for i in gx - 1:
			var a := j * gx + i
			var b := a + 1
			var c := a + gx
			var d := c + 1
			idx[n] = a
			idx[n + 1] = b
			idx[n + 2] = c
			idx[n + 3] = b
			idx[n + 4] = d
			idx[n + 5] = c
			n += 6
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mat := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = GROUND_SHADER
	mat.shader = shader
	mat.set_shader_parameter("snow_from", SNOW)
	mat.set_shader_parameter("base", -DROP)
	var lands := MeshInstance3D.new()
	lands.name = "Lands"
	lands.mesh = mesh
	lands.material_override = mat
	lands.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lands.extra_cull_margin = 500.0
	add_child(lands)


func _build_sea() -> void:
	var sea := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(9000.0, 9000.0)
	sea.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.09, 0.2, 0.3)
	mat.metallic = 0.4
	mat.roughness = 0.12
	sea.material_override = mat
	sea.position = Vector3(0.0, -DROP + 0.3, 0.0)
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sea)

