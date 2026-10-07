class_name HealNumber
extends Label3D

## Health given back (the elf's Moonwell, [method Player.heal]): a green "+12"
## rising off the hero's head and fading, and a few pale green motes rising
## round him.

const GREEN := Color(0.45, 1.0, 0.55)
const RISE := 0.9
const LIFE := 1.1

var _age: float = 0.0
var _from := Vector3.ZERO


static func pop(who: Node3D, amount: float) -> void:
	if who == null or not who.is_inside_tree():
		return
	var into := Blood.world_of(who)
	if into == null:
		return
	var n := HealNumber.new()
	n.text = "+%d" % roundi(amount)
	n.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	n.no_depth_test = true
	n.fixed_size = true
	n.pixel_size = 0.0011
	n.font_size = 30
	n.outline_size = 9
	n.modulate = GREEN
	n.outline_modulate = Color(0.02, 0.12, 0.04, 0.9)
	var font := UiArt.font("bold")
	if font != null:
		n.font = font
	into.add_child(n)
	n._from = who.global_position + Vector3.UP * 2.05 + Vector3(randf_range(-0.25, 0.25), 0.0, randf_range(-0.25, 0.25))
	n.global_position = n._from
	SkillFx.particles(into, who.global_position + Vector3.UP * 0.9, {"amount": 8, "life": 0.9, "one_shot": true,
			"explosiveness": 0.6, "speed": Vector2(0.4, 0.9), "dir": Vector3.UP, "spread": 25.0,
			"size": Vector2(0.025, 0.05), "box": Vector3(0.35, 0.7, 0.35),
			"colors": [Color(GREEN, 0.0), Color(0.8, 1.0, 0.85, 1.0), Color(GREEN, 0.0)]})


func _process(delta: float) -> void:
	_age += delta
	var k := _age / LIFE
	global_position = _from + Vector3.UP * RISE * (1.0 - pow(1.0 - minf(k, 1.0), 2.0))
	modulate.a = 1.0 - smoothstep(0.55, 1.0, k)
	outline_modulate.a = modulate.a * 0.9
	if k >= 1.0:
		queue_free()
