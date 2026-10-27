class_name TreasureGoblin
extends Node

## Now and then a goblin with a sack of gold in a place of the orc portal (the
## user's word, 2026-10-21: surprises, a reason to look round): it comes out
## of the far end a moment after the place wakes, glittering, and does not
## fight — it runs from him, round and round the place, for [constant
## STAYS] seconds, and then it is gone through a crack in the air with all
## it has. Caught, it bursts with gold: tusks, coins, a thing for the bag.
##
## Made by [Dungeon] with the place (out of sight, so nothing is read in when
## it comes: [method make]), let out as it wakes ([method release]). Not one
## of the place's creatures: the place clears without it.

const SCENE := "res://scenes/enemies/pack/goblin.tscn"
const CHANCE := 0.3
const STAYS := 20.0
const TUSKS := 10
const GOLD := 6
const NAME := "ოქროიანი გობლინი"

var body: GoblinFighter
var _d: Dungeon
var _i: int = -1
var _left: float = -1.0
var _gone: bool = false
var caught: bool = false
static var _gold_rim: ShaderMaterial


## A treasure goblin for place `i` of `d`, out of sight; null if none could be made.
static func make(d: Dungeon, i: int) -> TreasureGoblin:
	var scene := d._foe_scene(SCENE)
	var creatures := d._creatures_node()
	if scene == null or creatures == null:
		return null
	var g := scene.instantiate() as GoblinFighter
	if g == null:
		return null
	var c := d.centre(i)
	var r := d._room(i)
	g.name = "D%d_Treasure" % d.id
	g.max_health = 260.0
	g.health = 260.0
	g.flee_speed = 5.3
	g.bold = false
	g.set_meta(&"treasure", true)
	g.set_meta(&"title", NAME)
	g.set_meta(&"level", int(r["lv"]))
	g.set("band", StringName("dungeon_%d_treasure" % d.id))
	g.set("camp_centre", Vector3(c.x, c.y, c.z))
	g.position = c + Vector3(-6.0, -40.0, 0.0)
	g.visible = false
	g.process_mode = Node.PROCESS_MODE_DISABLED
	creatures.add_child(g)
	var t := TreasureGoblin.new()
	t.name = "Treasure"
	t.body = g
	t._d = d
	t._i = i
	g.add_child(t)
	d._watch_foe(g)
	g.died.connect(t._on_caught)
	return t


## Out it comes, at the place's far end, running.
func release() -> void:
	if body == null or not is_instance_valid(body) or _left >= 0.0:
		return
	var c := _d.centre(_i)
	var r := _d._room(_i)
	var l: float = r["l"]
	var w: float = r["w"]
	var at := c + Vector3((w * 0.3) * (1.0 if randf() < 0.5 else -1.0), 0.3, -l * 0.35)
	body.global_position = at
	body.set(&"_home", c)
	body.leash_radius = maxf(w, l) * 0.6
	body.visible = true
	body.process_mode = Node.PROCESS_MODE_INHERIT
	var hero := _d._nearest_hero(at)
	if hero != null:
		body.call_deferred("_rouse", hero)
	_left = STAYS
	_glitter()
	_d._say("%s! — დაიჭირე!" % NAME, 3.0)
	Sfx.play(_d, Dungeon.SND + "portal_whoosh.wav", null, at + Vector3.UP, 1.4, -2.0)


func _physics_process(delta: float) -> void:
	if _left < 0.0 or _gone or caught or not is_instance_valid(body) or body.is_dead:
		return
	# it never stops running, never throws, never calls the others
	body._called = true
	body._feared = false
	body._flee_left = 1.0
	body._throw_wait = 1.0
	_left -= delta
	if _left <= 0.0:
		_escape()


## Time up: a crack in the air, and it is gone with it all.
func _escape() -> void:
	_gone = true
	var at := body.global_position + Vector3.UP
	var world := Blood.world_of(_d)
	if world != null:
		SkillFx.burst(world, at, Color(1.0, 0.85, 0.3), 60, Vector2(2.0, 6.0), Vector3.UP, 180.0,
				Vector2(0.05, 0.14), Vector3(0, 1.0, 0), 0.9)
	Sfx.play(_d, Dungeon.SND + "portal_whoosh.wav", null, at, 1.6, -2.0)
	_d._say("გობლინი გაიქცა ოქროთი...", 3.0)
	body.queue_free()


## Caught: it bursts with gold.
func _on_caught() -> void:
	if caught or _gone:
		return
	caught = true
	var at := body.global_position
	var world := Blood.world_of(_d)
	if world != null:
		SkillFx.burst(world, at + Vector3.UP, Color(1.0, 0.82, 0.25), 120, Vector2(3.0, 9.0), Vector3.UP, 170.0,
				Vector2(0.06, 0.16), Vector3(0, -6.0, 0), 1.3)
	if not _d.decides():
		_d._say("ოქრო! %s დაიჭირე" % NAME, 3.0)
		return
	var bank := CoinBank.of(_d)
	if bank != null:
		bank.drop(at, GOLD)
	var loot := LootDrop.of(_d)
	var hero := _d._nearest_hero(at)
	if loot != null and hero != null:
		loot.net_loot(at + Vector3(1.0, 0.0, 0.0), hero.get_path(), randi())
	_d._say("ოქრო! %s დაიჭირე" % NAME, 3.0)


## A gold light in it and a trail of sparkles off its sack.
func _glitter() -> void:
	if _gold_rim == null:
		var sh := Shader.new()
		sh.code = FoeRoles.RIM_SHADER
		_gold_rim = ShaderMaterial.new()
		_gold_rim.shader = sh
		_gold_rim.set_shader_parameter(&"tint", Color(1.0, 0.75, 0.2))
		_gold_rim.set_shader_parameter(&"amount", 0.9)
	FoeRoles._overlay(body, _gold_rim)
	body.call(&"_show_bag", true)
	var p := GPUParticles3D.new()
	p.name = "Glitter"
	p.amount = 40
	p.lifetime = 0.9
	p.local_coords = false
	p.position = Vector3(0.0, 0.7, 0.0)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.3
	pm.direction = Vector3.UP
	pm.spread = 60.0
	pm.initial_velocity_min = 0.3
	pm.initial_velocity_max = 1.0
	pm.gravity = Vector3(0.0, -1.5, 0.0)
	pm.color = Color(1.0, 0.85, 0.35, 0.9)
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.06, 0.06)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.vertex_color_use_as_albedo = true
	q.material = m
	p.draw_pass_1 = q
	body.add_child(p)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.8, 0.35)
	light.light_energy = 1.4
	light.omni_range = 4.0
	light.position = Vector3(0.0, 1.0, 0.0)
	body.add_child(light)
