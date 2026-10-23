class_name ForestGlade
extends Object

## The forest as the user chose it (2026-10-23, concept "tye1"): an old oak
## wood round a wide mossy glade with patches of mud, giant oaks with buttress
## roots standing round it like a wall, a darker wood behind them, small
## ruined stone gates with steps at the far end and the sides, mossy boulders
## and big ferns at the trees' feet, beams of sun through the leaves, a light
## mist low on the ground. Nothing stands in the glade itself: the creatures
## see the hero from anywhere in it and have nothing to go behind.
##
## The oaks and the gates are `assets/dungeon/forest_glade/forest_glade.glb`
## from `vepxis-art/world/forest_glade.py` (Blender, background).

const KIT := "res://assets/dungeon/forest_glade/forest_glade.glb"
const OAKS := ["Oak0", "Oak1", "Oak2", "Oak3"]

const BEAM := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 tint : source_color = vec4(1.0, 0.86, 0.55, 1.0);
uniform float strength = 0.16;
uniform float seed = 0.0;
void fragment() {
	float across = 1.0 - abs(UV.x - 0.5) * 2.0;
	float along = smoothstep(0.0, 0.25, UV.y) * smoothstep(1.0, 0.55, UV.y);
	float pulse = 0.75 + 0.25 * sin(TIME * 0.4 + seed);
	// fade where it would cut the eye
	float near = smoothstep(2.0, 10.0, length(VERTEX));
	ALBEDO = tint.rgb;
	ALPHA = pow(across, 1.6) * along * strength * pulse * near;
}
"""

static var _kit: Node3D


## Builds the glade into `room`, `w` by `l` metres.
static func build(d: Dungeon, room: Node3D, w: float, l: float, rng: RandomNumberGenerator) -> void:
	if _kit == null or not is_instance_valid(_kit):
		_kit = (load(KIT) as PackedScene).instantiate() as Node3D
	var grow := 1.0
	match Graphics.current:
		Graphics.Level.LOW:
			grow = 0.5
		Graphics.Level.MEDIUM:
			grow = 0.75
		Graphics.Level.ULTRA:
			grow = 1.5
	# the ground: moss and grass, earth and mud in patches
	var ground := d._ground_mat()
	ground.set_shader_parameter("grass_a", Color(0.16, 0.25, 0.06))
	ground.set_shader_parameter("grass_b", Color(0.25, 0.34, 0.08))
	ground.set_shader_parameter("earth", Color(0.24, 0.15, 0.08))
	ground.set_shader_parameter("moss", Color(0.15, 0.24, 0.05))
	ground.set_shader_parameter("leaves", Color(0.26, 0.20, 0.09))
	ground.set_shader_parameter("bare_from", 0.42)
	ground.set_shader_parameter("mud", 1.0)
	d._solid(room, ground, Vector3(w + 110.0, 1.0, l + 110.0), Vector3(0.0, -0.5, 0.0))
	d._bounds(room, w, l)
	# the giant oaks round the glade, close, then a second row behind
	for row in 2:
		var out := 4.0 + float(row) * 10.0
		var step := 9.5 + float(row) * 2.0
		for side in 4:
			var long := (l if side < 2 else w) + out * 2.0
			var n := int(long / step)
			for k in n:
				var along := -long * 0.5 + (float(k) + rng.randf_range(0.25, 0.75)) * step
				var at := Vector3.ZERO
				match side:
					0: at = Vector3(-w * 0.5 - out, 0.0, along)
					1: at = Vector3(w * 0.5 + out, 0.0, along)
					2: at = Vector3(along, 0.0, -l * 0.5 - out)
					_: at = Vector3(along, 0.0, l * 0.5 + out)
				# the way in at the near end kept open a little
				if side == 3 and absf(at.x) < 7.0 and row == 0:
					continue
				at += Vector3(rng.randf_range(-1.8, 1.8), 0.0, rng.randf_range(-1.8, 1.8))
				var s := rng.randf_range(1.3, 1.7) + float(row) * 0.2
				_oak(room, OAKS[rng.randi_range(0, OAKS.size() - 1)], at, rng.randf_range(0.0, TAU), s)
	# a dark wood behind, the kit's own trees, big
	for k in int(70.0 * grow):
		var a := rng.randf_range(0.0, TAU)
		var dist := rng.randf_range(1.0, 1.35)
		var at2 := Vector3(sin(a) * (w * 0.5 + 30.0) * dist, 0.0, cos(a) * (l * 0.5 + 30.0) * dist)
		d._nature(room, ("CommonTree_%d" if k % 3 else "Pine_%d") % (1 + k % 5), at2, rng.randf_range(2.6, 3.6),
				rng.randf_range(0.0, TAU), false)
	# the ruined gates: the far end, and one either side
	_gate(room, "Gate0", Vector3(0.0, 0.0, -l * 0.5 + 1.5), 0.0)
	_gate(room, "Gate0", Vector3(w * 0.5 - 2.5, 0.0, -l * 0.18), -PI * 0.5 - 0.25)
	_gate(room, "Gate1", Vector3(-w * 0.5 + 2.5, 0.0, -l * 0.25), PI * 0.5 + 0.2)
	# mossy boulders and big ferns along the edge, the glade's middle left open
	for k in int(18.0 * grow):
		d._nature(room, "Rock_Medium_%d" % (1 + k % 3), _edge(w, l, rng, 1.5, 4.0), rng.randf_range(0.9, 1.8),
				rng.randf_range(0.0, TAU), true)
	for k in int(90.0 * grow):
		d._nature(room, ["Fern_1", "Fern_1", "Bush_Common", "Plant_1_Big"][k % 4], _edge(w, l, rng, 0.0, 6.0),
				rng.randf_range(1.4, 2.4), rng.randf_range(0.0, TAU), false)
	_beams(room, w, l, rng)


## A point on the glade's rim band, `inner`..`outer` metres in from its edge.
static func _edge(w: float, l: float, rng: RandomNumberGenerator, inner: float, outer: float) -> Vector3:
	var side := rng.randi_range(0, 3)
	var t := rng.randf_range(-0.5, 0.5)
	var inset := rng.randf_range(inner, outer)
	match side:
		0:
			return Vector3(-w * 0.5 + inset, 0.0, t * l)
		1:
			return Vector3(w * 0.5 - inset, 0.0, t * l)
		2:
			return Vector3(t * w, 0.0, -l * 0.5 + inset)
	return Vector3(t * w * 0.8, 0.0, l * 0.5 - inset)


static func _oak(room: Node3D, piece: String, at: Vector3, yaw: float, s: float) -> void:
	var src := _kit.get_node_or_null(piece) as Node3D
	if src == null:
		return
	var n := src.duplicate() as Node3D
	n.transform = Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * s), at)
	room.add_child(n)
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var c := CylinderShape3D.new()
	c.radius = 2.4
	c.height = 12.0
	shape.shape = c
	shape.position.y = 6.0
	body.add_child(shape)
	n.add_child(body)


static func _gate(room: Node3D, piece: String, at: Vector3, yaw: float, s: float = 1.35) -> void:
	var src := _kit.get_node_or_null(piece) as Node3D
	if src == null:
		return
	var n := src.duplicate() as Node3D
	n.transform = Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * s), at)
	room.add_child(n)
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(5.2, 6.0, 4.0)
	shape.shape = b
	shape.position = Vector3(0.0, 3.0, -1.0)
	body.add_child(shape)
	n.add_child(body)


## Beams of sun slanting down through the leaves into the glade.
static func _beams(room: Node3D, w: float, l: float, rng: RandomNumberGenerator) -> void:
	var sh := Shader.new()
	sh.code = BEAM
	for k in 11:
		var m := ShaderMaterial.new()
		m.shader = sh
		m.set_shader_parameter("seed", float(k) * 1.7)
		m.set_shader_parameter("strength", rng.randf_range(0.08, 0.16))
		var width := rng.randf_range(2.5, 5.5)
		var length := 34.0
		var foot := Vector3(rng.randf_range(-w * 0.42, w * 0.42), 0.0, rng.randf_range(-l * 0.42, l * 0.3))
		# all leaning the one way, from the sun's side
		var tilt := Basis(Vector3.RIGHT, deg_to_rad(28.0)).rotated(Vector3.UP, deg_to_rad(-35.0))
		var holder := Node3D.new()
		holder.transform = Transform3D(tilt, foot)
		room.add_child(holder)
		for q in 2:
			var quad := MeshInstance3D.new()
			var qm := QuadMesh.new()
			qm.size = Vector2(width, length)
			quad.mesh = qm
			quad.material_override = m
			quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			quad.position = Vector3(0.0, length * 0.5, 0.0)
			quad.rotation.y = float(q) * PI * 0.5
			holder.add_child(quad)
