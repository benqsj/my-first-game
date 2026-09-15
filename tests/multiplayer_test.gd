extends SceneTree

## Headless checks for the co-op phase: who owns what, who is spawned, and the
## two places the single-player assumptions were buried.
##
##     godot --path . --headless --script res://tests/multiplayer_test.gd
##
## What cannot be checked here is two machines talking to each other — one
## process has one [SceneTree] and one `multiplayer`. That is what
## `tools/two_windows.sh` is for, and what the acceptance list in
## `MULTIPLAYER_PVE.md` §7.4 describes. Everything *else* is checkable, and the
## things that broke while this was being built are all in here.

const WORLD := "res://scenes/world/greybox_world.tscn"

var _failures := 0
var _world: World


func _initialize() -> void:
	_world = load(WORLD).instantiate() as World
	root.add_child(_world)
	await _wait(2)

	await _check_spawning()
	await _check_ownership()
	await _check_enemies()
	await _check_two_attackers()

	print("")
	if _failures == 0:
		print("All checks passed.")
	else:
		print("%d check(s) FAILED." % _failures)
	quit(1 if _failures > 0 else 0)


## --- Bodies arrive rather than being baked in -----------------------------
func _check_spawning() -> void:
	var players := _world.get_node_or_null("Players") as Node3D
	_check("the level has somewhere to put players", players != null)
	_check("and a spawner to put them there",
			_world.get_node_or_null("PlayerSpawner") is MultiplayerSpawner)
	_check("and marks to stand them on",
			(_world.get_node_or_null("SpawnPoints") as Node3D).get_child_count() >= 2)
	_check("the player is not baked into the level any more",
			_world.get_node_or_null("Player") == null)

	_check("one body is spawned for this peer", players.get_child_count() == 1,
			"%d bodies" % players.get_child_count())
	var mine := _world.player()
	_check("and it can be asked for", mine != null)
	_check("named for the peer that owns it", mine.name == "1", "named '%s'" % mine.name)
	_check("with that peer as its authority", mine.get_multiplayer_authority() == 1,
			"authority %d" % mine.get_multiplayer_authority())
	_check("and a model on it", mine.rig != null)

	# The whole point of the spawn data: a second peer gets *its* character, not
	# whatever this one picked.
	var theirs := _world.call("_build_player", {
		"peer": 2, "character": "avtandil", "point": 1,
	}) as Player
	_check("a second peer is built with their own character",
			theirs != null and theirs.profile != null
					and theirs.profile.weapon == CharacterProfile.Weapon.BOW,
			"profile %s" % (theirs.profile.display_name if theirs.profile != null else "<none>"))
	_check("and stands somewhere else", not theirs.position.is_equal_approx(mine.position),
			"%v against %v" % [theirs.position, mine.position])
	theirs.free()


## --- Only your own body is driven -----------------------------------------
func _check_ownership() -> void:
	var mine := _world.player()
	_check("your own body takes physics ticks", mine.is_physics_processing())
	_check("and owns the camera", mine.camera.current)
	_check("and is animated", mine.is_processing())

	# Somebody else's, in this window. Nothing about it may be driven from here:
	# the whole reason the twenty `Input.` call sites need no guards is that they
	# are all reached from `_physics_process`.
	var players := _world.get_node_or_null("Players") as Node3D
	var theirs := _world.call("_build_player", {
		"peer": 7, "character": "tariel", "point": 2,
	}) as Player
	players.add_child(theirs)
	await _wait(2)
	_check("somebody else's body takes none", not theirs.is_physics_processing())
	_check("and does not steal the camera", not theirs.camera.current)
	_check("but is still animated", theirs.is_processing() and theirs.rig != null)

	# The mirrors the synchronizer carries. Without them a remote knight animates
	# off `is_on_floor()`, which is the answer from a physics tick it never took.
	var sync := mine.get_node_or_null("Body") as MultiplayerSynchronizer
	_check("the body is set up to be replicated", sync != null)
	var carried := {}
	if sync != null and sync.replication_config != null:
		for path in sync.replication_config.get_properties():
			carried[String(path).get_slice(":", 1)] = true
	for field in ["position", "rotation", "velocity", "net_state", "net_blocking",
			"net_crouching", "net_airborne", "net_stowed", "net_draw", "net_aim"]:
		_check("  %s goes over the wire" % field, carried.has(field))

	_check("the swing is a replicated call", mine.has_method("net_attack"))
	# And so is the shot. Without it an arrow is built on whichever peer loosed
	# it — nobody else sees it fly, and since a hit is the host's to decide, one
	# loosed by a client lands on nothing at all.
	_check("and so is the shot", mine.has_method("net_loose"))
	theirs.queue_free()
	await _wait(2)


