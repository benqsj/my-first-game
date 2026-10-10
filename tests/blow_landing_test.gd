extends SceneTree
## The blow felt landing (the user's word, 2026-10-10; claude/hit_feel_plan.md):
## * the ogre's swing held at the top of its wind-up creeps on there, never
##   pulled back (it shook: its clip ran ahead of the move's clock);
## * a heavy blow that makes him reel, and one that fells him, hold the ogre
##   and him a beat as they land (hit stop);
## * a reel shoves him back over the ground on his feet, dying away; a blow
##   with more of its string to come shoves him far less.
##   Godot --headless --path . --script res://tests/blow_landing_test.gd

const OGRE := "res://scenes/enemies/pack/ogre.tscn"

var _failures := 0
var _world: World
var _panel: ArenaPanel
var _hero: Player
var _struck_at := -1
var _f := 0


func _check(what: String, ok: bool, detail: String = "") -> void:
	print("  %s - %s %s" % ["ok  " if ok else "FAIL", what, detail])
	if not ok:
		_failures += 1


func _initialize() -> void:
	_run.call_deferred()


func _arena() -> void:
	if _world != null:
		_world.queue_free()
		for i in 3:
			await process_frame
	_world = load("res://scenes/world/test_arena.tscn").instantiate()
	root.add_child(_world)
	for i in 30:
		await physics_frame
	_panel = _world.get_node("ArenaPanel") as ArenaPanel
	_panel._clear()
	_panel._wait_for_blow = false
	_hero = _world.player()
	_hero.immortal = true
	_struck_at = -1
	_hero.struck.connect(func(_d: float, _b: bool) -> void:
		if _struck_at < 0:
			_struck_at = _f)


## The ogre `move` thrown at him from its reach in front (held `hold` s at
## the top, a string of `string` swings). Returns the ogre.
func _swing(move: int, hold: float, string: int) -> OgreFighter:
	await _arena()
	var ahead := -_hero.global_basis.z
	ahead.y = 0.0
	ahead = ahead.normalized()
	var ogre := _panel.call_up(OGRE, false, _hero.global_position + ahead * 3.0) as OgreFighter
	ogre.max_health = 99999.0
	ogre.health = 99999.0
	ogre.stance = 0.0
	ogre.sight_range = 0.0
	ogre.string_most = string
	ogre._rng.seed = 11
	var holds: Dictionary = ogre.get(&"_holds")
	var lead := 0.22
	if holds.has(move):
		lead = float((holds[move] as Array)[3])
	holds[move] = [1.0 if hold > 0.0 else 0.0, hold, hold, lead]
	await physics_frame
	var reach := float(ogre._strike_from.get(move, ogre.strike_off))
	ogre.global_position = _hero.global_position + ahead * reach
	var to := _hero.global_position - ogre.global_position
	ogre.rotation.y = atan2(-to.x, -to.z)
	await physics_frame
	ogre._quarry = _hero
	ogre._open(move)
	return ogre


func _run() -> void:
	(load("res://scripts/hit_feel.gd") as Script).set(&"frame_clock", true)

	# -- the held swing stands still at the top
	var ogre := await _swing(OgreFighter.CLEAVE, 0.7, 1)
	var hold_at := float(ogre.call(&"_windup_end", OgreFighter.CLEAVE, 0.22))
	var spots: Array = []
	var rates: Array = []
	var at0 := _hero.global_position
	_f = 0
	while _f < 240:
		await physics_frame
		_f += 1
		var t: float = ogre._act_time
		if ogre.act == OgreFighter.CLEAVE and t > hold_at + 0.1 and t < hold_at + 0.6:
			spots.append(ogre._anim.clip_position())
			rates.append(ogre._anim._player.speed_scale)
	# held, it creeps on slowly (PackBrute.HOLD_CREEP) and is never pulled back
	var back := 0
	for i in range(1, spots.size()):
		if float(spots[i]) < float(spots[i - 1]) - 0.0005:
			back += 1
	var spread: float = float(spots[spots.size() - 1]) - float(spots[0]) if spots.size() > 1 else 0.0
	var fastest := 0.0
	for r: float in rates:
		fastest = maxf(fastest, r)
	_check("a held swing creeps at the top, never pulled back", spots.size() > 10 and back == 0
			and spread > 0.0 and spread < 0.08 and fastest < 0.15,
			"%d ticks, pulled back %d, clip moved %.4f s, fastest rate %.3f" % [spots.size(), back, spread, fastest])

	# -- a heavy blow alone: he reels, both held a beat, shoved back on his feet
	ogre = await _swing(OgreFighter.SMASH, 0.0, 1)
	at0 = _hero.global_position
	var held_ogre := false
	var held_him := false
	var downed := false
	_f = 0
	while _f < 200:
		await physics_frame
		_f += 1
		if _struck_at < 0:
			_hero.global_position = Vector3(at0.x, _hero.global_position.y, at0.z)
			_hero.velocity = Vector3.ZERO
		elif _f <= _struck_at + 2:
			held_ogre = held_ogre or HitFeel.is_held(ogre)
			held_him = held_him or bool(_hero.rig.call(&"in_hitstop"))
		if _hero.state == Player.State.DOWNED:
			downed = true
	var moved := Vector3(_hero.global_position.x - at0.x, 0.0, _hero.global_position.z - at0.z).length()
	_check("the smash alone lands and he reels", _struck_at > 0 and not downed, "struck at %d, downed %s" % [_struck_at, downed])
	_check("the reel holds the ogre and him a beat", held_ogre and held_him, "ogre %s, him %s" % [held_ogre, held_him])
	_check("the reel shoves him back over the ground", moved > 0.25 and moved < 1.2, "%.2f m" % moved)

	# -- a felling blow holds them too
	ogre = await _swing(OgreFighter.HEAVY, 0.0, 1)
	at0 = _hero.global_position
	held_ogre = false
	downed = false
	_f = 0
	while _f < 300:
		await physics_frame
		_f += 1
		if _struck_at < 0:
			_hero.global_position = Vector3(at0.x, _hero.global_position.y, at0.z)
			_hero.velocity = Vector3.ZERO
		elif _f <= _struck_at + 2:
			held_ogre = held_ogre or HitFeel.is_held(ogre)
		if _hero.state == Player.State.DOWNED:
			downed = true
	_check("the great blow fells him and holds the ogre a beat", downed and held_ogre,
			"downed %s, ogre held %s" % [downed, held_ogre])

	# -- a blow with more of its string to come shoves him only a little
	_hero.set(&"_blow_force", 0.5)
	_hero.call(&"_shove", Vector3.BACK, _hero.flinch_shove, _hero.shove_mid_string)
	var mid: float = (_hero.get(&"_flinch_push") as Vector3).length()
	_hero.call(&"_shove", Vector3.BACK, _hero.reel_shove, 1.0)
	var reel: float = (_hero.get(&"_flinch_push") as Vector3).length()
	_check("a string's blow shoves far less than a reel", mid > 0.0 and mid < reel * 0.3, "%.2f vs %.2f m/s" % [mid, reel])

	print("All checks passed." if _failures == 0 else "%d check(s) FAILED." % _failures)
	quit(1 if _failures > 0 else 0)
