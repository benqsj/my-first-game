class_name Poise
extends Node

## An elite's or a boss's balance (the user's word, 2026-10-28: the
## director's plan, as in Sekiro): every blow it takes, every blow of its
## caught on his shield and every one he rolls through at the last moment
## shakes it; let be, it steadies. Shaken through, it reels open
## ([method Fighter.react] "stun": a riposte bites half as deep again) and its
## balance is whole again. A yellow bar under its health shows it, going red
## as it nears breaking.
##
## Not on a creature with a stance of its own ([member PackBrute.stance]: the
## orcs, the ogre). Put on by [CombatDirector]; the balance is the host's, the
## bar every peer's (from the host's count, [method net_poise]).

const MAX := 100.0
## What fills it: its life lost (per share of its whole), a blow caught on
## his shield, one he rolled through at the last moment.
const PER_LIFE := 260.0
const BLOCKED := 18.0
const DODGED := 30.0
## Let be this long, it steadies this fast.
const STEADY_AFTER := 2.0
const STEADY := 9.0

var poise := 0.0
var _body: Fighter
var _quiet := 0.0
var _last_health := -1.0
var _bar: Node3D
var _fill: MeshInstance3D
var _fill_mat: StandardMaterial3D


static func give(body: Fighter) -> Poise:
	if body == null or body.has_node(^"Poise"):
		return null
	var s: Variant = body.get(&"stance")
	if s is float and float(s) > 0.0:
		return null
	var p := Poise.new()
	p.name = "Poise"
	p._body = body
	body.add_child(p)
	return p


func _ready() -> void:
	_make_bar()


## Host: shaken by `amount`.
func shake(amount: float, by: Node3D = null) -> void:
	if not is_instance_valid(_body) or _body.is_dead:
		return
	_quiet = 0.0
	poise = minf(poise + amount, MAX)
	if poise >= MAX:
		poise = 0.0
		_body.react(&"stun", by)
		ImpactFx.thud(_body, _body.global_position + Vector3.UP * 1.2, true)
	_tell()


func _process(delta: float) -> void:
	if not is_instance_valid(_body):
		return
	if _body.is_dead:
		if _bar != null:
			_bar.visible = false
		return
	if _body.multiplayer.has_multiplayer_peer() and not _body.is_multiplayer_authority():
		_draw()
		return
	var h := _body.health
	if _last_health >= 0.0 and h < _last_health - 0.01:
		shake((_last_health - h) / maxf(_body.max_health, 1.0) * PER_LIFE)
	_last_health = h
	_quiet += delta
	if _quiet >= STEADY_AFTER and poise > 0.0:
		poise = maxf(poise - STEADY * delta, 0.0)
		_tell_slowly(delta)
	_draw()


var _told := 0.0


func _tell_slowly(delta: float) -> void:
	_told += delta
	if _told >= 0.5:
		_told = 0.0
		_tell()


func _tell() -> void:
	if _body.is_inside_tree() and _body.multiplayer.has_multiplayer_peer():
		net_poise.rpc(poise)


@rpc("authority", "call_remote", "unreliable")
func net_poise(value: float) -> void:
	poise = value


#region The bar
func _make_bar() -> void:
	_bar = Node3D.new()
	_bar.name = "PoiseBar"
	_body.add_child(_bar)
	var s := maxf(_body.visual_scale, 0.01)
	_bar.position = Vector3.UP * (_body.bar_height * s - 0.2)
	var back := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 0.07)
	back.mesh = quad
	var bm := StandardMaterial3D.new()
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.albedo_color = Color(0.0, 0.0, 0.0, 0.55)
	bm.no_depth_test = true
	back.material_override = bm
	back.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_bar.add_child(back)
	_fill = MeshInstance3D.new()
	var fq := QuadMesh.new()
	fq.size = Vector2(1.0, 0.05)
	_fill.mesh = fq
	_fill_mat = StandardMaterial3D.new()
	_fill_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_fill_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_fill_mat.billboard_keep_scale = true
	_fill_mat.no_depth_test = true
	_fill_mat.render_priority = 1
	_fill.material_override = _fill_mat
	_fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_bar.add_child(_fill)


func _draw() -> void:
	if _bar == null:
		return
	var t := poise / MAX
	_bar.visible = t > 0.01
	# grows from the middle out, both ways
	_fill.scale = Vector3(maxf(t, 0.001), 1.0, 1.0)
	_fill_mat.albedo_color = Color(1.0, 0.85, 0.25).lerp(Color(1.0, 0.2, 0.1), clampf((t - 0.6) / 0.4, 0.0, 1.0))
#endregion