## --- The wolves are the host's business -----------------------------------
func _check_enemies() -> void:
	var wolf := _world.get_node("Enemies/Wolf1") as Wolf
	_check("a wolf thinks on the host", wolf.is_physics_processing())
	_check("and is animated everywhere", wolf.is_processing())
	_check("its body is set up to be replicated",
			wolf.get_node_or_null("Body") is MultiplayerSynchronizer)
	var golem := _world.get_node("Enemies/Golem1") as Golem
	_check("so is a golem's",
			golem.get_node_or_null("Body") is MultiplayerSynchronizer)

	# The cached `_player` is gone: it was looked up once at `_ready()`, before
	# any player existed in the multiplayer flow, and it could only ever hold one.
	_check("a wolf no longer caches one player",
			not ("_player" in wolf), "still has _player")
	_check("it looks for the nearest instead", wolf.has_method("_nearest_player"))

	var mine := _world.player()
	mine.global_position = wolf.global_position + Vector3(4.0, 0.0, 0.0)
	await _wait(3)
	_check("and finds them", wolf.call("_nearest_player") == mine)

	# A named part comes off wherever it is told to, without re-running the
	# geometry — which is what lets the host decide and everyone else agree.
	_check("a limb can be taken by name", wolf.rig.has_method("detach"))
	var before := wolf.rig.lost_parts()
	wolf.rig.call("detach", "tail")
	_check("and it comes off", wolf.rig.lost_parts() == before + 1,
			"%d -> %d" % [before, wolf.rig.lost_parts()])
	_check("the same limb twice is not two limbs",
			wolf.rig.call("detach", "tail") == "")


## --- Two people swinging at the same wolf ---------------------------------
##
## The bug this catches is real and was there: `_last_hit_serial` was a single
## number, so the second attacker's swing in the same tick looked like one that
## had already been counted.
func _check_two_attackers() -> void:
	var wolf := _world.get_node("Enemies/Wolf2") as Wolf
	wolf.sight_range = 0.0
	wolf.prowl_speed = 0.0
	wolf.corpse_linger = 1000.0
	wolf.global_position = Vector3(30.0, 0.5, 30.0)

	var players := _world.get_node_or_null("Players") as Node3D
	var mine := _world.player()
	var other := _world.call("_build_player", {
		"peer": 9, "character": "tariel", "point": 3,
	}) as Player
	players.add_child(other)
	await _wait(5)

	# Both standing on it, facing it, swinging on the same tick.
	for knight in [mine, other]:
		(knight as Player).global_position = wolf.global_position + Vector3(0.0, 0.0, 1.3)
		(knight as Player).velocity = Vector3.ZERO
		(knight as Player).rotation.y = 0.0
	await _wait(4)

	var before := wolf.rig.lost_parts()
	var landed := 0
	for round_at in 10:
		if wolf.is_dead:
			break
		for knight in [mine, other]:
			(knight as Player).global_position = wolf.global_position + Vector3(0.0, 0.0, 1.3)
			(knight as Player).rig.attack(CharacterRig.AttackStyle.SIDE)
		await _wait(20)
		landed = wolf.rig.lost_parts() - before
	_check("two players swinging at one wolf both land", landed >= 2,
			"%d limbs between them" % landed)

	var serials: Dictionary = wolf.get("_last_hit_serial")
	_check("and each is remembered separately", serials.size() >= 2,
			"%d attackers on the books" % serials.size())
	other.queue_free()
	await _wait(2)


#region Scaffolding
func _wait(frames: int) -> void:
	for i in frames:
		await physics_frame


func _check(label: String, condition: bool, detail: String = "") -> void:
	if condition:
		print("  ok   - %s" % label)
	else:
		_failures += 1
		print("  FAIL - %s %s" % [label, ("(%s)" % detail) if detail else ""])
#endregion
